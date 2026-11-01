class_name RunSummary
extends Control
## Résumé de fin de run : verdict, causes de la défaite, statistiques, suggestions de build,
## relance en un clic (même personnage, nouvelle graine).

var victory: bool = false


func setup(params: Dictionary) -> void:
	victory = bool(params.get("victory", false))


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DecoBackground.new())
	var r: RunState = GameState.run()
	var v: VBoxContainer = VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.custom_minimum_size = Vector2(1200, 0)
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	v.add_child(UiKit.title(tr("SUMMARY_VICTORY") if victory else tr("SUMMARY_DEFEAT"), UiKit.SIZE_TITLE))
	if r == null:
		v.add_child(UiKit.button(tr("MENU_BACK"), GameState.goto.bind(GameState.SCREEN_TITLE)))
		return
	var stats: RichTextLabel = UiKit.rich(_stats_text(r), UiKit.SIZE_BODY)
	stats.custom_minimum_size = Vector2(1200, 0)
	v.add_child(stats)
	if not victory:
		var why: RichTextLabel = UiKit.rich(RunAnalysis.explain_defeat(r, DataRegistry.db), UiKit.SIZE_BODY)
		why.custom_minimum_size = Vector2(1200, 0)
		v.add_child(why)
	var tips: RichTextLabel = UiKit.rich(RunAnalysis.build_suggestions(r, DataRegistry.db), UiKit.SIZE_BODY - 2)
	tips.custom_minimum_size = Vector2(1200, 0)
	v.add_child(tips)
	var bar: GrigriBar = GrigriBar.new()
	v.add_child(bar)
	bar.bind(r)
	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 20)
	v.add_child(actions)
	var again: Button = UiKit.button(tr("SUMMARY_AGAIN"), _again.bind(r.character_id, r.risk_level))
	actions.add_child(again)
	if victory and not r.endless:
		actions.add_child(UiKit.button(tr("SUMMARY_ENDLESS"), _endless))
	actions.add_child(UiKit.button(tr("MENU_BACK"), _back))
	again.call_deferred("grab_focus")
	AudioBus.play("stinger_victory" if victory else "stinger_defeat")


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
