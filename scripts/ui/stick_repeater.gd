class_name StickRepeater
extends Node
## Stick gauche → appuis de croix, avec répétition maîtrisée (Options → Commandes →
## Sensibilité du stick). Sans lui, chaque micro-mouvement du stick déplaçait la sélection.
## Placé en dernier sous la racine : son `_input` passe avant tous les autres, ce qui lui
## permet aussi d'alimenter `GameInput` (gâchettes) avant les écrans.

const ENGAGE: float = 0.55
const DISENGAGE: float = 0.35
## Délai avant répétition et intervalle de répétition, du moins sensible (0) au plus sensible (1).
const DELAY_SLOW: float = 0.55
const DELAY_FAST: float = 0.22
const REPEAT_SLOW: float = 0.3
const REPEAT_FAST: float = 0.07
## La répétition s'accélère un peu quand on maintient (jusqu'à ce facteur).
const HOLD_ACCEL: float = 0.6
const HOLD_ACCEL_TIME: float = 1.5

var _dir: Vector2i = Vector2i.ZERO
var _timer: float = 0.0
var _held: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	GameInput.note_device(event)
	if event is InputEventJoypadMotion:
		GameInput.observe(event as InputEventJoypadMotion)


func _process(delta: float) -> void:
	var v: Vector2 = Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	var want: Vector2i = _direction(v)
	if want != _dir:
		if _dir != Vector2i.ZERO:
			_send(_dir, false)
		_dir = want
		_held = 0.0
		if _dir != Vector2i.ZERO:
			_send(_dir, true)
			_timer = delay()
		return
	if _dir == Vector2i.ZERO:
		return
	_held += delta
	_timer -= delta
	if _timer <= 0.0:
		_send(_dir, false)
		_send(_dir, true)
		var accel: float = lerpf(1.0, HOLD_ACCEL, clampf(_held / HOLD_ACCEL_TIME, 0.0, 1.0))
		_timer = interval() * accel


## Direction dominante (pas de diagonale : un pas à la fois, comme la croix).
func _direction(v: Vector2) -> Vector2i:
	var mag: float = maxf(absf(v.x), absf(v.y))
	var threshold: float = DISENGAGE if _dir != Vector2i.ZERO else ENGAGE
	if mag < threshold:
		return Vector2i.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y > 0.0 else -1)


static func sensitivity() -> float:
	return clampf(Settings.f("input", "stick_sensitivity"), 0.0, 1.0)


static func delay() -> float:
	return lerpf(DELAY_SLOW, DELAY_FAST, sensitivity())


static func interval() -> float:
	return lerpf(REPEAT_SLOW, REPEAT_FAST, sensitivity())


func _send(d: Vector2i, down: bool) -> void:
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	e.pressed = down
	e.pressure = 1.0 if down else 0.0
	if d.x < 0:
		e.button_index = JOY_BUTTON_DPAD_LEFT
	elif d.x > 0:
		e.button_index = JOY_BUTTON_DPAD_RIGHT
	elif d.y < 0:
		e.button_index = JOY_BUTTON_DPAD_UP
	else:
		e.button_index = JOY_BUTTON_DPAD_DOWN
	Input.parse_input_event(e)
