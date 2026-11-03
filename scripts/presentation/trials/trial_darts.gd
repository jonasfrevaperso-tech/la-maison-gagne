class_name TrialDarts
extends ThrowTrial
## FLÉCHETTES (écran dédié) : une vieille cible de pub, trois fléchettes. Le viseur tangue tout
## seul (la main a bu un peu trop de « courage ») ; on le ramène au centre au stick, aux flèches
## ou à la souris, et on lance au bon moment. Note = proximité du centre, fléchette par fléchette.

const BOARD_C: Vector2 = Vector2(960.0, 520.0)
const RINGS: Array[float] = [1.0, 0.82, 0.62, 0.44, 0.26, 0.11]
const SECTORS: int = 20

var _dart: int = 0
var _aim: Vector2 = BOARD_C
var _steer: Vector2 = Vector2.ZERO
var _phase_t: float = 0.0
var _seed: Vector2 = Vector2.ZERO
var _stuck: Array[Vector2] = []
var _scores: Array[float] = []
var _flying: float = -1.0
var _mouse_pt: Vector2 = Vector2(-1, -1)
var _bot_axis: Vector2 = Vector2.ZERO
## Dérive de la main (px/s) : sans correction, le viseur s'en va.
var _drift: Vector2 = Vector2.ZERO
## Scène 3D : cible de pub dans son armoire, mur lambrissé, ardoise ; 1 m = BOARD_R3 / rayon px.
var _gold: MeshInstance3D = null
var _darts3: Array[Node3D] = []
var _px3: float = 0.001


func begin() -> void:
	_build_3d()
	_new_dart()


## Pixel d'écran (repère de l'épreuve) → point du plan de la cible (z = 0). La caméra est
## frontale et calée pour que la cible 3D tombe exactement sur BOARD_C / _radius().
func _to3(p2: Vector2) -> Vector3:
	var d: Vector2 = (p2 - BOARD_C) * _px3
	return Vector3(d.x, -d.y, 0.0)


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.08, 0.05, 0.03)
	st.key.light_energy = 0.3
	var r3: float = 1.0
	_px3 = r3 / _radius()
	var fov: float = 40.0
	var dist: float = 540.0 * _px3 / tan(deg_to_rad(fov) * 0.5)
	st.cam.fov = fov
	st.cam.position = Vector3(0, (BOARD_C.y - 540.0) * _px3, dist)
	var r: Node3D = st.root
	# Mur lambrissé (lattes alternées) et plinthe.
	for k: int in 30:
		var shade: float = 0.11 + 0.025 * float(k % 3)
		var lath: StandardMaterial3D = Stage3D.mat(Color(shade * 1.3, shade * 0.8, shade * 0.5), 0.0, 0.8)
		Stage3D.box(r, Vector3(0.3, 8.0, 0.1), Vector3(-4.5 + 0.31 * float(k), 0, -0.3), lath)
	# Armoire de la cible, portes ouvertes.
	var wood: StandardMaterial3D = Stage3D.mat(Color(0.25, 0.13, 0.06), 0.0, 0.5)
	Stage3D.box(r, Vector3(2.7, 2.7, 0.12), Vector3(0, 0, -0.16), wood)
	for side: float in [-1.0, 1.0]:
		var door: MeshInstance3D = Stage3D.box(r, Vector3(1.3, 2.7, 0.06), Vector3(side * 1.95, 0, 0.2), wood)
		door.rotation.y = side * 0.5
		Stage3D.box(door, Vector3(1.1, 2.4, 0.02), Vector3(0, 0, 0.04), Stage3D.mat(Color(0.1, 0.11, 0.1), 0.0, 0.95))
	# Cible : couronne noire, puis secteurs colorés (maillage à couleurs de sommet).
	Stage3D.cylinder(r, r3 * 1.12, 0.08, Vector3(0, 0, -0.06), Stage3D.mat(Color(0.08, 0.06, 0.05), 0.0, 0.9)).rotation.x = PI * 0.5
	var face: MeshInstance3D = MeshInstance3D.new()
	face.mesh = _board_mesh(r3)
	var fm: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.85)
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	face.material_override = fm
	r.add_child(face)
	# Fils métalliques des anneaux.
	for k: float in RINGS:
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = k * r3 - 0.006
		tor.outer_radius = k * r3 + 0.006
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.mesh = tor
		ring.material_override = Stage3D.mat(Color(0.75, 0.75, 0.8), 0.9, 0.25)
		ring.rotation.x = PI * 0.5
		ring.position.z = 0.012
		r.add_child(ring)
	_gold = Stage3D.cylinder(r, 1.0, 0.01, Vector3(0, 0, 0.016), Stage3D.glow(Palette.GOLD_LIGHT, 0.8))
	_gold.rotation.x = PI * 0.5
	# Ardoise des scores (les chiffres restent dessinés en 2D par-dessus).
	var slate: Rect2 = Rect2(1430, 300, 300, 360)
	var sc: Vector3 = _to3(slate.get_center())
	var ss: Vector2 = slate.size * _px3
	Stage3D.box(r, Vector3(ss.x + 0.12, ss.y + 0.12, 0.06), sc, Stage3D.mat(Color(0.4, 0.27, 0.13), 0.0, 0.6))
	Stage3D.box(r, Vector3(ss.x, ss.y, 0.02), sc + Vector3(0, 0, 0.035), Stage3D.mat(Color(0.12, 0.13, 0.13), 0.0, 0.95))
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_energy = 9.0
	spot.light_color = Color(1.0, 0.86, 0.6)
	spot.spot_range = 8.0
	spot.spot_angle = 32.0
	spot.position = Vector3(0, 2.6, 2.4)
	spot.shadow_enabled = RenderQuality.shadows()
	r.add_child(spot)
	spot.look_at(Vector3.ZERO, Vector3.UP)
	Stage3D.omni(r, Color(1.0, 0.9, 0.75), 2.2, Vector3(0, 0.2, 1.6), 3.5)
	for k: int in pi("darts"):
		var dart: Node3D = _dart_node()
		dart.visible = false
		r.add_child(dart)
		_darts3.append(dart)


## Secteurs et anneaux de la cible en un seul maillage (couleurs de sommet).
func _board_mesh(r3: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.BACK)
	for s: int in SECTORS:
		var a0: float = TAU * float(s) / SECTORS - PI / SECTORS
		var a1: float = a0 + TAU / SECTORS
		for ri: int in RINGS.size() - 2:
			var light: bool = (s + ri) % 2 == 0
			var col: Color = Color(0.85, 0.78, 0.6) if light else Color(0.12, 0.1, 0.09)
			if ri == 0 or ri == 2:
				col = Palette.ROULETTE_RED.darkened(0.15) if light else Color(0.1, 0.38, 0.2)
			_quad(st, a0, a1, RINGS[ri + 1] * r3, RINGS[ri] * r3, col)
	for s: int in SECTORS:
		var a0: float = TAU * float(s) / SECTORS
		var a1: float = a0 + TAU / SECTORS
		_quad(st, a0, a1, RINGS[5] * r3, RINGS[4] * r3, Color(0.1, 0.38, 0.2))
		_quad(st, a0, a1, 0.0, RINGS[5] * r3, Palette.ROULETTE_RED)
	return st.commit()


func _quad(st: SurfaceTool, a0: float, a1: float, r0: float, r1: float, col: Color) -> void:
	st.set_color(col)
	var p00: Vector3 = Vector3(cos(a0) * r0, -sin(a0) * r0, 0)
	var p01: Vector3 = Vector3(cos(a0) * r1, -sin(a0) * r1, 0)
	var p10: Vector3 = Vector3(cos(a1) * r0, -sin(a1) * r0, 0)
	var p11: Vector3 = Vector3(cos(a1) * r1, -sin(a1) * r1, 0)
	for v: Vector3 in [p00, p11, p01, p00, p10, p11]:
		st.add_vertex(v)


## Fléchette : pointe d'acier, fût laiton, empennage magenta. Pointe vers -z.
func _dart_node() -> Node3D:
	var n: Node3D = Node3D.new()
	var tip: MeshInstance3D = Stage3D.cylinder(n, 0.008, 0.12, Vector3(0, 0, 0.06), Stage3D.mat(Color(0.8, 0.8, 0.85), 0.9, 0.2), 0.001)
	tip.rotation.x = -PI * 0.5
	var barrel: MeshInstance3D = Stage3D.cylinder(n, 0.022, 0.16, Vector3(0, 0, 0.2), Stage3D.mat(Palette.GOLD, 0.9, 0.3))
	barrel.rotation.x = PI * 0.5
	var shaft: MeshInstance3D = Stage3D.cylinder(n, 0.01, 0.14, Vector3(0, 0, 0.34), Stage3D.mat(Palette.INK))
	shaft.rotation.x = PI * 0.5
	for k: int in 2:
		var fl: MeshInstance3D = Stage3D.box(n, Vector3(0.1, 0.004, 0.1), Vector3(0, 0, 0.4), Stage3D.glow(Palette.MAGENTA, 0.6))
		fl.rotation.z = float(k) * PI * 0.5
	return n


func _new_dart() -> void:
	_steer = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(80.0, 140.0)
	_drift = Vector2.from_angle(rng.randf() * TAU) * p("drift")
	_seed = Vector2(rng.randf_range(0, 100), rng.randf_range(0, 100))
	_phase_t = 0.0
	_flying = -1.0
	# Le viseur part déjà décalé : sinon un appui immédiat tombait pile au centre.
	_aim = BOARD_C + _steer + _wobble()


func _radius() -> float:
	return p("board_radius")


## Tangage : somme de sinus (lent et ample + rapide et court), plus fort à chaque fléchette.
func _wobble() -> Vector2:
	var a: float = pk("wobble", _dart) / widen()
	var s: float = p("wobble_speed") / slow
	var tt: float = _phase_t * s
	return Vector2(sin(tt * 1.3 + _seed.x) * 0.7 + sin(tt * 3.1 + _seed.y) * 0.3,
		sin(tt * 1.7 + _seed.y) * 0.7 + cos(tt * 2.6 + _seed.x) * 0.3) * a


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_pt = mm.position
		return true
	if confirm_pressed(event):
		throw_dart()
		return true
	return false


func throw_dart() -> void:
	if _flying >= 0.0:
		return
	_flying = 0.0
	AudioBus.play("whoosh", 1.6, -6.0)


func _land() -> void:
	var d: float = _aim.distance_to(BOARD_C)
	var perfect: float = p("perfect_radius") * widen()
	var sc: float = 1.0 if d <= perfect else clampf(1.0 - (d - perfect) / (_radius() * p("falloff")), 0.0, 1.0)
	_scores.append(sc)
	_stuck.append(_aim)
	AudioBus.play("stamp", 1.4, -2.0)
	if sc >= 0.9:
		AudioBus.play("chime", 1.2, -4.0)
	pop(_aim + Vector2(0, -50), sc, "TRIAL_DARTS_BULL" if d <= perfect else "")
	_dart += 1
	if _dart >= pi("darts"):
		finish(mean(_scores))
	else:
		_new_dart()


func tick(dt: float) -> void:
	_phase_t += dt
	if _flying >= 0.0:
		_flying += dt
		if _flying >= 0.25:
			_land()
		return
	var v: Vector2 = held_vector() + _bot_axis
	_steer += v.limit_length(1.0) * p("steer_speed") * dt + _drift * dt
	if _mouse_pt.x >= 0.0 and mouse:
		_steer = _mouse_pt - BOARD_C
	_steer = _steer.limit_length(_radius() * 1.4)
	# La main dérive aussi d'elle-même : on doit corriger en permanence.
	_aim = BOARD_C + _steer + _wobble()
	if _phase_t > p("dart_seconds") * slow:
		throw_dart()  # bras fatigué : la fléchette part toute seule


func bot_wants() -> Dictionary:
	if _flying >= 0.0:
		return {"do": ""}
	var off: Vector2 = _aim - BOARD_C
	if off.length() < 4.0:
		return {"do": "confirm"}
	return {"do": "axis", "v": (-off / 40.0).limit_length(1.0)}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			_bot_axis = Vector2.ZERO
			throw_dart()
		"axis":
			_bot_axis = w["v"] as Vector2
		_:
			_bot_axis = Vector2.ZERO


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if _gold != null:
		var gr: float = p("perfect_radius") * widen() * _px3
		_gold.scale = Vector3(gr, 1.0, gr)
		for k: int in _darts3.size():
			var dart: Node3D = _darts3[k]
			dart.visible = k < _stuck.size() or (k == _stuck.size() and _flying >= 0.0)
			if k < _stuck.size():
				dart.position = _to3(_stuck[k])
				dart.rotation = Vector3(0.12, 0.18 * float(k % 2 * 2 - 1), 0)
			elif dart.visible:
				# En vol : part d'en bas, devant la caméra, et file vers le point visé.
				var u: float = clampf(_flying / 0.25, 0.0, 1.0)
				var to: Vector3 = _to3(_aim)
				dart.position = Vector3(0.6, -2.0, 4.0).lerp(to, u) + Vector3(0, sin(u * PI) * 0.4, 0)
				dart.rotation = Vector3(0.3 * (1.0 - u), 0, 0)
	var slate: Rect2 = Rect2(1430, 300, 300, 360)
	text(slate.position + Vector2(150, 40), tr("TRIAL_DARTS_SLATE"), UiKit.SIZE_BODY, Palette.IVORY, "display", 0)
	for k: int in _scores.size():
		text(slate.position + Vector2(150, 100 + k * 60), "%d" % roundi(_scores[k] * 100.0), UiKit.SIZE_H2, Palette.IVORY, "mono", 0)
	pips(Vector2(size.x * 0.5, 110), _scores, pi("darts"))
	if _flying < 0.0:
		var pulse: float = 0.7 + 0.3 * sin(t * 9.0)
		draw_arc(_aim, 22.0, 0, TAU, 32, Color(Palette.CYAN, pulse), 3.0, true)
		draw_line(_aim - Vector2(34, 0), _aim + Vector2(34, 0), Palette.CYAN, 2.0)
		draw_line(_aim - Vector2(0, 34), _aim + Vector2(0, 34), Palette.CYAN, 2.0)
		var left: float = clampf(1.0 - _phase_t / (p("dart_seconds") * slow), 0.0, 1.0)
		draw_arc(_aim, 30.0, -PI * 0.5, -PI * 0.5 + TAU * left, 32, Color(Palette.GOLD, 0.8), 3.0, true)
