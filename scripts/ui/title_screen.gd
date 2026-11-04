class_name TitleScreen
extends Control
## Écran titre. Mention obligatoire : jeu de hasard simulé, monnaie fictive.

const MENU_WIDTH: float = 720.0
const MENU_BUTTON: Vector2 = Vector2(720, 52)
const GRID_COLS: int = 3
const MENU_GAP: int = 8
const PANEL_POS: Vector2 = Vector2(110, 90)
## Téléphone : colonne plus large, reprise et nouvelle partie côte à côte, pas de « Quitter ».
const MENU_WIDTH_MOBILE: float = 1000.0
const GRID_COLS_MOBILE: int = 3
const PANEL_POS_MOBILE: Vector2 = Vector2(90, 40)
const TIP_SECONDS: float = 9.0
const TIP_W: float = 620.0
const TIP_W_MOBILE: float = 480.0
## Téléphone : en dessous de cette largeur logique (écrans 16:9 ou pliables), l'astuce
## rejoindrait le menu ; on la masque.
const TIP_MIN_W_MOBILE: float = 2100.0
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
	var mobile: bool = Platform.is_mobile()
	var menu_w: float = MENU_WIDTH_MOBILE if mobile else MENU_WIDTH
	var panel_pos: Vector2 = PANEL_POS_MOBILE if mobile else PANEL_POS
	var col: VBoxContainer = VBoxContainer.new()
	col.position = panel_pos
	col.custom_minimum_size = Vector2(menu_w, 0)
	col.add_theme_constant_override("separation", MENU_GAP)
	add_child(col)
	var t: Label = UiKit.title(tr("GAME_TITLE"), UiKit.SIZE_TITLE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(t)
	var sub: Label = UiKit.label(tr("GAME_TAGLINE"), UiKit.SIZE_H2, Palette.MAGENTA, "display")
	col.add_child(sub)
	var div: DecoDivider = UiKit.divider(menu_w, Palette.GOLD_DARK)
	col.add_child(div)
	col.add_child(UiKit.spacer(6))
	var first: Button = null
	# Téléphone : reprise et nouvelle partie sur une même ligne (le menu tient en hauteur).
	var main_row: BoxContainer = HBoxContainer.new() if mobile else VBoxContainer.new()
	main_row.add_theme_constant_override("separation", MENU_GAP)
	col.add_child(main_row)
	# Téléphone : le Musée rejoint la ligne principale (la grille garde trois rangées).
	var main_n: int = (2 if SaveSystem.has_run() else 1) + 1
	var main_w: float = (menu_w - float(MENU_GAP) * float(main_n - 1)) / float(main_n) if mobile else menu_w
	if SaveSystem.has_run():
		var cont: VBoxContainer = VBoxContainer.new()
		cont.add_theme_constant_override("separation", 2 if mobile else MENU_GAP)
		main_row.add_child(cont)
		first = UiKit.button(tr("MENU_CONTINUE"), _on_continue, Vector2(main_w, 62))
		cont.add_child(first)
		var info: String = _run_summary()
		if info != "":
			var lbl: Label = UiKit.label(info, UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.custom_minimum_size = Vector2(main_w, 0)
			cont.add_child(lbl)
	var new_btn: Button = UiKit.button(tr("MENU_NEW_RUN"), _on_new, Vector2(main_w, MENU_BUTTON.y))
	new_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main_row.add_child(new_btn)
	if mobile:
		var museum_btn: Button = UiKit.button(tr("MENU_MUSEUM"), GameState.goto.bind(GameState.SCREEN_MUSEUM),
			Vector2(main_w, MENU_BUTTON.y))
		museum_btn.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		main_row.add_child(museum_btn)
	if first == null:
		first = new_btn
	# Entrées secondaires (et Quitter) sur trois colonnes : le menu tient en 16:9 et en 16:10
	# même avec le texte agrandi.
	var extras: Array[Array] = _extra_entries()
	if not mobile:
		extras.append(["MENU_QUIT", _on_quit])  # Android : on quitte par le geste Retour
	var cols: int = GRID_COLS_MOBILE if mobile else GRID_COLS
	var grid: GridContainer = GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", MENU_GAP)
	grid.add_theme_constant_override("v_separation", MENU_GAP)
	col.add_child(grid)
	var cell: Vector2 = Vector2((menu_w - float(MENU_GAP) * float(cols - 1)) / float(cols), 48)
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
	tw.tween_property(col, "position:x", panel_pos.x, 0.6).from(panel_pos.x - 60.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	_tip.custom_minimum_size = Vector2(TIP_W_MOBILE if Platform.is_mobile() else TIP_W, 0)
	_tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_tip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tip.offset_right = -110.0
	_tip.offset_bottom = -96.0
	add_child(_tip)
	if Platform.is_mobile():
		resized.connect(_fit_tip)
		_fit_tip.call_deferred()
	_tip_i = RngService.cosmetic().randi_range(0, TIPS.size() - 1)
	_next_tip()


func _fit_tip() -> void:
	_tip.visible = size.x >= TIP_MIN_W_MOBILE


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
	var dlg: ConfirmBox = ConfirmBox.new().configure(tr("CONFIRM_TELEMETRY_MOBILE" if Platform.is_mobile() else "CONFIRM_TELEMETRY"))
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
		["MENU_MUSEUM", GameState.goto.bind(GameState.SCREEN_MUSEUM), &"museum"],
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
		if c[2] == &"museum" and Platform.is_mobile():
			continue  # sur la ligne principale
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


## Android (geste Retour) : quitter après confirmation.
func ask_quit() -> void:
	if find_children("*", "ConfirmBox", true, false).size() > 0:
		return
	var dlg: ConfirmBox = ConfirmBox.new().configure(tr("CONFIRM_QUIT"))
	dlg.confirmed.connect(_on_quit)
	add_child(dlg)


func _on_quit() -> void:
	GameState.quit_game()
