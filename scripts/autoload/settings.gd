extends Node
## Options joueur persistées dans user://settings.cfg.

const FILE: String = "settings.cfg"
const DEFAULTS: Dictionary = {
	"audio": {"master": 0.8, "music": 0.6, "sfx": 0.8, "ui": 0.7, "ambience": 0.5},
	"video":
	{
		"window_mode": "fullscreen",
		"window_size": "1600x900",
		"vsync": true,
		"fps_cap": 0,
		"crt": 0.5,
		"bloom": 0.6,
		"show_fps": false
	},
	"juice": {"intensity": 1.0, "shake": 1.0, "flashes": true, "reduced_motion": false},
	"game":
	{
		"speed": 1,
		"locale": "fr",
		"auto_repeat": false,
		"confirm_irreversible": true,
		"assist": false,
		"show_probabilities": false,
		"tutorial_tips": true
	},
	"access": {"colorblind": "off", "text_scale": 1.0, "high_contrast": false, "subtitles": true},
	"input": {"bindings": {}},
}

## Échelle de texte par défaut sur Steam Deck (écran 7 pouces, 1280×800).
const HANDHELD_TEXT_SCALE: float = 1.15
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "exclusive"]

## Surcharge de vitesse non persistée (QA automatisée) ; 0 = utiliser l'option du joueur.
var speed_override: float = 0.0
var _cfg: ConfigFile = ConfigFile.new()
var _path: String = ""
var _applied_mode: String = ""
var _applied_size: String = ""


func _ready() -> void:
	_path = DevMode.save_dir() + FILE
	load_settings()
	apply_bindings()
	apply()


## Remappage clavier persistant : remplace les touches clavier des actions concernées.
func apply_bindings() -> void:
	var saved: Variant = get_value("input", "bindings")
	if not (saved is Dictionary):
		return
	for action: Variant in (saved as Dictionary).keys():
		var a: StringName = StringName(String(action))
		if not InputMap.has_action(a):
			continue
		var keep: Array[InputEvent] = []
		for e: InputEvent in InputMap.action_get_events(a):
			if not (e is InputEventKey):
				keep.append(e)
		InputMap.action_erase_events(a)
		var k: InputEventKey = InputEventKey.new()
		k.physical_keycode = int((saved as Dictionary)[action]) as Key
		InputMap.action_add_event(a, k)
		for e2: InputEvent in keep:
			InputMap.action_add_event(a, e2)


func load_settings() -> void:
	_cfg = ConfigFile.new()
	var first_launch: bool = _cfg.load(_path) != OK
	_migrate()
	if first_launch:
		_detect_handheld()
	for section: String in DEFAULTS.keys():
		var sec: Dictionary = DEFAULTS[section]
		for key: String in sec.keys():
			if not _cfg.has_section_key(section, key):
				_cfg.set_value(section, key, sec[key])


## Anciennes clés : `video/fullscreen` (booléen) devient `video/window_mode`.
func _migrate() -> void:
	if _cfg.has_section_key("video", "fullscreen"):
		if not _cfg.has_section_key("video", "window_mode"):
			_cfg.set_value("video", "window_mode", "fullscreen" if bool(_cfg.get_value("video", "fullscreen")) else "windowed")
		_cfg.erase_section_key("video", "fullscreen")


## Premier lancement sur console portable (Steam Deck) : texte un peu plus grand.
func _detect_handheld() -> void:
	if OS.get_environment("SteamDeck") == "1" or OS.has_feature("steamdeck"):
		_cfg.set_value("access", "text_scale", HANDHELD_TEXT_SCALE)


func save_settings() -> void:
	_cfg.save(_path)


func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = (DEFAULTS.get(section, {}) as Dictionary).get(key, null)
	return _cfg.get_value(section, key, fallback)


func set_value(section: String, key: String, value: Variant) -> void:
	_cfg.set_value(section, key, value)
	save_settings()
	apply()
	EventBus.settings_changed.emit()


func f(section: String, key: String) -> float:
	return float(get_value(section, key))


func b(section: String, key: String) -> bool:
	return bool(get_value(section, key))


func s(section: String, key: String) -> String:
	return String(get_value(section, key))


func speed() -> float:
	if speed_override > 0.0:
		return speed_override
	return float(int(get_value("game", "speed")))


func juice() -> float:
	if b("juice", "reduced_motion"):
		return minf(f("juice", "intensity"), JuiceProfile.REDUCED_CAP)
	return f("juice", "intensity")


func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if not DevMode.active():
		_apply_window()
	Engine.max_fps = int(get_value("video", "fps_cap"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if b("video", "vsync") else DisplayServer.VSYNC_DISABLED)
	TranslationServer.set_locale(s("game", "locale"))
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = f("access", "text_scale")


## Mode d'affichage et taille de fenêtre (appliqués seulement s'ils changent, pour ne pas
## recentrer la fenêtre à chaque réglage).
func _apply_window() -> void:
	var mode_name: String = s("video", "window_mode")
	var size_name: String = s("video", "window_size")
	if mode_name == _applied_mode and size_name == _applied_size:
		return
	_applied_mode = mode_name
	_applied_size = size_name
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN
	match mode_name:
		"windowed":
			mode = DisplayServer.WINDOW_MODE_WINDOWED
		"exclusive":
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen: int = DisplayServer.window_get_current_screen()
	var wanted: Vector2i = parse_size(size_name)
	var allowed: Array[Vector2i] = UiLayout.window_sizes_for(DisplayServer.screen_get_usable_rect(screen).size)
	if not allowed.has(wanted):
		wanted = allowed[allowed.size() - 1]
	DisplayServer.window_set_size(wanted)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(usable.position + (usable.size - wanted) / 2)


## « 1600x900 » → Vector2i(1600, 900) ; taille par défaut si illisible.
static func parse_size(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return UiLayout.DEFAULT_WINDOW
	return Vector2i(int(parts[0]), int(parts[1]))
