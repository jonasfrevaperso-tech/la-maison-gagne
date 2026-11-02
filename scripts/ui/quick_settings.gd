class_name QuickSettings
extends Overlay
## Réglages en cours de partie (menu pause) : volumes, rythme, lancer, commandes, affichage.
## Chaque changement s'applique immédiatement ; les options complètes restent sur l'écran titre.

const ROW_LABEL_W: float = 380.0
const SLIDER_W: float = 320.0

var _tabs: TabContainer = null


func build() -> void:
	panel_width = 980.0
	cancel_closes = true
	heading(tr("QS_TITLE"))
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(900, 470)
	body.add_child(_tabs)
	var audio: VBoxContainer = _tab("OPT_TAB_AUDIO")
	for k: String in ["master", "music", "sfx", "ui", "ambience"]:
		_slider(audio, "OPT_VOL_" + k.to_upper(), "audio", k, 0.0, 1.0, 0.05)
	var game: VBoxContainer = _tab("OPT_TAB_GAME")
	_choice(game, "OPT_SPEED", "game", "speed", [1, 2, 4], ["SPEED_1", "SPEED_2", "SPEED_4"])
	_choice(game, "OPT_THROW_MODE", "game", "throw_mode", ["skill", "quick", "simple"], ["OPT_TM_SKILL", "OPT_TM_QUICK", "OPT_TM_SIMPLE"])
	_check(game, "OPT_ASSIST", "game", "assist")
	_check(game, "OPT_SHOW_PROBS", "game", "show_probabilities")
	_check(game, "OPT_TUTORIAL_TIPS", "game", "tutorial_tips")
	var ctl: VBoxContainer = _tab("QS_TAB_CONTROLS")
	_choice(ctl, "OPT_INPUT_MODE", "game", "input_mode", InputGlyphs.MODES, ["OPT_IM_AUTO", "OPT_IM_KEYBOARD", "OPT_IM_GAMEPAD"])
	_slider(ctl, "OPT_STICK_SENS", "input", "stick_sensitivity", 0.0, 1.0, 0.05)
	_slider(ctl, "OPT_JUICE", "juice", "intensity", 0.0, 1.0, 0.05)
	_slider(ctl, "OPT_CURSE_FX", "juice", "curse_fx", 0.0, 1.0, 0.1)
	_slider(ctl, "OPT_SHAKE", "juice", "shake", 0.0, 1.0, 0.05)
	_check(ctl, "OPT_FLASHES", "juice", "flashes")
	_check(ctl, "OPT_HANDHELD", "video", "handheld")
	var done: Button = UiKit.button(tr("QS_DONE"), close)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	PromptBadge.attach(done, "ui_cancel")
	body.add_child(done)
	_first_focus.call_deferred()


func _first_focus() -> void:
	if InputGlyphs.using_pad:
		var f: Control = PadNavigator.first_focusable(_tabs.get_current_tab_control())
		if f != null:
			f.grab_focus()


func go_back() -> void:
	close()


func _tab(title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = tr(title)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	_tabs.add_child(scroll)
	return box


func _row(box: VBoxContainer, key: String) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	var l: Label = UiKit.label(tr(key), UiKit.SIZE_BODY)
	l.custom_minimum_size = Vector2(ROW_LABEL_W, 0)
	h.add_child(l)
	box.add_child(h)
	return h


func _slider(box: VBoxContainer, key: String, section: String, k: String, lo: float, hi: float, step: float) -> void:
	var h: HBoxContainer = _row(box, key)
	var s: HSlider = HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = Settings.f(section, k)
	s.custom_minimum_size = Vector2(SLIDER_W, 32)
	var val: Label = UiKit.label("%d %%" % roundi(s.value * 100.0), UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "mono")
	s.value_changed.connect(
		func(v: float) -> void:
			Settings.set_value(section, k, v)
			val.text = "%d %%" % roundi(v * 100.0)
			if section == "audio":
				AudioBus.ui("click")
	)
	h.add_child(s)
	h.add_child(val)


func _check(box: VBoxContainer, key: String, section: String, k: String) -> void:
	var h: HBoxContainer = _row(box, key)
	var c: CheckButton = CheckButton.new()
	c.button_pressed = Settings.b(section, k)
	c.toggled.connect(func(on: bool) -> void: Settings.set_value(section, k, on))
	h.add_child(c)


func _choice(box: VBoxContainer, key: String, section: String, k: String, values: Array, labels: Array) -> void:
	var h: HBoxContainer = _row(box, key)
	var o: OptionButton = OptionButton.new()
	o.custom_minimum_size = Vector2(SLIDER_W, 44)
	var cur: Variant = Settings.get_value(section, k)
	for i: int in values.size():
		o.add_item(tr(String(labels[i])))
		if str(values[i]) == str(cur) or (cur is float and values[i] is int and is_equal_approx(float(values[i]), float(cur))):
			o.select(i)
	o.item_selected.connect(func(i: int) -> void: Settings.set_value(section, k, values[i]))
	h.add_child(o)
