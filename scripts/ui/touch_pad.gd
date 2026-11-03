class_name TouchPad
extends CanvasLayer
## Tactile : boutons de commande des épreuves qui se jouent « aux boutons » (Effet, Shaker,
## Simon, Tri des jetons, Plus haut / plus bas). Chaque bouton injecte l'action de manette
## correspondante (InputEventAction, appui puis relâcher) : les épreuves lisent les mêmes
## commandes qu'à la manette, sans code propre au tactile. Plusieurs doigts à la fois.
## Disposition : losange X/Y/B/A (couleurs Xbox) pour quatre boutons, sinon une rangée ;
## sous le pouce droit (pouce gauche en disposition gaucher), dans la zone sûre.

const BUTTON_D: float = 170.0
const GAP: float = 18.0
const MARGIN: float = 40.0
const PRESS_SCALE: float = 0.9
const HAPTIC_MS: int = 8
## Couleur et glyphe de chaque action.
const STYLE: Dictionary[String, Array] = {
	"qte_left": [Color("2f7de1"), "pad_x"],
	"qte_up": [Color("e8b923"), "pad_y"],
	"qte_right": [Color("d9363e"), "pad_b"],
	"qte_down": [Color("3fae49"), "pad_a"],
	"ui_up": [Color("c9a24a"), "pad_dpad_up"],
	"ui_down": [Color("c9a24a"), "pad_dpad_down"],
}
## Position (en diamètres) de chaque bouton dans le losange.
const DIAMOND: Dictionary[String, Vector2] = {
	"qte_left": Vector2(0, 1), "qte_up": Vector2(1, 0), "qte_right": Vector2(2, 1), "qte_down": Vector2(1, 2),
}

var actions: Array[String] = []
var _area: Control = null
var _centers: Dictionary[String, Vector2] = {}
var _held: Dictionary[int, String] = {}  # doigt -> action
var _icons: Dictionary[String, Texture2D] = {}


func configure(p_actions: Array[String]) -> TouchPad:
	actions = p_actions
	return self


func _ready() -> void:
	layer = 60
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_STOP  # le doigt sur un bouton n'atteint pas l'épreuve
	_area.draw.connect(_draw_pad)
	_area.gui_input.connect(func(_e: InputEvent) -> void: _area.accept_event())
	add_child(_area)
	for a: String in actions:
		var g: String = String(STYLE.get(a, [Color.WHITE, ""])[1])
		var path: String = "res://assets/glyphs/%s.png" % g
		if ResourceLoader.exists(path):
			_icons[a] = load(path) as Texture2D
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	for idx: int in _held.keys():
		_send(_held[idx], false)
	_held.clear()


func _layout() -> void:
	var safe: Rect2 = Platform.safe_rect(get_viewport())
	var four: bool = actions.size() == 4 and DIAMOND.has(actions[0])
	var box: Vector2
	_centers.clear()
	if four:
		box = Vector2.ONE * BUTTON_D * 3.0
		for a: String in actions:
			_centers[a] = (DIAMOND[a] + Vector2(0.5, 0.5)) * BUTTON_D
	else:
		box = Vector2(actions.size() * (BUTTON_D + GAP) - GAP, BUTTON_D)
		for i: int in actions.size():
			_centers[actions[i]] = Vector2(i * (BUTTON_D + GAP) + BUTTON_D * 0.5, BUTTON_D * 0.5)
	var left: bool = Settings.b("game", "left_handed")
	var x: float = safe.position.x + MARGIN if left else safe.end.x - MARGIN - box.x
	_area.position = Vector2(x, safe.end.y - MARGIN - box.y)
	_area.size = box
	_area.queue_redraw()


func _input(event: InputEvent) -> void:
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		if st.pressed:
			var a: String = _hit(st.position)
			if a != "":
				_held[st.index] = a
				_send(a, true)
				Platform.haptic(HAPTIC_MS)
		elif _held.has(st.index):
			_send(_held[st.index], false)
			_held.erase(st.index)
		_area.queue_redraw()
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null and _held.has(sd.index) and _hit(sd.position) != _held[sd.index]:
		# Le doigt a quitté son bouton : relâché (pas de glissement d'un bouton à l'autre).
		_send(_held[sd.index], false)
		_held.erase(sd.index)
		_area.queue_redraw()


## Action du bouton sous `p` (coordonnées de fenêtre), "" sinon.
func _hit(p: Vector2) -> String:
	var local: Vector2 = p - _area.position
	for a: String in _centers.keys():
		if local.distance_to(_centers[a]) <= BUTTON_D * 0.5:
			return a
	return ""


func _send(action: String, pressed: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = StringName(action)
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _draw_pad() -> void:
	var down: Array[String] = []
	for v: String in _held.values():
		down.append(v)
	for a: String in _centers.keys():
		var col: Color = STYLE.get(a, [Color.WHITE, ""])[0] as Color
		var pressed: bool = down.has(a)
		var r: float = BUTTON_D * 0.5 * (PRESS_SCALE if pressed else 1.0)
		var c: Vector2 = _centers[a]
		_area.draw_circle(c, r, Color(col, 0.85 if pressed else 0.55))
		_area.draw_arc(c, r - 2.0, 0.0, TAU, 48, col.lightened(0.4), 4.0, true)
		if _icons.has(a):
			var tex: Texture2D = _icons[a]
			var s: float = r * 0.9
			_area.draw_texture_rect(tex, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false)
