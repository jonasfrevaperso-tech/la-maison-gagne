class_name TrialFishing
extends ThrowTrial
## LA PÊCHE AU GROS (écran dédié) : la fontaine du hall et ses carpes dorées. Pour chaque
## poisson : LANCER (la jauge va et vient, valider quand elle touche les remous), FERRER (le
## bouchon plonge : valider vite), puis REMONTER (maintenir pour mouliner, relâcher pour donner
## du fil) en gardant la tension dans la zone verte pendant que la carpe tire par à-coups.
## Trop tendu, le fil casse ; trop mou, elle s'enfuit.
## Note = par poisson, lancer × poids + ferrage × poids + remontée (temps dans la zone, si
## remonté) × poids ; moyenne des poissons.

const POND: Rect2 = Rect2(260.0, 380.0, 1400.0, 520.0)
const ROD: Vector2 = Vector2(300.0, 960.0)
const GAUGE: Rect2 = Rect2(1720.0, 300.0, 40.0, 560.0)
## Décor 3D : le plan du jeu (px) est posé au sol du hall (m par px), caméra en plongée.
const PX3: float = 0.005
const GROUND_CENTER: Vector2 = Vector2(960.0, 640.0)
const WATER_Y: float = 0.2
const RIM_H: float = 0.32
const RIM_W: float = 0.26
const TILE: float = 1.0
const KOI_COLORS: Array[Color] = [Color("ff8a1e"), Color("f4f0e6"), Color("ffd23f"), Color("e04a1a"), Color("f4f0e6"), Color("ff8a1e")]
const RIPPLES: int = 3
const WATER_SHADER: String = "res://shaders/water.gdshader"

var _fish: int = 0
var _phase: String = "cast"
var _gauge: float = 0.0
var _gauge_dir: float = 1.0
var _spot: float = 0.5
var _lure: float = 0.0
var _wait: float = 0.0
var _bite_t: float = 0.0
var _tension: float = 0.3
var _dist: float = 1.0
var _hold: bool = false
var _pull: float = 0.0
var _pull_t: float = 0.0
var _in_zone: float = 0.0
var _reel_t: float = 0.0
var _slack_t: float = 0.0
var _part: Dictionary = {}
var _scores: Array[float] = []
var _pause: float = 0.0
var _carps: Array[Dictionary] = []
var _koi3: Array[Node3D] = []
var _bob3: Node3D = null
var _line3: MeshInstance3D = null
var _rod3: Node3D = null
var _ripples3: Array[MeshInstance3D] = []
var _splash3: Array[MeshInstance3D] = []


func begin() -> void:
	for k: int in 6:
		var at: Vector2 = Vector2(rng.randf_range(POND.position.x + 80, POND.end.x - 80),
			rng.randf_range(POND.position.y + 60, POND.end.y - 60))
		_carps.append({"p": at,
			"a": rng.randf() * TAU, "s": rng.randf_range(40.0, 90.0)})
	_new_fish()
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


## Point du plan de jeu (px) posé au sol du hall, à la hauteur `h`.
func _w3(px: Vector2, h: float = 0.0) -> Vector3:
	return Vector3((px.x - GROUND_CENTER.x) * PX3, h, (px.y - GROUND_CENTER.y) * PX3)


## Position écran d'un point du plan (pour les annonces), au ras de l'eau.
func _scr(px: Vector2) -> Vector2:
	return stage.project(_w3(px, WATER_Y)) if stage != null else px


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color("120e16")
	st.env.ambient_light_color = Color(0.5, 0.45, 0.55)
	st.env.ambient_light_energy = 0.5
	st.key.light_energy = 0.4
	st.look(Vector3(0, 6.2, 6.6), Vector3(0, 0.2, -0.5), 40.0)
	var r: Node3D = st.root
	_build_floor(r)
	# Colonnade du fond, chapiteaux dorés.
	var marble: StandardMaterial3D = Stage3D.mat(Color("c8c0b2"), 0.0, 0.4)
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	Stage3D.box(r, Vector3(24, 8, 0.2), Vector3(0, 4, -4.8), Stage3D.mat(Color("2a2230"), 0.0, 0.8))
	for k: int in 9:
		var x: float = -8.8 + float(k) * 2.2
		Stage3D.cylinder(r, 0.28, 5.0, Vector3(x, 2.5, -4.4), marble)
		Stage3D.box(r, Vector3(0.75, 0.22, 0.75), Vector3(x, 5.0, -4.4), gilt)
		Stage3D.box(r, Vector3(0.75, 0.16, 0.75), Vector3(x, 0.08, -4.4), gilt)
	# Bassin : fond de mosaïque, margelle de marbre, eau.
	var pond_c: Vector3 = _w3(POND.get_center())
	var pw: float = POND.size.x * PX3
	var pd: float = POND.size.y * PX3
	Stage3D.box(r, Vector3(pw, 0.04, pd), pond_c + Vector3(0, 0.02, 0), Stage3D.mat(Color("0c3a44"), 0.0, 0.8))
	for e: Array in [[Vector3(0, 0, -pd * 0.5 - RIM_W * 0.5), Vector3(pw + RIM_W * 2.0, RIM_H, RIM_W)],
			[Vector3(0, 0, pd * 0.5 + RIM_W * 0.5), Vector3(pw + RIM_W * 2.0, RIM_H, RIM_W)],
			[Vector3(-pw * 0.5 - RIM_W * 0.5, 0, 0), Vector3(RIM_W, RIM_H, pd)],
			[Vector3(pw * 0.5 + RIM_W * 0.5, 0, 0), Vector3(RIM_W, RIM_H, pd)]]:
		var sz: Vector3 = e[1]
		Stage3D.box(r, sz, pond_c + (e[0] as Vector3) + Vector3(0, RIM_H * 0.5, 0), marble)
		var inner: Vector3 = (e[0] as Vector3).normalized() * -RIM_W * 0.45
		var line: Vector3 = Vector3(sz.x if sz.x > sz.z else 0.035, 0.02, sz.z if sz.z > sz.x else 0.035)
		Stage3D.box(r, line, pond_c + (e[0] as Vector3) + inner + Vector3(0, RIM_H, 0), gilt)
	var water: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(pw, pd)
	plane.subdivide_width = 40
	plane.subdivide_depth = 16
	water.mesh = plane
	var wm: ShaderMaterial = ShaderMaterial.new()
	wm.shader = load(WATER_SHADER) as Shader
	water.material_override = wm
	water.position = pond_c + Vector3(0, WATER_Y, 0)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(water)
	# Carpes koï.
	for k2: int in _carps.size():
		_koi3.append(_build_koi(r, KOI_COLORS[k2 % KOI_COLORS.size()], KOI_COLORS[(k2 + 3) % KOI_COLORS.size()]))
	_build_statue(r, marble, gilt)
	# Canne, fil, bouchon, remous.
	_rod3 = Node3D.new()
	_rod3.position = _w3(ROD, 0.6)
	r.add_child(_rod3)
	var rod_m: StandardMaterial3D = Stage3D.mat(Color("7a4a24"), 0.0, 0.35)
	rod_m.clearcoat_enabled = true
	Stage3D.cylinder(_rod3, 0.03, 2.6, Vector3(0, 1.3, 0), rod_m, 0.012)
	Stage3D.cylinder(_rod3, 0.05, 0.5, Vector3(0, 0.1, 0), Stage3D.mat(Color("2a1a10"), 0.0, 0.7))
	var reel: MeshInstance3D = Stage3D.cylinder(_rod3, 0.09, 0.06, Vector3(0.06, 0.4, 0), Stage3D.mat(Color("b8b8c4"), 0.45, 0.25))
	reel.name = "reel"
	reel.rotation.z = PI * 0.5
	_rod3.rotation = Vector3(-0.75, -0.35, 0)
	_line3 = MeshInstance3D.new()
	var lm: CylinderMesh = CylinderMesh.new()
	lm.top_radius = 0.005
	lm.bottom_radius = 0.005
	lm.height = 1.0
	lm.radial_segments = 4
	_line3.mesh = lm
	_line3.material_override = Stage3D.mat(Color(0.95, 0.95, 0.9), 0.0, 0.5)
	r.add_child(_line3)
	_bob3 = Node3D.new()
	r.add_child(_bob3)
	Stage3D.sphere(_bob3, 0.07, Vector3(0, 0, 0), Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.3))
	Stage3D.sphere(_bob3, 0.045, Vector3(0, 0.06, 0), Stage3D.mat(Palette.IVORY, 0.0, 0.3))
	Stage3D.cylinder(_bob3, 0.008, 0.12, Vector3(0, 0.13, 0), Stage3D.mat(Palette.INK, 0.0, 0.5))
	var ring_m: StandardMaterial3D = Stage3D.glow(Palette.IVORY, 0.6)
	ring_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k3: int in RIPPLES * 2:
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.95
		tm.outer_radius = 1.0
		tm.rings = 32
		tm.ring_segments = 4
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.mesh = tm
		ring.material_override = ring_m.duplicate() as StandardMaterial3D
		r.add_child(ring)
		(_ripples3 if k3 < RIPPLES else _splash3).append(ring)
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.9, 0.75), 2.0, Vector3(0, 4.5, -0.3), 10.0)
	lamp.shadow_enabled = RenderQuality.shadows()


## Dallage de marbre en damier (une seule MultiMesh).
func _build_floor(r: Node3D) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(TILE * 0.98, 0.04, TILE * 0.98)
	mm.mesh = bm
	var nx: int = 20
	var nz: int = 10
	mm.instance_count = nx * nz
	for i: int in nx * nz:
		var x: float = (float(i % nx) - float(nx - 1) * 0.5) * TILE
		var z: float = -4.5 + float(i / nx) * TILE
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(x, -0.02, z)))
		mm.set_instance_color(i, Color("8a8278") if (i % nx + i / nx) % 2 == 0 else Color("2a2430"))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.45)
	m.vertex_color_use_as_albedo = true
	mmi.material_override = m
	r.add_child(mmi)


## Carpe koï : corps fuselé, nageoire caudale (qui ondule), tache de couleur sur le dos.
func _build_koi(r: Node3D, body: Color, spot: Color) -> Node3D:
	var n: Node3D = Node3D.new()
	r.add_child(n)
	var bm: MeshInstance3D = MeshInstance3D.new()
	bm.mesh = MeshPool.capsule(0.07, 0.38)
	bm.material_override = Stage3D.mat(body, 0.1, 0.35)
	bm.rotation.z = PI * 0.5
	bm.scale = Vector3(1.0, 1.0, 0.6)
	n.scale = Vector3.ONE * 1.4
	n.add_child(bm)
	Stage3D.sphere(n, 0.045, Vector3(0.03, 0.035, 0), Stage3D.mat(spot, 0.1, 0.35))
	var tail: Node3D = Node3D.new()
	tail.name = "tail"
	tail.position = Vector3(-0.19, 0, 0)
	n.add_child(tail)
	var fin: MeshInstance3D = Stage3D.box(tail, Vector3(0.12, 0.012, 0.12), Vector3(-0.05, 0, 0),
		Stage3D.mat(body.lightened(0.2), 0.0, 0.5))
	fin.rotation.y = PI * 0.25
	return n


## Fontaine : socle, deux vasques, figure dorée, filets d'eau qui retombent dans le bassin.
func _build_statue(r: Node3D, marble: StandardMaterial3D, gilt: StandardMaterial3D) -> void:
	var at: Vector3 = _w3(Vector2(POND.end.x - 220.0, POND.position.y - 10.0))
	Stage3D.cylinder(r, 0.32, 0.7, at + Vector3(0, 0.35, 0), marble)
	Stage3D.cylinder(r, 0.65, 0.14, at + Vector3(0, 0.75, 0), marble, 0.8)
	Stage3D.cylinder(r, 0.1, 0.6, at + Vector3(0, 1.1, 0), marble)
	Stage3D.cylinder(r, 0.3, 0.1, at + Vector3(0, 1.42, 0), marble, 0.42)
	Stage3D.sphere(r, 0.16, at + Vector3(0, 1.66, 0), gilt)
	Stage3D.cylinder(r, 0.04, 0.3, at + Vector3(0, 1.9, 0), gilt, 0.0)
	var stream: StandardMaterial3D = Stage3D.glow(Color(0.7, 0.9, 1.0), 0.4)
	stream.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stream.albedo_color.a = 0.45
	for k: int in 6:
		var a: float = TAU * float(k) / 6.0
		var top: Vector3 = at + Vector3(cos(a) * 0.72, 0.75, sin(a) * 0.72)
		Stage3D.cylinder(r, 0.012, 0.75 - WATER_Y, Vector3(top.x, (0.75 + WATER_Y) * 0.5, top.z), stream)


## Étire le fil entre deux points.
func _stretch(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var len_m: float = maxf(d.length(), 0.001)
	var y: Vector3 = d / len_m
	var x: Vector3 = y.cross(Vector3(0, 0, 1))
	if x.length() < 0.01:
		x = Vector3(1, 0, 0)
	x = x.normalized()
	mi.transform = Transform3D(Basis(x, y * len_m, x.cross(y)), (a + b) * 0.5)


func _sync_3d(dt: float) -> void:
	if _bob3 == null:
		return
	for k: int in _carps.size():
		var c: Dictionary = _carps[k]
		var koi: Node3D = _koi3[k]
		koi.position = _w3(c["p"] as Vector2, WATER_Y - 0.1)
		koi.rotation.y = -float(c["a"])
		(koi.get_node("tail") as Node3D).rotation.y = sin(t * 9.0 + float(k)) * 0.5
	var bend: float = _tension if _phase == "reel" else 0.0
	_rod3.rotation.x = -0.75 + 0.25 * bend
	(_rod3.get_node("reel") as Node3D).rotation.x += (8.0 if _hold else 0.0) * dt
	var tip: Vector3 = (_rod3.global_transform if _rod3.is_inside_tree() else _rod3.transform) * Vector3(0, 2.6, 0)
	var bob: Vector3 = _w3(_spot_pos(_lure * (_dist if _phase == "reel" else 1.0)), WATER_Y + 0.03)
	if _phase == "cast":
		bob = tip + Vector3(0, -0.6, 0)
	elif _phase == "bite":
		bob.y -= 0.05 + sin(t * 40.0) * 0.03
	elif _phase == "reel":
		bob.y += sin(t * 25.0) * 0.015 * bend
	_bob3.position = bob
	_stretch(_line3, tip, bob)
	# Remous du coin visé (lancer) et éclaboussure du bouchon.
	var spot: Vector3 = _w3(_spot_pos(_spot), WATER_Y + 0.01)
	for k2: int in RIPPLES:
		var ph: float = fmod(t * 0.55 + float(k2) / float(RIPPLES), 1.0)
		var ring: MeshInstance3D = _ripples3[k2]
		ring.visible = _phase == "cast"
		ring.position = spot
		ring.scale = Vector3.ONE * (0.1 + ph * 0.45)
		(ring.material_override as StandardMaterial3D).albedo_color.a = 0.6 * (1.0 - ph)
		var sp: MeshInstance3D = _splash3[k2]
		var sph: float = fmod(t * (1.6 if _phase == "bite" else 0.7) + float(k2) / float(RIPPLES), 1.0)
		sp.visible = _phase != "cast" and _phase != "done"
		sp.position = Vector3(bob.x, WATER_Y + 0.01, bob.z)
		sp.scale = Vector3.ONE * (0.06 + sph * 0.25)
		(sp.material_override as StandardMaterial3D).albedo_color.a = 0.5 * (1.0 - sph)


func _new_fish() -> void:
	_phase = "cast"
	_wait = 0.0
	_gauge = 0.0
	_gauge_dir = 1.0
	_spot = rng.randf_range(0.35, 0.9)
	_part = {}
	_tension = p("tension_start")
	_dist = 1.0
	_in_zone = 0.0
	_reel_t = 0.0
	_slack_t = 0.0
	_hold = false


func _spot_pos(v: float) -> Vector2:
	return Vector2(lerpf(POND.position.x + 120.0, POND.end.x - 80.0, v), POND.get_center().y + 40.0)


func handle(event: InputEvent) -> bool:
	if confirm_pressed(event):
		_press()
		_hold = true
		return true
	if confirm_released(event):
		_hold = false
		return true
	return false


func _press() -> void:
	match _phase:
		"cast":
			_lure = _gauge
			var err: float = absf(_gauge - _spot)
			_part["cast"] = clampf(1.0 - err / (p("cast_tolerance") * widen()), 0.0, 1.0)
			pop(_scr(_spot_pos(_lure)) + Vector2(0, -60), float(_part["cast"]))
			_phase = "wait"
			_wait = rng.randf_range(p("bite_min"), p("bite_max")) * slow
			AudioBus.play("whoosh", 0.9, -4.0)
		"wait":
			# Ferrer avant la touche : le poisson se méfie, on attend un peu plus.
			_wait += p("early_penalty")
			AudioBus.play("sticky", 1.0, -10.0)
		"bite":
			var rt: float = _bite_t
			_part["bite"] = clampf(1.0 - rt / (p("react_window") * widen()), 0.0, 1.0)
			pop(_scr(_spot_pos(_lure)) + Vector2(0, -60), float(_part["bite"]), "TRIAL_FISHING_HOOKED")
			AudioBus.play("decor_pluck", 1.2, -4.0)
			_phase = "reel"


func tick(dt: float) -> void:
	_sync_3d(dt)
	for c: Dictionary in _carps:
		c["a"] = float(c["a"]) + rng.randf_range(-1.0, 1.0) * dt
		var pos: Vector2 = (c["p"] as Vector2) + Vector2.from_angle(float(c["a"])) * float(c["s"]) * dt
		if not POND.grow(-50.0).has_point(pos):
			c["a"] = float(c["a"]) + PI
		else:
			c["p"] = pos
	if _pause > 0.0:
		_pause -= dt
		if _pause <= 0.0:
			_fish += 1
			if _fish >= pi("fish"):
				finish(ThrowTrial.mean(_scores))
			else:
				_new_fish()
		return
	match _phase:
		"cast":
			_wait += dt
			if _wait >= p("cast_timeout") * slow:
				_press()  # la ligne part toute seule
				return
			_gauge += _gauge_dir * dt / (p("cast_seconds") * slow)
			if _gauge >= 1.0 or _gauge <= 0.0:
				_gauge = clampf(_gauge, 0.0, 1.0)
				_gauge_dir = -_gauge_dir
		"wait":
			_wait -= dt
			if _wait <= 0.0:
				_phase = "bite"
				_bite_t = 0.0
				AudioBus.play("decor_puff", 1.3, -4.0)
		"bite":
			_bite_t += dt
			if _bite_t >= p("react_window") * widen():
				_part["bite"] = 0.0
				pop(_scr(_spot_pos(_lure)) + Vector2(0, -60), 0.0, "TRIAL_FISHING_MISSED")
				_land(false)
		"reel":
			_reel(dt)


## Remontée : maintenir tend le fil et rapproche la carpe ; elle tire par à-coups.
func _reel(dt: float) -> void:
	_reel_t += dt
	_pull_t -= dt
	if _pull_t <= 0.0:
		_pull_t = rng.randf_range(p("pull_every_min"), p("pull_every_max")) * slow
		_pull = p("pull_strength") * rng.randf_range(0.6, 1.0)
		AudioBus.play("decor_creak", 1.4, -8.0)
	_pull = maxf(0.0, _pull - p("pull_decay") * dt)
	var rate: float = p("reel_tension") if _hold else -p("slack_rate")
	_tension = clampf(_tension + (rate + _pull) * dt / slow, 0.0, 1.0)
	if _hold:
		_dist -= p("reel_speed") * dt * (1.0 - _pull / maxf(p("pull_strength"), 0.01)) / slow
	else:
		_dist = minf(1.0, _dist + p("run_speed") * _pull * dt)
	var lo: float = p("zone_low")
	var hi: float = p("zone_high")
	if _tension >= lo and _tension <= hi:
		_in_zone += dt
	if _tension >= 1.0:
		pop(_scr(_spot_pos(_lure * _dist)) + Vector2(0, -60), 0.0, "TRIAL_FISHING_SNAP")
		AudioBus.play("crack", 1.2, -4.0)
		_land(false)
	elif _tension <= 0.0:
		_slack_t += dt
		if _slack_t >= p("slack_escape") * slow:
			pop(_scr(_spot_pos(_lure * _dist)) + Vector2(0, -60), 0.0, "TRIAL_FISHING_ESCAPED")
			_land(false)
	else:
		_slack_t = 0.0
	if _dist <= 0.0:
		pop(_scr(ROD) + Vector2(200, -200), 1.0, "TRIAL_FISHING_LANDED")
		AudioBus.play("coins", 1.1, -4.0)
		_land(true)


func _land(caught: bool) -> void:
	var zone: float = _in_zone / maxf(_reel_t, 0.01) if caught else 0.0
	var sc: float = float(_part.get("cast", 0.0)) * p("w_cast") + float(_part.get("bite", 0.0)) * p("w_bite")
	sc += zone * (1.0 - p("w_cast") - p("w_bite"))
	_scores.append(clampf(sc, 0.0, 1.0))
	_phase = "done"
	_hold = false
	_pause = p("pause_seconds")


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	match _phase:
		"cast":
			var nxt: float = _gauge + _gauge_dir / 60.0 / (p("cast_seconds") * slow)
			if (_gauge - _spot) * (nxt - _spot) <= 0.0:
				return {"do": "confirm"}
		"bite":
			if _bite_t > p("bot_react"):
				return {"do": "confirm"}
		"reel":
			var mid: float = (p("zone_low") + p("zone_high")) * 0.5
			return {"do": "hold"} if _tension < mid else {"do": "release"}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			_press()
		"hold":
			_hold = true
		"release":
			_hold = false


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	if _phase == "bite":
		text(stage.project(_bob3.position) + Vector2(0, -60), "!", UiKit.SIZE_H1, Palette.GOLD_LIGHT)
	# Jauges : lancer, puis tension.
	draw_rect(GAUGE, Color(Palette.INK, 0.9))
	if _phase == "cast":
		var sy: float = GAUGE.end.y - GAUGE.size.y * _spot
		draw_rect(Rect2(GAUGE.position.x - 6, sy - p("cast_tolerance") * GAUGE.size.y * widen() * 0.5, GAUGE.size.x + 12,
			p("cast_tolerance") * GAUGE.size.y * widen()), Color(Palette.GOLD, 0.4))
		draw_rect(Rect2(GAUGE.position.x, GAUGE.end.y - GAUGE.size.y * _gauge - 4, GAUGE.size.x, 8), Palette.IVORY)
	elif _phase == "reel":
		var lo_y: float = GAUGE.end.y - GAUGE.size.y * p("zone_high")
		var zone_h: float = GAUGE.size.y * (p("zone_high") - p("zone_low"))
		draw_rect(Rect2(GAUGE.position.x, lo_y, GAUGE.size.x, zone_h), Color(Palette.EMERALD, 0.35))
		var col: Color = Palette.EMERALD if _tension >= p("zone_low") and _tension <= p("zone_high") else Palette.MULT_RED
		draw_rect(Rect2(GAUGE.position.x, GAUGE.end.y - GAUGE.size.y * _tension, GAUGE.size.x, GAUGE.size.y * _tension), Color(col, 0.8))
		text(Vector2(GAUGE.get_center().x, GAUGE.position.y - 30), tr("TRIAL_FISHING_TENSION"), UiKit.SIZE_SMALL, Palette.IVORY)
	draw_rect(GAUGE, Palette.GOLD, false, 2.0)
	var key: String = {"cast": "TRIAL_FISHING_CAST", "wait": "TRIAL_FISHING_WAIT", "bite": "TRIAL_FISHING_BITE",
		"reel": "TRIAL_FISHING_REEL"}.get(_phase, "")
	if key != "":
		text(Vector2(size.x * 0.5, 160.0), tr(key), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	pips(Vector2(size.x * 0.5, 100.0), _scores, pi("fish"))
