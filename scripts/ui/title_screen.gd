class_name TitleScreen
extends Control
## Écran titre. Mention obligatoire : jeu de hasard simulé, monnaie fictive.

const MENU_WIDTH: float = 420.0


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DecoBackground.new())
	var center: VBoxContainer = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 12)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(center)
	var t: Label = UiKit.title(tr("GAME_TITLE"), UiKit.SIZE_TITLE)
	center.add_child(t)
	var sub: Label = UiKit.label(tr("GAME_TAGLINE"), UiKit.SIZE_H2, Palette.MAGENTA, "display")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(sub)
	center.add_child(UiKit.spacer(30))
	var menu: VBoxContainer = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", 10)
	center.add_child(menu)
	var first: Button = null
	if SaveSystem.has_run():
		first = UiKit.button(tr("MENU_CONTINUE"), _on_continue)
		menu.add_child(first)
	var new_btn: Button = UiKit.button(tr("MENU_NEW_RUN"), _on_new)
	menu.add_child(new_btn)
	if first == null:
		first = new_btn
	for entry: Array in _extra_entries():
		menu.add_child(UiKit.button(tr(String(entry[0])), entry[1] as Callable))
	menu.add_child(UiKit.button(tr("MENU_QUIT"), _on_quit))
	first.call_deferred("grab_focus")
	var disclaimer: Label = UiKit.label(tr("DISCLAIMER_SIMULATED"), UiKit.SIZE_SMALL, Palette.SMOKE)
	disclaimer.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disclaimer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	disclaimer.position.y -= 48
	add_child(disclaimer)
	var ver: Label = UiKit.label("v" + String(ProjectSettings.get_setting("application/config/version")), UiKit.SIZE_SMALL, Palette.SMOKE)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position += Vector2(-110, -40)
	add_child(ver)
	AudioBus.play_music("menu")
	if not SaveSystem.corrupted_files.is_empty():
		EventBus.toast.emit.call_deferred(tr("TOAST_BACKUP_USED"), &"info")
		SaveSystem.corrupted_files.clear()


## Entrées optionnelles : n'apparaissent que si l'écran existe (développement incrémental).
func _extra_entries() -> Array[Array]:
	var out: Array[Array] = []
	var candidates: Array[Array] = [
		["MENU_DAILY", _on_daily, &"run"],
		["MENU_HALL", GameState.goto.bind(GameState.SCREEN_HALL), &"hall"],
		["MENU_CODEX", GameState.goto.bind(GameState.SCREEN_CODEX), &"codex"],
		["MENU_ACHIEVEMENTS", GameState.goto.bind(GameState.SCREEN_ACHIEVEMENTS), &"achievements"],
		["MENU_STATS", GameState.goto.bind(GameState.SCREEN_STATS), &"stats"],
		["MENU_OPTIONS", GameState.goto.bind(GameState.SCREEN_OPTIONS), &"options"],
		["MENU_CREDITS", GameState.goto.bind(GameState.SCREEN_CREDITS), &"credits"],
	]
	for c: Array in candidates:
		if ResourceLoader.exists(Main.SCREENS.get(c[2], "")):
			out.append([c[0], c[1]])
	return out


func _on_continue() -> void:
	if not GameState.continue_run():
		EventBus.toast.emit(tr("TOAST_SAVE_CORRUPT"), &"error")


func _on_new() -> void:
	GameState.goto(GameState.SCREEN_CHARACTER)


func _on_daily() -> void:
	GameState.goto(GameState.SCREEN_CHARACTER, {"daily": true})


func _on_quit() -> void:
	get_tree().quit()
