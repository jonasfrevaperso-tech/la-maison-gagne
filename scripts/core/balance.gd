class_name Balance
extends RefCounted
## Accès typé aux constantes de tuning de data/balance.json.
## Chargé une fois, partagé (cache statique) ; aucun nombre magique ailleurs.

const PATH: String = "res://data/balance.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		reload()
	return _data


static func reload() -> void:
	var text: String = FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	assert(parsed is Dictionary, "balance.json invalide")
	_data = parsed as Dictionary


## Lit une valeur par chemin pointé, ex. "bets.chip_value".
static func get_value(path: String) -> Variant:
	var node: Variant = data()
	for part: String in path.split("."):
		if not (node is Dictionary) or not (node as Dictionary).has(part):
			push_error("Balance : clé absente '%s'" % path)
			return null
		node = (node as Dictionary)[part]
	return node


static func i(path: String) -> int:
	return int(get_value(path))


static func f(path: String) -> float:
	return float(get_value(path))


static func b(path: String) -> bool:
	return bool(get_value(path))


static func arr(path: String) -> Array:
	var v: Variant = get_value(path)
	return v as Array if v is Array else []


static func dict(path: String) -> Dictionary:
	var v: Variant = get_value(path)
	return v as Dictionary if v is Dictionary else {}
