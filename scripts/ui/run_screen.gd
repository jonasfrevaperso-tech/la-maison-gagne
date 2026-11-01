class_name RunScreen
extends Control
## Écran principal d'un run. Machine à états d'interface :
## PARIS → VISÉE → BILLE → (RELANCE ?) → SCORE → paris suivants / boutique / pacte / fin.
## Toute la logique passe par RunController ; cet écran ne fait que présenter et relayer.

enum UiState { BETTING, AIMING, BALL, RETHROW, SCORING, OVERLAY, TARGETING }

const WHEEL_SIZE: Vector2 = Vector2(760, 640)
const TABLE_SIZE: Vector2 = Vector2(1040, 360)
const MARGIN: float = 28.0
const HISTORY_SHOWN: int = 14
const SHAKE_DECAY: float = 7.0
const FLASH_DECAY: float = 3.0

var ctl: RunController = null
var state: UiState = UiState.BETTING

var wheel_view: WheelView = null
var table_view: TableView = null
var score_panel: ScorePanel = null
var debt_gauge: DebtGauge = null
var grigri_bar: GrigriBar = null
var fortune_bar: HBoxContainer = null
var float_layer: FloatLayer = null
var presenter: ScorePresenter = null
var overlay_root: Control = null

var _content: Control = null
var _title_label: Label = null
var _info_label: RichTextLabel = null
var _money_label: Label = null
var _budget_label: Label = null
var _history_box: HBoxContainer = null
var _creditor_label: RichTextLabel = null
var _hint_label: Label = null
var _spin_btn: Button = null
var _rethrow_btn: Button = null
var _keep_btn: Button = null
var _undo_btn: Button = null
var _repeat_btn: Button = null
var _clear_btn: Button = null
var _speed_btn: Button = null
var _flash_rect: ColorRect = null
var _shake: float = 0.0
var _flash: float = 0.0
var _pending_outcome: RunController.SpinOutcome = null
var _target_fortune_slot: int = -1


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ctl = GameState.controller
	_build()
	EventBus.juice_shake.connect(_on_shake)
	EventBus.juice_flash.connect(_on_flash)
	EventBus.juice_hitstop.connect(_on_hitstop)
	_enter_phase()


# --------------------------------------------------------------------------- construction


func _build() -> void:
	var bg: DecoBackground = DecoBackground.new()
	bg.origin_ratio = Vector2(0.3, 0.55)
	add_child(bg)
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	# Barre du haut
	var top: HBoxContainer = HBoxContainer.new()
	top.position = Vector2(MARGIN, MARGIN * 0.6)
	top.add_theme_constant_override("separation", 26)
	_content.add_child(top)
	_title_label = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	top.add_child(_title_label)
	debt_gauge = DebtGauge.new()
	top.add_child(debt_gauge)
	_money_label = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "mono")
	top.add_child(_money_label)
	_budget_label = UiKit.label("", UiKit.SIZE_BODY, Palette.IVORY, "mono")
	top.add_child(_budget_label)
	_info_label = UiKit.rich("", UiKit.SIZE_BODY - 2)
	_info_label.position = Vector2(MARGIN, 92)
	_info_label.custom_minimum_size = Vector2(760, 0)
	_content.add_child(_info_label)
	_creditor_label = UiKit.rich("", UiKit.SIZE_BODY - 2)
	_creditor_label.position = Vector2(820, 92)
	_creditor_label.custom_minimum_size = Vector2(1060, 0)
	_content.add_child(_creditor_label)
	# Roue
	wheel_view = WheelView.new()
	wheel_view.position = Vector2(MARGIN, 150)
	wheel_view.size = WHEEL_SIZE
	wheel_view.setup(ctl.run.wheel, ctl.db)
	wheel_view.ball_settled.connect(_on_ball_settled)
	wheel_view.pocket_clicked.connect(_on_pocket_clicked)
	_content.add_child(wheel_view)
	_history_box = HBoxContainer.new()
	_history_box.position = Vector2(MARGIN, 150 + WHEEL_SIZE.y + 6)
	_history_box.add_theme_constant_override("separation", 4)
	_content.add_child(_history_box)
	# Score
	score_panel = ScorePanel.new()
	score_panel.position = Vector2(1000, 140)
	_content.add_child(score_panel)
	# Tapis
	table_view = TableView.new()
	table_view.position = Vector2(840, 360)
	table_view.size = TABLE_SIZE
	table_view.spot_changed.connect(_on_spot_changed)
	table_view.spot_hovered.connect(_on_spot_hovered)
	_content.add_child(table_view)
	# Actions
	var actions: HBoxContainer = HBoxContainer.new()
	actions.position = Vector2(840, 360 + TABLE_SIZE.y + 22)
	actions.add_theme_constant_override("separation", 10)
	_content.add_child(actions)
	var small: Vector2 = Vector2(150, 54)
	_undo_btn = UiKit.button(tr("BTN_UNDO"), _on_undo, small)
	_repeat_btn = UiKit.button(tr("BTN_REPEAT"), _on_repeat, small)
	_clear_btn = UiKit.button(tr("BTN_CLEAR"), _on_clear, small)
	_speed_btn = UiKit.button("", _on_speed, Vector2(90, 54))
	_spin_btn = UiKit.button(tr("BTN_SPIN"), _on_spin_pressed, Vector2(260, 64))
	_spin_btn.add_theme_font_size_override("font_size", UiKit.SIZE_H2)
	_rethrow_btn = UiKit.button(tr("BTN_RETHROW"), _on_rethrow, Vector2(220, 64))
	_keep_btn = UiKit.button(tr("BTN_KEEP"), _on_keep, Vector2(180, 64))
	for b: Button in [_undo_btn, _repeat_btn, _clear_btn, _speed_btn, _spin_btn, _rethrow_btn, _keep_btn]:
		actions.add_child(b)
	var menu_btn: Button = UiKit.button("☰", _on_menu, Vector2(64, 54))
	menu_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	menu_btn.position = Vector2(-MARGIN - 64, MARGIN * 0.5)
	add_child(menu_btn)
	_hint_label = UiKit.label("", UiKit.SIZE_SMALL, Palette.SMOKE)
	_hint_label.position = Vector2(840, 360 + TABLE_SIZE.y + 92)
	_content.add_child(_hint_label)
	# Grigris et Fortune
	grigri_bar = GrigriBar.new()
	grigri_bar.position = Vector2(MARGIN, 1080 - GrigriCard.CARD_SIZE.y - MARGIN)
	grigri_bar.changed.connect(_on_grigris_changed)
	_content.add_child(grigri_bar)
	fortune_bar = HBoxContainer.new()
	fortune_bar.add_theme_constant_override("separation", 10)
	fortune_bar.position = Vector2(1500, 1080 - GrigriCard.CARD_SIZE.y - MARGIN)
	_content.add_child(fortune_bar)
	# Couches d'effets
	float_layer = FloatLayer.new()
	add_child(float_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1, 1, 1, 0)
	add_child(_flash_rect)
	overlay_root = Control.new()
	overlay_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_root)
	presenter = ScorePresenter.new()
	presenter.score_panel = score_panel
	presenter.float_layer = float_layer
	presenter.grigri_bar = grigri_bar
	presenter.wheel_view = wheel_view
	presenter.table_view = table_view
	presenter.finished.connect(_on_score_finished)
	add_child(presenter)


# --------------------------------------------------------------------------- rafraîchissements


func _refresh_all() -> void:
	var r: RunState = ctl.run
	wheel_view.wheel = r.wheel
	var kind_key: String = "DEADLINE_" + r.deadline_kind().to_upper()
	_title_label.text = tr("HUD_TIER") % [r.tier, tr(kind_key)]
	debt_gauge.set_progress(r.deadline_score, r.debt, r.spins_left <= 1)
	_money_label.text = "%d $" % r.money
	_info_label.text = tr("HUD_INFO") % [r.spins_left, r.spins_total, r.chip_value, ctl.effective_precision(), r.act()]
	_refresh_budget()
	_refresh_creditor()
	_refresh_history()
	grigri_bar.bind(r)
	_refresh_fortunes()
	_refresh_table()
	_refresh_probabilities()
	_speed_btn.text = "×%d" % int(Settings.speed())


func _refresh_budget() -> void:
	var r: RunState = ctl.run
	_budget_label.text = tr("HUD_BUDGET") % [r.slip.total(), r.slip.budget]


func _refresh_table() -> void:
	var r: RunState = ctl.run
	table_view.slip = r.slip
	table_view.wheel = r.wheel
	table_view.chip_value = r.chip_value
	table_view.hide_odds = bool(r.flags.get("hide_odds", false))
	var hl: Dictionary = {}
	for spot_id: String in r.slip.order:
		for n: int in BetCatalog.get_spot(spot_id).numbers:
			hl[n] = true
	wheel_view.highlight_numbers = hl
	table_view.queue_redraw()
	_refresh_budget()
	_refresh_buttons()


func _refresh_buttons() -> void:
	var r: RunState = ctl.run
	var betting: bool = state == UiState.BETTING
	_spin_btn.disabled = not (betting and ctl.can_spin()) and state != UiState.AIMING
	_spin_btn.text = tr("BTN_RELEASE") if state == UiState.AIMING else tr("BTN_SPIN")
	_undo_btn.disabled = not betting or r.slip.history.is_empty()
	_repeat_btn.disabled = not betting or r.last_layout.is_empty()
	_clear_btn.disabled = not betting or r.slip.is_empty()
	_rethrow_btn.visible = state == UiState.RETHROW
	_keep_btn.visible = state == UiState.RETHROW
	_hint_label.text = tr("HINT_" + UiState.keys()[state])


func _refresh_probabilities() -> void:
	var r: RunState = ctl.run
	var show: bool = bool(r.flags.get("show_probabilities", false)) or Settings.b("game", "show_probabilities")
	if show and state == UiState.AIMING:
		wheel_view.probabilities = ctl.landing_distribution(wheel_view.aim_index)
	else:
		wheel_view.probabilities = []
	wheel_view.zone_width = ThrowResolver.zone_width_for(ctl.effective_precision(), int(r.flags.get("zone_width_override", 0)))


func _refresh_creditor() -> void:
	var r: RunState = ctl.run
	if r.creditor_id == "" or not r.is_creditor():
		_creditor_label.text = ""
		return
	var c: Dictionary = ctl.db.get_entry("creditors", r.creditor_id)
	var col: String = String(c.get("color", "ff2e88"))
	var phase_txt: String = ""
	var phases: Array = c.get("phases", [])
	if not phases.is_empty():
		phase_txt = (
			" · " + tr("HUD_PHASE") % [r.creditor_phase + 1, phases.size(), Localization.t(phases[r.creditor_phase] as Dictionary, "name")]
		)
	var ban: String = ""
	if r.banned_color != &"":
		ban = " · " + tr("HUD_BANNED") % tr("BET_" + String(r.banned_color).to_upper())
	_creditor_label.text = (
		"[color=#%s][b]%s[/b][/color] — %s%s%s" % [col, Localization.t(c, "name"), Localization.t(c, "desc"), phase_txt, ban]
	)


func _refresh_history() -> void:
	for c: Node in _history_box.get_children():
		c.queue_free()
	var r: RunState = ctl.run
	for i: int in mini(HISTORY_SHOWN, r.history.size()):
		var h: Dictionary = r.history[i]
		var chip: PanelContainer = PanelContainer.new()
		chip.add_theme_stylebox_override(
			"panel",
			UiKit.flat(Palette.pocket_color(StringName(String(h["c"]))), Palette.GOLD_DARK if i > 0 else Palette.GOLD_LIGHT, 2, 4, 4)
		)
		chip.custom_minimum_size = Vector2(44, 40)
		var l: Label = UiKit.label(str(int(h["n"])), UiKit.SIZE_SMALL, Palette.IVORY, "mono")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_child(l)
		chip.tooltip_text = tr("HISTORY_TIP") % [int(h["n"]), Localization.format_number(float(h["score"])), int(h["won"])]
		_history_box.add_child(chip)


func _refresh_fortunes() -> void:
	for c: Node in fortune_bar.get_children():
		c.queue_free()
	var r: RunState = ctl.run
	for i: int in r.fortunes.size():
		var card: GrigriCard = GrigriCard.new().configure("fortune", r.fortunes[i], i)
		card.draggable = false
		card.activated.connect(_on_fortune_activated)
		fortune_bar.add_child(card)
	for _j: int in maxi(r.fortune_slots - r.fortunes.size(), 0):
		var empty: Panel = Panel.new()
		empty.custom_minimum_size = GrigriCard.CARD_SIZE
		empty.modulate.a = GrigriBar.SLOT_EMPTY_ALPHA
		fortune_bar.add_child(empty)


# --------------------------------------------------------------------------- phases


## Affiche ce que la phase logique courante demande (reprise de sauvegarde incluse).
func _enter_phase() -> void:
	var r: RunState = ctl.run
	match r.phase:
		RunState.Phase.BETTING:
			_set_state(UiState.BETTING)
			AudioBus.play_music(_music_for())
			if r.spin_index == 0 and r.is_creditor() and r.creditor_id != "":
				_show_creditor_intro()
			elif r.spin_index == 0 and r.deadline_idx == 0 and r.tier == 1 and r.total_spins == 0:
				_show_overlay(TutorialHint.new())
		RunState.Phase.SHOP:
			_open_shop()
		RunState.Phase.PACT_OFFER:
			_open_pact()
		RunState.Phase.EVENT:
			_open_event()
		RunState.Phase.GAME_OVER:
			GameState.end_run(false)
		RunState.Phase.VICTORY:
			GameState.end_run(true)
		_:
			_set_state(UiState.BETTING)
	GameState.autosave()


func _music_for() -> String:
	var r: RunState = ctl.run
	if r.is_creditor() and r.creditor_id != "":
		return "boss"
	return ["act1", "act2", "act3"][clampi(r.act() - 1, 0, 2)]


func _set_state(s: UiState) -> void:
	state = s
	_refresh_all()


# --------------------------------------------------------------------------- entrées


func _unhandled_input(event: InputEvent) -> void:
	if state == UiState.OVERLAY:
		return
	if event.is_action_pressed("ui_spin"):
		_on_spin_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("bet_undo"):
		_on_undo()
	elif event.is_action_pressed("bet_repeat"):
		_on_repeat()
	elif event.is_action_pressed("bet_clear"):
		_on_clear()
	elif event.is_action_pressed("speed_toggle"):
		_on_speed()
	elif event.is_action_pressed("skip_anim"):
		_skip_animations()
	elif event.is_action_pressed("ui_cancel"):
		if state == UiState.TARGETING:
			_target_fortune_slot = -1
			_set_state(UiState.BETTING)
		else:
			_on_menu()


func _skip_animations() -> void:
	if state == UiState.BALL:
		wheel_view.skip_ball()
	elif state == UiState.SCORING:
		presenter.skip()


func _on_spot_changed(spot_id: String, delta: int) -> void:
	if state != UiState.BETTING:
		return
	if delta > 0:
		for _i: int in delta:
			var res: BetSlip.PlaceResult = ctl.place_bet(spot_id)
			if res != BetSlip.PlaceResult.OK:
				_bet_rejected(res)
				break
			AudioBus.play("chip_place", 1.0 + 0.04 * float(ctl.run.slip.chips.get(spot_id, 0)))
			GameState.log_input({"t": "bet", "spot": spot_id})
	else:
		if ctl.run.slip.chips.has(spot_id):
			ctl.run.slip.remove_one(spot_id)
			AudioBus.play("chip_remove")
	_refresh_table()


func _bet_rejected(res: BetSlip.PlaceResult) -> void:
	var key: String = (
		{
			BetSlip.PlaceResult.NO_BUDGET: "REJECT_BUDGET",
			BetSlip.PlaceResult.TABLE_LIMIT: "REJECT_LIMIT",
			BetSlip.PlaceResult.FORBIDDEN: "REJECT_FORBIDDEN",
		}
		. get(res, "REJECT_UNKNOWN")
	)
	EventBus.toast.emit(tr(key), &"error")
	AudioBus.ui("error")


func _on_spot_hovered(_spot_id: String) -> void:
	pass


func _on_undo() -> void:
	if state == UiState.BETTING and ctl.run.slip.undo() != "":
		AudioBus.play("chip_remove")
		_refresh_table()


func _on_repeat() -> void:
	if state == UiState.BETTING and ctl.repeat_last() > 0:
		AudioBus.play("chip_place")
		_refresh_table()


func _on_clear() -> void:
	if state == UiState.BETTING:
		ctl.run.slip.clear()
		AudioBus.play("chip_sweep")
		_refresh_table()


func _on_speed() -> void:
	var speeds: Array[int] = [1, 2, 4]
	var cur: int = int(Settings.speed())
	var nxt: int = speeds[(speeds.find(cur) + 1) % speeds.size()]
	Settings.set_value("game", "speed", nxt)
	_speed_btn.text = "×%d" % nxt


func _on_menu() -> void:
	if state != UiState.BETTING:
		return
	_show_overlay(PauseMenu.new())


# --------------------------------------------------------------------------- lancer


func _on_spin_pressed() -> void:
	match state:
		UiState.BETTING:
			if not ctl.can_spin():
				EventBus.toast.emit(tr("REJECT_NO_BET"), &"error")
				return
			wheel_view.start_aim()
			AudioBus.play("wheel_spin")
			_set_state(UiState.AIMING)
		UiState.AIMING:
			_release_throw()


func _release_throw() -> void:
	var target: int = wheel_view.stop_aim()
	GameState.log_input({"t": "throw", "target": target, "ms": Time.get_ticks_msec()})
	var tr_res: ThrowResolver.ThrowResult
	if has_meta("rethrowing"):
		remove_meta("rethrowing")
		tr_res = ctl.rethrow(target)
	else:
		tr_res = ctl.throw_ball(target)
	_start_ball(tr_res)


func _start_ball(tr_res: ThrowResolver.ThrowResult) -> void:
	AudioBus.play("ball_launch")
	wheel_view.play_throw(tr_res.landing_index, _predict_near_miss(tr_res.landing_index))
	_set_state(UiState.BALL)


func _predict_near_miss(landing: int) -> bool:
	var covered: Dictionary = {}
	for spot_id: String in ctl.run.slip.order:
		var s: BetSpot = BetCatalog.get_spot(spot_id)
		if not s.outside:
			for n: int in s.numbers:
				covered[n] = true
	if covered.has(ctl.run.wheel.at(landing).number):
		return true  # suspense aussi quand on gagne
	for ni: int in ctl.run.wheel.neighbors(landing, 1):
		if covered.has(ctl.run.wheel.at(ni).number):
			return true
	return false


func _on_ball_settled(_landing: int) -> void:
	if ctl.can_rethrow():
		_set_state(UiState.RETHROW)
	else:
		_commit()


func _on_rethrow() -> void:
	if state != UiState.RETHROW:
		return
	wheel_view.start_aim()
	_set_state(UiState.AIMING)
	# Le prochain relâchement utilisera la relance gratuite.
	_spin_btn.disabled = false
	set_meta("rethrowing", true)


func _on_keep() -> void:
	if state == UiState.RETHROW:
		_commit()


func _commit() -> void:
	var outcome: RunController.SpinOutcome = ctl.commit_spin()
	_pending_outcome = outcome
	table_view.flash_winners(outcome.ctx.landing_numbers)
	presenter.debt_remaining = maxi(ctl.run.debt - (ctl.run.deadline_score - outcome.ctx.total), 1)
	# La logique a déjà avancé : on fige l'affichage (mises posées, jauge) le temps du score.
	var shown: BetSlip = BetSlip.new()
	shown.budget = 1 << 20
	shown.apply_layout(outcome.ctx.slip)
	table_view.slip = shown
	table_view.queue_redraw()
	state = UiState.SCORING
	_refresh_buttons()
	presenter.play(outcome.ctx)


func _on_score_finished(_total: int) -> void:
	var out: RunController.SpinOutcome = _pending_outcome
	_pending_outcome = null
	SaveSystem.max_stat("best_spin", out.ctx.total)
	_refresh_all()
	if out.forgiven:
		EventBus.toast.emit(tr("TOAST_FORGIVEN"), &"success")
	if out.victory:
		_show_overlay(RewardOverlay.new().configure(out.reward, true), _on_victory_closed)
		return
	if out.deadline_won:
		AudioBus.play("deadline_won")
		_show_overlay(RewardOverlay.new().configure(out.reward, false), _on_reward_closed)
		return
	if out.deadline_failed:
		AudioBus.play("deadline_failed")
		if ctl.run.phase == RunState.Phase.PACT_OFFER:
			_open_pact()
		else:
			GameState.end_run(false)
		return
	GameState.autosave()
	_set_state(UiState.BETTING)


func _on_reward_closed() -> void:
	_open_shop()


func _on_victory_closed() -> void:
	GameState.end_run(true)


# --------------------------------------------------------------------------- surcouches


func _show_overlay(o: Control, on_closed: Callable = Callable()) -> void:
	state = UiState.OVERLAY
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(o)
	if o.has_signal("closed"):
		o.connect("closed", _on_overlay_closed.bind(o, on_closed), CONNECT_ONE_SHOT)


func _on_overlay_closed(o: Control, on_closed: Callable) -> void:
	o.queue_free()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state = UiState.BETTING
	if on_closed.is_valid():
		on_closed.call()
	elif ctl.run.phase == RunState.Phase.BETTING:
		_set_state(UiState.BETTING)


func _open_shop() -> void:
	AudioBus.play_music("shop")
	GameState.autosave()
	_show_overlay(ShopOverlay.new().configure(ctl), _on_shop_closed)


func _on_shop_closed() -> void:
	ctl.leave_shop()
	GameState.autosave()
	if ctl.run.phase == RunState.Phase.EVENT:
		_open_event()
	else:
		_enter_phase()


func _open_pact() -> void:
	GameState.autosave()
	_show_overlay(PactOverlay.new().configure(ctl), _on_pact_closed)


func _on_pact_closed() -> void:
	if ctl.run.phase == RunState.Phase.GAME_OVER:
		GameState.end_run(false)
	else:
		_enter_phase()


func _open_event() -> void:
	GameState.autosave()
	_show_overlay(EventOverlay.new().configure(ctl), _enter_phase)


func _show_creditor_intro() -> void:
	_show_overlay(CreditorIntro.new().configure(ctl.db.get_entry("creditors", ctl.run.creditor_id)))


# --------------------------------------------------------------------------- Fortune


func _on_fortune_activated(card: GrigriCard) -> void:
	if state != UiState.BETTING:
		return
	var slot: int = card.uid
	var fid: String = ctl.run.fortunes[slot]
	if ctl.fortune_needs_target(fid):
		_target_fortune_slot = slot
		_set_state(UiState.TARGETING)
		EventBus.toast.emit(tr("TOAST_PICK_POCKET"), &"info")
	else:
		_use_fortune(slot, -1)


func _on_pocket_clicked(index: int) -> void:
	if state == UiState.TARGETING and _target_fortune_slot >= 0:
		_use_fortune(_target_fortune_slot, index)
		_target_fortune_slot = -1


func _use_fortune(slot: int, index: int) -> void:
	var fid: String = ctl.run.fortunes[slot]
	if ctl.use_fortune(slot, index):
		AudioBus.play("card_use")
		var pos: Vector2 = (
			wheel_view.global_position
			+ (wheel_view.pocket_screen_pos(clampi(index, 0, ctl.run.wheel.size() - 1)) if index >= 0 else wheel_view.size * 0.5)
		)
		float_layer.burst("sparks", pos, 24)
		float_layer.pop_text(Localization.name_of("fortunes", fid), pos, Palette.CYAN)
		EventBus.fortune_used.emit(fid)
		GameState.autosave()
	_set_state(UiState.BETTING)


func _on_grigris_changed() -> void:
	GameState.autosave()


# --------------------------------------------------------------------------- jus


func _on_shake(amount: float) -> void:
	_shake = maxf(_shake, JuiceProfile.shake_px(amount))


func _on_flash(color: Color, intensity: float) -> void:
	if not JuiceProfile.flashes_enabled():
		return
	_flash_rect.color = Color(color, 0.0)
	_flash = clampf(intensity, 0.0, 1.0) * JuiceProfile.FLASH_ALPHA_MAX


func _on_hitstop(duration: float) -> void:
	if JuiceProfile.intensity() <= 0.0:
		return
	var prev: float = Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration * JuiceProfile.intensity(), true, false, true).timeout
	Engine.time_scale = prev if prev > 0.05 else 1.0


func _process(delta: float) -> void:
	if _shake > 0.1:
		var rng: RandomNumberGenerator = RngService.cosmetic()
		_content.position = Vector2(rng.randf_range(-_shake, _shake), rng.randf_range(-_shake, _shake))
		_shake = lerpf(_shake, 0.0, delta * SHAKE_DECAY)
	else:
		_content.position = Vector2.ZERO
	if _flash > 0.0:
		_flash = maxf(_flash - delta * FLASH_DECAY, 0.0)
		_flash_rect.color.a = _flash
	if state == UiState.AIMING:
		_refresh_probabilities()
