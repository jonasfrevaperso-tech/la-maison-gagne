class_name IconLibrary
extends RefCounted
## Accès aux icônes pixel art (assets/icons/<id>.png, générées par tools/gen_icons.py).
## Repli : None → les widgets dessinent un placeholder cohérent (glyphe + couleur de rareté).

const DIR: String = "res://assets/icons/"
const PORTRAIT_DIR: String = "res://assets/portraits/"

static var _cache: Dictionary[String, Texture2D] = {}
static var _missing: Dictionary[String, bool] = {}


static func icon(icon_id: String) -> Texture2D:
	return _load(DIR + icon_id + ".png")


static func portrait(portrait_id: String) -> Texture2D:
	return _load(PORTRAIT_DIR + portrait_id + ".png")


static func _load(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	if _missing.has(path):
		return null
	if ResourceLoader.exists(path):
		var t: Texture2D = load(path) as Texture2D
		_cache[path] = t
		return t
	_missing[path] = true
	return null


static func clear_cache() -> void:
	_cache.clear()
	_missing.clear()
