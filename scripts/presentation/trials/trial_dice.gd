class_name TrialDice
extends ThrowTrial
## LES DÉS (écran dédié, table de craps vue de dessus) : trois lancers. On vise (stick, flèches,
## souris), puis on maintient pour charger la force (la jauge monte et redescend) et on lâche.
## Les dés doivent toucher la bande du fond (règle du craps), rebondir et s'arrêter dans la
## zone dorée, qui change à chaque lancer. On note la position d'arrêt, jamais la face.
## Note = moyenne de la proximité au centre de la zone (sans bande touchée : note réduite).

const TABLE: Rect2 = Rect2(260.0, 170.0, 1400.0, 760.0)
const START: Vector2 = Vector2(960.0, 880.0)
const DIE: float = 52.0
const PAIR_GAP: float = 30.0
const AIM_LIMIT: float = 1.1
const ZONE_X: Vector2 = Vector2(520.0, 1400.0)
const ZONE_Y: Vector2 = Vector2(520.0, 720.0)
const PIPS: Dictionary[int, Array] = {
	1: [Vector2(0, 0)], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}
## Décor 3D (caméra frontale = vue de dessus) : mètres par pixel, normale de chaque face du dé
## (faces opposées = 7, +z regarde la caméra), pas des pyramides de la bande, vitesse de pose.
const PX3: float = 0.005
const FACE_N: Dictionary[int, Vector3] = {
	1: Vector3(0, 0, 1), 6: Vector3(0, 0, -1), 2: Vector3(0, 1, 0), 5: Vector3(0, -1, 0), 3: Vector3(1, 0, 0), 4: Vector3(-1, 0, 0),
}
const PYRAMID_STEP: float = 28.0
const SETTLE: float = 10.0
const CHIP_COLORS: Array[Color] = [Color("d11a3c"), Color("1f6fd1"), Color("1e9e5a"), Color("ece4d0"), Color("1a1a1a")]

var _throw: int = 0
var _aim: float = 0.0
var _charge: float = 0.0
var _charge_dir: float = 1.0
var _charging: bool = false
var _flying: bool = false
var _pos: Vector2 = START
var _vel: Vector2 = Vector2.ZERO
var _wall: bool = false
var _spin: float = 0.0
var _faces: Array[int] = [1, 1]
var _zone: Vector2 = Vector2.ZERO
var _scores: Array[float] = []
var _rest_t: float = 0.0
var _mouse_pos: Vector2 = Vector2(-1, -1)
var _bot_aim: float = 0.0
var _bot_mode: String = ""
var _trail: Array[Vector2] = []
var _wait: float = 0.0
var _dice3: Array[Node3D] = []
var _zone3: MeshInstance3D = null
var _halo3: MeshInstance3D = null
var _yaw: Array[float] = [0.0, 0.0]


func begin() -> void:
	_new_zone()
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("0c0810")
	st.env.ambient_light_energy = 0.45
	var r: Node3D = st.root
	Stage3D.box(r, Vector3(30, 20, 0.05), st.to3(Vector2(960, 540), -0.4), Stage3D.mat(Color("140a10"), 0.0, 0.9))
	# Feutre, bande de bois vernie et liseré doré.
	Stage3D.box(r, Vector3(TABLE.size.x * PX3, TABLE.size.y * PX3, 0.04), st.to3(TABLE.get_center(), -0.02),
		Stage3D.textured("felt", Color(0.1, 0.36, 0.22), 0.6))
	var wood: StandardMaterial3D = Stage3D.textured("wood", Color("8a5a34"), 1.0, 0.0, 0.3)
	wood.clearcoat_enabled = true
	wood.clearcoat = 0.6
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.35)
	var g: Rect2 = TABLE.grow(40.0)
	for e: Array in [[Vector2(g.get_center().x, g.position.y + 20.0), Vector2(g.size.x, 40.0)],
			[Vector2(g.get_center().x, g.end.y - 20.0), Vector2(g.size.x, 40.0)],
			[Vector2(g.position.x + 20.0, g.get_center().y), Vector2(40.0, g.size.y)],
			[Vector2(g.end.x - 20.0, g.get_center().y), Vector2(40.0, g.size.y)]]:
		var sz: Vector2 = e[1]
		Stage3D.box(r, Vector3(sz.x * PX3, sz.y * PX3, 0.22), st.to3(e[0] as Vector2, 0.09), wood)
	for e2: Array in [[Vector2(TABLE.get_center().x, TABLE.position.y - 7.0), Vector2(TABLE.size.x + 28.0, 14.0)],
			[Vector2(TABLE.get_center().x, TABLE.end.y + 7.0), Vector2(TABLE.size.x + 28.0, 14.0)],
			[Vector2(TABLE.position.x - 7.0, TABLE.get_center().y), Vector2(14.0, TABLE.size.y)],
			[Vector2(TABLE.end.x + 7.0, TABLE.get_center().y), Vector2(14.0, TABLE.size.y)]]:
		var sz2: Vector2 = e2[1]
		Stage3D.box(r, Vector3(sz2.x * PX3, sz2.y * PX3, 0.05), st.to3(e2[0] as Vector2, 0.01), gilt)
	# Bande du fond à pyramides de caoutchouc doré (le mur de rebond).
	var pyr_m: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.3, 0.4)
	var x: float = TABLE.position.x + PYRAMID_STEP * 0.5
	while x < TABLE.end.x:
		var pyr: MeshInstance3D = Stage3D.cylinder(r, PYRAMID_STEP * 0.5 * PX3, 0.08, st.to3(Vector2(x, TABLE.position.y + 8.0), 0.03),
			pyr_m, 0.0)
		pyr.rotation.x = PI * 0.5
		x += PYRAMID_STEP
	# Marquages du feutre.
	Stage3D.box(r, Vector3((TABLE.size.x - 120.0) * PX3, 6.0 * PX3, 0.003), st.to3(Vector2(TABLE.get_center().x, TABLE.end.y - 227.0), 0.0),
		Stage3D.mat(Palette.IVORY.darkened(0.6), 0.0, 0.9))
	for m: Array in [["PASS LINE", TABLE.position.x + 220.0], ["COME", TABLE.end.x - 220.0], ["FIELD", TABLE.get_center().x]]:
		var lbl: Label3D = Stage3D.text3d(r, String(m[0]), st.to3(Vector2(float(m[1]), TABLE.end.y - 262.0), 0.002), 56,
			Palette.IVORY.darkened(0.55), Color(0, 0, 0, 0))
		lbl.pixel_size = 0.0035
	# Palet « ON » du croupier et piles de jetons sur la bande.
	var puck: MeshInstance3D = Stage3D.cylinder(r, 34.0 * PX3, 0.03,
		st.to3(Vector2(TABLE.position.x + 120.0, TABLE.position.y + 110.0), 0.015),
		Stage3D.mat(Palette.IVORY, 0.0, 0.5))
	puck.rotation.x = PI * 0.5
	var on_lbl: Label3D = Stage3D.text3d(r, "ON", st.to3(Vector2(TABLE.position.x + 120.0, TABLE.position.y + 110.0), 0.035), 40,
		Palette.INK,
		Color(0, 0, 0, 0))
	on_lbl.pixel_size = 0.003
	for k: int in 10:
		var col: Color = CHIP_COLORS[k % CHIP_COLORS.size()]
		var at: Vector2 = Vector2(g.position.x + 160.0 + float(k) * 70.0,
			g.end.y - 20.0) if k < 5 else Vector2(g.end.x - 160.0 - float(k - 5) * 70.0,
			g.end.y - 20.0)
		var stack: MeshInstance3D = Stage3D.cylinder(r, 28.0 * PX3, 0.06 + 0.03 * float(k % 3), st.to3(at, 0.22),
			Stage3D.mat(col, 0.1, 0.4))
		stack.rotation.x = PI * 0.5
	# Zone visée : disque doré lumineux posé sur le feutre, halo de la marge.
	_halo3 = MeshInstance3D.new()
	_halo3.mesh = MeshPool.disc(PX3, 0.002, 48)
	_halo3.material_override = _tint(Palette.GOLD, 0.045)
	_halo3.rotation.x = PI * 0.5
	r.add_child(_halo3)
	_zone3 = MeshInstance3D.new()
	_zone3.mesh = MeshPool.disc(PX3, 0.004, 48)
	_zone3.material_override = _tint(Palette.GOLD, 0.22)
	_zone3.rotation.x = PI * 0.5
	r.add_child(_zone3)
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.96 * PX3
	ring.outer_radius = 1.04 * PX3
	ring.rings = 48
	var rim: MeshInstance3D = MeshInstance3D.new()
	rim.mesh = ring
	rim.material_override = Stage3D.glow(Palette.GOLD_LIGHT, 1.2)
	rim.name = "rim"
	_zone3.add_child(rim)
	for _d: int in 2:
		_dice3.append(_build_die(r))
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.88, 0.66), 1.6, st.to3(Vector2(960.0, 500.0), 3.0), 9.0)
	lamp.shadow_enabled = RenderQuality.shadows()


## Voile coloré translucide, non éclairé (zones dessinées sur le feutre).
func _tint(col: Color, alpha: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(col, alpha)
	return m


## Dé laqué rouge à points ivoire enfoncés, faces opposées = 7.
func _build_die(r: Node3D) -> Node3D:
	var n: Node3D = Node3D.new()
	r.add_child(n)
	var d: float = DIE * PX3
	var body: StandardMaterial3D = Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.2)
	body.clearcoat_enabled = true
	body.clearcoat = 0.8
	Stage3D.box(n, Vector3(d, d, d), Vector3.ZERO, body)
	var pip_m: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.5)
	for f: int in FACE_N.keys():
		var nrm: Vector3 = FACE_N[f]
		var u: Vector3 = Vector3(1, 0, 0) if absf(nrm.x) < 0.5 else Vector3(0, 1, 0)
		var v: Vector3 = nrm.cross(u)
		for pp: Variant in PIPS[f]:
			var q: Vector2 = (pp as Vector2) * d * 0.27
			Stage3D.sphere(n, d * 0.09, nrm * (d * 0.5 - d * 0.04) + u * q.x + v * q.y, pip_m)
	return n


## Orientation qui montre la face `f` à la caméra, tournée de `yaw` sur le feutre.
func _face_quat(f: int, yaw: float) -> Quaternion:
	var nrm: Vector3 = FACE_N[f]
	var arc: Quaternion = Quaternion(Vector3(1, 0, 0),
		PI) if f == 6 else (Quaternion.IDENTITY if f == 1 else Quaternion(nrm, Vector3(0, 0, 1)))
	return Quaternion(Vector3(0, 0, 1), yaw) * arc


func _sync_3d(dt: float) -> void:
	if _dice3.is_empty():
		return
	var st: Stage3D = stage
	var zr: float = _zone_r()
	_zone3.position = st.to3(_zone, 0.001)
	_zone3.scale = Vector3(zr, 1.0, zr)
	_halo3.position = st.to3(_zone, 0.0)
	_halo3.scale = Vector3(zr * (1.0 + p("falloff")), 1.0, zr * (1.0 + p("falloff")))
	var w: float = 1.0 - exp(-SETTLE * dt)
	var roll: Vector3 = Vector3(_vel.y, _vel.x, 0.0)
	for k: int in 2:
		var dx: float = (PAIR_GAP * 0.5 + DIE * 0.25) * (-1.0 if k == 0 else 1.0)
		var die: Node3D = _dice3[k]
		die.position = st.to3(_pos + Vector2(dx, 0), DIE * 0.5 * PX3)
		if _flying and roll.length() > 1.0:
			# Roule dans le sens du mouvement (axe perpendiculaire à la vitesse, sur le feutre).
			var ang: float = _vel.length() * dt / (DIE * 0.5) * (1.0 if k == 0 else 0.85)
			die.quaternion = (Quaternion(roll.normalized(), ang) * die.quaternion).normalized()
			_yaw[k] = _rest_yaw(k)
		else:
			die.quaternion = die.quaternion.slerp(_face_quat(_faces[k], _yaw[k]), w)


## Petit angle de pose différent pour chaque dé (dérivé du lancer, purement visuel).
func _rest_yaw(k: int) -> float:
	return (float(_faces[k]) * 0.37 + float(_throw) * 0.61 + float(k) * 0.9)


func _new_zone() -> void:
	_zone = Vector2(rng.randf_range(ZONE_X.x, ZONE_X.y), rng.randf_range(ZONE_Y.x, ZONE_Y.y))
	_pos = START
	_vel = Vector2.ZERO
	_wall = false
	_flying = false
	_charge = 0.0
	_charge_dir = 1.0
	_trail.clear()
	_wait = 0.0


func _zone_r() -> float:
	return p("zone_radius") * widen()


func _speed_for(charge: float) -> float:
	return lerpf(p("speed_min"), p("speed_max"), charge)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pos = mm.position
		return true
	if confirm_pressed(event):
		_charging = not _flying and _rest_t <= 0.0
		return true
	if confirm_released(event):
		if _charging:
			_release()
		return true
	return false


func _release() -> void:
	_charging = false
	_flying = true
	_vel = Vector2.from_angle(-PI * 0.5 + _aim) * _speed_for(_charge)
	_faces = [rng.randi_range(1, 6), rng.randi_range(1, 6)]
	AudioBus.play("dice", 1.0, -2.0)


func tick(dt: float) -> void:
	if _throw >= pi("throws"):
		return
	if _rest_t > 0.0:
		_rest_t -= dt
		if _rest_t <= 0.0:
			_throw += 1
			if _throw >= pi("throws"):
				finish(ThrowTrial.mean(_scores))
			else:
				_new_zone()
		return
	if not _flying:
		_wait += dt
		if _wait >= p("aim_timeout") * slow:
			_release()  # le croupier perd patience : les dés partent tels quels
			return
		# Visée progressive : stick à fond pour tourner vite, effleuré pour les réglages fins.
		var axis: float = clampf(held_vector().x + _bot_aim, -1.0, 1.0)
		_aim = clampf(_aim + signf(axis) * pow(absf(axis), p("aim_curve")) * p("aim_speed") * dt, -AIM_LIMIT, AIM_LIMIT)
		if mouse and _mouse_pos.x >= 0.0:
			var d: Vector2 = _mouse_pos - START
			if d.length() > 20.0:
				_aim = clampf(atan2(d.x, -d.y), -AIM_LIMIT, AIM_LIMIT)
		if _charging:
			_charge += _charge_dir * dt / (p("charge_seconds") * slow)
			if _charge >= 1.0 or _charge <= 0.0:
				_charge = clampf(_charge, 0.0, 1.0)
				_charge_dir = -_charge_dir

		return
	_roll(dt)


func _process(delta: float) -> void:
	super(delta)
	_sync_3d(delta)


## Glissement sur le feutre : décélération constante, rebond amorti sur les bandes.
func _roll(dt: float) -> void:
	var sp: float = _vel.length()
	var dec: float = p("friction") * dt
	if sp <= dec:
		_vel = Vector2.ZERO
		_settle()
		return
	_vel = _vel * ((sp - dec) / sp)
	_pos += _vel * dt
	_spin += sp * dt * 0.02
	if _trail.is_empty() or _trail[-1].distance_to(_pos) > 18.0:
		_trail.append(_pos)
	var half: float = DIE * 0.5 + PAIR_GAP * 0.5
	if _pos.y < TABLE.position.y + DIE * 0.5:
		_pos.y = TABLE.position.y + DIE * 0.5
		_vel.y = absf(_vel.y) * p("restitution")
		_vel.x *= p("restitution")
		_wall = true
		AudioBus.play("ball_wood", 1.3, -4.0)
	if _pos.x < TABLE.position.x + half or _pos.x > TABLE.end.x - half:
		_pos.x = clampf(_pos.x, TABLE.position.x + half, TABLE.end.x - half)
		_vel.x = -_vel.x * p("restitution")
		AudioBus.play("ball_wood", 1.1, -8.0)
	if _pos.y > TABLE.end.y - DIE * 0.5:
		_pos.y = TABLE.end.y - DIE * 0.5
		_vel.y = -absf(_vel.y) * p("restitution")


func _settle() -> void:
	_flying = false
	var dist: float = _pos.distance_to(_zone)
	var sc: float = clampf(1.0 - maxf(dist - _zone_r() * p("perfect_ratio"), 0.0) / (_zone_r() * p("falloff")), 0.0, 1.0)
	if not _wall:
		sc *= p("no_wall_factor")
		pop(_pos + Vector2(0, -70), 0.0, "TRIAL_DICE_NO_WALL")
	else:
		pop(_pos + Vector2(0, -70), sc)
	_scores.append(sc)
	_rest_t = p("rest_seconds")
	AudioBus.play("chip_place" if sc > 0.5 else "lose_soft", 1.0, -6.0)


# --------------------------------------------------------------------------- bot


## Visée idéale : le reflet de la zone derrière la bande du fond donne l'angle, et la vitesse
## couvre l'aller (décélération) puis le retour après un rebond amorti.
func bot_plan() -> Vector2:
	var wall_y: float = TABLE.position.y + DIE * 0.5
	var mirror: Vector2 = Vector2(_zone.x, 2.0 * wall_y - _zone.y)
	var dir: Vector2 = (mirror - START).normalized()
	var aim: float = atan2(dir.x, -dir.y)
	var hit: Vector2 = START + dir * ((START.y - wall_y) / -dir.y)
	var d1: float = START.distance_to(hit)
	var d2: float = hit.distance_to(_zone)
	var e: float = p("restitution")
	var v_after: float = sqrt(2.0 * p("friction") * d2) / e
	var v0: float = sqrt(v_after * v_after + 2.0 * p("friction") * d1)
	var charge: float = clampf((v0 - p("speed_min")) / (p("speed_max") - p("speed_min")), 0.0, 1.0)
	return Vector2(aim, charge)


func bot_wants() -> Dictionary:
	if _flying or _rest_t > 0.0:
		return {"do": ""}
	var plan: Vector2 = bot_plan()
	var miss: float = plan.x - _aim
	if absf(miss) > p("bot_aim_tolerance") and not _charging:
		# Amplitude mini : un vrai stick a une zone morte.
		return {"do": "axis", "v": Vector2(signf(miss) * clampf(pow(absf(miss) * 8.0, 1.0 / p("aim_curve")), 0.35, 1.0), 0.0)}
	if not _charging:
		return {"do": "hold"}
	# Lâcher quand la jauge croise la force voulue (prévue une image à l'avance).
	var nxt: float = _charge + _charge_dir / 60.0 / (p("charge_seconds") * slow)
	if (_charge - plan.y) * (nxt - plan.y) <= 0.0:
		return {"do": "release"}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	_bot_mode = String(w.get("do", ""))
	_bot_aim = (w.get("v", Vector2.ZERO) as Vector2).x if _bot_mode == "axis" else 0.0
	if _bot_mode == "hold" and not _flying and _rest_t <= 0.0:
		_charging = true
	elif _bot_mode == "release" and _charging:
		_release()


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	for k: int in _trail.size():
		draw_circle(_trail[k], 3.0, Color(Palette.IVORY, 0.15))
	# Visée et jauge.
	if not _flying and _rest_t <= 0.0:
		var dir: Vector2 = Vector2.from_angle(-PI * 0.5 + _aim)
		for k2: int in 10:
			draw_circle(START + dir * (60.0 + float(k2) * 34.0), 5.0 - float(k2) * 0.3, Color(Palette.CYAN, 0.8 - float(k2) * 0.07))
		var g: Rect2 = Rect2(TABLE.end.x + 70.0, TABLE.position.y + 80.0, 40.0, TABLE.size.y - 160.0)
		draw_rect(g, Color(Palette.INK, 0.9))
		draw_rect(Rect2(g.position.x, g.end.y - g.size.y * _charge, g.size.x, g.size.y * _charge),
			Palette.GOLD.lerp(Palette.MULT_RED, _charge))
		draw_rect(g, Palette.GOLD, false, 2.0)
	pips(Vector2(size.x * 0.5, 100.0), _scores, pi("throws"))
