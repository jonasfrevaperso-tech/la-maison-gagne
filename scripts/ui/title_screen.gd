class_name TitleScreen
extends Control
## Écran titre. Mention obligatoire : jeu de hasard simulé, monnaie fictive.

const MENU_WIDTH: float = 720.0
const MENU_BUTTON: Vector2 = Vector2(720, 52)
const GRID_COLS: int = 3
const MENU_GAP: int = 8
const PANEL_POS: Vector2 = Vector2(110, 90)
const TIP_SECONDS: float = 9.0
const TIPS: Array[String] = [
	"TIP_COLOR", "TIP_COPY", "TIP_ECONOMY", "TIP_NEED_XMULT", "TIP_OUTSIDE", "TIP_PRECISION",
	"TIP_RETRIGGER", "TIP_STRAIGHT", "TIP_STREAK", "TIP_ZERO",
]

var _tip: Label = null
var _tip_i: int = 0


func setup(_params: Dictionary) -> void:
	pass


## Écran titre 1.5.2 : la grande salle abandonnée en 3D (repli 2D si la 3D est coupée), un voile
## sombre à gauche pour la lisibilité, le menu en colonne (titre néon, reprise avec résumé de la
## partie, entrées principales, grille des autres écrans), une astuce qui défile en bas à droite.
func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if Settings.b("video", "wheel_3d"):
		add_child(TitleHall3D.new())
	else:
		add_child(DecoBackground.new())
	add_child(_veil())
	var col: VBoxContainer = VBoxContainer.new()
	col.position = PANEL_POS
	col.custom_minimum_size = Vector2(MENU_WIDTH, 0)
	col.add_theme_constant_override("separation", MENU_GAP)
	add_child(col)
	var t: Label = UiKit.title(tr("GAME_TITLE"), UiKit.SIZE_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(t)
	var sub: Label = UiKit.label(tr("GAME_TAGLINE"), UiKit.SIZE_H2, Palette.MAGENTA, "display")
	col.add_child(sub)
	var div: DecoDivider = UiKit.divider(MENU_WIDTH, Palette.GOLD_DARK)
	col.add_child(div)
	col.add_child(UiKit.spacer(6))
	var first: Button = null
	if SaveSystem.has_run():
		first = UiKit.button(tr("MENU_CONTINUE"), _on_continue, Vector2(MENU_WIDTH, 62))
		col.add_child(first)
		var info: String = _run_summary()
		if info != "":
			var lbl: Label = UiKit.label(info, UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(lbl)
	var new_btn: Button = UiKit.button(tr("MENU_NEW_RUN"), _on_new, MENU_BUTTON)
	col.add_child(new_btn)
	if first == null:
		first = new_btn
	# Entrées secondaires (et Quitter) sur trois colonnes : le menu tient en 16:9 et en 16:10
	# même avec le texte agrandi.
	var extras: Array[Array] = _extra_entries()
	extras.append(["MENU_QUIT", _on_quit])
	var grid: GridContainer = GridContainer.new()
	grid.columns = GRID_COLS
	grid.add_theme_constant_override("h_separation", MENU_GAP)
	grid.add_theme_constant_override("v_separation", MENU_GAP)
	col.add_child(grid)
	var cell: Vector2 = Vector2((MENU_WIDTH - float(MENU_GAP) * float(GRID_COLS - 1)) / float(GRID_COLS), 48)
	for i: int in range(0, extras.size()):
		var b: Button = UiKit.button(tr(String(extras[i][0])), extras[i][1] as Callable, cell)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		grid.add_child(b)
	first.call_deferred("grab_focus")
	# Entrée en scène : la colonne glisse depuis la gauche.
	col.modulate.a = 0.0
	var tw: Tween = col.create_tween().set_parallel()
	tw.tween_property(col, "modulate:a", 1.0, 0.6)
	tw.tween_property(col, "position:x", PANEL_POS.x, 0.6).from(PANEL_POS.x - 60.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_add_footer()
	AudioBus.play_music("menu")
	if not Settings.b("game", "telemetry_asked") and not DevMode.active():
		_ask_telemetry.call_deferred()
	if not SaveSystem.corrupted_files.is_empty():
		EventBus.toast.emit.call_deferred(tr("TOAST_BACKUP_USED"), &"info")
		SaveSystem.corrupted_files.clear()


## Voile sombre en dégradé (opaque à gauche, transparent à droite) derrière le menu.
func _veil() -> TextureRect:
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(Palette.INK, 0.92))
	g.set_color(1, Color(Palette.INK, 0.0))
	g.add_point(0.45, Color(Palette.INK, 0.7))
	var gt: GradientTexture2D = GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	var tr_v: TextureRect = TextureRect.new()
	tr_v.texture = gt
	tr_v.stretch_mode = TextureRect.STRETCH_SCALE
	tr_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr_v.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	tr_v.offset_right = 1150.0
	return tr_v


## Pied de page : mention légale, version, astuce qui défile.
func _add_footer() -> void:
	var disclaimer: Label = UiKit.label(tr("DISCLAIMER_SIMULATED"), UiKit.SIZE_SMALL, Palette.SMOKE)
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	disclaimer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	disclaimer.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	disclaimer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	disclaimer.offset_right = -180.0
	disclaimer.offset_bottom = -34.0
	add_child(disclaimer)
	var ver: Label = UiKit.label("v" + String(ProjectSettings.get_setting("application/config/version")), UiKit.SIZE_SMALL, Palette.SMOKE)
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position += Vector2(-110, -40)
	add_child(ver)
	_tip = UiKit.label("", UiKit.SIZE_SMALL, Palette.IVORY)
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tip.custom_minimum_size = Vector2(620, 0)
	_tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip.offset_right = -110.0
	_tip.offset_bottom = -96.0
	add_child(_tip)
	_tip_i = RngService.cosmetic().randi_range(0, TIPS.size() - 1)
	_next_tip()


func _next_tip() -> void:
	if not is_instance_valid(_tip):
		return
	_tip.text = "%s  %s" % [tr("MENU_TIP"), tr(TIPS[_tip_i % TIPS.size()])]
	_tip_i += 1
	var tw: Tween = _tip.create_tween()
	tw.tween_property(_tip, "modulate:a", 1.0, 0.5).from(0.0)
	tw.tween_interval(TIP_SECONDS)
	tw.tween_property(_tip, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_next_tip)


## Résumé de la partie sauvegardée (personnage, palier, échéance), vide si illisible.
func _run_summary() -> String:
	var run: RunState = SaveSystem.load_run()
	if run == null:
		return ""
	var who: String = Localization.name_of("characters", run.character_id)
	return tr("MENU_CONTINUE_INFO") % [who, run.tier, run.deadline_idx + 1]


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
