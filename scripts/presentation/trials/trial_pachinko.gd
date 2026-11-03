class_name TrialPachinko
extends ThrowTrial
## PACHINKO DU GRAND ZÉRO (écran dédié) : un lanceur doré balaie le haut d'un plateau de clous
## et lâche les billes à intervalles réguliers. Elles rebondissent (physique déterministe) puis
## l'entonnoir du bas les pousse vers deux taquets, à gauche et à droite du godet d'or.
## Frapper le bon taquet au moment où la bille passe dessus la renvoie dans le godet ; trop tôt
## ou trop tard, elle finit dans un godet d'argent ou dans la gouttière.
## Note = valeur moyenne des godets atteints (or 1, argent partiel, gouttière 0).

const BOARD: Rect2 = Rect2(560.0, 150.0, 800.0, 830.0)
const BALL_R: float = 13.0
const PEG_R: float = 7.0
const PEG_ROWS: int = 9
const PEG_GAP: Vector2 = Vector2(80.0, 56.0)
const LAUNCH_Y: float = 190.0
const FUNNEL_Y: float = 750.0
const KICK_Y: float = 850.0
const KICK_HALF_W: float = 150.0
const KICK_GAP: float = 200.0
const CUP_Y: float = 930.0
const GOLD_HALF: float = 60.0
const SILVER_HALF: float = 140.0
const SUBSTEPS: int = 4

var _pegs: Array[Vector2] = []
var _balls: Array[Dictionary] = []
var _launched: int = 0
var _launch_t: float = 0.6
var _phase: float = 0.0
var _scores: Array[float] = []
var _kick: Array[float] = [0.0, 0.0]
var _cool: Array[float] = [0.0, 0.0]
var _bot_side: int = -1
var _ended: bool = false
var _lights: float = 0.0


func begin() -> void:
	_phase = rng.randf() * TAU
	for r: int in PEG_ROWS:
		var y: float = BOARD.position.y + 120.0 + float(r) * PEG_GAP.y
		var off: float = PEG_GAP.x * 0.5 if r % 2 == 1 else 0.0
		var x: float = BOARD.position.x + 60.0 + off
		while x < BOARD.end.x - 40.0:
			_pegs.append(Vector2(x, y))
			x += PEG_GAP.x


func _center() -> float:
	return BOARD.get_center().x


func _launcher_x() -> float:
	return _center() + sin(t * p("launcher_speed") / slow + _phase) * (BOARD.size.x * 0.5 - 70.0)


## Taquet sous la bille : 0 gauche, 1 droit, -1 aucun.
func _kick_side(pos: Vector2) -> int:
	if absf(pos.y - KICK_Y) > p("kick_window") * widen():
		return -1
	var dx: float = pos.x - _center()
	if dx < -KICK_GAP * 0.5 and dx > -KICK_GAP * 0.5 - KICK_HALF_W * 2.0:
		return 0
	if dx > KICK_GAP * 0.5 and dx < KICK_GAP * 0.5 + KICK_HALF_W * 2.0:
		return 1
	return -1


func handle(event: InputEvent) -> bool:
	var k: int = sym_pressed(event)
	var d: Vector2i = dir_pressed(event)
	if k == 0 or d == Vector2i.LEFT:
		kick(0)
		return true
	if (mouse and k == 1) or k == 2 or d == Vector2i.RIGHT:
		kick(1)
		return true
	return false


## Frappe d'un taquet : renvoie vers le godet d'or chaque bille qui passe dessus, avec une
## erreur qui grandit avec l'écart au point idéal (le milieu de la fenêtre).
func kick(side: int) -> void:
	if _cool[side] > 0.0 or _ended:
		return
	_cool[side] = p("kick_cooldown")
	_kick[side] = 1.0
	AudioBus.play("decor_switch", 1.2 if side == 0 else 1.0, -6.0)
	for b: Dictionary in _balls:
		var pos: Vector2 = b["p"]
		if _kick_side(pos) != side or bool(b["kicked"]):
			continue
		b["kicked"] = true
		var err: float = clampf(absf(pos.y - KICK_Y) / (p("kick_window") * widen()), 0.0, 1.0)
		var dir: float = 1.0 if side == 0 else -1.0
		# Trajectoire balistique visée sur le godet, ratée d'autant plus que la frappe est tardive.
		var target: float = _center() + dir * err * (SILVER_HALF + 40.0)
		var flight: float = p("kick_flight")
		var v: Vector2 = Vector2((target - pos.x) / flight, (CUP_Y - pos.y - 0.5 * p("gravity") * flight * flight) / flight)
		b["v"] = v
		AudioBus.play("ball_metal", 1.3, -6.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_lights += dt
	for s: int in 2:
		_cool[s] = maxf(0.0, _cool[s] - dt)
		_kick[s] = maxf(0.0, _kick[s] - dt * 5.0)
	if _bot_side >= 0:
		kick(_bot_side)
		_bot_side = -1
	_launch_t -= dt
	if _launch_t <= 0.0 and _launched < pi("balls"):
		_launched += 1
		_launch_t = p("ball_every") * slow
		_balls.append({"p": Vector2(_launcher_x(), LAUNCH_Y), "v": Vector2(rng.randf_range(-30.0, 30.0), 0.0), "kicked": false})
		AudioBus.play("ball_launch", 1.4, -8.0)
	var h: float = dt / float(SUBSTEPS)
	for _s: int in SUBSTEPS:
		for b: Dictionary in _balls:
			_step(b, h)
	var kept: Array[Dictionary] = []
	for b2: Dictionary in _balls:
		var pos: Vector2 = b2["p"]
		if pos.y >= CUP_Y:
			_score_ball(pos.x)
		else:
			kept.append(b2)
	_balls = kept
	if _launched >= pi("balls") and _balls.is_empty():
		_ended = true
		finish(ThrowTrial.mean(_scores))


func _step(b: Dictionary, h: float) -> void:
	var v: Vector2 = b["v"]
	var pos: Vector2 = b["p"]
	v.y += p("gravity") * h
	pos += v * h
	if not bool(b["kicked"]):
		for peg: Vector2 in _pegs:
			var d: Vector2 = pos - peg
			var md: float = BALL_R + PEG_R
			if d.length_squared() < md * md and d.length_squared() > 0.0001:
				var n: Vector2 = d.normalized()
				pos = peg + n * md
				var vn: float = v.dot(n)
				if vn < 0.0:
					v -= (1.0 + p("restitution")) * vn * n
					v.x += n.x * p("peg_kick")
					if rng.randf() < 0.15:
						AudioBus.play("tick", 1.6, -16.0)
		# Entonnoir : sous FUNNEL_Y, les parois inclinées poussent vers les taquets.
		if pos.y > FUNNEL_Y and pos.y < KICK_Y:
			var dx: float = pos.x - _center()
			var lane: float = KICK_GAP * 0.5 + KICK_HALF_W
			v.x += clampf((signf(dx if absf(dx) > 1.0 else 1.0) * lane - dx) * p("funnel_pull"), -900.0, 900.0) * h
	if pos.x < BOARD.position.x + BALL_R:
		pos.x = BOARD.position.x + BALL_R
		v.x = absf(v.x) * p("restitution")
	elif pos.x > BOARD.end.x - BALL_R:
		pos.x = BOARD.end.x - BALL_R
		v.x = -absf(v.x) * p("restitution")
	v.x = clampf(v.x, -p("max_vx"), p("max_vx"))
	if not bool(b["kicked"]):
		v.y = minf(v.y, p("max_vy") / slow)  # le plateau freine la bille : on a le temps de la voir
	b["v"] = v
	b["p"] = pos


func _score_ball(x: float) -> void:
	var dx: float = absf(x - _center())
	var sc: float = 0.0
	var key: String = "TRIAL_PACHINKO_GUTTER"
	if dx <= GOLD_HALF:
		sc = 1.0
		key = "TRIAL_PACHINKO_GOLD"
		AudioBus.play("slot_win", 1.2, -4.0)
	elif dx <= SILVER_HALF:
		sc = p("silver_value")
		key = "TRIAL_PACHINKO_SILVER"
		AudioBus.play("coin", 1.1, -6.0)
	else:
		AudioBus.play("lose_soft", 1.0, -8.0)
	_scores.append(sc)
	pop(Vector2(x, CUP_Y - 60.0), sc, key)


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Frappe le taquet dès qu'une bille non frappée atteint le point idéal.
	for b: Dictionary in _balls:
		var pos: Vector2 = b["p"]
		if bool(b["kicked"]):
			continue
		var side: int = _kick_side(pos)
		if side >= 0 and pos.y >= KICK_Y - 6.0:
			return {"do": "sym", "symbol": 0 if side == 0 else 2}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "sym":
		_bot_side = 0 if int(w.get("symbol", 0)) == 0 else 1
	else:
		_bot_side = -1


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Caisson laqué rouge, néons, plateau de laiton.
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("140812"))
	for k: int in 14:
		var lx: float = -size.x * 0.5 + float(k) * 260.0
		draw_rect(Rect2(lx, 0, 6, size.y), Color(Palette.MAGENTA, 0.06 + 0.04 * sin(_lights * 2.0 + k)))
	var case_r: Rect2 = BOARD.grow(46.0)
	draw_rect(case_r, Color("5a0c18"))
	draw_rect(case_r, Palette.GOLD, false, 4.0)
	for k2: int in 24:
		var a: float = float(k2) / 24.0
		var bulb: Vector2 = case_r.position + Vector2(case_r.size.x * a, 0) + Vector2(12, 18)
		var on: bool = int(_lights * 8.0 + k2) % 3 == 0
		draw_circle(bulb, 7.0, Palette.GOLD_LIGHT if on else Palette.GOLD_DARK)
		draw_circle(Vector2(bulb.x, case_r.end.y - 18), 7.0, Palette.GOLD_LIGHT if not on else Palette.GOLD_DARK)
	draw_rect(BOARD, Color("2a2018"))
	draw_rect(BOARD, Color(Palette.GOLD, 0.15))
	for peg: Vector2 in _pegs:
		draw_circle(peg + Vector2(2, 3), PEG_R, Color(0, 0, 0, 0.4))
		draw_circle(peg, PEG_R, Color("d8d0c0"))
	# Lanceur.
	var lx2: float = _launcher_x()
	draw_rect(Rect2(lx2 - 30, LAUNCH_Y - 40, 60, 22), Palette.GOLD)
	draw_line(Vector2(BOARD.position.x, LAUNCH_Y - 30), Vector2(BOARD.end.x, LAUNCH_Y - 30), Palette.GOLD_DARK, 2.0)
	# Entonnoir, taquets, godets.
	var c: float = _center()
	draw_line(Vector2(BOARD.position.x, FUNNEL_Y), Vector2(c - KICK_GAP * 0.5 - KICK_HALF_W * 2.0, KICK_Y - 30), Palette.GOLD_DARK, 4.0)
	draw_line(Vector2(BOARD.end.x, FUNNEL_Y), Vector2(c + KICK_GAP * 0.5 + KICK_HALF_W * 2.0, KICK_Y - 30), Palette.GOLD_DARK, 4.0)
	for s: int in 2:
		var dir: float = -1.0 if s == 0 else 1.0
		var x0: float = c + dir * (KICK_GAP * 0.5 + KICK_HALF_W * 2.0)
		var x1: float = c + dir * KICK_GAP * 0.5
		var lift: float = 30.0 * _kick[s]
		var zone: Rect2 = Rect2(minf(x0, x1), KICK_Y - p("kick_window") * widen(), absf(x1 - x0), p("kick_window") * widen() * 2.0)
		draw_rect(zone, Color(Palette.CYAN, 0.06 + 0.15 * _kick[s]))
		draw_line(Vector2(x0, KICK_Y + 10), Vector2(x1, KICK_Y - lift), Palette.CYAN if _kick[s] > 0.0 else Palette.IVORY, 8.0)
	draw_rect(Rect2(c - SILVER_HALF, CUP_Y - 10, SILVER_HALF * 2.0, 50), Color("8a8a96"))
	draw_rect(Rect2(c - GOLD_HALF, CUP_Y - 10, GOLD_HALF * 2.0, 50), Palette.GOLD)
	draw_rect(Rect2(BOARD.position.x, CUP_Y - 10, c - SILVER_HALF - BOARD.position.x, 50), Color("201418"))
	draw_rect(Rect2(c + SILVER_HALF, CUP_Y - 10, BOARD.end.x - c - SILVER_HALF, 50), Color("201418"))
	for b: Dictionary in _balls:
		var pos: Vector2 = b["p"]
		draw_circle(pos, BALL_R, Color("e8e8f0"))
		draw_circle(pos - Vector2(4, 4), BALL_R * 0.35, Color.WHITE)
	# Pastilles : billes jouées.
	pips(Vector2(c, 70.0), _scores, pi("balls"))
