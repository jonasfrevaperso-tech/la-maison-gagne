class_name OptionsScreen
extends Control
## Options complètes : audio, vidéo, jus, jeu, accessibilité, commandes (remappage).

const REMAPPABLE: Array[String] = [
	"ui_spin", "bet_undo", "bet_repeat", "bet_clear", "speed_toggle", "skip_anim", "bet_place", "bet_cycle_prev", "bet_cycle_next"
]
const ROW_W: float = 900.0

var _tabs: TabContainer = null
var _waiting_action: String = ""
var _remap_buttons: Dictionary[String, Button] = {}


func setup(_params: Dictionary) -> void:
	pass


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
	var back: Button = UiKit.button(tr("MENU_BACK"), _back)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(back)
	back.call_deferred("grab_focus")


func _back() -> void:
	if GameState.has_active_run() and GameState.run().phase != RunState.Phase.GAME_OVER:
		GameState.goto(GameState.SCREEN_RUN)
	else:
		GameState.goto(GameState.SCREEN_TITLE)


func _tab(title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tr(title)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_tabs.add_child(scroll)
	return box


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
	var val: Label = UiKit.label("%d %%" % int(s.value * 100.0 / maxf(max_v, 0.001)), UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "mono")
	s.value_changed.connect(_on_slider.bind(section, key, val, max_v))
	h.add_child(s)
	h.add_child(val)


func _on_slider(v: float, section: String, key: String, val: Label, max_v: float) -> void:
	Settings.set_value(section, key, v)
	val.text = "%d %%" % int(v * 100.0 / maxf(max_v, 0.001))
	if section == "audio":
		AudioBus.ui("click")


func _check(box: VBoxContainer, label_key: String, section: String, key: String) -> void:
	var h: HBoxContainer = _row(box, label_key)
	var c: CheckBox = CheckBox.new()
	c.button_pressed = Settings.b(section, key)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(section, key, on))
	h.add_child(c)


func _choice(box: VBoxContainer, label_key: String, section: String, key: String, values: Array, label_keys: Array) -> void:
	var h: HBoxContainer = _row(box, label_key)
	var o: OptionButton = OptionButton.new()
	var cur: Variant = Settings.get_value(section, key)
	for i: int in values.size():
		o.add_item(tr(String(label_keys[i])), i)
		if str(values[i]) == str(cur):
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(section, key, values[i]))
	h.add_child(o)


func _audio_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_AUDIO")
	for k: String in ["master", "music", "sfx", "ui", "ambience"]:
		_slider(b, "OPT_VOL_" + k.to_upper(), "audio", k, 0.0, 1.0, 0.05)


func _video_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_VIDEO")
	_choice(b, "OPT_WINDOW_MODE", "video", "window_mode", Settings.WINDOW_MODES, ["OPT_WM_WINDOWED", "OPT_WM_FULLSCREEN", "OPT_WM_EXCLUSIVE"])
	var sizes: Array = []
	var size_labels: Array = []
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	for r: Vector2i in UiLayout.window_sizes_for(usable):
		sizes.append("%dx%d" % [r.x, r.y])
		size_labels.append("%d × %d" % [r.x, r.y])
	_choice(b, "OPT_WINDOW_SIZE", "video", "window_size", sizes, size_labels)
	_choice(b, "OPT_FPS_CAP", "video", "fps_cap", [0, 30, 60, 90, 120, 144], ["OPT_FPS_UNLIMITED", "30", "60", "90", "120", "144"])
	_check(b, "OPT_VSYNC", "video", "vsync")
	_slider(b, "OPT_CRT", "video", "crt", 0.0, 1.0, 0.05)
	_slider(b, "OPT_BLOOM", "video", "bloom", 0.0, 1.0, 0.05)
	_check(b, "OPT_SHOW_FPS", "video", "show_fps")


func _juice_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_JUICE")
	_slider(b, "OPT_JUICE", "juice", "intensity", 0.0, 1.0, 0.05)
	_slider(b, "OPT_SHAKE", "juice", "shake", 0.0, 1.0, 0.05)
	_check(b, "OPT_FLASHES", "juice", "flashes")
	_check(b, "OPT_REDUCED_MOTION", "juice", "reduced_motion")


func _game_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_GAME")
	_choice(b, "OPT_LOCALE", "game", "locale", ["fr", "en"], ["LANG_FR", "LANG_EN"])
	_choice(b, "OPT_SPEED", "game", "speed", [1, 2, 4], ["SPEED_1", "SPEED_2", "SPEED_4"])
	_check(b, "OPT_CONFIRM", "game", "confirm_irreversible")
	_check(b, "OPT_SHOW_PROBS", "game", "show_probabilities")
	_check(b, "OPT_ASSIST", "game", "assist")
	_check(b, "OPT_TUTORIAL_TIPS", "game", "tutorial_tips")
	b.add_child(UiKit.button(tr("OPT_RESET_TUTORIAL"), _reset_tutorial))


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
	_slider(b, "OPT_TEXT_SCALE", "access", "text_scale", 0.8, 1.4, 0.05)
	_check(b, "OPT_HIGH_CONTRAST", "access", "high_contrast")
	_check(b, "OPT_SUBTITLES", "access", "subtitles")


func _input_tab() -> void:
	var b: VBoxContainer = _tab("OPT_TAB_INPUT")
	for action: String in REMAPPABLE:
		var h: HBoxContainer = _row(b, "ACTION_" + action.to_upper())
		var btn: Button = UiKit.button(_action_text(action), _start_remap.bind(action), Vector2(320, 48))
		h.add_child(btn)
		_remap_buttons[action] = btn
	b.add_child(UiKit.button(tr("OPT_RESET_INPUT"), _reset_input))


func _action_text(action: String) -> String:
	var parts: PackedStringArray = []
	for e: InputEvent in InputMap.action_get_events(action):
		parts.append(e.as_text().replace(" - Physical", ""))
	return " / ".join(parts)


func _start_remap(action: String) -> void:
	_waiting_action = action
	_remap_buttons[action].text = tr("OPT_PRESS_KEY")


func _input(event: InputEvent) -> void:
	if _waiting_action == "":
		return
	if event is InputEventKey and event.is_pressed():
		var k: InputEventKey = event as InputEventKey
		var keep: Array[InputEvent] = []
		for e: InputEvent in InputMap.action_get_events(_waiting_action):
			if not (e is InputEventKey):
				keep.append(e)
		InputMap.action_erase_events(_waiting_action)
		var ne: InputEventKey = InputEventKey.new()
		ne.physical_keycode = k.physical_keycode
		InputMap.action_add_event(_waiting_action, ne)
		for e2: InputEvent in keep:
			InputMap.action_add_event(_waiting_action, e2)
		var saved: Dictionary = Settings.get_value("input", "bindings") if Settings.get_value("input", "bindings") is Dictionary else {}
		saved[_waiting_action] = k.physical_keycode
		Settings.set_value("input", "bindings", saved)
		_remap_buttons[_waiting_action].text = _action_text(_waiting_action)
		_waiting_action = ""
		get_viewport().set_input_as_handled()


func _reset_input() -> void:
	InputMap.load_from_project_settings()
	Settings.set_value("input", "bindings", {})
	for a: String in REMAPPABLE:
		_remap_buttons[a].text = _action_text(a)


func _reset_tutorial() -> void:
	TutorialDirector.reset()
	EventBus.toast.emit(tr("TOAST_TUTORIAL_RESET"), &"success")
