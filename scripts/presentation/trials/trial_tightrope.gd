class_name TrialTightrope
extends ThrowTrial
## LE FUNAMBULE (Cabaret, 2.0) : traverser le fil tendu au-dessus de la scène. Maintenir fait
## avancer (chaque pas déséquilibre un peu) ; le stick déplace la perche pour rattraper le corps
## qui penche — un pendule inversé : plus il penche, plus il tombe vite. Des rafales, annoncées par
## les fanions, poussent d'un côté. Trop penché : le funambule se rattrape au fil et perd du temps.
## Note = chemin parcouru × stabilité, moins une part par rattrapage.

const PX3: float = 0.005
const FLOOR_Y: float = 960.0
const WIRE_Y: float = 430.0
const WIRE_X0: float = 300.0
const WIRE_X1: float = 1620.0
const FIGURE_H: float = 1.3
const POLE_LEN: float = 2.4
const STRIDE: float = 46.0
const GAUGE_C: Vector2 = Vector2(960.0, 290.0)
const GAUGE_R: float = 120.0

var _x: float = WIRE_X0
var _theta: float = 0.0
var _omega: float = 0.0
var _walking: bool = false
var _axis: Vector2 = Vector2.ZERO
var _mouse_x: float = -1.0
var _walked: float = 0.0
var _falls: int = 0
var _fall_left: float = 0.0
var _steady_sum: float = 0.0
var _steady_n: int = 0
var _gusts: Array[Dictionary] = []  # {"at", "dir", "force"}
var _gust_force: float = 0.0
var _arrived: bool = false
var _arrived_t: float = 0.0
var _ended: bool = false
var _fig: Figure3D = null
var _pivot: Node3D = null
var _pole: Node3D = null
var _flags: Array[MeshInstance3D] = []
var _heads: Array[Node3D] = []


func begin() -> void:
	var at: float = p("gust_first")
	while at < p("duration"):
		_gusts.append({"at": at * slow, "dir": -1.0 if rng.randf() < 0.5 else 1.0, "force": rng.randf_range(p("gust_min"), p("gust_max"))})
		at += rng.randf_range(p("gust_every_min"), p("gust_every_max"))
	_build_3d()


func _dur() -> float:
	return p("duration") * slow


func _progress() -> float:
	return clampf((_x - WIRE_X0) / (WIRE_X1 - WIRE_X0), 0.0, 1.0)


## Force de la rafale en cours (rad/s²) et préavis (0..1) de la prochaine.
func _gust_now() -> Vector2:
	var force: float = 0.0
	var warn: float = 0.0
	for g: Dictionary in _gusts:
		var dtg: float = t - float(g["at"])
		var span: float = p("gust_seconds") * slow
		if dtg >= 0.0 and dtg <= span:
			force += float(g["dir"]) * float(g["force"]) * sin(PI * dtg / span)
		elif dtg < 0.0 and dtg > -p("gust_warn") * slow:
			warn = float(g["dir"]) * (1.0 + dtg / (p("gust_warn") * slow))
	return Vector2(force, warn)


func _control() -> float:
	var v: float = clampf(held_vector().x + _axis.x, -1.0, 1.0)
	if mouse and _mouse_x >= 0.0:
		v = clampf((_mouse_x - _x) / p("mouse_span"), -1.0, 1.0)
	return v


func tick(dt: float) -> void:
	if _ended:
		_sync_3d(dt)
		return
	var g: Vector2 = _gust_now()
	_gust_force = g.x
	if _fall_left > 0.0:
		_fall_left -= dt
		_theta = move_toward(_theta, 0.0, dt * 2.0)
		_omega = 0.0
	else:
		# Pendule inversé : la gravité creuse la pente, la perche la corrige, l'amorti calme.
		var acc: float = p("gravity") * sin(_theta) - p("damping") * _omega + _control() * p("control") + _gust_force / slow
		_omega += acc * dt
		_theta += _omega * dt
		if _walking and not _arrived:
			var before: float = floorf(_walked / STRIDE)
			var step: float = p("walk_speed") / slow * dt
			_x = minf(_x + step, WIRE_X1)
			_walked += step
			if floorf(_walked / STRIDE) != before:
				_omega += rng.randf_range(-1.0, 1.0) * p("step_kick")
				AudioBus.play("decor_creak", rng.randf_range(1.2, 1.5), -16.0)
			_steady_sum += 1.0 - pow(absf(_theta) / p("fall_angle"), 2.0)
			_steady_n += 1
			if _x >= WIRE_X1:
				_arrived = true
				_arrived_t = t
				pop(Vector2(WIRE_X1, WIRE_Y - 300.0), 1.0, "TRIAL_TIGHTROPE_ARRIVED")
				AudioBus.play("celebrate", 1.0, -6.0)
		if absf(_theta) > p("fall_angle"):
			_falls += 1
			_fall_left = p("fall_seconds") * slow
			pop(Vector2(_x, WIRE_Y - 300.0), 0.0, "TRIAL_TIGHTROPE_CAUGHT")
			AudioBus.play("whoosh", 0.7, -4.0)
	_sync_3d(dt)
	if t >= _dur() or (_arrived and t - _arrived_t >= p("bow_seconds")):
		_ended = true
		finish(_score())


func _score() -> float:
	var steady: float = _steady_sum / float(maxi(_steady_n, 1))
	var keep: float = maxf(0.0, 1.0 - p("fall_penalty") * float(_falls))
	return clampf(_progress() * keep * lerpf(1.0 - p("steady_weight"), 1.0, steady), 0.0, 1.0)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	if confirm_pressed(event):
		_walking = true
		return true
	if confirm_released(event):
		_walking = false
		return true
	return false


func journal() -> Dictionary:
	return {"progress": snappedf(_progress(), 0.001), "falls": _falls, "steady": snappedf(_steady_sum / float(maxi(_steady_n, 1)), 0.001)}


# --------------------------------------------------------------------------- bot


## Régulateur : ramène l'angle et sa vitesse à zéro en compensant la rafale ; n'avance que
## stable, et s'arrête à l'approche d'une rafale annoncée.
func bot_wants() -> Dictionary:
	var g: Vector2 = _gust_now()
	var u: float = -(p("bot_kp") * _theta + p("bot_kd") * _omega + g.x / p("control"))
	var v: Vector2 = Vector2(clampf(u, -1.0, 1.0), 0.0)
	var calm: bool = absf(_theta) < p("bot_walk_angle") and absf(g.y) <= 0.0 and _fall_left <= 0.0
	if _arrived:
		return {"do": "release"} if _walking else {"do": "axis", "v": v}
	if calm and not _walking:
		return {"do": "hold", "v": v}
	if not calm and _walking and absf(_theta) > p("bot_stop_angle"):
		return {"do": "release"}
	# En marche, la gâchette reste tenue : seul le stick change (geste « axis »).
	return {"do": "axis", "v": v}


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", _axis) as Vector2
	match String(w.get("do", "")):
		"hold":
			_walking = true
		"release":
			_walking = false
		"axis", "":
			if not w.has("v"):
				_axis = Vector2.ZERO


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	var deco: Dictionary = CabaretSet.build(st, FLOOR_Y, 780.0)
	_heads.assign(deco.get("audience", []))
	var r: Node3D = st.root
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.75, 0.3)
	var wood: StandardMaterial3D = Stage3D.mat(Color("5a3418"), 0.0, 0.6)
	# Mâts, plateformes et échelles de chaque côté ; le fil, ses haubans, le filet.
	for side: int in 2:
		var x: float = WIRE_X0 - 60.0 if side == 0 else WIRE_X1 + 60.0
		Stage3D.cylinder(r, 0.05, (FLOOR_Y - WIRE_Y + 160.0) * PX3, st.to3(Vector2(x, (FLOOR_Y + WIRE_Y - 160.0) * 0.5), -0.3), brass)
		Stage3D.box(r, Vector3(0.7, 0.05, 0.6), st.to3(Vector2(x, WIRE_Y + 6.0), -0.3), wood)
		for k: int in 12:
			var y: float = WIRE_Y + 40.0 + float(k) * (FLOOR_Y - WIRE_Y - 40.0) / 12.0
			Stage3D.box(r, Vector3(0.3, 0.025, 0.025), st.to3(Vector2(x + (40.0 if side == 0 else -40.0), y), -0.15), wood)
		var flag: MeshInstance3D = Stage3D.box(r, Vector3(0.32, 0.18, 0.01), st.to3(Vector2(x, WIRE_Y - 190.0), -0.3),
			Stage3D.mat(Color("ff2e88"), 0.0, 0.6))
		_flags.append(flag)
		Stage3D.sphere(r, 0.05, st.to3(Vector2(x, WIRE_Y - 160.0), -0.3), brass)
	var wire: MeshInstance3D = Stage3D.cylinder(r, 0.008, (WIRE_X1 - WIRE_X0 + 120.0) * PX3, st.to3(Vector2(960.0, WIRE_Y), -0.3),
		Stage3D.mat(Color("aab0be"), 0.9, 0.25))
	wire.rotation.z = PI * 0.5
	var net: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.82, 0.75), 0.0, 0.8)
	var net_y: float = FLOOR_Y - 160.0
	for k2: int in 34:
		var nx: float = WIRE_X0 + (WIRE_X1 - WIRE_X0) * float(k2) / 33.0
		Stage3D.box(r, Vector3(0.006, 0.006, 1.2), st.to3(Vector2(nx, net_y), -0.3), net)
	for k3: int in 7:
		var cord: MeshInstance3D = Stage3D.box(r, Vector3((WIRE_X1 - WIRE_X0) * PX3, 0.006, 0.006),
			st.to3(Vector2(960.0, net_y), -0.9 + 0.2 * float(k3)), net)
		cord.name = "net%d" % k3
	# Projecteur sur le funambule (suit sa position).
	_pivot = Node3D.new()
	r.add_child(_pivot)
	_fig = Figure3D.new().build(FIGURE_H, {"coat": Color("f0ece0"), "trousers": Color("f0ece0"), "trim": Color("ff2e88"),
		"hat": "", "shoes": Color("d8c8a0"), "hair": Color("201008")})
	_pivot.add_child(_fig)
	# La perche : tenue à hauteur des mains, elle s'incline avec la correction.
	_pole = Node3D.new()
	_pole.position = Vector3(0, FIGURE_H * 0.72, 0.14)
	_pivot.add_child(_pole)
	var pole: MeshInstance3D = Stage3D.cylinder(_pole, 0.018, POLE_LEN, Vector3.ZERO, Stage3D.mat(Color("8a5a2a"), 0.0, 0.5))
	pole.rotation.z = PI * 0.5
	for s: float in [-1.0, 1.0]:
		Stage3D.sphere(_pole, 0.05, Vector3(s * POLE_LEN * 0.5, 0, 0), brass)
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_energy = 5.0
	spot.spot_angle = 12.0
	spot.spot_range = 14.0
	spot.position = Vector3(0, 3.5, 3.0)
	_pivot.add_child(spot)
	spot.look_at_from_position(spot.position, Vector3(0, FIGURE_H * 0.5, 0))
	_sync_3d(0.0)


func _sync_3d(dt: float) -> void:
	if _fig == null:
		return
	_pivot.position = stage.to3(Vector2(_x, WIRE_Y), -0.3)
	_pivot.rotation.z = -_theta
	_pole.rotation.z = _theta * 0.4 + _control() * 0.35
	if _fall_left > 0.0:
		_fig.position.y = -FIGURE_H * 0.92
		_fig.animate(&"hang", t * 3.0, dt, 0.4 * sin(t * 4.0))
	else:
		_fig.position.y = 0.0
		var phase: float = _walked / STRIDE * PI
		_fig.animate(&"cheer" if _arrived else &"balance", phase, dt, clampf(_theta / p("fall_angle"), -1.0, 1.0))
	var g: Vector2 = _gust_now()
	for k: int in _flags.size():
		var f: MeshInstance3D = _flags[k]
		var push: float = clampf(g.x / maxf(p("gust_max"), 0.01), -1.0, 1.0) + g.y * 0.6
		f.rotation.y = push * 1.2 + sin(t * (6.0 + 10.0 * absf(push))) * (0.1 + 0.4 * absf(push))
	CabaretSet.bob_audience(_heads, t * 0.3, 0.3 + 0.7 * minf(1.0, absf(_theta) / p("fall_angle")))


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Jauge d'équilibre : arc, zones rouges aux bords, aiguille de l'angle.
	var lim: float = p("fall_angle")
	draw_arc(GAUGE_C, GAUGE_R, PI + 0.35, TAU - 0.35, 48, Color(Palette.INK, 0.8), 18.0)
	draw_arc(GAUGE_C, GAUGE_R, PI + 0.35, PI + 0.75, 12, Color(Palette.ROULETTE_RED, 0.8), 18.0)
	draw_arc(GAUGE_C, GAUGE_R, TAU - 0.75, TAU - 0.35, 12, Color(Palette.ROULETTE_RED, 0.8), 18.0)
	draw_arc(GAUGE_C, GAUGE_R, PI * 1.5 - 0.25, PI * 1.5 + 0.25, 12, Color(Palette.EMERALD, 0.7), 18.0)
	var a: float = PI * 1.5 + clampf(_theta / lim, -1.0, 1.0) * (PI * 0.5 - 0.35)
	draw_line(GAUGE_C, GAUGE_C + Vector2(cos(a), sin(a)) * (GAUGE_R + 14.0), Palette.GOLD_LIGHT, 5.0)
	draw_circle(GAUGE_C, 9.0, Palette.GOLD)
	# Rafale annoncée : flèche qui grossit du côté d'où elle pousse.
	var g: Vector2 = _gust_now()
	var warn: float = g.y if absf(g.y) > 0.0 else clampf(g.x / maxf(p("gust_max"), 0.01), -1.0, 1.0)
	if absf(warn) > 0.05:
		var dir: float = signf(warn)
		var c: Vector2 = GAUGE_C + Vector2(-dir * 260.0, -10.0)
		var span: float = 60.0 + 60.0 * absf(warn)
		draw_line(c - Vector2(dir * span * 0.5, 0), c + Vector2(dir * span * 0.5, 0), Color(Palette.CYAN, 0.9), 8.0)
		var tip: Vector2 = c + Vector2(dir * span * 0.5, 0)
		draw_colored_polygon(PackedVector2Array([tip + Vector2(dir * 22.0, 0), tip + Vector2(0, -16.0), tip + Vector2(0, 16.0)]), Palette.CYAN)
		text(c + Vector2(0, -40.0), tr("TRIAL_TIGHTROPE_GUST"), UiKit.SIZE_BODY, Palette.CYAN)
	# Avancée sur le fil et temps restant.
	var bar: Rect2 = Rect2(WIRE_X0, WIRE_Y + 40.0, WIRE_X1 - WIRE_X0, 8.0)
	draw_rect(bar, Color(Palette.INK, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * _progress(), bar.size.y)), Palette.GOLD)
	var left: float = clampf(1.0 - t / _dur(), 0.0, 1.0)
	draw_rect(Rect2(660.0, 100.0, 600.0, 10.0), Color(Palette.INK, 0.7))
	draw_rect(Rect2(660.0, 100.0, 600.0 * left, 10.0), Palette.GOLD)
	if _falls > 0:
		text(Vector2(960.0, 390.0), tr("TRIAL_TIGHTROPE_FALLS") % _falls, UiKit.SIZE_SMALL, Palette.ROULETTE_RED)
