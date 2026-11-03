class_name TrialCave
extends ThrowTrial
## LA CAVE DU GRAND ZÉRO (écran dédié, course de plateformes) : le groom traverse les caves
## du casino pour rapporter la bouteille du patron. Courir (stick, flèches, souris à droite),
## sauter (valider). Fosses à franchir, grandes fosses avec un câble de lustre où l'on se
## suspend puis se lâche au bon moment, tonneaux qui roulent, rats qui patrouillent, trésors
## suspendus (jetons) à cueillir d'un saut. Chute = retour au bord, choc = sonné.
## Note = part du parcours × poids + part des trésors × poids, moins les chutes et les chocs.

const FLOOR_Y: float = 860.0
const SCREEN_X: float = 520.0
const BODY: Vector2 = Vector2(36.0, 70.0)
const SEG_W: float = 760.0
const KINDS: Array[String] = ["pit", "rope", "barrel", "rat", "pit", "treasure"]
const ROPE_LEN: float = 300.0
const ROPE_PIVOT_H: float = 470.0
const GRAB_R: float = 56.0
const TREASURE_H: float = 150.0
const BARREL_R: float = 30.0
const RAT_W: float = 50.0
## Décor 3D : mètres par pixel, pas des voûtes (px), profondeur du mur et des casiers (m).
const PX3: float = 0.005
const ARCH_STEP: float = 640.0
const WALL_Z: float = -2.6
const RACK_Z: float = -1.9
const PILLAR_Z: float = -1.1
const LAMP_RANGE: float = 12.0
const GROOM: Array[String] = [
	"  ####  ",
	" ###### ",
	"  #  #  ",
	"  ####  ",
	" ###### ",
	"########",
	"# #### #",
	"  ####  ",
	"  #  #  ",
	" ##  ## ",
]

var _x: float = 120.0
var _y: float = FLOOR_Y
var _vx: float = 0.0
var _vy: float = 0.0
var _ground: bool = true
var _rope: int = -1
var _segs: Array[Dictionary] = []
var _goal_x: float = 0.0
var _treasures: int = 0
var _treasure_total: int = 0
var _falls: int = 0
var _hits: int = 0
var _stun: float = 0.0
var _mouse_x: float = -1.0
var _bot_axis: float = 0.0
var _bot_jump: bool = false
var _jump_queued: bool = false
var _cam: float = 0.0
var _ended: bool = false
var _run_anim: float = 0.0
var _barrels3: Dictionary[int, Node3D] = {}
var _rats3: Dictionary[int, Node3D] = {}
var _treasure3: Dictionary[int, Node3D] = {}
var _ropes3: Dictionary[int, Array] = {}
var _lamps: Array[OmniLight3D] = []
var _flames: Array[MeshInstance3D] = []
var _rat_last: Dictionary[int, float] = {}


func begin() -> void:
	var order: Array[String] = []
	var n: int = pi("segments")
	while order.size() < n:
		var bag: Array[String] = KINDS.duplicate()
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: String = bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		order.append_array(bag)
	order.resize(n)
	for k: int in n:
		var x0: float = 500.0 + float(k) * SEG_W
		var seg: Dictionary = {"kind": order[k], "x": x0 + SEG_W * 0.5, "taken": false, "phase": rng.randf() * TAU}
		match order[k]:
			"pit":
				seg["w"] = p("pit_width")
			"rope":
				seg["w"] = p("rope_pit_width")
			"barrel":
				seg["bx"] = x0 + SEG_W + 300.0
			"rat":
				seg["bx"] = x0 + SEG_W * 0.5
		if order[k] in ["treasure", "pit", "barrel"]:
			_treasure_total += 1
		_segs.append(seg)
	_goal_x = 500.0 + float(n) * SEG_W + 200.0
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("0a0605")
	st.env.ambient_light_color = Color(0.4, 0.26, 0.2)
	st.env.ambient_light_energy = 0.22
	st.key.light_energy = 0.25
	var x0: float = -1600.0
	var x1: float = _goal_x + 1800.0
	_build_wall(st, x0, x1)
	_build_floor(st, x0, x1)
	var k: int = 0
	var x: float = x0
	while x < x1:
		_build_arch(st, x, k)
		x += ARCH_STEP
		k += 1
	for i: int in _segs.size():
		var sg: Dictionary = _segs[i]
		match String(sg["kind"]):
			"barrel":
				_barrels3[i] = _build_barrel(st)
			"rat":
				_rats3[i] = _build_rat(st)
			"rope":
				_ropes3[i] = _build_rope(st, i)
		if String(sg["kind"]) in ["treasure", "pit", "barrel"]:
			_treasure3[i] = _build_treasure(st)
	_build_door(st)


## Mur de briques du fond (une seule MultiMesh), joints sombres derrière.
func _build_wall(st: Stage3D, x0: float, x1: float) -> void:
	var y_top: float = -700.0
	var y_bot: float = FLOOR_Y + 200.0
	var w: float = (x1 - x0) * PX3
	var mid: Vector3 = st.to3(Vector2((x0 + x1) * 0.5, (y_top + y_bot) * 0.5), WALL_Z - 0.05)
	Stage3D.box(st.root, Vector3(w, (y_bot - y_top) * PX3, 0.05), mid, Stage3D.mat(Color("140b08"), 0.0, 1.0))
	var brick: Vector2 = Vector2(0.6, 0.28)
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(brick.x - 0.03, brick.y - 0.03, 0.08)
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = bm
	var cols: int = ceili(w / brick.x)
	var rows: int = ceili((y_bot - y_top) * PX3 / brick.y)
	mm.instance_count = cols * rows
	var top: Vector3 = st.to3(Vector2(x0, y_top), WALL_Z)
	for r: int in rows:
		for c: int in cols:
			var shift: float = brick.x * 0.5 if r % 2 == 1 else 0.0
			var at: Vector3 = top + Vector3(float(c) * brick.x + shift, -float(r) * brick.y, 0.0)
			var i: int = r * cols + c
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
			var shade: float = 0.75 + 0.25 * fmod(float(c * 7 + r * 13) * 0.37, 1.0)
			mm.set_instance_color(i, Color("3a1d13") * shade)
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.95)
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	st.root.add_child(mmi)


## Dalles de pierre du sol, interrompues par les fosses (fond noir et pointes).
func _build_floor(st: Stage3D, x0: float, x1: float) -> void:
	var holes: Array[Vector2] = []
	for sg: Dictionary in _segs:
		if String(sg["kind"]) in ["pit", "rope"]:
			holes.append(Vector2(float(sg["x"]) - float(sg["w"]) * 0.5, float(sg["x"]) + float(sg["w"]) * 0.5))
	var stone: StandardMaterial3D = Stage3D.mat(Color("6b4a2a"), 0.0, 0.85)
	var stone2: StandardMaterial3D = Stage3D.mat(Color("5a3d22"), 0.0, 0.9)
	var h: float = (1200.0 - FLOOR_Y) * PX3
	var slab: float = 240.0
	var x: float = x0
	var n: int = 0
	while x < x1:
		var e: float = x + slab
		for hl: Vector2 in holes:
			if x < hl.y and e > hl.x:
				e = hl.x if x < hl.x else hl.y
				break
		var inside: bool = false
		for hl2: Vector2 in holes:
			inside = inside or (x >= hl2.x and x < hl2.y)
		if inside:
			_build_pit(st, x, e)
		elif e > x:
			var c: Vector3 = st.to3(Vector2((x + e) * 0.5, FLOOR_Y), 0.0)
			Stage3D.box(st.root, Vector3((e - x) * PX3 - 0.01, h, 1.6), c + Vector3(0, -h * 0.5, -0.4), stone if n % 2 == 0 else stone2)
			n += 1
		x = maxf(e, x + 1.0)


func _build_pit(st: Stage3D, a: float, b: float) -> void:
	var c: Vector3 = st.to3(Vector2((a + b) * 0.5, 1080.0), 0.0)
	Stage3D.box(st.root, Vector3((b - a) * PX3, 0.05, 1.6), c + Vector3(0, -0.02, -0.4), Stage3D.mat(Color("050302"), 0.0, 1.0))
	var steel: StandardMaterial3D = Stage3D.mat(Color("8a8a96"), 0.45, 0.3)
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 14.0 * PX3
	cone.height = 50.0 * PX3
	cone.radial_segments = 6
	var x: float = a + 20.0
	while x < b - 10.0:
		for z: float in [-0.5, 0.0, 0.4]:
			var sp: MeshInstance3D = MeshInstance3D.new()
			sp.mesh = cone
			sp.material_override = steel
			sp.position = st.to3(Vector2(x, 1080.0 - 25.0), z)
			st.root.add_child(sp)
		x += 40.0


## Voûte : piliers, arc de pierre, casier à bouteilles, lampe à huile qui vacille.
func _build_arch(st: Stage3D, x: float, k: int) -> void:
	var stone: StandardMaterial3D = Stage3D.mat(Color("4a3020"), 0.0, 0.9)
	var top_y: float = 150.0
	var base: Vector3 = st.to3(Vector2(x, FLOOR_Y), PILLAR_Z)
	var ph: float = (FLOOR_Y - top_y) * PX3
	Stage3D.box(st.root, Vector3(0.45, ph, 0.5), base + Vector3(0, ph * 0.5, 0), stone)
	# Arc en claveaux jusqu'au pilier suivant.
	var r: float = ARCH_STEP * PX3 * 0.5
	var centre: Vector3 = base + Vector3(r, ph, 0)
	for s: int in 9:
		var a: float = PI * (float(s) + 0.5) / 9.0
		var vb: MeshInstance3D = Stage3D.box(st.root, Vector3(0.32, 0.36, 0.5), centre + Vector3(-cos(a) * r, sin(a) * r * 0.6, 0), stone)
		vb.rotation.z = -(a - PI * 0.5) * 0.6
	# Casier à bouteilles entre les piliers (plus loin : défile plus lentement).
	if k % 2 == 0:
		var rc: Vector3 = st.to3(Vector2(x + ARCH_STEP * 0.5, FLOOR_Y - 230.0), RACK_Z)
		Stage3D.box(st.root, Vector3(1.9, 2.0, 0.4), rc, Stage3D.mat(Color("2a160c"), 0.0, 0.7))
		var green: StandardMaterial3D = Stage3D.mat(Color("1d4a2a"), 0.3, 0.2)
		var red: StandardMaterial3D = Stage3D.mat(Color("4a1220"), 0.3, 0.2)
		for b: int in 12:
			var bot: MeshInstance3D = Stage3D.cylinder(st.root, 0.08, 0.36,
				rc + Vector3(-0.66 + float(b % 4) * 0.44, 0.6 - floorf(float(b) / 4.0) * 0.6, 0.15), green if (b + k) % 3 else red)
			bot.rotation.x = PI * 0.5
	# Lampe à huile accrochée au pilier.
	var lamp_at: Vector3 = base + Vector3(0, ph * 0.62, 0.32)
	Stage3D.cylinder(st.root, 0.06, 0.18, lamp_at, Stage3D.mat(Palette.BRONZE, 0.45, 0.3))
	var flame: MeshInstance3D = Stage3D.sphere(st.root, 0.07, lamp_at + Vector3(0, 0.16, 0), Stage3D.glow(Color(1.0, 0.6, 0.2), 4.0))
	_flames.append(flame)
	_lamps.append(Stage3D.omni(st.root, Color(1.0, 0.58, 0.26), 1.6, lamp_at + Vector3(0, 0.2, 0.4), 3.6))


func _build_barrel(st: Stage3D) -> Node3D:
	var n: Node3D = Node3D.new()
	st.root.add_child(n)
	var body: MeshInstance3D = Stage3D.cylinder(n, BARREL_R * PX3, 0.5, Vector3.ZERO, Stage3D.mat(Color("7a4a24"), 0.0, 0.7))
	body.rotation.x = PI * 0.5
	for z: float in [-0.17, 0.17]:
		var hoop: MeshInstance3D = Stage3D.cylinder(n, BARREL_R * PX3 * 1.04, 0.04, Vector3(0, 0, z),
			Stage3D.mat(Color("c0c0c8"), 0.45, 0.3))
		hoop.rotation.x = PI * 0.5
	Stage3D.box(n, Vector3(BARREL_R * PX3 * 1.8, 0.02, 0.51), Vector3.ZERO, Stage3D.mat(Color("3a2210")))
	return n


func _build_rat(st: Stage3D) -> Node3D:
	var n: Node3D = Node3D.new()
	st.root.add_child(n)
	var fur: StandardMaterial3D = Stage3D.mat(Color("6a6a70"), 0.0, 0.9)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = MeshPool.capsule(12.0 * PX3, RAT_W * PX3)
	body.material_override = fur
	body.rotation.z = PI * 0.5
	n.add_child(body)
	Stage3D.sphere(n, 9.0 * PX3, Vector3(RAT_W * 0.5 * PX3, 4.0 * PX3, 0), fur)
	Stage3D.sphere(n, 2.5 * PX3, Vector3((RAT_W * 0.5 + 5.0) * PX3, 7.0 * PX3, 0.03), Stage3D.glow(Palette.MULT_RED, 3.0))
	var tail_at: Vector3 = Vector3(-(RAT_W * 0.5 + 14.0) * PX3, -2.0 * PX3, 0)
	var tail: MeshInstance3D = Stage3D.cylinder(n, 1.5 * PX3, 32.0 * PX3, tail_at, Stage3D.mat(Color("c08080")))
	tail.rotation.z = PI * 0.5 + 0.3
	return n


func _build_treasure(st: Stage3D) -> Node3D:
	var n: Node3D = Node3D.new()
	st.root.add_child(n)
	var chip: MeshInstance3D = MeshInstance3D.new()
	chip.mesh = MeshPool.disc(22.0 * PX3, 0.04)
	var m: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.25)
	m.emission_enabled = true
	m.emission = Palette.GOLD
	m.emission_energy_multiplier = 0.6
	chip.material_override = m
	chip.rotation.x = PI * 0.5
	n.add_child(chip)
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.mesh = MeshPool.disc(16.0 * PX3, 0.045, 16)
	ring.material_override = Stage3D.mat(Palette.IVORY, 0.2, 0.4)
	ring.rotation.x = PI * 0.5
	n.add_child(ring)
	return n


## Câble de lustre : petit lustre au pivot, câble doré, anneau au bout.
func _build_rope(st: Stage3D, i: int) -> Array:
	var pivot: Vector3 = st.to3(Vector2(float(_segs[i]["x"]), FLOOR_Y - ROPE_PIVOT_H), 0.0)
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	var lustre: Node3D = Node3D.new()
	lustre.position = pivot
	st.root.add_child(lustre)
	Stage3D.sphere(lustre, 0.12, Vector3.ZERO, gilt)
	for a: int in 6:
		var arm: MeshInstance3D = Stage3D.cylinder(lustre, 0.015, 0.4, Vector3(cos(float(a)) * 0.15, 0.05, sin(float(a)) * 0.15), gilt)
		arm.rotation = Vector3(0, -float(a), PI * 0.5)
		Stage3D.sphere(lustre, 0.035, Vector3(cos(float(a)) * 0.32, 0.12, sin(float(a)) * 0.32), Stage3D.glow(Color(1.0, 0.85, 0.6), 3.0))
	var cable: MeshInstance3D = Stage3D.cylinder(st.root, 0.018, ROPE_LEN * PX3, pivot, gilt)
	var end: MeshInstance3D = Stage3D.sphere(st.root, 10.0 * PX3, pivot, Stage3D.glow(Palette.GOLD_LIGHT, 1.5))
	return [cable, end]


## Porte de sortie : cadre doré, battants de chêne, bouteille du patron éclairée.
func _build_door(st: Stage3D) -> void:
	var c: Vector3 = st.to3(Vector2(_goal_x + 70.0, FLOOR_Y - 110.0), -0.2)
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	Stage3D.box(st.root, Vector3(0.7, 1.1, 0.1), c, Stage3D.mat(Color("2a1a10"), 0.0, 0.6))
	Stage3D.box(st.root, Vector3(0.82, 0.06, 0.14), c + Vector3(0, 0.58, 0), gilt)
	for sx: float in [-0.41, 0.41]:
		Stage3D.box(st.root, Vector3(0.06, 1.16, 0.14), c + Vector3(sx, 0, 0), gilt)
	var bottle: MeshInstance3D = Stage3D.cylinder(st.root, 0.07, 0.3, c + Vector3(0, 0.85, 0.1), Stage3D.glow(Color("2ee6a8"), 1.2))
	bottle.rotation.z = 0.0
	Stage3D.omni(st.root, Palette.GOLD_LIGHT, 1.5, c + Vector3(0, 0.6, 0.8), 3.0)


func _sync_3d() -> void:
	if stage == null:
		return
	var st: Stage3D = stage
	st.cam.position.x = _cam * PX3
	for i: int in _barrels3.keys():
		var b: Node3D = _barrels3[i]
		b.position = st.to3(Vector2(float(_segs[i]["bx"]), FLOOR_Y - BARREL_R), 0.0)
		b.rotation.z = float(_segs[i]["bx"]) / BARREL_R
	for i2: int in _rats3.keys():
		var r: Node3D = _rats3[i2]
		var bx: float = float(_segs[i2]["bx"])
		var last: float = _rat_last.get(i2, bx)
		if absf(bx - last) > 0.01:
			r.rotation.y = 0.0 if bx > last else PI
		_rat_last[i2] = bx
		r.position = st.to3(Vector2(bx, FLOOR_Y - 14.0 - absf(sin(t * 14.0)) * 3.0), 0.0)
	for i3: int in _treasure3.keys():
		var tr3: Node3D = _treasure3[i3]
		tr3.visible = not bool(_segs[i3]["taken"])
		var tp: Vector2 = _treasure_pos(_segs[i3])
		tr3.position = st.to3(tp + Vector2(0, sin(t * 3.0 + i3) * 6.0), 0.0)
		tr3.rotation.y = t * 2.5
	for i4: int in _ropes3.keys():
		var parts: Array = _ropes3[i4]
		var pivot: Vector2 = Vector2(float(_segs[i4]["x"]), FLOOR_Y - ROPE_PIVOT_H)
		var e: Vector2 = _rope_end(i4)
		var cable: MeshInstance3D = parts[0]
		cable.position = st.to3((pivot + e) * 0.5, 0.0)
		cable.rotation.z = _rope_angle(i4)
		(parts[1] as MeshInstance3D).position = st.to3(e, 0.0)
	# Lampes : seules celles près de la caméra éclairent (téléphones : peu de lumières par objet).
	for k: int in _lamps.size():
		var near: bool = absf(_lamps[k].position.x - st.cam.position.x) < LAMP_RANGE
		_lamps[k].visible = near
		var fl: float = 1.0 + 0.18 * sin(t * 13.0 + float(k) * 1.7) + 0.08 * sin(t * 31.0 + float(k))
		_lamps[k].light_energy = 1.6 * fl
		_flames[k].scale = Vector3.ONE * fl


func _dur() -> float:
	return p("duration") * slow


## Fosse sous x (index du segment) ou -1.
func _pit_at(x: float) -> int:
	for k: int in _segs.size():
		var s: Dictionary = _segs[k]
		if String(s["kind"]) in ["pit", "rope"] and absf(x - float(s["x"])) < float(s["w"]) * 0.5:
			return k
	return -1


func _rope_angle(k: int) -> float:
	return p("rope_swing") * sin(t * TAU / p("rope_period") + float(_segs[k]["phase"]))


func _rope_end(k: int) -> Vector2:
	var a: float = _rope_angle(k)
	var pivot: Vector2 = Vector2(float(_segs[k]["x"]), FLOOR_Y - ROPE_PIVOT_H)
	return pivot + Vector2(sin(a), cos(a)) * ROPE_LEN


func _treasure_pos(s: Dictionary) -> Vector2:
	var x: float = float(s["x"])
	if String(s["kind"]) == "barrel":
		x -= SEG_W * 0.25
	return Vector2(x, FLOOR_Y - TREASURE_H - BODY.y * 0.5)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	if confirm_pressed(event) or sym_pressed(event) == 3 or GameInput.pressed(event, &"ui_up"):
		_jump_queued = true
		return true
	return false


func _jump() -> void:
	if _stun > 0.0:
		return
	if _rope >= 0:
		# Se lâcher du câble : on garde l'élan du balancement.
		var a: float = _rope_angle(_rope)
		var w: float = p("rope_swing") * TAU / p("rope_period") * cos(t * TAU / p("rope_period") + float(_segs[_rope]["phase"]))
		_vx = maxf(w * ROPE_LEN * cos(a), 0.0) + p("run_speed") * 0.6
		_vy = -p("jump_speed") * 0.6
		_rope = -1
		_ground = false
		AudioBus.play("whoosh", 1.2, -6.0)
	elif _ground:
		_vy = -p("jump_speed")
		_ground = false
		AudioBus.play("decor_squeak", 1.4, -8.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_stun = maxf(0.0, _stun - dt)
	if _jump_queued or _bot_jump:
		_jump()
	_jump_queued = false
	_bot_jump = false
	var axis: float = clampf(held_vector().x + _bot_axis, -1.0, 1.0)
	if mouse and _mouse_x >= 0.0:
		axis = clampf((_mouse_x - (_x - _cam)) / 120.0, -1.0, 1.0)
	if _stun > 0.0:
		axis = 0.0
	if _rope >= 0:
		var e: Vector2 = _rope_end(_rope)
		_x = e.x
		_y = e.y + BODY.y
	else:
		if _ground:
			_vx = axis * p("run_speed")
		else:
			_vx = move_toward(_vx, axis * p("run_speed"), p("air_control") * dt)
		_vy += p("gravity") * dt
		_x += _vx * dt
		_y += _vy * dt
		_x = maxf(_x, 60.0)
		_land()
		_grab_rope()
	_run_anim += absf(_vx) * dt * 0.02
	_obstacles(dt)
	_collect()
	_cam = clampf(_x - SCREEN_X, 0.0, _goal_x - size.x + 200.0)
	_sync_3d()
	if _x >= _goal_x or t >= _dur():
		_end()


func _land() -> void:
	if _vy < 0.0:
		return
	var pit: int = _pit_at(_x)
	if pit < 0 and _y >= FLOOR_Y:
		_y = FLOOR_Y
		_vy = 0.0
		_ground = true
	elif pit >= 0 and _y > FLOOR_Y + p("fall_depth"):
		# Chute : retour au bord de la fosse, un peu de temps perdu.
		_falls += 1
		pop(Vector2(_x - _cam, FLOOR_Y - 150.0), 0.0, "TRIAL_CAVE_FALL")
		AudioBus.play("decor_topple", 0.8, -4.0)
		var s: Dictionary = _segs[pit]
		_x = float(s["x"]) - float(s["w"]) * 0.5 - 60.0
		_y = FLOOR_Y
		_vx = 0.0
		_vy = 0.0
		_ground = true
		_stun = p("fall_stun")
	elif pit >= 0:
		_ground = false


func _grab_rope() -> void:
	if _ground:
		return
	for k: int in _segs.size():
		if String(_segs[k]["kind"]) != "rope":
			continue
		# Les mains attrapent le câble sur sa moitié inférieure (plus tolérant que le seul bout).
		var e: Vector2 = _rope_end(k)
		var pivot: Vector2 = Vector2(float(_segs[k]["x"]), FLOOR_Y - ROPE_PIVOT_H)
		var hands: Vector2 = Vector2(_x, _y - BODY.y)
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(hands, pivot.lerp(e, p("rope_grab_from")), e)
		if near.distance_to(hands) < GRAB_R * p("grab_scale") and _x < float(_segs[k]["x"]) + 60.0:
			_rope = k
			_vx = 0.0
			_vy = 0.0
			AudioBus.play("cloth", 1.0, -6.0)
			return


func _obstacles(dt: float) -> void:
	for s: Dictionary in _segs:
		var kind: String = String(s["kind"])
		if kind == "barrel":
			s["bx"] = float(s["bx"]) - p("barrel_speed") * dt
			var start: float = float(s["x"]) - SEG_W * 0.5
			if float(s["bx"]) < start - 200.0:
				s["bx"] = start + SEG_W + 300.0
			_bump(Vector2(float(s["bx"]), FLOOR_Y - BARREL_R), BARREL_R)
		elif kind == "rat":
			var x0: float = float(s["x"])
			s["bx"] = x0 + sin(t * p("rat_speed") + float(s["phase"])) * SEG_W * 0.3
			_bump(Vector2(float(s["bx"]), FLOOR_Y - 14.0), RAT_W * 0.5)


func _bump(c: Vector2, r: float) -> void:
	if _stun > 0.0 or _rope >= 0:
		return
	var feet: Vector2 = Vector2(_x, _y - BODY.y * 0.3)
	if absf(feet.x - c.x) < r + BODY.x * 0.4 and absf(feet.y - c.y) < r + BODY.y * 0.3:
		_hits += 1
		_stun = p("hit_stun")
		_vx = -p("run_speed") * 0.5
		_x -= 40.0
		pop(Vector2(_x - _cam, FLOOR_Y - 150.0), 0.0, "TRIAL_CAVE_HIT")
		AudioBus.play("decor_bottle", 0.7, -4.0)


func _collect() -> void:
	for s: Dictionary in _segs:
		if bool(s["taken"]) or not String(s["kind"]) in ["treasure", "pit", "barrel"]:
			continue
		var tp: Vector2 = _treasure_pos(s)
		if tp.distance_to(Vector2(_x, _y - BODY.y * 0.5)) < 60.0:
			s["taken"] = true
			_treasures += 1
			pop(tp - Vector2(_cam, 50.0), 1.0, "TRIAL_CAVE_TREASURE")
			AudioBus.play("coins", 1.2, -4.0)


func _end() -> void:
	_ended = true
	var prog: float = clampf(_x / _goal_x, 0.0, 1.0)
	var tre: float = float(_treasures) / maxf(float(_treasure_total), 1.0)
	var sc: float = prog * p("weight_distance") + tre * (1.0 - p("weight_distance"))
	sc -= p("fall_penalty") * float(_falls) + p("hit_penalty") * float(_hits)
	if _x >= _goal_x:
		AudioBus.play("jackpot", 1.3, -8.0)
	finish(clampf(sc, 0.0, 1.0))


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Court à droite ; saute au bord des fosses, par-dessus tonneaux et rats ; aux grandes
	# fosses, attend le câble qui revient, s'y suspend puis se lâche en fin d'aller.
	if _rope >= 0:
		var a: float = _rope_angle(_rope)
		var rising: bool = cos(t * TAU / p("rope_period") + float(_segs[_rope]["phase"])) > 0.0
		return {"do": "confirm"} if rising and a > p("rope_swing") * 0.45 else {"do": ""}
	if not _ground:
		return {"do": "axis", "v": Vector2(1, 0)}
	var air: float = 2.0 * p("jump_speed") / p("gravity")
	var reach: float = p("run_speed") * air
	for s: Dictionary in _segs:
		var kind: String = String(s["kind"])
		var x: float = float(s["x"])
		match kind:
			"pit":
				var edge: float = x - float(s["w"]) * 0.5
				if edge - _x > 0.0 and edge - _x < reach * 0.5 - float(s["w"]) * 0.5 + 40.0:
					return {"do": "confirm"}
			"rope":
				var edge2: float = x - float(s["w"]) * 0.5
				if edge2 - _x > -10.0 and edge2 - _x < 120.0:
					var e: Vector2 = _rope_end(int(_segs.find(s)))
					var coming: bool = cos(t * TAU / p("rope_period") + float(s["phase"])) < 0.0
					var near: bool = e.x - edge2 < 110.0
					if edge2 - _x < 40.0 and not (coming and near):
						return {"do": "axis", "v": Vector2.ZERO}
					return {"do": "confirm"} if coming and near else {"do": "axis", "v": Vector2(1, 0)}
			"barrel", "rat":
				var bx: float = float(s["bx"])
				var closing: float = p("run_speed") + (p("barrel_speed") if kind == "barrel" else 0.0)
				var d: float = bx - _x
				if d > 0.0 and d < closing * air * 0.5 + 10.0 and d > closing * air * 0.25:
					return {"do": "confirm"}
		if kind in ["treasure", "barrel"] and not bool(s["taken"]):
			var dt_x: float = _treasure_pos(s).x - _x
			if dt_x < reach * 0.5 + 6.0 and dt_x > reach * 0.5 - 30.0:
				return {"do": "confirm"}
	return {"do": "axis", "v": Vector2(1, 0)}


func bot_apply(w: Dictionary) -> void:
	# Un geste par image : le saut garde l'élan de la course (comme le stick relâché un instant).
	var act: String = String(w.get("do", ""))
	if act == "axis":
		_bot_axis = (w.get("v", Vector2.ZERO) as Vector2).x
	_bot_jump = act == "confirm"


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	var c: float = _cam
	if stage == null:
		return
	# Le groom.
	var col: Color = Palette.MULT_RED if _stun > 0.0 and fmod(t * 10.0, 1.0) < 0.5 else Palette.ROULETTE_RED
	var cell: float = BODY.x / 8.0 * 1.4
	var at: Vector2 = Vector2(_x - c - 4.0 * cell, _y - 10.0 * cell + (sin(_run_anim) * 3.0 if _ground else 0.0))
	ArcadeKit.sprite(self, at, GROOM, cell, col)
	draw_rect(Rect2(at + Vector2(2.0 * cell, 0), Vector2(4.0 * cell, cell)), Palette.GOLD)
	# Bandeau : progression et trésors.
	var prog: float = clampf(_x / _goal_x, 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 400, 80, 800, 14), Color(Palette.INK, 0.8))
	draw_rect(Rect2(size.x * 0.5 - 400, 80, 800 * prog, 14), Palette.GOLD)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 400, 100, 800 * left, 6), Palette.CYAN)
	text(Vector2(size.x * 0.5, 140.0), tr("TRIAL_CAVE_STATUS") % [_treasures, _treasure_total], UiKit.SIZE_BODY, Palette.IVORY)
