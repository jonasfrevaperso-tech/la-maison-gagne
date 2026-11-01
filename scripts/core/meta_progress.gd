class_name MetaProgress
extends RefCounted
## Succès et défis, pilotés par les données (data/achievements, data/challenges).
## Logique pure : opère sur un dictionnaire de profil fourni par l'appelant (SaveSystem.profile).
##
## Un succès : {"id", "on": "spin|deadline_won|run_end|shop|profile", "cond": [{"k", "op", "v"}], "reward": {...}}
## Opérateurs : >=, >, <=, <, ==, != (numériques), "eq" / "ne" (texte).

const HOOKS: Array[String] = ["spin", "deadline_won", "run_end", "shop", "profile"]


## Métriques d'un tour résolu.
static func spin_metrics(run: RunState, ctx: ScoreContext) -> Dictionary:
	var straight_won: int = 0
	for b: String in ctx.bets_won:
		if b.begins_with("straight:"):
			straight_won = 1
	return {
		"spin_score": ctx.total,
		"spin_mult": ctx.mult(),
		"spin_chips": ctx.chips,
		"bets_won": ctx.bets_won.size(),
		"bets_lost": ctx.bets_lost.size(),
		"bets_placed": ctx.slip.size(),
		"is_zero": 1 if ctx.is_zero else 0,
		"number": ctx.landing.number if ctx.landing != null else -1,
		"landing_type": String(ctx.landing.type_id) if ctx.landing != null else "",
		"near_miss": 1 if ctx.near_miss else 0,
		"straight_won": straight_won,
		"color_streak": run.color_streak,
		"wheel_size": run.wheel.size(),
		"grigri_count": run.grigris.size(),
		"money": run.money,
		"character": run.character_id,
		"tier": run.tier,
		"chips_staked": _staked(ctx),
		"in_zone": 1 if ctx.throw_result != null and ctx.throw_result.in_zone else 0,
	}


static func _staked(ctx: ScoreContext) -> int:
	var t: int = 0
	for v: Variant in ctx.slip.values():
		t += int(v)
	return t


static func deadline_metrics(run: RunState) -> Dictionary:
	var last: Dictionary = run.deadline_log[run.deadline_log.size() - 1] if not run.deadline_log.is_empty() else {}
	var creditor: String = ""
	if int(last.get("deadline", 0)) == Balance.arr("run.deadline_kinds").size() - 1:
		var plan: Array = run.flags.get("creditor_plan", [])
		var t: int = int(last.get("tier", 1))
		if t - 1 < plan.size():
			creditor = String(plan[t - 1])
	return {
		"tier": int(last.get("tier", run.tier)),
		"deadline": int(last.get("deadline", 0)),
		"spins_used": int(last.get("spins_used", 0)),
		"score_ratio": float(last.get("score", 0)) / maxf(float(last.get("debt", 1)), 1.0),
		"money": run.money,
		"creditor": creditor,
		"character": run.character_id,
	}


static func run_metrics(run: RunState, db: ContentDB, victory: bool) -> Dictionary:
	var legendary: int = 0
	var cursed: int = 0
	for g: GrigriInstance in run.grigris:
		var r: String = String(db.get_entry("grigris", g.id).get("rarity", ""))
		legendary += 1 if r == "legendary" else 0
		cursed += 1 if r == "cursed" else 0
	var pacts: int = 0
	for v: Variant in run.pacts_used.values():
		pacts += int(v)
	return {
		"victory": 1 if victory else 0,
		"character": run.character_id,
		"risk": run.risk_level,
		"tier": run.tier,
		"endless_tier": run.tier if run.endless else 0,
		"deadlines": run.deadlines_cleared,
		"best_spin": run.best_spin,
		"grigri_count": run.grigris.size(),
		"legendary_count": legendary,
		"cursed_count": cursed,
		"zeros": run.zeros_hit,
		"pacts": pacts,
		"money": run.money,
		"wheel_size": run.wheel.size(),
		"total_spins": run.total_spins,
		"daily": 1 if run.daily else 0,
		"challenge": run.challenge_id,
		"sold": run.sold_count,
		"fortunes_used": int(run.flags.get("fortunes_used", 0)),
	}


static func profile_metrics(profile: Dictionary) -> Dictionary:
	var st: Dictionary = profile.get("stats", {})
	var seen: Dictionary = profile.get("seen", {})
	return {
		"runs": int(st.get("runs", 0)),
		"wins": int(st.get("wins", 0)),
		"spins": int(st.get("spins", 0)),
		"zeros": int(st.get("zeros", 0)),
		"best_spin": int(st.get("best_spin", 0)),
		"seen_grigris": (seen.get("grigris", []) as Array).size(),
		"achievements": (profile.get("achievements", []) as Array).size(),
		"challenges_done": (profile.get("challenges_done", []) as Array).size(),
	}


static func matches(cond: Array, metrics: Dictionary) -> bool:
	for c: Variant in cond:
		var d: Dictionary = c as Dictionary
		var k: String = String(d.get("k", ""))
		if not metrics.has(k):
			return false
		var op: String = String(d.get("op", ">="))
		if op == "eq":
			if String(metrics[k]) != String(d.get("v", "")):
				return false
		elif op == "ne":
			if String(metrics[k]) == String(d.get("v", "")):
				return false
		elif not EffectRunner.compare(float(metrics[k]), op, float(d.get("v", 0))):
			return false
	return true


## Évalue les succès d'un crochet ; renvoie les ids nouvellement débloqués (et les inscrit au profil).
static func evaluate(profile: Dictionary, db: ContentDB, hook: String, metrics: Dictionary) -> Array[String]:
	var unlocked: Array = profile.get("achievements", [])
	var out: Array[String] = []
	for a: Dictionary in db.list("achievements"):
		var aid: String = String(a["id"])
		if unlocked.has(aid) or String(a.get("on", "")) != hook:
			continue
		if matches(a.get("cond", []) as Array, metrics):
			unlocked.append(aid)
			out.append(aid)
			apply_reward(profile, a.get("reward", {}) as Dictionary)
	profile["achievements"] = unlocked
	return out


static func apply_reward(profile: Dictionary, reward: Dictionary) -> void:
	if reward.has("unlock_character"):
		var chars: Array = profile.get("unlocked_characters", [])
		if not chars.has(String(reward["unlock_character"])):
			chars.append(String(reward["unlock_character"]))
		profile["unlocked_characters"] = chars


## Un défi est réussi si son objectif est atteint en fin de run.
static func challenge_completed(db: ContentDB, run: RunState, victory: bool) -> bool:
	if run.challenge_id == "":
		return false
	var c: Dictionary = db.get_entry("challenges", run.challenge_id)
	var goal: Dictionary = c.get("goal", {"victory": true})
	if goal.has("endless_tier"):
		return run.endless and run.tier >= int(goal["endless_tier"])
	return victory
