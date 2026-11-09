class_name TrialTorque
extends ThrowTrial
## LA CLÉ DYNAMOMÉTRIQUE (Garage, 2.0) : remonter les roues d'une voiture du client. Choisir un
## écrou (gauche / droite tourne autour du moyeu), maintenir pour serrer, relâcher quand l'aiguille
## du couple est dans la zone verte. L'écrou file d'abord sans résistance, puis se bloque et le
## couple monte de plus en plus vite. Trop serré : le filetage foire. Pas assez : on peut reprendre.
## Les écrous rouillés accrochent : l'aiguille fait un faux pic — qui lâche là n'a rien serré.
## Règle du métier : serrer en étoile, jamais deux écrous voisins de suite (sinon la roue se voile).
## Note = moyenne des roues (qualité moyenne des écrous, moins les voilages).

const RUN_LEVEL: float = 0.1  # couple affiché pendant que l'écrou file
const HUB: Vector2 = Vector2(1060.0, 560.0)  # centre de la roue à l'écran
const NUT_R_PX: float = 150.0

var _wheel: int = 0
var _nuts: Array[Dictionary] = []
var _sel: int = 0
var _holding: bool = false
var _last_started: int = -1
var _warps: int = 0
var _wheel_t0: float = 0.0
var _rest: float = 0.0
var _marks: Array[float] = []
var _ended: bool = false
var _total_warps: int = 0
var _stripped: int = 0
var _ratchet_cd: float = 0.0
var _hub: Node3D = null
var _nut_nodes: Array[Node3D] = []
var _nut_mats: Array[StandardMaterial3D] = []
var _wrench: Node3D = null
var _ring: MeshInstance3D = null
var _wheel_node: Node3D = null
var _deco: Dictionary = {}
var _bot_target: float = 0.0


func begin() -> void:
	_build_3d()
	_new_wheel()


func _wheels() -> int:
	return pi("wheels")


func _count() -> int:
	return int(pk("nuts", _wheel))


func _new_wheel() -> void:
	_nuts.clear()
	for k: int in _count():
		var rusty: bool = rng.randf() < p("rusty_p")
		_nuts.append({"torque": 0.0, "held": 0.0, "seat": rng.randf_range(p("seat_min"), p("seat_max")),
			"rise": rng.randf_range(p("rise_min"), p("rise_max")), "rusty": rusty,
			"spike_at": rng.randf_range(p("spike_min"), p("spike_max")), "spike_t": 0.0, "spiked": false, "stripped": false})
	_sel = 0
	_holding = false
	_last_started = -1
	_warps = 0
	_wheel_t0 = t
	_bot_target = rng.randf_range(-1.0, 1.0)
	_sync_wheel()


# --------------------------------------------------------------------------- serrage


## Couple de base après `held` secondes de serrage : l'écrou file (couple faible) jusqu'à
## l'assise, puis le couple monte de plus en plus vite.
static func torque_at(held: float, seat: float, rise: float, accel: float) -> float:
	if held < seat:
		return RUN_LEVEL * held / maxf(seat, 0.001)
	var u: float = held - seat
	return RUN_LEVEL + rise * u + accel * u * u


func _torque_of(n: Dictionary) -> float:
	return torque_at(float(n["held"]), float(n["seat"]), float(n["rise"]), p("rise_accel"))


## Couple lu sur le cadran (le faux pic d'un écrou rouillé en plus).
func reading(n: Dictionary) -> float:
	var v: float = float(n["torque"])
	if float(n["spike_t"]) > 0.0:
		v += p("spike") * float(n["spike_t"]) / p("spike_seconds")
	return v


## Qualité d'un écrou : plein dans la zone verte ; moins en dessous (rien sous `under_zero`) et
## au-dessus ; filetage foiré = rien.
func nut_quality(n: Dictionary) -> float:
	if bool(n["stripped"]):
		return 0.0
	var v: float = float(n["torque"])
	var lo: float = p("zone_lo")
	var hi: float = p("zone_hi")
	if v < lo:
		return clampf((v - p("under_zero")) / (lo - p("under_zero")), 0.0, 1.0)
	if v <= hi:
		return 1.0
	return lerpf(1.0, p("over_q"), clampf((v - hi) / (p("strip") - hi), 0.0, 1.0))


## Vrai si les écrous `a` et `b` sont voisins sur le moyeu.
func adjacent(a: int, b: int) -> bool:
	var n: int = _nuts.size()
	return absi(a - b) == 1 or absi(a - b) == n - 1


func _wheel_done() -> bool:
	for n: Dictionary in _nuts:
		if not bool(n["stripped"]) and float(n["torque"]) < p("zone_lo"):
			return false
	return true


func _start_hold() -> void:
	if _rest > 0.0 or _ended or _holding:
		return
	var n: Dictionary = _nuts[_sel]
	if bool(n["stripped"]):
		AudioBus.play("error", 1.0, -8.0)
		return
	if float(n["held"]) <= 0.0:  # premier serrage de cet écrou : la règle de l'étoile
		if _last_started >= 0 and adjacent(_last_started, _sel):
			_warps += 1
			_total_warps += 1
			pop(_nut_screen(_sel), 0.0, "TRIAL_TORQUE_WARP")
			AudioBus.play("decor_creak", 0.8, -6.0)
		_last_started = _sel
	_holding = true


func _stop_hold() -> void:
	if not _holding:
		return
	_holding = false
	var n: Dictionary = _nuts[_sel]
	n["spike_t"] = 0.0
	if bool(n["stripped"]):
		return
	var q: float = nut_quality(n)
	if float(n["torque"]) >= p("zone_lo"):
		AudioBus.play("decor_torque", 1.0 + 0.2 * q, -4.0)
		pop(_nut_screen(_sel), q, "TRIAL_TORQUE_TIGHT" if q >= 1.0 else "TRIAL_TORQUE_OVER")
	if _wheel_done():
		_end_wheel()


func _end_wheel() -> void:
	var qs: Array[float] = []
	for n: Dictionary in _nuts:
		qs.append(nut_quality(n))
	var q: float = clampf(ThrowTrial.mean(qs) - p("warp_cost") * float(_warps), 0.0, 1.0)
	_marks.append(q)
	pop(Vector2(960.0, 230.0), q, "TRIAL_TORQUE_WHEEL")
	AudioBus.play("chime" if q > 0.5 else "lose_soft", 1.0 + 0.3 * q, -5.0)
	_holding = false
	_rest = p("rest_seconds") * slow


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_wheel += 1
			if _wheel >= _wheels():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_wheel()
		return
	for n: Dictionary in _nuts:
		n["spike_t"] = maxf(0.0, float(n["spike_t"]) - dt)
	if _holding:
		var n2: Dictionary = _nuts[_sel]
		n2["held"] = float(n2["held"]) + dt / slow
		n2["torque"] = maxf(float(n2["torque"]), _torque_of(n2))
		if bool(n2["rusty"]) and not bool(n2["spiked"]) and float(n2["torque"]) >= float(n2["spike_at"]):
			n2["spiked"] = true
			n2["spike_t"] = p("spike_seconds")
			AudioBus.play("decor_creak", 1.3, -8.0)
		if float(n2["torque"]) >= p("strip"):
			n2["stripped"] = true
			_stripped += 1
			_holding = false
			pop(_nut_screen(_sel), 0.0, "TRIAL_TORQUE_STRIP")
			AudioBus.play("crack", 0.8, -2.0)
			if _wheel_done():
				_end_wheel()
				return
		_ratchet_cd -= dt
		if _ratchet_cd <= 0.0:
			AudioBus.play("decor_ratchet", 1.0 + 0.3 * float(n2["torque"]), -10.0)
			_ratchet_cd = 0.22
	if t - _wheel_t0 >= p("wheel_seconds") * slow:
		pop(Vector2(960.0, 300.0), 0.0, "TRIAL_TORQUE_LATE")
		_end_wheel()


func _move(step_k: int) -> void:
	if _holding or _rest > 0.0:
		return
	_sel = posmod(_sel + step_k, _nuts.size())
	AudioBus.play("tick", 1.2, -10.0)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mouse and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and not _holding:
		var k: int = _nut_under(mb.position)  # à la souris : on clique l'écrou à serrer
		if k >= 0:
			_sel = k
	var d: Vector2i = dir_pressed(event)
	if d.x != 0 or d.y != 0:
		_move(d.x if d.x != 0 else d.y)
		return true
	if confirm_pressed(event):
		_start_hold()
		return true
	if confirm_released(event):
		_stop_hold()
		return true
	return false


## Au doigt (et à la souris) : toucher un écrou le choisit et commence à le serrer.
func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return true
	if mb.pressed:
		var k: int = _nut_under(mb.position)
		if k >= 0 and not _holding:
			_sel = k
			_start_hold()
	else:
		_stop_hold()
	return true


func _nut_under(pos: Vector2) -> int:
	var best: int = -1
	var best_d: float = p("tap_radius")
	for k: int in _nuts.size():
		var d: float = pos.distance_to(_nut_screen(k))
		if d < best_d:
			best_d = d
			best = k
	return best


func journal() -> Dictionary:
	return {"wheels": _marks.size(), "warps": _total_warps, "stripped": _stripped}


# --------------------------------------------------------------------------- bot


## Bot : écrou suivant en étoile (le plus loin du dernier serré parmi ceux qui restent), il y
## tourne, serre, et relâche quand le couple de base atteindra la cible (un peu au-dessus du
## milieu de la zone) à l'image suivante ; il ignore les faux pics des écrous rouillés.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0:
		return {"do": "release"} if _holding else {"do": ""}
	if _holding:
		var n: Dictionary = _nuts[_sel]
		var target: float = lerpf(p("zone_lo"), p("zone_hi"), p("bot_aim") + p("bot_jitter") * _bot_target)
		var nxt: float = torque_at(float(n["held"]) + 1.0 / 60.0, float(n["seat"]), float(n["rise"]), p("rise_accel"))
		return {"do": "release"} if nxt >= target else {"do": "hold"}
	var want: int = _bot_next()
	if want < 0:
		return {"do": ""}
	if want != _sel:
		var fwd: int = posmod(want - _sel, _nuts.size())
		return {"do": "dir", "dir": Vector2i.RIGHT if fwd <= _nuts.size() - fwd else Vector2i.LEFT}
	return {"do": "hold"}


func _bot_next() -> int:
	var cur: Dictionary = _nuts[_sel]
	if float(cur["held"]) > 0.0 and not bool(cur["stripped"]) and float(cur["torque"]) < p("zone_lo"):
		return _sel  # repris : on finit cet écrou
	var best: int = -1
	var best_d: int = -1
	for k: int in _nuts.size():
		var n: Dictionary = _nuts[k]
		if bool(n["stripped"]) or float(n["torque"]) >= p("zone_lo"):
			continue
		var d: int = 0
		if _last_started >= 0:
			var a: int = absi(k - _last_started)
			d = mini(a, _nuts.size() - a)
		if d > best_d:
			best_d = d
			best = k
	return best


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"dir":
			var d: Vector2i = w.get("dir", Vector2i.ZERO) as Vector2i
			_move(d.x)
		"hold":
			_start_hold()
		"release":
			_stop_hold()


# --------------------------------------------------------------------------- décor 3D


func _nut_angle(k: int) -> float:
	return -PI * 0.5 + TAU * float(k) / float(maxi(_nuts.size(), 1))


func _nut_screen(k: int) -> Vector2:
	if stage == null:
		return HUB + Vector2.from_angle(_nut_angle(k)) * NUT_R_PX
	var n: Node3D = _nut_nodes[k] if k < _nut_nodes.size() else null
	return stage.project(n.global_position) if n != null and n.is_inside_tree() else HUB + Vector2.from_angle(_nut_angle(k)) * NUT_R_PX


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(0.0016, HUB, 1080.0, 40.0)
	var r: Node3D = st.root
	_deco = GarageSet.build(st, Vector3(0, -0.5, -1.5), Vector2(8.0, 6.0), [Vector2(-1.8, -2.6)], -3.2)
	st.env.ambient_light_energy = 0.4
	# Flanc de la voiture sur cric : aile bordeaux, passage de roue sombre, bas de caisse chromé.
	var paint: StandardMaterial3D = Stage3D.mat(GarageSet.CAR_COLORS[0], 0.55, 0.22)
	paint.clearcoat_enabled = true
	Stage3D.box(r, Vector3(2.8, 0.6, 0.3), Vector3(0, 0.62, -0.3), paint)
	Stage3D.box(r, Vector3(2.8, 0.06, 0.32), Vector3(0, 0.3, -0.29), Stage3D.mat(Color("e8ecf0"), 1.0, 0.12))
	Stage3D.box(r, Vector3(0.015, 0.5, 0.02), Vector3(0.75, 0.66, -0.14), Stage3D.mat(Color("2a0a0a"), 0.0, 0.6))  # portière
	Stage3D.box(r, Vector3(0.16, 0.035, 0.04), Vector3(0.95, 0.78, -0.13), Stage3D.mat(Color("e8ecf0"), 1.0, 0.12))  # poignée
	Stage3D.box(r, Vector3(1.6, 0.2, 0.05), Vector3(1.2, 1.05, -0.36), Stage3D.mat(Color(0.12, 0.18, 0.24), 0.6, 0.05))  # vitre
	var arch: MeshInstance3D = Stage3D.cylinder(r, 0.5, 0.31, Vector3(0, 0.08, -0.3), Stage3D.mat(Color("0a0a0a"), 0.0, 0.9))
	arch.rotation.x = PI * 0.5
	# Cric rouge sous le bas de caisse, à gauche de la roue.
	var jack: StandardMaterial3D = Stage3D.mat(Color("b82a1a"), 0.3, 0.5)
	Stage3D.box(r, Vector3(0.08, 0.2, 0.08), Vector3(-0.85, 0.17, -0.35), jack)
	Stage3D.box(r, Vector3(0.3, 0.05, 0.16), Vector3(-0.85, 0.05, -0.35), jack)
	Stage3D.box(r, Vector3(0.36, 0.06, 0.2), Vector3(-0.85, -0.47, -0.35), jack)
	Stage3D.box(r, Vector3(0.05, 0.5, 0.05), Vector3(-0.85, -0.2, -0.35), Stage3D.mat(Color("8a8a8a"), 0.8, 0.3))
	# Roue : pneu à flanc blanc, jante peinte, moyeu.
	_wheel_node = Node3D.new()
	r.add_child(_wheel_node)
	var tyre: MeshInstance3D = Stage3D.cylinder(_wheel_node, 0.4, 0.22, Vector3(0, 0, -0.05), Stage3D.mat(Color("141414"), 0.0, 0.85))
	tyre.rotation.x = PI * 0.5
	var ww: MeshInstance3D = Stage3D.cylinder(_wheel_node, 0.33, 0.01, Vector3(0, 0, 0.062), Stage3D.mat(Color("ece8dc"), 0.0, 0.6))
	ww.rotation.x = PI * 0.5
	var rim_m: StandardMaterial3D = Stage3D.mat(GarageSet.CAR_COLORS[0].darkened(0.2), 0.5, 0.3)
	var rim: MeshInstance3D = Stage3D.cylinder(_wheel_node, 0.27, 0.05, Vector3(0, 0, 0.07), rim_m)
	rim.rotation.x = PI * 0.5
	var hub: MeshInstance3D = Stage3D.cylinder(_wheel_node, 0.09, 0.08, Vector3(0, 0, 0.1), Stage3D.mat(Color("8a8a8a"), 0.9, 0.3))
	hub.rotation.x = PI * 0.5
	_hub = _wheel_node
	# Anneau lumineux de l'écrou choisi, clé dynamométrique (barre chromée, poignée, cadran).
	_ring = Stage3D.cylinder(r, 0.042, 0.004, Vector3.ZERO, Stage3D.glow(Palette.GOLD, 2.0))
	_ring.rotation.x = PI * 0.5
	_wrench = Node3D.new()
	r.add_child(_wrench)
	var chrome: StandardMaterial3D = Stage3D.mat(Color("d8dce0"), 1.0, 0.15)
	Stage3D.cylinder(_wrench, 0.03, 0.06, Vector3(0, 0, 0.03), chrome).rotation.x = PI * 0.5
	Stage3D.box(_wrench, Vector3(0.6, 0.035, 0.03), Vector3(0.33, 0, 0.07), chrome)
	Stage3D.box(_wrench, Vector3(0.2, 0.05, 0.045), Vector3(0.65, 0, 0.07), Stage3D.mat(Color("1a1a1a"), 0.0, 0.6))


func _sync_wheel() -> void:
	if stage == null:
		return
	for n0: Node3D in _nut_nodes:
		n0.queue_free()
	_nut_nodes.clear()
	_nut_mats.clear()
	for k: int in _nuts.size():
		var nn: Node3D = Node3D.new()
		var at: Vector2 = Vector2.from_angle(_nut_angle(k)) * 0.19
		nn.position = Vector3(at.x, -at.y, 0.1)
		_hub.add_child(nn)
		var rusty: bool = bool(_nuts[k]["rusty"])
		var m: StandardMaterial3D = Stage3D.mat(Color("7a4a2a") if rusty else Color("b8bcc0"), 0.4 if rusty else 0.9, 0.6 if rusty else 0.3)
		var hexa: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = 0.028
		cm.bottom_radius = 0.028
		cm.height = 0.04
		cm.radial_segments = 6
		hexa.mesh = cm
		hexa.material_override = m
		hexa.rotation.x = PI * 0.5
		nn.add_child(hexa)
		_nut_nodes.append(nn)
		_nut_mats.append(m)


func _sync_3d(dt: float) -> void:
	if _wrench == null:
		return
	GarageSet.animate(_deco, t)
	if _sel < _nut_nodes.size():
		var nn: Node3D = _nut_nodes[_sel]
		var at: Vector3 = nn.global_position if nn.is_inside_tree() else nn.position
		_ring.position = at + Vector3(0, 0, 0.025)
		_wrench.position = at + Vector3(0, 0, 0.02)
		var n: Dictionary = _nuts[_sel]
		_wrench.rotation.z = -0.6 - fmod(float(n["held"]) * 1.4, 0.9) if _holding else lerp_angle(_wrench.rotation.z, -0.6, minf(1.0, dt * 8.0))
	for k: int in mini(_nut_nodes.size(), _nuts.size()):
		var n2: Dictionary = _nuts[k]
		var col: Color = Color("7a4a2a") if bool(n2["rusty"]) else Color("b8bcc0")
		if bool(n2["stripped"]):
			col = Palette.ROULETTE_RED
		elif float(n2["torque"]) >= p("zone_lo"):
			col = col.lerp(Palette.EMERALD, 0.6)
		_nut_mats[k].albedo_color = col
		_nut_nodes[k].position.z = 0.1 + 0.03 * (1.0 - clampf(float(n2["torque"]) / p("zone_lo"), 0.0, 1.0))
		_nut_nodes[k].rotation.z = -float(n2["held"]) * 6.0


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	# Cadran du couple (en haut à gauche) : zone verte, zone de casse, aiguille.
	var c: Vector2 = Vector2(400.0, 470.0)
	var rad: float = 190.0
	var a0: float = PI * 0.8
	var span: float = PI * 1.4
	draw_circle(c, rad + 18.0, Color(Palette.INK, 0.92))
	draw_arc(c, rad, a0, a0 + span, 64, Palette.IVORY, 4.0)
	var lo_a: float = a0 + span * p("zone_lo") / p("strip")
	var hi_a: float = a0 + span * p("zone_hi") / p("strip")
	draw_arc(c, rad - 14.0, lo_a, hi_a, 24, Palette.EMERALD, 26.0)
	draw_arc(c, rad - 14.0, hi_a, a0 + span, 24, Color(Palette.ROULETTE_RED, 0.6), 26.0)
	for k: int in 11:
		var ta: float = a0 + span * float(k) / 10.0
		draw_line(c + Vector2.from_angle(ta) * (rad - 30.0), c + Vector2.from_angle(ta) * rad, Palette.IVORY, 3.0)
	var v: float = reading(_nuts[_sel]) if _sel < _nuts.size() else 0.0
	var na: float = a0 + span * clampf(v / p("strip"), 0.0, 1.05)
	draw_line(c, c + Vector2.from_angle(na) * (rad - 10.0), Palette.ROULETTE_RED, 6.0)
	draw_circle(c, 16.0, Palette.GOLD)
	text(c + Vector2(0.0, 95.0), tr("TRIAL_TORQUE_DIAL"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	# Pastilles des écrous de la roue (vert = serré, rouge = foiré), voilages, temps.
	var done: int = 0
	for n: Dictionary in _nuts:
		if float(n["torque"]) >= p("zone_lo") or bool(n["stripped"]):
			done += 1
	text(Vector2(960.0, 105.0), tr("TRIAL_TORQUE_STATUS") % [mini(_wheel + 1, _wheels()), _wheels(), done, _nuts.size()],
		UiKit.SIZE_BODY, Palette.IVORY)
	if _warps > 0:
		text(Vector2(960.0, 150.0), tr("TRIAL_TORQUE_WARPS") % _warps, UiKit.SIZE_SMALL, Palette.ROULETTE_RED, "body", 4)
	var left: float = clampf(1.0 - (t - _wheel_t0) / (p("wheel_seconds") * slow), 0.0, 1.0)
	var bar: Rect2 = Rect2(660.0, 1000.0, 600.0, 16.0)
	draw_rect(bar, Color(Palette.INK, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
	# Le dernier écrou commencé, entouré de pointillés (aide à respecter l'étoile).
	if _last_started >= 0 and _last_started < _nuts.size() and _rest <= 0.0:
		var lp: Vector2 = _nut_screen(_last_started)
		for k2: int in 12:
			var aa: float = TAU * float(k2) / 12.0 + t
			draw_circle(lp + Vector2.from_angle(aa) * 44.0, 3.0, Color(Palette.IVORY, 0.6))
