extends Node
## Options joueur persistées dans user://settings.cfg.

const FILE: String = "settings.cfg"
const DEFAULTS: Dictionary = {
	"audio": {"master": 0.8, "music": 0.6, "sfx": 0.8, "ui": 0.7, "ambience": 0.5},
	"video":
	{
		"window_mode": "fullscreen",
		"window_size": "1600x900",
		"render_resolution": "native",
		"vsync": true,
		"fps_cap": 0,
		"crt": 0.5,
		"bloom": 0.6,
		"show_fps": false,
		"wheel_3d": true,
		"decor_3d": true,
		"handheld": false,
		"quality": "balanced"
	},
	"juice": {"intensity": 1.0, "shake": 1.0, "flashes": true, "reduced_motion": false, "curse_fx": 1.0},
	"game":
	{
		"speed": 1,
		"locale": "fr",
		"auto_repeat": false,
		"confirm_irreversible": true,
		"assist": false,
		"throw_mode": "skill",
		"show_probabilities": false,
		"tutorial_tips": true,
		"input_mode": "auto",
		"telemetry": false,
		"telemetry_asked": false,
		"haptics": true,
		"left_handed": false,
		"tap_confirm": false,
		"audio_offset_ms": -1
	},
	"access": {"colorblind": "off", "text_scale": 1.0, "high_contrast": false, "subtitles": true},
	"input": {"bindings": {}, "pad_bindings": {}, "stick_sensitivity": 0.35},
}

## Échelle de texte par défaut sur Steam Deck (écran 7 pouces, 1280×800).
const HANDHELD_TEXT_SCALE: float = 1.15
const ECO_PRESET: Dictionary = {"bloom": 0.0, "fps_cap": 60}
## Mode Steam Deck / portable : préréglage économie + texte agrandi. Les valeurs remplacées
## sont gardées (video/handheld_saved) et restaurées quand on désactive le mode.
const HANDHELD_KEYS: Array[String] = ["video/bloom", "video/fps_cap", "access/text_scale"]
const WINDOW_MODES: Array[String] = ["windowed", "fullscreen", "exclusive"]
## Mobile (Android) : niveaux de qualité du rendu (cf. RenderQuality).
const QUALITY_LEVELS: Array[String] = ["eco", "balanced", "high"]
const MOBILE_FILE: String = "settings_mobile.cfg"
## Premier lancement sur téléphone : texte agrandi, effets d'écran allégés, 60 images/s.
const MOBILE_DEFAULTS: Dictionary = {
	"access/text_scale": 1.35, "video/crt": 0.25, "video/bloom": 0.4, "video/fps_cap": 60, "video/quality": "balanced"
}

## Surcharge de vitesse non persistée (QA automatisée) ; 0 = utiliser l'option du joueur.
var speed_override: float = 0.0
var _cfg: ConfigFile = ConfigFile.new()
var _path: String = ""
var _applied_mode: String = ""
var _applied_size: String = ""
var _applied_render: String = ""


func _ready() -> void:
	# L'émulation mobile de développement a son propre fichier : elle ne touche pas aux
	# réglages des sessions PC.
	_path = DevMode.save_dir() + (MOBILE_FILE if Platform.is_emulated() else FILE)
	load_settings()
	apply_bindings()
	apply()


## Remappage persistant : `input/bindings` (action → touche physique) et
## `input/pad_bindings` (action → bouton de manette). Remplace la commande du même type.
func apply_bindings() -> void:
	var keys: Variant = get_value("input", "bindings")
	if keys is Dictionary:
		for action: Variant in (keys as Dictionary).keys():
			var k: InputEventKey = InputEventKey.new()
			k.physical_keycode = int((keys as Dictionary)[action]) as Key
			_replace_event(StringName(String(action)), k)
	var pads: Variant = get_value("input", "pad_bindings")
	if pads is Dictionary:
		for action2: Variant in (pads as Dictionary).keys():
			var j: InputEventJoypadButton = InputEventJoypadButton.new()
			j.button_index = int((pads as Dictionary)[action2]) as JoyButton
			_replace_event(StringName(String(action2)), j)


## Remplace les événements du même type (touche, ou bouton/axe de manette) d'une action.
static func _replace_event(a: StringName, ev: InputEvent) -> void:
	if not InputMap.has_action(a):
		return
	var pad: bool = ev is InputEventJoypadButton
	var keep: Array[InputEvent] = []
	for e: InputEvent in InputMap.action_get_events(a):
		var e_pad: bool = e is InputEventJoypadButton or e is InputEventJoypadMotion
		var same: bool = (pad and e_pad) or (not pad and e is InputEventKey)
		if not same:
			keep.append(e)
	InputMap.action_erase_events(a)
	InputMap.action_add_event(a, ev)
	for e2: InputEvent in keep:
		InputMap.action_add_event(a, e2)


func bind_key(action: String, physical: Key) -> void:
	var saved: Dictionary = get_value("input", "bindings") if get_value("input", "bindings") is Dictionary else {}
	saved[action] = physical
	var k: InputEventKey = InputEventKey.new()
	k.physical_keycode = physical
	_replace_event(StringName(action), k)
	set_value("input", "bindings", saved)


func bind_pad_button(action: String, button: JoyButton) -> void:
	var saved: Dictionary = get_value("input", "pad_bindings") if get_value("input", "pad_bindings") is Dictionary else {}
	saved[action] = button
	var j: InputEventJoypadButton = InputEventJoypadButton.new()
	j.button_index = button
	_replace_event(StringName(action), j)
	set_value("input", "pad_bindings", saved)


func reset_bindings() -> void:
	InputMap.load_from_project_settings()
	_cfg.set_value("input", "bindings", {})
	_cfg.set_value("input", "pad_bindings", {})
	save_settings()
	EventBus.settings_changed.emit()


func load_settings() -> void:
	_cfg = ConfigFile.new()
	var first_launch: bool = _cfg.load(_path) != OK
	_migrate()
	if first_launch:
		_detect_handheld()
		if Platform.is_mobile():
			_mobile_first_launch()
	for section: String in DEFAULTS.keys():
		var sec: Dictionary = DEFAULTS[section]
		for key: String in sec.keys():
			if not _cfg.has_section_key(section, key):
				_cfg.set_value(section, key, sec[key])


## Anciennes clés : `video/fullscreen` (booléen) devient `video/window_mode`.
## 1.5.2 : la vitesse d'animation repart une fois à ×1 (un réglage ×4 hérité restait collé).
func _migrate() -> void:
	if not _cfg.has_section_key("meta", "speed_reset_152"):
		if _cfg.has_section_key("game", "speed"):
			_cfg.set_value("game", "speed", 1)
		_cfg.set_value("meta", "speed_reset_152", true)
	if _cfg.has_section_key("video", "fullscreen"):
		if not _cfg.has_section_key("video", "window_mode"):
			_cfg.set_value("video", "window_mode", "fullscreen" if bool(_cfg.get_value("video", "fullscreen")) else "windowed")
		_cfg.erase_section_key("video", "fullscreen")


## Premier lancement sur console portable (Steam Deck) : texte un peu plus grand et
## préréglage économie (autonomie, 60 images/s tenues).
func _detect_handheld() -> void:
	if is_steam_deck():
		_set_handheld(true)


## Téléphone : réglages par défaut adaptés et langue du système (FR, sinon EN).
func _mobile_first_launch() -> void:
	for path: String in MOBILE_DEFAULTS.keys():
		var parts: PackedStringArray = path.split("/")
		_cfg.set_value(parts[0], parts[1], MOBILE_DEFAULTS[path])
	_cfg.set_value("game", "locale", "fr" if OS.get_locale_language() == "fr" else "en")
	# Décalage audio du rythme : latence de sortie mesurée par le système (réglable ensuite).
	var lat_ms: float = AudioServer.get_output_latency() * 1000.0
	_cfg.set_value("game", "audio_offset_ms", int(clampf(roundf(lat_ms / 10.0) * 10.0, 0.0, Platform.AUDIO_OFFSET_MAX_MS)))


static func is_steam_deck() -> bool:
	return OS.get_environment("SteamDeck") == "1" or OS.has_feature("steamdeck")


## Active / désactive le mode portable en gardant (puis en restaurant) les réglages touchés.
func _set_handheld(on: bool) -> void:
	if on:
		var saved: Dictionary = {}
		for path: String in HANDHELD_KEYS:
			var parts: PackedStringArray = path.split("/")
			saved[path] = get_value(parts[0], parts[1])
		_cfg.set_value("video", "handheld_saved", saved)
		_cfg.set_value("access", "text_scale", maxf(f("access", "text_scale"), HANDHELD_TEXT_SCALE))
		for key: String in ECO_PRESET.keys():
			_cfg.set_value("video", key, ECO_PRESET[key])
	else:
		var back: Variant = _cfg.get_value("video", "handheld_saved", {})
		if back is Dictionary:
			for path: Variant in (back as Dictionary).keys():
				var parts2: PackedStringArray = String(path).split("/")
				_cfg.set_value(parts2[0], parts2[1], (back as Dictionary)[path])
		if _cfg.has_section_key("video", "handheld_saved"):
			_cfg.erase_section_key("video", "handheld_saved")
	_cfg.set_value("video", "handheld", on)


func save_settings() -> void:
	_cfg.save(_path)


func get_value(section: String, key: String) -> Variant:
	var fallback: Variant = (DEFAULTS.get(section, {}) as Dictionary).get(key, null)
	return _cfg.get_value(section, key, fallback)


func set_value(section: String, key: String, value: Variant) -> void:
	if section == "video" and key == "handheld" and bool(value) != b("video", "handheld"):
		_set_handheld(bool(value))
		UiKit.clear_cache()
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
	if not DevMode.active() and not Platform.is_mobile():
		_apply_window()
		_apply_render_resolution()
	Engine.max_fps = int(get_value("video", "fps_cap"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if b("video", "vsync") else DisplayServer.VSYNC_DISABLED)
	TranslationServer.set_locale(s("game", "locale"))
	var tree: SceneTree = get_tree()
	if tree != null and tree.root != null:
		if tree.root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
			tree.root.content_scale_factor = 1.0  # la taille du texte agit sur les polices (UiKit.fs)


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


## Plein écran à une définition inférieure à celle de l'écran : la fenêtre racine est rendue à
## cette définition (étirement « viewport ») puis agrandie ; l'échelle du contenu garde la scène
## logique de référence (1920×1080). « native » : rendu à la définition de l'écran.
func _apply_render_resolution() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return
	var fullscreen: bool = s("video", "window_mode") != "windowed"
	var res: String = s("video", "render_resolution") if fullscreen else "native"
	if res == _applied_render:
		return
	_applied_render = res
	var root: Window = tree.root
	if res == "native":
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(UiLayout.DESIGN_SIZE)
		return
	var r: Vector2i = parse_size(res)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = r
	root.content_scale_factor = minf(float(r.x) / UiLayout.DESIGN_SIZE.x, float(r.y) / UiLayout.DESIGN_SIZE.y)


## « 1600x900 » → Vector2i(1600, 900) ; taille par défaut si illisible.
static func parse_size(text: String) -> Vector2i:
	var parts: PackedStringArray = text.split("x")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return UiLayout.DEFAULT_WINDOW
	return Vector2i(int(parts[0]), int(parts[1]))
