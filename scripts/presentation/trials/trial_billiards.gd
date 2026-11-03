class_name TrialBilliards
extends ThrowTrial
## LE BILLARD (écran dédié, salon du Grand Zéro, vue de dessus) : trois coups, une bille de
## couleur à empocher à chaque coup. Viser (stick, flèches, souris) : un court segment montre
## la trajectoire de la blanche et la « bille fantôme » au contact. Puis maintenir pour doser
## la force (la jauge va et vient) et lâcher. Collisions élastiques, bandes amorties.
## Note = par coup, 1 si la bille est empochée, sinon sa proximité d'une poche ; la blanche
## dans une poche coûte une pénalité.

const TABLE: Rect2 = Rect2(360.0, 230.0, 1200.0, 640.0)
const BALL_R: float = 22.0
const POCKET_R: float = 60.0
const PREVIEW: float = 260.0
## Sous-pas : au plus ≈ 1,5 px par pas à pleine vitesse, pour un point de contact juste.
const SUBSTEPS: int = 24
const BOT_FORCE_STEPS: int = 24
const BOT_SIM_MAX_STEPS: int = 60 * 24 * 8

var _shot: int = 0
var _cue: Vector2 = Vector2.ZERO
var _obj: Vector2 = Vector2.ZERO
var _cue_v: Vector2 = Vector2.ZERO
var _obj_v: Vector2 = Vector2.ZERO
var _obj_in: bool = false
var _cue_in: bool = false
var _aim: float = 0.0
var _charge: float = 0.0
var _charge_dir: float = 1.0
var _charging: bool = false
var _rolling: bool = false
var _rest_t: float = 0.0
var _wait: float = 0.0
var _scores: Array[float] = []
var _mouse_pos: Vector2 = Vector2(-1, -1)
var _bot_aim: float = 0.0
var _bot_force: float = -1.0  # force choisie par le bot pour ce coup (simulée), -1 à recalculer
var _sim: bool = false  # simulation du bot : pas de son
var _colors: Array[Color] = [Color("ffd23f"), Color("ff4d6d"), Color("29e0ff")]


func begin() -> void:
	_rack()


func _pockets() -> Array[Vector2]:
	var c: Vector2 = TABLE.get_center()
	return [TABLE.position, Vector2(c.x, TABLE.position.y), Vector2(TABLE.end.x, TABLE.position.y),
		Vector2(TABLE.position.x, TABLE.end.y), Vector2(c.x, TABLE.end.y), TABLE.end]


## Pose la blanche et la bille de couleur pour un coup jouable (coupe modérée vers une poche).
func _rack() -> void:
	for _try: int in 60:
		var cue: Vector2 = _random_spot(Vector2(120, 110))
		var obj: Vector2 = _random_spot(Vector2(150, 130))
		if cue.distance_to(obj) < 220.0 or cue.distance_to(obj) > 640.0:
			continue
		_cue = cue
		_obj = obj
		if _best_plan().y <= p("max_cut"):
			break
	_cue_v = Vector2.ZERO
	_obj_v = Vector2.ZERO
	_obj_in = false
	_cue_in = false
	_rolling = false
	_charging = false
	_charge = 0.0
	_charge_dir = 1.0
	_wait = 0.0
	_aim = (_obj - _cue).angle()


func _random_spot(margin: Vector2) -> Vector2:
	var x: float = rng.randf_range(TABLE.position.x + margin.x, TABLE.end.x - margin.x)
	return Vector2(x, rng.randf_range(TABLE.position.y + margin.y, TABLE.end.y - margin.y))


## Meilleure visée « bille fantôme » : (angle de la queue, angle de coupe, poche, distance).
func _best_plan() -> Vector4:
	var best: Vector4 = Vector4(0, INF, -1, 0)
	var pockets: Array[Vector2] = _pockets()
	for k: int in pockets.size():
		var to_pocket: Vector2 = (pockets[k] - _obj).normalized()
		var ghost: Vector2 = _obj - to_pocket * BALL_R * 2.0
		var shot: Vector2 = ghost - _cue
		var cut: float = absf(shot.angle_to(to_pocket))
		if cut < best.y:
			best = Vector4(shot.angle(), cut, float(k), 0.0)
	return best


func _speed_for(c: float) -> float:
	return lerpf(p("speed_min"), p("speed_max"), c)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pos = mm.position
		return true
	if confirm_pressed(event):
		_charging = not _rolling and _rest_t <= 0.0
		return true
	if confirm_released(event):
		if _charging:
			_strike()
		return true
	return false


func _strike() -> void:
	_charging = false
	_rolling = true
	_cue_v = Vector2.from_angle(_aim) * _speed_for(_charge)
	AudioBus.play("ball_wood", 1.4, -2.0)


func tick(dt: float) -> void:
	if _shot >= pi("shots"):
		return
	if _rest_t > 0.0:
		_rest_t -= dt
		if _rest_t <= 0.0:
			_shot += 1
			if _shot >= pi("shots"):
				finish(ThrowTrial.mean(_scores))
			else:
				_rack()
		return
	if not _rolling:
		_wait += dt
		if _wait >= p("aim_timeout") * slow:
			_strike()
			return
		# Visée progressive : vitesse en puissance de l'inclinaison, pour les réglages fins.
		var ax: float = clampf(held_vector().x + _bot_aim, -1.0, 1.0)
		_aim += signf(ax) * pow(absf(ax), p("aim_curve")) * p("aim_speed") * dt
		if mouse and _mouse_pos.x >= 0.0 and _mouse_pos.distance_to(_cue) > 30.0:
			_aim = (_mouse_pos - _cue).angle()
		if _charging:
			_charge += _charge_dir * dt / (p("charge_seconds") * slow)
			if _charge >= 1.0 or _charge <= 0.0:
				_charge = clampf(_charge, 0.0, 1.0)
				_charge_dir = -_charge_dir
		return
	var h: float = dt / float(SUBSTEPS)
	for _s: int in SUBSTEPS:
		_physics(h)
	if _cue_v.length() < 4.0 and _obj_v.length() < 4.0:
		_settle()


func _physics(h: float) -> void:
	for k: int in 2:
		var is_cue: bool = k == 0
		if (is_cue and _cue_in) or (not is_cue and _obj_in):
			continue
		var v: Vector2 = _cue_v if is_cue else _obj_v
		var pos: Vector2 = _cue if is_cue else _obj
		var sp: float = v.length()
		var dec: float = p("friction") * h
		v = Vector2.ZERO if sp <= dec else v * ((sp - dec) / sp)
		pos += v * h
		for pk: Vector2 in _pockets():
			if pos.distance_to(pk) < POCKET_R:
				if is_cue:
					_cue_in = true
				else:
					_obj_in = true
				v = Vector2.ZERO
				if not _sim:
					AudioBus.play("ball_land", 1.0, -4.0)
		if pos.x < TABLE.position.x + BALL_R or pos.x > TABLE.end.x - BALL_R:
			pos.x = clampf(pos.x, TABLE.position.x + BALL_R, TABLE.end.x - BALL_R)
			v.x = -v.x * p("cushion")
		if pos.y < TABLE.position.y + BALL_R or pos.y > TABLE.end.y - BALL_R:
			pos.y = clampf(pos.y, TABLE.position.y + BALL_R, TABLE.end.y - BALL_R)
			v.y = -v.y * p("cushion")
		if is_cue:
			_cue_v = v
			_cue = pos
		else:
			_obj_v = v
			_obj = pos
	if _cue_in or _obj_in:
		return
	# Choc élastique de deux billes de même masse : échange des composantes normales.
	var d: Vector2 = _obj - _cue
	if d.length() < BALL_R * 2.0 and d.length() > 0.001:
		var n: Vector2 = d.normalized()
		var rel: float = (_cue_v - _obj_v).dot(n)
		if rel > 0.0:
			_cue_v -= n * rel
			_obj_v += n * rel
			if not _sim:
				AudioBus.play("ball_glass", 1.3, -4.0)
		var push: float = (BALL_R * 2.0 - d.length()) * 0.5
		_cue -= n * push
		_obj += n * push


func _settle() -> void:
	_rolling = false
	_bot_force = -1.0
	var sc: float = 1.0
	if not _obj_in:
		var near: float = INF
		for pk: Vector2 in _pockets():
			near = minf(near, _obj.distance_to(pk))
		sc = p("miss_value") * clampf(1.0 - (near - POCKET_R) / p("near_range"), 0.0, 1.0)
	if _cue_in:
		sc = maxf(0.0, sc - p("scratch_penalty"))
	_scores.append(sc)
	pop(_obj + Vector2(0, -60), sc, "TRIAL_BILLIARDS_POTTED" if _obj_in else ("TRIAL_BILLIARDS_SCRATCH" if _cue_in else ""))
	_rest_t = p("rest_seconds")


# --------------------------------------------------------------------------- bot


## Force voulue : le bot rejoue le coup dans la vraie physique pour quelques forces et garde
## celle qui empoche (la plus proche de l'estimation analytique) ; calculée une fois par coup.
func bot_charge() -> float:
	if _bot_force >= 0.0:
		return _bot_force
	var guess: float = _bot_guess()
	var best: float = guess
	var best_err: float = INF
	for k: int in BOT_FORCE_STEPS + 1:
		var c: float = float(k) / float(BOT_FORCE_STEPS)
		var err: float = _simulate(_best_plan().x, c)
		err += absf(c - guess) * 0.01  # à égalité, la force la plus proche du calcul
		if err < best_err:
			best_err = err
			best = c
	_bot_force = best
	return best


## Joue le coup (angle, force) en accéléré sans toucher à l'état : 0 si la couleur tombe seule,
## sinon distance de la couleur à la poche la plus proche (+ pénalité si la blanche tombe).
func _simulate(angle: float, c: float) -> float:
	var saved: Array = [_cue, _obj, _cue_v, _obj_v, _cue_in, _obj_in]
	_sim = true
	_cue_v = Vector2.from_angle(angle) * _speed_for(c)
	_obj_v = Vector2.ZERO
	var h: float = 1.0 / 60.0 / float(SUBSTEPS)
	var steps: int = 0
	while (_cue_v.length() >= 4.0 or _obj_v.length() >= 4.0) and steps < BOT_SIM_MAX_STEPS:
		_physics(h)
		steps += 1
	var near: float = INF
	for pk: Vector2 in _pockets():
		near = minf(near, _obj.distance_to(pk))
	var err: float = 0.0 if _obj_in else near
	if _cue_in:
		err += 1000.0
	_sim = false
	_cue = saved[0]
	_obj = saved[1]
	_cue_v = saved[2]
	_obj_v = saved[3]
	_cue_in = saved[4]
	_obj_in = saved[5]
	return err


## Estimation analytique : la blanche doit arriver au contact avec assez d'élan pour que la
## couleur, qui reçoit la composante normale (cos de la coupe), atteigne la poche.
func _bot_guess() -> float:
	var plan: Vector4 = _best_plan()
	var pk: Vector2 = _pockets()[int(plan.z)]
	var ghost: Vector2 = _obj - (pk - _obj).normalized() * BALL_R * 2.0
	var d1: float = _cue.distance_to(ghost)
	var d2: float = _obj.distance_to(pk)
	var a: float = p("friction")
	var v_obj: float = sqrt(2.0 * a * d2) * p("bot_margin")
	var v_contact: float = v_obj / maxf(cos(plan.y), 0.3)
	var v0: float = sqrt(v_contact * v_contact + 2.0 * a * d1)
	return clampf((v0 - p("speed_min")) / (p("speed_max") - p("speed_min")), 0.0, 1.0)


func bot_wants() -> Dictionary:
	if _rolling or _rest_t > 0.0:
		return {"do": ""}
	var miss: float = angle_difference(_aim, _best_plan().x)
	if absf(miss) > p("bot_aim_tolerance") and not _charging:
		return {"do": "axis", "v": Vector2(signf(miss) * clampf(pow(absf(miss) * 6.0, 1.0 / p("aim_curve")), 0.35, 1.0), 0.0)}
	if not _charging:
		return {"do": "hold"}
	var target: float = bot_charge()
	var nxt: float = _charge + _charge_dir / 60.0 / (p("charge_seconds") * slow)
	if (_charge - target) * (nxt - target) <= 0.0:
		return {"do": "release"}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	var act: String = String(w.get("do", ""))
	_bot_aim = (w.get("v", Vector2.ZERO) as Vector2).x if act == "axis" else 0.0
	if act == "hold" and not _rolling and _rest_t <= 0.0:
		_charging = true
	elif act == "release" and _charging:
		_strike()


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color("0e0a08"))
	# Lampe de billard, bois, tapis, mouches.
	draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.5 - 200, 0), Vector2(size.x * 0.5 + 200, 0),
		Vector2(TABLE.end.x + 80, size.y), Vector2(TABLE.position.x - 80, size.y)]), Color(1, 0.9, 0.6, 0.04))
	draw_rect(TABLE.grow(54.0), Color("5a3018"))
	draw_rect(TABLE.grow(54.0), Palette.GOLD_DARK, false, 3.0)
	draw_rect(TABLE.grow(16.0), Color("0b5a3a"))
	draw_rect(TABLE, Color("0e6b45"))
	for k: int in 3:
		var dx: float = TABLE.size.x * (0.25 + 0.25 * float(k))
		draw_circle(Vector2(TABLE.position.x + dx, TABLE.position.y - 34), 5.0, Palette.IVORY)
		draw_circle(Vector2(TABLE.position.x + dx, TABLE.end.y + 34), 5.0, Palette.IVORY)
	for pk: Vector2 in _pockets():
		draw_circle(pk, POCKET_R, Color("050302"))
		draw_arc(pk, POCKET_R, 0, TAU, 24, Palette.GOLD_DARK, 3.0)
	if not _obj_in:
		var col: Color = _colors[_shot % _colors.size()]
		draw_circle(_obj + Vector2(3, 4), BALL_R, Color(0, 0, 0, 0.35))
		draw_circle(_obj, BALL_R, col)
		draw_circle(_obj - Vector2(5, 5), 4.0, Color(1, 1, 1, 0.7))
	if not _cue_in:
		draw_circle(_cue + Vector2(3, 4), BALL_R, Color(0, 0, 0, 0.35))
		draw_circle(_cue, BALL_R, Palette.IVORY)
	if not _rolling and _rest_t <= 0.0:
		var dir: Vector2 = Vector2.from_angle(_aim)
		# Segment de visée court et bille fantôme au premier contact.
		var hit: float = PREVIEW
		var to_obj: Vector2 = _obj - _cue
		var along: float = to_obj.dot(dir)
		var perp: float = absf(to_obj.cross(dir))
		if along > 0.0 and perp < BALL_R * 2.0:
			hit = minf(PREVIEW, along - sqrt(BALL_R * BALL_R * 4.0 - perp * perp))
			draw_arc(_cue + dir * hit, BALL_R, 0, TAU, 24, Color(Palette.IVORY, 0.6), 2.0)
		draw_line(_cue + dir * BALL_R, _cue + dir * hit, Color(Palette.IVORY, 0.6), 2.0)
		var back: float = 30.0 + _charge * 120.0
		draw_line(_cue - dir * back, _cue - dir * (back + 420.0), Color("c89a5a"), 10.0)
		draw_line(_cue - dir * back, _cue - dir * (back + 20.0), Palette.IVORY, 10.0)
		var g: Rect2 = Rect2(TABLE.end.x + 90.0, TABLE.position.y + 40.0, 36.0, TABLE.size.y - 80.0)
		draw_rect(g, Color(Palette.INK, 0.9))
		draw_rect(Rect2(g.position.x, g.end.y - g.size.y * _charge, g.size.x, g.size.y * _charge), Palette.GOLD.lerp(Palette.MULT_RED, _charge))
		draw_rect(g, Palette.GOLD, false, 2.0)
	pips(Vector2(size.x * 0.5, 120.0), _scores, pi("shots"))
