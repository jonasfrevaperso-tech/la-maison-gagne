class_name TrialJuggle
extends ThrowTrial
## LE JONGLAGE (écran dédié, scène du cabaret) : le croupier jongle avec des jetons de plus en
## plus nombreux. Trois mains (gauche, milieu, droite) : frapper la bonne quand un jeton
## redescend sur la ligne dorée le relance vers une autre main. Trop tôt ou trop tard, il
## tombe et repart d'en haut un peu plus tard. Un jeton s'ajoute à intervalles réguliers.
## Note = moyenne des réceptions (pleine dans la fenêtre parfaite, partielle sinon, 0 raté).

const LANES: int = 3
const LANE_X: Array[float] = [660.0, 960.0, 1260.0]
const HIT_Y: float = 820.0
const TOP_Y: float = 260.0
const CHIP_R: float = 30.0
const LANE_SYMBOLS: Array[int] = [0, 3, 2]
const CHIP_COLORS: Array[Color] = [Color("ff4d6d"), Color("ffd23f"), Color("29e0ff"), Color("2ee6a8"), Color("b03aff")]

var _chips: Array[Dictionary] = []
var _added: int = 0
var _add_t: float = 0.0
var _marks: Array[float] = []
var _hand_flash: Array[float] = [0.0, 0.0, 0.0]
var _bot_lane: int = -1
var _ended: bool = false


func begin() -> void:
	_add_chip()


func _dur() -> float:
	return p("duration") * slow


func _flight() -> float:
	return p("flight_seconds") * slow


func _add_chip() -> void:
	var lane: int = _added % LANES
	_chips.append({"lane": lane, "from": lane, "age": _flight() * 0.5, "col": CHIP_COLORS[_added % CHIP_COLORS.size()], "wait": 0.0})
	_added += 1
	_add_t = p("add_every") * slow


## Position d'un jeton : parabole de la main de départ à la main d'arrivée, sommet en haut.
func _chip_pos(c: Dictionary) -> Vector2:
	var u: float = clampf(float(c["age"]) / _flight(), 0.0, 1.2)
	var x0: float = LANE_X[int(c["from"])]
	var x1: float = LANE_X[int(c["lane"])]
	var x: float = lerpf(x0, x1, minf(u, 1.0))
	var y: float = HIT_Y - (HIT_Y - TOP_Y) * 4.0 * u * (1.0 - u)
	return Vector2(x, y)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var best: int = 0
			for k: int in LANES:
				if absf(mb.position.x - LANE_X[k]) < absf(mb.position.x - LANE_X[best]):
					best = k
			strike(best)
		return true
	var s: int = sym_pressed(event)
	var d: Vector2i = dir_pressed(event)
	if s == 0 or d == Vector2i.LEFT:
		strike(0)
	elif s == 3 or d == Vector2i.DOWN or d == Vector2i.UP:
		strike(1)
	elif s == 2 or d == Vector2i.RIGHT:
		strike(2)
	else:
		return false
	return true


## Frappe de la main `lane` : rattrape le jeton le plus proche de la ligne dans cette main.
func strike(lane: int) -> void:
	if _ended:
		return
	_hand_flash[lane] = 1.0
	var best: Dictionary = {}
	var best_d: float = INF
	for c: Dictionary in _chips:
		if int(c["lane"]) != lane or float(c["wait"]) > 0.0:
			continue
		var d: float = absf(float(c["age"]) - _flight())
		if d < best_d:
			best_d = d
			best = c
	var window: float = p("hit_window") * widen()
	if best.is_empty() or best_d > window:
		AudioBus.play("sticky", 1.2, -10.0)
		return
	var perfect: float = window * p("perfect_ratio")
	var q: float = 1.0 if best_d <= perfect else lerpf(1.0, p("late_value"), (best_d - perfect) / maxf(window - perfect, 0.001))
	_marks.append(q)
	pop(LANE_X[lane] * Vector2.RIGHT + Vector2(0, HIT_Y - 80.0), q)
	AudioBus.play("chip_place", 1.0 + 0.1 * float(lane), -4.0)
	# Relance vers une autre main.
	var nxt: int = (lane + 1 + rng.randi_range(0, LANES - 2)) % LANES
	best["from"] = lane
	best["lane"] = nxt
	best["age"] = 0.0


func tick(dt: float) -> void:
	if _ended:
		return
	for k: int in LANES:
		_hand_flash[k] = maxf(0.0, _hand_flash[k] - dt * 5.0)
	if _bot_lane >= 0:
		strike(_bot_lane)
		_bot_lane = -1
	_add_t -= dt
	if _add_t <= 0.0 and _added < pi("max_chips") and t < _dur():
		_add_chip()
	var window: float = p("hit_window") * widen()
	for c: Dictionary in _chips:
		if float(c["wait"]) > 0.0:
			c["wait"] = float(c["wait"]) - dt
			if float(c["wait"]) <= 0.0:
				c["from"] = c["lane"]
				c["age"] = _flight() * 0.5
			continue
		c["age"] = float(c["age"]) + dt
		if float(c["age"]) > _flight() + window:
			# Raté : le jeton tombe et revient d'en haut un peu plus tard.
			_marks.append(0.0)
			pop(_chip_pos(c) + Vector2(0, -40), 0.0, "TRIAL_JUGGLE_DROP")
			AudioBus.play("chip_lose", 1.0, -6.0)
			c["wait"] = p("respawn_seconds") * slow
	if t >= _dur():
		_ended = true
		finish(ThrowTrial.mean(_marks) if not _marks.is_empty() else 0.0)


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	for c: Dictionary in _chips:
		if float(c["wait"]) <= 0.0 and absf(float(c["age"]) - _flight()) <= 1.0 / 60.0:
			return {"do": "sym", "symbol": LANE_SYMBOLS[int(c["lane"])]}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	_bot_lane = LANE_SYMBOLS.find(int(w.get("symbol", -1))) if String(w.get("do", "")) == "sym" else -1


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Scène du cabaret : rideaux, projecteur, croupier jongleur stylisé.
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("12060c"))
	for k: int in 30:
		var x: float = -size.x * 0.5 + float(k) * 110.0
		var fold: float = 0.5 + 0.5 * sin(float(k) * 1.3)
		if absf(x - size.x * 0.5) > 560.0:
			draw_rect(Rect2(x, 0, 110, size.y), Color(0.35 + 0.1 * fold, 0.04, 0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 60, 0), Vector2(size.x * 0.5 + 60, 0), Vector2(size.x * 0.5 + 460, size.y),
		Vector2(size.x * 0.5 - 460, size.y)]), Color(1, 0.95, 0.75, 0.05))
	draw_rect(Rect2(-size.x, HIT_Y + 120.0, size.x * 3.0, size.y), Color("3a2214"))
	var c0: Vector2 = Vector2(size.x * 0.5, HIT_Y + 120.0)
	draw_rect(Rect2(c0 - Vector2(60, 220), Vector2(120, 220)), Color("1a1a22"))
	draw_rect(Rect2(c0 - Vector2(18, 220), Vector2(36, 120)), Palette.IVORY)
	draw_circle(c0 - Vector2(0, 270), 50.0, Color("e8c8a8"))
	draw_rect(Rect2(c0 - Vector2(55, 330), Vector2(110, 20)), Palette.INK)
	draw_line(Vector2(LANE_X[0] - 300, HIT_Y), Vector2(LANE_X[2] + 300, HIT_Y), Color(Palette.GOLD, 0.6), 3.0)
	for k2: int in LANES:
		var hp: Vector2 = Vector2(LANE_X[k2], HIT_Y + 40.0)
		draw_circle(hp, 34.0 + 10.0 * _hand_flash[k2], Color("e8c8a8").lerp(Palette.GOLD_LIGHT, _hand_flash[k2]))
		draw_line(c0 - Vector2(0, 160), hp, Color("1a1a22"), 18.0)
	for c: Dictionary in _chips:
		if float(c["wait"]) > 0.0:
			continue
		var pos: Vector2 = _chip_pos(c)
		var col: Color = c["col"]
		draw_circle(pos + Vector2(4, 6), CHIP_R, Color(0, 0, 0, 0.35))
		draw_circle(pos, CHIP_R, col)
		draw_arc(pos, CHIP_R - 7.0, 0, TAU, 24, Palette.IVORY, 4.0)
		var near: float = 1.0 - clampf(absf(float(c["age"]) - _flight()) / 0.4, 0.0, 1.0)
		if near > 0.0:
			draw_arc(Vector2(LANE_X[int(c["lane"])], HIT_Y), CHIP_R + 30.0 * (1.0 - near), 0, TAU, 32, Color(Palette.GOLD_LIGHT, near), 3.0)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 120, 600 * left, 10), Palette.GOLD)
	var caught: int = _marks.filter(func(m: float) -> bool: return m > 0.0).size()
	text(Vector2(size.x * 0.5, 170.0), tr("TRIAL_JUGGLE_STATUS") % [caught, _chips.size()], UiKit.SIZE_BODY, Palette.IVORY)
