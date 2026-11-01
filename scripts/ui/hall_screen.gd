class_name HallScreen
extends MetaScreen
## Le Hall : progression méta (personnages et Risque max), défis, graine du jour, fins vues.


const CHAR_W: float = 276.0
const CHALLENGE_W: float = 860.0


func screen_title() -> String:
	return tr("MENU_HALL")


func build() -> void:
	var p: Dictionary = SaveSystem.profile
	section(tr("HALL_CHARACTERS"))
	var unlocked: Array = p.get("unlocked_characters", [])
	var max_risk: Dictionary = p.get("max_risk", {})
	var chars: HBoxContainer = HBoxContainer.new()
	chars.add_theme_constant_override("separation", 14)
	content.add_child(chars)
	for c: Dictionary in DataRegistry.db.list("characters"):
		chars.add_child(_character_card(c, unlocked.has(String(c["id"])), int(max_risk.get(String(c["id"]), 0))))
	section(tr("HALL_CHALLENGES"))
	var done: Array = p.get("challenges_done", [])
	var g: GridContainer = grid(2)
	g.add_theme_constant_override("h_separation", 16)
	for ch: Dictionary in DataRegistry.db.list("challenges"):
		var chid: String = String(ch["id"])
		var won: bool = done.has(chid)
		var card: PanelContainer = UiKit.section_card("", CHALLENGE_W, Palette.EMERALD.darkened(0.3) if won else Palette.GOLD_DARK)
		var body_v: VBoxContainer = card.get_meta("body") as VBoxContainer
		var h: HBoxContainer = HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		body_v.add_child(h)
		var btn: Button = UiKit.button(("✔ " if won else "") + Localization.t(ch, "name"), _start_challenge.bind(chid), Vector2(300, 52))
		h.add_child(btn)
		var d: Label = UiKit.label(Localization.t(ch, "desc"), UiKit.SIZE_SMALL, Palette.IVORY.darkened(0.1))
		d.custom_minimum_size = Vector2(CHALLENGE_W - 360.0, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(d)
		g.add_child(card)
	section(tr("HALL_DAILY"))
	var daily: Dictionary = p.get("daily", {})
	content.add_child(
		UiKit.label(tr("HALL_DAILY_BEST") % [RngService.seed_to_code(RngService.daily_seed()), int(daily.get("best", 0))], UiKit.SIZE_BODY)
	)
	content.add_child(UiKit.button(tr("MENU_DAILY"), GameState.goto.bind(GameState.SCREEN_CHARACTER, {"daily": true})))
	section(tr("HALL_ENDINGS"))
	var endings: Array = (p.get("campaign", {}) as Dictionary).get("endings", [])
	for eid: String in ["end_repay", "end_flee", "end_take", "end_secret"]:
		var seen: bool = endings.has(eid)
		content.add_child(
			UiKit.label(
				("✔ " + tr("ENDING_" + eid.substr(4).to_upper())) if seen else "✕ ???",
				UiKit.SIZE_BODY,
				Palette.GOLD_LIGHT if seen else Palette.SMOKE
			)
		)


## Carte de personnage : portrait, nom, Risque maximal atteint, capacité.
func _character_card(c: Dictionary, unlocked: bool, risk: int) -> PanelContainer:
	var card: PanelContainer = UiKit.section_card("", CHAR_W, Color(String(c.get("color", "d4af37"))) if unlocked else Palette.SMOKE_DARK)
	var v: VBoxContainer = card.get_meta("body") as VBoxContainer
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	var pv: PortraitView = PortraitView.new().configure(String(c.get("portrait", c["id"])), Color(String(c.get("color", "d4af37"))))
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.modulate = Color.WHITE if unlocked else Color(0.15, 0.13, 0.18)
	v.add_child(pv)
	var n: Label = UiKit.label(Localization.t(c, "name") if unlocked else "???", UiKit.SIZE_BODY, Palette.GOLD_LIGHT, "display")
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	var info: String = tr("HALL_MAX_RISK") % risk if unlocked else tr("HALL_LOCKED_HINT")
	var r: Label = UiKit.label(info, UiKit.SIZE_SMALL, Palette.CYAN if unlocked else Palette.SMOKE)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(CHAR_W - 36.0, 0)
	v.add_child(r)
	if unlocked:
		var d: Label = UiKit.label(Localization.t(c, "desc"), UiKit.SIZE_SMALL, Palette.IVORY.darkened(0.1))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(CHAR_W - 36.0, 0)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(d)
	card.focus_mode = Control.FOCUS_ALL  # lisible à la manette (défilement par le focus)
	return card


func _start_challenge(chid: String) -> void:
	var ch: Dictionary = DataRegistry.db.get_entry("challenges", chid)
	GameState.start_new_run(String(ch.get("character", "lea")), 0, RngService.new_seed(), chid)
