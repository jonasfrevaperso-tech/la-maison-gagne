class_name TrialEscape
extends ThrowTrial
## LA FUITE (Garage, 2.0) : sortie en trombe du parking, la police aux trousses, sur le boulevard
## de nuit. La voiture roule seule à fond ; gauche / droite change de file, maintenir freine. La
## police suit à vitesse constante : chaque dépassement réussi creuse l'écart, chaque accrochage
## fait perdre presque toute sa vitesse. Les voitures mettent leur clignotant avant de changer de
## file ; les camions sont longs et lents. Rattrapé : c'est fini.
## Repère : la voiture du joueur reste en z = 0 et regarde vers −z ; la route défile.
## Note = écart final avec la police (de `gap_lo` à `gap_hi`), rien si rattrapé.

const DT: float = 1.0 / 60.0
const LANE_W: float = 3.5
const CAR_HALF: Vector2 = Vector2(0.9, 2.2)
const TRUCK_LEN: float = 9.0
## Tolérance latérale des contacts (m) : un frôlement de rétroviseur en changeant de file passe.
const SIDE_SLACK: float = 0.45

var _lanes: int = 4
var _lane: int = 1
var _x: float = 0.0
var _v: float = 0.0
var _braking: bool = false
var _gap: float = 0.0
var _dist: float = 0.0
var _traffic: Array[Dictionary] = []  # lane, x, z, v, truck, sig (−1/0/1), sig_t, to, node, model
var _spawn_z: float = 0.0
var _free: int = -1
var _rows: int = 0
var _crashes: int = 0
var _invuln: float = 0.0
var _t0: float = 0.0
var _rest: float = 0.0
var _ended: bool = false
var _acc: float = 0.0
var _caught: bool = false
var _changes: int = 0
var _me: Dictionary = {}
var _roll: float = 0.0
var _dashes: Array[Node3D] = []
var _posts: Array[Node3D] = []
var _police: Dictionary = {}
var _beacons: Array[StandardMaterial3D] = []
var _siren_cd: float = 0.0


func begin() -> void:
	_lanes = pi("lanes")
	_lane = rng.randi_range(1, _lanes - 2)
	_x = lane_x(_lane)
	_v = p("v_start")
	_gap = p("gap_start")
	_t0 = t
	_build_3d()
	# Première rangée : la file du départ est occupée (il faut doubler tout de suite).
	_free = _lane + (1 if _lane + 1 < _lanes else -1)
	_spawn_z = -p("spawn_near")
	while _spawn_z > -p("spawn_far"):
		_spawn_row()


func lane_x(k: int) -> float:
	return (float(k) - float(_lanes - 1) * 0.5) * LANE_W


# --------------------------------------------------------------------------- circulation


## Une rangée de circulation à `_spawn_z` : deux puis trois véhicules, jamais toutes les files
## bouchées ; la file laissée libre est la voisine de celle de la rangée précédente (un passage
## existe toujours, mais il faut zigzaguer : rester dans sa file ne paie pas). Chaque file a sa
## vitesse (lente à droite, rapide à gauche) : deux voitures
## d'une même file ne se rattrapent pas, les barrages ne se forment pas au hasard des tirages.
## Les camions ne roulent que dans la file de droite.
func _spawn_row() -> void:
	var free: int = rng.randi_range(0, _lanes - 1)
	if _free >= 0:
		var step: int = -1 if rng.randf() < 0.5 else 1
		free = _free + (step if _free + step >= 0 and _free + step < _lanes else -step)
	_free = free
	# Véhicules sur les files autres que le passage, dans un ordre tiré au sort.
	var lanes: Array[int] = []
	for k: int in _lanes:
		if k != free:
			lanes.append(k)
	for i: int in range(lanes.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = lanes[i]
		lanes[i] = lanes[j]
		lanes[j] = tmp
	_rows += 1
	var count: int = 3 if _rows % 2 == 0 else 2  # rangées régulières : deux, puis trois véhicules
	if _traffic.is_empty() and lanes.has(_lane):
		lanes.erase(_lane)
		lanes.push_front(_lane)
	for lane: int in lanes.slice(0, mini(count, lanes.size())):
		var truck: bool = lane == _lanes - 1 and rng.randf() < p("truck_p")
		_add_vehicle(lane, _spawn_z - rng.randf_range(0.0, 6.0), _cruise(lane, truck), truck)
	_spawn_z -= rng.randf_range(p("row_min"), p("row_max"))


## Vitesse de croisière d'un véhicule dans la file `lane` (de `car_v_max` à gauche à
## `car_v_min` à droite ; camions plus lents), à `lane_jitter` près.
func _cruise(lane: int, truck: bool) -> float:
	var u: float = float(lane) / float(maxi(_lanes - 1, 1))
	var base: float = lerpf(p("truck_v_max"), p("truck_v_min"), u) if truck else lerpf(p("car_v_max"), p("car_v_min"), u)
	return base + rng.randf_range(-p("lane_jitter"), p("lane_jitter"))


func _add_vehicle(lane: int, z: float, v: float, truck: bool) -> void:
	var d: Dictionary = {"lane": lane, "x": lane_x(lane), "z": z, "v": v, "cruise": v, "truck": truck, "sig": 0, "sig_t": 0.0, "to": lane,
		"node": null, "model": {}}
	if stage != null:
		d["model"] = _truck_model() if truck else GarageSet.car(GarageSet.CAR_COLORS[rng.randi_range(0, GarageSet.CAR_COLORS.size() - 1)])
		var n: Node3D = (d["model"] as Dictionary)["node"] as Node3D
		stage.root.add_child(n)
		d["node"] = n
	_traffic.append(d)


func _half_len(d: Dictionary) -> float:
	return TRUCK_LEN * 0.5 if bool(d["truck"]) else CAR_HALF.y


## Vrai si la file `lane` est libre entre `z0` et `z1` (z vers l'arrière positif), en tenant compte
## des véhicules qui y arrivent ou en partent.
func lane_free(lane: int, z0: float, z1: float, skip: Dictionary = {}) -> bool:
	var x: float = lane_x(lane)
	for d: Dictionary in _traffic:
		if d == skip:
			continue
		if absf(float(d["x"]) - x) > LANE_W * 0.8 and int(d["to"]) != lane:
			continue
		var hl: float = _half_len(d)
		if float(d["z"]) + hl > z0 and float(d["z"]) - hl < z1:
			return false
	return true


func _traffic_step() -> void:
	var rel_v: float = _v
	for d: Dictionary in _traffic:
		# Clignotant, puis changement de file s'il y a la place.
		if int(d["sig"]) == 0 and int(d["to"]) == int(d["lane"]) and rng.randf() < p("signal_rate") * DT and not bool(d["truck"]):
			var dir: int = -1 if rng.randf() < 0.5 else 1
			var tgt: int = int(d["lane"]) + dir
			if tgt >= 0 and tgt < _lanes:
				d["sig"] = dir
				d["sig_t"] = p("signal_seconds")
		if int(d["sig"]) != 0:
			d["sig_t"] = float(d["sig_t"]) - DT
			if float(d["sig_t"]) <= 0.0:
				var tgt2: int = int(d["lane"]) + int(d["sig"])
				var z: float = float(d["z"])
				if lane_free(tgt2, z - 8.0, z + 8.0, d) and not _player_in(tgt2, z - 7.0, z + 7.0):
					d["to"] = tgt2
					d["cruise"] = _cruise(tgt2, false)
				d["sig"] = 0
		var tx: float = lane_x(int(d["to"]))
		d["x"] = move_toward(float(d["x"]), tx, p("traffic_lateral") * DT)
		if absf(float(d["x"]) - tx) < 0.01:
			d["lane"] = d["to"]
		# Les véhicules ralentissent derrière un plus lent de leur file.
		var ahead_v: float = float(d["cruise"])
		for o: Dictionary in _traffic:
			if o != d and int(o["lane"]) == int(d["lane"]) and float(o["z"]) < float(d["z"]) and float(d["z"]) - float(o["z"]) < 14.0:
				ahead_v = minf(ahead_v, float(o["v"]))
		d["v"] = move_toward(float(d["v"]), ahead_v, 6.0 * DT)
		d["z"] = float(d["z"]) + (rel_v - float(d["v"])) * DT
	var keep: Array[Dictionary] = []
	for d2: Dictionary in _traffic:
		if float(d2["z"]) > p("despawn_back"):
			if d2["node"] != null:
				(d2["node"] as Node3D).queue_free()
			continue
		keep.append(d2)
	_traffic = keep
	_spawn_z += rel_v * DT
	while _spawn_z > -p("spawn_far"):
		_spawn_row()


func _player_in(lane: int, z0: float, z1: float) -> bool:
	return absf(_x - lane_x(lane)) < LANE_W * 0.8 and CAR_HALF.y > z0 and -CAR_HALF.y < z1


## Vrai si la voiture du joueur touche le véhicule `d` (avec `SIDE_SLACK` sur les côtés).
func touches(d: Dictionary, px: float) -> bool:
	return absf(float(d["x"]) - px) < CAR_HALF.x * 2.0 - SIDE_SLACK and absf(float(d["z"])) < _half_len(d) + CAR_HALF.y - 0.1


# --------------------------------------------------------------------------- jeu


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_ended = true
			finish(quality())
		return
	_acc += dt
	while _acc >= DT and _rest <= 0.0:
		_acc -= DT
		_step()
	_siren_cd -= dt
	if _gap < p("siren_gap") and _siren_cd <= 0.0:
		AudioBus.play("decor_horn", 1.6, -16.0)
		_siren_cd = 0.7
	if _rest <= 0.0 and t - _t0 >= p("run_seconds") * slow:
		var q: float = quality()
		pop(Vector2(960.0, 300.0), q, "TRIAL_ESCAPE_CLEAR" if q > 0.0 else "TRIAL_ESCAPE_CLOSE")
		AudioBus.play("chime" if q > 0.0 else "lose_soft", 1.0 + 0.3 * q, -5.0)
		_rest = p("rest_seconds") * slow


func _step() -> void:
	var vmax: float = p("v_max")
	if _braking:
		_v = move_toward(_v, p("v_min"), p("brake") * DT)
	else:
		_v = move_toward(_v, vmax, p("accel") * DT)
	_x = move_toward(_x, lane_x(_lane), p("lateral") * DT)
	_dist += _v * DT
	_roll += _v * DT / GarageSet.WHEEL_R
	_gap += (_v - p("police_v")) * DT
	_invuln = maxf(0.0, _invuln - DT)
	_traffic_step()
	if _invuln <= 0.0:
		for d: Dictionary in _traffic:
			if touches(d, _x):
				_crash(d)
				break
	if _gap <= 0.0:
		_caught = true
		_gap = 0.0
		pop(Vector2(960.0, 300.0), 0.0, "TRIAL_ESCAPE_CAUGHT")
		AudioBus.play("lose_soft", 0.8, -3.0)
		_rest = p("rest_seconds") * slow


func _crash(d: Dictionary) -> void:
	_crashes += 1
	_v *= p("crash_keep")
	_gap -= p("crash_gap")  # le temps de reprendre ses esprits : la police se rapproche
	_invuln = p("invuln_seconds")
	d["v"] = float(d["v"]) * 0.7
	d["z"] = float(d["z"]) - 1.5 * signf(-float(d["z"]) + 0.001)
	AudioBus.play("decor_bump", 0.8, 0.0)
	AudioBus.play("shatter", 1.2, -10.0)
	pop(Vector2(960.0, 420.0), 0.0, "TRIAL_ESCAPE_CRASH")


func quality() -> float:
	if _caught:
		return 0.0
	return clampf((_gap - p("gap_lo")) / (p("gap_hi") - p("gap_lo")), 0.0, 1.0)


func _change(dir: int) -> void:
	if _rest > 0.0 or _ended:
		return
	var tgt: int = clampi(_lane + dir, 0, _lanes - 1)
	if tgt != _lane:
		_lane = tgt
		_changes += 1
		AudioBus.play("whoosh", 1.4, -12.0)


func handle(event: InputEvent) -> bool:
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		_change(d.x)
		return true
	if d.y > 0 or confirm_pressed(event):
		_braking = true
		return true
	if confirm_released(event) or GameInput.released(event, &"ui_down"):
		_braking = false
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mouse:
		return direct_input(event)
	return false


## Au doigt (et à la souris) : toucher le tiers gauche / droit change de file ; maintenir le
## milieu freine.
func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return true
	if not mb.pressed:
		_braking = false
		return true
	if mb.position.x < 640.0:
		_change(-1)
	elif mb.position.x > 1280.0:
		_change(1)
	else:
		_braking = true
	return true


func journal() -> Dictionary:
	return {"gap": snappedf(_gap, 0.1), "crashes": _crashes, "lane_changes": _changes, "caught": _caught}


# --------------------------------------------------------------------------- bot


## Pilote : pour chaque file (la sienne et les voisines, en comptant la file d'après si l'on peut
## y passer), distance libre devant ; il change de file si une voisine est nettement plus dégagée
## et que le passage est libre (y compris pour ceux qui y arrivent), sinon il freine quand
## l'obstacle devant est trop près.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0:
		return {"do": "release"} if _braking else {"do": ""}
	var here: float = _free_ahead(_lane)
	var best: int = _lane
	var best_free: float = here
	for dir: int in [-1, 1]:
		var tgt: int = _lane + dir
		if tgt < 0 or tgt >= _lanes or absf(_x - lane_x(_lane)) > 0.3:
			continue
		if not _can_merge(tgt):
			continue
		var f: float = _free_ahead(tgt)
		var beyond: int = tgt + dir  # une file plus loin, si l'on peut y passer ensuite
		if beyond >= 0 and beyond < _lanes and f > p("bot_pass_room"):
			f = maxf(f, _free_ahead(beyond) * p("bot_beyond_k"))
		if f > best_free + p("bot_gain_m"):
			best_free = f
			best = tgt
	if best != _lane and here < p("bot_look"):
		return {"do": "dir", "dir": Vector2i(best - _lane, 0)}
	var want_brake: bool = _must_brake(_lane) and best == _lane
	if want_brake != _braking:
		return {"do": "hold" if want_brake else "release"}
	return {"do": ""}


## Valeur d'une file pour le pilote : distance libre devant, allongée selon la vitesse de la
## voiture devant par rapport à la vitesse de pointe (une file rapide vaut mieux).
func _free_ahead(lane: int) -> float:
	var x: float = lane_x(lane)
	var best: float = p("bot_look") * 2.0
	for d: Dictionary in _traffic:
		if absf(float(d["x"]) - x) > LANE_W * 0.7 and int(d["to"]) != lane:
			continue
		var gap: float = -float(d["z"]) - _half_len(d) - CAR_HALF.y
		if gap < -CAR_HALF.y * 2.0:
			continue
		var closing: float = maxf(p("v_max") - float(d["v"]), 0.1)
		best = minf(best, maxf(gap, 0.0) * (1.0 + p("bot_rel_k") * float(d["v"]) / closing))
	return best


## Vrai si le pilote peut se rabattre dans la file `lane` : personne à hauteur, assez de place
## pour freiner derrière celui de devant, et celui de derrière met au moins `bot_rear_t` s à
## rattraper (plus une marge `bot_rear_m`).
func _can_merge(lane: int) -> bool:
	if _must_brake(lane):
		return false
	var x: float = lane_x(lane)
	for d: Dictionary in _traffic:
		if absf(float(d["x"]) - x) > LANE_W * 0.8 and int(d["to"]) != lane:
			continue
		var z: float = float(d["z"])
		var hl: float = _half_len(d)
		if absf(z) < hl + CAR_HALF.y + 0.5:
			return false
		if z > 0.0:
			var room: float = z - hl - CAR_HALF.y
			if room < p("bot_rear_m") + maxf(float(d["v"]) - _v, 0.0) * p("bot_rear_t"):
				return false
	return true


## Vrai si, dans la file `lane`, un véhicule devant est plus près que la distance qu'il faut
## pour retomber à sa vitesse (freinage `brake`), marge `bot_brake_margin` comprise.
func _must_brake(lane: int) -> bool:
	var x: float = lane_x(lane)
	for d: Dictionary in _traffic:
		if absf(float(d["x"]) - x) > LANE_W * 0.7 and int(d["to"]) != lane:
			continue
		var gap: float = -float(d["z"]) - _half_len(d) - CAR_HALF.y
		if gap < -CAR_HALF.y * 2.0:
			continue
		var va: float = float(d["v"])
		var need: float = maxf(_v * _v - va * va, 0.0) / (2.0 * p("brake")) * p("bot_brake_k") + p("bot_brake_margin")
		if gap < need:
			return true
	return false


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"dir":
			_change((w.get("dir", Vector2i.ZERO) as Vector2i).x)
		"hold":
			_braking = true
		"release":
			_braking = false


# --------------------------------------------------------------------------- décor 3D


func _truck_model() -> Dictionary:
	var n: Node3D = Node3D.new()
	var cab: StandardMaterial3D = Stage3D.mat(Color("2a4a7a"), 0.4, 0.4)
	Stage3D.box(n, Vector3(2.2, 2.2, 2.0), Vector3(0, 1.4, -TRUCK_LEN * 0.5 + 1.0), cab)
	Stage3D.box(n, Vector3(2.0, 0.6, 0.05), Vector3(0, 1.9, -TRUCK_LEN * 0.5 - 0.01), Stage3D.mat(Color(0.12, 0.18, 0.24), 0.6, 0.05))
	Stage3D.box(n, Vector3(2.4, 2.8, TRUCK_LEN - 2.2), Vector3(0, 1.8, 1.1), Stage3D.mat(Color("d8d0c0"), 0.0, 0.7))
	var band: Label3D = Stage3D.text3d(n, "TRANSPORTS DU CASINO", Vector3(1.21, 2.0, 1.1), 110, Palette.ROULETTE_RED, Palette.IVORY)
	band.rotation.y = PI * 0.5
	var brake: StandardMaterial3D = Stage3D.glow(Color(0.9, 0.05, 0.05), 1.0)
	for sx: float in [-1.0, 1.0]:
		Stage3D.box(n, Vector3(0.25, 0.2, 0.05), Vector3(sx * 1.0, 0.6, TRUCK_LEN * 0.5 + 0.01), brake)
	for k: int in 3:
		for sx2: float in [-1.0, 1.0]:
			var wheel_at: Vector3 = Vector3(sx2 * 1.05, 0.5, -3.0 + 2.6 * float(k) + (0.6 if k > 0 else 0.0))
			var w: MeshInstance3D = Stage3D.cylinder(n, 0.5, 0.3, wheel_at, Stage3D.mat(Color("141414"), 0.0, 0.85))
			w.rotation.z = PI * 0.5
	return {"node": n, "steer": [] as Array[Node3D], "spin": [] as Array[Node3D], "brake": brake, "reverse": brake}


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	var r: Node3D = st.root
	st.env.background_color = Color("070a14")
	st.env.ambient_light_color = Color(0.5, 0.55, 0.8)
	st.env.ambient_light_energy = 0.3
	st.key.light_energy = 0.2
	var road_w: float = float(_lanes) * LANE_W
	Stage3D.box(r, Vector3(road_w + 1.0, 0.05, 300.0), Vector3(0, -0.03, -120.0), Stage3D.mat(Color("1a1a1e"), 0.0, 0.75))
	for sx: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(4.0, 0.2, 300.0), Vector3(sx * (road_w * 0.5 + 2.5), 0.05, -120.0), Stage3D.mat(Color("4a4844"), 0.0, 0.9))
		Stage3D.box(r, Vector3(0.12, 0.5, 300.0), Vector3(sx * (road_w * 0.5 + 0.4), 0.4, -120.0), Stage3D.mat(Color("b8bcc0"), 0.8, 0.3))
		Stage3D.box(r, Vector3(0.15, 0.01, 300.0), Vector3(sx * (road_w * 0.5 - 0.2), 0.0, -120.0), Stage3D.mat(Color("e8e0c8"), 0.0, 0.6))
	for k: int in _lanes - 1:
		for j: int in int(p("dashes")):
			var dash: MeshInstance3D = Stage3D.box(r, Vector3(0.14, 0.01, 3.0), Vector3(lane_x(k) + LANE_W * 0.5, 0.0, -9.0 * float(j)),
				Stage3D.mat(Color("e8e0c8"), 0.0, 0.6))
			dash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_dashes.append(dash)
	# Réverbères des deux côtés (lumière orangée de sodium), recyclés en défilant.
	for k2: int in int(p("posts")):
		var post: Node3D = Node3D.new()
		var side: float = -1.0 if k2 % 2 == 0 else 1.0
		post.position = Vector3(side * (road_w * 0.5 + 1.6), 0.0, -18.0 * float(k2 / 2))
		r.add_child(post)
		Stage3D.cylinder(post, 0.1, 7.0, Vector3(0, 3.5, 0), Stage3D.mat(Color("3a3a3a"), 0.6, 0.4))
		Stage3D.box(post, Vector3(1.6, 0.1, 0.1), Vector3(-side * 0.8, 7.0, 0), Stage3D.mat(Color("3a3a3a"), 0.6, 0.4))
		Stage3D.box(post, Vector3(0.5, 0.12, 0.25), Vector3(-side * 1.5, 6.9, 0), Stage3D.glow(Color(1.0, 0.65, 0.3), 3.0))
		if k2 < 6:
			Stage3D.omni(post, Color(1.0, 0.65, 0.3), 2.2, Vector3(-side * 1.5, 6.0, 0), 14.0)
		_posts.append(post)
	# Ville au loin : immeubles sombres aux fenêtres allumées, enseigne du casino.
	var city: RandomNumberGenerator = RandomNumberGenerator.new()
	city.seed = 11  # décor fixe, hors des flux de jeu
	for k3: int in 18:
		var bx: float = -60.0 + 7.0 * float(k3)
		if absf(bx) < road_w:
			continue
		var bh: float = city.randf_range(10.0, 34.0)
		Stage3D.box(r, Vector3(6.0, bh, 6.0), Vector3(bx, bh * 0.5, -150.0 - city.randf_range(0.0, 20.0)), Stage3D.mat(Color("141a2a"), 0.0, 0.9))
		for wy: int in int(bh / 4.0):
			if city.randf() < 0.5:
				Stage3D.box(r, Vector3(1.2, 1.4, 0.1), Vector3(bx + city.randf_range(-2.0, 2.0), 2.0 + 4.0 * float(wy), -146.9),
					Stage3D.glow(RooftopSet.WINDOW, 1.2))
	var sign_l: Label3D = Stage3D.text3d(r, "LA MAISON GAGNE", Vector3(0, 30.0, -145.0), 2600, Palette.MAGENTA, Palette.INK)
	sign_l.modulate = Palette.MAGENTA * 1.6
	_me = GarageSet.car(GarageSet.CAR_COLORS[0])
	r.add_child(_me["node"] as Node3D)
	_police = GarageSet.car(Color("141418"), Color("f4f0e8"))
	r.add_child(_police["node"] as Node3D)
	for k4: int in 2:
		var bm: StandardMaterial3D = Stage3D.glow(Color(0.9, 0.1, 0.1) if k4 == 0 else Color(0.2, 0.4, 1.0), 4.0)
		Stage3D.box(_police["node"] as Node3D, Vector3(0.2, 0.14, 0.3), Vector3(1.2, 1.36, -0.25 + 0.5 * float(k4)), bm)
		_beacons.append(bm)
	st.look(Vector3(0.0, p("cam_h"), p("cam_back")), Vector3(0.0, 0.8, -14.0), 50.0)


func _sync_3d(_dt: float) -> void:
	if _me.is_empty():
		return
	var head: float = -PI * 0.5
	var steer: float = clampf((lane_x(_lane) - _x) * 0.15, -0.3, 0.3)
	GarageSet.pose_car(_me, Vector2(_x, CAR_HALF.y - GarageSet.REAR_OVERHANG), head, steer, _roll, _braking)
	(_me["node"] as Node3D).rotation.z = 0.0
	(_me["node"] as Node3D).rotation.x = -0.03 if _braking else 0.0
	var scroll: float = fmod(_dist, 9.0)
	for k: int in _dashes.size():
		var j: int = k % int(p("dashes"))
		_dashes[k].position.z = -9.0 * float(j) + scroll + 18.0
	var post_scroll: float = fmod(_dist, 18.0)
	for k2: int in _posts.size():
		_posts[k2].position.z = -18.0 * float(k2 / 2) + post_scroll + 18.0
	for d: Dictionary in _traffic:
		var md: Dictionary = d["model"] as Dictionary
		if md.is_empty():
			continue
		var n: Node3D = md["node"] as Node3D
		if bool(d["truck"]):
			n.position = Vector3(float(d["x"]), 0.0, float(d["z"]))
		else:
			GarageSet.pose_car(md, Vector2(float(d["x"]), float(d["z"]) + CAR_HALF.y - GarageSet.REAR_OVERHANG), head, 0.0, 0.0, false)
		# Clignotant : le feu arrière du côté choisi clignote en orange.
		var blink: bool = int(d["sig"]) != 0 and fmod(t, 0.5) < 0.25
		(md["brake"] as StandardMaterial3D).emission = Color(1.0, 0.6, 0.1) if blink else Color(0.9, 0.05, 0.05)
		(md["brake"] as StandardMaterial3D).emission_energy_multiplier = 4.0 if blink else 0.8
	var pz: float = clampf(_gap, 0.0, 60.0) + CAR_HALF.y
	GarageSet.pose_car(_police, Vector2(lane_x(clampi(_lane, 0, _lanes - 1)) * 0.6, pz), head, 0.0, _roll)
	(_police["node"] as Node3D).visible = _gap < 40.0
	var ph: bool = fmod(t, 0.4) < 0.2
	_beacons[0].emission_energy_multiplier = 6.0 if ph else 0.5
	_beacons[1].emission_energy_multiplier = 0.5 if ph else 6.0


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	# Rétroviseur : distance de la police, en rouge quand elle se rapproche.
	var mirror: Rect2 = Rect2(760.0, 40.0, 400.0, 90.0)
	draw_rect(mirror, Color(Palette.INK, 0.9))
	draw_rect(mirror, Palette.GOLD_DARK, false, 3.0)
	var u: float = clampf(_gap / p("gap_hi"), 0.0, 1.0)
	var col: Color = Palette.ROULETTE_RED.lerp(Palette.EMERALD, clampf((_gap - p("gap_lo")) / (p("gap_hi") - p("gap_lo")), 0.0, 1.0))
	draw_rect(Rect2(mirror.position + Vector2(20.0, 54.0), Vector2((mirror.size.x - 40.0) * u, 14.0)), col)
	var ph: bool = fmod(t, 0.4) < 0.2 and _gap < p("siren_gap")
	draw_circle(mirror.position + Vector2(20.0 + (mirror.size.x - 40.0) * 0.0, 61.0), 9.0, Palette.ROULETTE_RED if ph else Palette.CHIPS_BLUE)
	var gap_at: Vector2 = mirror.position + Vector2(mirror.size.x * 0.5, 32.0)
	text(gap_at, tr("TRIAL_ESCAPE_GAP") % int(round(_gap)), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	var left: float = clampf(1.0 - (t - _t0) / (p("run_seconds") * slow), 0.0, 1.0)
	var bar: Rect2 = Rect2(660.0, 1000.0, 600.0, 16.0)
	draw_rect(bar, Color(Palette.INK, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
	text(Vector2(1700.0, 980.0), "%d km/h" % int(round(_v * 3.6)), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	if _crashes > 0:
		text(Vector2(220.0, 980.0), tr("TRIAL_ESCAPE_CRASHES") % _crashes, UiKit.SIZE_SMALL, Palette.ROULETTE_RED, "body", 4)
