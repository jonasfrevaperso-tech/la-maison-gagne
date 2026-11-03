class_name TrialLasers
extends ThrowTrial
## LES LASERS DU COFFRE (écran dédié, vue de dessus) : traverser la salle des coffres du
## Grand Zéro jusqu'à la porte blindée. Des faisceaux rouges balaient la pièce : pendules qui
## pivotent, barrières qui glissent, rideaux qui clignotent. Déplacement libre (stick, flèches,
## souris). Touché : alarme, recul et un instant d'immobilité.
## Note = arrivée (plus tôt = mieux) ou part du chemin parcouru, moins les faisceaux touchés.

const ROOM: Rect2 = Rect2(220.0, 220.0, 1480.0, 720.0)
const START: Vector2 = Vector2(290.0, 580.0)
const DOOR: Rect2 = Rect2(1630.0, 500.0, 60.0, 160.0)
const BODY_R: float = 18.0
const BEAM_W: float = 6.0
const LOOK_STEPS: int = 8
const BOT_DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(0.7, -0.7), Vector2(0.7, 0.7), Vector2(0, -1), Vector2(0, 1), Vector2.ZERO,
	Vector2(-1, 0)]

var _pos: Vector2 = START
var _beams: Array[Dictionary] = []
var _hits: int = 0
var _stun: float = 0.0
var _invuln: float = 0.0
var _alarm: float = 0.0
var _best_x: float = START.x
var _mouse_pos: Vector2 = Vector2(-1, -1)
var _bot_v: Vector2 = Vector2.ZERO
var _ended: bool = false


func begin() -> void:
	# Quatre bandes de la salle, chacune gardée par un faisceau tiré au hasard (type et phase).
	var kinds: Array[String] = ["sweep", "slide", "blink", "sweep"]
	for i: int in range(kinds.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	for k: int in kinds.size():
		var x: float = ROOM.position.x + p("first_beam") + float(k) * p("beam_spacing")
		var b: Dictionary = {"kind": kinds[k], "x": x, "ph": rng.randf() * TAU, "w": p("beam_speed") * rng.randf_range(0.85, 1.15)}
		match kinds[k]:
			"sweep":
				b["pivot"] = Vector2(x, ROOM.position.y if k % 2 == 0 else ROOM.end.y)
			"blink":
				b["gap"] = rng.randf_range(ROOM.position.y + 160.0, ROOM.end.y - 160.0)
		_beams.append(b)


func _dur() -> float:
	return p("duration") * slow


## Segments actifs du faisceau `b` à l'instant `at`.
func _segments(b: Dictionary, at: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var w: float = float(b["w"]) / slow
	var ph: float = float(b["ph"])
	match String(b["kind"]):
		"sweep":
			var pv: Vector2 = b["pivot"]
			var down: float = 1.0 if pv.y <= ROOM.position.y else -1.0
			var a: float = sin(at * w + ph) * p("sweep_amp")
			var dir: Vector2 = Vector2(sin(a), cos(a) * down)
			# Pendule plus court que la salle : on passe du côté opposé au pivot.
			out.append(PackedVector2Array([pv, pv + dir * ROOM.size.y * p("sweep_len")]))
		"slide":
			# Barrière horizontale qui monte et descend sur toute la largeur de sa bande.
			var y: float = ROOM.get_center().y + sin(at * w * 0.8 + ph) * (ROOM.size.y * 0.5 - 40.0)
			var x: float = float(b["x"])
			out.append(PackedVector2Array([Vector2(x - p("slide_half"), y), Vector2(x + p("slide_half"), y)]))
			out.append(PackedVector2Array([Vector2(x, y - 4.0), Vector2(x, y + 4.0)]))
		"blink":
			# Rideau vertical percé d'une ouverture, allumé une partie du cycle.
			if fmod(at * w * 0.25 + ph, 1.0) < p("blink_on"):
				var x2: float = float(b["x"])
				var gap: float = float(b["gap"])
				var half: float = p("blink_gap") * 0.5 * widen()
				out.append(PackedVector2Array([Vector2(x2, ROOM.position.y), Vector2(x2, gap - half)]))
				out.append(PackedVector2Array([Vector2(x2, gap + half), Vector2(x2, ROOM.end.y)]))
	return out


func _hit_at(pos: Vector2, at: float) -> bool:
	for b: Dictionary in _beams:
		for s: PackedVector2Array in _segments(b, at):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(pos, s[0], s[1])
			if q.distance_to(pos) < BODY_R + BEAM_W * 0.5:
				return true
	return false


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pos = mm.position
		return true
	return false


func tick(dt: float) -> void:
	if _ended:
		return
	_stun = maxf(0.0, _stun - dt)
	_invuln = maxf(0.0, _invuln - dt)
	_alarm = maxf(0.0, _alarm - dt)
	var v: Vector2 = (held_vector() + _bot_v).limit_length(1.0)
	if mouse and _mouse_pos.x >= 0.0:
		var d: Vector2 = _mouse_pos - _pos
		v = d / maxf(d.length(), 60.0)
	if _stun <= 0.0:
		_pos += v * p("move_speed") * dt
	_pos = _pos.clamp(ROOM.position + Vector2.ONE * BODY_R, ROOM.end - Vector2.ONE * BODY_R)
	_best_x = maxf(_best_x, _pos.x)
	if _invuln <= 0.0 and _hit_at(_pos, t):
		_hits += 1
		_stun = p("hit_stun")
		_invuln = p("hit_invuln")
		_alarm = 1.0
		_pos.x = maxf(START.x, _pos.x - p("knockback"))
		pop(_pos + Vector2(0, -60), 0.0, "TRIAL_LASERS_ALARM")
		AudioBus.play("deadline", 1.4, -6.0)
	if DOOR.grow(BODY_R).has_point(_pos):
		_end(true)
	elif t >= _dur():
		_end(false)


func _end(reached: bool) -> void:
	_ended = true
	var sc: float = 0.0
	if reached:
		AudioBus.play("vault", 1.0, -4.0)
		sc = p("arrive_base") + (1.0 - p("arrive_base")) * clampf(1.0 - t / _dur(), 0.0, 1.0) / p("time_scale")
	else:
		sc = p("partial_weight") * clampf((_best_x - START.x) / (DOOR.position.x - START.x), 0.0, 1.0)
	finish(clampf(sc - p("hit_penalty") * float(_hits), 0.0, 1.0))


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Vise un point de passage (l'ouverture du prochain rideau, sinon la porte), prévoit les
	# faisceaux sur un court horizon et prend la direction sûre qui y mène le mieux.
	var way: Vector2 = DOOR.get_center()
	for b: Dictionary in _beams:
		var bx: float = float(b["x"])
		if bx > _pos.x - BODY_R and bx < way.x:
			if String(b["kind"]) == "blink":
				way = Vector2(bx + 80.0, float(b["gap"]))
			break
	var to_way: Vector2 = (way - _pos).normalized()
	var options: Array[Vector2] = [to_way]
	options.append_array(BOT_DIRS)
	var best: Vector2 = Vector2(-1, 0)
	var best_score: float = -INF
	for dirv: Vector2 in options:
		if not _safe(dirv):
			continue
		var sc: float = dirv.dot(to_way) if dirv != Vector2.ZERO else -0.15
		if sc > best_score:
			best_score = sc
			best = dirv
	return {"do": "axis", "v": best}


func _safe(dirv: Vector2) -> bool:
	var q: Vector2 = _pos
	var dtk: float = p("bot_horizon") / float(LOOK_STEPS)
	for s: int in LOOK_STEPS:
		q = (q + dirv * p("move_speed") * dtk).clamp(ROOM.position + Vector2.ONE * BODY_R, ROOM.end - Vector2.ONE * BODY_R)
		if _hit_at(q, t + dtk * float(s + 1)):
			return false
	return true


func bot_apply(w: Dictionary) -> void:
	_bot_v = (w.get("v", Vector2.ZERO) as Vector2) if String(w.get("do", "")) == "axis" else Vector2.ZERO


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("07090c"))
	# Sol de la salle des coffres : dalles d'acier, coffres aux murs.
	draw_rect(ROOM.grow(30.0), Color("3a3e48"))
	draw_rect(ROOM, Color("15181e"))
	var x: float = ROOM.position.x
	while x < ROOM.end.x:
		draw_line(Vector2(x, ROOM.position.y), Vector2(x, ROOM.end.y), Color(1, 1, 1, 0.03), 2.0)
		x += 80.0
	var y: float = ROOM.position.y
	while y < ROOM.end.y:
		draw_line(Vector2(ROOM.position.x, y), Vector2(ROOM.end.x, y), Color(1, 1, 1, 0.03), 2.0)
		y += 80.0
	for k: int in 16:
		var bx: float = ROOM.position.x + 20.0 + float(k) * 92.0
		for row: float in [ROOM.position.y - 26.0, ROOM.end.y + 4.0]:
			draw_rect(Rect2(bx, row, 80, 22), Color("4a505c"))
			draw_circle(Vector2(bx + 40, row + 11), 6.0, Palette.GOLD_DARK)
	# Porte blindée.
	draw_rect(DOOR, Palette.GOLD_DARK)
	draw_circle(DOOR.get_center(), 26.0, Palette.GOLD)
	for k2: int in 6:
		var a: float = TAU * float(k2) / 6.0 + t
		draw_line(DOOR.get_center(), DOOR.get_center() + Vector2.from_angle(a) * 24.0, Palette.GOLD_DARK, 3.0)
	# Faisceaux.
	for b: Dictionary in _beams:
		for s: PackedVector2Array in _segments(b, t):
			draw_line(s[0], s[1], Color(1, 0.1, 0.15, 0.25), BEAM_W * 4.0)
			draw_line(s[0], s[1], Color(1, 0.2, 0.2, 0.95), BEAM_W)
		if String(b["kind"]) == "sweep":
			draw_circle(b["pivot"] as Vector2, 14.0, Color("9a9aa4"))
	# Cambrioleur (vu de dessus) et alarme.
	var col: Color = Palette.IVORY if _invuln <= 0.0 or fmod(t * 10.0, 1.0) < 0.5 else Palette.MULT_RED
	draw_circle(_pos, BODY_R, Palette.INK)
	draw_circle(_pos, BODY_R - 4.0, col)
	draw_circle(_pos + Vector2(6, 0), 5.0, Palette.INK)
	if _alarm > 0.0:
		draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color(1, 0, 0, 0.18 * _alarm))
	var prog: float = clampf((_best_x - START.x) / (DOOR.position.x - START.x), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 130, 600, 10), Color(Palette.INK, 0.9))
	draw_rect(Rect2(size.x * 0.5 - 300, 130, 600 * prog, 10), Palette.GOLD)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 146, 600 * left, 6), Palette.CYAN)
	text(Vector2(size.x * 0.5, 100.0), tr("TRIAL_LASERS_STATUS") % _hits, UiKit.SIZE_BODY, Palette.IVORY)
