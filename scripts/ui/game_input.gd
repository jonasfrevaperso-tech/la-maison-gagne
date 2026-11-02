class_name GameInput
extends RefCounted
## Lecture des actions robuste aux commandes analogiques.
## Une gâchette (LT/RT) envoie des dizaines d'événements de mouvement pendant un seul appui :
## `pressed()` n'en retient qu'UN, le franchissement du seuil haut (hystérésis : il faut
## redescendre sous le seuil bas pour qu'un nouvel appui compte).
## Le résultat est mémorisé par événement : tous les gestionnaires qui lisent le même
## événement obtiennent la même réponse, quel que soit leur ordre.

const PRESS_THRESHOLD: float = 0.6
const RELEASE_THRESHOLD: float = 0.3

static var _latched: Dictionary[int, bool] = {}
static var _last_event: InputEvent = null
static var _last_edge: bool = false


## Équivalent de `event.is_action_pressed(action, allow_echo)`, un seul vrai par appui de gâchette.
static func pressed(event: InputEvent, action: StringName, allow_echo: bool = false) -> bool:
	if event is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = event as InputEventJoypadMotion
		var edge: bool = observe(m)
		return edge and InputMap.has_action(action) and InputMap.event_is_action(m, action)
	return event.is_action_pressed(action, allow_echo)


## Met à jour l'état d'un axe ; vrai si cet événement est le début d'un appui.
static func observe(m: InputEventJoypadMotion) -> bool:
	if m == _last_event:
		return _last_edge
	_last_event = m
	var key: int = m.device * 64 + int(m.axis)
	var v: float = absf(m.axis_value)
	var was: bool = bool(_latched.get(key, false))
	var edge: bool = false
	if not was and v >= PRESS_THRESHOLD:
		_latched[key] = true
		edge = true
	elif was and v <= RELEASE_THRESHOLD:
		_latched[key] = false
	_last_edge = edge
	return edge


## Remise à zéro (tests).
static func reset() -> void:
	_latched.clear()
	_last_event = null
	_last_edge = false
