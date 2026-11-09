class_name TrialService
extends ThrowTrial
## LE SERVICE (Cuisines, 2.0) : le serveur traverse la salle du restaurant, plateau de six verres à
## bout de bras. Il avance seul ; le stick le déporte à gauche ou à droite pour éviter les
## chaises tirées, les chariots et les collègues qui traversent. Mais les verres glissent : un
## écart brusque les fait filer vers le bord, un écart doux les garde au centre. Un obstacle
## heurté renverse deux verres.
## Note = part des verres arrivés à table.

const LANE: float = 1.7
const GLASSES: int = 6
const TRAY_HALF: float = 0.3
const LOOK: float = 3.4
const HALL_W: float = 5.2
const TABLES: int = 9
const INSET: Rect2 = Rect2(1500.0, 760.0, 340.0, 200.0)

var _s: float = 0.0
var _len: float = 30.0
var _x: float = 0.0
var _vx: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_x: float = -1.0
var _glass_off: Array[float] = []
var _glass_v: Array[float] = []
var _glass_on: Array[bool] = []
var _obstacles: Array[Dictionary] = []  # {"s", "x0", "x1", "vx", "kind", "hit"}
var _bump: float = 0.0
var _ended: bool = false
var _arrived_t: float = -1.0
var _waiter: Figure3D = null
var _tray3: Node3D = null
var _glass3: Array[Node3D] = []
var _obs3: Array[Node3D] = []
var _cam_x: float = 0.0


func begin() -> void:
	_len = p("speed") * p("walk_seconds")
	for k: int in GLASSES:
		_glass_off.append((float(k % 3) - 1.0) * 0.12)
		_glass_v.append(0.0)
		_glass_on.append(true)
	_place_obstacles()
	_build_3d()


## Obstacles le long de l'allée : un passage libre est toujours assez large, jamais au même
## endroit deux fois de suite ; les collègues traversent à vitesse constante.
func _place_obstacles() -> void:
	var at: float = p("first_obstacle")
	var last_gap: float = 0.0
	var k: int = 0
	var rows: Array[Vector2] = []  # (abscisse du rang, centre du passage)
	while at < _len - 2.0:
		var gap: float = rng.randf_range(-LANE + 0.5, LANE - 0.5)
		if absf(gap - last_gap) < 0.9:
			gap = clampf(-signf(last_gap + 0.01) * rng.randf_range(0.6, LANE - 0.5), -LANE + 0.5, LANE - 0.5)
		var half: float = p("gap_width") * 0.5
		var kind: int = k % 3
		if gap - half > -LANE:
			_obstacles.append({"s": at, "x0": -LANE - 0.3, "x1": gap - half, "vx": 0.0, "kind": kind, "hit": false})
		if gap + half < LANE:
			_obstacles.append({"s": at, "x0": gap + half, "x1": LANE + 0.3, "vx": 0.0, "kind": (kind + 1) % 3, "hit": false})
		rows.append(Vector2(at, gap))
		last_gap = gap
		at += rng.randf_range(p("spacing_min"), p("spacing_max"))
		k += 1
	# Collègues qui traversent juste après certains rangs : au moment où le serveur arrive, ils
	# passent devant l'ancien passage, venus du côté opposé au suivant. Qui file tôt vers le passage
	# suivant les évite ; qui traîne dans l'ancien les percute.
	for r: int in rows.size() - 1:
		if r % 3 != 2:
			continue
		var gap_now: float = rows[r].y
		var gap_next: float = rows[r + 1].y
		var dir: float = signf(gap_next - gap_now)  # il vient du côté opposé au passage suivant
		var row_s: float = rows[r].x + p("crosser_ahead")
		var arrive: float = row_s / p("speed")
		var start_x: float = -dir * 2.6
		var t0: float = arrive - (gap_now - start_x) / (dir * p("crosser_speed"))
		_obstacles.append({"s": row_s, "x0": start_x - 0.25, "x1": start_x + 0.25, "vx": dir * p("crosser_speed"),
			"kind": 3, "hit": false, "t0": t0})


## Étendue latérale d'un obstacle à l'instant `when` (maintenant si négatif).
func _obs_x(o: Dictionary, when: float = -1.0) -> Vector2:
	if float(o["vx"]) == 0.0:
		return Vector2(float(o["x0"]), float(o["x1"]))
	var now: float = t if when < 0.0 else when
	var dt: float = maxf(0.0, now / slow - float(o.get("t0", 0.0)))
	var shift: float = float(o["vx"]) * dt
	return Vector2(float(o["x0"]) + shift, float(o["x1"]) + shift)


func _remaining() -> int:
	var n: int = 0
	for on: bool in _glass_on:
		n += 1 if on else 0
	return n


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _arrived_t >= 0.0:
		if t - _arrived_t >= p("bow_seconds"):
			_ended = true
			finish(float(_remaining()) / float(GLASSES))
		return
	var speed: float = p("speed") / slow * (p("bump_slow") if _bump > 0.0 else 1.0)
	_bump = maxf(0.0, _bump - dt)
	_s += speed * dt
	# Déport : le stick (ou la souris) donne la vitesse voulue ; le serveur y vient en souplesse.
	var v_des: float = clampf(held_vector().x + _axis.x, -1.0, 1.0) * p("lateral_speed")
	if mouse and _mouse_x >= 0.0:
		var want_x: float = clampf((_mouse_x - 960.0) / 520.0, -1.0, 1.0) * LANE
		v_des = clampf((want_x - _x) * 3.0, -p("lateral_speed"), p("lateral_speed"))
	var old_v: float = _vx
	_vx += (v_des - _vx) * minf(1.0, p("response") * dt)
	_x = clampf(_x + _vx * dt, -LANE, LANE)
	if absf(_x) >= LANE:
		_vx = 0.0
	# Verres : ils suivent le plateau par frottement ; une accélération brusque les fait filer.
	var acc: float = (_vx - old_v) / maxf(dt, 0.0001)
	for k: int in GLASSES:
		if not _glass_on[k]:
			continue
		if absf(acc) < p("static_accel") and absf(_glass_v[k] - _vx) < p("stick_rel"):
			_glass_v[k] = _vx  # adhérence : le verre suit le plateau
		else:
			var rel: float = _glass_v[k] - _vx
			_glass_v[k] -= signf(rel) * minf(absf(rel), p("friction") * dt)
			_glass_off[k] += (_glass_v[k] - _vx) * dt
		if absf(_glass_off[k]) > TRAY_HALF:
			_drop(k)
	_collide()
	if _s >= _len:
		_arrived_t = t
		pop(Vector2(960.0, 380.0), float(_remaining()) / float(GLASSES), "TRIAL_SERVICE_SERVED")
		AudioBus.play("chime", 1.0, -3.0)


func _drop(k: int) -> void:
	if not _glass_on[k]:
		return
	_glass_on[k] = false
	AudioBus.play("shatter", rng.randf_range(0.9, 1.2), -5.0)
	pop(Vector2(960.0 + _glass_off[k] * 600.0, 520.0), 0.0, "TRIAL_SERVICE_DROP")


func _collide() -> void:
	for o: Dictionary in _obstacles:
		if bool(o["hit"]):
			continue
		var ds: float = float(o["s"]) - _s
		if ds > 0.25 or ds < -0.25:
			continue
		var ox: Vector2 = _obs_x(o)
		if _x + p("body_half") > ox.x and _x - p("body_half") < ox.y:
			o["hit"] = true
			_bump = p("bump_seconds") * slow
			AudioBus.play("decor_topple", 1.0, -3.0)
			var lost: int = 0
			for k: int in GLASSES:
				if _glass_on[k] and lost < pi("bump_glasses"):
					_drop(k)
					lost += 1


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	return false


func journal() -> Dictionary:
	return {"glasses": _remaining(), "obstacles": _obstacles.size()}


# --------------------------------------------------------------------------- bot


## Vise le milieu du passage libre du prochain obstacle (en tenant compte des collègues qui
## traversent), et y glisse en douceur : vitesse proportionnelle à l'écart.
func bot_wants() -> Dictionary:
	var target: float = _x
	var best_s: float = INF
	for o: Dictionary in _obstacles:
		var ds: float = float(o["s"]) - _s
		if ds < -0.2 or ds > p("bot_horizon") or float(o["vx"]) != 0.0:
			continue
		if ds < best_s:
			best_s = ds
			target = _gap_center(float(o["s"]))
	# Un collègue qui traverse bientôt : rester du côté où l'on est (ne pas couper sa route), à bonne
	# distance de l'endroit où il sera au moment du croisement.
	for o2: Dictionary in _obstacles:
		var ds2: float = float(o2["s"]) - _s
		if float(o2["vx"]) == 0.0 or ds2 < -0.3 or ds2 > p("bot_cross_horizon"):
			continue
		var cx: Vector2 = _obs_x(o2, t + maxf(ds2, 0.0) / (p("speed") / slow))
		var mid: float = (cx.x + cx.y) * 0.5
		var clear: float = p("body_half") + (cx.y - cx.x) * 0.5 + absf(float(o2["vx"])) * p("bot_cross_window")
		# Esquiver du côté où l'on va (le passage suivant), sauf si l'on est déjà nettement de l'autre.
		var side: float = signf(target - mid) if absf(target - mid) > 0.01 else signf(_x - mid)
		if absf(_x - mid) > clear * 0.8 and signf(_x - mid) != side:
			side = signf(_x - mid)
		var keep: float = mid + side * clear
		if keep < -LANE or keep > LANE:
			keep = mid - side * clear
		if (target - mid) * side < clear:
			target = clampf(keep, -LANE, LANE)
	var err: float = target - _x
	# Écart en douceur : la vitesse voulue ne s'éloigne jamais trop de la vitesse actuelle,
	# sinon l'accélération dépasse l'adhérence des verres.
	var dv: float = p("static_accel") / p("response") * p("bot_smooth")
	var v_des: float = clampf(err * p("bot_gain"), _vx - dv, _vx + dv)
	var v: float = clampf(v_des / p("lateral_speed"), -1.0, 1.0)
	return {"do": "axis", "v": Vector2(v, 0.0)}


func _gap_center(s: float) -> float:
	var lo: float = -LANE
	var hi: float = LANE
	for o: Dictionary in _obstacles:
		if absf(float(o["s"]) - s) > 0.01 or float(o["vx"]) != 0.0:
			continue
		if float(o["x1"]) <= 0.0 or float(o["x0"]) < -LANE:
			lo = maxf(lo, float(o["x1"]))
		if float(o["x0"]) >= 0.0 or float(o["x1"]) > LANE:
			hi = minf(hi, float(o["x0"]))
	return (lo + hi) * 0.5


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color("140c08")
	st.env.ambient_light_color = Color(1.0, 0.85, 0.65)
	st.env.ambient_light_energy = 0.5
	st.key.light_energy = 0.4
	var r: Node3D = st.root
	var depth: float = _len + 12.0
	# Parquet en point de Hongrie (bandes alternées), murs lambrissés, chandeliers.
	var oak: StandardMaterial3D = Stage3D.mat(Color("8a5a2e"), 0.0, 0.45)
	var oak2: StandardMaterial3D = Stage3D.mat(Color("6e4422"), 0.0, 0.5)
	for k: int in int(depth / 0.6):
		Stage3D.box(r, Vector3(HALL_W * 2.2, 0.02, 0.6), Vector3(0, -0.01, 4.0 - 0.6 * float(k)), oak if k % 2 == 0 else oak2)
	var wall: StandardMaterial3D = Stage3D.mat(Color("3a1a14"), 0.0, 0.8)
	var panel: StandardMaterial3D = Stage3D.mat(Color("5a2e1a"), 0.0, 0.6)
	for side: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(0.1, 3.2, depth), Vector3(side * HALL_W, 1.6, 4.0 - depth * 0.5), wall)
		Stage3D.box(r, Vector3(0.12, 1.0, depth), Vector3(side * (HALL_W - 0.02), 0.5, 4.0 - depth * 0.5), panel)
		Stage3D.box(r, Vector3(0.13, 0.04, depth), Vector3(side * (HALL_W - 0.03), 1.02, 4.0 - depth * 0.5), Stage3D.mat(Palette.GOLD, 0.7, 0.3))
	var cloth: StandardMaterial3D = Stage3D.mat(Color("f2efe8"), 0.0, 0.85)
	var lamp: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.75, 0.4), 2.5)
	for k2: int in TABLES:
		var z: float = 1.0 - float(k2) * depth / float(TABLES)
		for side2: float in [-1.0, 1.0]:
			var tx: float = side2 * (LANE + 1.5)
			Stage3D.cylinder(r, 0.5, 0.74, Vector3(tx, 0.37, z), cloth, 0.55)
			Stage3D.sphere(r, 0.05, Vector3(tx, 0.85, z), lamp)
			var diner: Figure3D = Figure3D.new().build(1.5, {"coat": [Color("2a2a44"), Color("6a1a2a"), Color("1a3a2a")][k2 % 3],
				"hat": "", "hair": [Color("3a2416"), Color("101010"), Color("a07040")][(k2 + int(side2)) % 3]})
			diner.position = Vector3(tx + side2 * 0.55, 0.1, z)
			diner.rotation.y = -side2 * PI * 0.5
			r.add_child(diner)
			diner.animate(&"sit", float(k2), 1.0, 0.4)
		if k2 % 2 == 0:
			Stage3D.omni(r, Color(1.0, 0.8, 0.55), 1.4, Vector3(0, 2.8, z), 6.0)
			Stage3D.sphere(r, 0.22, Vector3(0, 3.0, z), Stage3D.glow(Palette.GOLD_LIGHT, 1.5))
	# Obstacles : chaise tirée, desserte roulante, collègue (qui traverse ou non).
	for o: Dictionary in _obstacles:
		_obs3.append(_obstacle_node(r, o))
	_waiter = Figure3D.new().build(1.8, {"coat": Color("16161e"), "trim": Palette.IVORY, "hat": "", "hair": Color("201008")})
	r.add_child(_waiter)
	_tray3 = Node3D.new()
	r.add_child(_tray3)
	Stage3D.cylinder(_tray3, TRAY_HALF + 0.04, 0.015, Vector3.ZERO, Stage3D.mat(Color("c8ccd4"), 0.9, 0.25))
	Stage3D.cylinder(_tray3, TRAY_HALF + 0.05, 0.03, Vector3(0, 0.01, 0), Stage3D.mat(Palette.GOLD, 0.8, 0.3), TRAY_HALF + 0.05)
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.95, 1.0, 0.45), 0.0, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wine: StandardMaterial3D = Stage3D.mat(Color("8a1020"), 0.0, 0.2)
	for k3: int in GLASSES:
		var g: Node3D = Node3D.new()
		_tray3.add_child(g)
		Stage3D.cylinder(g, 0.03, 0.005, Vector3(0, 0.01, 0), glass)
		Stage3D.cylinder(g, 0.004, 0.07, Vector3(0, 0.045, 0), glass)
		Stage3D.cylinder(g, 0.035, 0.07, Vector3(0, 0.115, 0), glass, 0.02)
		Stage3D.cylinder(g, 0.03, 0.03, Vector3(0, 0.1, 0), wine, 0.02)
		_glass3.append(g)


func _obstacle_node(r: Node3D, o: Dictionary) -> Node3D:
	var n: Node3D = Node3D.new()
	r.add_child(n)
	var w: float = minf(float(o["x1"]) - float(o["x0"]), 3.5)
	match int(o["kind"]):
		0:  # chaises tirées
			var wood: StandardMaterial3D = Stage3D.mat(Color("4a2410"), 0.0, 0.5)
			var velvet: StandardMaterial3D = Stage3D.mat(Color("8a1a2a"), 0.0, 0.8)
			for c: int in maxi(1, int(w / 0.6)):
				var cx: float = -w * 0.5 + 0.3 + 0.6 * float(c)
				Stage3D.box(n, Vector3(0.45, 0.06, 0.45), Vector3(cx, 0.46, 0), velvet)
				Stage3D.box(n, Vector3(0.45, 0.6, 0.05), Vector3(cx, 0.78, -0.2), wood)
				for lx: float in [-0.19, 0.19]:
					Stage3D.box(n, Vector3(0.04, 0.45, 0.04), Vector3(cx + lx, 0.22, 0.18), wood)
					Stage3D.box(n, Vector3(0.04, 0.45, 0.04), Vector3(cx + lx, 0.22, -0.18), wood)
		1:  # desserte à gâteaux
			var steel: StandardMaterial3D = Stage3D.mat(Color("c8ccd4"), 0.85, 0.3)
			for y: float in [0.35, 0.75]:
				Stage3D.box(n, Vector3(w, 0.03, 0.55), Vector3(0, y, 0), steel)
			for kx: int in maxi(1, int(w / 0.4)):
				var cake_x: float = -w * 0.5 + 0.2 + 0.4 * float(kx)
				var icing: Color = [Color("f2d8e8"), Color("5a2a1a"), Color("f0e0a0")][kx % 3]
				Stage3D.cylinder(n, 0.13, 0.14, Vector3(cake_x, 0.84, 0), Stage3D.mat(icing, 0.0, 0.6))
			for cx2: float in [-w * 0.5, w * 0.5]:
				Stage3D.cylinder(n, 0.015, 0.8, Vector3(cx2, 0.4, 0.25), steel)
		_:  # un collègue, plateau à l'épaule
			var col: Figure3D = Figure3D.new().build(1.75, {"coat": Color("f2efe8"), "trim": Color("1a1a24"), "hat": ""})
			n.add_child(col)
			col.set_meta("fig", true)
	return n


func _sync_3d(dt: float) -> void:
	if _waiter == null:
		return
	var st: Stage3D = stage
	var z: float = 3.0 - _s
	_cam_x = lerpf(_cam_x, _x * 0.55, minf(1.0, dt * 4.0))
	st.look(Vector3(_cam_x, 2.5, z + LOOK), Vector3(_cam_x * 0.7, 0.9, z - 4.0), 52.0)
	_waiter.position = Vector3(_x, 0, z)
	_waiter.rotation.y = PI - _vx * 0.12
	var tilt: float = clampf(-_vx * 0.08, -0.25, 0.25)
	_waiter.animate(&"carry", _s * 2.2, dt, tilt * 2.0)
	var hand: Vector3 = _waiter.joint_global(&"el_r")
	_tray3.global_position = hand + Vector3(0.05, 0.32, 0.0)  # plateau à hauteur d'épaule, au bout de l'avant-bras
	_tray3.rotation.z = tilt
	for k: int in GLASSES:
		var g: Node3D = _glass3[k]
		g.visible = _glass_on[k]
		g.position = Vector3(_glass_off[k], 0.008, (float(k / 3) - 0.5) * 0.24)
	for k2: int in _obstacles.size():
		var o: Dictionary = _obstacles[k2]
		var ox: Vector2 = _obs_x(o)
		var n: Node3D = _obs3[k2]
		n.position = Vector3((ox.x + ox.y) * 0.5, 0, 3.0 - float(o["s"]))
		if int(o["kind"]) == 3 and n.get_child_count() > 0:
			var f: Figure3D = n.get_child(0) as Figure3D
			f.rotation.y = PI * 0.5 * signf(float(o["vx"]))
			f.animate(&"carry", t * 5.0, dt, 0.0)
		elif n.get_child_count() > 0 and n.get_child(0) is Figure3D:
			(n.get_child(0) as Figure3D).animate(&"idle", t * 2.0, dt)
		if bool(o["hit"]):
			n.rotation.z = lerpf(n.rotation.z, 0.3, minf(1.0, dt * 6.0))


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	var prog: float = clampf(_s / _len, 0.0, 1.0)
	draw_rect(Rect2(660.0, 110.0, 600.0, 10.0), Color(Palette.INK, 0.7))
	draw_rect(Rect2(660.0, 110.0, 600.0 * prog, 10.0), Palette.GOLD)
	text(Vector2(960.0, 160.0), tr("TRIAL_SERVICE_STATUS") % [_remaining(), GLASSES], UiKit.SIZE_BODY, Palette.IVORY)
	# Plateau vu de dessus : où glissent les verres (rouge près du bord).
	draw_rect(INSET, Color(Palette.INK, 0.85))
	draw_rect(INSET, Palette.GOLD_DARK, false, 2.0)
	var c: Vector2 = INSET.get_center()
	var rx: float = INSET.size.x * 0.42
	draw_arc(c, rx, 0, TAU, 48, Color("c8ccd4"), 4.0)
	draw_arc(c, rx * 0.66, 0, TAU, 32, Color(Palette.EMERALD, 0.35), 2.0)
	for k: int in GLASSES:
		if not _glass_on[k]:
			continue
		var gp: Vector2 = c + Vector2(_glass_off[k] / TRAY_HALF * rx, (float(k / 3) - 0.5) * 60.0)
		var danger: float = clampf((absf(_glass_off[k]) / TRAY_HALF - 0.5) * 2.0, 0.0, 1.0)
		draw_circle(gp, 16.0, Palette.IVORY.lerp(Palette.ROULETTE_RED, danger))
		draw_circle(gp, 9.0, Color("8a1020"))
