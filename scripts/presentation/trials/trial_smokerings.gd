class_name TrialSmokerings
extends ThrowTrial
## LES RONDS DE FUMÉE (Fumoir, 2.0) : calé dans son fauteuil club, le fumeur souffle des ronds
## à travers des cerceaux de laiton suspendus qui montent et descendent au bout de leur cordon.
## Stick : incliner le souffle ; maintenir : inspirer (plus on inspire, plus le rond file vite) ;
## relâcher : souffler. Un rond ralentit, s'élargit et monte (la fumée est chaude) : soufflé
## doucement, il arrive tard, gros et haut ; trop inspirer fait tousser.
## Le passage est calculé au souffle (règle 4) : le vol ne fait que le raconter.
## Note = moyenne des cerceaux (plein au centre, moins vers le bord, rien si le rond s'y brise).

const PX3: float = 0.005
const FLOOR_Y: float = 960.0
const MOUTH: Vector2 = Vector2(395.0, 700.0)
const CEIL_Y: float = 40.0
const RING_ASPECT: float = 0.35
const PLAN_STEP_A: float = 0.01
const PLAN_STEPS_C: int = 100

var _hoop: int = 0
var _aim: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_aim: float = INF
var _charging: bool = false
var _charge: float = 0.0
var _over: float = 0.0
var _hoop_t0: float = 0.0
var _ring: Dictionary = {}  # vol en cours : t0, v0, q, cross (s), dy
var _rest: float = 0.0
var _marks: Array[float] = []
var _coughs: int = 0
var _ended: bool = false
var _blow_t: float = -10.0
var _plan: Vector3 = Vector3(INF, INF, 0.0)  # bot : (angle, charge, note prévue)
var _phase: Array[float] = []
var _lift_y: Array[float] = []
var _deco: Dictionary = {}
var _smoker: Figure3D = null
var _hoop_n: Node3D = null
var _cord: MeshInstance3D = null
var _hoop_mat: StandardMaterial3D = null


func begin() -> void:
	for k: int in _hoops():
		_phase.append(rng.randf_range(0.0, TAU))
		_lift_y.append(rng.randf_range(-p("y_jitter"), p("y_jitter")))
	_build_3d()
	_hoop_t0 = t


func _hoops() -> int:
	return pi("hoops")


## Centre du cerceau `k` à l'instant `when` (temps de l'épreuve).
func hoop_at(k: int, when: float) -> Vector2:
	var w: float = TAU / maxf(pk("period", k), 0.1)
	var y: float = pk("hoop_y", k) + _lift_y[k] + pk("amp", k) * sin(w * (when - _hoop_t0) + _phase[k])
	return Vector2(MOUTH.x + pk("dist", k), y)


func _speed(c: float) -> float:
	return lerpf(p("v_min"), p("v_max"), clampf(c, 0.0, 1.0))


## Trajectoire analytique d'un rond (traînée `d`, poussée vers le haut constante) :
## position relative à la bouche après `s` secondes.
func ring_pos(v0: Vector2, s: float) -> Vector2:
	var d: float = p("drag")
	var a: float = -p("lift")
	var e: float = 1.0 - exp(-d * s)
	return Vector2(v0.x * e / d, (v0.y - a / d) * e / d + a * s / d)


func ring_radius(s: float) -> float:
	return p("r0") + p("grow") * s


## Résultat d'un souffle lâché à `when` avec l'angle `a` et la charge `c` sur le cerceau `k` :
## Vector3(note, durée de vol jusqu'au cerceau, écart vertical) ; durée négative = n'arrive pas.
func outcome(k: int, a: float, c: float, when: float) -> Vector3:
	var v: float = _speed(c)
	var v0: Vector2 = Vector2.from_angle(a) * v
	var d: float = p("drag")
	var dist: float = pk("dist", k)
	if v0.x - dist * d < p("die_vx"):
		return Vector3(0.0, -1.0, 0.0)
	var s: float = -log(1.0 - dist * d / v0.x) / d
	var ry: float = MOUTH.y + ring_pos(v0, s).y
	var dy: float = ry - hoop_at(k, when + s).y
	var fit: float = pk("hoop_r", k) - ring_radius(s) * p("fit_share")
	if fit <= 0.0 or absf(dy) > fit:
		return Vector3(0.0, s, dy)
	var u: float = absf(dy) / fit
	if u <= p("perfect_ratio"):
		return Vector3(1.0, s, dy)
	return Vector3(lerpf(1.0, p("edge_q"), (u - p("perfect_ratio")) / (1.0 - p("perfect_ratio"))), s, dy)


# --------------------------------------------------------------------------- jeu


func _blow() -> void:
	if not _charging:
		return
	_charging = false
	var c: float = _charge
	_charge = 0.0
	_over = 0.0
	if not _ring.is_empty() or _rest > 0.0 or _ended:
		return
	var res: Vector3 = outcome(_hoop, _aim, c, t)
	var v0: Vector2 = Vector2.from_angle(_aim) * _speed(c)
	_ring = {"t0": t, "v0": v0, "q": res.x, "cross": res.y, "dy": res.z, "k": _hoop}
	_blow_t = t
	AudioBus.play("decor_puff", 0.8 + 0.4 * c, -6.0)


func _cough() -> void:
	_charging = false
	_charge = 0.0
	_over = 0.0
	_coughs += 1
	_blow_t = t
	pop(MOUTH + Vector2(60, -80), 0.0, "TRIAL_SMOKERINGS_COUGH")
	AudioBus.play("lose_soft", 1.4, -8.0)


func _resolve(q: float, key: String) -> void:
	_marks.append(q)
	pop(hoop_at(_hoop, t), q, key)
	AudioBus.play("chime" if q > 0.0 else "decor_puff", 1.0 + 0.3 * q, -5.0 if q > 0.0 else -12.0)
	if _hoop_mat != null and q > 0.0:
		_hoop_mat.emission_energy_multiplier = 2.5
	_rest = p("rest_seconds") * slow


func tick(dt: float) -> void:
	_steer(dt)
	_sync_3d(dt)
	if _ended:
		return
	if _charging:
		_charge = minf(1.0, _charge + dt / (p("charge_seconds") * slow))
		if _charge >= 1.0:
			_over += dt
			if _over >= p("cough_seconds") * slow:
				_cough()
	if not _ring.is_empty():
		var age: float = t - float(_ring["t0"])
		var cross: float = float(_ring["cross"])
		if cross >= 0.0 and age >= cross:
			var q: float = float(_ring["q"])
			_resolve(q, "TRIAL_SMOKERINGS_CLEAN" if q >= 1.0 else ("TRIAL_SMOKERINGS_THROUGH" if q > 0.0 else "TRIAL_SMOKERINGS_BROKE"))
			_ring["done"] = true
		elif cross < 0.0 and age >= p("fade_seconds"):
			_resolve(0.0, "TRIAL_SMOKERINGS_SHORT")
			_ring["done"] = true
		if bool(_ring.get("done", false)):
			_ring = {}
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_next_hoop()
		return
	if _ring.is_empty() and t - _hoop_t0 >= p("hoop_seconds") * slow:
		_resolve(0.0, "TRIAL_SMOKERINGS_SHORT")


func _next_hoop() -> void:
	_hoop += 1
	_plan = Vector3(INF, INF, 0.0)
	if _hoop >= _hoops():
		_ended = true
		finish(ThrowTrial.mean(_marks))
		return
	_hoop_t0 = t
	if _hoop_mat != null:
		_hoop_mat.emission_energy_multiplier = 0.0


func _steer(dt: float) -> void:
	var lim: float = p("aim_max")
	if mouse and _mouse_aim != INF:
		_aim = move_toward(_aim, clampf(_mouse_aim, -lim, lim), p("aim_speed") * 2.0 * dt)
		return
	var v: float = clampf(held_vector().y + _axis.y, -1.0, 1.0)
	_aim = clampf(_aim + v * p("aim_speed") * dt, -lim, lim)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_aim = (mm.position - MOUTH).angle()
		return true
	if confirm_pressed(event):
		if _ring.is_empty() and _rest <= 0.0:
			_charging = true
		return true
	if confirm_released(event):
		_blow()
		return true
	return false


func journal() -> Dictionary:
	return {"hoops": _marks.size(), "coughs": _coughs}


# --------------------------------------------------------------------------- bot


## Cherche (angle, charge) qui passe au centre en tenant compte du temps de visée et
## d'inspiration ; vise, inspire, puis souffle quand la charge atteint la valeur choisie.
func _plan_shot(from_aim: float, fixed_aim: bool) -> Vector3:
	var best: Vector3 = Vector3(from_aim, 0.6, 0.0)
	var best_q: float = -1.0
	var lim: float = p("aim_max")
	var a: float = -lim
	while a <= lim + 0.0001:
		var aa: float = from_aim if fixed_aim else a
		var aim_time: float = absf(aa - _aim) / p("aim_speed") + p("bot_settle")
		for i: int in range(20, PLAN_STEPS_C):
			var c: float = float(i) / float(PLAN_STEPS_C)
			var when: float = t + aim_time + c * p("charge_seconds") * slow
			# Plan robuste : la note doit tenir si le souffle part un peu plus tôt ou plus tard.
			var q: float = minf(outcome(_hoop, aa, c, when).x,
				minf(outcome(_hoop, aa, c, when - p("bot_margin")).x, outcome(_hoop, aa, c, when + p("bot_margin")).x))
			# Préférer le centre, puis un souffle franc (moins long à attendre).
			var score_v: float = q + 0.001 * c
			if score_v > best_q:
				best_q = score_v
				best = Vector3(aa, c, q)
		if fixed_aim:
			break
		a += PLAN_STEP_A
	return best


func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0 or not _ring.is_empty():
		return {"do": "axis", "v": Vector2.ZERO}
	if not _charging:
		if _plan.x == INF:
			_plan = _plan_shot(_aim, false)
		var miss: float = _plan.x - _aim
		if absf(miss) > p("bot_aim_tol"):
			return {"do": "axis", "v": Vector2(0.0, clampf(miss * 6.0, -1.0, 1.0))}
		# Inspirer seulement si un souffle de cette fenêtre-ci passe au centre ; sinon laisser
		# le cerceau revenir (son mouvement est périodique).
		var now: Vector3 = _plan_shot(_aim, true)
		if now.z < _plan.z - p("bot_wait_slack") and t - _hoop_t0 < p("hoop_seconds") * slow - p("bot_deadline"):
			return {"do": "axis", "v": Vector2.ZERO}
		_plan = now
		return {"do": "hold"}
	# Souffler dès que souffler maintenant passe au centre (ou au plus tard à la charge prévue).
	if outcome(_hoop, _aim, _charge, t).x >= minf(_plan.z, 1.0) - p("bot_wait_slack") or _charge >= _plan.y:
		return {"do": "release"}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	var mode: String = String(w.get("do", ""))
	_axis = w.get("v", Vector2.ZERO) as Vector2 if mode == "axis" else Vector2.ZERO
	if mode == "hold" and not _charging and _ring.is_empty() and _rest <= 0.0:
		_charging = true
	elif mode == "release" and _charging:
		_blow()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = SmokingSet.build(st, FLOOR_Y, 1560.0)
	var r: Node3D = st.root
	SmokingSet.club_chair(r, st.to3(Vector2(385.0, FLOOR_Y), 0.0), PI * 0.5)
	_smoker = SmokingSet.gentleman(1.7, Color("3a1a2a"))
	_smoker.position = st.to3(Vector2(385.0, FLOOR_Y), 0.05)
	_smoker.rotation.y = PI * 0.5
	r.add_child(_smoker)
	# Guéridon, cendrier et carafe à côté du fauteuil.
	var table_at: Vector3 = st.to3(Vector2(170.0, FLOOR_Y), 0.3)
	var wood: StandardMaterial3D = Stage3D.textured("wood", SmokingSet.WALNUT, 0.6, 0.0, 0.4)
	Stage3D.cylinder(r, 0.05, 0.6, table_at + Vector3(0, 0.3, 0), wood)
	Stage3D.cylinder(r, 0.32, 0.04, table_at + Vector3(0, 0.62, 0), wood)
	Stage3D.cylinder(r, 0.09, 0.03, table_at + Vector3(0.1, 0.655, 0), Stage3D.mat(Color("8a8a90"), 0.8, 0.3), 0.07)
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.8, 0.6, 0.3, 0.55), 0.0, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Stage3D.cylinder(r, 0.07, 0.2, table_at + Vector3(-0.12, 0.74, 0), glass, 0.05)
	SmokingSet.banker_lamp(r, table_at + Vector3(0.05, 0.64, -0.15), true)
	# Cerceau de laiton suspendu (vu de biais) et son cordon.
	_hoop_mat = Stage3D.glow(SmokingSet.BRASS, 0.0)
	_hoop_mat.metallic = 0.85
	_hoop_mat.roughness = 0.25
	_hoop_n = Node3D.new()
	r.add_child(_hoop_n)
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = torus
	mi.material_override = _hoop_mat
	mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
	var tilt: Node3D = Node3D.new()
	tilt.rotation.y = asin(RING_ASPECT)
	tilt.add_child(mi)
	_hoop_n.add_child(tilt)
	_cord = Stage3D.cylinder(r, 0.006, 1.0, Vector3.ZERO, Stage3D.mat(Color("8a6a3a"), 0.0, 0.8))


func _sync_3d(dt: float) -> void:
	if _smoker == null:
		return
	var pose: float = _charge if _charging else (-clampf(1.0 - (t - _blow_t) * 2.0, 0.0, 1.0))
	_smoker.animate(&"smoke", t * 1.5, dt, pose)
	SmokingSet.animate(_deco, stage, FLOOR_Y, t)
	var k: int = mini(_hoop, _hoops() - 1)
	var c: Vector2 = hoop_at(k, t)
	var rr: float = pk("hoop_r", k)
	_hoop_n.position = stage.to3(c, 0.0)
	_hoop_n.scale = Vector3.ONE * rr * PX3
	_hoop_n.visible = not _ended
	var top: Vector3 = stage.to3(Vector2(c.x, CEIL_Y), 0.0)
	var bottom: Vector3 = stage.to3(c - Vector2(0, rr), 0.0)
	_cord.position = (top + bottom) * 0.5
	_cord.scale = Vector3(1.0, maxf(0.01, top.y - bottom.y), 1.0)
	if _hoop_mat != null:
		_hoop_mat.emission_energy_multiplier = maxf(0.0, _hoop_mat.emission_energy_multiplier - dt * 2.0)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Rond en vol : ellipse de fumée qui s'élargit et s'estompe.
	if not _ring.is_empty():
		var age: float = t - float(_ring["t0"])
		var pos: Vector2 = MOUTH + ring_pos(_ring["v0"] as Vector2, age)
		var rr: float = ring_radius(age)
		var a: float = clampf(1.0 - age / p("fade_seconds"), 0.15, 0.9)
		_smoke_ring(pos, rr, a)
	# Direction du souffle et jauge d'inspiration.
	if not _ended and _ring.is_empty() and _rest <= 0.0:
		var dir: Vector2 = Vector2.from_angle(_aim)
		for k2: int in 5:
			draw_circle(MOUTH + dir * (40.0 + 26.0 * float(k2)), 4.0 - 0.5 * float(k2), Color(Palette.IVORY, 0.55 - 0.08 * float(k2)))
	var g: Rect2 = Rect2(MOUTH.x - 60.0, MOUTH.y - 330.0, 22.0, 160.0)
	draw_rect(g, Color(Palette.INK, 0.85))
	var col: Color = Palette.GOLD if _over <= 0.0 else Palette.ROULETTE_RED.lerp(Palette.IVORY, 0.5 + 0.5 * sin(t * 30.0))
	draw_rect(Rect2(g.position.x, g.end.y - g.size.y * _charge, g.size.x, g.size.y * _charge), col)
	draw_rect(g, Palette.GOLD_DARK, false, 2.0)
	text(Vector2(g.get_center().x, g.end.y + 26.0), tr("TRIAL_SMOKERINGS_BREATH"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	text(Vector2(960.0, 105.0), tr("TRIAL_SMOKERINGS_STATUS") % [mini(_hoop + 1, _hoops()), _hoops()], UiKit.SIZE_BODY, Palette.IVORY)
	var left: float = clampf(1.0 - (t - _hoop_t0) / (p("hoop_seconds") * slow), 0.0, 1.0)
	if not _ended and _rest <= 0.0:
		draw_rect(Rect2(860.0, 130.0, 200.0 * left, 6.0), Color(Palette.GOLD, 0.7))


## Rond de fumée vu de biais : tore épais (halo, cœur, reflet), largeur de trait constante.
func _smoke_ring(at: Vector2, rr: float, alpha: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k: int in 41:
		var a: float = TAU * float(k) / 40.0
		pts.append(at + Vector2(cos(a) * rr * RING_ASPECT, sin(a) * rr))
	var thick: float = maxf(8.0, rr * 0.34)
	draw_polyline(pts, Color(0.85, 0.83, 0.78, alpha * 0.22), thick * 1.6, true)
	draw_polyline(pts, Color(0.92, 0.9, 0.86, alpha * 0.55), thick, true)
	draw_polyline(pts, Color(1.0, 1.0, 0.97, alpha * 0.6), thick * 0.3, true)
