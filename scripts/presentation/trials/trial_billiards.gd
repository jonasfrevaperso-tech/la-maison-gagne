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
## Décor 3D (caméra frontale = vue de dessus) : mètres par pixel, largeur des bandes, queue.
const PX3: float = 0.005
const RAIL_PX: float = 54.0
const CUSHION_PX: float = 16.0
const CUE_LEN: float = 420.0

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
var _cue3: Node3D = null
var _obj3: Node3D = null
var _obj_mat: StandardMaterial3D = null
var _stick3: Node3D = null
var _last_cue: Vector2 = Vector2.ZERO
var _last_obj: Vector2 = Vector2.ZERO


func begin() -> void:
	_rack()
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("0e0a08")
	st.env.ambient_light_energy = 0.3
	st.key.light_energy = 0.2
	var r: Node3D = st.root
	Stage3D.box(r, Vector3(30, 20, 0.05), st.to3(Vector2(960, 540), -0.3), Stage3D.mat(Color("1a100c"), 0.0, 0.9))
	# Tapis, bandes de feutre, cadre d'acajou verni et mouches de nacre.
	Stage3D.box(r, Vector3((TABLE.size.x + CUSHION_PX * 2.0) * PX3, (TABLE.size.y + CUSHION_PX * 2.0) * PX3, 0.04),
		st.to3(TABLE.get_center(), -0.02),
		Stage3D.mat(Color("0a5034"), 0.0, 0.95))
	var cushion: StandardMaterial3D = Stage3D.mat(Color("08422b"), 0.0, 0.9)
	var wood: StandardMaterial3D = Stage3D.mat(Color("5a2a12"), 0.0, 0.3)
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.8
	var g: Rect2 = TABLE.grow(RAIL_PX)
	var cg: Rect2 = TABLE.grow(CUSHION_PX)
	for e: Array in [[Rect2(g.position, Vector2(g.size.x, RAIL_PX - CUSHION_PX)), 0.16],
			[Rect2(Vector2(g.position.x, cg.end.y), Vector2(g.size.x, RAIL_PX - CUSHION_PX)), 0.16],
			[Rect2(Vector2(g.position.x, cg.position.y), Vector2(RAIL_PX - CUSHION_PX, cg.size.y)), 0.16],
			[Rect2(Vector2(cg.end.x, cg.position.y), Vector2(RAIL_PX - CUSHION_PX, cg.size.y)), 0.16]]:
		var rr: Rect2 = e[0]
		Stage3D.box(r, Vector3(rr.size.x * PX3, rr.size.y * PX3, float(e[1])), st.to3(rr.get_center(), float(e[1]) * 0.5), wood)
	for e2: Rect2 in [Rect2(cg.position, Vector2(cg.size.x, CUSHION_PX)),
		Rect2(Vector2(cg.position.x, TABLE.end.y), Vector2(cg.size.x, CUSHION_PX)),
			Rect2(cg.position, Vector2(CUSHION_PX, cg.size.y)), Rect2(Vector2(TABLE.end.x, cg.position.y), Vector2(CUSHION_PX, cg.size.y))]:
		Stage3D.box(r, Vector3(e2.size.x * PX3, e2.size.y * PX3, 0.07), st.to3(e2.get_center(), 0.035), cushion)
	var pearl: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.2, 0.2)
	for k: int in 3:
		var dx: float = TABLE.size.x * (0.25 + 0.25 * float(k))
		for y: float in [TABLE.position.y - 34.0, TABLE.end.y + 34.0]:
			Stage3D.sphere(r, 5.0 * PX3, st.to3(Vector2(TABLE.position.x + dx, y), 0.16), pearl)
	# Poches : trou noir, rebord doré.
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.3)
	for pk: Vector2 in _pockets():
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = POCKET_R * PX3
		ring.outer_radius = (POCKET_R + 9.0) * PX3
		ring.rings = 32
		var rim: MeshInstance3D = MeshInstance3D.new()
		rim.mesh = ring
		rim.material_override = gilt
		rim.rotation.x = PI * 0.5
		rim.position = st.to3(pk, 0.18)
		r.add_child(rim)
		var hole: MeshInstance3D = Stage3D.cylinder(r, POCKET_R * PX3, 0.2, st.to3(pk, 0.078), Stage3D.mat(Color("050302"), 0.0, 1.0))
		hole.rotation.x = PI * 0.5
	# Billes laquées : la blanche et la bille de couleur, avec une pastille qui montre le roulement.
	_cue3 = _build_ball(Palette.IVORY, Color("d11a3c"))
	_obj_mat = Stage3D.mat(_colors[0], 0.0, 0.15)
	_obj_mat.clearcoat_enabled = true
	_obj_mat.clearcoat = 1.0
	_obj3 = _build_ball(_colors[0], Palette.IVORY, _obj_mat)
	# Queue : flèche d'érable, bague de laiton, procédé bleu, talon d'ébène.
	_stick3 = Node3D.new()
	r.add_child(_stick3)
	var shaft: MeshInstance3D = Stage3D.cylinder(_stick3, 7.0 * PX3, CUE_LEN * PX3, Vector3(-CUE_LEN * 0.5 * PX3, 0, 0),
		Stage3D.mat(Color("d8b07a"), 0.0, 0.4), 5.0 * PX3)
	shaft.rotation.z = -PI * 0.5
	var butt: MeshInstance3D = Stage3D.cylinder(_stick3, 9.0 * PX3, 140.0 * PX3, Vector3(-(CUE_LEN - 70.0) * PX3, 0, 0),
		Stage3D.mat(Color("1a0e08"), 0.0, 0.3))
	butt.rotation.z = -PI * 0.5
	var ferrule: MeshInstance3D = Stage3D.cylinder(_stick3, 5.5 * PX3, 16.0 * PX3, Vector3(-8.0 * PX3, 0, 0),
		Stage3D.mat(Palette.IVORY, 0.0, 0.4))
	ferrule.rotation.z = -PI * 0.5
	var tip: MeshInstance3D = Stage3D.cylinder(_stick3, 5.5 * PX3, 4.0 * PX3, Vector3(0, 0, 0), Stage3D.mat(Color("2a5aa0"), 0.0, 0.8))
	tip.rotation.z = -PI * 0.5
	# Lampe de billard : deux spots chauds au-dessus du tapis.
	for x: float in [-1.0, 1.0]:
		var spot: SpotLight3D = SpotLight3D.new()
		spot.light_color = Color(1.0, 0.9, 0.7)
		spot.light_energy = 2.6
		spot.spot_range = 8.0
		spot.spot_angle = 40.0
		spot.position = st.to3(TABLE.get_center() + Vector2(x * TABLE.size.x * 0.25, 0), 3.0)
		r.add_child(spot)
		spot.shadow_enabled = RenderQuality.shadows()
	_last_cue = _cue
	_last_obj = _obj


func _build_ball(col: Color, dot: Color, m: StandardMaterial3D = null) -> Node3D:
	var n: Node3D = Node3D.new()
	stage.root.add_child(n)
	var lacquer: StandardMaterial3D = m
	if lacquer == null:
		lacquer = Stage3D.mat(col, 0.0, 0.15)
		lacquer.clearcoat_enabled = true
		lacquer.clearcoat = 1.0
	Stage3D.sphere(n, BALL_R * PX3, Vector3.ZERO, lacquer)
	for f: float in [-1.0, 1.0]:
		var d: MeshInstance3D = Stage3D.cylinder(n, BALL_R * 0.42 * PX3, BALL_R * 0.2 * PX3, Vector3(0, 0, f * BALL_R * 0.93 * PX3),
			Stage3D.mat(dot, 0.0, 0.3))
		d.rotation.x = PI * 0.5
	return n


## La bille roule sans glisser : rotation autour de l'axe perpendiculaire au déplacement.
func _roll3(n: Node3D, from: Vector2, to: Vector2) -> void:
	var d: Vector2 = to - from
	if d.length() < 0.01 or d.length() > 200.0:
		return
	var axis: Vector3 = Vector3(d.y, d.x, 0).normalized()
	n.quaternion = (Quaternion(axis, d.length() / BALL_R) * n.quaternion).normalized()


func _process(delta: float) -> void:
	super(delta)
	if _cue3 == null:
		return
	var st: Stage3D = stage
	_obj_mat.albedo_color = _colors[_shot % _colors.size()]
	_roll3(_cue3, _last_cue, _cue)
	_roll3(_obj3, _last_obj, _obj)
	_last_cue = _cue
	_last_obj = _obj
	_cue3.visible = not _cue_in
	_obj3.visible = not _obj_in
	_cue3.position = st.to3(_cue, BALL_R * PX3)
	_obj3.position = st.to3(_obj, BALL_R * PX3)
	var aiming: bool = not _rolling and _rest_t <= 0.0 and _shot < pi("shots")
	_stick3.visible = aiming
	if aiming:
		var dir: Vector2 = Vector2.from_angle(_aim)
		var back: float = 30.0 + _charge * 120.0
		_stick3.position = st.to3(_cue - dir * back, BALL_R * PX3 * 1.3)
		_stick3.rotation = Vector3(0, 0.08, -_aim)


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
	if stage == null:
		return
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
		var g: Rect2 = Rect2(TABLE.end.x + 90.0, TABLE.position.y + 40.0, 36.0, TABLE.size.y - 80.0)
		draw_rect(g, Color(Palette.INK, 0.9))
		draw_rect(Rect2(g.position.x, g.end.y - g.size.y * _charge, g.size.x, g.size.y * _charge),
			Palette.GOLD.lerp(Palette.MULT_RED, _charge))
		draw_rect(g, Palette.GOLD, false, 2.0)
	pips(Vector2(size.x * 0.5, 120.0), _scores, pi("shots"))
