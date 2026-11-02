class_name Families
extends RefCounted
## Familles de grigris (builds) — logique pure. Chaque grigri appartient à une famille
## (data/families/families.json) ; en posséder assez débloque des paliers dont les effets
## s'ajoutent à ceux des grigris. Seul le palier le plus haut atteint est actif.


## Nombre de grigris actifs (non désactivés) par famille.
static func counts(run: RunState, db: ContentDB) -> Dictionary:
	var out: Dictionary = {}
	for g: GrigriInstance in run.grigris:
		if g.disabled:
			continue
		var fid: String = family_of(db, g.id)
		if fid != "":
			out[fid] = int(out.get(fid, 0)) + 1
	return out


static func family_of(db: ContentDB, grigri_id: String) -> String:
	return String(db.get_entry("grigris", grigri_id).get("family", ""))


## Index du palier atteint avec `count` grigris (-1 : aucun).
static func tier_index(def: Dictionary, count: int) -> int:
	var idx: int = -1
	var tiers: Array = def.get("tiers", [])
	for k: int in tiers.size():
		if count >= int((tiers[k] as Dictionary).get("n", 99)):
			idx = k
	return idx


## Seuil du palier suivant (0 si tous les paliers sont atteints).
static func next_threshold(def: Dictionary, count: int) -> int:
	for td: Variant in def.get("tiers", []):
		var n: int = int((td as Dictionary).get("n", 0))
		if count < n:
			return n
	return 0


## Paliers actifs de la partie : [{ "id", "def", "tier" (index), "count" }], dans l'ordre des données.
## Mis en cache sur le RunState (appelé à chaque déclencheur d'effet).
static func active(run: RunState, db: ContentDB) -> Array[Dictionary]:
	var key: int = run.grigris.size()
	for g: GrigriInstance in run.grigris:
		key = key * 31 + g.uid * 2 + (1 if g.disabled else 0)
	if key != run.family_cache_key:
		run.family_cache = _compute(run, db)
		run.family_cache_key = key
	return run.family_cache


static func _compute(run: RunState, db: ContentDB) -> Array[Dictionary]:
	var c: Dictionary = counts(run, db)
	var out: Array[Dictionary] = []
	if c.is_empty():
		return out
	for def: Dictionary in db.list("families"):
		var fid: String = String(def["id"])
		var n: int = int(c.get(fid, 0))
		var ti: int = tier_index(def, n)
		if ti >= 0:
			out.append({"id": fid, "def": def, "tier": ti, "count": n})
	return out
