class_name TouchPad
extends CanvasLayer
## Tactile : boutons de commande des épreuves qui se jouent « aux boutons » (Effet, Shaker,
## Simon, Tri des jetons, Plus haut / plus bas). Chaque bouton injecte l'action de manette
## correspondante (InputEventAction, appui puis relâcher) : les épreuves lisent les mêmes
## commandes qu'à la manette, sans code propre au tactile. Plusieurs doigts à la fois.
## Disposition (`touch_layout` des données) : « diamond » losange X/Y/B/A (couleurs Xbox),
## « row » rangée sous le pouce droit (gauche en disposition gaucher), « split » premier bouton
## dans le coin bas gauche et second dans le coin bas droit (alterner les deux pouces).

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
	"ui_spin": [Color("c9a24a"), ""],
}
## Libellé des boutons sans glyphe.
const LABELS: Dictionary[String, String] = {"ui_spin": "TOUCH_THROW"}
const LAYOUTS: Array[String] = ["diamond", "row", "split"]
## Position (en diamètres) de chaque bouton dans le losange.
const DIAMOND: Dictionary[String, Vector2] = {
	"qte_left": Vector2(0, 1), "qte_up": Vector2(1, 0), "qte_right": Vector2(2, 1), "qte_down": Vector2(1, 2),
}

var actions: Array[String] = []
var layout: String = ""
var _area: Control = null
var _areas: Array[Control] = []
var _centers: Dictionary[String, Vector2] = {}
var _held: Dictionary[int, String] = {}  # doigt -> action
var _icons: Dictionary[String, Texture2D] = {}


func configure(p_actions: Array[String], p_layout: String = "") -> TouchPad:
	actions = p_actions
	layout = p_layout if p_layout != "" else default_layout(p_actions)
	return self


static func default_layout(p_actions: Array[String]) -> String:
	return "diamond" if p_actions.size() == 4 and DIAMOND.has(p_actions[0]) else "row"


## Place occupée à l'écran : (largeur, hauteur) d'un bloc ; « split » : hauteur de bande seulement.
static func box_size(p_actions: Array[String], p_layout: String) -> Vector2:
	match p_layout if p_layout != "" else default_layout(p_actions):
		"diamond":
			return Vector2.ONE * (BUTTON_D * 3.0 + MARGIN)
		"split":
			return Vector2(BUTTON_D + MARGIN, BUTTON_D + MARGIN)
	return Vector2(p_actions.size() * (BUTTON_D + GAP) - GAP + MARGIN, BUTTON_D + MARGIN)


func _ready() -> void:
	layer = 60
	_area = _new_area()
	if layout == "split":
		_areas.append(_new_area())  # second bouton : coin opposé
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


func _new_area() -> Control:
	var a: Control = Control.new()
	a.mouse_filter = Control.MOUSE_FILTER_STOP  # le doigt sur un bouton n'atteint pas l'épreuve
	a.draw.connect(_draw_pad.bind(a))
	a.gui_input.connect(func(_e: InputEvent) -> void: a.accept_event())
	add_child(a)
	return a


func _layout() -> void:
	var safe: Rect2 = Platform.safe_rect(get_viewport())
	var four: bool = layout == "diamond"
	var box: Vector2
	_centers.clear()
	if layout == "split":
		_layout_split(safe)
		return
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
		_redraw()
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null and _held.has(sd.index) and _hit(sd.position) != _held[sd.index]:
		# Le doigt a quitté son bouton : relâché (pas de glissement d'un bouton à l'autre).
		_send(_held[sd.index], false)
		_held.erase(sd.index)
		_redraw()


## « split » : un bouton par coin bas (ordre inversé en disposition gaucher). Les centres sont
## alors en coordonnées de fenêtre, chaque zone ne dessinant que son bouton.
func _layout_split(safe: Rect2) -> void:
	var order: Array[String] = actions.duplicate()
	if Settings.b("game", "left_handed"):
		order.reverse()
	var spots: Array[Vector2] = [
		Vector2(safe.position.x + MARGIN, safe.end.y - MARGIN - BUTTON_D),
		Vector2(safe.end.x - MARGIN - BUTTON_D, safe.end.y - MARGIN - BUTTON_D),
	]
	var areas: Array[Control] = [_area]
	areas.append_array(_areas)
	for i: int in mini(order.size(), 2):
		areas[i].position = spots[i]
		areas[i].size = Vector2.ONE * BUTTON_D
		areas[i].set_meta("action", order[i])
		_centers[order[i]] = spots[i] + Vector2.ONE * BUTTON_D * 0.5
		areas[i].queue_redraw()


## Action du bouton sous `p` (coordonnées de fenêtre), "" sinon.
func _hit(p: Vector2) -> String:
	var origin: Vector2 = Vector2.ZERO if layout == "split" else _area.position
	for a: String in _centers.keys():
		if (p - origin).distance_to(_centers[a]) <= BUTTON_D * 0.5:
			return a
	return ""


func _send(action: String, pressed: bool) -> void:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = StringName(action)
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _redraw() -> void:
	_area.queue_redraw()
	for a: Control in _areas:
		a.queue_redraw()


func _draw_pad(area: Control) -> void:
	var down: Array[String] = []
	for v: String in _held.values():
		down.append(v)
	var origin: Vector2 = area.position if layout == "split" else Vector2.ZERO
	for a: String in _centers.keys():
		if layout == "split" and String(area.get_meta("action", "")) != a:
			continue
		var col: Color = STYLE.get(a, [Color.WHITE, ""])[0] as Color
		var pressed: bool = down.has(a)
		var r: float = BUTTON_D * 0.5 * (PRESS_SCALE if pressed else 1.0)
		var c: Vector2 = _centers[a] - origin
		area.draw_circle(c, r, Color(col, 0.85 if pressed else 0.55))
		area.draw_arc(c, r - 2.0, 0.0, TAU, 48, col.lightened(0.4), 4.0, true)
		if _icons.has(a):
			var tex: Texture2D = _icons[a]
			var s: float = r * 0.9
			area.draw_texture_rect(tex, Rect2(c - Vector2.ONE * s * 0.5, Vector2.ONE * s), false)
		elif LABELS.has(a):
			var f: Font = UiKit.font("display")
			var fs: int = UiKit.fs(UiKit.SIZE_BODY)
			var txt: String = tr(LABELS[a])
			var w: float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			area.draw_string(f, c + Vector2(-w * 0.5, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
