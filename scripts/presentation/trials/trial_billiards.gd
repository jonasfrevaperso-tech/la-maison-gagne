class_name TrialBilliards
extends ThrowTrial
## LE BILLARD (écran dédié, salon du Grand Zéro, vue de dessus) : quatre coups, une bille de
## couleur à empocher à chaque coup. Visée (1.9) : trajectoire complète jusqu'au premier rebond,
## bille fantôme au contact, direction prévue de la couleur et déviation de la blanche ; poche
## visée mise en évidence. Manette / clavier : viser, maintenir pour doser (la jauge va et vient),
## lâcher. Souris / doigt : lance-pierre depuis la blanche (tirer en arrière dose la force, revenir
## sur la bille annule, toucher ailleurs ne tire jamais). Collisions élastiques, bandes amorties.
## Note = par coup, 1 si la bille est empochée, sinon sa proximité d'une poche ; la blanche
## dans une poche coûte une pénalité.
## 2.0 : d'autres billes sur le tapis. La NOIRE est interdite : la blanche ne doit pas la
## toucher (pénalité), et l'empocher annule le coup ; une bille neutre gêne. Avant de tirer, on
## choisit l'EFFET : coulé (la blanche suit), rétro (elle revient) ou aucun — haut / bas, clic
## droit ou la pastille d'effet au doigt.

const TABLE: Rect2 = Rect2(360.0, 230.0, 1200.0, 640.0)
const BALL_R: float = 22.0
const POCKET_R: float = 60.0
## Longueur maximale tracée après le premier rebond, flèches de la couleur et de la blanche.
const PREVIEW_BOUNCE: float = 420.0
const OBJ_ARROW: float = 360.0
const CUE_ARROW: float = 200.0
## Chute dans la poche (s) : la bille glisse vers le centre et rapetisse.
const SINK_TIME: float = 0.3
## Sous-pas : au plus ≈ 1,5 px par pas à pleine vitesse, pour un point de contact juste.
const SUBSTEPS: int = 24
const BOT_FORCE_STEPS: int = 24
const BOT_SIM_MAX_STEPS: int = 60 * 24 * 8
## Décor 3D (caméra frontale = vue de dessus) : mètres par pixel, largeur des bandes, queue.
const PX3: float = 0.005
const RAIL_PX: float = 54.0
const CUSHION_PX: float = 16.0
const CUE_LEN: float = 420.0
## Billes en plus : la noire (interdite) puis les neutres ; pastille d'effet (coin du tapis).
const BLACK: Color = Color("15151a")
const NEUTRAL: Color = Color("8a5cd6")
const SPIN_KEYS: Array[String] = ["TRIAL_BILLIARDS_SPIN_DRAW", "TRIAL_BILLIARDS_SPIN_NONE", "TRIAL_BILLIARDS_SPIN_FOLLOW"]
const SPIN_BOX: Rect2 = Rect2(130.0, 700.0, 150.0, 150.0)

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
## Lance-pierre (souris / doigt) : glissé en cours depuis la blanche, et point tiré.
var _sling: bool = false
var _sling_at: Vector2 = Vector2.ZERO
## Chute animée : [poche, temps restant] de la couleur et de la blanche.
var _sink_obj: Array = []
var _sink_cue: Array = []
var _pulse: float = 0.0
## Billes en plus (0 : la noire, puis les neutres) : positions, vitesses, empochées.
var _xp: Array[Vector2] = []
var _xv: Array[Vector2] = []
var _xin: Array[bool] = []
var _x3: Array[Node3D] = []
var _x_last: Array[Vector2] = []
## Effet choisi (-1 rétro, 0 aucun, 1 coulé), appliqué au premier choc de la blanche ; faute
## (la blanche a touché la noire) pendant le coup en cours.
var _spin: int = 0
var _spun: bool = false
var _foul: bool = false
var _bot_spin: int = 0
var _black_on: bool = false


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
		Stage3D.textured("felt", Color("1c9a62"), 0.35, 0.0, 1.0))
	var cushion: StandardMaterial3D = Stage3D.textured("felt", Color("13784b"), 0.35, 0.0, 1.0)
	var wood: StandardMaterial3D = Stage3D.textured("wood", Color("c07a50"), 0.8, 0.0, 0.7)
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
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.75, 0.3)
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
	for k: int in _xp.size():
		_x3.append(_build_ball(BLACK if k == 0 else NEUTRAL, Palette.IVORY if k == 0 else Palette.GOLD_LIGHT))
		_x_last.append(_xp[k])
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
	_pulse += delta
	_cue3.position = st.to3(_cue, BALL_R * PX3)
	_obj3.position = st.to3(_obj, BALL_R * PX3)
	_cue3.scale = Vector3.ONE
	_obj3.scale = Vector3.ONE
	_cue3.visible = _sink3(_cue3, _cue, _sink_cue, delta) if _cue_in else true
	_obj3.visible = _sink3(_obj3, _obj, _sink_obj, delta) if _obj_in else true
	for k: int in _x3.size():
		_roll3(_x3[k], _x_last[k], _xp[k])
		_x_last[k] = _xp[k]
		_x3[k].position = st.to3(_xp[k], BALL_R * PX3)
		_x3[k].visible = not _xin[k]
	var aiming: bool = not _rolling and _rest_t <= 0.0 and _shot < pi("shots")
	_stick3.visible = aiming
	if aiming:
		var dir: Vector2 = Vector2.from_angle(_aim)
		var back: float = 30.0 + _charge * 120.0
		_stick3.position = st.to3(_cue - dir * back, BALL_R * PX3 * 1.3)
		_stick3.rotation = Vector3(0, 0.08, -_aim)


## Bille qui tombe : glisse vers le centre de la poche, s'enfonce et rapetisse ; faux une fois tombée.
func _sink3(n: Node3D, at: Vector2, sink: Array, delta: float) -> bool:
	if sink.is_empty():
		return false
	sink[1] = float(sink[1]) - delta
	var u: float = 1.0 - clampf(float(sink[1]) / SINK_TIME, 0.0, 1.0)
	var pos: Vector2 = at.lerp(sink[0] as Vector2, u)
	n.position = stage.to3(pos, BALL_R * PX3 * (1.0 - u * 1.6))
	n.scale = Vector3.ONE * (1.0 - u * 0.5)
	return u < 1.0


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
	_place_extras()
	_black_on = not _xin[0]
	_cue_v = Vector2.ZERO
	_obj_v = Vector2.ZERO
	_obj_in = false
	_cue_in = false
	_spun = false
	_foul = false
	_sink_obj = []
	_sink_cue = []
	_sling = false
	_rolling = false
	_charging = false
	_charge = 0.0
	_charge_dir = 1.0
	_wait = 0.0
	_aim = (_obj - _cue).angle()


## La noire se pose près de la ligne de jeu (sans la boucher : le coup reste propre), les
## neutres ailleurs ; aucune ne gêne le meilleur coup.
func _place_extras() -> void:
	_xp.clear()
	_xv.clear()
	_xin.clear()
	var with_black: bool = _shot >= pi("black_from")
	for k: int in 1 + pi("neutrals"):
		_xp.append(Vector2(-1000, -1000))
		_xv.append(Vector2.ZERO)
		_xin.append(k == 0 and not with_black)  # pas encore de noire : rangée hors jeu
	var plan: Vector4 = _best_plan()
	var pk: Vector2 = _pockets()[int(plan.z)]
	var ghost: Vector2 = _obj - (pk - _obj).normalized() * BALL_R * 2.0
	for k: int in _xp.size():
		if _xin[k]:
			continue
		for _try: int in 80:
			var at: Vector2 = _random_spot(Vector2(90, 90))
			if k == 0:
				# Noire : à côté de la trajectoire de la blanche, à 2,6 – 5 rayons.
				var u: float = rng.randf_range(0.3, 0.8)
				var side: Vector2 = (ghost - _cue).normalized().orthogonal() * (1.0 if rng.randf() < 0.5 else -1.0)
				at = _cue.lerp(ghost, u) + side * BALL_R * rng.randf_range(2.8, 5.0)
				if not TABLE.grow(-BALL_R * 2.0).has_point(at):
					continue
			if _clear_of(at, ghost, pk, k):
				_xp[k] = at
				break
		if _xp[k].x < 0.0:
			_xin[k] = true  # pas de place : la bille reste au râtelier


## Vrai si une bille en `at` laisse libres la blanche, la couleur, les poches et le meilleur coup.
func _clear_of(at: Vector2, ghost: Vector2, pk: Vector2, k: int) -> bool:
	var gap: float = BALL_R * 2.3
	if at.distance_to(_cue) < gap * 1.5 or at.distance_to(_obj) < gap * 1.5:
		return false
	for pp: Vector2 in _pockets():
		if at.distance_to(pp) < POCKET_R + BALL_R * 2.0:
			return false
	if _seg_dist(at, _cue, ghost) < gap or _seg_dist(at, _obj, pk) < gap:
		return false
	for j: int in k:
		if not _xin[j] and at.distance_to(_xp[j]) < gap * 1.5:
			return false
	return true


static func _seg_dist(pt: Vector2, a: Vector2, b: Vector2) -> float:
	return pt.distance_to(Geometry2D.get_closest_point_to_segment(pt, a, b))


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
	var ready: bool = not _rolling and _rest_t <= 0.0 and _shot < pi("shots")
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and ready and SPIN_BOX.has_point(mb.position):
		set_spin(_spin + 1 if _spin < 1 else -1)  # pastille d'effet : touche pour changer
		return true
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed and ready and mb.position.distance_to(_cue) <= p("sling_grab"):
			_sling = true
			_sling_at = mb.position
			_charge = 0.0
		elif not mb.pressed and _sling:
			_sling = false
			_sling_at = mb.position
			if _sling_pull() >= p("sling_fire"):
				_strike()
			else:
				_charge = 0.0  # revenu sur la bille : coup annulé
				AudioBus.play("click", 0.8, -10.0)
		return true
	if mb != null and mb.pressed and ready and (mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_WHEEL_UP
			or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		set_spin(_spin - 1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else (_spin + 1 if _spin < 1 else -1))
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pos = mm.position
		if _sling:
			_sling_at = mm.position
			_sling_update()
		return true
	var d: Vector2i = dir_pressed(event)
	if ready and not _charging and d.y != 0:
		set_spin(_spin - d.y)  # haut : coulé, bas : rétro
		return true
	if confirm_pressed(event):
		_charging = not _rolling and _rest_t <= 0.0
		return true
	if confirm_released(event):
		if _charging:
			_strike()
		return true
	return false


func set_spin(v: int) -> void:
	var nv: int = clampi(v, -1, 1)
	if nv != _spin:
		_spin = nv
		AudioBus.play("click", 1.2 + 0.2 * float(_spin), -8.0)


## Distance tirée depuis la blanche (pixels).
func _sling_pull() -> float:
	return _sling_at.distance_to(_cue)


## Le lance-pierre vise à l'opposé du doigt ; la force suit la distance tirée.
func _sling_update() -> void:
	var pull: float = _sling_pull()
	if pull >= p("sling_fire") * 0.5:
		_aim = (_cue - _sling_at).angle()
	_charge = clampf((pull - p("sling_fire")) / maxf(p("sling_max") - p("sling_fire"), 1.0), 0.0, 1.0)


func _strike() -> void:
	_sling = false
	_charging = false
	_rolling = true
	_spun = false
	_foul = false
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
		if not _sling:
			_wait += dt
		if _wait >= p("aim_timeout") * slow:
			_strike()
			return
		# Visée progressive : vitesse en puissance de l'inclinaison, pour les réglages fins.
		var ax: float = clampf(held_vector().x + _bot_aim, -1.0, 1.0)
		_aim += signf(ax) * pow(absf(ax), p("aim_curve")) * p("aim_speed") * dt
		if _charging:
			_charge += _charge_dir * dt / (p("charge_seconds") * slow)
			if _charge >= 1.0 or _charge <= 0.0:
				_charge = clampf(_charge, 0.0, 1.0)
				_charge_dir = -_charge_dir
		return
	var h: float = dt / float(SUBSTEPS)
	for _s: int in SUBSTEPS:
		_physics(h)
	if _all_still():
		_settle()


func _physics(h: float) -> void:
	# Toutes les billes : 0 la blanche, 1 la couleur, puis les billes en plus.
	var pos: Array[Vector2] = [_cue, _obj]
	pos.append_array(_xp)
	var vel: Array[Vector2] = [_cue_v, _obj_v]
	vel.append_array(_xv)
	var inn: Array[bool] = [_cue_in, _obj_in]
	inn.append_array(_xin)
	for k: int in pos.size():
		if inn[k]:
			continue
		var v: Vector2 = vel[k]
		var sp: float = v.length()
		var dec: float = p("friction") * h
		v = Vector2.ZERO if sp <= dec else v * ((sp - dec) / sp)
		var at: Vector2 = pos[k] + v * h
		for pk: Vector2 in _pockets():
			if at.distance_to(pk) < POCKET_R:
				inn[k] = true
				if k == 0:
					_sink_cue = [pk, SINK_TIME]
				elif k == 1:
					_sink_obj = [pk, SINK_TIME]
				v = Vector2.ZERO
				if not _sim:
					AudioBus.play("ball_land", 1.0, -4.0)
				break
		if at.x < TABLE.position.x + BALL_R or at.x > TABLE.end.x - BALL_R:
			at.x = clampf(at.x, TABLE.position.x + BALL_R, TABLE.end.x - BALL_R)
			_cushion_sound(absf(v.x))
			v.x = -v.x * p("cushion")
		if at.y < TABLE.position.y + BALL_R or at.y > TABLE.end.y - BALL_R:
			at.y = clampf(at.y, TABLE.position.y + BALL_R, TABLE.end.y - BALL_R)
			_cushion_sound(absf(v.y))
			v.y = -v.y * p("cushion")
		vel[k] = v
		pos[k] = at
	# Chocs élastiques de billes de même masse : échange des composantes normales.
	for i: int in pos.size():
		if inn[i]:
			continue
		for j: int in range(i + 1, pos.size()):
			if inn[j]:
				continue
			var d: Vector2 = pos[j] - pos[i]
			if d.length() >= BALL_R * 2.0 or d.length() <= 0.001:
				continue
			var n: Vector2 = d.normalized()
			var rel: float = (vel[i] - vel[j]).dot(n)
			if rel > 0.0:
				vel[i] -= n * rel
				vel[j] += n * rel
				if i == 0:
					if not _spun:
						# Effet : au premier choc, la blanche suit (coulé) ou revient (rétro).
						_spun = true
						vel[0] += n * rel * p("spin_k") * float(_spin)
					if j == 2 and not _xin[0]:
						_foul = true
				if not _sim:
					AudioBus.play("ball_glass", 1.3, -4.0)
			var push: float = (BALL_R * 2.0 - d.length()) * 0.5
			pos[i] -= n * push
			pos[j] += n * push
	_cue = pos[0]
	_obj = pos[1]
	_cue_v = vel[0]
	_obj_v = vel[1]
	_cue_in = inn[0]
	_obj_in = inn[1]
	for k2: int in _xp.size():
		_xp[k2] = pos[k2 + 2]
		_xv[k2] = vel[k2 + 2]
		_xin[k2] = inn[k2 + 2]


## Toutes les billes à l'arrêt (ou empochées).
func _all_still() -> bool:
	if _cue_v.length() >= 4.0 or _obj_v.length() >= 4.0:
		return false
	for k: int in _xv.size():
		if not _xin[k] and _xv[k].length() >= 4.0:
			return false
	return true


func _cushion_sound(sp: float) -> void:
	if not _sim and sp > p("cushion_sound_speed"):
		AudioBus.play("ball_wood", 0.7 + rng.randf() * 0.2, linear_to_db(clampf(sp / p("speed_max"), 0.05, 1.0)) - 4.0)


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
	if _foul:
		sc = maxf(0.0, sc - p("black_penalty"))
	var black_in: bool = _black_potted()
	if black_in:
		sc = 0.0
	_scores.append(sc)
	var key: String = "TRIAL_BILLIARDS_POTTED" if _obj_in else ("TRIAL_BILLIARDS_SCRATCH" if _cue_in else "TRIAL_BILLIARDS_CLOSE")
	if not _obj_in and not _cue_in and sc < p("miss_value") * 0.35:
		key = "TRIAL_BILLIARDS_MISSED"
	if _foul:
		key = "TRIAL_BILLIARDS_FOUL"
	if black_in:
		key = "TRIAL_BILLIARDS_BLACK_IN"
	pop(Vector2(TABLE.get_center().x, TABLE.position.y - 90.0), sc, key)
	_rest_t = p("rest_seconds")


## La noire est tombée pendant ce coup (elle était sur le tapis au départ).
func _black_potted() -> bool:
	return _black_on and _xin[0]


# --------------------------------------------------------------------------- bot


## Force voulue : le bot rejoue le coup dans la vraie physique pour quelques forces et garde
## celle qui empoche (la plus proche de l'estimation analytique) ; calculée une fois par coup.
func bot_charge() -> float:
	if _bot_force >= 0.0:
		return _bot_force
	var guess: float = _bot_guess()
	var best: float = guess
	var best_err: float = INF
	var saved_spin: int = _spin
	for sp: int in [0, 1, -1]:
		_spin = sp
		for k: int in BOT_FORCE_STEPS + 1:
			var c: float = float(k) / float(BOT_FORCE_STEPS)
			var err: float = _simulate(_best_plan().x, c)
			err += absf(c - guess) * 0.01 + absf(float(sp)) * 0.005  # à égalité : sans effet, force calculée
			if err < best_err:
				best_err = err
				best = c
				_bot_spin = sp
	_spin = saved_spin
	_bot_force = best
	return best


## Joue le coup (angle, force) en accéléré sans toucher à l'état : 0 si la couleur tombe seule,
## sinon distance de la couleur à la poche la plus proche (+ pénalité si la blanche tombe).
func _simulate(angle: float, c: float) -> float:
	var saved: Array = [_cue, _obj, _cue_v, _obj_v, _cue_in, _obj_in, _xp.duplicate(), _xv.duplicate(), _xin.duplicate(), _spun, _foul,
		_sink_cue, _sink_obj]
	_sim = true
	_spun = false
	_foul = false
	_cue_v = Vector2.from_angle(angle) * _speed_for(c)
	_obj_v = Vector2.ZERO
	var h: float = 1.0 / 60.0 / float(SUBSTEPS)
	var steps: int = 0
	while not _all_still() and steps < BOT_SIM_MAX_STEPS:
		_physics(h)
		steps += 1
	var near: float = INF
	for pk: Vector2 in _pockets():
		near = minf(near, _obj.distance_to(pk))
	var err: float = 0.0 if _obj_in else near
	if _cue_in:
		err += 1000.0
	if _foul or (_black_on and _xin[0]):
		err += 800.0
	_sim = false
	_cue = saved[0]
	_obj = saved[1]
	_cue_v = saved[2]
	_obj_v = saved[3]
	_cue_in = saved[4]
	_obj_in = saved[5]
	_xp.assign(saved[6])
	_xv.assign(saved[7])
	_xin.assign(saved[8])
	_spun = saved[9]
	_foul = saved[10]
	_sink_cue = saved[11]
	_sink_obj = saved[12]
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
		bot_charge()
		if _bot_spin != _spin:
			return {"do": "dir", "dir": Vector2i(0, -1 if _bot_spin > _spin else 1)}
		return {"do": "hold"}
	var target: float = bot_charge()
	var nxt: float = _charge + _charge_dir / 60.0 / (p("charge_seconds") * slow)
	if (_charge - target) * (nxt - target) <= 0.0:
		return {"do": "release"}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	var act: String = String(w.get("do", ""))
	_bot_aim = (w.get("v", Vector2.ZERO) as Vector2).x if act == "axis" else 0.0
	if act == "dir" and not _rolling and not _charging:
		set_spin(_spin - (w["dir"] as Vector2i).y)
	if act == "hold" and not _rolling and _rest_t <= 0.0:
		_charging = true
	elif act == "release" and _charging:
		_strike()


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	if not _rolling and _rest_t <= 0.0 and _shot < pi("shots"):
		_draw_aim()
		var g: Rect2 = Rect2(TABLE.end.x + 90.0, TABLE.position.y + 40.0, 36.0, TABLE.size.y - 80.0)
		draw_rect(g, Color(Palette.INK, 0.9))
		draw_rect(Rect2(g.position.x, g.end.y - g.size.y * _charge, g.size.x, g.size.y * _charge),
			Palette.GOLD.lerp(Palette.MULT_RED, _charge))
		draw_rect(g, Palette.GOLD, false, 2.0)
		text(Vector2(g.get_center().x, g.position.y - 24.0), tr("TRIAL_BILLIARDS_POWER"), UiKit.SIZE_SMALL, Palette.IVORY)
		if mouse:
			# Lance-pierre : anneau de prise autour de la blanche, élastique quand on tire.
			var ring: Color = Color(Palette.GOLD_LIGHT, 0.35 + 0.25 * sin(_pulse * 4.0))
			draw_arc(_cue, p("sling_grab"), 0, TAU, 48, ring, 2.0)
			if _sling:
				var ok: bool = _sling_pull() >= p("sling_fire")
				draw_line(_cue, _sling_at, Color(Palette.GOLD_LIGHT if ok else Palette.SMOKE, 0.8), 3.0)
				draw_circle(_sling_at, 10.0, Palette.GOLD_LIGHT if ok else Palette.SMOKE)
				if not ok:
					text(_cue + Vector2(0, -p("sling_grab") - 22.0), tr("TRIAL_BILLIARDS_CANCEL"), UiKit.SIZE_SMALL, Palette.SMOKE)
	_draw_spin()
	if _black_on and not _xin[0]:
		draw_arc(_xp[0], BALL_R + 7.0, 0, TAU, 32, Color(Palette.MULT_RED, 0.6 + 0.3 * sin(_pulse * 6.0)), 3.0)
	text(Vector2(size.x * 0.5, 80.0), tr("TRIAL_BILLIARDS_SHOT") % [mini(_shot + 1, pi("shots")), pi("shots")], UiKit.SIZE_BODY,
		Palette.IVORY)
	pips(Vector2(size.x * 0.5, 120.0), _scores, pi("shots"))


## Pastille d'effet : une bille blanche vue de face, le point de frappe haut (coulé), centre ou bas
## (rétro), et son nom.
func _draw_spin() -> void:
	var c: Vector2 = SPIN_BOX.get_center() + Vector2(0, -10)
	var rad: float = SPIN_BOX.size.x * 0.32
	draw_circle(c, rad + 4.0, Palette.GOLD_DARK)
	draw_circle(c, rad, Palette.IVORY)
	draw_circle(c + Vector2(0, -float(_spin) * rad * 0.55), rad * 0.2, Color("2a5aa0"))
	text(c + Vector2(0, rad + 26.0), tr(SPIN_KEYS[_spin + 1]), UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
	text(c + Vector2(0, -rad - 22.0), tr("TRIAL_BILLIARDS_SPIN"), UiKit.SIZE_SMALL, Palette.IVORY)


## Trace la blanche jusqu'à la couleur ou au premier rebond (puis un segment après), la bille
## fantôme au contact, la direction prévue de la couleur et la déviation de la blanche.
func _draw_aim() -> void:
	var dir: Vector2 = Vector2.from_angle(_aim)
	var from: Vector2 = _cue
	var left: float = INF
	var line: Color = Color(Palette.IVORY, 0.75)
	var best_pk: Vector2 = _pockets()[int(_best_plan().z)]
	# Poche conseillée (pointillés) et bille à empocher (halo).
	_dotted_ring(best_pk, POCKET_R + 14.0, Color(Palette.GOLD_LIGHT, 0.5))
	draw_arc(_obj, BALL_R + 8.0 + 3.0 * sin(_pulse * 5.0), 0, TAU, 32, Color(_colors[_shot % _colors.size()], 0.8), 3.0)
	for seg: int in 2:
		var hit_obj: float = _ray_ball(from, dir, _obj)
		var hit_wall: Vector3 = _ray_wall(from, dir)
		var lim: float = minf(left, hit_wall.x)
		# Une autre bille en premier sur la trajectoire : contact marqué (rouge pour la noire).
		for k: int in _xp.size():
			if _xin[k]:
				continue
			var hx: float = _ray_ball(from, dir, _xp[k])
			if hx >= 0.0 and hx < lim and (hit_obj < 0.0 or hx < hit_obj):
				var gx: Vector2 = from + dir * hx
				_dashed(from + dir * (BALL_R if seg == 0 else 0.0), gx, line)
				draw_arc(gx, BALL_R, 0, TAU, 32, Palette.MULT_RED if k == 0 else Color(Palette.IVORY, 0.85), 3.0)
				return
		if hit_obj >= 0.0 and hit_obj <= lim:
			var ghost: Vector2 = from + dir * hit_obj
			_dashed(from + dir * (BALL_R if seg == 0 else 0.0), ghost, line)
			draw_arc(ghost, BALL_R, 0, TAU, 32, Color(Palette.IVORY, 0.85), 2.0)
			var n: Vector2 = (_obj - ghost).normalized()
			var cut: float = clampf(dir.dot(n), 0.0, 1.0)
			var obj_to: Vector2 = _obj + n * OBJ_ARROW * cut
			var col: Color = _colors[_shot % _colors.size()]
			var pk: int = _pocket_on_ray(_obj, n)
			if pk >= 0:
				var pp: Vector2 = _pockets()[pk]
				draw_arc(pp, POCKET_R + 6.0, 0, TAU, 40, Color(Palette.EMERALD, 0.9), 5.0)
				obj_to = _obj + n * minf(_obj.distance_to(pp), OBJ_ARROW * maxf(cut, 0.6))
			_arrow(_obj, obj_to, col)
			var tang: Vector2 = dir - n * dir.dot(n)
			if tang.length() > 0.05:
				_arrow(ghost, ghost + tang.normalized() * CUE_ARROW * tang.length(), Color(Palette.IVORY, 0.5))
			return
		var end: Vector2 = from + dir * lim
		_dashed(from + dir * (BALL_R if seg == 0 else 0.0), end, line)
		if lim < hit_wall.x:
			return
		# Rebond : on reflète la direction sur la bande touchée, et on prolonge un peu.
		dir = Vector2(-dir.x, dir.y) if hit_wall.y > 0.5 else Vector2(dir.x, -dir.y)
		from = end
		left = PREVIEW_BOUNCE
		line = Color(Palette.IVORY, 0.4)
		draw_circle(end, 5.0, Color(Palette.IVORY, 0.6))


## Distance le long du rayon jusqu'au contact avec la bille en `c` (-1 si manquée).
func _ray_ball(from: Vector2, dir: Vector2, c: Vector2) -> float:
	var to: Vector2 = c - from
	var along: float = to.dot(dir)
	var perp: float = absf(to.cross(dir))
	if along <= 0.0 or perp >= BALL_R * 2.0:
		return -1.0
	return along - sqrt(BALL_R * BALL_R * 4.0 - perp * perp)


## Premier rebond : (distance, 1 si bande verticale, 0 sinon).
func _ray_wall(from: Vector2, dir: Vector2) -> Vector3:
	var inner: Rect2 = TABLE.grow(-BALL_R)
	var tx: float = INF
	var ty: float = INF
	if dir.x > 0.0001:
		tx = (inner.end.x - from.x) / dir.x
	elif dir.x < -0.0001:
		tx = (inner.position.x - from.x) / dir.x
	if dir.y > 0.0001:
		ty = (inner.end.y - from.y) / dir.y
	elif dir.y < -0.0001:
		ty = (inner.position.y - from.y) / dir.y
	return Vector3(maxf(minf(tx, ty), 0.0), 1.0 if tx < ty else 0.0, 0.0)


## Poche que la couleur atteint en ligne droite dans la direction `n` (-1 sinon).
func _pocket_on_ray(from: Vector2, n: Vector2) -> int:
	var pk: Array[Vector2] = _pockets()
	for k: int in pk.size():
		var to: Vector2 = pk[k] - from
		if to.dot(n) > 0.0 and absf(to.cross(n)) < POCKET_R * 0.8:
			return k
	return -1


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var n: int = maxi(1, int(a.distance_to(b) / 18.0))
	for k: int in n:
		if k % 2 == 0:
			draw_line(a.lerp(b, float(k) / float(n)), a.lerp(b, float(k + 1) / float(n)), col, 3.0)


func _dotted_ring(c: Vector2, r: float, col: Color) -> void:
	for k: int in 24:
		draw_circle(c + Vector2.from_angle(TAU * float(k) / 24.0 + _pulse) * r, 3.0, col)


func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	if a.distance_to(b) < 8.0:
		return
	draw_line(a, b, col, 4.0)
	var d: Vector2 = (b - a).normalized()
	draw_colored_polygon(PackedVector2Array([b + d * 10.0, b - d * 12.0 + d.orthogonal() * 10.0, b - d * 12.0 - d.orthogonal() * 10.0]),
		col)
