class_name TrialLasers
extends ThrowTrial
## LES LASERS DU COFFRE (écran dédié, vue de dessus) : traverser la salle des coffres du
## Grand Zéro jusqu'à la porte blindée. Des faisceaux rouges balaient la pièce : pendules qui
## pivotent, barrières qui glissent, rideaux qui clignotent. Déplacement libre (stick, flèches,
## souris). Touché : alarme, recul et un instant d'immobilité.
## Note = arrivée (plus tôt = mieux) ou part du chemin parcouru, moins les faisceaux touchés.
## 2.0 : un RIDEAU laser, renvoyé par un miroir au sol, barre la porte. Une dalle-INTERRUPTEUR,
## cachée entre les faisceaux, fait pivoter le miroir quelques secondes : le rideau part le
## long du mur. Il faut planifier le détour par la dalle, puis filer à la porte à temps.

const ROOM: Rect2 = Rect2(220.0, 220.0, 1480.0, 720.0)
const START: Vector2 = Vector2(290.0, 580.0)
const DOOR: Rect2 = Rect2(1630.0, 500.0, 60.0, 160.0)
const BODY_R: float = 18.0
## Rideau devant la porte (x), dalle-interrupteur (rayon) et miroir (côté).
const BARRIER_X: float = 1545.0
const SWITCH_R: float = 40.0
const MIRROR_PX: float = 46.0
## Bot : bonus du cap actuel (évite les allers-retours d'une image à l'autre).
const BOT_STICKY: float = 0.2
const BEAM_W: float = 6.0
const LOOK_STEPS: int = 8
## Décor 3D (caméra frontale = vue de dessus) : mètres par pixel, dalles, coffres, fumée.
const PX3: float = 0.005
const TILE_PX: float = 80.0
const LOCKER_PX: Vector2 = Vector2(80.0, 60.0)
const BEAM_Z: float = 0.22
const SMOKE_LAYERS: int = 3
const BOT_DIRS: Array[Vector2] = [Vector2(1, 0), Vector2(0.7, -0.7), Vector2(0.7, 0.7), Vector2(0, -1), Vector2(0, 1), Vector2.ZERO,
	Vector2(-1, 0), Vector2(-0.7, -0.7), Vector2(-0.7, 0.7), Vector2(0.92, 0.38), Vector2(0.92, -0.38), Vector2(0.38, 0.92),
	Vector2(0.38, -0.92)]

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
var _core_pool: MeshPool = null
var _haze_pool: MeshPool = null
var _thief3: Node3D = null
var _wheel3: Node3D = null
var _beacon: OmniLight3D = null
var _smoke: Array[StandardMaterial3D] = []
var _face: float = 0.0
## Dalle-interrupteur et temps restant d'ouverture du rideau.
var _switch: Vector2 = Vector2.ZERO
var _open_t: float = 0.0
var _mirror3: Node3D = null
var _plate_mat: StandardMaterial3D = null
var _bot_last: Vector2 = Vector2.ZERO


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
	# Dalle entre le 2e et le 3e faisceau, contre un mur (haut ou bas) : un vrai détour.
	var sx: float = ROOM.position.x + p("first_beam") + p("beam_spacing") * 1.5
	# Côté : à l'opposé des pivots des balayeurs qui l'encadrent (sinon, au hasard).
	var top_votes: int = 0
	for k2: int in [1, 2]:
		if String(_beams[k2]["kind"]) == "sweep":
			top_votes += -1 if (_beams[k2]["pivot"] as Vector2).y <= ROOM.position.y else 1
	var top: bool = top_votes > 0 or (top_votes == 0 and rng.randf() < 0.5)
	_switch = Vector2(sx, ROOM.position.y + 110.0 if top else ROOM.end.y - 110.0)
	_beams.append({"kind": "barrier", "x": BARRIER_X, "ph": 0.0, "w": 0.0})
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("050608")
	st.env.ambient_light_color = Color(0.35, 0.4, 0.5)
	st.env.ambient_light_energy = 0.35
	st.key.light_energy = 0.25
	var r: Node3D = st.root
	_build_floor(st)
	# Murs de coffres numérotés autour de la salle.
	var steel: StandardMaterial3D = Stage3D.mat(Color("4a505c"), 0.45, 0.35)
	var steel_d: StandardMaterial3D = Stage3D.mat(Color("2a2e36"), 0.45, 0.45)
	var knob: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.3)
	var g: Rect2 = ROOM.grow(60.0)
	Stage3D.box(r, Vector3(30, 20, 0.05), st.to3(Vector2(960, 540), -0.05), Stage3D.mat(Color("0a0b0e"), 0.0, 0.9))
	for row: float in [g.position.y + 30.0, g.end.y - 30.0]:
		var x: float = g.position.x + LOCKER_PX.x * 0.5
		while x < g.end.x:
			Stage3D.box(r, Vector3((LOCKER_PX.x - 6.0) * PX3, (LOCKER_PX.y - 6.0) * PX3, 0.5), st.to3(Vector2(x, row), 0.25), steel)
			Stage3D.cylinder(r, 7.0 * PX3, 0.04, st.to3(Vector2(x, row), 0.51), knob).rotation.x = PI * 0.5
			x += LOCKER_PX.x
	for col: float in [g.position.x + 30.0, g.end.x - 30.0]:
		Stage3D.box(r, Vector3(60.0 * PX3, (g.size.y - 120.0) * PX3, 0.5), st.to3(Vector2(col, g.get_center().y), 0.25), steel_d)
	# Porte blindée ronde, volant qui tourne.
	var dc: Vector2 = DOOR.get_center()
	var door: MeshInstance3D = Stage3D.cylinder(r, 95.0 * PX3, 0.12, st.to3(dc + Vector2(30, 0), 0.45),
		Stage3D.mat(Color("8a8a96"), 0.45, 0.25))
	door.rotation.x = PI * 0.5
	var ring: MeshInstance3D = Stage3D.cylinder(r, 75.0 * PX3, 0.02, st.to3(dc + Vector2(30, 0), 0.52),
		Stage3D.mat(Palette.GOLD, 0.45, 0.3))
	ring.rotation.x = PI * 0.5
	_wheel3 = Node3D.new()
	_wheel3.position = st.to3(dc + Vector2(30, 0), 0.56)
	r.add_child(_wheel3)
	for k: int in 3:
		var spoke: MeshInstance3D = Stage3D.box(_wheel3, Vector3(110.0 * PX3, 9.0 * PX3, 0.03), Vector3.ZERO,
			Stage3D.mat(Palette.GOLD_LIGHT, 0.45, 0.3))
		spoke.rotation.z = PI * float(k) / 3.0
	Stage3D.sphere(_wheel3, 14.0 * PX3, Vector3.ZERO, Stage3D.mat(Palette.GOLD, 0.45, 0.3))
	# Émetteurs : pivots des pendules et rails des barrières.
	var emitter: StandardMaterial3D = Stage3D.mat(Color("1a1c22"), 0.45, 0.4)
	for b: Dictionary in _beams:
		match String(b["kind"]):
			"sweep":
				Stage3D.box(r, Vector3(34.0 * PX3, 34.0 * PX3, 0.3), st.to3(b["pivot"] as Vector2, 0.15), emitter)
				Stage3D.sphere(r, 8.0 * PX3, st.to3(b["pivot"] as Vector2, 0.31), Stage3D.glow(Color(1, 0.15, 0.15), 3.0))
			"blink":
				for y: float in [ROOM.position.y, ROOM.end.y]:
					Stage3D.box(r, Vector3(30.0 * PX3, 30.0 * PX3, 0.3), st.to3(Vector2(float(b["x"]), y), 0.15), emitter)
			"slide":
				for y2: float in [ROOM.position.y + 6.0, ROOM.end.y - 6.0]:
					Stage3D.box(r, Vector3(p("slide_half") * 2.0 * PX3, 8.0 * PX3, 0.05), st.to3(Vector2(float(b["x"]), y2), 0.03), emitter)
	# Rideau : émetteur au plafond, miroir pivotant au sol ; dalle-interrupteur.
	Stage3D.box(r, Vector3(40.0 * PX3, 40.0 * PX3, 0.3), st.to3(Vector2(BARRIER_X, ROOM.position.y), 0.15), emitter)
	_mirror3 = Node3D.new()
	_mirror3.position = st.to3(Vector2(BARRIER_X, ROOM.end.y - MIRROR_PX * 0.5), BEAM_Z)
	r.add_child(_mirror3)
	Stage3D.box(_mirror3, Vector3(MIRROR_PX * PX3, 6.0 * PX3, 0.3), Vector3.ZERO, Stage3D.mat(Color("d8e4f0"), 0.95, 0.05))
	_plate_mat = Stage3D.glow(Color(0.2, 0.5, 0.3), 0.6)
	var plate: MeshInstance3D = Stage3D.cylinder(r, SWITCH_R * PX3, 0.03, st.to3(_switch, 0.0), _plate_mat)
	plate.rotation.x = PI * 0.5
	# Faisceaux : cœur lumineux et halo diffusé dans la fumée.
	var unit: BoxMesh = BoxMesh.new()
	unit.size = Vector3.ONE
	_core_pool = MeshPool.new(r, unit, Stage3D.glow(Color(1, 0.2, 0.2), 4.0))
	var haze: StandardMaterial3D = Stage3D.glow(Color(1, 0.1, 0.15), 1.0)
	haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	haze.albedo_color.a = 0.14
	_haze_pool = MeshPool.new(r, unit, haze)
	# Nappes de fumée qui dérivent au-dessus du sol.
	var noise: NoiseTexture2D = NoiseTexture2D.new()
	noise.seamless = true
	noise.width = 256
	noise.height = 256
	noise.noise = FastNoiseLite.new()
	(noise.noise as FastNoiseLite).frequency = 0.012
	for k2: int in SMOKE_LAYERS:
		var sm: StandardMaterial3D = StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_texture = noise
		sm.albedo_color = Color(0.55, 0.58, 0.66, 0.035)
		sm.uv1_scale = Vector3(2.0 + float(k2), 1.0 + float(k2) * 0.5, 1.0)
		var quad: MeshInstance3D = Stage3D.box(r, Vector3(ROOM.size.x * PX3, ROOM.size.y * PX3, 0.001),
			st.to3(ROOM.get_center(), 0.12 + 0.12 * float(k2)), sm)
		quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_smoke.append(sm)
	_thief3 = _build_thief(r)
	_beacon = Stage3D.omni(r, Color(1, 0.1, 0.1), 0.0, st.to3(ROOM.get_center(), 2.0), 9.0)
	Stage3D.omni(r, Color(0.7, 0.8, 1.0), 0.6, st.to3(ROOM.get_center(), 3.5), 9.0)


## Dalles d'acier en léger damier (une seule MultiMesh).
func _build_floor(st: Stage3D) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3((TILE_PX - 4.0) * PX3, (TILE_PX - 4.0) * PX3, 0.02)
	mm.mesh = bm
	var nx: int = int(ceil(ROOM.size.x / TILE_PX))
	var ny: int = int(ceil(ROOM.size.y / TILE_PX))
	mm.instance_count = nx * ny
	for i: int in nx * ny:
		var at: Vector2 = ROOM.position + Vector2((float(i % nx) + 0.5) * TILE_PX, (float(i / nx) + 0.5) * TILE_PX)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, st.to3(at, -0.01)))
		mm.set_instance_color(i, Color("1c2028") if (i % nx + i / nx) % 2 == 0 else Color("161a20"))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.45, 0.35)
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	st.root.add_child(mmi)


## Cambrioleur vu de dessus : épaules, bonnet, sac à dos, lampe frontale.
func _build_thief(r: Node3D) -> Node3D:
	var n: Node3D = Node3D.new()
	r.add_child(n)
	n.scale = Vector3.ONE * 1.6
	var dark: StandardMaterial3D = Stage3D.mat(Color("2a2a36"), 0.0, 0.6)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = MeshPool.capsule(BODY_R * 0.6 * PX3, BODY_R * 2.2 * PX3)
	body.material_override = dark
	body.rotation.x = PI * 0.5
	body.position.z = 0.08
	body.scale = Vector3(1.0, 1.0, 0.6)
	body.name = "body"
	n.add_child(body)
	var shoulders: MeshInstance3D = Stage3D.box(n, Vector3(BODY_R * 1.2 * PX3, BODY_R * 2.2 * PX3, 0.08), Vector3(0, 0, 0.12), dark)
	shoulders.name = "shoulders"
	Stage3D.sphere(n, BODY_R * 0.55 * PX3, Vector3(0, 0, 0.2), Stage3D.mat(Palette.ROULETTE_RED.darkened(0.3), 0.0, 0.7))
	Stage3D.box(n, Vector3(BODY_R * 0.8 * PX3, BODY_R * 1.4 * PX3, 0.08), Vector3(-BODY_R * 0.7 * PX3, 0, 0.14),
		Stage3D.mat(Color("5a4030"), 0.0, 0.7))
	Stage3D.sphere(n, 4.0 * PX3, Vector3(BODY_R * 0.55 * PX3, 0, 0.22), Stage3D.glow(Color(1.0, 0.95, 0.7), 3.0))
	return n


func _sync_3d(dt: float, v: Vector2) -> void:
	if _core_pool == null:
		return
	var st: Stage3D = stage
	var n: int = 0
	for b: Dictionary in _beams:
		for sg: PackedVector2Array in _segments(b, t):
			var a: Vector3 = st.to3(sg[0], BEAM_Z)
			var c: Vector3 = st.to3(sg[1], BEAM_Z)
			var len_m: float = a.distance_to(c)
			var ang: float = atan2(c.y - a.y, c.x - a.x)
			var core: MeshInstance3D = _core_pool.at(n)
			core.position = (a + c) * 0.5
			core.rotation = Vector3(0, 0, ang)
			core.scale = Vector3(len_m, BEAM_W * PX3, BEAM_W * PX3)
			var hz: MeshInstance3D = _haze_pool.at(n)
			hz.position = core.position
			hz.rotation = core.rotation
			hz.scale = Vector3(len_m, BEAM_W * 5.0 * PX3, BEAM_W * 3.0 * PX3)
			n += 1
	_core_pool.hide_from(n)
	_haze_pool.hide_from(n)
	if v.length() > 0.1 and _stun <= 0.0:
		_face = lerp_angle(_face, atan2(-v.y, v.x), 1.0 - exp(-12.0 * dt))
	_thief3.position = st.to3(_pos, 0.0)
	_thief3.rotation.z = _face
	# Marche : les épaules se balancent ; clignote quand l'alarme a sonné.
	var walk: float = sin(t * 14.0) * 0.18 if v.length() > 0.1 and _stun <= 0.0 else 0.0
	(_thief3.get_node("shoulders") as Node3D).rotation.z = walk
	_thief3.visible = _invuln <= 0.0 or fmod(t * 10.0, 1.0) < 0.6
	_wheel3.rotation.z = t * 0.6
	_mirror3.rotation.z = lerp_angle(_mirror3.rotation.z, PI * 0.25 if _open_t > 0.0 else -PI * 0.25, 1.0 - exp(-10.0 * dt))
	var lit: float = clampf(_open_t / p("switch_seconds"), 0.0, 1.0)
	_plate_mat.emission = Color(0.2, 0.5, 0.3).lerp(Color(0.3, 1.0, 0.5), lit)
	_plate_mat.emission_energy_multiplier = 0.6 + 2.5 * lit
	_beacon.light_energy = 3.0 * _alarm * (0.5 + 0.5 * sin(t * 18.0))
	for k: int in _smoke.size():
		_smoke[k].uv1_offset = Vector3(t * 0.01 * float(k + 1), t * 0.004 * float(k % 2 * 2 - 1), 0)


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
		"barrier":
			# Fermé : rideau vertical (plafond → miroir). Ouvert : renvoyé le long du mur du bas.
			var mirror: Vector2 = Vector2(BARRIER_X, ROOM.end.y - MIRROR_PX * 0.5)
			if _open_t - (at - t) > 0.0:
				out.append(PackedVector2Array([Vector2(BARRIER_X, ROOM.position.y), Vector2(BARRIER_X, ROOM.position.y + 4.0)]))
				out.append(PackedVector2Array([mirror + Vector2(0, MIRROR_PX * 0.4), Vector2(ROOM.end.x, mirror.y + MIRROR_PX * 0.4)]))
			else:
				out.append(PackedVector2Array([Vector2(BARRIER_X, ROOM.position.y), mirror]))
		"blink":
			# Rideau vertical percé d'une ouverture, allumé une partie du cycle.
			if fmod(at * w * 0.25 + ph, 1.0) < p("blink_on"):
				var x2: float = float(b["x"])
				var gap: float = float(b["gap"])
				var half: float = p("blink_gap") * 0.5 * widen()
				out.append(PackedVector2Array([Vector2(x2, ROOM.position.y), Vector2(x2, gap - half)]))
				out.append(PackedVector2Array([Vector2(x2, gap + half), Vector2(x2, ROOM.end.y)]))
	return out


## `extra` : marge (px) que le bot garde autour des faisceaux dans ses prévisions.
func _hit_at(pos: Vector2, at: float, extra: float = 0.0) -> bool:
	for b: Dictionary in _beams:
		for s: PackedVector2Array in _segments(b, at):
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(pos, s[0], s[1])
			if q.distance_to(pos) < BODY_R + BEAM_W * 0.5 + extra:
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
	_sync_3d(dt, v)
	_pos = _pos.clamp(ROOM.position + Vector2.ONE * BODY_R, ROOM.end - Vector2.ONE * BODY_R)
	_best_x = maxf(_best_x, _pos.x)
	_open_t = maxf(0.0, _open_t - dt)
	if _pos.distance_to(_switch) <= SWITCH_R + BODY_R:
		if _open_t <= 0.0:
			AudioBus.play("vault", 1.6, -8.0)
			pop(_switch + Vector2(0, -60), 1.0, "TRIAL_LASERS_SWITCH")
		_open_t = p("switch_seconds")
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
	# Rideau fermé (ou qui se refermera avant l'arrivée) : d'abord la dalle.
	var way: Vector2 = DOOR.get_center()
	var need: float = (DOOR.get_center().x - _pos.x) / p("move_speed") * p("bot_rush")
	if _open_t < need:
		way = _switch
	# Premier faisceau entre soi et le but, dans le sens de la marche (aller ou retour).
	var fwd: float = signf(way.x - _pos.x)
	var order: Array[Dictionary] = _beams.duplicate()
	if fwd < 0.0:
		order.reverse()
	for b: Dictionary in order:
		var bx: float = float(b["x"])
		if String(b["kind"]) == "barrier" or (bx - _pos.x) * fwd < -BODY_R or (way.x - bx) * fwd <= 0.0:
			continue
		var past: float = bx + fwd * 70.0
		if String(b["kind"]) == "blink":
			way = Vector2(past, float(b["gap"]))
		elif String(b["kind"]) == "sweep":
			# Balayeur : on passe hors de sa portée, du côté opposé à son pivot.
			var pv: Vector2 = b["pivot"]
			var reach: float = ROOM.size.y * p("sweep_len") + BODY_R * 3.0
			var far_y: float = pv.y + reach if pv.y <= ROOM.position.y else pv.y - reach
			way = Vector2(past, clampf(far_y, ROOM.position.y + BODY_R * 2.0, ROOM.end.y - BODY_R * 2.0))
		break
	var to_way: Vector2 = (way - _pos).normalized()
	var options: Array[Vector2] = [to_way, _bot_last]
	options.append_array(BOT_DIRS)
	var best: Vector2 = Vector2(-1, 0)
	var best_score: float = -INF
	for dirv: Vector2 in options:
		if not _safe(dirv):
			continue
		var sc: float = dirv.dot(to_way) if dirv != Vector2.ZERO else -0.15
		if dirv.is_equal_approx(_bot_last):
			sc += BOT_STICKY  # garder le cap évite d'osciller d'une image à l'autre
		if sc > best_score:
			best_score = sc
			best = dirv
	_bot_last = best
	return {"do": "axis", "v": best}


func _safe(dirv: Vector2) -> bool:
	var q: Vector2 = _pos
	var dtk: float = p("bot_horizon") / float(LOOK_STEPS)
	for s: int in LOOK_STEPS:
		q = (q + dirv * p("move_speed") * dtk).clamp(ROOM.position + Vector2.ONE * BODY_R, ROOM.end - Vector2.ONE * BODY_R)
		if _hit_at(q, t + dtk * float(s + 1), p("bot_margin")):
			return false
	return true


func bot_apply(w: Dictionary) -> void:
	_bot_v = (w.get("v", Vector2.ZERO) as Vector2) if String(w.get("do", "")) == "axis" else Vector2.ZERO


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	if _alarm > 0.0:
		draw_rect(Rect2(-size.x, 0, size.x * 3.0, size.y), Color(1, 0, 0, 0.18 * _alarm))
	var prog: float = clampf((_best_x - START.x) / (DOOR.position.x - START.x), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 130, 600, 10), Color(Palette.INK, 0.9))
	draw_rect(Rect2(size.x * 0.5 - 300, 130, 600 * prog, 10), Palette.GOLD)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 146, 600 * left, 6), Palette.CYAN)
	text(Vector2(size.x * 0.5, 100.0), tr("TRIAL_LASERS_STATUS") % _hits, UiKit.SIZE_BODY, Palette.IVORY)
	# Dalle : anneau qui pulse tant que le rideau est fermé, jauge du temps d'ouverture sinon.
	if _open_t > 0.0:
		draw_arc(_switch, SWITCH_R + 10.0, -PI * 0.5, -PI * 0.5 + TAU * _open_t / p("switch_seconds"), 40, Palette.EMERALD, 6.0)
		text(Vector2(BARRIER_X, ROOM.position.y - 26.0), tr("TRIAL_LASERS_OPEN"), UiKit.SIZE_SMALL, Palette.EMERALD)
	else:
		draw_arc(_switch, SWITCH_R + 8.0 + 4.0 * sin(t * 5.0), 0, TAU, 40, Color(Palette.EMERALD, 0.7), 3.0)
		text(Vector2(BARRIER_X, ROOM.position.y - 26.0), tr("TRIAL_LASERS_CLOSED"), UiKit.SIZE_SMALL, Palette.MULT_RED)
