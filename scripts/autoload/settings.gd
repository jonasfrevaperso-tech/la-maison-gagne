extends Node
## Options joueur persistées dans user://settings.cfg.

const PATH: String = "user://settings.cfg"
const DEFAULTS: Dictionary = {
	"audio": {"master": 0.8, "music": 0.6, "sfx": 0.8, "ui": 0.7, "ambience": 0.5},
	"video": {"fullscreen": false, "vsync": true, "crt": 0.5, "bloom": 0.6, "show_fps": false},
	"juice": {"intensity": 1.0, "shake": 1.0, "flashes": true, "reduced_motion": false},
	"game": {"speed": 1, "locale": "fr", "auto_repeat": false, "confirm_irreversible": true, "assist": false, "show_probabilities": false},
	"access": {"colorblind": "off", "text_scale": 1.0, "high_contrast": false, "subtitles": true},
	"input": {"bindings": {}},
}

## Surcharge de vitesse non persistée (QA automatisée) ; 0 = utiliser l'option du joueur.
var speed_override: float = 0.0
var _cfg: ConfigFile = ConfigFile.new()


func _ready() -> void:
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
	_cfg.load(PATH)
	for section: String in DEFAULTS.keys():
		var sec: Dictionary = DEFAULTS[section]
		for key: String in sec.keys():
			if not _cfg.has_section_key(section, key):
				_cfg.set_value(section, key, sec[key])


func save_settings() -> void:
	_cfg.save(PATH)


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
	var fs: bool = b("video", "fullscreen")
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if b("video", "vsync") else DisplayServer.VSYNC_DISABLED)
	TranslationServer.set_locale(s("game", "locale"))
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = f("access", "text_scale")
