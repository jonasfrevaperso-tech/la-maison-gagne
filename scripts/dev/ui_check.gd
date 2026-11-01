class_name DevUiCheck
extends Node
## Contrôle d'interface sans écran : chaque écran et chaque surcouche est ouvert à plusieurs
## tailles de fenêtre logique (16:9, 16:10 Steam Deck, texte agrandi) et doit :
##  - donner le focus à un contrôle (navigation manette possible dès l'ouverture) ;
##  - garder tous ses boutons dans la fenêtre (hors zones défilantes).
## Usage : godot --headless --path . -- --dev-ui-check
## Code de sortie 1 au moindre défaut.

const SIZES: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1920, 1200), Vector2i(1600, 900)]
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
	for sz: Vector2i in SIZES:
		root.size = sz
		root.content_scale_size = sz
		UiLayout.fit_frame(frame, Vector2(sz))
		for screen_id: StringName in Main.SCREENS.keys():
			_prepare_run(db)
			var packed: PackedScene = load(Main.SCREENS[screen_id]) as PackedScene
			var node: Control = packed.instantiate() as Control
			if node.has_method("setup"):
				node.call("setup", {"victory": false})
			await _check(node, "%s @%dx%d" % [screen_id, sz.x, sz.y], not NO_FOCUS_OK.has(screen_id))
		# États de l'écran de run qui changent la rangée d'actions.
		for st: RunScreen.UiState in [RunScreen.UiState.RETHROW, RunScreen.UiState.TARGETING]:
			_prepare_run(db)
			var rs: RunScreen = (load(Main.SCREENS[&"run"]) as PackedScene).instantiate() as RunScreen
			await _check(rs, "run/%s @%dx%d" % [RunScreen.UiState.keys()[st], sz.x, sz.y], false, rs._set_state.bind(st))
		for o: Array in _overlays(db):
			await _check(o[1] as Control, "%s @%dx%d" % [o[0], sz.x, sz.y])
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
