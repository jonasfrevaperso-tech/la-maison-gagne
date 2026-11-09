class_name TrialRally
extends ThrowTrial
## LE RALLYE (Garage, 2.0) : un tour chronométré du niveau −2, entre les plots, au volant d'une
## berline préparée. La voiture accélère seule ; le stick braque (bas : freiner). Le frein à main
## (maintenir) casse l'adhérence de l'arrière : la voiture pivote et glisse — seul moyen de
## passer l'épingle du fond sans perdre tout son élan. Portes de plots à franchir dans l'ordre
## (la flèche montre la suivante) ; un plot renversé ou un mur touché coûte des points.
## Modèle : vitesse décomposée en longitudinal (moteur, freins) et latéral (adhérence qui l'amortit,
## bien moindre au frein à main) ; le lacet suit le braquage, plus vif au frein à main.
## Note = chrono (du temps de référence au temps limite), moins plots et murs.

const DT: float = 1.0 / 60.0
const CAR_R: float = 1.0  # rayon de contact de la voiture avec un plot (m)

var _pos: Vector2 = Vector2.ZERO  # centre de la voiture (x, z)
var _head: float = 0.0
var _vel: Vector2 = Vector2.ZERO
var _steer: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _hb: bool = false  # frein à main tenu
var _mouse_pt: Vector3 = Vector3.INF
var _gates: Array[PackedVector2Array] = []
var _gate: int = 0
var _cones: Array[Dictionary] = []  # p, vel, down, node
var _knocked: int = 0
var _walls: int = 0
var _wall_cd: float = 0.0
var _t0: float = 0.0
var _lap: float = -1.0
var _rest: float = 0.0
var _ended: bool = false
var _acc: float = 0.0
var _drift_t: float = 0.0
var _screech_cd: float = 0.0
var _half: Vector2 = Vector2.ZERO
var _car: Dictionary = {}
var _roll: float = 0.0
var _deco: Dictionary = {}
var _arrow: Node3D = null
var _flags: Array[Node3D] = []
var _marshal: Figure3D = null
var _skid: Array[MeshInstance3D] = []
var _skid_i: int = 0


func begin() -> void:
	_half = Vector2(p("lot_w"), p("lot_d")) * 0.5
	var courses: Array = entry.get("courses", []) as Array
	var course: Dictionary = courses[rng.randi_range(0, courses.size() - 1)] as Dictionary
	var mirror: float = -1.0 if rng.randf() < 0.5 else 1.0
	var inner_only: Array[bool] = []
	for g: Variant in course["gates"]:
		var a: Array = g as Array
		_gates.append(PackedVector2Array([Vector2(float(a[0]), float(a[1]) * mirror), Vector2(float(a[2]), float(a[3]) * mirror)]))
		inner_only.append(a.size() > 4 and int(a[4]) == 1)  # porte jusqu'au mur : un seul plot
	var st: Array = course["start"] as Array
	_pos = Vector2(float(st[0]), float(st[1]) * mirror)
	_head = float(st[2]) * mirror
	for gi: int in _gates.size():
		for ci: int in (1 if inner_only[gi] else 2):
			var c: Vector2 = _gates[gi][ci]
			_cones.append({"p": c, "vel": Vector2.ZERO, "down": false, "node": null, "spin": 0.0})
	for extra: Variant in course.get("cones", []):
		var e: Array = extra as Array
		_cones.append({"p": Vector2(float(e[0]), float(e[1]) * mirror), "vel": Vector2.ZERO, "down": false, "node": null, "spin": 0.0})
	_t0 = t
	_build_3d()


# --------------------------------------------------------------------------- physique


## Un pas du modèle de dérapage : `s` = {pos, head, vel}, commandes braquage / frein / frein à main.
static func advance(s: Dictionary, steer: float, brake: bool, hb: bool, prm: Dictionary) -> void:
	var h: float = float(s["head"])
	var f: Vector2 = Vector2.from_angle(h)
	var side: Vector2 = f.orthogonal()
	var vel: Vector2 = s["vel"] as Vector2
	var lon: float = vel.dot(f)
	var lat: float = vel.dot(side)
	if brake:
		lon = move_toward(lon, 0.0, float(prm["brake"]) * DT)
	else:
		lon = move_toward(lon, float(prm["v_max"]), float(prm["accel"]) * DT)
	if hb:
		lon = move_toward(lon, 0.0, float(prm["hb_drag"]) * DT)
	lat *= exp(-float(prm["hb_grip"] if hb else prm["grip"]) * DT)
	var yaw: float = clampf(steer, -1.0, 1.0) * float(prm["yaw_max"]) * clampf(absf(lon) / float(prm["v_ref"]), 0.0, 1.0)
	if hb:
		yaw *= float(prm["hb_yaw"])
	s["head"] = h + yaw * DT
	vel = f * lon + side * lat
	s["vel"] = vel
	s["pos"] = (s["pos"] as Vector2) + vel * DT


func _prm() -> Dictionary:
	return {"brake": p("brake"), "v_max": p("v_max"), "accel": p("accel"), "hb_drag": p("hb_drag"), "hb_grip": p("hb_grip"),
		"grip": p("grip"), "yaw_max": p("yaw_max"), "v_ref": p("v_ref"), "hb_yaw": p("hb_yaw")}


## Glissement latéral (m/s) : sert aux traces de pneus et au crissement.
func slip() -> float:
	return absf(_vel.dot(Vector2.from_angle(_head).orthogonal()))


## Vrai si le segment (a → b) parcouru par la voiture coupe la porte `g`.
static func crosses(a: Vector2, b: Vector2, g: PackedVector2Array) -> bool:
	return Geometry2D.segment_intersects_segment(a, b, g[0], g[1]) != null


## Note d'un tour bouclé en `lap` secondes avec ces fautes.
func quality(lap: float, knocked: int, walls: int) -> float:
	var q: float = clampf((p("lap_max") - lap) / (p("lap_max") - p("lap_par")), 0.0, 1.0)
	return clampf(q - p("cone_cost") * float(knocked) - p("wall_cost") * float(walls), 0.0, 1.0)


# --------------------------------------------------------------------------- jeu


func _controls() -> Vector2:
	if mouse and _mouse_pt != Vector3.INF:
		var to: Vector2 = Vector2(_mouse_pt.x, _mouse_pt.z) - _pos
		var err: float = wrapf(to.angle() - _head, -PI, PI)
		return Vector2(clampf(err * 2.0, -1.0, 1.0), 0.0)
	var hv: Vector2 = held_vector()
	return Vector2(clampf(hv.x + _axis.x, -1.0, 1.0), clampf(hv.y + _axis.y, -1.0, 1.0))


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_ended = true
			finish(quality(_lap, _knocked, _walls) if _lap >= 0.0 else _partial())
		return
	var c: Vector2 = _controls()
	_steer = c.x
	var brake: bool = c.y > p("brake_stick")
	var prm: Dictionary = _prm()
	_acc += dt
	_wall_cd = maxf(0.0, _wall_cd - dt)
	while _acc >= DT and _rest <= 0.0:
		_acc -= DT
		var s: Dictionary = {"pos": _pos, "head": _head, "vel": _vel}
		advance(s, c.x, brake, _hb, prm)
		var before: Vector2 = _pos
		_pos = s["pos"] as Vector2
		_head = float(s["head"])
		_vel = s["vel"] as Vector2
		_roll += _vel.length() * DT / GarageSet.WHEEL_R
		if _hb:
			_drift_t += DT
		_walls_bounce()
		_hit_cones()
		if _gate < _gates.size() and crosses(before, _pos, _gates[_gate]):
			_gate += 1
			AudioBus.play("tick", 1.0 + 0.05 * float(_gate), -4.0)
			if _gate >= _gates.size():
				_lap = t - _t0
				var q: float = quality(_lap, _knocked, _walls)
				pop(Vector2(960.0, 300.0), q, "TRIAL_RALLY_FINISH")
				AudioBus.play("chime", 1.0 + 0.3 * q, -4.0)
				_rest = p("rest_seconds") * slow
	_screech_cd -= dt
	if slip() > p("screech_slip") and _screech_cd <= 0.0:
		AudioBus.play("decor_screech", 0.9 + 0.1 * slip() / p("v_max"), -12.0)
		_screech_cd = 0.5
	if _rest <= 0.0 and t - _t0 >= p("lap_max") * slow:
		pop(Vector2(960.0, 300.0), 0.0, "TRIAL_RALLY_LATE")
		_rest = p("rest_seconds") * slow


## Tour non bouclé : un peu de crédit pour les portes passées.
func _partial() -> float:
	return p("partial") * float(_gate) / float(maxi(_gates.size(), 1))


## Caisse de la voiture (coins, plan x / z), grossie de `grow`.
func _body(grow: float = 0.0) -> PackedVector2Array:
	var rear_axle: Vector2 = _pos - Vector2.from_angle(_head) * (GarageSet.CAR_LEN * 0.5 - GarageSet.REAR_OVERHANG)
	return GarageSet.car_corners(rear_axle, _head, grow)


func _walls_bounce() -> void:
	var lim: Vector2 = _half - Vector2(CAR_R, CAR_R)
	var hit: bool = false
	if absf(_pos.x) > lim.x:
		_pos.x = signf(_pos.x) * lim.x
		_vel.x *= -p("wall_bounce")
		hit = true
	if absf(_pos.y) > lim.y:
		_pos.y = signf(_pos.y) * lim.y
		_vel.y *= -p("wall_bounce")
		hit = true
	if hit and _wall_cd <= 0.0:
		_walls += 1
		_wall_cd = p("wall_cooldown")
		AudioBus.play("decor_bump", 0.9, -3.0)
		pop(stage.project(Vector3(_pos.x, 1.0, _pos.y)) if stage != null else Vector2(960.0, 500.0), 0.0, "TRIAL_RALLY_WALL")


func _hit_cones() -> void:
	for cd: Dictionary in _cones:
		if bool(cd["down"]):
			cd["p"] = (cd["p"] as Vector2) + (cd["vel"] as Vector2) * DT
			cd["vel"] = (cd["vel"] as Vector2) * exp(-3.0 * DT)
			continue
		var d: Vector2 = (cd["p"] as Vector2) - _pos
		if Geometry2D.is_point_in_polygon(cd["p"] as Vector2, _body(p("cone_r"))):
			cd["down"] = true
			cd["vel"] = _vel * 0.8 + d.normalized() * 2.0
			cd["spin"] = rng.randf_range(-1.0, 1.0)
			_knocked += 1
			AudioBus.play("decor_bump", 1.6, -8.0)
			pop(stage.project(Vector3(_pos.x, 1.0, _pos.y)) if stage != null else Vector2(960.0, 500.0), 0.3, "TRIAL_RALLY_CONE")


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if stage != null:
			_mouse_pt = stage.unproject_to_plane(mm.position, 0.0)
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mouse:
		_hb = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		return true
	if confirm_pressed(event):
		_hb = true
		return true
	if confirm_released(event):
		_hb = false
		return true
	return false


func journal() -> Dictionary:
	return {"lap": snappedf(_lap, 0.01), "gates": _gate, "cones": _knocked, "walls": _walls, "handbrake_s": snappedf(_drift_t, 0.01)}


# --------------------------------------------------------------------------- bot


## Pilote : vise un point sur la trajectoire (porte suivante, puis celle d'après à l'approche),
## braque à proportion de l'écart de cap ; tire le frein à main quand le virage demandé est trop
## serré pour la vitesse, freine si l'écart est énorme.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0 or _gate >= _gates.size():
		return {"do": "release"} if _hb else {"do": "axis", "v": Vector2.ZERO}
	var aim: Vector2 = _bot_aim()
	var err: float = wrapf((aim - _pos).angle() - _head, -PI, PI)
	var steer: float = clampf(err * p("bot_k"), -1.0, 1.0)
	var sp: float = _vel.length()
	var want_hb: bool = absf(err) > p("bot_hb_angle") and sp > p("bot_hb_speed")
	if _hb and absf(err) > p("bot_hb_release"):
		want_hb = true
	var brake: float = 1.0 if (absf(err) > p("bot_brake_angle") and sp > p("bot_brake_speed")) or sp > _bot_speed_cap() else 0.0
	if want_hb != _hb:
		return {"do": "hold" if want_hb else "release", "v": Vector2(steer, brake)}
	return {"do": "axis", "v": Vector2(steer, brake)}


## Vitesse permise à l'approche de la porte : d'autant plus basse que la porte d'après demande un
## grand changement de cap (freinage anticipé sur la distance qui reste).
func _bot_speed_cap() -> float:
	if _gate + 1 >= _gates.size():
		return INF
	var g: PackedVector2Array = _gates[_gate]
	var g2: PackedVector2Array = _gates[_gate + 1]
	var mid: Vector2 = (g[0] + g[1]) * 0.5
	var nxt: Vector2 = (g2[0] + g2[1]) * 0.5
	var turn: float = absf(wrapf((nxt - mid).angle() - (mid - _pos).angle(), -PI, PI))
	var v_turn: float = lerpf(p("v_max"), p("bot_v_turn"), clampf(turn / (PI * 0.5), 0.0, 1.0))
	var dist: float = _pos.distance_to(mid)
	return sqrt(v_turn * v_turn + 2.0 * p("brake") * p("bot_brake_eff") * dist)


## Point visé : point d'approche devant la porte suivante, puis son centre, décalé vers la porte
## d'après quand on en approche.
func _bot_aim() -> Vector2:
	var g: PackedVector2Array = _gates[_gate]
	var mid: Vector2 = (g[0] + g[1]) * 0.5
	# Approche : d'abord un point devant la porte, pour la traverser d'équerre.
	var n: Vector2 = (g[1] - g[0]).normalized().orthogonal()
	var from: Vector2 = _pos
	if _gate > 0:
		from = (_gates[_gate - 1][0] + _gates[_gate - 1][1]) * 0.5
	if n.dot(mid - from) < 0.0:
		n = -n
	var pre: Vector2 = mid - n * p("bot_approach")
	var sharp: bool = absf(n.angle_to(mid - from)) > p("bot_pre_angle")
	if sharp and n.dot(_pos - pre) < 0.0 and _pos.distance_to(pre) > p("bot_pre_r"):
		return pre
	if _gate + 1 < _gates.size():
		var g2: PackedVector2Array = _gates[_gate + 1]
		var nxt: Vector2 = (g2[0] + g2[1]) * 0.5
		var d: float = _pos.distance_to(mid)
		var k: float = clampf(1.0 - d / p("bot_lookahead"), 0.0, p("bot_blend"))
		return mid.lerp(nxt, k)
	return mid


func bot_apply(w: Dictionary) -> void:
	var mode: String = String(w.get("do", ""))
	_axis = w.get("v", Vector2.ZERO) as Vector2
	if mode == "hold":
		_hb = true
	elif mode == "release":
		_hb = false


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	var pillars: Array[Vector2] = []
	for k: int in 4:
		var px: float = -_half.x + 3.0 + (_half.x * 2.0 - 6.0) * float(k) / 3.0
		pillars.append(Vector2(px, -_half.y - 0.6))
		pillars.append(Vector2(px, _half.y + 0.6))
	_deco = GarageSet.build(st, Vector3.ZERO, Vector2(_half.x * 2.0 + 2.0, _half.y * 2.0 + 2.0), pillars, -_half.y - 1.4)
	var r: Node3D = st.root
	# Bordure du circuit (murets bas à bandes), damier de départ, numéros de porte.
	for sz: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(_half.x * 2.0, 0.3, 0.2), Vector3(0, 0.15, sz * (_half.y + 0.1)), Stage3D.mat(GarageSet.HAZARD, 0.0, 0.6))
	for sx: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(0.2, 0.3, _half.y * 2.0), Vector3(sx * (_half.x + 0.1), 0.15, 0), Stage3D.mat(GarageSet.HAZARD, 0.0, 0.6))
	var last: PackedVector2Array = _gates[_gates.size() - 1]
	_checker(r, last)
	for cd: Dictionary in _cones:
		var p2: Vector2 = cd["p"] as Vector2
		cd["node"] = GarageSet.cone(r, Vector3(p2.x, 0.0, p2.y))
	for k2: int in _gates.size():
		var g: PackedVector2Array = _gates[k2]
		GarageSet.paint_line(r, g[0], g[1], 0.08, Color(1.0, 1.0, 1.0, 1.0) if k2 < _gates.size() - 1 else Palette.GOLD)
		var mid: Vector2 = (g[0] + g[1]) * 0.5
		var lbl: Label3D = Stage3D.text3d(r, str(k2 + 1), Vector3(mid.x, 0.03, mid.y), 480, Palette.IVORY)
		lbl.rotation.x = -PI * 0.5
		lbl.modulate.a = 0.6
	_car = GarageSet.car(Color("e86a1a"), Color("f4f0e8"))
	r.add_child(_car["node"] as Node3D)
	var num: Label3D = Stage3D.text3d(_car["node"] as Node3D, "7", Vector3(1.0, 1.31, 0), 360, Palette.INK, Palette.IVORY)
	num.rotation = Vector3(-PI * 0.5, 0, -PI * 0.5)
	# Flèche dorée au-dessus de la porte suivante.
	_arrow = Node3D.new()
	_arrow.scale = Vector3.ONE * 2.2
	r.add_child(_arrow)
	var gold: StandardMaterial3D = Stage3D.glow(Palette.GOLD, 1.5)
	Stage3D.cylinder(_arrow, 0.25, 0.7, Vector3(0, 0.6, 0), gold, 0.0).rotation.x = PI
	Stage3D.cylinder(_arrow, 0.08, 0.6, Vector3(0, 1.2, 0), gold)
	# Traces de pneus (réserve circulaire de marques sombres).
	var skid_m: StandardMaterial3D = Stage3D.mat(Color(0.03, 0.03, 0.03, 0.55), 0.0, 0.9)
	skid_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k3: int in int(p("skid_marks")):
		var mi: MeshInstance3D = Stage3D.box(r, Vector3(0.35, 0.003, 0.18), Vector3(0, -10.0, 0), skid_m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_skid.append(mi)
	# Le commissaire au drapeau, au bord du circuit près de l'arrivée.
	_marshal = GarageSet.mechanic()
	var mid_l: Vector2 = (last[0] + last[1]) * 0.5
	_marshal.position = Vector3(mid_l.x, 0.0, signf(mid_l.y) * (_half.y + 0.9) if mid_l.y != 0.0 else _half.y + 0.9)
	_marshal.rotation.y = PI if _marshal.position.z > 0.0 else 0.0
	r.add_child(_marshal)
	var flag: Node3D = Node3D.new()
	_marshal.add_child(flag)
	_flags.append(flag)
	Stage3D.cylinder(flag, 0.015, 0.8, Vector3(0, 0.4, 0), Stage3D.mat(Color("3a2010"), 0.0, 0.5))
	for i: int in 4:
		for j: int in 3:
			var col: Color = Palette.IVORY if (i + j) % 2 == 0 else Palette.INK
			Stage3D.box(flag, Vector3(0.12, 0.1, 0.01), Vector3(0.06 + 0.12 * float(i), 0.75 - 0.1 * float(j), 0), Stage3D.mat(col, 0.0, 0.8))
	st.look(Vector3(0.0, p("cam_h"), p("cam_back")), Vector3(0.0, 0.0, 0.6), 40.0)


## Damier peint au sol le long de la ligne d'arrivée.
func _checker(r: Node3D, g: PackedVector2Array) -> void:
	var d: Vector2 = g[1] - g[0]
	var n: int = int(d.length() / 0.4)
	var across: Vector2 = d.normalized().orthogonal() * 0.4
	for k: int in n:
		for row: int in 2:
			if (k + row) % 2 == 1:
				continue
			var c: Vector2 = g[0] + d * ((float(k) + 0.5) / float(n)) + across * (float(row) - 0.5)
			var sq: MeshInstance3D = Stage3D.box(r, Vector3(0.4, 0.005, 0.4), Vector3(c.x, 0.01, c.y), Stage3D.mat(Palette.IVORY, 0.0, 0.7))
			sq.rotation.y = -d.angle()


func _sync_3d(dt: float) -> void:
	if _car.is_empty():
		return
	var braking: bool = _hb or _controls().y > p("brake_stick")
	GarageSet.pose_car(_car, _pos - Vector2.from_angle(_head) * (GarageSet.CAR_LEN * 0.5 - GarageSet.REAR_OVERHANG), _head,
		_steer * 0.5, _roll, braking)
	GarageSet.animate(_deco, t)
	for cd: Dictionary in _cones:
		var n: Node3D = cd["node"] as Node3D
		if n == null:
			continue
		var p2: Vector2 = cd["p"] as Vector2
		n.position = Vector3(p2.x, 0.0, p2.y)
		if bool(cd["down"]):
			n.rotation = n.rotation.lerp(Vector3(PI * 0.5, float(cd["spin"]) * 3.0, 0.0), minf(1.0, dt * 10.0))
	if _gate < _gates.size():
		var g: PackedVector2Array = _gates[_gate]
		var mid: Vector2 = (g[0] + g[1]) * 0.5
		_arrow.visible = true
		_arrow.position = Vector3(mid.x, 0.4 + 0.15 * sin(t * 5.0), mid.y)
		_arrow.rotation.y = t * 2.0
	else:
		_arrow.visible = false
	if slip() > p("skid_slip") and not _skid.is_empty():
		var f: Vector2 = Vector2.from_angle(_head)
		for sv: float in [-0.75, 0.75]:
			var at: Vector2 = _pos - f * 1.35 + f.orthogonal() * sv
			var mk: MeshInstance3D = _skid[_skid_i]
			_skid_i = (_skid_i + 1) % _skid.size()
			mk.position = Vector3(at.x, 0.012, at.y)
			mk.rotation.y = -_head
	if _lap >= 0.0:
		_marshal.animate(&"cheer", t * 8.0, dt)
		_flags[0].rotation.z = 0.6 * sin(t * 14.0)
	else:
		_marshal.animate(&"idle", t * 2.0, dt)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	var run_t: float = _lap if _lap >= 0.0 else (t - _t0)
	text(Vector2(960.0, 105.0), tr("TRIAL_RALLY_STATUS") % [mini(_gate, _gates.size()), _gates.size()], UiKit.SIZE_BODY, Palette.IVORY)
	var col: Color = Palette.GOLD_LIGHT if run_t <= p("lap_par") * slow else Palette.IVORY
	text(Vector2(960.0, 160.0), "%.1f s" % run_t, UiKit.SIZE_H2, col)
	text(Vector2(960.0, 205.0), tr("TRIAL_RALLY_PAR") % p("lap_par"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	if _hb and _rest <= 0.0:
		text(Vector2(960.0, 980.0), tr("TRIAL_RALLY_HANDBRAKE"), UiKit.SIZE_H2, Palette.ROULETTE_RED)
	if _knocked + _walls > 0:
		text(Vector2(1640.0, 105.0), tr("TRIAL_RALLY_FAULTS") % (_knocked + _walls), UiKit.SIZE_SMALL, Palette.ROULETTE_RED, "body", 4)
