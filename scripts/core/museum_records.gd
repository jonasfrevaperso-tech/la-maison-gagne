class_name MuseumRecords
extends RefCounted
## Logique pure du Musée : records et médailles par épreuve et par difficulté.
## Opère sur le dictionnaire de profil fourni par l'appelant (SaveSystem.profile["museum"]).
## Forme : {"records": {trial_id: {difficulty: meilleure note ∈ [0, 1]}}}. Sans effet sur les parties.

enum Medal { NONE, BRONZE, SILVER, GOLD }

const DIFFICULTIES: Array[String] = ["relax", "normal", "expert"]


## Médaille d'une note (seuils `museum.medal_*` de balance.json).
static func medal_for(score: float) -> Medal:
	if score >= Balance.f("museum.medal_gold"):
		return Medal.GOLD
	if score >= Balance.f("museum.medal_silver"):
		return Medal.SILVER
	if score >= Balance.f("museum.medal_bronze"):
		return Medal.BRONZE
	return Medal.NONE


static func _records(museum: Dictionary) -> Dictionary:
	if not museum.has("records") or not museum["records"] is Dictionary:
		museum["records"] = {}
	return museum["records"] as Dictionary


## Meilleure note d'une épreuve ; -1 si jamais jouée. Sans difficulté : la meilleure de toutes.
static func best(museum: Dictionary, trial_id: String, difficulty: String = "") -> float:
	var per: Dictionary = _records(museum).get(trial_id, {}) as Dictionary
	if difficulty != "":
		return float(per.get(difficulty, -1.0))
	var b: float = -1.0
	for d: String in DIFFICULTIES:
		b = maxf(b, float(per.get(d, -1.0)))
	return b


## Meilleure médaille d'une épreuve : la médaille compte en Normal et en Expert, la Détente
## plafonne au bronze (on s'y entraîne).
static func best_medal(museum: Dictionary, trial_id: String) -> Medal:
	var m: Medal = Medal.NONE
	for d: String in DIFFICULTIES:
		var sc: float = best(museum, trial_id, d)
		if sc < 0.0:
			continue
		var md: Medal = medal_for(sc)
		if d == "relax":
			md = mini(md, Medal.BRONZE) as Medal
		m = maxi(m, md) as Medal
	return m


## Enregistre une note ; vrai si c'est un nouveau record pour cette difficulté.
static func submit(museum: Dictionary, trial_id: String, difficulty: String, score: float) -> bool:
	var recs: Dictionary = _records(museum)
	if not recs.has(trial_id) or not recs[trial_id] is Dictionary:
		recs[trial_id] = {}
	var per: Dictionary = recs[trial_id] as Dictionary
	var sc: float = clampf(score, 0.0, 1.0)
	if sc <= float(per.get(difficulty, -1.0)):
		return false
	per[difficulty] = snappedf(sc, 0.001)
	return true


## Nombre d'épreuves de la liste qui ont au moins la médaille donnée.
static func count_medals(museum: Dictionary, trial_ids: Array, at_least: Medal) -> int:
	var n: int = 0
	for t: Variant in trial_ids:
		if best_medal(museum, String(t)) >= at_least:
			n += 1
	return n


## Nombre d'épreuves du profil qui ont la médaille d'or (succès « Conservateur »).
static func gold_count(museum: Dictionary) -> int:
	return count_medals(museum, _records(museum).keys(), Medal.GOLD)


## Nombre d'épreuves du profil qui ont au moins le bronze.
static func medal_count(museum: Dictionary) -> int:
	return count_medals(museum, _records(museum).keys(), Medal.BRONZE)
