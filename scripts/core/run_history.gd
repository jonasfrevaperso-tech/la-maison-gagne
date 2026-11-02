class_name RunHistory
extends RefCounted
## Historique des runs dans le profil (logique pure) : derniers runs et survie par palier.

const MAX_ENTRIES: int = 100


static func entry(run: RunState, victory: bool, seconds: float, seed_code: String, date: String) -> Dictionary:
	return {
		"date": date,
		"character": run.character_id,
		"risk": run.risk_level,
		"challenge": run.challenge_id,
		"daily": run.daily,
		"victory": victory,
		"tier": run.tier,
		"deadlines": run.deadlines_cleared,
		"spins": run.total_spins,
		"best_spin": run.best_spin,
		"minutes": snappedf(seconds / 60.0, 0.1),
		"seed": seed_code,
		"score_total": total_score(run),
	}


## Score cumulé du run : toutes les échéances terminées + l'échéance en cours.
static func total_score(run: RunState) -> int:
	var t: int = run.deadline_score
	for d: Dictionary in run.deadline_log:
		t += int(d.get("score", 0))
	return t


## Classement « Course de graine » : tous les runs joués sur cette graine, du meilleur au moins bon
## (victoire, puis échéances remboursées, puis score cumulé, puis le plus rapide).
static func leaderboard(profile: Dictionary, seed_code: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Variant in profile.get("history", []):
		if e is Dictionary and String((e as Dictionary).get("seed", "")) == seed_code:
			out.append(e as Dictionary)
	out.sort_custom(_better)
	return out


static func _better(a: Dictionary, b: Dictionary) -> bool:
	var va: int = 1 if bool(a.get("victory", false)) else 0
	var vb: int = 1 if bool(b.get("victory", false)) else 0
	if va != vb:
		return va > vb
	if int(a.get("deadlines", 0)) != int(b.get("deadlines", 0)):
		return int(a.get("deadlines", 0)) > int(b.get("deadlines", 0))
	if int(a.get("score_total", 0)) != int(b.get("score_total", 0)):
		return int(a.get("score_total", 0)) > int(b.get("score_total", 0))
	return float(a.get("minutes", 0.0)) < float(b.get("minutes", 0.0))


## Ajoute un run au profil : liste bornée + compteurs « entrés / passés » par palier.
static func record(profile: Dictionary, e: Dictionary, tiers: int) -> void:
	var hist: Array = profile.get("history", [])
	hist.append(e)
	while hist.size() > MAX_ENTRIES:
		hist.pop_front()
	profile["history"] = hist
	var surv: Dictionary = profile.get("tier_survival", {})
	var entered: Array = surv.get("entered", [])
	var passed: Array = surv.get("passed", [])
	while entered.size() < tiers:
		entered.append(0)
	while passed.size() < tiers:
		passed.append(0)
	var victory: bool = bool(e["victory"])
	var last: int = tiers if victory else clampi(int(e["tier"]), 1, tiers)
	for t: int in range(1, last + 1):
		entered[t - 1] = int(entered[t - 1]) + 1
		if victory or t < last:
			passed[t - 1] = int(passed[t - 1]) + 1
	surv["entered"] = entered
	surv["passed"] = passed
	profile["tier_survival"] = surv
	var st: Dictionary = profile.get("stats", {})
	st["minutes"] = snappedf(float(st.get("minutes", 0.0)) + float(e["minutes"]), 0.1)
	profile["stats"] = st


## Taux de passage de chaque palier (−1 si jamais atteint).
static func survival_rates(profile: Dictionary, tiers: int) -> Array[float]:
	var surv: Dictionary = profile.get("tier_survival", {})
	var entered: Array = surv.get("entered", [])
	var passed: Array = surv.get("passed", [])
	var out: Array[float] = []
	for i: int in tiers:
		var e: int = int(entered[i]) if i < entered.size() else 0
		var p: int = int(passed[i]) if i < passed.size() else 0
		out.append(float(p) / float(e) if e > 0 else -1.0)
	return out
