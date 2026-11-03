class_name TouchStick
extends CanvasLayer
## Tactile : joystick virtuel fixe, dans le coin bas gauche (bas droit en disposition gaucher).
## Le doigt posé dans sa zone pilote `ui_left/right/up/down` avec leur intensité
## (`Input.action_press`) : les épreuves lisent `ThrowTrial.held_vector()` comme au stick.

const RADIUS: float = 150.0
const KNOB_R: float = 62.0
const MARGIN: float = 48.0
## Zone de prise : plus large que le socle (le pouce n'a pas à viser le centre).
const GRAB_SCALE: float = 1.5
const DEAD: float = 0.12
const ACTIONS: Dictionary[String, Vector2] = {
	"ui_left": Vector2.LEFT, "ui_right": Vector2.RIGHT, "ui_up": Vector2.UP, "ui_down": Vector2.DOWN,
}

var _area: Control = null
var _center: Vector2 = Vector2.ZERO
var _finger: int = -1
var _vec: Vector2 = Vector2.ZERO


## Taille réservée à l'écran (socle et marge), pour placer l'épreuve à côté.
static func box_size() -> Vector2:
	return Vector2.ONE * (RADIUS * 2.0 + MARGIN)


func _ready() -> void:
	layer = 60
	_area = Control.new()
	_area.mouse_filter = Control.MOUSE_FILTER_STOP  # le pouce sur le joystick n'atteint pas l'épreuve
	_area.draw.connect(_draw_stick)
	_area.gui_input.connect(func(_e: InputEvent) -> void: _area.accept_event())
	add_child(_area)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _exit_tree() -> void:
	_set_vector(Vector2.ZERO)


func _layout() -> void:
	var safe: Rect2 = Platform.safe_rect(get_viewport())
	var side: float = RADIUS * 2.0 * GRAB_SCALE
	var left: bool = not Settings.b("game", "left_handed")
	var x: float = safe.position.x + MARGIN if left else safe.end.x - MARGIN - side
	_area.position = Vector2(x, safe.end.y - MARGIN - side)
	_area.size = Vector2.ONE * side
	_center = _area.size * 0.5
	_area.queue_redraw()


func _input(event: InputEvent) -> void:
	var st: InputEventScreenTouch = event as InputEventScreenTouch
	if st != null:
		var local: Vector2 = st.position - _area.position
		if st.pressed and _finger < 0 and local.distance_to(_center) <= RADIUS * GRAB_SCALE:
			_finger = st.index
			_follow(local)
		elif not st.pressed and st.index == _finger:
			_finger = -1
			_set_vector(Vector2.ZERO)
		return
	var sd: InputEventScreenDrag = event as InputEventScreenDrag
	if sd != null and sd.index == _finger:
		_follow(sd.position - _area.position)


func _follow(local: Vector2) -> void:
	var v: Vector2 = (local - _center) / RADIUS
	_set_vector(v.limit_length(1.0) if v.length() > DEAD else Vector2.ZERO)


## Intensité de chaque direction = projection du vecteur sur elle (diagonales comprises).
func _set_vector(v: Vector2) -> void:
	_vec = v
	for a: String in ACTIONS.keys():
		var s: float = maxf(0.0, v.dot(ACTIONS[a]))
		if s > 0.0:
			Input.action_press(StringName(a), s)
		elif Input.is_action_pressed(StringName(a)):
			Input.action_release(StringName(a))
	if _area != null:
		_area.queue_redraw()


func vector() -> Vector2:
	return _vec


func _draw_stick() -> void:
	_area.draw_circle(_center, RADIUS, Color(Palette.INK, 0.45))
	_area.draw_arc(_center, RADIUS - 2.0, 0.0, TAU, 64, Color(Palette.GOLD, 0.8), 4.0, true)
	for a: String in ACTIONS.keys():
		var d: Vector2 = ACTIONS[a]
		var tip: Vector2 = _center + d * (RADIUS - 22.0)
		var side: Vector2 = d.orthogonal() * 12.0
		_area.draw_colored_polygon([tip, tip - d * 18.0 + side, tip - d * 18.0 - side], Color(Palette.GOLD_LIGHT, 0.7))
	var knob: Vector2 = _center + _vec * (RADIUS - KNOB_R * 0.5)
	_area.draw_circle(knob, KNOB_R, Color(Palette.GOLD, 0.85 if _finger >= 0 else 0.6))
	_area.draw_arc(knob, KNOB_R - 2.0, 0.0, TAU, 48, Palette.GOLD_LIGHT, 3.0, true)
