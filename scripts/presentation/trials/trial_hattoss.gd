class_name TrialHattoss
extends ThrowTrial
## LE LANCER DE CHAPEAU (Cabaret, 2.0) : le groom lance son haut-de-forme vers la patère du
## portemanteau, à l'autre bout de la scène. Son bras balance : lâcher au bon moment donne la force.
## Le stick, au lâcher, donne l'effet : vers le haut le chapeau plane (lifté), vers le bas il plonge
## (coupé). Le ventilateur souffle (les rubans montrent le sens), le portemanteau change de place et,
## dès le troisième lancer, un nuage de décor suspendu barre les trajectoires trop hautes.
## Note = moyenne des lancers (accroché : plein ; sinon selon l'écart à la patère).

const PX3: float = 0.005
const FLOOR_Y: float = 780.0
const HAND: Vector2 = Vector2(330.0, 590.0)
const LAUNCH_ANGLE: float = 0.75
const HOOK_DROP: float = 360.0
const CLOUD: Rect2 = Rect2(760.0, 150.0, 260.0, 150.0)
const THROWER_X: float = 280.0
const FAN_X: float = 1780.0
const FLIGHT_MAX: float = 3.0
const HAT_SPIN: float = 9.0
## Tirage équitable : essais et marge (part du rayon de la patère) du meilleur lancer possible.
const FAIR_TRIES: int = 12
const FAIR_MARGIN: float = 0.4

var _throw: int = 0
var _marks: Array[float] = []
var _hook: Vector2 = Vector2.ZERO
var _wind: float = 0.0
var _cloud: bool = false
var _swing_t: float = 0.0
var _flying: bool = false
var _hat: Vector2 = HAND
var _hat_v: Vector2 = Vector2.ZERO
var _spin: float = 0.0
var _best: float = INF
var _flight_t: float = 0.0
var _rest: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_y: float = -1.0
var _bot_fire: bool = false
var _plan: Vector2 = Vector2(-1.0, 0.0)  # (force visée, effet) du bot
var _release_pow: float = 0.0
var _hung: int = 0
var _ended: bool = false
var _thrower: Figure3D = null
var _hat3: Node3D = null
var _hung3: Array[Node3D] = []
var _stand3: Node3D = null
var _blades: Node3D = null
var _ribbons: Array[MeshInstance3D] = []
var _cloud3: Node3D = null
var _heads: Array[Node3D] = []


func begin() -> void:
	_build_3d()
	_setup_throw()


func _throws() -> int:
	return pi("throws")


## Nouveau lancer : place de la patère, vent du ventilateur, nuage de décor.
func _setup_throw() -> void:
	var span: Array = Balance.data()["throw_trials"]["hattoss"]["stand_x"] as Array
	_cloud = _throw >= pi("cloud_from")
	# Équité : on retire jusqu'à ce qu'un lancer accroche franchement (force et effet atteignables).
	for k: int in FAIR_TRIES:
		_hook = Vector2(rng.randf_range(float(span[0]), float(span[1])), FLOOR_Y - HOOK_DROP)
		_wind = rng.randf_range(-1.0, 1.0) * pk("wind", _throw)
		if _make_plan() <= p("hook_radius") * FAIR_MARGIN:
			break
	_swing_t = 0.0
	_flying = false
	_hat = HAND
	_best = INF
	_bot_fire = false
	if _stand3 != null:
		_stand3.position = stage.to3(Vector2(_hook.x, FLOOR_Y), -0.2)
		_cloud3.visible = _cloud


## Force du balancier (0..1), en dents de scie adoucies : monte puis redescend.
func _power() -> float:
	var period: float = p("swing_seconds") * slow
	var u: float = fmod(_swing_t, period) / period
	return 1.0 - absf(1.0 - 2.0 * u)


func _effect() -> float:
	var v: float = -(held_vector().y + _axis.y)
	if mouse and _mouse_y >= 0.0:
		v = clampf((HAND.y - _mouse_y) / p("mouse_span"), -1.0, 1.0)
	return clampf(v, -1.0, 1.0)


func release() -> void:
	if _flying or _rest > 0.0 or _ended:
		return
	_release_pow = _power()
	_spin = _effect()
	var speed: float = lerpf(p("speed_min"), p("speed_max"), _release_pow)
	_hat_v = Vector2(cos(LAUNCH_ANGLE), -sin(LAUNCH_ANGLE)) * speed
	_hat = HAND
	_flying = true
	_flight_t = 0.0
	AudioBus.play("whoosh", 1.1 + 0.2 * _spin, -4.0)


## Accélération du chapeau : pesanteur, portance de l'effet (plane ou plonge), vent.
func _accel(v: Vector2, spin: float) -> Vector2:
	return Vector2(_wind, p("gravity") - spin * p("lift") * v.length() / p("speed_max"))


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_throw += 1
			if _throw >= _throws():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_setup_throw()
		return
	if not _flying:
		_swing_t += dt
		if _bot_fire:
			_bot_fire = false
			release()
		elif _swing_t > p("idle_seconds") * slow:
			_score_throw(0.0, "TRIAL_HATTOSS_TOO_LATE")
		return
	_flight_t += dt
	_hat_v += _accel(_hat_v, _spin) * dt
	_hat += _hat_v * dt
	if _hat_v.y > 0.0:
		var d: float = _hat.distance_to(_hook)
		_best = minf(_best, d)
		if d <= p("hook_radius") * widen():
			_hung += 1
			_score_throw(1.0, "TRIAL_HATTOSS_HOOKED")
			AudioBus.play("chime", 1.2, -2.0)
			return
	if _cloud and CLOUD.has_point(_hat):
		_score_throw(0.0, "TRIAL_HATTOSS_CLOUD")
		AudioBus.play("cloth", 0.8, -2.0)
		return
	if _hat.y > FLOOR_Y or _hat.x > 1900.0 or _hat.x < 0.0 or _flight_t > FLIGHT_MAX:
		var miss: float = p("miss_px") * widen()
		var r: float = p("hook_radius") * widen()
		_score_throw(clampf(1.0 - (_best - r) / maxf(miss - r, 1.0), 0.0, 1.0) * p("near_value"), "")
		AudioBus.play("cloth", 1.2, -6.0)


func _score_throw(q: float, key: String) -> void:
	_marks.append(q)
	pop(_hook + Vector2(0, -90.0), q, key)
	_flying = false
	_rest = p("rest_seconds") * slow


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_y = mm.position.y
		return true
	if confirm_pressed(event):
		release()
		return true
	return false


func journal() -> Dictionary:
	return {"hooked": _hung, "throws": _throws()}


# --------------------------------------------------------------------------- bot


## Trajectoire simulée pour (force, effet) : écart minimal à la patère en descente (INF si le
## nuage l'arrête).
func _simulate(pw: float, spin: float) -> float:
	var v: Vector2 = Vector2(cos(LAUNCH_ANGLE), -sin(LAUNCH_ANGLE)) * lerpf(p("speed_min"), p("speed_max"), pw)
	var x: Vector2 = HAND
	var best: float = INF
	var h: float = 1.0 / 60.0
	for k: int in int(FLIGHT_MAX / h):
		v += _accel(v, spin) * h
		x += v * h
		if _cloud and CLOUD.has_point(x):
			return INF
		if v.y > 0.0:
			best = minf(best, x.distance_to(_hook))
		if x.y > FLOOR_Y:
			break
	return best


## Meilleur lancer (force, effet) pour la patère en place ; rend son écart.
func _make_plan() -> float:
	var best: float = INF
	for si: int in 9:
		var spin: float = -1.0 + 0.25 * float(si)
		for pk_i: int in 41:
			var pw: float = float(pk_i) / 40.0
			var d: float = _simulate(pw, spin) + absf(spin) * 2.0
			if d < best:
				best = d
				_plan = Vector2(pw, spin)
	return best


func bot_wants() -> Dictionary:
	if _flying or _rest > 0.0:
		return {"do": "axis", "v": Vector2.ZERO}
	var v: Vector2 = Vector2(0.0, -_plan.y)
	if absf(_effect() - _plan.y) > 0.05:
		return {"do": "axis", "v": v}
	# Lâche quand le balancier passe par la force visée (en montant, prévisible).
	var period: float = p("swing_seconds") * slow
	var u: float = fmod(_swing_t, period) / period
	if u < 0.5 and absf(_power() - _plan.x) <= 2.0 / 60.0 / period * 1.01 + 0.001:
		return {"do": "confirm", "v": v}
	return {"do": "axis", "v": v}


func bot_apply(w: Dictionary) -> void:
	if w.has("v"):
		_axis = w["v"] as Vector2
	_bot_fire = String(w.get("do", "")) == "confirm"


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	var deco: Dictionary = CabaretSet.build(st, FLOOR_Y, 780.0)
	_heads.assign(deco.get("audience", []))
	var r: Node3D = st.root
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.8, 0.28)
	var wood: StandardMaterial3D = Stage3D.mat(Color("3a2010"), 0.0, 0.45)
	_thrower = Figure3D.new().build(1.7)
	_thrower.position = st.to3(Vector2(THROWER_X, FLOOR_Y), -0.2)
	_thrower.rotation.y = PI * 0.4
	r.add_child(_thrower)
	# Portemanteau : pied tripode, fût de bois tourné, patères de laiton en couronne.
	_stand3 = Node3D.new()
	r.add_child(_stand3)
	Stage3D.cylinder(_stand3, 0.3, 0.05, Vector3(0, 0.025, 0), wood, 0.22)
	Stage3D.cylinder(_stand3, 0.035, HOOK_DROP * PX3, Vector3(0, HOOK_DROP * PX3 * 0.5, 0), wood)
	Stage3D.sphere(_stand3, 0.06, Vector3(0, HOOK_DROP * PX3 + 0.05, 0), brass)
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0 + PI * 0.25
		var hook: MeshInstance3D = Stage3D.cylinder(_stand3, 0.012, 0.2, Vector3(cos(a) * 0.07, HOOK_DROP * PX3 - 0.05, sin(a) * 0.07), brass)
		hook.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)
	# Ventilateur de théâtre : cage de laiton, pales, rubans qui flottent.
	var fan: Node3D = Node3D.new()
	fan.position = st.to3(Vector2(FAN_X, FLOOR_Y - 260.0), -0.3)
	fan.rotation.y = -PI * 0.3
	r.add_child(fan)
	Stage3D.cylinder(r, 0.04, 260.0 * PX3, st.to3(Vector2(FAN_X, FLOOR_Y - 130.0), -0.3), brass)
	Stage3D.cylinder(r, 0.25, 0.04, st.to3(Vector2(FAN_X, FLOOR_Y - 2.0), -0.3), Stage3D.mat(Color("15151a"), 0.4, 0.4))
	var ring: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.46
	ring.mesh = tm
	ring.material_override = brass
	ring.rotation.x = PI * 0.5
	fan.add_child(ring)
	_blades = Node3D.new()
	fan.add_child(_blades)
	for k2: int in 4:
		var b: MeshInstance3D = Stage3D.box(_blades, Vector3(0.12, 0.38, 0.02), Vector3(0, 0.2, 0), Stage3D.mat(Color("2a2a30"), 0.5, 0.4))
		var piv: Node3D = Node3D.new()
		piv.rotation.z = TAU * float(k2) / 4.0
		_blades.add_child(piv)
		b.reparent(piv, false)
	var rib_cols: Array[Color] = [Color("ff2e88"), Color("ffd23f"), Color("29e0ff")]
	for k3: int in 3:
		var rat: Vector3 = st.to3(Vector2(FAN_X - 110.0, FLOOR_Y - 330.0 + 70.0 * float(k3)), -0.1)
		var rb: MeshInstance3D = Stage3D.box(r, Vector3(0.5, 0.05, 0.005), rat,
			Stage3D.mat(rib_cols[k3], 0.0, 0.7))
		_ribbons.append(rb)
	# Nuage de décor suspendu (toile peinte, cordes).
	_cloud3 = Node3D.new()
	r.add_child(_cloud3)
	var paint: StandardMaterial3D = Stage3D.mat(Color("c8d4e8"), 0.0, 0.9)
	var c0: Vector2 = CLOUD.get_center()
	for k4: int in 5:
		var off: Vector2 = Vector2(-100.0 + 50.0 * float(k4), (20.0 if k4 % 2 == 0 else -20.0))
		var puff: MeshInstance3D = Stage3D.sphere(_cloud3, (70.0 - 10.0 * absf(float(k4) - 2.0)) * PX3, st.to3(c0 + off, -0.3), paint)
		puff.scale = Vector3(1.2, 0.85, 0.25)
	for sx: float in [-90.0, 90.0]:
		Stage3D.cylinder(_cloud3, 0.004, 1.5, st.to3(Vector2(c0.x + sx, CLOUD.position.y - 140.0), -0.3), Stage3D.mat(Palette.SMOKE))
	_hat3 = _top_hat(r)
	_stand3.position = st.to3(Vector2(_hook.x, FLOOR_Y), -0.2)


func _top_hat(parent: Node3D) -> Node3D:
	var h: Node3D = Node3D.new()
	parent.add_child(h)
	var felt: StandardMaterial3D = Stage3D.mat(Color("101014"), 0.1, 0.35)
	Stage3D.cylinder(h, 0.17, 0.015, Vector3.ZERO, felt)
	Stage3D.cylinder(h, 0.1, 0.2, Vector3(0, 0.1, 0), felt)
	Stage3D.cylinder(h, 0.102, 0.035, Vector3(0, 0.03, 0), Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.5))
	return h


func _sync_3d(dt: float) -> void:
	if _thrower == null:
		return
	var st: Stage3D = stage
	if _flying:
		_hat3.position = st.to3(_hat, -0.2)
		_hat3.rotation = Vector3(0.3, _flight_t * HAT_SPIN, _spin * 0.4 + sin(_flight_t * 5.0) * 0.15)
		_thrower.animate(&"throw", 1.0, dt)
	else:
		var hand: Vector3 = _thrower.joint_global(&"el_r")
		_hat3.position = hand + Vector3(0, -0.22, 0.08) if _rest <= 0.0 else st.to3(HAND, -0.2)
		_hat3.rotation = Vector3(0.0, 0.0, 0.0)
		_hat3.visible = _rest <= 0.0
		_thrower.animate(&"throw", 0.0 if _rest > 0.0 else 1.0 - _power(), dt)
	if _flying:
		_hat3.visible = true
	# Chapeaux déjà accrochés : empilés sur les patères.
	while _hung3.size() < _hung:
		_hung3.append(_top_hat(_stand3))
	for k: int in _hung3.size():
		_hung3[k].position = Vector3(cos(float(k) * 1.6) * 0.07, HOOK_DROP * PX3 - 0.05 + 0.03 * float(k), sin(float(k) * 1.6) * 0.07)
		_hung3[k].rotation.z = 0.25 * cos(float(k) * 1.6)
	_blades.rotation.z += dt * (4.0 + 30.0 * absf(_wind) / maxf(pk("wind", 3), 1.0))
	for k2: int in _ribbons.size():
		var push: float = clampf(_wind / maxf(pk("wind", 3), 1.0), -1.0, 1.0)
		_ribbons[k2].rotation.y = PI * (0.0 if push < 0.0 else 1.0) + sin(t * 14.0 + float(k2)) * 0.3 * absf(push)
		_ribbons[k2].scale.x = 0.2 + 0.8 * absf(push)
	CabaretSet.bob_audience(_heads, t * 0.4, 0.4)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	pips(Vector2(960.0, 120.0), _marks, _throws())
	# Balancier de force : arc gradué près du lanceur, aiguille et effet choisi.
	var c: Vector2 = Vector2(THROWER_X + 40.0, 330.0)
	draw_arc(c, 120.0, PI * 1.1, PI * 1.9, 32, Color(Palette.INK, 0.8), 16.0)
	var n: int = 10
	for k: int in n:
		var a0: float = PI * 1.1 + PI * 0.8 * float(k) / float(n)
		draw_arc(c, 120.0, a0, a0 + PI * 0.8 / float(n) - 0.01, 4, Palette.GOLD.lerp(Palette.ROULETTE_RED, float(k) / float(n)), 12.0)
	if not _flying and _rest <= 0.0:
		var a: float = PI * 1.1 + PI * 0.8 * _power()
		draw_line(c, c + Vector2(cos(a), sin(a)) * 136.0, Palette.IVORY, 5.0)
		var e: float = _effect()
		var ek: String = "TRIAL_HATTOSS_FLAT"
		if e > 0.25:
			ek = "TRIAL_HATTOSS_LIFT"
		elif e < -0.25:
			ek = "TRIAL_HATTOSS_DIVE"
		text(c + Vector2(0, 40.0), tr(ek), UiKit.SIZE_SMALL, Palette.CYAN)
	# Vent : flèche au-dessus du ventilateur.
	if absf(_wind) > 1.0:
		var dir: float = signf(_wind)
		var wc: Vector2 = Vector2(FAN_X - 200.0, FLOOR_Y - 420.0)
		var span: float = 40.0 + 80.0 * absf(_wind) / maxf(pk("wind", 3), 1.0)
		draw_line(wc - Vector2(dir * span * 0.5, 0), wc + Vector2(dir * span * 0.5, 0), Palette.CYAN, 6.0)
		var tip: Vector2 = wc + Vector2(dir * span * 0.5, 0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(dir * 18.0, 0), tip + Vector2(0, -12.0), tip + Vector2(0, 12.0)]), Palette.CYAN)
	draw_arc(_hook, p("hook_radius") * widen(), 0, TAU, 32, Color(Palette.GOLD_LIGHT, 0.5), 2.0)
