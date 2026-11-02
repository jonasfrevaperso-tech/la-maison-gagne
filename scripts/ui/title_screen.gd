class_name TitleScreen
extends Control
## Écran titre. Mention obligatoire : jeu de hasard simulé, monnaie fictive.

const MENU_WIDTH: float = 420.0
const MENU_BUTTON: Vector2 = Vector2(420, 46)
const MENU_GAP: int = 6
const HERO_SIZE: float = 900.0
const HERO_POS: Vector2 = Vector2(1180, 260)
const HERO_ALPHA: float = 0.55


func setup(_params: Dictionary) -> void:
	pass


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(DecoBackground.new())
	# Roue 3D en décor (repli : image fixe si la roue 3D est désactivée).
	var hero: Control
	if Settings.b("video", "wheel_3d"):
		hero = TitleWheel.new()
	else:
		var tr_hero: TextureRect = TextureRect.new()
		tr_hero.texture = IconLibrary.sprite("title_wheel")
		tr_hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr_hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hero = tr_hero
	hero.size = Vector2(HERO_SIZE, HERO_SIZE)
	hero.position = HERO_POS
	hero.modulate = Color(1, 1, 1, HERO_ALPHA)
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero)
	var tw: Tween = hero.create_tween().set_loops()
	tw.tween_property(hero, "position:y", HERO_POS.y - 14.0, 3.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hero, "position:y", HERO_POS.y, 3.0).set_trans(Tween.TRANS_SINE)
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
	center.add_child(UiKit.spacer(14))
	var menu: VBoxContainer = VBoxContainer.new()
	menu.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu.add_theme_constant_override("separation", MENU_GAP)
	center.add_child(menu)
	var first: Button = null
	if SaveSystem.has_run():
		first = UiKit.button(tr("MENU_CONTINUE"), _on_continue, MENU_BUTTON)
		menu.add_child(first)
	var new_btn: Button = UiKit.button(tr("MENU_NEW_RUN"), _on_new, MENU_BUTTON)
	menu.add_child(new_btn)
	if first == null:
		first = new_btn
	# Entrées secondaires sur deux colonnes : le menu tient en 16:9 même avec le texte agrandi.
	var extras: Array[Array] = _extra_entries()
	if not extras.is_empty():
		var cols: GridContainer = GridContainer.new()
		cols.columns = 2
		cols.add_theme_constant_override("h_separation", MENU_GAP)
		cols.add_theme_constant_override("v_separation", MENU_GAP)
		menu.add_child(cols)
		var half: Vector2 = Vector2((MENU_BUTTON.x - float(MENU_GAP)) * 0.5, MENU_BUTTON.y)
		for i: int in range(0, extras.size()):
			cols.add_child(UiKit.button(tr(String(extras[i][0])), extras[i][1] as Callable, half))
	menu.add_child(UiKit.button(tr("MENU_QUIT"), _on_quit, MENU_BUTTON))
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
	if not Settings.b("game", "telemetry_asked") and not DevMode.active():
		_ask_telemetry.call_deferred()
	if not SaveSystem.corrupted_files.is_empty():
		EventBus.toast.emit.call_deferred(tr("TOAST_BACKUP_USED"), &"info")
		SaveSystem.corrupted_files.clear()


## Consentement à la télémétrie locale (demandé une seule fois, modifiable dans les options).
func _ask_telemetry() -> void:
	var dlg: ConfirmBox = ConfirmBox.new().configure(tr("CONFIRM_TELEMETRY"))
	dlg.confirmed.connect(_set_telemetry.bind(true))
	dlg.declined.connect(_set_telemetry.bind(false))
	add_child(dlg)


func _set_telemetry(on: bool) -> void:
	Settings.set_value("game", "telemetry_asked", true)
	Settings.set_value("game", "telemetry", on)


## Entrées optionnelles : n'apparaissent que si l'écran existe (développement incrémental).
func _extra_entries() -> Array[Array]:
	var out: Array[Array] = []
	var candidates: Array[Array] = [
		["MENU_DAILY", _on_daily, &"run"],
		["MENU_RACE", GameState.goto.bind(GameState.SCREEN_RACE), &"seed_race"],
		["MENU_HALL", GameState.goto.bind(GameState.SCREEN_HALL), &"hall"],
		["MENU_CODEX", GameState.goto.bind(GameState.SCREEN_CODEX), &"codex"],
		["MENU_ACHIEVEMENTS", GameState.goto.bind(GameState.SCREEN_ACHIEVEMENTS), &"achievements"],
		["MENU_STATS", GameState.goto.bind(GameState.SCREEN_STATS), &"stats"],
		["MENU_OPTIONS", GameState.goto.bind(GameState.SCREEN_OPTIONS), &"options"],
		["MENU_CREDITS", GameState.goto.bind(GameState.SCREEN_CREDITS), &"credits"],
		["MENU_PROLOGUE", GameState.goto.bind(GameState.SCREEN_INTRO, {"next": "title"}), &"intro"],
	]
	for c: Array in candidates:
		if ResourceLoader.exists(Main.SCREENS.get(c[2], "")):
			out.append([c[0], c[1]])
	return out


func _on_continue() -> void:
	if not GameState.continue_run():
		EventBus.toast.emit(tr("TOAST_SAVE_CORRUPT"), &"error")


## Nouvelle partie : si un run est sauvegardé, il est abandonné (et compté) après confirmation.
func _on_new() -> void:
	if not SaveSystem.has_run():
		GameState.goto(GameState.SCREEN_CHARACTER)
		return
	var dlg: ConfirmBox = ConfirmBox.new().configure(tr("CONFIRM_NEW_OVER_SAVE"))
	dlg.confirmed.connect(_abandon_saved_and_new)
	add_child(dlg)


func _abandon_saved_and_new() -> void:
	SaveSystem.clear_run()
	GameState.controller = null
	GameState.goto(GameState.SCREEN_CHARACTER)


func _on_daily() -> void:
	GameState.goto(GameState.SCREEN_CHARACTER, {"daily": true})


func _on_quit() -> void:
	GameState.quit_game()
