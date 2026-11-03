class_name RunScreenLayout
extends RefCounted
## Construction de la barre du haut et de la rangée d'actions de l'écran de run (extrait de
## RunScreen), plus les petits recalages quand la taille du texte change.


static func build_header(s: RunScreen) -> void:
	# Barre du haut, sur un bandeau.
	var strip: Panel = Panel.new()
	strip.position = Vector2(RunScreen.MARGIN * 0.4, 6)
	strip.size = Vector2(UiLayout.DESIGN_SIZE.x - RunScreen.MARGIN * 0.8 - 80.0, RunScreen.HUD_STRIP_H)
	strip.add_theme_stylebox_override("panel", UiKit.flat(Color(Palette.INK, 0.72), Palette.GOLD_DARK, 2, 10, 0))
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s._stage.add_child(strip)
	s._header_strip = strip
	var top: HBoxContainer = HBoxContainer.new()
	top.position = Vector2(RunScreen.MARGIN, RunScreen.MARGIN * 0.6)
	top.add_theme_constant_override("separation", 26)
	s._stage.add_child(top)
	s._title_label = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "display")
	top.add_child(s._title_label)
	s.debt_gauge = DebtGauge.new()
	top.add_child(s.debt_gauge)
	s._money_label = UiKit.label("", UiKit.SIZE_H2, Palette.GOLD_LIGHT, "mono")
	top.add_child(s._money_label)
	s._budget_label = UiKit.label("", UiKit.SIZE_BODY, Palette.IVORY, "mono")
	top.add_child(s._budget_label)
	s._info_label = UiKit.rich("", UiKit.SIZE_BODY - 2)
	s._info_label.position = Vector2(RunScreen.MARGIN, 92)
	s._info_label.custom_minimum_size = Vector2(760, 0)
	s._stage.add_child(s._info_label)
	s._creditor_label = UiKit.rich("", UiKit.SIZE_BODY - 2)
	s._creditor_label.position = Vector2(820, 92)
	s._creditor_label.custom_minimum_size = Vector2(1060, 0)
	s._stage.add_child(s._creditor_label)
	# Grande police : la ligne d'infos descend sous la barre du haut au lieu de la chevaucher.
	top.resized.connect(func() -> void:
		var y: float = maxf(92.0, top.position.y + top.size.y + 2.0)
		s._info_label.position.y = y
		s._creditor_label.position.y = y)


static func build_actions(s: RunScreen) -> void:
	# Actions
	var actions: HBoxContainer = HBoxContainer.new()
	actions.position = Vector2(840, 360 + RunScreen.TABLE_SIZE.y + 22)
	actions.add_theme_constant_override("separation", 10)
	s._stage.add_child(actions)
	s._actions = actions
	var small: Vector2 = Vector2(150, 54)
	s._undo_btn = UiKit.button(s.tr("BTN_UNDO"), s._on_undo, small)
	s._repeat_btn = UiKit.button(s.tr("BTN_REPEAT"), s._on_repeat, small)
	s._clear_btn = UiKit.button(s.tr("BTN_CLEAR"), s._on_clear, small)
	s._speed_btn = UiKit.button("", s._on_speed, Vector2(90, 54))
	s._spin_btn = UiKit.button(s.tr("BTN_SPIN"), s._on_spin_pressed, Vector2(260, 64))
	s._spin_btn.add_theme_font_size_override("font_size", UiKit.SIZE_H2)
	s._rethrow_btn = UiKit.button(s.tr("BTN_RETHROW"), s._on_rethrow, Vector2(220, 64))
	s._keep_btn = UiKit.button(s.tr("BTN_KEEP"), s._on_keep, Vector2(180, 64))
	for b: Button in [s._undo_btn, s._repeat_btn, s._clear_btn, s._speed_btn, s._spin_btn, s._rethrow_btn, s._keep_btn]:
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		actions.add_child(b)
	s._rethrow_btn.visible = false
	s._keep_btn.visible = false
	# Boutons actionnés par raccourci : jamais de focus (sinon A / Espace les déclencheraient en double).
	var badges: Dictionary = {
		s._undo_btn: "bet_undo",
		s._repeat_btn: "bet_repeat",
		s._clear_btn: "bet_clear",
		s._speed_btn: "speed_toggle",
		s._spin_btn: "ui_spin",
		s._rethrow_btn: "ui_spin",
		s._keep_btn: "skip_anim",
	}
	for b: Button in badges.keys():
		b.focus_mode = Control.FOCUS_NONE
		PromptBadge.attach(b, String(badges[b]))
	var menu_btn: Button = UiKit.button("☰", s._on_menu, Vector2(64, 54))
	menu_btn.focus_mode = Control.FOCUS_NONE
	PromptBadge.attach(menu_btn, "pause_menu")
	menu_btn.position = Vector2(UiLayout.DESIGN_SIZE.x - RunScreen.MARGIN - 64, RunScreen.MARGIN * 0.5)
	s._stage.add_child(menu_btn)
	s._menu_btn = menu_btn
	# Aide aux commandes : invites du périphérique actif (glyphes manette ou touches), sans débordement.
	s._prompt_bar = PromptBar.new()
	s._prompt_bar.position = Vector2(840, 360 + RunScreen.TABLE_SIZE.y + RunScreen.HINT_OFFSET_Y)
	# Jusqu'à la barre de Fortune seulement (grande police : jamais par-dessus sa légende).
	s._prompt_bar.max_width = RunScreen.FORTUNE_X - 840.0 - RunScreen.HINT_GAP
	s._prompt_bar.size = Vector2(s._prompt_bar.max_width, InputGlyphs.PROMPT_H + 6)
	s._stage.add_child(s._prompt_bar)
	s._hint_label = UiKit.label("", UiKit.SIZE_SMALL, Palette.IVORY)
	s._hint_label.modulate.a = RunScreen.HINT_ALPHA
	s._hint_label.position = Vector2(840, 360 + RunScreen.TABLE_SIZE.y + RunScreen.HINT_OFFSET_Y + InputGlyphs.PROMPT_H + 10)
	# Jusqu'à la barre de Fortune (à droite) seulement, sur deux lignes au plus.
	s._hint_label.size = Vector2(RunScreen.FORTUNE_X - 840.0 - RunScreen.HINT_GAP, 0)
	s._hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	s._hint_label.max_lines_visible = 2
	s._hint_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s._stage.add_child(s._hint_label)
	actions.resized.connect(place_hints.bind(s, actions))


## L'aide aux commandes suit la hauteur réelle de la rangée d'actions (grande police comprise).
static func place_hints(s: RunScreen, actions: Control) -> void:
	if Platform.is_mobile():
		return  # RunScreenLayoutMobile place l'aide lui-même
	var y: float = maxf(actions.position.y + actions.size.y + RunScreen.HINT_GAP * 0.5, 360 + RunScreen.TABLE_SIZE.y + RunScreen.HINT_OFFSET_Y)
	s._prompt_bar.position.y = y
	s._hint_label.position.y = y + InputGlyphs.PROMPT_H + 10


## Légende posée juste au-dessus de sa barre, quelle que soit la taille du texte.
## Pastilles des familles : sur la ligne du titre des grigris, juste après lui.
static func seat_family_strip(strip: Control, cap: Control) -> void:
	strip.position = Vector2(cap.position.x + cap.size.x + 14.0, cap.position.y + (cap.size.y - FamilyChip.SIZE.y) * 0.5)


static func seat_caption(cap: Control, bar: Control) -> void:
	cap.position.y = bar.position.y - maxf(RunScreen.BAR_CAPTION_Y, cap.size.y + 2.0)
