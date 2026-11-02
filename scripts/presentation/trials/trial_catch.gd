class_name TrialCatch
extends ThrowTrial
## PLUIE DE JETONS (écran dédié) : le plafond du Grand Zéro fuit… des jetons. Déplacer le
## plateau (stick, flèches ou souris) pour attraper les jetons dorés et éviter les fausses
## pièces violettes de La Maison. La pluie s'intensifie. Note = part des jetons dorés
## attrapés, moins une pénalité par fausse pièce.

const TRAY_W: float = 220.0
const TRAY_Y: float = 900.0
const CHIP_R: float = 22.0
const FIELD_X: Vector2 = Vector2(300.0, 1620.0)
const FAKE: Color = Color("b03aff")

var _x: float = 960.0
var _chips: Array[Dictionary] = []
var _spawn_t: float = 0.0
var _good_total: int = 0
var _caught: int = 0
var _bad: int = 0
var _mouse_x: float = -1.0
var _bot_axis: float = 0.0
var _ended: bool = false


func begin() -> void:
	_x = size.x * 0.5


func _progress() -> float:
	return clampf(t / (p("duration") * slow), 0.0, 1.0)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	return false


func _spawn() -> void:
	var bad: bool = rng.randf() < p("bad_ratio")
	var x: float = rng.randf_range(FIELD_X.x, FIELD_X.y)
	var sp: float = lerpf(p("fall_speed_start"), p("fall_speed_end"), _progress()) / slow
	_chips.append({"p": Vector2(x, 150.0), "v": sp, "bad": bad, "spin": rng.randf() * TAU})
	if not bad:
		_good_total += 1


func tick(dt: float) -> void:
	if _ended:
		return
	var v: float = held_vector().x + _bot_axis
	_x += clampf(v, -1.0, 1.0) * p("tray_speed") * dt
	if mouse and _mouse_x >= 0.0:
		_x = _mouse_x
	_x = clampf(_x, FIELD_X.x, FIELD_X.y)
	_spawn_t -= dt
	if _spawn_t <= 0.0 and t < p("duration") * slow:
		_spawn()
		_spawn_t = lerpf(p("spawn_start"), p("spawn_end"), _progress()) * slow
	var kept: Array[Dictionary] = []
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		pos.y += float(c["v"]) * dt
		c["p"] = pos
		c["spin"] = float(c["spin"]) + dt * 6.0
		if absf(pos.y - TRAY_Y) < 18.0 and absf(pos.x - _x) < TRAY_W * 0.5 * widen() + CHIP_R * 0.5:
			if bool(c["bad"]):
				_bad += 1
				AudioBus.play("curse", 1.2, -4.0)
				pop(pos + Vector2(0, -40), 0.0, "TRIAL_CATCH_FAKE")
			else:
				_caught += 1
				AudioBus.play("chip_place", 0.9 + 0.02 * float(_caught % 12))
			continue
		if pos.y < size.y + 40.0:
			kept.append(c)
	_chips = kept
	if t >= p("duration") * slow and _chips.is_empty():
		_ended = true
		var sc: float = float(_caught) / maxf(float(_good_total), 1.0) - p("bad_penalty") * float(_bad)
		finish(clampf(sc, 0.0, 1.0))


func bot_wants() -> Dictionary:
	# Vise le premier jeton doré encore atteignable, en évitant les fausses pièces imminentes.
	var goal: float = _x
	var best_t: float = INF
	var half: float = TRAY_W * 0.5 * widen()
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		if bool(c["bad"]) or pos.y > TRAY_Y + 5.0:
			continue
		var arrive: float = (TRAY_Y - pos.y) / maxf(float(c["v"]), 1.0)
		var travel: float = maxf(absf(pos.x - _x) - half * 0.6, 0.0) / p("tray_speed")
		if travel <= arrive and arrive < best_t:
			best_t = arrive
			goal = pos.x
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		var arrive: float = (TRAY_Y - pos.y) / maxf(float(c["v"]), 1.0)
		if bool(c["bad"]) and arrive > 0.0 and arrive < minf(best_t, 0.35) and absf(pos.x - goal) < half + CHIP_R:
			goal = pos.x + (half + CHIP_R * 2.0) * (1.0 if goal >= pos.x else -1.0)
	return {"do": "axis", "v": Vector2(clampf((goal - _x) / 40.0, -1.0, 1.0), 0.0)}


func bot_apply(want: Dictionary) -> void:
	if String(want.get("do", "")) == "axis":
		_bot_axis = (want["v"] as Vector2).x
	else:
		_bot_axis = 0.0


func paint() -> void:
	backdrop()
	# Plafond qui fuit, flaque dorée au sol.
	draw_rect(Rect2(0, 120, size.x, 30), Color(0.2, 0.12, 0.08))
	for k: int in 12:
		draw_rect(Rect2(160.0 + k * 140.0, 140, 30, 10 + 6 * sin(t * 2.0 + k)), Color(0.12, 0.07, 0.05))
	draw_rect(Rect2(0, TRAY_Y + 60, size.x, size.y), Color(0.05, 0.12, 0.08))
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		var squash: float = absf(cos(float(c["spin"])))
		var col: Color = FAKE if bool(c["bad"]) else Palette.GOLD
		draw_set_transform(pos, 0.0, Vector2(maxf(squash, 0.2), 1.0))
		draw_circle(Vector2.ZERO, CHIP_R, col.darkened(0.3))
		draw_circle(Vector2.ZERO, CHIP_R - 5.0, col)
		draw_arc(Vector2.ZERO, CHIP_R - 9.0, 0, TAU, 20, Palette.IVORY if not bool(c["bad"]) else Palette.INK, 3.0)
		draw_set_transform(Vector2.ZERO)
	# Plateau de croupier.
	var w: float = TRAY_W * widen()
	draw_rect(Rect2(_x - w * 0.5, TRAY_Y, w, 18), Palette.GOLD_DARK)
	draw_rect(Rect2(_x - w * 0.5, TRAY_Y - 6, w, 8), Palette.GOLD_LIGHT)
	draw_rect(Rect2(_x - w * 0.5 - 10, TRAY_Y - 30, 10, 48), Palette.GOLD_DARK)
	draw_rect(Rect2(_x + w * 0.5, TRAY_Y - 30, 10, 48), Palette.GOLD_DARK)
	var info: String = tr("TRIAL_CATCH_STATUS") % [_caught, _good_total, _bad]
	text(Vector2(size.x * 0.5, 210.0), info, UiKit.SIZE_H2, Palette.IVORY)
	var left: float = clampf(1.0 - t / (p("duration") * slow), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 250, 600 * left, 10), Palette.GOLD)
