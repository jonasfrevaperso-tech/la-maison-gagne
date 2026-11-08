class_name TrialSpotlight
extends ThrowTrial
## LE PROJECTEUR (Cabaret, 2.0) : la meneuse de revue arpente la scène et ses deux escaliers, marque
## des pauses, repart dans l'autre sens, accélère. Le joueur tient la poursuite sur elle : le
## projecteur est lourd (il prend de l'élan et freine), et le cercle de lumière se resserre.
## Deux fois, les lumières vacillent et une doublure en argent entre en scène : il faut garder la
## poursuite sur la vraie, en or.
## Note = part du temps où la meneuse est dans la lumière (pleine au cœur, partielle au bord).

## Parcours (pixels) : palier gauche, escalier, plancher, escalier, palier droit.
const PATH: Array[Vector2] = [Vector2(330, 470), Vector2(450, 470), Vector2(650, 700), Vector2(1270, 700),
	Vector2(1470, 470), Vector2(1590, 470)]
const PX3: float = 0.005
const FLOOR_Y: float = 700.0
const FIGURE_H: float = 1.75
## Point visé : la poitrine, à cette hauteur au-dessus des pieds.
const CHEST: float = 220.0
const STRIDE: float = 70.0
const DOUBLE_SPEED: float = 1.15
const FLICKER: float = 0.6
const START: Vector2 = Vector2(960.0, 480.0)

var _len: float = 0.0
var _s: float = 0.0
var _goal: float = 0.0
var _speed: float = 0.0
var _pause: float = 0.0
var _next_dir: float = 1.0
var _spot: Vector2 = START
var _vel: Vector2 = Vector2.ZERO
var _axis: Vector2 = Vector2.ZERO
var _mouse_at: Vector2 = Vector2(-1, -1)
var _lit: float = 0.0
var _lit_time: float = 0.0
var _show_time: float = 0.0
var _doubles: Array[float] = []
var _double_s: float = -1.0
var _double_goal: float = 0.0
var _double_left: float = 0.0
var _flicker: float = 0.0
var _star: Figure3D = null
var _double: Figure3D = null
var _walk: float = 0.0
var _walk2: float = 0.0
var _fs: Dictionary = {}
var _heads: Array[Node3D] = []
var _ended: bool = false


func begin() -> void:
	for k: int in PATH.size() - 1:
		_len += PATH[k].distance_to(PATH[k + 1])
	_s = _len * 0.5
	_doubles.assign(Balance.data()["throw_trials"]["spotlight"]["double_at"] as Array)
	_new_goal()
	_pause = p("first_pause")
	_build_3d()


func _dur() -> float:
	return p("duration") * slow


## Prochaine étape : un point assez loin, de l'autre côté de préférence ; vitesse croissante.
func _new_goal() -> void:
	var gap: float = p("min_leg")
	var lo: float = 0.0
	var hi: float = _len
	var choices: Array[float] = []
	for k: int in 12:
		var g: float = lerpf(lo, hi, rng.randf())
		if absf(g - _s) >= gap:
			choices.append(g)
	_goal = choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else (_len - _s)
	var u: float = clampf(t / _dur(), 0.0, 1.0)
	_speed = lerpf(p("speed_start"), p("speed_end"), u) * rng.randf_range(0.85, 1.15) / slow
	_next_dir = signf(_goal - _s)


## Point du parcours à l'abscisse curviligne `s`.
func _at(s: float) -> Vector2:
	var left: float = clampf(s, 0.0, _len)
	for k: int in PATH.size() - 1:
		var seg: float = PATH[k].distance_to(PATH[k + 1])
		if left <= seg:
			return PATH[k].lerp(PATH[k + 1], left / maxf(seg, 0.001))
		left -= seg
	return PATH[PATH.size() - 1]


func _target() -> Vector2:
	return _at(_s) - Vector2(0, CHEST)


func _radius() -> float:
	return lerpf(p("radius_start"), p("radius_end"), clampf(t / _dur(), 0.0, 1.0)) * widen()


func tick(dt: float) -> void:
	if _ended:
		_sync_3d(dt)
		return
	_move_star(dt)
	_move_double(dt)
	_move_spot(dt)
	# Lumière : pleine au cœur du cercle, décroît jusqu'au bord.
	var d: float = _spot.distance_to(_target())
	var r: float = _radius()
	var inner: float = r * p("inner_ratio")
	_lit = 1.0 if d <= inner else clampf(1.0 - (d - inner) / maxf(r - inner, 1.0), 0.0, 1.0)
	_lit_time += _lit * dt
	_show_time += dt
	_sync_3d(dt)
	if t >= _dur():
		_ended = true
		var sc: float = _lit_time / maxf(_show_time, 0.001)
		pop(_target() - Vector2(0, 160.0), sc)
		finish(sc)


func _move_star(dt: float) -> void:
	if _pause > 0.0:
		_pause -= dt
		return
	var step: float = _speed * dt
	if absf(_goal - _s) <= step:
		_s = _goal
		_pause = rng.randf_range(p("pause_min"), p("pause_max")) * slow
		_new_goal()
		return
	_s += signf(_goal - _s) * step
	_walk += step / STRIDE


## Doublure : entre par une coulisse aux instants prévus, croise la meneuse, ressort.
func _move_double(dt: float) -> void:
	_flicker = maxf(0.0, _flicker - dt)
	if _double_s < 0.0 and not _doubles.is_empty() and t >= float(_doubles[0]) * slow:
		_doubles.pop_front()
		_flicker = FLICKER
		_double_s = 0.0 if _s > _len * 0.5 else _len
		_double_goal = _len - _double_s
		_double_left = p("double_seconds") * slow
		AudioBus.play("decor_switch", 0.8, -4.0)
	if _double_s < 0.0:
		return
	_double_left -= dt
	var step: float = _speed * DOUBLE_SPEED * dt
	_double_s = move_toward(_double_s, _double_goal, step)
	_walk2 += step / STRIDE
	if _double_left <= 0.0 or is_equal_approx(_double_s, _double_goal):
		_double_s = -1.0


## Poursuite lourde : le stick règle la vitesse visée, le projecteur y vient avec inertie ;
## la souris donne le point visé (le projecteur le rejoint à sa vitesse maximale).
func _move_spot(dt: float) -> void:
	var max_v: float = p("spot_speed")
	var want: Vector2 = (held_vector() + _axis).limit_length(1.0) * max_v
	if mouse and _mouse_at.x >= 0.0:
		var to: Vector2 = _mouse_at - _spot
		want = to.normalized() * minf(max_v, to.length() * p("mouse_gain"))
	_vel = _vel.move_toward(want, p("spot_accel") * dt)
	_spot += _vel * dt
	_spot = _spot.clamp(Vector2(220.0, 200.0), Vector2(1700.0, 760.0))


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_at = mm.position
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		_mouse_at = mb.position
		return true
	return false


func journal() -> Dictionary:
	return {"lit_share": snappedf(_lit_time / maxf(_show_time, 0.001), 0.001), "radius_end": p("radius_end")}


# --------------------------------------------------------------------------- bot


## Vise un peu en avant de la meneuse (là où elle sera), freine en arrivant.
func bot_wants() -> Dictionary:
	var vel: Vector2 = Vector2.ZERO
	if _pause <= 0.0:
		var ahead: Vector2 = _at(_s + signf(_goal - _s) * 10.0) - _at(_s)
		vel = ahead.normalized() * _speed
	var aim: Vector2 = _target() + vel * p("bot_lead")
	var d: Vector2 = aim - _spot
	var v_want: Vector2 = d * p("bot_gain") + vel
	return {"do": "axis", "v": (v_want / p("spot_speed")).limit_length(1.0)}


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2 if String(w.get("do", "")) == "axis" else Vector2.ZERO


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	var deco: Dictionary = CabaretSet.build(st, FLOOR_Y, 760.0)
	_heads.assign(deco.get("audience", []))
	st.env.ambient_light_energy = 0.18
	(deco["footlight"] as OmniLight3D).light_energy = 0.5
	var r: Node3D = st.root
	# Deux escaliers de revue (marches laquées, nez dorés) et leurs paliers.
	var lacquer: StandardMaterial3D = Stage3D.mat(Color("1c0c14"), 0.2, 0.3)
	var nose: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.7, 0.3)
	for side: int in 2:
		var a: Vector2 = PATH[1] if side == 0 else PATH[4]
		var b: Vector2 = PATH[2] if side == 0 else PATH[3]
		var steps: int = 8
		for k: int in steps:
			var u: float = (float(k) + 0.5) / float(steps)
			var p2: Vector2 = b.lerp(a, u)
			var h: float = FLOOR_Y - p2.y + 12.0
			var c: Vector3 = st.to3(Vector2(p2.x, FLOOR_Y - h * 0.5), -0.4)
			Stage3D.box(r, Vector3(absf(a.x - b.x) / float(steps) * PX3 + 0.01, h * PX3, 0.9), c, lacquer)
			Stage3D.box(r, Vector3(absf(a.x - b.x) / float(steps) * PX3 + 0.01, 0.02, 0.92), st.to3(Vector2(p2.x, FLOOR_Y - h), -0.4), nose)
		var land_x: float = (PATH[0].x + PATH[1].x) * 0.5 if side == 0 else (PATH[4].x + PATH[5].x) * 0.5
		var lh: float = FLOOR_Y - PATH[0].y + 12.0
		Stage3D.box(r, Vector3(220.0 * PX3, lh * PX3, 0.9), st.to3(Vector2(land_x, FLOOR_Y - lh * 0.5), -0.4), lacquer)
		Stage3D.box(r, Vector3(220.0 * PX3, 0.02, 0.92), st.to3(Vector2(land_x, FLOOR_Y - lh), -0.4), nose)
	_fs = CabaretSet.follow_spot(st, 9.0)
	_star = Figure3D.new().build(FIGURE_H, {"coat": Color("d4af37"), "trim": Palette.GOLD_LIGHT, "skirt": true, "hat": "bow",
		"hat_col": Color("ff2e88"), "hair": Color("2a140a"), "trousers": Color("e8b896")})
	r.add_child(_star)
	_double = Figure3D.new().build(FIGURE_H, {"coat": Color("aab0be"), "trim": Palette.IVORY, "skirt": true, "hat": "bow",
		"hat_col": Color("29e0ff"), "hair": Color("2a140a"), "trousers": Color("e8b896")})
	_double.visible = false
	r.add_child(_double)
	_sync_3d(0.0)


func _sync_3d(dt: float) -> void:
	if _star == null:
		return
	var st: Stage3D = stage
	_place(_star, _s, _goal, _pause > 0.0, _walk, dt)
	_double.visible = _double_s >= 0.0
	if _double.visible:
		_place(_double, _double_s, _double_goal, false, _walk2, dt)
	var spot_floor: Vector3 = st.to3(_spot + Vector2(0, CHEST), -0.4)
	var flick: float = 1.0 if _flicker <= 0.0 else (0.25 if fmod(_flicker * 20.0, 2.0) < 1.0 else 1.0)
	(_fs["spot"] as SpotLight3D).light_energy = 9.0 * flick
	CabaretSet.aim_spot(_fs, spot_floor, _radius() * PX3 * 1.25)
	CabaretSet.bob_audience(_heads, t * 0.8, 0.6)


func _place(fig: Figure3D, s: float, goal: float, paused: bool, walk: float, dt: float) -> void:
	fig.position = stage.to3(_at(s), -0.4)
	var dir: float = signf(goal - s)
	var face: float = 0.0 if paused else dir * PI * 0.5
	fig.rotation.y = lerp_angle(fig.rotation.y, face, minf(1.0, dt * 10.0))
	if paused:
		fig.animate(&"point", t, dt, _next_dir)
	else:
		fig.animate(&"walk" if _speed < p("run_from") else &"run", walk * PI, dt)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	var r: float = _radius()
	draw_arc(_spot, r, 0, TAU, 64, Color(Palette.GOLD_LIGHT, 0.35 + 0.4 * _lit), 3.0)
	draw_arc(_spot, r * p("inner_ratio"), 0, TAU, 48, Color(Palette.GOLD_LIGHT, 0.15), 2.0)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(660.0, 120.0, 600.0, 10.0), Color(Palette.INK, 0.7))
	draw_rect(Rect2(660.0, 120.0, 600.0 * left, 10.0), Palette.GOLD)
	var share: int = roundi(100.0 * _lit_time / maxf(_show_time, 0.001))
	text(Vector2(960.0, 170.0), tr("TRIAL_SPOTLIGHT_STATUS") % share, UiKit.SIZE_BODY, Palette.IVORY)
	if _double_s >= 0.0:
		text(Vector2(960.0, 220.0), tr("TRIAL_SPOTLIGHT_DOUBLE"), UiKit.SIZE_H2, Palette.CYAN)
