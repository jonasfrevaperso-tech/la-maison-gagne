class_name TrialValet
extends ThrowTrial
## LE VOITURIER (Garage, 2.0) : garer la berline d'un client en créneau, en marche arrière, entre
## deux voitures le long du trottoir du parking. Modèle de voiture « bicyclette » (essieu arrière
## de référence) : le volant tourne à vitesse limitée, la voiture accélère et freine en douceur.
## Toucher une voiture ou le trottoir arrête net et coûte des points ; bien rangée (dans la place,
## près du trottoir, droite), la voiture s'arrête et la manœuvre est notée.
## Stick : gauche / droite braque, haut avance, bas recule (souris : maintenir le clic et viser).
## Note = moyenne des manœuvres (rangement, distance au trottoir, cap, moins les chocs).

const DT: float = 1.0 / 60.0
## Repère du parking (mètres, plan x / z) : trottoir le long du mur, file des voitures garées.
const CURB_Z: float = -2.0
const PARK_Z: float = CURB_Z + 0.35 + GarageSet.CAR_W * 0.5
const SLOT_A_X: float = 2.0

var _round: int = 0
var _pos: Vector2 = Vector2.ZERO  # essieu arrière (x, z)
var _head: float = 0.0
var _steer: float = 0.0
var _vel: float = 0.0
var _roll: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_v: Vector2 = Vector2.ZERO
var _mouse_held: bool = false
var _parked: Array[Vector2] = []  # essieux arrière des voitures garées (cap 0)
var _goal: Vector2 = Vector2.ZERO
var _bumps: int = 0
var _scrapes: int = 0
var _bump_cd: float = 0.0
var _still: float = 0.0
var _round_t0: float = 0.0
var _rest: float = 0.0
var _acc: float = 0.0
var _marks: Array[float] = []
var _total_bumps: int = 0
var _ended: bool = false
var _validate: bool = false
# Bot : phase (0 placement, 1 premier arc, 2 contre-braquage, 3 redressement, 4 recentrage), départ visé.
var _bot_phase: int = 0
var _bot_start_x: float = INF
var _bot_bumps: int = 0
var _bot_unstick: float = 0.0
var _bot_unstick_dir: float = 1.0
var _bot_last: Vector2 = Vector2.ZERO
var _cars: Array[Dictionary] = []
var _me: Dictionary = {}
var _valet: Figure3D = null
var _deco: Dictionary = {}
var _guides: Array[Node3D] = []
var _engine_cd: float = 0.0


func begin() -> void:
	_build_3d()
	_new_round()


func _rounds() -> int:
	return pi("rounds")


func _new_round() -> void:
	var gap: float = pk("slot_k", _round) * GarageSet.CAR_LEN
	var a_x: float = SLOT_A_X
	var b_x: float = a_x - gap - GarageSet.CAR_LEN
	_parked = [Vector2(a_x, PARK_Z), Vector2(b_x, PARK_Z), Vector2(a_x + GarageSet.CAR_LEN + 1.2, PARK_Z),
		Vector2(b_x - GarageSet.CAR_LEN - 1.4, PARK_Z)]
	var a_rear: float = a_x - GarageSet.REAR_OVERHANG
	var center: float = a_rear - gap * 0.5
	_goal = Vector2(center - (GarageSet.CAR_LEN * 0.5 - GarageSet.REAR_OVERHANG), PARK_Z)
	_pos = Vector2(a_x + rng.randf_range(p("start_min"), p("start_max")), PARK_Z + pk("lateral", _round))
	_head = 0.0
	_steer = 0.0
	_vel = 0.0
	_bumps = 0
	_scrapes = 0
	_still = 0.0
	_validate = false
	_round_t0 = t
	_bot_phase = 0
	_bot_start_x = INF
	_bot_bumps = 0
	_bot_unstick = 0.0
	_sync_scene()


# --------------------------------------------------------------------------- physique


## Un pas du modèle : volant vers sa consigne (vitesse limitée), vitesse vers la consigne de
## l'accélérateur (frein quand on lâche), puis avance de l'essieu arrière et rotation du cap.
static func advance(s: Dictionary, steer_in: float, throttle: float, prm: Dictionary) -> void:
	var target_d: float = clampf(steer_in, -1.0, 1.0) * float(prm["steer_max"])
	s["steer"] = move_toward(float(s["steer"]), target_d, float(prm["steer_rate"]) * DT)
	var v: float = float(s["vel"])
	var want: float = throttle * (float(prm["v_fwd"]) if throttle > 0.0 else float(prm["v_rev"]))
	var rate: float = float(prm["brake"])
	if absf(want) > 0.01 and (absf(v) < 0.01 or signf(want) == signf(v)):
		rate = float(prm["accel"])
	v = move_toward(v, want, rate * DT)
	s["vel"] = v
	var h: float = float(s["head"])
	s["pos"] = (s["pos"] as Vector2) + Vector2.from_angle(h) * v * DT
	s["head"] = h + v / GarageSet.WHEELBASE * tan(float(s["steer"])) * DT


func _prm() -> Dictionary:
	return {"steer_max": p("steer_max"), "steer_rate": p("steer_rate"), "v_fwd": p("v_fwd"), "v_rev": p("v_rev"),
		"accel": p("accel"), "brake": p("brake")}


func _state() -> Dictionary:
	return {"pos": _pos, "head": _head, "steer": _steer, "vel": _vel}


## Vrai si la voiture posée ainsi touche quelque chose (cf. `contact`).
func hits(pos: Vector2, head: float, grow: float = 0.0) -> bool:
	return contact(pos, head, grow) != 0


## Contact de la voiture posée ainsi : 0 aucun, 1 un pneu bute contre la bordure (la caisse, elle,
## passe au-dessus du trottoir), 2 la caisse touche une voiture garée.
func contact(pos: Vector2, head: float, grow: float = 0.0) -> int:
	var body: PackedVector2Array = GarageSet.car_corners(pos, head, grow)
	# La caisse passe au-dessus du trottoir ; seuls les pneus butent contre la bordure.
	var f: Vector2 = Vector2.from_angle(head)
	var side: Vector2 = f.orthogonal() * (GarageSet.CAR_W * 0.5 - 0.09 + grow)
	for axle: float in [0.0, GarageSet.WHEELBASE]:
		for sv: float in [-1.0, 1.0]:
			var wheel: Vector2 = pos + f * axle + side * sv
			for e: float in [-GarageSet.WHEEL_R, GarageSet.WHEEL_R]:
				if (wheel + f * e).y < CURB_Z:
					return 1
	for pc: Vector2 in _parked:
		if not Geometry2D.intersect_polygons(body, GarageSet.car_corners(pc, 0.0)).is_empty():
			return 2
	return 0


## Vrai si la voiture est entièrement rangée entre les deux voitures de la place.
func inside(pos: Vector2, head: float) -> bool:
	var body: PackedVector2Array = GarageSet.car_corners(pos, head)
	var lo: float = _parked[1].x - GarageSet.REAR_OVERHANG + GarageSet.CAR_LEN
	var hi: float = _parked[0].x - GarageSet.REAR_OVERHANG
	for c: Vector2 in body:
		if c.x < lo or c.x > hi or c.y > PARK_Z + GarageSet.CAR_W * 0.5 + p("lane_tol"):
			return false
	return true


## Note d'une voiture arrêtée : rangée, près du trottoir, droite, centrée ; moins les bosses
## (carrosserie) et, bien moins, les pneus frottés contre la bordure.
func quality(pos: Vector2, head: float, bumps: int, scrapes: int = 0) -> float:
	if not inside(pos, head):
		return 0.0
	var lat: float = clampf(absf(pos.y - PARK_Z) / p("lat_tol"), 0.0, 1.0)
	var ang: float = clampf(absf(wrapf(head, -PI, PI)) / p("head_tol"), 0.0, 1.0)
	var lon: float = clampf(absf(pos.x - _goal.x) / p("lon_tol"), 0.0, 1.0)
	var q: float = 1.0 - p("w_lat") * lat - p("w_head") * ang - p("w_lon") * lon
	return clampf(q - p("bump_cost") * float(bumps) - p("curb_cost") * float(scrapes), 0.0, 1.0)


# --------------------------------------------------------------------------- jeu


func _controls() -> Vector2:
	if mouse and _mouse_held:
		return _mouse_v
	var hv: Vector2 = held_vector()
	var throttle: float = clampf(-hv.y - _axis.y, -1.0, 1.0)
	if absf(throttle) < p("deadzone"):  # zone morte de la pédale : on lâche = on freine
		throttle = 0.0
	return Vector2(clampf(hv.x + _axis.x, -1.0, 1.0), throttle)


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_round += 1
			if _round >= _rounds():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_round()
		return
	_bump_cd = maxf(0.0, _bump_cd - dt)
	var c: Vector2 = _controls()
	_acc += dt
	var prm: Dictionary = _prm()
	while _acc >= DT:
		_acc -= DT
		var s: Dictionary = _state()
		advance(s, c.x, c.y, prm)
		_steer = float(s["steer"])
		var hit: int = contact(s["pos"] as Vector2, float(s["head"]))
		if hit != 0:
			_vel = 0.0
			if _bump_cd <= 0.0:
				if hit == 2:
					_bumps += 1
					_total_bumps += 1
				else:
					_scrapes += 1
				_bump_cd = p("bump_cooldown")
				AudioBus.play("decor_bump" if hit == 2 else "decor_screech", 1.0, -3.0 if hit == 2 else -9.0)
				var at: Vector2 = stage.project(Vector3(_pos.x, 1.0, _pos.y)) if stage != null else Vector2(960.0, 400.0)
				pop(at, 0.0 if hit == 2 else 0.5, "TRIAL_VALET_BUMP" if hit == 2 else "TRIAL_VALET_CURB")
		else:
			_pos = s["pos"] as Vector2
			_head = float(s["head"])
			_vel = float(s["vel"])
			_roll += _vel * DT / GarageSet.WHEEL_R
	_engine_cd -= dt
	if absf(c.y) > 0.5 and _engine_cd <= 0.0:
		AudioBus.play("decor_engine", 0.9 + 0.2 * absf(_vel), -14.0)
		_engine_cd = 0.6
	var moving: bool = absf(_vel) > p("still_speed") or absf(c.y) > 0.1
	_still = 0.0 if moving else _still + dt
	if (_still >= p("settle_seconds") and inside(_pos, _head)) or (_validate and not moving):
		_end_round()
	elif t - _round_t0 >= p("round_seconds") * slow:
		_end_round()


func _end_round() -> void:
	var q: float = quality(_pos, _head, _bumps, _scrapes)
	_marks.append(q)
	var key: String = "TRIAL_VALET_PERFECT" if q >= 0.9 else ("TRIAL_VALET_PARKED" if q > 0.0 else "TRIAL_VALET_OUT")
	if q <= 0.0 and t - _round_t0 >= p("round_seconds") * slow:
		key = "TRIAL_VALET_LATE"
	pop(Vector2(960.0, 300.0), q, key)
	AudioBus.play("chime" if q > 0.0 else "lose_soft", 1.0 + 0.3 * q, -5.0)
	if q >= 0.9:
		AudioBus.play("decor_horn", 1.0, -10.0)
	_rest = p("rest_seconds") * slow


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_v = Vector2(clampf((mm.position.x - 960.0) / 420.0, -1.0, 1.0), clampf((620.0 - mm.position.y) / 300.0, -1.0, 1.0))
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mouse and mb.button_index == MOUSE_BUTTON_LEFT:
		_mouse_held = mb.pressed
		_mouse_v = Vector2(clampf((mb.position.x - 960.0) / 420.0, -1.0, 1.0), clampf((620.0 - mb.position.y) / 300.0, -1.0, 1.0))
		return true
	if confirm_pressed(event):
		_validate = true
		return true
	return false


func journal() -> Dictionary:
	return {"rounds": _marks.size(), "bumps": _total_bumps}


# --------------------------------------------------------------------------- bot


## Le bot simule son propre modèle : il se place d'abord à l'abscisse d'où la manœuvre type
## (plein braquage vers le trottoir, puis contre-braquage) finit dans la place, puis il
## enchaîne les arcs en basculant le volant dès que la simulation dit que c'est le moment.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0:
		return {"do": "axis", "v": Vector2.ZERO}
	if _bumps + _scrapes > _bot_bumps:  # bosse : on se dégage, puis on reprend la manœuvre depuis le début
		_bot_bumps = _bumps + _scrapes
		_bot_unstick = p("bot_unstick_seconds")
		_bot_unstick_dir = -signf(_bot_last.y) if _bot_last.y != 0.0 else 1.0
	if _bot_unstick > 0.0:
		_bot_unstick -= DT
		if _bot_unstick <= 0.0:
			_bot_phase = 0
			_bot_start_x = INF
		return {"do": "axis", "v": Vector2(0.0, -_bot_unstick_dir)}
	var cmd: Vector2 = _bot_command(_state(), true)
	_bot_last = cmd
	return {"do": "axis", "v": Vector2(cmd.x, -cmd.y)}


## Commande (braquage, accélérateur) du bot pour l'état `s` ; `live` : fait avancer ses phases.
func _bot_command(s: Dictionary, live: bool) -> Vector2:
	var phase: int = _bot_phase
	var pos: Vector2 = s["pos"] as Vector2
	var h: float = float(s["head"])
	if phase == 0:
		if _bot_start_x == INF:
			_bot_start_x = _plan_start(pos.y)
		var dx: float = _bot_start_x - pos.x
		if absf(dx) < p("bot_pos_tol") and absf(float(s["vel"])) < p("bot_still"):
			phase = 1
		else:
			return Vector2(-h * 4.0, _approach(dx, float(s["vel"])))
	if phase == 1 and _counter_lands(s):
		phase = 2
	if phase == 2 and _straighten_lands(s):
		phase = 3
	if phase == 3 and absf(float(s["steer"])) < 0.02:
		phase = 4
	if phase in [1, 2, 3] and _rear_gap(s) < p("bot_rear_margin"):
		phase = 4  # plus de place derrière : on s'arrête et on finit en avançant
	if live:
		_bot_phase = phase
	match phase:
		1:
			return Vector2(-1.0, -1.0)
		2:
			return Vector2(1.0, -1.0)
		3:
			return Vector2(0.0, -1.0)
	var lon: float = _goal.x - pos.x
	return Vector2(clampf(-h * 6.0, -1.0, 1.0), _approach(lon, float(s["vel"])) if absf(lon) > p("bot_pos_tol") * 0.5 else 0.0)


## Place qui resterait derrière la voiture (jusqu'au pare-chocs de la voiture garée derrière) si
## elle freinait maintenant ; négatif = elle la toucherait.
func _rear_gap(s: Dictionary) -> float:
	var v: float = float(s["vel"])
	if v >= 0.0:
		return INF
	var stop_d: float = v * v / (2.0 * p("brake")) + absf(v) * DT * 2.0
	var rear_x: float = INF
	for c: Vector2 in GarageSet.car_corners(s["pos"] as Vector2, float(s["head"])):
		rear_x = minf(rear_x, c.x)
	return rear_x - stop_d - (_parked[1].x - GarageSet.REAR_OVERHANG + GarageSet.CAR_LEN)


## Accélérateur pour parcourir `dx` et s'arrêter (freinage anticipé).
func _approach(dx: float, v: float) -> float:
	var stop_d: float = v * v / (2.0 * p("brake")) + absf(v) * DT * 2.0
	if absf(dx) <= stop_d and signf(v) == signf(dx):
		return 0.0
	return clampf(dx * p("bot_gain"), -1.0, 1.0)


## Départ (abscisse) d'où la manœuvre type, lancée à l'arrêt et cap 0 depuis la file `z`,
## finit dans la place sans rien toucher : le plus près possible du centre (recentrage ensuite).
func _plan_start(z: float) -> float:
	var dx: float = _simulate_maneuver(Vector2(0.0, z)).x
	var back: float = p("bot_back")
	while back <= p("bot_back_max"):
		var x0: float = _goal.x - back - dx
		if _simulate_maneuver(Vector2(x0, z)).y < 0.5:
			return x0
		back += 0.1
	return _goal.x - p("bot_back") - dx


## Simule la manœuvre type depuis `start` : (abscisse finale à l'arrêt, 1 si un choc).
func _simulate_maneuver(start: Vector2) -> Vector2:
	var saved: int = _bot_phase
	var s: Dictionary = {"pos": start, "head": 0.0, "steer": 0.0, "vel": 0.0}
	_bot_phase = 1
	var prm: Dictionary = _prm()
	var hit: float = 0.0
	for _k: int in 900:
		var cmd: Vector2 = _bot_command(s, true)
		if _bot_phase >= 4:
			break
		advance(s, cmd.x, cmd.y, prm)
		if hits(s["pos"] as Vector2, float(s["head"]), p("bot_margin")):
			hit = 1.0
	for _k2: int in 120:  # puis le freinage jusqu'à l'arrêt
		if absf(float(s["vel"])) < 0.01:
			break
		advance(s, 0.0, 0.0, prm)
		if hits(s["pos"] as Vector2, float(s["head"]), p("bot_margin")):
			hit = 1.0
	_bot_phase = saved
	return Vector2((s["pos"] as Vector2).x, hit)


## En contre-braquant maintenant (marche arrière), la voiture finit-elle à la hauteur de la file ?
func _counter_lands(s: Dictionary) -> bool:
	var q: Dictionary = s.duplicate()
	var prm: Dictionary = _prm()
	for _k: int in 600:
		advance(q, 1.0, -1.0, prm)
		if float(q["head"]) <= 0.0:
			break
	return (q["pos"] as Vector2).y <= PARK_Z + p("bot_lat_bias")


## En remettant les roues droites maintenant, le cap finit-il à zéro ?
func _straighten_lands(s: Dictionary) -> bool:
	var q: Dictionary = s.duplicate()
	var prm: Dictionary = _prm()
	for _k: int in 200:
		advance(q, 0.0, -1.0, prm)
		if absf(float(q["steer"])) < 0.001:
			break
	return float(q["head"]) <= 0.0


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2 if String(w.get("do", "")) == "axis" else Vector2.ZERO


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	var pillars: Array[Vector2] = [Vector2(-9.0, CURB_Z - 1.2), Vector2(-1.5, CURB_Z - 1.2), Vector2(6.0, CURB_Z - 1.2)]
	_deco = GarageSet.build(st, Vector3(-2.0, 0.0, 0.0), Vector2(26.0, 14.0), pillars, CURB_Z - 1.8)
	var r: Node3D = st.root
	# Trottoir et bordure, marquage de la voie, flèches au sol.
	Stage3D.box(r, Vector3(30.0, 0.16, 1.6), Vector3(-2.0, 0.08, CURB_Z - 0.8), Stage3D.mat(Color("8a8478"), 0.0, 0.9))
	Stage3D.box(r, Vector3(30.0, 0.17, 0.12), Vector3(-2.0, 0.085, CURB_Z - 0.06), Stage3D.mat(GarageSet.HAZARD, 0.0, 0.6))
	for k: int in 7:
		var x0: float = -14.0 + 4.0 * float(k)
		GarageSet.paint_line(r, Vector2(x0, PARK_Z + 2.6), Vector2(x0 + 2.0, PARK_Z + 2.6))
	for k2: int in 4:
		var c: Dictionary = GarageSet.car(GarageSet.CAR_COLORS[(k2 * 3 + 1) % GarageSet.CAR_COLORS.size()])
		r.add_child(c["node"] as Node3D)
		_cars.append(c)
	_me = GarageSet.car(GarageSet.CAR_COLORS[0])
	r.add_child(_me["node"] as Node3D)
	# Silhouette du conducteur derrière le pare-brise.
	Stage3D.sphere(_me["node"] as Node3D, 0.13, Vector3(1.2, 1.12, -0.35), Stage3D.mat(Color("2a1a14"), 0.0, 0.8))
	# Repère de la place : quatre équerres peintes au sol.
	for k3: int in 4:
		var g: Node3D = Node3D.new()
		r.add_child(g)
		Stage3D.box(g, Vector3(0.6, 0.006, 0.08), Vector3(0.3, 0.012, 0), Stage3D.mat(Palette.GOLD, 0.5, 0.4))
		Stage3D.box(g, Vector3(0.08, 0.006, 0.6), Vector3(0, 0.012, 0.3), Stage3D.mat(Palette.GOLD, 0.5, 0.4))
		g.rotation.y = -PI * 0.5 * float(k3)
		_guides.append(g)
	_valet = GarageSet.valet()
	r.add_child(_valet)
	st.look(Vector3(-2.2, p("cam_h"), PARK_Z + p("cam_back")), Vector3(-2.2, 0.0, PARK_Z + 0.4), 40.0)


func _sync_scene() -> void:
	if stage == null:
		return
	for k: int in _cars.size():
		GarageSet.pose_car(_cars[k], _parked[k], 0.0)
	var body: PackedVector2Array = GarageSet.car_corners(_goal, 0.0, 0.25)
	for k2: int in _guides.size():
		var corner: Vector2 = body[(k2 + 2) % 4]
		_guides[k2].position = Vector3(corner.x, 0.0, corner.y)
	_valet.position = Vector3(_goal.x + 1.0, 0.16, CURB_Z - 0.7)


func _sync_3d(dt: float) -> void:
	if _me.is_empty():
		return
	var c: Vector2 = _controls() if not _ended and _rest <= 0.0 else Vector2.ZERO
	var braking: bool = (absf(c.y) < 0.1 and absf(_vel) > 0.05) or c.y * _vel < 0.0
	GarageSet.pose_car(_me, _pos, _head, _steer, _roll, braking, _vel < -0.02)
	GarageSet.animate(_deco, t)
	if _rest > 0.0 and not _marks.is_empty() and _marks[_marks.size() - 1] > 0.0:
		_valet.animate(&"cheer", t * 8.0, dt)
	elif _vel < -0.05:
		# Le voiturier guide de la main : à gauche ou à droite selon le cap de la manœuvre.
		_valet.animate(&"point", t, dt, clampf(_head * 3.0, -1.0, 1.0))
	else:
		_valet.animate(&"idle", t * 2.0, dt)
	_valet.rotation.y = 0.0


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	# Volant (en bas à gauche) qui tourne avec le braquage, rapport engagé, chrono.
	var wc: Vector2 = Vector2(210.0, 860.0)
	var ang: float = _steer / p("steer_max") * PI * 0.75
	draw_arc(wc, 92.0, 0.0, TAU, 48, Color(Palette.INK, 0.8), 30.0)
	draw_arc(wc, 92.0, 0.0, TAU, 48, Palette.IVORY, 10.0)
	for k: int in 3:
		var spoke: float = ang + PI * 0.5 + TAU / 3.0 * float(k)
		draw_line(wc, wc + Vector2.from_angle(spoke) * 86.0, Palette.IVORY, 8.0)
	draw_circle(wc, 22.0, Palette.GOLD)
	draw_circle(wc + Vector2.from_angle(ang - PI * 0.5) * 92.0, 10.0, Palette.ROULETTE_RED)
	var gear: String = "R" if _vel < -0.02 else ("D" if _vel > 0.02 else "N")
	text(Vector2(390.0, 880.0), gear, UiKit.SIZE_H1, Palette.ROULETTE_RED if gear == "R" else Palette.GOLD_LIGHT)
	var left: float = clampf(1.0 - (t - _round_t0) / (p("round_seconds") * slow), 0.0, 1.0)
	var bar: Rect2 = Rect2(660.0, 1000.0, 600.0, 16.0)
	draw_rect(bar, Color(Palette.INK, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
	text(Vector2(960.0, 105.0), tr("TRIAL_VALET_STATUS") % [mini(_round + 1, _rounds()), _rounds()], UiKit.SIZE_BODY, Palette.IVORY)
	if _bumps > 0:
		text(Vector2(960.0, 155.0), tr("TRIAL_VALET_BUMPS") % _bumps, UiKit.SIZE_SMALL, Palette.ROULETTE_RED, "body", 4)
