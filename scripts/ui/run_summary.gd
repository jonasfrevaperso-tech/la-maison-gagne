class_name RunSummary
extends Control
## Résumé de fin de run : verdict, causes de la défaite, statistiques, suggestions de build,
## relance en un clic (même personnage, nouvelle graine).

const CONTENT_W: float = 1400.0
const TILE_W: float = 200.0
const CARD_W: float = 640.0
const TILE_STAGGER: float = 0.12

var victory: bool = false


func setup(params: Dictionary) -> void:
	victory = bool(params.get("victory", false))


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(VenueBackdrop3D.create("victory" if victory else "defeat"))
	var veil: ColorRect = ColorRect.new()
	veil.color = Overlay.DIM_OVER_BACKDROP
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var r: RunState = GameState.run()
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.custom_minimum_size = Vector2(CONTENT_W, 0)
	v.add_theme_constant_override("separation", 18)
	add_child(v)
	var verdict: Label = UiKit.title(tr("SUMMARY_VICTORY") if victory else tr("SUMMARY_DEFEAT"), UiKit.SIZE_TITLE)
	verdict.add_theme_color_override("font_color", Palette.EMERALD if victory else Palette.GOLD_LIGHT)
	v.add_child(verdict)
	if r == null:
		v.add_child(UiKit.button(tr("MENU_BACK"), GameState.goto.bind(GameState.SCREEN_TITLE)))
		return
	var who: Label = UiKit.label(
		"%s · %s %d · %s" % [Localization.name_of("characters", r.character_id), tr("STATS_COL_RISK"), r.risk_level, tr("STATS_COL_SEED")]
		+ " " + RngService.seed_to_code(r.rng.seed_value),
		UiKit.SIZE_BODY,
		Palette.IVORY
	)
	who.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(who)
	v.add_child(UiKit.divider(CONTENT_W * 0.6))
	_verdict_anim(verdict)
	# Tuiles de statistiques (apparition en cascade).
	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_theme_constant_override("separation", 16)
	v.add_child(tiles)
	var tier_txt: String = str(r.tier if r.endless else mini(r.tier, Balance.i("run.tiers")))
	var minutes: float = Telemetry.run_seconds() / 60.0
	var data: Array[Array] = [
		["SUMMARY_T_DEADLINES", str(r.deadlines_cleared), Palette.EMERALD],
		["SUMMARY_T_TIER", tier_txt, Palette.GOLD_LIGHT],
		["SUMMARY_T_SPINS", str(r.total_spins), Palette.IVORY],
		["SUMMARY_T_BEST", Localization.format_number(float(r.best_spin)), Palette.CHIPS_BLUE],
		["SUMMARY_T_ZEROS", str(r.zeros_hit), Palette.ZERO_GREEN.lightened(0.3)],
		["SUMMARY_T_TIME", "%d min" % roundi(minutes), Palette.IVORY],
	]
	for i: int in data.size():
		var t: PanelContainer = UiKit.stat_tile(tr(String(data[i][0])), String(data[i][1]), data[i][2] as Color, TILE_W)
		tiles.add_child(t)
		_pop_in(t, i)
	# Analyse : pourquoi / pistes.
	var cards: HBoxContainer = HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 20)
	v.add_child(cards)
	if not victory:
		var why: PanelContainer = UiKit.section_card(tr("WHY_TITLE"), CARD_W, Palette.DANGER.darkened(0.3))
		(why.get_meta("body") as VBoxContainer).add_child(_rich(RunAnalysis.explain_defeat(r, DataRegistry.db)))
		cards.add_child(why)
	var tips: PanelContainer = UiKit.section_card(tr("TIP_TITLE"), CARD_W, Palette.CYAN.darkened(0.4))
	(tips.get_meta("body") as VBoxContainer).add_child(_rich(RunAnalysis.build_suggestions(r, DataRegistry.db)))
	cards.add_child(tips)
	# Build final.
	var build_card: PanelContainer = UiKit.section_card(tr("SUMMARY_BUILD"))
	build_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bar: GrigriBar = GrigriBar.new()
	(build_card.get_meta("body") as VBoxContainer).add_child(bar)
	bar.bind(r)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	# Téléphone : le build et les boutons sur une même ligne (le bilan tient en hauteur).
	if Platform.is_mobile():
		var bottom: HBoxContainer = HBoxContainer.new()
		bottom.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom.add_theme_constant_override("separation", 40)
		v.add_child(bottom)
		bottom.add_child(build_card)
		actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bottom.add_child(actions)
	else:
		v.add_child(build_card)
		v.add_child(actions)
	var again: Button = UiKit.button(tr("SUMMARY_AGAIN"), _again.bind(r.character_id, r.risk_level))
	actions.add_child(again)
	if victory and not r.endless:
		actions.add_child(UiKit.button(tr("SUMMARY_ENDLESS"), _endless))
	var back: Button = UiKit.button(tr("MENU_BACK"), _back)
	PromptBadge.attach(back, "ui_cancel")
	actions.add_child(back)
	again.call_deferred("grab_focus")
	AudioBus.play("stinger_victory" if victory else "stinger_defeat")


## Corps d'une analyse (la première ligne, son titre, devient le titre de la carte).
func _rich(bb: String) -> RichTextLabel:
	var parts: PackedStringArray = bb.split("\n", true, 1)
	var r: RichTextLabel = UiKit.rich(parts[1] if parts.size() > 1 else bb, UiKit.SIZE_SMALL)
	r.custom_minimum_size = Vector2(CARD_W - 40.0, 0)
	return r


func _verdict_anim(l: Label) -> void:
	l.pivot_offset = Vector2(CONTENT_W * 0.5, 50)
	l.scale = Vector2(1.4, 1.4)
	l.modulate.a = 0.0
	var tw: Tween = l.create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.3)


func _pop_in(c: Control, i: int) -> void:
	c.modulate.a = 0.0
	var tw: Tween = c.create_tween()
	tw.tween_interval(TILE_STAGGER * float(i + 1))
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_callback(AudioBus.ui.bind("tick"))


func _stats_text(r: RunState) -> String:
	return (
		tr("SUMMARY_STATS")
		% [
			Localization.name_of("characters", r.character_id),
			r.risk_level,
			r.tier if r.endless else mini(r.tier, Balance.i("run.tiers")),
			tr("DEADLINE_" + r.deadline_kind().to_upper()) if not victory else tr("REWARD_VICTORY"),
			r.deadlines_cleared,
			r.total_spins,
			Localization.format_number(float(r.best_spin)),
			r.zeros_hit,
			RngService.seed_to_code(r.rng.seed_value),
		]
	)


func _again(cid: String, risk: int) -> void:
	GameState.start_new_run(cid, risk, RngService.new_seed())


func _endless() -> void:
	GameState.controller.continue_endless()
	GameState.goto(GameState.SCREEN_RUN)


func _back() -> void:
	GameState.controller = null
	GameState.goto(GameState.SCREEN_TITLE)


func go_back() -> void:
	_back()
