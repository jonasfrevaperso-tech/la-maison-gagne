class_name ContentDB
extends RefCounted
## Base de contenu chargée depuis data/ (JSON). Chaque catégorie = un dossier
## et un préfixe de fichiers ; tous les fichiers `prefix*.json` sont fusionnés.
## Un fichier contient soit un tableau d'entrées, soit {"entries": [...]}.

const CATEGORIES: Dictionary[String, Array] = {
	"pocket_types": ["res://data/pockets", "pocket_types"],
	"editions": ["res://data/pockets", "editions"],
	"seals": ["res://data/pockets", "seals"],
	"grigris": ["res://data/grigris", "grigris"],
	"fortunes": ["res://data/fortunes", "fortunes"],
	"families": ["res://data/families", "families"],
	"contracts": ["res://data/contracts", "contracts"],
	"creditors": ["res://data/creditors", "creditors"],
	"characters": ["res://data/characters", "characters"],
	"risks": ["res://data/risks", "risks"],
	"events": ["res://data/events", "events"],
	"achievements": ["res://data/achievements", "achievements"],
	"challenges": ["res://data/challenges", "challenges"],
	"dialogues": ["res://data/events", "dialogues"],
	"speakers": ["res://data/events", "speakers"],
	"tutorial": ["res://data/events", "tutorial"],
	"slot_symbols": ["res://data/slots", "slot_symbols"],
	"slot_prizes": ["res://data/slots", "slot_prizes"],
	"throw_trials": ["res://data/throw", "throw_trials"],
	"cutscenes": ["res://data/cutscenes", "cutscenes"],
}

static var _shared: ContentDB = null

var errors: Array[String] = []
var _data: Dictionary[String, Dictionary] = {}
var _order: Dictionary[String, Array] = {}


## Instance partagée (lecture seule) : le contenu ne change pas pendant l'exécution.
static func shared() -> ContentDB:
	if _shared == null:
		_shared = ContentDB.new()
		_shared.load_all()
	return _shared


func load_all() -> void:
	_data.clear()
	_order.clear()
	errors.clear()
	for cat: String in CATEGORIES.keys():
		var spec: Array = CATEGORIES[cat]
		_load_category(cat, String(spec[0]), String(spec[1]))


func _load_category(cat: String, dir_path: String, prefix: String) -> void:
	var entries: Dictionary = {}
	var ids: Array[String] = []
	_data[cat] = entries
	_order[cat] = ids
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	var files: Array[String] = []
	for f: String in dir.get_files():
		if f.begins_with(prefix) and f.ends_with(".json"):
			files.append(f)
	files.sort()
	for f: String in files:
		var path: String = dir_path.path_join(f)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var list: Array = []
		if parsed is Array:
			list = parsed as Array
		elif parsed is Dictionary and (parsed as Dictionary).has("entries"):
			list = (parsed as Dictionary)["entries"] as Array
		else:
			errors.append("%s : JSON invalide" % path)
			continue
		for e: Variant in list:
			if not (e is Dictionary) or not (e as Dictionary).has("id"):
				errors.append("%s : entrée sans id" % path)
				continue
			var ed: Dictionary = e as Dictionary
			var eid: String = String(ed["id"])
			if entries.has(eid):
				errors.append("%s : id dupliqué '%s'" % [path, eid])
				continue
			entries[eid] = ed
			ids.append(eid)


func has_entry(cat: String, entry_id: String) -> bool:
	return _data.has(cat) and _data[cat].has(entry_id)


func get_entry(cat: String, entry_id: String) -> Dictionary:
	if not has_entry(cat, entry_id):
		return {}
	return _data[cat][entry_id] as Dictionary


func ids(cat: String) -> Array[String]:
	var out: Array[String] = []
	if _order.has(cat):
		out.assign(_order[cat])
	return out


func list(cat: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for eid: String in ids(cat):
		out.append(_data[cat][eid] as Dictionary)
	return out


func count(cat: String) -> int:
	return ids(cat).size()


## Texte localisé d'une entrée : champ `<field>_<locale>` avec repli FR puis brut.
static func text(entry: Dictionary, field: String, locale: String = "fr") -> String:
	var key: String = "%s_%s" % [field, locale]
	if entry.has(key):
		return String(entry[key])
	if entry.has(field + "_fr"):
		return String(entry[field + "_fr"])
	return String(entry.get(field, ""))
