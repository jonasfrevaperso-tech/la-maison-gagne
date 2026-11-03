class_name RunScreen
extends Control
## Écran principal d'un run. Machine à états d'interface :
## PARIS → VISÉE → BILLE → (RELANCE ?) → SCORE → paris suivants / boutique / pacte / fin.
## Toute la logique passe par RunController ; cet écran ne fait que présenter et relayer.

enum UiState { BETTING, AIMING, BALL, RETHROW, SCORING, OVERLAY, TARGETING, THROWING }

const WHEEL_SIZE: Vector2 = Vector2(760, 640)
const TABLE_SIZE: Vector2 = Vector2(1040, 360)
const MARGIN: float = 28.0
const HISTORY_SHOWN: int = 14
const SHAKE_DECAY: float = 7.0
const FLASH_DECAY: float = 3.0
const HEAT_SHADER: String = "res://shaders/heat.gdshader"
const TENSION_FROM_DEBT: float = 0.6
const BG_TINT_BASE: float = 0.12
const BG_TINT_PER_PHASE: float = 0.1
const TENSION_CREDITOR: float = 0.35
const TENSION_LAST_SPIN: float = 0.35
## Décalage vertical de la ligne d'aide sous le tapis.
const HINT_OFFSET_Y: float = 106.0
const HINT_ALPHA: float = 0.72
const FORTUNE_X: float = 1500.0
const HINT_GAP: float = 16.0
const HUD_STRIP_H: float = 120.0
const BAR_CAPTION_Y: float = 30.0
## États dont l'aide commence par une phrase d'explication.
const HINT_SENTENCES: Array[String] = ["AIMING", "RETHROW", "TARGETING", "THROWING"]

var ctl: RunController = null
var state: UiState = UiState.BETTING
## Taille de la scène de référence : 1920×1080 sur PC, plus large sur téléphone (20:9).
var stage_size: Vector2 = UiLayout.DESIGN_SIZE

var wheel_view: WheelView = null
## Mini-jeu du lancer (élan, lâcher), par-dessus la roue.
var throw_game: ThrowMinigame = null
var table_view: TableView = null
var score_panel: ScorePanel = null
var debt_gauge: DebtGauge = null
var grigri_bar: GrigriBar = null
var family_strip: FamilyStrip = null
var fortune_bar: HBoxContainer = null
var float_layer: FloatLayer = null
var presenter: ScorePresenter = null
var overlay_root: Control = null
var tutorial: TutorialDirector = null
var decor: CasinoDecor = null

var _content: Control = null
## Scène de référence 1920×1080, centrée et mise à l'échelle (cf. UiLayout).
var _stage: Control = null
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
var _deferred_closes: Array[Callable] = []
var _target_fortune_slot: int = -1
var _overlay_queue: Array[Control] = []
var _victory_reward: Dictionary = {}
var _heat: ColorRect = null
## Manette : sélection dans la barre de grigris / Fortune (View) au lieu du tapis.
var _items_mode: bool = false
var _prompt_bar: PromptBar = null
var _grigri_caption: Label = null
var _fortune_caption: Label = null
## Commandes (souris, clavier, manette) selon l'état : RunScreenInput.
var _input_ctl: RunScreenInput = null
var _throw: RunScreenThrow = null
var _cards: RunScreenCards
var _curse: CurseFx = null
var _bg: Control = null
var _actions: HBoxContainer = null
var _menu_btn: Button = null
var _header_strip: Panel = null
var _trial_host: Control = null


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ctl = GameState.controller
	if Platform.is_mobile():
		stage_size = RunScreenLayoutMobile.STAGE
	_input_ctl = RunScreenInput.new(self)
	_cards = RunScreenCards.new(self)
	_throw = RunScreenThrow.new(self)
	_build()
	EventBus.juice_shake.connect(_on_shake)
	EventBus.juice_flash.connect(_on_flash)
	EventBus.juice_hitstop.connect(_on_hitstop)
	EventBus.input_device_changed.connect(_on_device_changed)
	AudioBus.play_ambience("ambience_casino")
	table_view.cursor_active = InputGlyphs.using_pad
	_enter_phase()


# --------------------------------------------------------------------------- construction


func _build() -> void:
	if Settings.b("video", "decor_3d"):
		decor = CasinoDecor.new()
		_bg = decor
	else:
		var deco: DecoBackground = DecoBackground.new()
		deco.origin_ratio = Vector2(0.3, 0.55)
		_bg = deco
	add_child(_bg)
	_content = Control.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_stage = Control.new()
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_stage)
	if decor != null:
		decor.stage = _stage
	_fit_stage()
	resized.connect(_fit_stage)
	RunScreenLayout.build_header(self)
	# Roue
	wheel_view = WheelView.new()
	wheel_view.position = Vector2(MARGIN, 150)
	wheel_view.size = WHEEL_SIZE
	wheel_view.setup(ctl.run.wheel, ctl.db)
	wheel_view.ball_settled.connect(_on_ball_settled)
	wheel_view.pocket_clicked.connect(_on_pocket_clicked)
	_stage.add_child(wheel_view)
	_stage.move_child(wheel_view, 0)
	throw_game = ThrowMinigame.new()
	throw_game.set_anchors_preset(Control.PRESET_TOP_LEFT)
	throw_game.position = wheel_view.position
	throw_game.size = WHEEL_SIZE
	throw_game.finished.connect(func(q: float) -> void: _throw.on_quality(q))
	throw_game.hold = func() -> bool: return tutorial != null and tutorial.blocking()
	_stage.add_child(throw_game)
	_history_box = HBoxContainer.new()
	_history_box.position = Vector2(MARGIN, 150 + WHEEL_SIZE.y + 6)
	_history_box.add_theme_constant_override("separation", 4)
	_stage.add_child(_history_box)
	# Score
	score_panel = ScorePanel.new()
	score_panel.position = Vector2(1000, 140)
	_stage.add_child(score_panel)
	# Tapis
	table_view = TableView.new()
	table_view.position = Vector2(840, 360)
	table_view.size = TABLE_SIZE
	table_view.spot_changed.connect(_on_spot_changed)
	table_view.spot_hovered.connect(_on_spot_hovered)
	_stage.add_child(table_view)
	RunScreenLayout.build_actions(self)
	# Grigris et Fortune
	grigri_bar = GrigriBar.new()
	grigri_bar.position = Vector2(MARGIN, UiLayout.DESIGN_SIZE.y - GrigriCard.CARD_SIZE.y - MARGIN)
	grigri_bar.changed.connect(_on_grigris_changed)
	_stage.add_child(grigri_bar)
	_grigri_caption = UiKit.label("", UiKit.SIZE_SMALL, Palette.GOLD, "display")
	_grigri_caption.position = grigri_bar.position - Vector2(0, BAR_CAPTION_Y)
	_stage.add_child(_grigri_caption)
	_grigri_caption.resized.connect(RunScreenLayout.seat_caption.bind(_grigri_caption, grigri_bar))
	# Familles (builds) : pastilles à droite du titre des grigris.
	family_strip = FamilyStrip.new()
	_stage.add_child(family_strip)
	_grigri_caption.resized.connect(RunScreenLayout.seat_family_strip.bind(family_strip, _grigri_caption))
	fortune_bar = HBoxContainer.new()
	fortune_bar.add_theme_constant_override("separation", 10)
	fortune_bar.position = Vector2(FORTUNE_X, UiLayout.DESIGN_SIZE.y - GrigriCard.CARD_SIZE.y - MARGIN)
	_stage.add_child(fortune_bar)
	_fortune_caption = UiKit.label("", UiKit.SIZE_SMALL, Palette.CYAN, "display")
	_fortune_caption.position = fortune_bar.position - Vector2(0, BAR_CAPTION_Y)
	_stage.add_child(_fortune_caption)
	_fortune_caption.resized.connect(RunScreenLayout.seat_caption.bind(_fortune_caption, fortune_bar))
	# Écrans dédiés des épreuves du lancer : au-dessus de tout le plateau.
	var trial_host: Control = Control.new()
	trial_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trial_host.size = UiLayout.DESIGN_SIZE
	trial_host.position.x = (stage_size.x - UiLayout.DESIGN_SIZE.x) * 0.5
	_stage.add_child(trial_host)
	_trial_host = trial_host
	throw_game.full_host = trial_host
	# Couches d'effets (malus visuels des grigris sous les textes flottants)
	_curse = CurseFx.new()
	add_child(_curse)
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
	presenter.family_strip = family_strip
	presenter.wheel_view = wheel_view
	presenter.table_view = table_view
	presenter.finished.connect(_on_score_finished)
	add_child(presenter)
	tutorial = TutorialDirector.new()
	tutorial.anchor_rect = _anchor_rect
	add_child(tutorial)
	if Platform.is_mobile():
		RunScreenLayoutMobile.apply(self)


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
	family_strip.bind(r)
	_grigri_caption.text = tr("SHOP_OWNED").to_upper() + "  %d / %d" % [r.grigris.size(), r.grigri_slots]
	_refresh_fortunes()
	_fortune_caption.text = tr("HUD_FORTUNE").to_upper() + "  %d / %d" % [r.fortunes.size(), r.fortune_slots]
	_refresh_table()
	_refresh_probabilities()
	_speed_btn.text = "×%d" % int(Settings.speed())
	# Musique adaptative : la tension monte avec la dette remboursée et face aux créanciers.
	var tension: float = clampf(float(r.deadline_score) / maxf(float(r.debt), 1.0), 0.0, 1.0) * TENSION_FROM_DEBT
	if r.is_creditor() and r.creditor_id != "":
		tension += TENSION_CREDITOR
	if r.spins_left <= 1:
		tension += TENSION_LAST_SPIN
	AudioBus.set_intensity(tension)


func _refresh_budget() -> void:
	var r: RunState = ctl.run
	_budget_label.text = tr("HUD_BUDGET") % [r.slip.total(), r.slip.budget]
	if table_view != null and table_view.bet_amount > 1:
		_budget_label.text += InputGlyphs.SEP + tr("HUD_AMOUNT") % table_view.bet_amount


func _refresh_amount() -> void:
	_refresh_budget()


func _refresh_table() -> void:
	var r: RunState = ctl.run
	table_view.slip = r.slip
	table_view.wheel = r.wheel
	table_view.chip_value = r.chip_value
	table_view.hide_odds = bool(r.flags.get("hide_odds", false)) or bool(r.flags.get("hide_odds_always", false))
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
	var throwing: bool = state == UiState.AIMING or state == UiState.THROWING
	_spin_btn.disabled = (not (betting and ctl.can_spin()) and not throwing) or state == UiState.THROWING
	_spin_btn.text = tr("BTN_SPIN")
	if state == UiState.AIMING:
		_spin_btn.text = tr("BTN_RELEASE") if RunScreenThrow.simple_throw() else tr("BTN_AIM_LOCK")
	elif state == UiState.THROWING:
		_spin_btn.text = tr("BTN_STRIKE")
	_undo_btn.disabled = not betting or r.slip.history.is_empty()
	_repeat_btn.disabled = not betting or r.last_layout.is_empty()
	_clear_btn.disabled = not betting or r.slip.is_empty()
	var rethrow: bool = state == UiState.RETHROW
	_rethrow_btn.visible = rethrow
	_keep_btn.visible = rethrow
	# La rangée d'actions tient dans le tapis : pendant une relance, les boutons de mise s'effacent.
	for b: Button in [_undo_btn, _repeat_btn, _clear_btn]:
		b.visible = not rethrow
	_refresh_hint()


## Invites de l'état courant (périphérique actif seulement) et phrase d'explication éventuelle.
func _refresh_hint() -> void:
	var state_name: String = UiState.keys()[state]
	var key: String = "ITEMS" if _items_mode else state_name
	if key == "BETTING":
		key = "BETTING_PAD" if InputGlyphs.using_pad else "BETTING_KEYS"
	var items: Array[Array] = []
	items.assign(RunScreenInput.PROMPTS.get(key, []))
	_prompt_bar.set_items(items)
	_hint_label.text = tr("HINT_" + state_name) if state_name in HINT_SENTENCES else ""


func _refresh_probabilities() -> void:
	var r: RunState = ctl.run
	var show: bool = bool(r.flags.get("show_probabilities", false)) or Settings.b("game", "show_probabilities")
	if show and state == UiState.AIMING:
		wheel_view.probabilities = ctl.landing_distribution(wheel_view.aim_index)
	else:
		wheel_view.probabilities = []
	wheel_view.zone_width = ThrowResolver.zone_width_for(ctl.effective_precision(), int(r.flags.get("zone_width_override", 0)))


func _refresh_heat() -> void:
	var r: RunState = ctl.run
	var hot: bool = r.is_creditor() and (r.creditor_id == "cr_pyromane" or (r.creditor_id == "cr_la_maison" and r.creditor_phase >= 2))
	hot = hot or r.challenge_id == "ch_blaze"
	if hot and _heat == null and JuiceProfile.intensity() > 0.0 and not Settings.b("juice", "reduced_motion"):
		_heat = ColorRect.new()
		_heat.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_heat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var m: ShaderMaterial = ShaderMaterial.new()
		m.shader = load(HEAT_SHADER) as Shader
		_heat.material = m
		add_child(_heat)
		move_child(_heat, 1)
	elif not hot and _heat != null:
		_heat.queue_free()
		_heat = null


func _refresh_creditor() -> void:
	_refresh_heat()
	var tint: Color = Color(1, 1, 1, 0)
	if ctl.run.is_creditor() and ctl.run.creditor_id != "":
		tint = Color(String(ctl.db.get_entry("creditors", ctl.run.creditor_id).get("color", "ff2e88")))
		tint.a = BG_TINT_BASE + BG_TINT_PER_PHASE * float(ctl.run.creditor_phase)
	_bg.call("set_tint", tint)
	var r: RunState = ctl.run
	var active: bool = r.creditor_id != "" and r.is_creditor()
	var cdef: Dictionary = ctl.db.get_entry("creditors", r.creditor_id) if active else {}
	# Créanciers de roue : rotation inversée, visée accélérée.
	wheel_view.direction = -1.0 if bool(cdef.get("wheel_reverse", false)) else 1.0
	wheel_view.aim_speed_mult = float(cdef.get("aim_speed_mult", 1.0))
	if not active:
		_creditor_label.text = ""
		return
	var c: Dictionary = cdef
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
		card.action_text = tr("CARD_USE")
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
			_queue_intros()
			if state == UiState.BETTING:
				_tutorial_betting()
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


## Enchaîne titre d'acte, dialogue d'ouverture, aide du premier tour et entrée du créancier.
func _queue_intros() -> void:
	var r: RunState = ctl.run
	if r.spin_index != 0:
		return
	var act_key: String = "act_intro_seen_%d" % r.act()
	var first_tier_of_act: bool = int((Balance.arr("run.acts")[r.act() - 1] as Array)[0]) == r.tier
	if r.deadline_idx == 0 and first_tier_of_act and not r.flags.has(act_key):
		r.flags[act_key] = true
		_queue(ActTitle.new().configure(r.act()))
		var dlg_id: String = "act%d_intro" % r.act()
		if ctl.db.has_entry("dialogues", dlg_id):
			_queue(DialogueOverlay.new().configure(dlg_id, r, ctl.db))
	# Interlude au deuxième palier de chaque acte (scénario entre deux créanciers).
	var mid_key: String = "act_mid_seen_%d" % r.act()
	var tiers: Array = Balance.arr("run.acts")[r.act() - 1] as Array
	if r.deadline_idx == 0 and tiers.size() > 1 and int(tiers[1]) == r.tier and not r.flags.has(mid_key):
		r.flags[mid_key] = true
		var mid_id: String = "act%d_mid" % r.act()
		if ctl.db.has_entry("dialogues", mid_id):
			_queue(DialogueOverlay.new().configure(mid_id, r, ctl.db))
	if r.is_creditor() and r.creditor_id != "":
		_queue(CreditorIntro.new().configure(ctl.db.get_entry("creditors", r.creditor_id)))


func _exit_tree() -> void:
	for o: Control in _overlay_queue:
		o.free()
	_overlay_queue.clear()


## Rectangle global d'un élément d'interface pour ancrer les bulles d'aide.
func _anchor_rect(anchor: String) -> Rect2:
	var c: Control = (
		{
			"debt": debt_gauge,
			"table": table_view,
			"budget": _budget_label,
			"spin": _spin_btn,
			"wheel": wheel_view,
			"score": score_panel,
			"history": _history_box,
			"grigris": grigri_bar,
			"fortunes": fortune_bar,
			"creditor": _creditor_label,
		}
		. get(anchor, null)
	)
	if c == null:
		var me: Rect2 = UiLayout.canvas_rect(self)
		return Rect2(me.position + me.size * Vector2(0.5, 0.15), Vector2.ZERO)
	return UiLayout.canvas_rect(c)


func _fit_stage() -> void:
	UiLayout.fit_stage(_stage, size, stage_size)


## Moments de jeu signalés au tutoriel une fois les surcouches fermées.
func _tutorial_betting() -> void:
	tutorial.notify("betting_start")
	var r: RunState = ctl.run
	if not r.grigris.is_empty():
		tutorial.notify("grigri_owned")
		tutorial.notify("family_owned")
	if not VisualCurse.strengths(r, ctl.db).is_empty():
		tutorial.notify("curse_owned")
	if r.total_spins >= 2:
		tutorial.notify("second_round")
	if not r.fortunes.is_empty():
		tutorial.notify("fortune_owned")
	if r.is_creditor() and r.creditor_id != "":
		tutorial.notify("creditor")


func _queue(o: Control) -> void:
	_overlay_queue.append(o)
	if state != UiState.OVERLAY:
		_show_next_queued()


func _show_next_queued() -> void:
	if _overlay_queue.is_empty():
		return
	var o: Control = _overlay_queue.pop_front()
	_show_overlay(o)


func _music_for() -> String:
	var r: RunState = ctl.run
	if r.is_creditor() and r.creditor_id != "":
		return "boss"
	return ["act1", "act2", "act3"][clampi(r.act() - 1, 0, 2)]


func _set_state(s: UiState) -> void:
	if s == UiState.BETTING and state != UiState.BETTING:
		Telemetry.betting_started()
	state = s
	if s != UiState.BETTING:
		_cards.hide_bet()
	var fx_phase: StringName = &"throw" if s == UiState.THROWING else (&"ball" if s == UiState.BALL else &"none")
	if _curse != null:
		_curse.set_phase(fx_phase, ctl.run, ctl.db)
	_refresh_all()


# --------------------------------------------------------------------------- entrées


func _unhandled_input(event: InputEvent) -> void:
	if state == UiState.OVERLAY:
		return
	if _input_ctl.handle(event):
		get_viewport().set_input_as_handled()


## Manette : le curseur du tapis est toujours visible ; clavier/souris : il disparaît.
func _on_device_changed(pad: bool) -> void:
	if pad:
		table_view.cursor_active = true
	else:
		table_view.cursor_active = false
		_cards.hide_bet()
	table_view.queue_redraw()
	if not pad and _items_mode:
		_input_ctl.set_items_mode(false)
	_refresh_hint()


## Le navigateur manette ne force le focus que dans le mode « objets » (le tapis a son curseur).
func wants_pad_focus() -> bool:
	return _items_mode


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
			table_view.pop_chip(spot_id)
			tutorial.notify("bet_placed")
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


func _on_spot_hovered(spot_id: String) -> void:
	if not (table_view.cursor_active or table_view.touch_aiming) or spot_id == "":
		return
	_cards.show_bet(spot_id)


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
			tutorial.notify("aiming")
		UiState.AIMING:
			_throw.release()
		UiState.THROWING:
			throw_game.press()


func _on_ball_settled(landing: int) -> void:
	_throw.announce(ctl.pending_throw, landing)
	tutorial.notify("ball")
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
	Telemetry.before_spin(ctl.run)
	var outcome: RunController.SpinOutcome = ctl.commit_spin()
	_pending_outcome = outcome
	Telemetry.after_spin(ctl.run, outcome)
	GameState.record_spin(outcome)
	table_view.flash_winners(outcome.ctx.landing_numbers)
	presenter.debt_remaining = maxi(ctl.run.debt - (ctl.run.deadline_score - outcome.ctx.total), 1)
	presenter.jackpot = outcome.jackpot
	# La logique a déjà avancé : on fige l'affichage (mises posées, jauge) le temps du score.
	var shown: BetSlip = BetSlip.new()
	shown.budget = 1 << 20
	shown.apply_layout(outcome.ctx.slip)
	table_view.slip = shown
	table_view.queue_redraw()
	state = UiState.SCORING
	_refresh_buttons()
	tutorial.notify("scoring")
	presenter.play(outcome.ctx)


func _on_score_finished(total: int) -> void:
	var out: RunController.SpinOutcome = _pending_outcome
	# Jackpot : la machine à sous d'abord (gains déjà appliqués par le cœur), puis la suite.
	if out != null and out.jackpot and not out.slot.is_empty():
		# Toute première machine à sous : Lucette se présente d'abord.
		if _story_once("slot_intro", _on_score_finished.bind(total)):
			return
		var spins: Array[Dictionary] = out.slot
		out.slot = []
		_refresh_all()
		_show_overlay(SlotOverlay.new().configure(spins, ctl.db), _on_score_finished.bind(total))
		tutorial.notify("jackpot")
		return
	_pending_outcome = null
	SaveSystem.max_stat("best_spin", out.ctx.total)
	_refresh_all()
	if out.forgiven:
		EventBus.toast.emit(tr("TOAST_FORGIVEN"), &"success")
	if out.victory:
		_victory_reward = out.reward
		_show_overlay(DialogueOverlay.new().configure("finale", ctl.run, ctl.db), _on_finale_closed)
		return
	if out.deadline_won:
		AudioBus.play("deadline_won")
		float_layer.burst_3d(UiLayout.canvas_point(_stage, Vector2(stage_size.x * 0.5, 120)), JuiceProfile.COINS_3D_DEADLINE, true)
		EventBus.subtitle.emit(tr("SUB_DEADLINE_WON"))
		if bool(ctl.run.flags.get("act_changed", false)):
			var outro: String = "act%d_creditor_won" % (ctl.run.act() - 1)
			if ctl.db.has_entry("dialogues", outro):
				var reward: Dictionary = out.reward
				_show_overlay(DialogueOverlay.new().configure(outro, ctl.run, ctl.db), _show_reward.bind(reward))
				return
		_show_overlay(RewardOverlay.new().configure(out.reward, false), _on_reward_closed)
		return
	if out.deadline_failed:
		AudioBus.play("deadline_failed")
		EventBus.subtitle.emit(tr("SUB_DEADLINE_FAILED"))
		if ctl.run.phase == RunState.Phase.PACT_OFFER:
			_open_pact()
		else:
			GameState.end_run(false)
		return
	GameState.autosave()
	_set_state(UiState.BETTING)
	tutorial.notify("scored")
	_tutorial_betting()


func _on_reward_closed() -> void:
	_open_shop()


func _show_reward(reward: Dictionary) -> void:
	_show_overlay(RewardOverlay.new().configure(reward, false), _on_reward_closed)


func _on_finale_closed() -> void:
	var ending: String = String(ctl.run.flags.get("ending", "end_repay"))
	ctl.run.flags["ending"] = ending
	_show_overlay(DialogueOverlay.new().configure("ending_" + ending.substr(4), ctl.run, ctl.db), _on_ending_closed)


func _on_ending_closed() -> void:
	_show_overlay(RewardOverlay.new().configure(_victory_reward, true), _on_victory_closed)


func _on_victory_closed() -> void:
	GameState.end_run(true)


# --------------------------------------------------------------------------- surcouches


func _show_overlay(o: Control, on_closed: Callable = Callable()) -> void:
	state = UiState.OVERLAY
	# Fiches flottantes (pari, case) : jamais par-dessus une surcouche.
	_cards.hide_bet()
	_cards.show_pocket(-1)
	overlay_root.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_root.add_child(o)
	if o.has_signal("closed"):
		o.connect("closed", _on_overlay_closed.bind(o, on_closed), CONNECT_ONE_SHOT)


func _on_overlay_closed(o: Control, on_closed: Callable) -> void:
	o.queue_free()
	overlay_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state = UiState.BETTING
	if on_closed.is_valid():
		_deferred_closes.append(on_closed)
	if not _overlay_queue.is_empty():
		_show_next_queued()
		return
	if not _deferred_closes.is_empty():
		# Les suites des surcouches fermées passent après la file d'attente, dans l'ordre.
		var next: Callable = _deferred_closes.pop_front()
		next.call()
	elif ctl.run.phase == RunState.Phase.BETTING:
		_set_state(UiState.BETTING)
	if state == UiState.BETTING:
		_tutorial_betting()


func _open_shop() -> void:
	AudioBus.play_music("shop")
	if _story_once("shop_intro", _open_shop):
		return
	Telemetry.shop_opened(ctl.run)
	GameState.autosave()
	_show_overlay(ShopOverlay.new().configure(ctl), _on_shop_closed)
	tutorial.notify("shop")


## Scène racontée une seule fois par profil avant une nouveauté (boutique, machine à sous,
## pacte). Renvoie vrai si la scène est jouée : `then` reprend ensuite le déroulé normal.
func _story_once(dlg_id: String, then: Callable) -> bool:
	if DialogueOverlay.seen(dlg_id) or not ctl.db.has_entry("dialogues", dlg_id):
		return false
	_show_overlay(DialogueOverlay.new().configure(dlg_id, ctl.run, ctl.db), then)
	return true


func _on_shop_closed() -> void:
	Telemetry.shop_closed(ctl.run)
	ctl.leave_shop()
	GameState.autosave()
	if ctl.run.phase == RunState.Phase.EVENT:
		_open_event()
	else:
		_enter_phase()


func _open_pact() -> void:
	GameState.autosave()
	if _story_once("pact_intro", _open_pact):
		return
	_show_overlay(PactOverlay.new().configure(ctl), _on_pact_closed)
	tutorial.notify("pact")


func _on_pact_closed() -> void:
	if ctl.run.phase == RunState.Phase.GAME_OVER:
		GameState.end_run(false)
	else:
		_enter_phase()


func _open_event() -> void:
	GameState.autosave()
	_show_overlay(EventOverlay.new().configure(ctl), _enter_phase)


# --------------------------------------------------------------------------- Fortune


func _on_fortune_activated(card: GrigriCard) -> void:
	if state != UiState.BETTING:
		return
	var slot: int = card.uid
	var fid: String = ctl.run.fortunes[slot]
	if _items_mode:
		_input_ctl.set_items_mode(false)
	if ctl.fortune_needs_target(fid):
		_target_fortune_slot = slot
		_set_state(UiState.TARGETING)
		if InputGlyphs.using_pad:
			_input_ctl.move_target(0, ctl.run.wheel.size())
		EventBus.toast.emit(tr("TOAST_PICK_POCKET"), &"info")
	else:
		_use_fortune(slot, -1)


func _on_pocket_clicked(index: int) -> void:
	if state == UiState.TARGETING and _target_fortune_slot >= 0:
		_use_fortune(_target_fortune_slot, index)
		_target_fortune_slot = -1
		wheel_view.hover_index = -1
		_cards.show_pocket(-1)


func _use_fortune(slot: int, index: int) -> void:
	var fid: String = ctl.run.fortunes[slot]
	if ctl.use_fortune(slot, index):
		AudioBus.play("card_use")
		var local: Vector2 = wheel_view.pocket_screen_pos(clampi(index, 0, ctl.run.wheel.size() - 1)) if index >= 0 else wheel_view.size * 0.5
		var pos: Vector2 = UiLayout.canvas_point(wheel_view, local)
		float_layer.burst("sparks", pos, 24)
		float_layer.pop_text(Localization.name_of("fortunes", fid), pos, Palette.CYAN)
		EventBus.fortune_used.emit(fid)
		GameState.autosave()
	_set_state(UiState.BETTING)
	tutorial.notify("scored")
	_tutorial_betting()


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
