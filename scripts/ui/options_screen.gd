class_name OptionsScreen
extends Control
## Options complètes : audio, vidéo, jus, jeu, accessibilité, commandes (remappage).

const REMAPPABLE: Array[String] = [
	"ui_spin",
	"bet_place",
	"bet_remove",
	"bet_undo",
	"bet_repeat",
	"bet_clear",
	"bet_cycle_prev",
	"bet_cycle_next",
	"item_panel",
	"speed_toggle",
	"skip_anim",
	"pause_menu",
	"playtest_note",
]
const ROW_W: float = 900.0

var _tabs: TabContainer = null
var _waiting_action: String = ""
var _remap_buttons: Dictionary[String, Button] = {}
var _remap_box: VBoxContainer = null


var _start_tab: int = 0


func setup(params: Dictionary) -> void:
	_start_tab = int(params.get("tab", 0))


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(UiKit.background(Palette.INK))
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 200
	v.offset_right = -200
	v.offset_top = 40
	v.offset_bottom = -40
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	v.add_child(UiKit.title(tr("MENU_OPTIONS"), UiKit.SIZE_H1))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_tabs)
	_audio_tab()
	_video_tab()
	_juice_tab()
	_game_tab()
	_access_tab()
	_input_tab()
	_tabs.current_tab = clampi(_start_tab, 0, _tabs.get_tab_count() - 1)
	var back: Button = UiKit.button(tr("MENU_BACK"), _back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	back.call_deferred("grab_focus")


func _back() -> void:
	UiKit.clear_cache()  # la taille du texte est prise en compte au prochain écran
	if GameState.has_active_run() and GameState.run().phase != RunState.Phase.GAME_OVER:
		GameState.goto(GameState.SCREEN_RUN)
	else:
		GameState.goto(GameState.SCREEN_TITLE)


func _tab(title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tr(title)
	# Jamais de défilement horizontal : les textes longs vont à la ligne.
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_tabs.add_child(scroll)
	return box


## Texte d'aide sous une option : retour à la ligne automatique dans la largeur de l'onglet.
func _desc(box: VBoxContainer, key: String) -> void:
	var l: Label = UiKit.label(tr(key), UiKit.SIZE_SMALL, Palette.SMOKE)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(200, 0)
	box.add_child(l)


func _row(box: VBoxContainer, label_key: String) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l: Label = UiKit.label(tr(label_key), UiKit.SIZE_BODY)
	l.custom_minimum_size = Vector2(420, 0)
	h.add_child(l)
	box.add_child(h)
	return h


func _slider(box: VBoxContainer, label_key: String, section: String, key: String, min_v: float, max_v: float, step: float) -> void:
	var h: HBoxContainer = _row(box, label_key)
	var s: HSlider = HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = Settings.f(section, key)
	s.custom_minimum_size = Vector2(380, 32)
	var val: Label = UiKit.label(_pct(s.value, max_v), UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "mono")
	s.value_changed.connect(_on_slider.bind(section, key, val, max_v))
	h.add_child(s)
	h.add_child(val)


## Pourcentage affiché : part du maximum (volumes), ou valeur réelle pour une échelle > 1.
static func _pct(v: float, max_v: float) -> String:
	return "%d %%" % roundi(v * 100.0 if max_v > 1.0 else v * 100.0 / maxf(max_v, 0.001))


func _on_slider(v: float, section: String, key: String, val: Label, max_v: float) -> void:
	Settings.set_value(section, key, v)
	val.text = _pct(v, max_v)
	if section == "audio":
		AudioBus.ui("click")


func _check(box: VBoxContainer, label_key: String, section: String, key: String) -> void:
	var h: HBoxContainer = _row(box, label_key)
	var c: CheckBox = CheckBox.new()
	c.button_pressed = Settings.b(section, key)
	c.toggled.connect(func(on: bool) -> void: _on_check(section, key, on))
	h.add_child(c)


## Le mode portable change d'autres réglages (bloom, images/s, texte) : l'écran se recharge.
func _on_check(section: String, key: String, on: bool) -> void:
	Settings.set_value(section, key, on)
	if section == "video" and key == "handheld":
		UiKit.clear_cache()
		GameState.goto(&"options", {"tab": _tabs.current_tab})


func _choice(box: VBoxContainer, label_key: String, section: String, key: String, values: Array, label_keys: Array) -> void:
	var h: HBoxContainer = _row(box, label_key)
	var o: OptionButton = OptionButton.new()
	var cur: Variant = Settings.get_value(section, key)
	for i: int in values.size():
		o.add_item(tr(String(label_keys[i])), i)
		if str(values[i]) == str(cur) or (cur is float and values[i] is int and is_equal_approx(float(values[i]), float(cur))):
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: _on_choice(section, key, values[i]))
	h.add_child(o)


## Changer de mode d'affichage change la liste des résolutions : l'écran se recharge.
func _on_choice(section: String, key: String, value: Variant) -> void:
	Settings.set_value(section, key, value)
	if section == "video" and key == "window_mode":
		GameState.goto(&"options", {"tab": _tabs.current_tab})


func _audio_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_AUDIO")
	for k: String in ["master", "music", "sfx", "ui", "ambience"]:
		_slider(b, "OPT_VOL_" + k.to_upper(), "audio", k, 0.0, 1.0, 0.05)
	b.add_child(UiKit.button(tr("SOUNDBOARD_OPEN"), _open_soundboard))


func _video_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_VIDEO")
	_choice(b, "OPT_WINDOW_MODE", "video", "window_mode", Settings.WINDOW_MODES, ["OPT_WM_WINDOWED", "OPT_WM_FULLSCREEN", "OPT_WM_EXCLUSIVE"])
	var screen: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var sizes: Array = []
	var size_labels: Array = []
	if Settings.s("video", "window_mode") == "windowed":
		for r: Vector2i in UiLayout.window_sizes_for(screen):
			sizes.append("%dx%d" % [r.x, r.y])
			size_labels.append("%d × %d  (%s)" % [r.x, r.y, UiLayout.aspect_label(r)])
		_choice(b, "OPT_WINDOW_SIZE", "video", "window_size", sizes, size_labels)
	else:
		sizes.append("native")
		size_labels.append(tr("OPT_RES_NATIVE") % [screen.x, screen.y, UiLayout.aspect_label(screen)])
		for r2: Vector2i in UiLayout.render_sizes_for(screen):
			sizes.append("%dx%d" % [r2.x, r2.y])
			size_labels.append("%d × %d  (%s)" % [r2.x, r2.y, UiLayout.aspect_label(r2)])
		_choice(b, "OPT_RENDER_RES", "video", "render_resolution", sizes, size_labels)
	_desc(b, "OPT_RES_DESC")
	_choice(b, "OPT_FPS_CAP", "video", "fps_cap", [0, 30, 60, 90, 120, 144], ["OPT_FPS_UNLIMITED", "30", "60", "90", "120", "144"])
	_check(b, "OPT_VSYNC", "video", "vsync")
	_slider(b, "OPT_CRT", "video", "crt", 0.0, 1.0, 0.05)
	_slider(b, "OPT_BLOOM", "video", "bloom", 0.0, 1.0, 0.05)
	_check(b, "OPT_SHOW_FPS", "video", "show_fps")
	_check(b, "OPT_WHEEL_3D", "video", "wheel_3d")
	_check(b, "OPT_DECOR_3D", "video", "decor_3d")
	b.add_child(UiKit.label(tr("OPT_WHEEL_3D_DESC"), UiKit.SIZE_SMALL, Palette.SMOKE))
	_check(b, "OPT_HANDHELD", "video", "handheld")
	_desc(b, "OPT_HANDHELD_DESC")


func _juice_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_JUICE")
	_slider(b, "OPT_JUICE", "juice", "intensity", 0.0, 1.0, 0.05)
	_slider(b, "OPT_SHAKE", "juice", "shake", 0.0, 1.0, 0.05)
	_check(b, "OPT_FLASHES", "juice", "flashes")
	_check(b, "OPT_REDUCED_MOTION", "juice", "reduced_motion")
	_slider(b, "OPT_CURSE_FX", "juice", "curse_fx", 0.0, 1.0, 0.1)


func _game_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_GAME")
	_choice(b, "OPT_LOCALE", "game", "locale", ["fr", "en"], ["LANG_FR", "LANG_EN"])
	_choice(b, "OPT_SPEED", "game", "speed", [1, 2, 4], ["SPEED_1", "SPEED_2", "SPEED_4"])
	_check(b, "OPT_CONFIRM", "game", "confirm_irreversible")
	_check(b, "OPT_SHOW_PROBS", "game", "show_probabilities")
	_choice(b, "OPT_THROW_MODE", "game", "throw_mode", ["skill", "quick", "simple"], ["OPT_TM_SKILL", "OPT_TM_QUICK", "OPT_TM_SIMPLE"])
	_desc(b, "OPT_THROW_MODE_DESC")
	_check(b, "OPT_ASSIST", "game", "assist")
	_check(b, "OPT_TUTORIAL_TIPS", "game", "tutorial_tips")
	_check(b, "OPT_TELEMETRY", "game", "telemetry")
	_desc(b, "OPT_TELEMETRY_DESC")
	b.add_child(UiKit.button(tr("OPT_RESET_TUTORIAL"), _reset_tutorial))
	b.add_child(UiKit.button(tr("OPT_OPEN_DATA"), _open_data_dir))


func _access_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_ACCESS")
	_choice(
		b,
		"OPT_COLORBLIND",
		"access",
		"colorblind",
		["off", "protan", "deutan", "tritan"],
		["CB_OFF", "CB_PROTAN", "CB_DEUTAN", "CB_TRITAN"]
	)
	_slider(b, "OPT_TEXT_SCALE", "access", "text_scale", UiKit.TEXT_SCALE_MIN, UiKit.TEXT_SCALE_MAX, 0.05)
	_desc(b, "OPT_TEXT_SCALE_DESC")
	_check(b, "OPT_HIGH_CONTRAST", "access", "high_contrast")
	_check(b, "OPT_SUBTITLES", "access", "subtitles")


func _input_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_INPUT")
	_choice(b, "OPT_INPUT_MODE", "game", "input_mode", InputGlyphs.MODES, ["OPT_IM_AUTO", "OPT_IM_KEYBOARD", "OPT_IM_GAMEPAD"])
	_desc(b, "OPT_INPUT_MODE_DESC")
	_slider(b, "OPT_STICK_SENS", "input", "stick_sensitivity", 0.0, 1.0, 0.05)
	_desc(b, "OPT_STICK_SENS_DESC")
	_remap_box = VBoxContainer.new()
	_remap_box.add_theme_constant_override("separation", 12)
	b.add_child(_remap_box)
	_build_remap_rows()
	b.add_child(UiKit.button(tr("OPT_RESET_INPUT"), _reset_input))
	EventBus.input_device_changed.connect(func(_pad: bool) -> void: _build_remap_rows())


## Une ligne par action remappable ; montre (et remappe) la commande du périphérique actif.
func _build_remap_rows() -> void:
	if not is_instance_valid(_remap_box):
		return
	for c: Node in _remap_box.get_children():
		_remap_box.remove_child(c)
		c.queue_free()
	_remap_buttons.clear()
	var device: String = "OPT_REMAP_PAD" if InputGlyphs.using_pad else "OPT_REMAP_KEYS"
	_remap_box.add_child(UiKit.label(tr(device), UiKit.SIZE_BODY, Palette.GOLD))
	for action: String in REMAPPABLE:
		var h: HBoxContainer = _row(_remap_box, "ACTION_" + action.to_upper())
		var btn: Button = UiKit.button("", _start_remap.bind(action), Vector2(220, 48))
		h.add_child(btn)
		_remap_buttons[action] = btn
		_paint_remap(action)


func _paint_remap(action: String) -> void:
	var btn: Button = _remap_buttons[action]
	for c: Node in btn.get_children():
		if c is PromptBar or c is HBoxContainer:
			c.queue_free()
	btn.text = ""
	var p: Control = InputGlyphs.prompt(action, 32)
	if p == null:
		btn.text = "—"
		return
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	btn.add_child(p)


func _start_remap(action: String) -> void:
	_waiting_action = action
	var btn: Button = _remap_buttons[action]
	for c: Node in btn.get_children():
		c.queue_free()
	btn.text = tr("OPT_PRESS_BUTTON") if InputGlyphs.using_pad else tr("OPT_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	var key_ev: InputEventKey = event as InputEventKey
	var pad_ev: InputEventJoypadButton = event as InputEventJoypadButton
	if key_ev != null and key_ev.pressed and not key_ev.echo and not InputGlyphs.using_pad:
		Settings.bind_key(_waiting_action, key_ev.physical_keycode)
	elif pad_ev != null and pad_ev.pressed and InputGlyphs.using_pad:
		Settings.bind_pad_button(_waiting_action, pad_ev.button_index)
	else:
		return
	var done: String = _waiting_action
	_waiting_action = ""
	_paint_remap(done)
	get_viewport().set_input_as_handled()


func _reset_input() -> void:
	Settings.reset_bindings()
	_build_remap_rows()


func _open_soundboard() -> void:
	add_child(SoundboardOverlay.new())


## Dossier des données (sauvegardes, journaux, télémétrie, captures des notes de test).
func _open_data_dir() -> void:
	OS.shell_open(ProjectSettings.globalize_path(DevMode.save_dir()))


func _reset_tutorial() -> void:
	TutorialDirector.reset()
	EventBus.toast.emit(tr("TOAST_TUTORIAL_RESET"), &"success")


func go_back() -> void:
	_back()
