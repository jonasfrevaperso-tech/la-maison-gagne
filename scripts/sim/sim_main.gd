extends SceneTree
## Simulateur headless : joue N runs avec un bot et exporte des CSV + docs/BALANCE.md.
## Usage : godot --headless --path . -s res://scripts/sim/sim_main.gd -- --runs=500 --bot=greedy
##         [--character=lea|all] [--risk=0] [--seed=1] [--out=user://dev/sim] [--quiet] [--report]
##         [--telemetry=user://dev/sim_telemetry]  (même format que la télémétrie joueur)

const SECONDS_PER_SPIN: float = 20.0
const SECONDS_PER_SHOP: float = 35.0
const MAX_SPINS_PER_RUN: int = 400
const MIN_OFFERS: int = 8

var opts: Dictionary = {
	"runs": "100", "bot": "greedy", "character": "all", "risk": "0", "seed": "1", "out": "user://dev/sim", "quiet": "false", "report": "false"
}


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv: PackedStringArray = a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	_apply_overrides()
	var db: ContentDB = ContentDB.shared()
	var n: int = int(opts["runs"])
	var chars: Array[String] = db.ids("characters") if opts["character"] == "all" else [String(opts["character"])]
	if opts["character"] == "all":
		chars.erase("ghost")
	var results: Array[Dictionary] = []
	var t0: int = Time.get_ticks_msec()
	for i: int in n:
		var cid: String = chars[i % chars.size()]
		results.append(play_run(db, cid, int(opts["risk"]), int(opts["seed"]) * 100003 + i, String(opts["bot"])))
	var summary: Dictionary = summarize(db, results)
	summary["elapsed_ms"] = Time.get_ticks_msec() - t0
	export_csv(results, summary)
	if opts["report"] == "true":
		write_report(summary)
	print(
		(
			"Simulation %s : %d runs, victoire %.1f %%, palier moyen %.2f, durée estimée %.1f min, %d ms"
			% [
				opts["bot"],
				n,
				float(summary["win_rate"]) * 100.0,
				float(summary["avg_tier"]),
				float(summary["avg_minutes"]),
				int(summary["elapsed_ms"])
			]
		)
	)
	quit(0)


## Surcharges de tuning pour les balayages : --set=run.tier_debts=[...];economy.start_money=6
func _apply_overrides() -> void:
	if not opts.has("set"):
		return
	for assign: String in String(opts["set"]).split(";"):
		var kv: PackedStringArray = assign.split("=", true, 1)
		if kv.size() != 2:
			continue
		var parts: PackedStringArray = kv[0].split(".")
		var node: Dictionary = Balance.data()
		for i: int in parts.size() - 1:
			node = node[parts[i]]
		node[parts[parts.size() - 1]] = JSON.parse_string(kv[1])
	print("Surcharges : ", opts["set"])


func play_run(db: ContentDB, cid: String, risk: int, seed_value: int, bot_kind: String) -> Dictionary:
	var ctl: RunController = RunController.new(db)
	ctl.new_run(cid, risk, seed_value)
	var bot: SimBot = SimBot.new(bot_kind, seed_value ^ 0x5bd1e995)
	var tel: Array[Dictionary] = []
	var with_tel: bool = opts.has("telemetry")
	if with_tel:
		tel.append(RunTelemetry.run_start(ctl.run, "bot:" + bot_kind, String(ProjectSettings.get_setting("application/config/version"))))
	var spins: int = 0
	var shops: int = 0
	var best: int = 0
	var reached_tier: int = 1
	while spins < MAX_SPINS_PER_RUN:
		var run: RunState = ctl.run
		match run.phase:
			RunState.Phase.BETTING:
				bot.place_bets(ctl)
				var pre: Dictionary = RunTelemetry.snapshot(run)
				var out: RunController.SpinOutcome = ctl.spin(bot.aim(ctl))
				if with_tel:
					tel.append(RunTelemetry.spin(pre, ctl.run, out.ctx, SECONDS_PER_SPIN))
					if out.deadline_won or out.deadline_failed:
						tel.append(RunTelemetry.deadline(pre, ctl.run, out.ctx, out.deadline_won, 0.0))
				best = maxi(best, out.ctx.total)
				spins += 1
			RunState.Phase.SHOP:
				shops += 1
				var owned: Array[String] = RunTelemetry.grigri_ids(run)
				var offers0: Dictionary = bot.offers.duplicate()
				var picks0: int = bot.picks.size()
				var money0: int = run.money
				var rerolls0: int = run.shop_rerolls
				bot.shop(ctl)
				if with_tel:
					var rec: Dictionary = RunTelemetry.shop(
						run, _grown(offers0, bot.offers), bot.picks.slice(picks0), owned, money0, run.shop_rerolls - rerolls0, SECONDS_PER_SHOP
					)
					tel.append(rec)
				ctl.leave_shop()
			RunState.Phase.PACT_OFFER:
				bot.pact(ctl)
			RunState.Phase.EVENT:
				ctl.resolve_event(0)
			_:
				break
		reached_tier = maxi(reached_tier, ctl.run.tier)
	var r: RunState = ctl.run
	var won: bool = r.phase == RunState.Phase.VICTORY
	if with_tel:
		tel.append(RunTelemetry.run_end(r, won, float(spins) * SECONDS_PER_SPIN + float(shops) * SECONDS_PER_SHOP))
		_write_telemetry(tel, "run_%s_%d.jsonl" % [cid, seed_value])
	var final_grigris: Array[String] = []
	for g: GrigriInstance in r.grigris:
		final_grigris.append(g.id)
	return {
		"character": cid,
		"won": won,
		"tier": mini(r.tier, Balance.i("run.tiers")),
		"deadline": r.deadline_idx,
		"cleared": r.deadlines_cleared,
		"spins": spins,
		"shops": shops,
		"best_spin": best,
		"minutes": (float(spins) * SECONDS_PER_SPIN + float(shops) * SECONDS_PER_SHOP) / 60.0,
		"picks": bot.picks.duplicate(),
		"offers": bot.offers.duplicate(),
		"final": final_grigris,
		"money": r.money,
		"fail_score": r.deadline_score,
		"fail_debt": r.debt,
		"zeros": r.zeros_hit,
	}


func summarize(db: ContentDB, results: Array[Dictionary]) -> Dictionary:
	var n: int = maxi(results.size(), 1)
	var wins: int = 0
	var tier_sum: float = 0.0
	var minutes: float = 0.0
	var reach: Array[int] = []
	reach.resize(Balance.i("run.tiers") + 2)
	reach.fill(0)
	var by_char: Dictionary = {}
	var picks: Dictionary = {}
	var offers: Dictionary = {}
	var fail_ratio: Array[float] = []
	for r: Dictionary in results:
		if bool(r["won"]):
			wins += 1
		tier_sum += float(r["tier"])
		minutes += float(r["minutes"])
		for t: int in range(1, int(r["tier"]) + 1):
			reach[t] += 1
		if bool(r["won"]):
			reach[Balance.i("run.tiers") + 1] += 1
		var c: String = String(r["character"])
		if not by_char.has(c):
			by_char[c] = {"runs": 0, "wins": 0, "tier": 0.0}
		by_char[c]["runs"] += 1
		by_char[c]["wins"] += 1 if bool(r["won"]) else 0
		by_char[c]["tier"] += float(r["tier"])
		for gid: Variant in r["picks"]:
			picks[String(gid)] = int(picks.get(String(gid), 0)) + 1
		var ro: Dictionary = r["offers"]
		for gk: Variant in ro.keys():
			offers[String(gk)] = int(offers.get(String(gk), 0)) + int(ro[gk])
		if not bool(r["won"]):
			fail_ratio.append(float(r["fail_score"]) / maxf(float(r["fail_debt"]), 1.0))
	var total_picks: int = 0
	for v: Variant in picks.values():
		total_picks += int(v)
	var shop_ids: int = 0
	for e: Dictionary in db.list("grigris"):
		if String(e.get("rarity", "")) != "cursed":
			shop_ids += 1
	var mean_pick: float = float(total_picks) / maxf(float(shop_ids), 1.0)
	var avg_fail: float = 0.0
	for x: float in fail_ratio:
		avg_fail += x
	avg_fail /= maxf(float(fail_ratio.size()), 1.0)
	return {
		"runs": results.size(),
		"win_rate": float(wins) / float(n),
		"avg_tier": tier_sum / float(n),
		"avg_minutes": minutes / float(n),
		"reach": reach,
		"by_char": by_char,
		"picks": picks,
		"mean_pick": mean_pick,
		"avg_fail_ratio": avg_fail,
		"offers": offers,
	}


func export_csv(results: Array[Dictionary], summary: Dictionary) -> void:
	var dir: String = String(opts["out"])
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir.path_join("runs_%s.csv" % opts["bot"]), FileAccess.WRITE)
	if f == null:
		return
	f.store_line("character,won,tier,deadline,cleared,spins,shops,minutes,best_spin,zeros,final_grigris")
	for r: Dictionary in results:
		f.store_line(
			(
				"%s,%s,%d,%d,%d,%d,%d,%.1f,%d,%d,%s"
				% [
					r["character"],
					str(r["won"]),
					r["tier"],
					r["deadline"],
					r["cleared"],
					r["spins"],
					r["shops"],
					r["minutes"],
					r["best_spin"],
					r["zeros"],
					"|".join(r["final"])
				]
			)
		)
	f.close()
	var g: FileAccess = FileAccess.open(dir.path_join("picks_%s.csv" % opts["bot"]), FileAccess.WRITE)
	g.store_line("grigri,picks")
	var picks: Dictionary = summary["picks"]
	for k: Variant in picks.keys():
		g.store_line("%s,%d" % [k, picks[k]])
	g.close()


func write_report(s: Dictionary) -> void:
	var lines: PackedStringArray = []
	lines.append("# Rapport d'équilibrage (généré par `scripts/sim/sim_main.gd`)")
	lines.append("")
	lines.append(
		"Bot : **%s** · runs : %d · risque %s · durée de simulation %d ms" % [opts["bot"], s["runs"], opts["risk"], s["elapsed_ms"]]
	)
	lines.append("")
	lines.append("- Taux de victoire : **%.1f %%** (objectif bot compétent : 35–45 %%)" % (float(s["win_rate"]) * 100.0))
	lines.append("- Palier moyen atteint : %.2f / %d" % [s["avg_tier"], Balance.i("run.tiers")])
	lines.append("- Durée estimée d'un run : %.1f min (objectif 35–50 min pour un run gagnant)" % s["avg_minutes"])
	lines.append("- Progression moyenne de la dette au moment de l'échec : %.0f %%" % (float(s["avg_fail_ratio"]) * 100.0))
	lines.append("")
	lines.append(
		"Limites : les bots visent mieux ou moins bien qu'un humain (erreur de ±1 case dans 35 % des lancers) et le bot « synergy »"
	)
	lines.append("estime chaque offre sur 12 tours simulés, ce qui sous-évalue les grigris à croissance lente (ex. Ouroboros, Tirelire).")
	lines.append("Il compare la valeur au prix (les légendaires à 10 $ en pâtissent), ne joue ni transversales ni sixains, et ne voit")
	lines.append("ni la valeur d'un tour supplémentaire ni celle des améliorations économiques : ces « délaissés » relèvent du bot.")
	lines.append("")
	lines.append("## Courbe de survie par palier")
	lines.append("")
	lines.append("| Palier | Runs l'atteignant |")
	lines.append("|---|---|")
	var reach: Array = s["reach"]
	for t: int in range(1, reach.size()):
		var label: String = str(t) if t <= Balance.i("run.tiers") else "Victoire"
		lines.append("| %s | %.1f %% |" % [label, 100.0 * float(reach[t]) / maxf(float(s["runs"]), 1.0)])
	lines.append("")
	lines.append("## Par personnage")
	lines.append("")
	lines.append("| Personnage | Runs | Victoires | Palier moyen |")
	lines.append("|---|---|---|---|")
	var bc: Dictionary = s["by_char"]
	for c: Variant in bc.keys():
		var d: Dictionary = bc[c]
		lines.append(
			(
				"| %s | %d | %.1f %% | %.2f |"
				% [c, d["runs"], 100.0 * float(d["wins"]) / maxf(float(d["runs"]), 1.0), float(d["tier"]) / maxf(float(d["runs"]), 1.0)]
			)
		)
	lines.append("")
	var picks: Dictionary = s["picks"]
	var offers: Dictionary = s["offers"]
	var rates: Dictionary = {}
	var rate_sum: float = 0.0
	for k: Variant in offers.keys():
		if int(offers[k]) >= MIN_OFFERS:
			rates[k] = float(picks.get(k, 0)) / float(offers[k])
			rate_sum += float(rates[k])
	var mean_rate: float = rate_sum / maxf(float(rates.size()), 1.0)
	lines.append(
		(
			"## Grigris — taux de choix quand proposé (moyenne %.1f %%, %d grigris proposés ≥ %d fois)"
			% [mean_rate * 100.0, rates.size(), MIN_OFFERS]
		)
	)
	lines.append("")
	lines.append(
		"Dominant : > 2× la moyenne. Délaissé : < 0,25× la moyenne. Le taux brut dépend de la rareté, d'où cette mesure conditionnelle."
	)
	lines.append("")
	var keys: Array = rates.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return float(rates[a]) > float(rates[b]))
	lines.append("| Grigri | Proposé | Choisi | Taux | × moyenne | Statut |")
	lines.append("|---|---|---|---|---|---|")
	var dominant: int = 0
	var weak: int = 0
	for k: Variant in keys:
		var ratio: float = float(rates[k]) / maxf(mean_rate, 0.0001)
		var status: String = "dominant" if ratio > 2.0 else ("délaissé" if ratio < 0.25 else "ok")
		dominant += 1 if status == "dominant" else 0
		weak += 1 if status == "délaissé" else 0
		lines.append("| %s | %d | %d | %.0f %% | %.2f | %s |" % [k, offers[k], picks.get(k, 0), float(rates[k]) * 100.0, ratio, status])
	lines.insert(8, "- Grigris dominants : %d · délaissés : %d (sur %d mesurés)" % [dominant, weak, rates.size()])
	var f: FileAccess = FileAccess.open("res://docs/BALANCE.md", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lines) + "\n")
		f.close()


## Identifiants dont le compteur a augmenté entre deux instantanés.
static func _grown(before: Dictionary, after: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for k: Variant in after.keys():
		if int(after[k]) > int(before.get(k, 0)):
			out.append(String(k))
	return out


func _write_telemetry(records: Array[Dictionary], file_name: String) -> void:
	var dir: String = String(opts["telemetry"])
	if not dir.ends_with("/"):
		dir += "/"
	DirAccess.make_dir_recursive_absolute(dir)
	var f: FileAccess = FileAccess.open(dir + file_name, FileAccess.WRITE)
	if f == null:
		return
	for rec: Dictionary in records:
		f.store_line(JSON.stringify(rec))
	f.close()
