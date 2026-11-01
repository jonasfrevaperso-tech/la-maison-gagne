class_name HallScreen
extends MetaScreen
## Le Hall : progression méta (personnages et Risque max), défis, graine du jour, fins vues.


func screen_title() -> String:
	return tr("MENU_HALL")


func build() -> void:
	var p: Dictionary = SaveSystem.profile
	section(tr("HALL_CHARACTERS"))
	var unlocked: Array = p.get("unlocked_characters", [])
	var max_risk: Dictionary = p.get("max_risk", {})
	for c: Dictionary in DataRegistry.db.list("characters"):
		var cid: String = String(c["id"])
		var txt: String
		if unlocked.has(cid):
			txt = (
				"[b]%s[/b] — %s · %s"
				% [Localization.t(c, "name"), tr("HALL_MAX_RISK") % int(max_risk.get(cid, 0)), Localization.t(c, "desc")]
			)
		else:
			txt = "[color=#6b6275]??? — %s[/color]" % tr("HALL_LOCKED_HINT")
		var r: RichTextLabel = UiKit.rich(txt, UiKit.SIZE_BODY - 2)
		r.custom_minimum_size = Vector2(1600, 0)
		content.add_child(r)
	section(tr("HALL_CHALLENGES"))
	var done: Array = p.get("challenges_done", [])
	var g: GridContainer = grid(2)
	for ch: Dictionary in DataRegistry.db.list("challenges"):
		var chid: String = String(ch["id"])
		var mark: String = "✔ " if done.has(chid) else ""
		var b: Button = UiKit.button("%s%s" % [mark, Localization.t(ch, "name")], _start_challenge.bind(chid), Vector2(360, 54))
		b.tooltip_text = Localization.t(ch, "desc")
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.add_child(b)
		var d: Label = UiKit.label(Localization.t(ch, "desc"), UiKit.SIZE_SMALL, Palette.SMOKE)
		d.custom_minimum_size = Vector2(400, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(d)
		g.add_child(row)
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


func _start_challenge(chid: String) -> void:
	var ch: Dictionary = DataRegistry.db.get_entry("challenges", chid)
	GameState.start_new_run(String(ch.get("character", "lea")), 0, RngService.new_seed(), chid)
