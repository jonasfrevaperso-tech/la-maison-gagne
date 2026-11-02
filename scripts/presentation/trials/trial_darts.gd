class_name TrialDarts
extends ThrowTrial
## FLÉCHETTES (écran dédié) : une vieille cible de pub, trois fléchettes. Le viseur tangue tout
## seul (la main a bu un peu trop de « courage ») ; on le ramène au centre au stick, aux flèches
## ou à la souris, et on lance au bon moment. Note = proximité du centre, fléchette par fléchette.

const BOARD_C: Vector2 = Vector2(960.0, 520.0)
const RINGS: Array[float] = [1.0, 0.82, 0.62, 0.44, 0.26, 0.11]
const SECTORS: int = 20

var _dart: int = 0
var _aim: Vector2 = BOARD_C
var _steer: Vector2 = Vector2.ZERO
var _phase_t: float = 0.0
var _seed: Vector2 = Vector2.ZERO
var _stuck: Array[Vector2] = []
var _scores: Array[float] = []
var _flying: float = -1.0
var _mouse_pt: Vector2 = Vector2(-1, -1)
var _bot_axis: Vector2 = Vector2.ZERO
## Dérive de la main (px/s) : sans correction, le viseur s'en va.
var _drift: Vector2 = Vector2.ZERO


func begin() -> void:
	_new_dart()


func _new_dart() -> void:
	_steer = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 140.0)
	_drift = Vector2.from_angle(rng.randf() * TAU) * p("drift")
	_seed = Vector2(rng.randf_range(0, 100), rng.randf_range(0, 100))
	_phase_t = 0.0
	_flying = -1.0


func _radius() -> float:
	return p("board_radius")


## Tangage : somme de sinus (lent et ample + rapide et court), plus fort à chaque fléchette.
func _wobble() -> Vector2:
	var a: float = pk("wobble", _dart) / widen()
	var s: float = p("wobble_speed") / slow
	var tt: float = _phase_t * s
	return Vector2(sin(tt * 1.3 + _seed.x) * 0.7 + sin(tt * 3.1 + _seed.y) * 0.3,
		sin(tt * 1.7 + _seed.y) * 0.7 + cos(tt * 2.6 + _seed.x) * 0.3) * a


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pt = mm.position
		return true
	if confirm_pressed(event):
		throw_dart()
		return true
	return false


func throw_dart() -> void:
	if _flying >= 0.0:
		return
	_flying = 0.0
	AudioBus.play("whoosh", 1.6, -6.0)


func _land() -> void:
	var d: float = _aim.distance_to(BOARD_C)
	var perfect: float = p("perfect_radius") * widen()
	var sc: float = 1.0 if d <= perfect else clampf(1.0 - (d - perfect) / (_radius() * p("falloff")), 0.0, 1.0)
	_scores.append(sc)
	_stuck.append(_aim)
	AudioBus.play("stamp", 1.4, -2.0)
	if sc >= 0.9:
		AudioBus.play("chime", 1.2, -4.0)
	pop(_aim + Vector2(0, -50), sc, "TRIAL_DARTS_BULL" if d <= perfect else "")
	_dart += 1
	if _dart >= pi("darts"):
		finish(mean(_scores))
	else:
		_new_dart()


func tick(dt: float) -> void:
	_phase_t += dt
	if _flying >= 0.0:
		_flying += dt
		if _flying >= 0.25:
			_land()
		return
	var v: Vector2 = held_vector() + _bot_axis
	_steer += v.limit_length(1.0) * p("steer_speed") * dt + _drift * dt
	if _mouse_pt.x >= 0.0 and mouse:
		_steer = _mouse_pt - BOARD_C
	_steer = _steer.limit_length(_radius() * 1.4)
	# La main dérive aussi d'elle-même : on doit corriger en permanence.
	_aim = BOARD_C + _steer + _wobble()
	if _phase_t > p("dart_seconds") * slow:
		throw_dart()  # bras fatigué : la fléchette part toute seule


func bot_wants() -> Dictionary:
	if _flying >= 0.0:
		return {"do": ""}
	var off: Vector2 = _aim - BOARD_C
	if off.length() < 4.0:
		return {"do": "confirm"}
	return {"do": "axis", "v": (-off / 40.0).limit_length(1.0)}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			_bot_axis = Vector2.ZERO
			throw_dart()
		"axis":
			_bot_axis = w["v"] as Vector2
		_:
			_bot_axis = Vector2.ZERO


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Mur lambrissé, cible en liège, craie des scores sur une ardoise.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.13, 0.08, 0.05))
	for k: int in 24:
		draw_line(Vector2(k * 84.0, 0), Vector2(k * 84.0, size.y), Color(0.09, 0.05, 0.03), 4.0)
	draw_circle(BOARD_C, _radius() + 60.0, Color(0, 0, 0, 0.35))
	draw_circle(BOARD_C, _radius() + 40.0, Color(0.1, 0.07, 0.05))
	for s: int in SECTORS:
		var a0: float = TAU * float(s) / SECTORS - PI / SECTORS
		var a1: float = a0 + TAU / SECTORS
		for ri: int in RINGS.size() - 2:
			var r0: float = RINGS[ri] * _radius()
			var r1: float = RINGS[ri + 1] * _radius()
			var light: bool = (s + ri) % 2 == 0
			var col: Color = Color(0.85, 0.78, 0.6) if light else Color(0.12, 0.1, 0.09)
			if ri == 0 or ri == 2:
				col = Palette.ROULETTE_RED.darkened(0.15) if light else Color(0.1, 0.38, 0.2)
			var pts: PackedVector2Array = PackedVector2Array([
				BOARD_C + Vector2(cos(a0), sin(a0)) * r1, BOARD_C + Vector2(cos(a0), sin(a0)) * r0,
				BOARD_C + Vector2(cos(a1), sin(a1)) * r0, BOARD_C + Vector2(cos(a1), sin(a1)) * r1])
			draw_colored_polygon(pts, col)
	draw_circle(BOARD_C, RINGS[4] * _radius(), Color(0.1, 0.38, 0.2))
	draw_circle(BOARD_C, RINGS[5] * _radius(), Palette.ROULETTE_RED)
	draw_circle(BOARD_C, p("perfect_radius") * widen(), Palette.GOLD_LIGHT)
	for d: Vector2 in _stuck:
		draw_line(d, d + Vector2(26, 22), Palette.SMOKE, 4.0)
		draw_rect(Rect2(d + Vector2(22, 16), Vector2(16, 12)), Palette.MAGENTA)
		draw_circle(d, 4.0, Palette.IVORY)
	# Ardoise.
	var slate: Rect2 = Rect2(1430, 300, 300, 360)
	draw_rect(slate, Color(0.12, 0.13, 0.13))
	draw_rect(slate, Color(0.4, 0.27, 0.13), false, 10.0)
	text(slate.position + Vector2(150, 40), tr("TRIAL_DARTS_SLATE"), UiKit.SIZE_BODY, Palette.IVORY, "display", 0)
	for k: int in _scores.size():
		text(slate.position + Vector2(150, 100 + k * 60), "%d" % roundi(_scores[k] * 100.0), UiKit.SIZE_H2, Palette.IVORY, "mono", 0)
	pips(Vector2(size.x * 0.5, 110), _scores, pi("darts"))
	if _flying < 0.0:
		var pulse: float = 0.7 + 0.3 * sin(t * 9.0)
		draw_arc(_aim, 22.0, 0, TAU, 32, Color(Palette.CYAN, pulse), 3.0, true)
		draw_line(_aim - Vector2(34, 0), _aim + Vector2(34, 0), Palette.CYAN, 2.0)
		draw_line(_aim - Vector2(0, 34), _aim + Vector2(0, 34), Palette.CYAN, 2.0)
		var left: float = clampf(1.0 - _phase_t / (p("dart_seconds") * slow), 0.0, 1.0)
		draw_arc(_aim, 30.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(Palette.GOLD, 0.8), 3.0, true)
	else:
		var u: float = clampf(_flying / 0.25, 0.0, 1.0)
		var from: Vector2 = Vector2(size.x * 0.5, size.y + 40)
		var pos: Vector2 = from.lerp(_aim, u)
		draw_line(pos, pos + (from - _aim).normalized() * 60.0 * (1.2 - u), Palette.SMOKE, 5.0)
