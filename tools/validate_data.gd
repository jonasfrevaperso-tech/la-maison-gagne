extends SceneTree
## Validation du contenu data/ + compilation de tous les scripts.
## Vérifie : ids uniques, champs requis, déclencheurs/conditions/actions connus,
## références croisées (types de cases, éditions, sceaux, grigris), comptes cibles.
## Usage : godot --headless --path . -s res://tools/validate_data.gd

const REQUIRED_COMMON: Array[String] = ["id", "name_fr", "name_en", "desc_fr", "desc_en"]
const REQUIRED_BY_CAT: Dictionary = {
	"grigris": ["rarity", "tags", "flavor_fr", "flavor_en", "icon", "sfx"],
	"pocket_types": ["flavor_fr", "flavor_en", "icon"],
	"fortunes": ["flavor_fr", "flavor_en", "icon", "cost"],
	"contracts": ["cost", "flavor_fr", "flavor_en"],
	"creditors": ["tier_min", "tier_max"],
	"characters": [],
	"risks": ["level"],
}
const RARITIES: Array[String] = ["common", "rare", "legendary", "cursed"]
const SKIP_DESC: Array[String] = ["dialogues", "achievements", "challenges", "events"]

var errors: Array[String] = []
var warnings: Array[String] = []


func _initialize() -> void:
	_compile_scripts("res://scripts")
	_compile_scripts("res://tests")
	var db: ContentDB = ContentDB.new()
	db.load_all()
	errors.append_array(db.errors)
	for cat: String in ContentDB.CATEGORIES.keys():
		for e: Dictionary in db.list(cat):
			_validate_entry(db, cat, e)
	for e: String in warnings:
		print("avertissement : " + e)
	for e: String in errors:
		printerr("ERREUR DONNÉES : " + e)
	var counts: PackedStringArray = []
	for cat: String in ContentDB.CATEGORIES.keys():
		counts.append("%s=%d" % [cat, db.count(cat)])
	print("Contenu : " + ", ".join(counts))
	print("Validation : %d erreur(s), %d avertissement(s)" % [errors.size(), warnings.size()])
	quit(1 if not errors.is_empty() else 0)


func _compile_scripts(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for f: String in dir.get_files():
		if f.ends_with(".gd"):
			var path: String = dir_path.path_join(f)
			var s: GDScript = load(path) as GDScript
			if s == null:
				errors.append("Script non compilable : %s" % path)
	for d: String in dir.get_directories():
		_compile_scripts(dir_path.path_join(d))


func _validate_entry(db: ContentDB, cat: String, e: Dictionary) -> void:
	var eid: String = "%s/%s" % [cat, String(e.get("id", "?"))]
	var required: Array[String] = []
	if not SKIP_DESC.has(cat):
		required.assign(REQUIRED_COMMON)
	else:
		required.assign(["id"])
	for k: Variant in REQUIRED_BY_CAT.get(cat, []):
		required.append(String(k))
	for k: String in required:
		if not e.has(k):
			errors.append("%s : champ requis absent '%s'" % [eid, k])
	if cat == "grigris" and not RARITIES.has(String(e.get("rarity", ""))):
		errors.append("%s : rareté invalide" % eid)
	_validate_effects(db, eid, e.get("effects", []) as Array)
	for ph: Variant in e.get("phases", []):
		_validate_effects(db, eid + "/phase", (ph as Dictionary).get("effects", []) as Array)
	for ch: Variant in e.get("choices", []):
		_validate_effects(db, eid + "/choice", (ch as Dictionary).get("effects", []) as Array)
	var setup: Dictionary = e.get("setup", {})
	for gid: Variant in setup.get("grigris", []):
		if not db.has_entry("grigris", String(gid)):
			errors.append("%s : grigri de départ inconnu '%s'" % [eid, gid])
	for wop: Variant in setup.get("wheel", []):
		var t: String = String((wop as Dictionary).get("type", ""))
		if t != "" and not db.has_entry("pocket_types", t):
			errors.append("%s : type de case inconnu '%s'" % [eid, t])
	if cat == "contracts" and String(e.get("requires", "")) != "" and not db.has_entry("contracts", String(e["requires"])):
		errors.append("%s : prérequis inconnu" % eid)


func _validate_effects(db: ContentDB, eid: String, effects: Array) -> void:
	for eff_v: Variant in effects:
		if not (eff_v is Dictionary):
			errors.append("%s : effet non objet" % eid)
			continue
		var eff: Dictionary = eff_v as Dictionary
		var trig: StringName = StringName(String(eff.get("trigger", "")))
		if not EffectRunner.TRIGGERS.has(trig):
			errors.append("%s : déclencheur inconnu '%s'" % [eid, trig])
		for c: Variant in eff.get("if", []):
			_validate_cond(eid, c as Dictionary)
		for a: Variant in eff.get("do", []):
			var ad: Dictionary = a as Dictionary
			var op: StringName = StringName(String(ad.get("op", "")))
			if not EffectRunner.OPS.has(op):
				errors.append("%s : action inconnue '%s'" % [eid, op])
			_validate_value(eid, ad.get("v", 0))
			if (
				ad.has("type")
				and op in [&"transform_pocket", &"burn_random_pocket"]
				and not db.has_entry("pocket_types", String(ad["type"]))
			):
				errors.append("%s : type de case inconnu '%s'" % [eid, ad["type"]])
			if ad.has("edition") and String(ad["edition"]) != "" and not db.has_entry("editions", String(ad["edition"])):
				errors.append("%s : édition inconnue '%s'" % [eid, ad["edition"]])
			if ad.has("seal") and not db.has_entry("seals", String(ad["seal"])):
				errors.append("%s : sceau inconnu '%s'" % [eid, ad["seal"]])
			if op == &"add_grigri" and String(ad.get("id", "")) != "" and not db.has_entry("grigris", String(ad["id"])):
				errors.append("%s : grigri inconnu '%s'" % [eid, ad["id"]])
			if op == &"add_fortune" and String(ad.get("id", "random")) != "random" and not db.has_entry("fortunes", String(ad["id"])):
				errors.append("%s : fortune inconnue '%s'" % [eid, ad["id"]])


func _validate_cond(eid: String, c: Dictionary) -> void:
	var n: StringName = StringName(String(c.get("c", "")))
	if n == &"not":
		_validate_cond(eid, c.get("x", {}) as Dictionary)
		return
	if n == &"any":
		for sub: Variant in c.get("x", []):
			_validate_cond(eid, sub as Dictionary)
		return
	if not EffectRunner.PREDICATES.has(n) and not EffectRunner.VARIABLES.has(n):
		errors.append("%s : condition inconnue '%s'" % [eid, n])
	_validate_value(eid, c.get("v", 0))


func _validate_value(eid: String, v: Variant) -> void:
	if v is Dictionary:
		var vn: StringName = StringName(String((v as Dictionary).get("var", "")))
		if not EffectRunner.VARIABLES.has(vn):
			errors.append("%s : variable inconnue '%s'" % [eid, vn])
