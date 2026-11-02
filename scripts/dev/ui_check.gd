class_name DevUiCheck
extends Node
## Contrôle d'interface sans écran : chaque écran et chaque surcouche est ouvert à plusieurs
## tailles de fenêtre logique (16:9, 16:10 Steam Deck, texte agrandi) et doit :
##  - donner le focus à un contrôle (navigation manette possible dès l'ouverture) ;
##  - garder tous ses boutons dans la fenêtre (hors zones défilantes).
## Usage : godot --headless --path . -- --dev-ui-check
## Code de sortie 1 au moindre défaut.

## [taille logique, taille du texte] : 16:9, Steam Deck (16:10), petite fenêtre, Steam Deck texte max.
const CONFIGS: Array[Array] = [
	[Vector2i(1920, 1080), 1.0],
	[Vector2i(1920, 1200), 1.0],
	[Vector2i(1600, 900), 1.0],
	[Vector2i(1920, 1200), 1.3],
]
## Lisibilité Steam Deck : taille minimale d'un texte rendu en 1280×800 (critère Valve : 9 px).
const DECK_MIN_PX: float = 9.0
const DECK_HEIGHT: float = 800.0
const SETTLE_FRAMES: int = 6
const EDGE_TOLERANCE: float = 2.0
## Écrans pilotés à la manette sans focus d'interface (curseur du tapis, cf. RunScreen._gamepad_table) :
## donner le focus à un bouton y ferait déclencher « LANCER » par la touche A (miser).
const NO_FOCUS_OK: Array[StringName] = [&"run"]

var problems: Array[String] = []
var checked: int = 0


var root: Window = null
var frame: Control = null


func _ready() -> void:
	root = get_tree().root
	frame = Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_run.call_deferred()


func _run() -> void:
	var db: ContentDB = ContentDB.shared()
	Settings.set_value("game", "input_mode", "gamepad")
	InputGlyphs.apply_mode()
	for cfg: Array in CONFIGS:
		var sz: Vector2i = cfg[0]
		Settings.set_value("access", "text_scale", float(cfg[1]))
		UiKit.clear_cache()
		root.size = sz
		root.content_scale_size = sz
		UiLayout.fit_frame(frame, Vector2(sz))
		for screen_id: StringName in Main.SCREENS.keys():
			_prepare_run(db)
			var packed: PackedScene = load(Main.SCREENS[screen_id]) as PackedScene
			var node: Control = packed.instantiate() as Control
			if node.has_method("setup"):
				node.call("setup", {"victory": false})
			await _check(node, "%s @%dx%d×%.1f" % [screen_id, sz.x, sz.y, float(cfg[1])], not NO_FOCUS_OK.has(screen_id))
		# États de l'écran de run qui changent la rangée d'actions.
		for st: RunScreen.UiState in [RunScreen.UiState.RETHROW, RunScreen.UiState.TARGETING]:
			_prepare_run(db)
			var rs: RunScreen = (load(Main.SCREENS[&"run"]) as PackedScene).instantiate() as RunScreen
			await _check(rs, "run/%s @%dx%d×%.1f" % [RunScreen.UiState.keys()[st], sz.x, sz.y, float(cfg[1])], false, rs._set_state.bind(st))
		for o: Array in _overlays(db):
			await _check(o[1] as Control, "%s @%dx%d×%.1f" % [o[0], sz.x, sz.y, float(cfg[1])])
	Settings.set_value("access", "text_scale", 1.0)
	Settings.set_value("game", "input_mode", "auto")
	for p: String in problems:
		printerr("UI : " + p)
	print("Interface : %d vues contrôlées, %d problème(s)" % [checked, problems.size()])
	_cleanup()
	get_tree().quit(1 if not problems.is_empty() else 0)


func _prepare_run(db: ContentDB) -> void:
	var gs: Node = GameState
	var ctl: RunController = RunController.new(db)
	ctl.new_run("lea", 0, 1234)
	ctl.run.flags["act_intro_seen_1"] = true
	gs.set("controller", ctl)


func _overlays(db: ContentDB) -> Array[Array]:
	var ctl: RunController = RunController.new(db)
	ctl.new_run("lea", 0, 99)
	ctl.run.money = 30
	ShopModel.enter(ctl.run, db)
	GameState.controller = ctl
	var out: Array[Array] = [
		["shop", ShopOverlay.new().configure(ctl)],
		["pause", PauseMenu.new()],
		["quick_settings", QuickSettings.new()],
		["confirm", ConfirmBox.new().configure("?")],
		["note", NoteOverlay.new().configure(Image.create(8, 8, false, Image.FORMAT_RGB8), "run")],
		["soundboard", SoundboardOverlay.new()],
		["reward", RewardOverlay.new().configure(ctl.compute_reward(), false)],
	]
	var pact_ctl: RunController = RunController.new(db)
	pact_ctl.new_run("lea", 0, 7)
	out.append(["pact", PactOverlay.new().configure(pact_ctl)])
	var ev_ctl: RunController = RunController.new(db)
	ev_ctl.new_run("lea", 0, 8)
	ev_ctl.run.pending_event_id = db.ids("events")[0]
	out.append(["event", EventOverlay.new().configure(ev_ctl)])
	return out


func _check(node: Control, label: String, need_focus: bool = true, prep: Callable = Callable()) -> void:
	frame.add_child(node)
	for _i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	if prep.is_valid():
		prep.call()
		for _i: int in SETTLE_FRAMES:
			await get_tree().process_frame
	checked += 1
	var focus: Control = root.gui_get_focus_owner()
	if need_focus and (focus == null or not node.is_ancestor_of(focus)):
		problems.append("%s : aucun contrôle n'a le focus (manette inutilisable à l'ouverture)" % label)
	var view: Rect2 = Rect2(Vector2.ZERO, Vector2(root.size)).grow(EDGE_TOLERANCE)
	for b: Node in node.find_children("*", "BaseButton", true, false):
		var btn: BaseButton = b as BaseButton
		if not btn.is_visible_in_tree() or _in_scroll(btn, node):
			continue
		var r: Rect2 = btn.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, btn.size)
		if not view.encloses(r):
			problems.append("%s : bouton « %s » hors de l'écran %s" % [label, _name(btn), r])
	_check_fonts(node, label)
	frame.remove_child(node)
	node.queue_free()
	await get_tree().process_frame


func _in_scroll(c: Node, stop: Node) -> bool:
	var p: Node = c.get_parent()
	while p != null and p != stop:
		if p is ScrollContainer:
			return true
		p = p.get_parent()
	return false


func _name(b: BaseButton) -> String:
	return (b as Button).text if b is Button and (b as Button).text != "" else String(b.name)


func _cleanup() -> void:
	GameState.controller = null
	UiKit.clear_cache()
	IconLibrary.clear_cache()


## Plus petit texte visible, ramené à l'écran du Steam Deck (la fenêtre logique la plus haute
## correspond à 800 px physiques).
func _check_fonts(node: Control, label: String) -> void:
	var to_deck: float = DECK_HEIGHT / maxf(float(root.size.y), 1.0)
	var worst: float = 1e9
	var worst_name: String = ""
	for c: Node in node.find_children("*", "Control", true, false):
		var ctl: Control = c as Control
		if not ctl.is_visible_in_tree():
			continue
		var size_px: int = 0
		var txt: String = ""
		if ctl is Label:
			size_px = ctl.get_theme_font_size("font_size")
			txt = (ctl as Label).text
		elif ctl is Button:
			size_px = ctl.get_theme_font_size("font_size")
			txt = (ctl as Button).text
		elif ctl is RichTextLabel:
			size_px = ctl.get_theme_font_size("normal_font_size")
			txt = (ctl as RichTextLabel).get_parsed_text()
		if txt.strip_edges() == "" or size_px <= 0:
			continue
		var px: float = float(size_px) * ctl.get_global_transform_with_canvas().get_scale().y * to_deck
		if px < worst:
			worst = px
			worst_name = txt.substr(0, 24)
	if worst < DECK_MIN_PX:
		problems.append("%s : texte de %.1f px sur Steam Deck (« %s »), minimum %.0f px" % [label, worst, worst_name, DECK_MIN_PX])
