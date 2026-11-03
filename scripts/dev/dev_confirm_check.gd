class_name DevConfirmCheck
extends Node
## `--dev-confirm-check` : chaque confirmation (Oui / Non) ouverte depuis son vrai parent, dans le
## vrai arbre du jeu (PadNavigator, StickRepeater compris), en mode manette : le focus doit
## partir sur Oui, aller sur Non avec « droite » et revenir avec « gauche ».

const SETTLE: int = 30
const WAIT_FRAMES: int = 3000

var problems: Array[String] = []
var checked: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Settings.set_value("game", "input_mode", "gamepad")
	InputGlyphs.apply_mode()
	# Pause → Abandonner (en partie).
	GameState.controller = RunController.new(DataRegistry.db)
	GameState.controller.new_run("lea", 0, 4242)
	GameState.controller.run.flags["act_intro_seen_1"] = true
	GameState.controller.run.flags["tutorial_off"] = true
	GameState.goto(&"run")
	var rs: RunScreen = await _wait_for("RunScreen") as RunScreen
	if rs == null:
		problems.append("écran de partie introuvable")
	else:
		rs.call("_on_menu")
		await _settle()
		var pm: Node = _find(rs, "PauseMenu")
		if pm != null:
			pm.call("_abandon")
			await _check("pause → abandonner")
			var f: Control = get_viewport().gui_get_focus_owner()
			if f == null or not (pm as Node).is_ancestor_of(f):
				problems.append("pause : focus perdu après « Non » (%s)" % _name(f))
		else:
			problems.append("menu de pause introuvable")
	# Titre → Nouvelle partie (sauvegarde présente) et Quitter.
	GameState.autosave()
	GameState.controller = null
	GameState.goto(&"title")
	var ts: Node = await _wait_for("TitleScreen")
	if ts != null:
		ts.call("_on_new")
		await _check("titre → nouvelle partie")
		ts.call("ask_quit")
		await _check("titre → quitter")
	else:
		problems.append("écran titre introuvable")
	SaveSystem.clear_run()
	for p: String in problems:
		printerr("CONFIRM : " + p)
	print("Confirmations : %d contrôlées, %d problème(s)" % [checked, problems.size()])
	get_tree().quit(1 if not problems.is_empty() else 0)


func _check(label: String) -> void:
	await _settle()
	checked += 1
	var box: ConfirmBox = _find(get_tree().root, "ConfirmBox") as ConfirmBox
	if box == null:
		problems.append("%s : pas de confirmation" % label)
		return
	var buttons: Array[Node] = box.find_children("*", "Button", true, false)
	if buttons.size() < 2:
		problems.append("%s : boutons introuvables" % label)
		return
	var yes: Control = buttons[0] as Control
	var no: Control = buttons[1] as Control
	var vp: Viewport = get_viewport()
	if vp.gui_get_focus_owner() != yes:
		problems.append("%s : focus initial sur %s au lieu de Oui" % [label, _name(vp.gui_get_focus_owner())])
	await _press(&"ui_right")
	if vp.gui_get_focus_owner() != no:
		problems.append("%s : « droite » mène à %s au lieu de Non" % [label, _name(vp.gui_get_focus_owner())])
	await _press(&"ui_left")
	if vp.gui_get_focus_owner() != yes:
		problems.append("%s : « gauche » mène à %s au lieu de Oui" % [label, _name(vp.gui_get_focus_owner())])
	box.call("go_back")
	await _settle()


## Attend l'écran (chargement, chauffe du rendu) puis l'ouverture des rideaux.
func _wait_for(cls: String) -> Node:
	for _i: int in WAIT_FRAMES:
		await get_tree().process_frame
		var n: Node = _find(get_tree().root, cls)
		if n != null:
			await _settle(90)
			return n
	return null


func _press(action: StringName) -> void:
	for down: bool in [true, false]:
		var ev: InputEventAction = InputEventAction.new()
		ev.action = action
		ev.pressed = down
		Input.parse_input_event(ev)
		await get_tree().process_frame
	await _settle(6)


func _settle(frames: int = SETTLE) -> void:
	for _i: int in frames:
		await get_tree().process_frame


func _find(from: Node, cls: String) -> Node:
	var found: Array[Node] = from.find_children("*", cls, true, false)
	for n: Node in found:
		if (n as CanvasItem) == null or (n as CanvasItem).is_visible_in_tree():
			return n
	return null


func _name(c: Control) -> String:
	if c == null:
		return "rien"
	var b: Button = c as Button
	return "« %s » (%s)" % [b.text, c.get_parent().get_class()] if b != null else c.get_class()
