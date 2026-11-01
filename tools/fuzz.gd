extends SceneTree
## Fuzzing de graines : runs aléatoires (personnage, risque, défi, paris, cibles, boutique, Fortune,
## pactes, événements) avec contrôle d'invariants après chaque action et aller-retour de sauvegarde.
## Usage : godot --headless --path . -s res://tools/fuzz.gd -- --runs=300 --seed=1
## Code de sortie 1 au premier invariant violé (graine et étape affichées pour reproduire).

const MAX_ACTIONS: int = 600
const ROUNDTRIP_EVERY: int = 7

var violations: Array[String] = []


func _initialize() -> void:
	var runs: int = 200
	var base_seed: int = 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.substr(7))
		elif a.begins_with("--seed="):
			base_seed = int(a.substr(7))
	var db: ContentDB = ContentDB.shared()
	var chars: Array[String] = db.ids("characters")
	var challenges: Array[String] = db.ids("challenges")
	var t0: int = Time.get_ticks_msec()
	var total_actions: int = 0
	for i: int in runs:
		var seed_value: int = base_seed * 7919 + i
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		var ch: String = challenges[rng.randi_range(0, challenges.size() - 1)] if rng.randf() < 0.25 else ""
		var cid: String = chars[rng.randi_range(0, chars.size() - 1)]
		var ctl: RunController = RunController.new(db)
		ctl.new_run(cid, rng.randi_range(0, 8), seed_value, ch)
		if rng.randf() < 0.3:
			ctl.run.flags["debt_mult"] = 0.05  # explorer aussi la fin de campagne et l'Infini
		total_actions += _fuzz_run(ctl, rng, seed_value)
		if not violations.is_empty():
			break
	for v: String in violations:
		printerr("INVARIANT VIOLÉ : " + v)
	print("Fuzz : %d runs, %d actions, %d violation(s), %d ms" % [runs, total_actions, violations.size(), Time.get_ticks_msec() - t0])
	quit(1 if not violations.is_empty() else 0)


func _fuzz_run(ctl: RunController, rng: RandomNumberGenerator, seed_value: int) -> int:
	var actions: int = 0
	while actions < MAX_ACTIONS:
		actions += 1
		var r: RunState = ctl.run
		match r.phase:
			RunState.Phase.BETTING:
				var spots: Array[BetSpot] = BetCatalog.all()
				for _k: int in rng.randi_range(0, 12):
					ctl.place_bet(spots[rng.randi_range(0, spots.size() - 1)].id, rng.randi_range(1, 3))
				if rng.randf() < 0.2:
					r.slip.undo()
				if not r.fortunes.is_empty() and rng.randf() < 0.3:
					ctl.use_fortune(rng.randi_range(0, r.fortunes.size() - 1), rng.randi_range(0, r.wheel.size() - 1))
				if r.phase != RunState.Phase.BETTING:
					continue
				ctl.ensure_some_bet()
				if not ctl.can_spin():
					violations.append("seed %d étape %d : aucun pari possible" % [seed_value, actions])
					return actions
				ctl.throw_ball(rng.randi_range(0, r.wheel.size() - 1))
				if ctl.can_rethrow() and rng.randf() < 0.5:
					ctl.rethrow(rng.randi_range(0, r.wheel.size() - 1))
				ctl.commit_spin()
			RunState.Phase.SHOP:
				for _k: int in rng.randi_range(0, 4):
					match rng.randi_range(0, 5):
						0:
							ShopModel.buy_grigri(r, ctl.db, rng.randi_range(0, 2))
						1:
							ShopModel.reroll(r, ctl.db)
						2:
							if not r.grigris.is_empty():
								ShopModel.sell_grigri(r, ctl.db, r.grigris[rng.randi_range(0, r.grigris.size() - 1)].uid)
						3:
							if ShopModel.buy_pack(r, ctl.db, rng.randi_range(0, 1)) == ShopModel.BuyResult.OK:
								if not ShopModel.choose_pack(r, ctl.db, rng.randi_range(0, 2), "add" if rng.randf() < 0.5 else "replace"):
									ShopModel.skip_pack(r)
						4:
							ShopModel.buy_contract(r, ctl.db, 0)
						5:
							if r.grigris.size() >= 2:
								var g: GrigriInstance = r.grigris.pop_front()
								r.grigris.append(g)
				ShopModel.skip_pack(r)
				ctl.leave_shop()
			RunState.Phase.PACT_OFFER:
				var opts: Array[Dictionary] = ctl.pact_options()
				if opts.is_empty() or rng.randf() < 0.3:
					ctl.decline_pact()
				else:
					ctl.accept_pact(opts[rng.randi_range(0, opts.size() - 1)])
			RunState.Phase.EVENT:
				var choices: Array = ctl.db.get_entry("events", r.pending_event_id).get("choices", [])
				ctl.resolve_event(rng.randi_range(0, maxi(choices.size() - 1, 0)))
			RunState.Phase.VICTORY:
				if rng.randf() < 0.5:
					ctl.continue_endless()
				else:
					return actions
			_:
				return actions
		if not _check(ctl, seed_value, actions):
			return actions
		if actions % ROUNDTRIP_EVERY == 0 and not _roundtrip(ctl, seed_value, actions):
			return actions
	return actions


func _check(ctl: RunController, seed_value: int, step: int) -> bool:
	var r: RunState = ctl.run
	var where: String = "seed %d étape %d (palier %d)" % [seed_value, step, r.tier]
	if r.money < 0:
		violations.append("%s : argent négatif %d" % [where, r.money])
	if r.wheel.size() < WheelModel.MIN_SIZE:
		violations.append("%s : roue trop petite %d" % [where, r.wheel.size()])
	if r.spins_left < 0:
		violations.append("%s : tours négatifs" % where)
	if r.debt <= 0:
		violations.append("%s : dette nulle" % where)
	if r.grigris.size() > Balance.i("slots.grigri_slots_max") + 1:
		violations.append("%s : trop de grigris %d" % [where, r.grigris.size()])
	if r.fortunes.size() > r.fortune_slots:
		violations.append("%s : trop de Fortune" % where)
	if r.precision < 1 or r.precision > Balance.i("throw.max_precision"):
		violations.append("%s : précision hors bornes %d" % [where, r.precision])
	for p: Pocket in r.wheel.pockets:
		if p.number < 0 or p.number >= WheelLayout.POCKET_COUNT:
			violations.append("%s : numéro de case invalide %d" % [where, p.number])
			break
		if not ctl.db.has_entry("pocket_types", String(p.type_id)):
			violations.append("%s : type de case inconnu %s" % [where, p.type_id])
			break
	return violations.is_empty()


func _roundtrip(ctl: RunController, seed_value: int, step: int) -> bool:
	var a: String = JSON.stringify(ctl.run.to_dict())
	var back: RunState = RunState.from_dict(JSON.parse_string(a) as Dictionary)
	if JSON.stringify(back.to_dict()) != a:
		var orig: Dictionary = ctl.run.to_dict()
		var redo: Dictionary = back.to_dict()
		var bad: PackedStringArray = []
		for k: Variant in orig.keys():
			if JSON.stringify(orig[k]) != JSON.stringify(redo.get(k)):
				bad.append("%s: %s ≠ %s" % [k, JSON.stringify(orig[k]).left(160), JSON.stringify(redo.get(k)).left(160)])
		violations.append("seed %d étape %d : aller-retour de sauvegarde inexact (%s)" % [seed_value, step, " | ".join(bad)])
		return false
	ctl.load_run(back)
	return true
