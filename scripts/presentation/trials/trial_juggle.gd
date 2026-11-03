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
## Décor 3D : mètres par pixel, plis des rideaux, ampoules de la rampe, vitesse de rotation.
const PX3: float = 0.005
const FOLDS: int = 18
const FOOTLIGHTS: int = 16
const TUMBLE: float = 7.0
const SKIN: Color = Color("e8c8a8")
## Profondeur des mains, des jetons et de la ligne : devant le jongleur.
const FRONT_Z: float = 0.4

var _chips: Array[Dictionary] = []
var _added: int = 0
var _add_t: float = 0.0
var _marks: Array[float] = []
var _hand_flash: Array[float] = [0.0, 0.0, 0.0]
var _bot_lane: int = -1
var _ended: bool = false
var _chip3: Array[Node3D] = []
var _hands3: Array[MeshInstance3D] = []
var _hand_mat: Array[StandardMaterial3D] = []
var _arms3: Array[MeshInstance3D] = []
var _shoulder: Vector3 = Vector3.ZERO


func begin() -> void:
	_build_3d()
	_add_chip()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("0a0306")
	st.env.ambient_light_color = Color(0.45, 0.2, 0.25)
	st.env.ambient_light_energy = 0.35
	st.key.light_energy = 0.2
	var r: Node3D = st.root
	# Rideaux de velours plissés de part et d'autre, lambrequin doré en haut.
	var velvet: StandardMaterial3D = Stage3D.mat(Color(0.42, 0.04, 0.09), 0.0, 0.75)
	for side: float in [-1.0, 1.0]:
		for k: int in FOLDS:
			var x: float = 960.0 + side * (600.0 + float(k) * 70.0)
			Stage3D.cylinder(r, 42.0 * PX3, 1400.0 * PX3, st.to3(Vector2(x, 420.0), -0.6 - 0.05 * float(k % 2)), velvet)
	Stage3D.box(r, Vector3(30.0, 6.0, 0.05), st.to3(Vector2(960.0, 400.0), -1.4), Stage3D.mat(Color("140408"), 0.0, 0.9))
	for k2: int in 40:
		var vx: float = -1000.0 + float(k2) * 100.0
		Stage3D.cylinder(r, 50.0 * PX3, 120.0 * PX3, st.to3(Vector2(vx, 40.0), -0.4), velvet)
	Stage3D.box(r, Vector3(30.0, 14.0 * PX3, 0.06), st.to3(Vector2(960.0, 104.0), -0.36), Stage3D.mat(Palette.GOLD, 0.45, 0.3))
	# Plancher de scène et rampe de lumières.
	var floor_y: float = HIT_Y + 120.0
	var plank: StandardMaterial3D = Stage3D.mat(Color("4a2a16"), 0.0, 0.5)
	var plank2: StandardMaterial3D = Stage3D.mat(Color("3e2412"), 0.0, 0.5)
	for k3: int in 6:
		var z: float = -1.2 + float(k3) * 0.4
		var b: MeshInstance3D = Stage3D.box(r, Vector3(30.0, 0.04, 0.38), st.to3(Vector2(960.0, floor_y), 0.0) + Vector3(0, -0.02, z),
			plank if k3 % 2 == 0 else plank2)
		b.name = "plank%d" % k3
	var bulb: StandardMaterial3D = Stage3D.glow(Palette.GOLD_LIGHT, 2.5)
	for k4: int in FOOTLIGHTS:
		var fx: float = 960.0 - 900.0 + 1800.0 * float(k4) / float(FOOTLIGHTS - 1)
		Stage3D.sphere(r, 12.0 * PX3, st.to3(Vector2(fx, floor_y), 0.0) + Vector3(0, 0.03, 0.9), bulb)
	Stage3D.omni(r, Color(1.0, 0.8, 0.5), 1.4, st.to3(Vector2(960.0, floor_y - 100.0), 1.2), 6.0)
	# Projecteur : cône de lumière visible et spot sur le jongleur.
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.8)
	spot.light_energy = 6.0
	spot.spot_range = 12.0
	spot.spot_angle = 22.0
	spot.position = st.to3(Vector2(960.0, -200.0), 2.0)
	r.add_child(spot)
	spot.look_at_from_position(spot.position, st.to3(Vector2(960.0, 700.0), 0.0))
	spot.shadow_enabled = RenderQuality.shadows()
	var cone: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 40.0 * PX3
	cm.bottom_radius = 420.0 * PX3
	cm.height = 1000.0 * PX3
	cone.mesh = cm
	var beam: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.95, 0.75), 0.4)
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.albedo_color.a = 0.022
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = beam
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone.position = st.to3(Vector2(960.0, 450.0), -0.5)
	r.add_child(cone)
	_build_juggler(st)


## Croupier jongleur : queue-de-pie, plastron, nœud papillon, haut-de-forme, trois bras.
func _build_juggler(st: Stage3D) -> void:
	var r: Node3D = st.root
	var c0: Vector2 = Vector2(960.0, HIT_Y + 120.0)
	var tux: StandardMaterial3D = Stage3D.mat(Color("16161e"), 0.0, 0.5)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = MeshPool.capsule(65.0 * PX3, 260.0 * PX3)
	body.material_override = tux
	body.position = st.to3(c0 - Vector2(0, 120.0), -0.15)
	r.add_child(body)
	Stage3D.box(r, Vector3(40.0 * PX3, 120.0 * PX3, 0.02), st.to3(c0 - Vector2(0, 170.0), -0.15 + 65.0 * PX3),
		Stage3D.mat(Palette.IVORY, 0.0, 0.5))
	Stage3D.box(r, Vector3(46.0 * PX3, 16.0 * PX3, 0.04), st.to3(c0 - Vector2(0, 228.0), -0.13 + 65.0 * PX3),
		Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.4))
	Stage3D.sphere(r, 50.0 * PX3, st.to3(c0 - Vector2(0, 280.0), -0.15), Stage3D.mat(SKIN, 0.0, 0.6))
	var hat: StandardMaterial3D = Stage3D.mat(Color("101014"), 0.1, 0.35)
	Stage3D.cylinder(r, 70.0 * PX3, 10.0 * PX3, st.to3(c0 - Vector2(0, 325.0), -0.15), hat)
	Stage3D.cylinder(r, 44.0 * PX3, 90.0 * PX3, st.to3(c0 - Vector2(0, 375.0), -0.15), hat)
	Stage3D.cylinder(r, 45.0 * PX3, 14.0 * PX3, st.to3(c0 - Vector2(0, 340.0), -0.15), Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.5))
	_shoulder = st.to3(c0 - Vector2(0, 190.0), -0.1)
	var arm: CylinderMesh = CylinderMesh.new()
	arm.top_radius = 14.0 * PX3
	arm.bottom_radius = 14.0 * PX3
	arm.height = 1.0
	for k: int in LANES:
		var a: MeshInstance3D = MeshInstance3D.new()
		a.mesh = arm
		a.material_override = tux
		r.add_child(a)
		_arms3.append(a)
		var hm: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.5)
		hm.emission_enabled = true
		hm.emission = Palette.GOLD_LIGHT
		hm.emission_energy_multiplier = 0.0
		_hand_mat.append(hm)
		_hands3.append(Stage3D.sphere(r, 30.0 * PX3, st.to3(Vector2(LANE_X[k], HIT_Y + 40.0), FRONT_Z), hm))
	# Ligne dorée de réception.
	Stage3D.box(r, Vector3((LANE_X[2] - LANE_X[0] + 600.0) * PX3, 4.0 * PX3, 0.01), st.to3(Vector2(960.0, HIT_Y), FRONT_Z - 0.05),
		Stage3D.glow(Palette.GOLD, 0.8))


func _sync_3d() -> void:
	if stage == null:
		return
	var st: Stage3D = stage
	while _chip3.size() < _chips.size():
		var chip: Node3D = CasinoChip3D.build(stage.root, _chips[_chip3.size()]["col"] as Color, CHIP_R * PX3)
		chip.scale = Vector3.ONE * 1.3
		_chip3.append(chip)
	for k: int in _chips.size():
		var c: Dictionary = _chips[k]
		var n: Node3D = _chip3[k]
		n.visible = float(c["wait"]) <= 0.0
		if n.visible:
			n.position = st.to3(_chip_pos(c), FRONT_Z)
			n.rotation = Vector3(float(c["age"]) * TUMBLE, float(c["age"]) * TUMBLE * 0.4, 0)
	for k2: int in LANES:
		var hand: Vector3 = st.to3(Vector2(LANE_X[k2], HIT_Y + 40.0 - 20.0 * _hand_flash[k2]), FRONT_Z)
		_hands3[k2].position = hand
		_hands3[k2].scale = Vector3.ONE * (1.0 + 0.3 * _hand_flash[k2])
		_hand_mat[k2].emission_energy_multiplier = 2.5 * _hand_flash[k2]
		var d: Vector3 = hand - _shoulder
		var y: Vector3 = d.normalized()
		var x: Vector3 = y.cross(Vector3(0, 0, 1)).normalized()
		_arms3[k2].transform = Transform3D(Basis(x, y * d.length(), x.cross(y)), (_shoulder + hand) * 0.5)


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
	_sync_3d()
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
	if stage == null:
		return
	# Cercle d'approche : se resserre sur la main quand un jeton redescend.
	for c: Dictionary in _chips:
		if float(c["wait"]) > 0.0:
			continue
		var near: float = 1.0 - clampf(absf(float(c["age"]) - _flight()) / 0.4, 0.0, 1.0)
		if near > 0.0:
			draw_arc(Vector2(LANE_X[int(c["lane"])], HIT_Y), CHIP_R + 30.0 * (1.0 - near), 0, TAU, 32, Color(Palette.GOLD_LIGHT, near), 3.0)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(size.x * 0.5 - 300, 120, 600, 10), Color(Palette.INK, 0.7))
	draw_rect(Rect2(size.x * 0.5 - 300, 120, 600 * left, 10), Palette.GOLD)
	var caught: int = _marks.filter(func(m: float) -> bool: return m > 0.0).size()
	text(Vector2(size.x * 0.5, 170.0), tr("TRIAL_JUGGLE_STATUS") % [caught, _chips.size()], UiKit.SIZE_BODY, Palette.IVORY)
