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
const SUBSTEPS: int = 4
## Décor 3D : mètres par pixel, ampoules du caisson, machines voisines de la salle.
const PX3: float = 0.005
const BULBS: int = 24
const NEIGHBOR_X: Array[float] = [-1.0, 1.0]

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
var _ball_pool: MeshPool = null
var _flippers: Array[Node3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _bulb_on: StandardMaterial3D = null
var _bulb_off: StandardMaterial3D = null
var _launcher3: Node3D = null
var _cup_light: OmniLight3D = null
var _cup_flash: float = 0.0


func begin() -> void:
	_phase = rng.randf() * TAU
	for r: int in PEG_ROWS:
		var y: float = BOARD.position.y + 120.0 + float(r) * PEG_GAP.y
		var off: float = PEG_GAP.x * 0.5 if r % 2 == 1 else 0.0
		var x: float = BOARD.position.x + 60.0 + off
		while x < BOARD.end.x - 40.0:
			_pegs.append(Vector2(x, y))
			x += PEG_GAP.x
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("0c0610")
	st.env.ambient_light_color = Color(0.4, 0.25, 0.35)
	st.env.ambient_light_energy = 0.45
	var r: Node3D = st.root
	var lacquer: StandardMaterial3D = Stage3D.mat(Color("7a0c1e"), 0.3, 0.25)
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 0.8
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.25)
	var case_r: Rect2 = BOARD.grow(46.0)
	var cc: Vector3 = st.to3(case_r.get_center(), -0.3)
	Stage3D.box(r, Vector3(case_r.size.x * PX3, case_r.size.y * PX3, 0.5), cc, lacquer)
	# Plateau de laiton brossé (fond) avec rosace gravée.
	Stage3D.box(r, Vector3(BOARD.size.x * PX3, BOARD.size.y * PX3, 0.02), st.to3(BOARD.get_center(), -0.04), Stage3D.mat(Color("6a5230"),
		0.7, 0.45))
	# Rosace gravée : anneaux concentriques à peine plus clairs que le laiton.
	for ring: int in 4:
		var ros: MeshInstance3D = MeshInstance3D.new()
		ros.mesh = MeshPool.disc((220.0 - float(ring) * 50.0) * PX3, 0.004, 48)
		ros.material_override = Stage3D.mat(Color("6a5230").lightened(0.06 * float(ring % 2 + 1)), 0.45, 0.4)
		ros.rotation.x = PI * 0.5
		ros.position = st.to3(Vector2(_center(), BOARD.position.y + 330.0), -0.03 + 0.003 * float(ring))
		r.add_child(ros)
	# Cadre chromé.
	for e: Array in [[Vector2(0, -1), BOARD.size.x], [Vector2(0, 1), BOARD.size.x], [Vector2(-1, 0), BOARD.size.y], [Vector2(1, 0),
		BOARD.size.y]]:
		var d: Vector2 = e[0]
		var len_px: float = float(e[1]) + 40.0
		var at: Vector2 = BOARD.get_center() + d * (BOARD.size * 0.5 + Vector2(10, 10))
		var sz: Vector3 = Vector3(len_px * PX3, 20.0 * PX3, 0.08) if d.y != 0.0 else Vector3(20.0 * PX3, len_px * PX3, 0.08)
		Stage3D.box(r, sz, st.to3(at, 0.0), gilt)
	# Clous de laiton.
	var nail: CylinderMesh = MeshPool.disc(PEG_R * PX3, 0.06, 10)
	var nail_mat: StandardMaterial3D = Stage3D.mat(Color("f0d8a0"), 0.35, 0.3)
	for peg: Vector2 in _pegs:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = nail
		mi.material_override = nail_mat
		mi.rotation.x = PI * 0.5
		mi.position = st.to3(peg, 0.0)
		r.add_child(mi)
	# Lanceur, entonnoir, taquets, godets.
	_launcher3 = Node3D.new()
	r.add_child(_launcher3)
	Stage3D.box(_launcher3, Vector3(60.0 * PX3, 22.0 * PX3, 0.08), Vector3.ZERO, gilt)
	Stage3D.box(r, Vector3(BOARD.size.x * PX3, 3.0 * PX3, 0.03), st.to3(Vector2(_center(), LAUNCH_Y - 30.0), 0.0),
		Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.3))
	var c: float = _center()
	for sd: int in 2:
		var dir: float = -1.0 if sd == 0 else 1.0
		var a: Vector2 = Vector2(BOARD.position.x if sd == 0 else BOARD.end.x, FUNNEL_Y)
		var b: Vector2 = Vector2(c + dir * (KICK_GAP * 0.5 + KICK_HALF_W * 2.0), KICK_Y - 30.0)
		var rail: MeshInstance3D = Stage3D.box(r, Vector3(a.distance_to(b) * PX3, 6.0 * PX3, 0.06), st.to3((a + b) * 0.5, 0.0), gilt)
		rail.rotation.z = -(b - a).angle()
		var x0: float = c + dir * (KICK_GAP * 0.5 + KICK_HALF_W * 2.0)
		var fl: Node3D = Node3D.new()
		fl.position = st.to3(Vector2(x0, KICK_Y + 10.0), 0.02)
		r.add_child(fl)
		var blade: MeshInstance3D = Stage3D.box(fl, Vector3(KICK_HALF_W * 2.0 * PX3, 12.0 * PX3, 0.07), Vector3(-dir * KICK_HALF_W * PX3,
			0, 0), Stage3D.mat(Palette.IVORY, 0.3, 0.3))
		blade.name = "blade"
		Stage3D.cylinder(fl, 10.0 * PX3, 0.09, Vector3.ZERO, gilt).rotation.x = PI * 0.5
		_flippers.append(fl)
	Stage3D.box(r, Vector3(_silver_half() * 2.0 * PX3, 50.0 * PX3, 0.1), st.to3(Vector2(c, CUP_Y + 15.0), 0.0), Stage3D.mat(Color("b0b0bc"),
		0.45, 0.2))
	Stage3D.box(r, Vector3(_gold_half() * 2.0 * PX3, 52.0 * PX3, 0.12), st.to3(Vector2(c, CUP_Y + 15.0), 0.01), Stage3D.glow(Palette.GOLD,
		0.6))
	_cup_light = Stage3D.omni(r, Palette.GOLD_LIGHT, 0.6, st.to3(Vector2(c, CUP_Y - 40.0), 0.4), 2.0)
	# Ampoules du caisson (haut et bas) qui chassent.
	_bulb_on = Stage3D.glow(Palette.GOLD_LIGHT, 3.0)
	_bulb_off = Stage3D.mat(Palette.GOLD_DARK, 0.5, 0.4)
	for k: int in BULBS:
		var fx: float = case_r.position.x + 12.0 + (case_r.size.x - 24.0) * float(k) / float(BULBS - 1)
		for y: float in [case_r.position.y + 18.0, case_r.end.y - 18.0]:
			_bulbs.append(Stage3D.sphere(r, 7.0 * PX3, st.to3(Vector2(fx, y), 0.02), _bulb_off))
	# Salle : machines voisines de biais, rideau de perles de lumière.
	for side: float in NEIGHBOR_X:
		for n: int in 2:
			var at3: Vector3 = Vector3(side * (3.6 + float(n) * 2.3), cc.y, -1.6 - float(n) * 1.1)
			var m: MeshInstance3D = Stage3D.box(r, Vector3(2.0, 4.6, 0.6), at3, lacquer)
			m.rotation.y = -side * 0.5
			var face: MeshInstance3D = Stage3D.box(m, Vector3(1.5, 3.6, 0.02), Vector3(0, 0, 0.31),
				Stage3D.glow(Color("5a1030") if n == 0 else Color("103a4a"), 0.35))
			face.rotation.y = 0.0
	Stage3D.omni(r, Color(1.0, 0.75, 0.6), 0.8, cc + Vector3(0, 2.5, 4.0), 10.0)
	var chrome: StandardMaterial3D = Stage3D.mat(Color("f4f6ff"), 0.3, 0.12)
	chrome.emission_enabled = true
	chrome.emission = Color("8890a8")
	chrome.emission_energy_multiplier = 0.25
	_ball_pool = MeshPool.new(r, _ball_mesh(), chrome)


func _ball_mesh() -> SphereMesh:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = BALL_R * PX3
	sm.height = BALL_R * PX3 * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	return sm


func _sync_3d(dt: float) -> void:
	if _ball_pool == null:
		return
	var st: Stage3D = stage
	for k: int in _balls.size():
		var b: MeshInstance3D = _ball_pool.at(k)
		b.position = st.to3(_balls[k]["p"] as Vector2, 0.04)
		b.rotation.z -= (_balls[k]["v"] as Vector2).x * dt * 0.05
	_ball_pool.hide_from(_balls.size())
	_launcher3.position = st.to3(Vector2(_launcher_x(), LAUNCH_Y - 30.0), 0.02)
	for s2: int in 2:
		var dir: float = -1.0 if s2 == 0 else 1.0
		_flippers[s2].rotation.z = dir * 0.35 * _kick[s2]
	for k2: int in _bulbs.size():
		var on: bool = int(_lights * 8.0 + float(k2 % BULBS)) % 3 == (0 if k2 < BULBS else 1)
		_bulbs[k2].material_override = _bulb_on if on else _bulb_off
	_cup_flash = maxf(0.0, _cup_flash - dt * 2.0)
	_cup_light.light_energy = 0.6 + 3.0 * _cup_flash


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
		var target: float = _center() + dir * err * (_silver_half() + 40.0)
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
	_sync_3d(dt)
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


## Demi-largeurs des godets or et argent (réglages de l'épreuve).
func _gold_half() -> float:
	return p("gold_half")


func _silver_half() -> float:
	return p("silver_half")


func _score_ball(x: float) -> void:
	var dx: float = absf(x - _center())
	var sc: float = 0.0
	var key: String = "TRIAL_PACHINKO_GUTTER"
	if dx <= _gold_half():
		sc = 1.0
		key = "TRIAL_PACHINKO_GOLD"
		AudioBus.play("slot_win", 1.2, -4.0)
	elif dx <= _silver_half():
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
	if stage == null:
		return
	# Vitre : reflets en biais par-dessus le plateau 3D ; zones des taquets quand on frappe.
	var c: float = _center()
	for s: int in 2:
		var dir: float = -1.0 if s == 0 else 1.0
		var x0: float = c + dir * (KICK_GAP * 0.5 + KICK_HALF_W * 2.0)
		var x1: float = c + dir * KICK_GAP * 0.5
		var zone: Rect2 = Rect2(minf(x0, x1), KICK_Y - p("kick_window") * widen(), absf(x1 - x0), p("kick_window") * widen() * 2.0)
		draw_rect(zone, Color(Palette.CYAN, 0.05 + 0.18 * _kick[s]))
	var o: Vector2 = BOARD.position
	var sz: Vector2 = BOARD.size
	draw_colored_polygon(PackedVector2Array([o + Vector2(sz.x * 0.15, 0), o + Vector2(sz.x * 0.3, 0), o + Vector2(sz.x * 0.05, sz.y), o]),
		Color(1, 1, 1, 0.035))
	draw_colored_polygon(PackedVector2Array([o + Vector2(sz.x * 0.7, 0), o + Vector2(sz.x * 0.75, 0), o + Vector2(sz.x * 0.55, sz.y),
		o + Vector2(sz.x * 0.5, sz.y)]), Color(1, 1, 1, 0.025))
	# Pastilles : billes jouées.
	pips(Vector2(c, 70.0), _scores, pi("balls"))


## Au doigt : le taquet du côté touché.
func tap_action(pos: Vector2) -> StringName:
	return &"qte_left" if pos.x < size.x * 0.5 else &"qte_right"
