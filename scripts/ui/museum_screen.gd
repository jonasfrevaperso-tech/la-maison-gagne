class_name MuseumScreen
extends Control
## Le Musée : cinq salles en vitrine (data/museum), une maquette par épreuve. On passe d'objet
## en objet (manette ←/→, LB/RB entre les salles, flèches, survol, glisser du doigt), le cartel
## donne la règle, le record et la médaille ; « Jouer » lance l'épreuve en entraînement
## (ThrowMinigame.start_practice, sans lâcher ni lien avec une partie). Records : MuseumRecords.

const MARGIN: float = 36.0
const CARTEL_W: float = 600.0
const STRIP_GAP: int = 10
const SWIPE_PX: float = 90.0
const MEDAL_COLORS: Array[Color] = [Palette.SMOKE, Palette.BRONZE, Palette.SILVER, Palette.GOLD_LIGHT]
const MEDAL_KEYS: Array[String] = ["MUSEUM_MEDAL_NONE", "MUSEUM_MEDAL_BRONZE", "MUSEUM_MEDAL_SILVER", "MUSEUM_MEDAL_GOLD"]
const DIFF_KEYS: Dictionary[String, String] = {"relax": "MUSEUM_DIFF_RELAX", "normal": "MUSEUM_DIFF_NORMAL", "expert": "MUSEUM_DIFF_EXPERT"}

var rooms: Array[Dictionary] = []
var room_index: int = 0
var difficulty: String = "normal"
var game: ThrowMinigame = null
var _view: MuseumRoom3D = null
var _ui: Control = null
var _room_name: Label = null
var _room_desc: Label = null
var _count: Label = null
var _strip: HBoxContainer = null
var _strip_buttons: Array[Button] = []
var _cartel_name: Label = null
var _cartel_desc: Label = null
var _cartel_record: RichTextLabel = null
var _diff_buttons: Dictionary[String, Button] = {}
var _play_btn: Button = null
var _play_layer: Control = null
var _host: Control = null
var _result: PanelContainer = null
var _playing: String = ""
var _drag_x: float = 0.0
var _dragging: bool = false
## Outillage (--dev-screen=museum --dev-trials=id [--dev-autoplay]) : épreuve lancée d'emblée.
var _dev_play: String = ""
## Pause d'une épreuve du Musée (Start / Échap / Retour Android) : Reprendre, Recommencer, Quitter.
var _pause: PanelContainer = null
var _focus0: int = 0
var _dev_bot: bool = false


func setup(params: Dictionary) -> void:
	room_index = int(params.get("room", 0))
	_focus0 = int(params.get("focus", 0))
	_dev_play = String(params.get("play", ""))
	_dev_bot = bool(params.get("bot", false))


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for r: Dictionary in DataRegistry.db.list("museum_rooms"):
		rooms.append(r)
	room_index = clampi(room_index, 0, maxi(rooms.size() - 1, 0))
	_view = MuseumRoom3D.new()
	add_child(_view)
	if Platform.is_mobile():  # la salle déborde sous le poinçon et les coins arrondis
		_view.offset_left = -ThrowMinigame.MOBILE_EDGE_BLEED
		_view.offset_right = ThrowMinigame.MOBILE_EDGE_BLEED
	_build_ui()
	_build_play_layer()
	_show_room(room_index, _focus0)
	AudioBus.play_music("menu")
	resized.connect(_fit)
	_fit()
	if _dev_play != "":
		_dev_start.call_deferred()


func _dev_start() -> void:
	for r: int in rooms.size():
		var k: int = (rooms[r].get("exhibits", []) as Array).find(_dev_play)
		if k >= 0:
			_show_room(r, k)
			play_current()
			return


func _process(_delta: float) -> void:
	if _dev_bot and _playing != "":
		game.bot_apply(game.bot_wants())


func _museum() -> Dictionary:
	if not SaveSystem.profile.has("museum") or not SaveSystem.profile["museum"] is Dictionary:
		SaveSystem.profile["museum"] = {"records": {}}
	return SaveSystem.profile["museum"] as Dictionary


# --------------------------------------------------------------------------- interface


func _build_ui() -> void:
	_ui = MarginContainer.new()
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		_ui.add_theme_constant_override("margin_" + side, int(MARGIN))
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	var v: VBoxContainer = VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 14)
	_ui.add_child(v)
	# Bandeau : retour, salle précédente, nom et devise de la salle, salle suivante, médailles.
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	v.add_child(top)
	var back: Button = UiKit.button(tr("MENU_BACK"), go_back, Vector2(180, 56))
	PromptBadge.attach(back, "ui_cancel")
	top.add_child(back)
	var prev: Button = UiKit.button(tr("MUSEUM_PREV"), _step_room.bind(-1), Vector2(230, 56))
	PromptBadge.attach(prev, "bet_cycle_prev")
	top.add_child(prev)
	var head: VBoxContainer = VBoxContainer.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(head)
	_room_name = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD, "display")
	_room_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_room_name)
	_room_desc = UiKit.label("", UiKit.SIZE_SMALL, Palette.IVORY)
	_room_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_room_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_room_desc)
	var nxt: Button = UiKit.button(tr("MUSEUM_NEXT"), _step_room.bind(1), Vector2(230, 56))
	PromptBadge.attach(nxt, "bet_cycle_next")
	top.add_child(nxt)
	# Le titre sépare les deux flèches : la manette passe de l'une à l'autre.
	prev.focus_neighbor_right = prev.get_path_to(nxt)
	nxt.focus_neighbor_left = nxt.get_path_to(prev)
	_count = UiKit.label("", UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(_count)
	_room_desc.visible = not Platform.is_mobile()  # téléphone : la place va au cartel
	# Milieu : la salle 3D (glisser du doigt), cartel à droite.
	var mid: HBoxContainer = HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(mid)
	var swipe: Control = Control.new()
	swipe.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	swipe.mouse_filter = Control.MOUSE_FILTER_PASS
	swipe.gui_input.connect(_on_swipe)
	mid.add_child(swipe)
	mid.add_child(_build_cartel())
	# Bas : rangée des objets de la salle.
	_strip = HBoxContainer.new()
	_strip.alignment = BoxContainer.ALIGNMENT_CENTER
	_strip.add_theme_constant_override("separation", STRIP_GAP)
	v.add_child(_strip)


func _build_cartel() -> PanelContainer:
	var panel: PanelContainer = UiKit.panel(Color(Palette.VELVET_DEEP, 0.92), Palette.GOLD_DARK)
	panel.custom_minimum_size.x = CARTEL_W
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var c: VBoxContainer = VBoxContainer.new()
	c.add_theme_constant_override("separation", 12)
	panel.add_child(c)
	_cartel_name = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	_cartel_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_cartel_name)
	_cartel_desc = UiKit.label("", UiKit.SIZE_SMALL if Platform.is_mobile() else UiKit.SIZE_BODY, Palette.IVORY)
	_cartel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_cartel_desc)
	_cartel_record = UiKit.rich("", UiKit.SIZE_BODY)
	_cartel_record.fit_content = true
	c.add_child(_cartel_record)
	var diffs: HBoxContainer = HBoxContainer.new()
	diffs.add_theme_constant_override("separation", 8)
	c.add_child(diffs)
	var group: ButtonGroup = ButtonGroup.new()
	for d: String in MuseumRecords.DIFFICULTIES:
		var b: Button = UiKit.button(tr(DIFF_KEYS[d]), _set_difficulty.bind(d), Vector2(0, 56))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d == difficulty
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		diffs.add_child(b)
		_diff_buttons[d] = b
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	c.add_child(row)
	_play_btn = UiKit.button(tr("MUSEUM_PLAY"), play_current, Vector2(0, 64))
	_play_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	PromptBadge.attach(_play_btn, "ui_accept")
	row.add_child(_play_btn)
	# Tuto : démonstration puis essai, puis l'épreuve elle-même (revoir à volonté).
	row.add_child(UiKit.button(tr("MUSEUM_TUTO"), play_current.bind(true), Vector2(0, 64)))
	return panel


func _show_room(k: int, focus: int) -> void:
	if rooms.is_empty():
		return
	room_index = posmod(k, rooms.size())
	var room: Dictionary = rooms[room_index]
	_room_name.text = Localization.t(room, "name")
	_room_desc.text = Localization.t(room, "desc")
	_view.focus = focus
	_view.build_room(room)
	for b: Button in _strip_buttons:
		b.queue_free()
	_strip_buttons.clear()
	for i: int in _view.exhibits.size():
		var b: Button = UiKit.button(_strip_label(_view.exhibits[i]), _on_strip.bind(i), Vector2(0, 56))
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_entered.connect(select.bind(i))
		b.mouse_entered.connect(select.bind(i))
		_strip.add_child(b)
		_strip_buttons.append(b)
	select(clampi(focus, 0, _strip_buttons.size() - 1))
	if not _strip_buttons.is_empty():
		_strip_buttons[_view.focus].call_deferred("grab_focus")


## Rangée des objets : au doigt, toucher choisit (« Jouer » lance) ; manette et souris jouent.
func _on_strip(k: int) -> void:
	if InputGlyphs.using_touch and not InputGlyphs.using_pad and k != _view.focus:
		select(k)
		_strip_buttons[k].grab_focus()
		return
	if InputGlyphs.using_touch and not InputGlyphs.using_pad:
		_strip_buttons[k].grab_focus()
		_play_btn.grab_focus()
		return
	play_current()


func _strip_label(trial_id: String) -> String:
	var m: MuseumRecords.Medal = MuseumRecords.best_medal(_museum(), trial_id)
	var mark: String = ["", "· ", "·· ", "··· "][m]
	return mark + Localization.name_of("throw_trials", trial_id)


func _step_room(d: int) -> void:
	AudioBus.ui("steps")
	_show_room(room_index + d, 0)


## Choisit l'objet `k` de la salle : caméra, projecteur et cartel.
func select(k: int) -> void:
	if k < 0 or k >= _view.exhibits.size():
		return
	if k != _view.focus:
		AudioBus.ui("hover")
	_view.set_focus(k)
	_refresh_cartel()


func _set_difficulty(d: String) -> void:
	difficulty = d
	_refresh_cartel()


func _refresh_cartel() -> void:
	if _view.exhibits.is_empty():
		return
	var id: String = _view.exhibits[_view.focus]
	var e: Dictionary = DataRegistry.db.get_entry("throw_trials", id)
	_cartel_name.text = Localization.t(e, "name")
	_cartel_desc.text = Localization.t(e, "desc")
	var mus: Dictionary = _museum()
	var lines: PackedStringArray = []
	var best: float = MuseumRecords.best(mus, id, difficulty)
	if best < 0.0:
		lines.append("[color=#%s]%s[/color]" % [Palette.SMOKE.to_html(false), tr("MUSEUM_NO_RECORD")])
	else:
		var md: MuseumRecords.Medal = MuseumRecords.medal_for(best)
		var medal_txt: String = "  [color=#%s]%s[/color]" % [MEDAL_COLORS[md].to_html(false), tr(MEDAL_KEYS[md])]
		lines.append(tr("MUSEUM_RECORD") % ("%d %%" % roundi(best * 100.0)) + medal_txt)
	if not ((SaveSystem.profile.get("seen", {}) as Dictionary).get("trials", []) as Array).has(id):
		lines.append("[color=#%s]%s[/color]" % [Palette.CYAN.to_html(false), tr("MUSEUM_UNSEEN")])
	_cartel_record.text = "\n".join(lines)
	_refresh_count()


func _refresh_count() -> void:
	var mus: Dictionary = _museum()
	var all_ids: Array = []
	for r: Dictionary in rooms:
		all_ids.append_array(r.get("exhibits", []) as Array)
	var in_room: int = MuseumRecords.count_medals(mus, _view.exhibits, MuseumRecords.Medal.BRONZE)
	var gold: int = MuseumRecords.count_medals(mus, all_ids, MuseumRecords.Medal.GOLD)
	_count.text = tr("MUSEUM_COUNT") % [in_room, _view.exhibits.size(), gold, all_ids.size()]
	for i: int in _strip_buttons.size():
		_strip_buttons[i].text = _strip_label(_view.exhibits[i])


func _on_swipe(event: InputEvent) -> void:
	var left_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch or left_click:
		var pressed: bool = event.is_pressed()
		var x: float = (event as InputEventMouseButton).position.x if left_click else (event as InputEventScreenTouch).position.x
		if pressed:
			_dragging = true
			_drag_x = x
		elif _dragging:
			_dragging = false
			var dx: float = x - _drag_x
			if absf(dx) >= SWIPE_PX:
				select(_view.focus + (-1 if dx > 0.0 else 1))
				if _view.focus < _strip_buttons.size():
					_strip_buttons[_view.focus].grab_focus()


func _input(event: InputEvent) -> void:
	if _playing != "" and _pause == null:
		if _play_input(event):
			get_viewport().set_input_as_handled()
		return
	if not _ui.visible:
		return
	if GameInput.pressed(event, "bet_cycle_prev") or GameInput.pressed(event, "bet_cycle_next"):
		_step_room(-1 if GameInput.pressed(event, "bet_cycle_prev") else 1)
		get_viewport().set_input_as_handled()


## Pendant une épreuve, clavier et manette vont à l'épreuve AVANT la navigation commune :
## B (ui_cancel) est un bouton de jeu (Shaker, Tiercé…). On quitte par la pause.
## Vrai si l'événement est consommé.
func _play_input(event: InputEvent) -> bool:
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return false  # le pointeur passe par l'interface puis _unhandled_input, comme en partie
	if GameInput.pressed(event, "pause_menu"):
		_open_pause()
		return true
	return game.handle(event)


func _open_pause() -> void:
	if _pause != null:
		return
	AudioBus.ui("panel_open")
	_pause = UiKit.panel(Color(Palette.VELVET_DEEP, 0.95), Palette.GOLD)
	_pause.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_pause.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_pause)
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_pause.add_child(v)
	var title: Label = UiKit.label(Localization.name_of("throw_trials", _playing), UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var resume: Button = UiKit.button(tr("MUSEUM_RESUME"), _close_pause)
	PromptBadge.attach(resume, "ui_cancel")
	v.add_child(resume)
	v.add_child(UiKit.button(tr("MUSEUM_RESTART"), _restart_play))
	v.add_child(UiKit.button(tr("MUSEUM_QUIT_TRIAL"), _quit_play))
	resume.call_deferred("grab_focus")


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null


func _restart_play() -> void:
	_close_pause()
	_end_play()
	play_current()


func _quit_play() -> void:
	_close_pause()
	_end_play()


func is_paused() -> bool:
	return _pause != null


func go_back() -> void:
	if _pause != null:
		_close_pause()
		return
	if _playing != "":
		_open_pause()
		return
	if _result != null:
		_close_result()
		return
	GameState.goto(GameState.SCREEN_TITLE)


# --------------------------------------------------------------------------- jeu


func _build_play_layer() -> void:
	_play_layer = Control.new()
	_play_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_layer.visible = false
	add_child(_play_layer)
	_play_layer.add_child(DecoBackground.new())
	_host = Control.new()
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.size = UiLayout.DESIGN_SIZE
	_play_layer.add_child(_host)
	game = ThrowMinigame.new()
	game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	game.size = UiLayout.DESIGN_SIZE
	game.full_host = _host
	game.hold = func() -> bool: return AppLifecycle.holding or _pause != null
	game.practice_done.connect(_on_practice_done)
	_host.add_child(game)


func _fit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	UiLayout.fit_frame(_play_layer, size)
	_host.position = ((_play_layer.size - UiLayout.DESIGN_SIZE) * 0.5).floor()
	game.panel_rect = Rect2((UiLayout.DESIGN_SIZE - ThrowMinigame.PANEL_RECT.size * Balance.f("museum.panel_scale")) * 0.5,
		ThrowMinigame.PANEL_RECT.size)


## Lance l'objet choisi en entraînement, à la difficulté du cartel.
func play_current(tuto: bool = false) -> void:
	if _view.exhibits.is_empty() or _playing != "":
		return
	_playing = _view.exhibits[_view.focus]
	AudioBus.ui("panel_open")
	_ui.visible = false
	_view.visible = false
	_view.process_mode = Node.PROCESS_MODE_DISABLED
	_play_layer.visible = true
	game.panel_scale = Balance.f("museum.panel_scale")
	game.start_practice(_playing, difficulty, tuto)


func _unhandled_input(event: InputEvent) -> void:
	if _playing == "" or _pause != null:
		return
	if game.handle(event):
		get_viewport().set_input_as_handled()


func _on_practice_done(score: float) -> void:
	var id: String = _playing
	_end_play()
	var mus: Dictionary = _museum()
	var record: bool = MuseumRecords.submit(mus, id, difficulty, score)
	SaveSystem.save_profile()
	GameState.check_profile_achievements()
	_show_result(id, score, record)


func _end_play() -> void:
	game.stop()
	_playing = ""
	_play_layer.visible = false
	_view.visible = true
	_view.process_mode = Node.PROCESS_MODE_INHERIT
	_ui.visible = true
	_refresh_cartel()
	if _view.focus < _strip_buttons.size():
		_strip_buttons[_view.focus].call_deferred("grab_focus")


func _show_result(id: String, score: float, record: bool) -> void:
	_ui.visible = false
	_result = UiKit.panel(Color(Palette.VELVET_DEEP, 0.95), Palette.GOLD)
	_result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_result.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_result.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_result)
	var v: VBoxContainer = VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	_result.add_child(v)
	var md: MuseumRecords.Medal = MuseumRecords.medal_for(score)
	for row: Array in [
		[Localization.name_of("throw_trials", id), UiKit.SIZE_H2, Palette.GOLD_LIGHT],
		[tr("MUSEUM_SCORE") % roundi(score * 100.0), UiKit.SIZE_H1, Palette.IVORY],
		[tr(MEDAL_KEYS[md]), UiKit.SIZE_H2, MEDAL_COLORS[md]],
	]:
		var l: Label = UiKit.label(String(row[0]), int(row[1]), row[2] as Color, "display")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	if record:
		var rl: Label = UiKit.label(tr("MUSEUM_NEW_RECORD"), UiKit.SIZE_BODY, Palette.EMERALD)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(rl)
		AudioBus.play("celebrate")
	var row_b: HBoxContainer = HBoxContainer.new()
	row_b.add_theme_constant_override("separation", 16)
	v.add_child(row_b)
	var again: Button = UiKit.button(tr("MUSEUM_RETRY"), _retry)
	row_b.add_child(again)
	var back: Button = UiKit.button(tr("MUSEUM_BACK"), _close_result)
	PromptBadge.attach(back, "ui_cancel")
	row_b.add_child(back)
	again.call_deferred("grab_focus")


func _close_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null
	_ui.visible = true
	if _view.focus < _strip_buttons.size():
		_strip_buttons[_view.focus].call_deferred("grab_focus")


func _retry() -> void:
	_close_result()
	play_current()
