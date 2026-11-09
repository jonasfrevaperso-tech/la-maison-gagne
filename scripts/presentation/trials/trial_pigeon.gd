class_name TrialPigeon
extends ThrowTrial
## LE PIGEON VOYAGEUR (Toits, 2.0) : vol plané au-dessus des toits de Paris, la nuit. Le stick
## règle l'assiette : piquer donne de la vitesse, cabrer en coûte (sous la vitesse de
## décrochage, le pigeon pique tout seul). Les fumées chaudes des cheminées portent vers le
## haut ; trois battements d'ailes en réserve (bouton), rechargés dans les fumées. Il faut passer
## dans l'anneau doré devant chaque fenêtre qui attend un message, sans heurter les souches.
## Note = part des messages remis, moins une part par choc.

const PX3: float = 0.005
const SCREEN_X: float = 520.0
const ROOF_Y: float = 930.0
const SKY_Y: float = 80.0
const STACK_W: float = 120.0
const RING_R: float = 70.0
const PLUME_W: float = 150.0
const FLAPS: int = 3

var _wx: float = 0.0
var _y: float = 420.0
var _v: float = 0.0
var _pitch: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_y: float = -1.0
var _flaps: int = FLAPS
var _flap_anim: float = 0.0
var _boost: float = 0.0
var _stacks: Array[Vector2] = []  # (x, sommet y)
var _rings: Array[Dictionary] = []  # {"x", "y", "done": -1 | 0 | 1}
var _hits: int = 0
var _hit_cool: float = 0.0
var _length: float = 4000.0
var _ended: bool = false
var _deco: Dictionary = {}
var _bird: Node3D = null
var _wings: Array[Node3D] = []
var _ring3: Array[Node3D] = []
var _people: Array[Figure3D] = []


func begin() -> void:
	_v = p("cruise")
	_length = p("cruise") * p("fly_seconds")
	_lay_out()
	_build_3d()


## Parcours : souches de hauteurs variées, une fenêtre à message toutes les deux souches,
## alternativement haute (il faut avoir gardé de l'altitude) et basse (plonger entre deux souches).
func _lay_out() -> void:
	var x: float = p("first_stack")
	var k: int = 0
	var min_top: float = 0.0  # sommet le plus haut permis (après un anneau bas : souche plus basse)
	while x < _length - 300.0:
		var top: float = maxf(ROOF_Y - rng.randf_range(p("stack_min"), p("stack_max")), min_top)
		_stacks.append(Vector2(x, top))
		min_top = 0.0
		if k % 2 == 1:
			var ry: float = rng.randf_range(p("ring_high_min"), p("ring_high_max"))
			if (k / 2) % 2 == 1:
				# Anneau bas : sous le sommet de la souche qu'on vient de passer, à plonger.
				ry = minf(top + rng.randf_range(p("ring_low_min"), p("ring_low_max")), ROOF_Y - RING_R - 20.0)
				min_top = ry + p("low_exit")
			_rings.append({"x": x + p("spacing") * p("ring_at"), "y": ry, "done": -1})
		x += p("spacing") * rng.randf_range(0.85, 1.15)
		k += 1


func _plume_lift(x: float, y: float) -> float:
	for s: Vector2 in _stacks:
		var cx: float = s.x + p("wind") * (s.y - y) / p("plume_rise")
		if y < s.y and absf(x - cx) < PLUME_W * 0.5 and s.y - y < p("plume_height"):
			return p("lift") * (1.0 - (s.y - y) / p("plume_height"))
	return 0.0


func tick(dt: float) -> void:
	_flap_anim = maxf(0.0, _flap_anim - dt * 3.0)
	_hit_cool = maxf(0.0, _hit_cool - dt)
	_sync_3d(dt)
	if _ended:
		return
	# Assiette : le stick donne l'assiette voulue (bas = piquer), la souris donne l'altitude visée.
	var want: float = clampf(held_vector().y + _axis.y, -1.0, 1.0) * p("max_pitch")
	if mouse and _mouse_y >= 0.0:
		want = clampf((_mouse_y - _y) / 300.0, -1.0, 1.0) * p("max_pitch")
	if _v < p("stall"):
		want = maxf(want, p("max_pitch") * 0.6)  # décrochage : le nez tombe
	_pitch += clampf(want - _pitch, -p("pitch_rate") * dt, p("pitch_rate") * dt) / slow
	# Énergie : la pente échange vitesse et altitude ; la traînée ramène vers la croisière.
	_v += (p("gravity") * sin(_pitch) - p("drag") * (_v - p("cruise"))) * dt / slow
	_v = clampf(_v, p("stall") * 0.6, p("max_speed"))
	var lift: float = _plume_lift(_wx + SCREEN_X, _y)
	if lift > 0.0 and _flaps < FLAPS:
		_flaps = mini(FLAPS, _flaps + (1 if rng.randf() < dt * p("recharge_rate") else 0))
	_wx += _v * cos(_pitch) * dt / slow
	_y += (_v * sin(_pitch) + p("sink") - lift - _boost) * dt / slow
	_boost = maxf(0.0, _boost - _boost * p("boost_decay") * dt / slow)
	_y = clampf(_y, SKY_Y, ROOF_Y)
	_collide()
	_check_rings()
	if _wx + SCREEN_X >= _length:
		_ended = true
		finish(_score())


func _score() -> float:
	var got: int = 0
	for r: Dictionary in _rings:
		got += 1 if int(r["done"]) == 1 else 0
	var base: float = float(got) / float(maxi(1, _rings.size()))
	return clampf(base - p("hit_penalty") * float(_hits), 0.0, 1.0)


func _collide() -> void:
	if _hit_cool > 0.0:
		return
	var x: float = _wx + SCREEN_X
	var hit: bool = _y >= ROOF_Y - 2.0
	for s: Vector2 in _stacks:
		if absf(x - s.x) < STACK_W * 0.5 + 18.0 and _y > s.y - 14.0:
			hit = true
	if hit:
		_hits += 1
		_hit_cool = p("hit_cool") * slow
		_v = p("stall") * 0.9
		_y -= 50.0
		_pitch = -0.3
		AudioBus.play("cloth", 1.3, -3.0)
		pop(Vector2(SCREEN_X, _y - 60.0), 0.0, "TRIAL_PIGEON_HIT")


func _check_rings() -> void:
	var x: float = _wx + SCREEN_X
	for r: Dictionary in _rings:
		if int(r["done"]) >= 0 or x < float(r["x"]):
			continue
		var ok: bool = absf(_y - float(r["y"])) <= RING_R * widen()
		r["done"] = 1 if ok else 0
		var key: String = "TRIAL_PIGEON_DELIVERED" if ok else "TRIAL_PIGEON_MISSED"
		pop(Vector2(SCREEN_X, float(r["y"]) - 90.0), 1.0 if ok else 0.0, key)
		AudioBus.play("chime" if ok else "lose_soft", 1.2, -4.0)


func flap() -> void:
	if _flaps <= 0 or _ended:
		return
	_flaps -= 1
	_flap_anim = 1.0
	_boost = p("flap_rise") * p("boost_decay")
	_v = minf(p("max_speed"), _v + p("flap_speed"))
	_pitch = minf(_pitch, -0.15)
	AudioBus.play("cloth", 1.6, -6.0)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_y = mm.position.y
		return true
	if confirm_pressed(event):
		flap()
		return true
	return false


func journal() -> Dictionary:
	return {"hits": _hits, "rings": _rings.size(), "flaps_left": _flaps}


# --------------------------------------------------------------------------- bot


## Vise l'altitude du prochain obstacle (au centre de l'anneau, ou au-dessus de la souche) en
## pilotant l'assiette ; bat des ailes s'il est trop bas et trop lent pour remonter.
func bot_wants() -> Dictionary:
	var x: float = _wx + SCREEN_X
	var goal: float = 420.0
	var best: float = INF
	for r: Dictionary in _rings:
		var d: float = float(r["x"]) - x
		if d > -10.0 and d < best:
			best = d
			goal = float(r["y"])
	for s: Vector2 in _stacks:
		var d2: float = s.x - x
		if d2 > -STACK_W * 0.5 - 20.0 and d2 < best + 1.0 and d2 < p("bot_look"):
			goal = minf(goal, s.y - p("bot_clear"))
			break
	var err: float = goal - _y
	var vy: float = _v * sin(_pitch)
	if err < -p("bot_flap_gap") and _flaps > 0 and _flap_anim <= 0.0 and _v < p("cruise"):
		return {"do": "confirm"}
	var want: float = clampf(err * p("bot_kp") - vy * p("bot_kd"), -1.0, 1.0)
	return {"do": "axis", "v": Vector2(0.0, want)}


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2
	if String(w.get("do", "")) == "confirm":
		flap()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = RooftopSet.build(st, ROOF_Y - 60.0, [], 11, _length + 1200.0)
	var r: Node3D = st.root
	for s: Vector2 in _stacks:
		RooftopSet.chimney(st, r, s.x, ROOF_Y, ROOF_Y - s.y, _deco, 0.0)
	# Fenêtres à message : lucarne allumée au fond, un habitant qui attend, anneau doré.
	var gold: StandardMaterial3D = Stage3D.glow(Palette.GOLD_LIGHT, 1.2)
	for ring: Dictionary in _rings:
		var at: Vector3 = st.to3(Vector2(float(ring["x"]), float(ring["y"])), 0.0)
		var tor: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = RING_R * PX3 * 0.9
		tm.outer_radius = RING_R * PX3
		tor.mesh = tm
		tor.material_override = gold
		tor.rotation.x = PI * 0.5
		tor.position = at
		r.add_child(tor)
		_ring3.append(tor)
		var win: Vector3 = st.to3(Vector2(float(ring["x"]), float(ring["y"]) + 20.0), -1.2)
		Stage3D.box(r, Vector3(0.9, 1.2, 0.05), win + Vector3(0, 0, -0.05), Stage3D.glow(RooftopSet.WINDOW, 0.9))
		# La façade de l'immeuble sous la fenêtre, jusqu'aux toits.
		var foot: float = st.to3(Vector2(0.0, ROOF_Y + 200.0)).y
		var facade_h: float = win.y - 0.6 - foot
		if facade_h > 0.0:
			var stone: StandardMaterial3D = Stage3D.mat(Color("c8b89a"), 0.0, 0.85)
			Stage3D.box(r, Vector3(1.6, facade_h, 0.3), Vector3(win.x, foot + facade_h * 0.5, win.z - 0.2), stone)
			for fw: int in int(facade_h / 0.5):
				var fwin: Vector3 = Vector3(win.x + (-0.4 if fw % 2 == 0 else 0.4), win.y - 1.0 - 0.5 * float(fw / 2), win.z - 0.04)
				if fwin.y > foot + 0.2:
					var pane: StandardMaterial3D = Stage3D.glow(RooftopSet.WINDOW, 0.5) if fw % 3 != 0 else Stage3D.mat(Color("101420"), 0.3, 0.2)
					Stage3D.box(r, Vector3(0.3, 0.38, 0.02), fwin, pane)
		Stage3D.box(r, Vector3(1.05, 0.08, 0.2), win + Vector3(0, -0.62, 0.05), Stage3D.mat(Color("2a2a30"), 0.6, 0.4))
		var coat: Color = [Color("6a1a2a"), Color("2a3a6a"), Color("3a5a2a")][_people.size() % 3]
		var who: Figure3D = Figure3D.new().build(0.9, {"coat": coat, "hat": ""})
		who.position = win + Vector3(0, -0.6, 0.0)
		r.add_child(who)
		_people.append(who)
	# Le pigeon : corps gris ardoise, gorge irisée, ailes articulées.
	_bird = Node3D.new()
	r.add_child(_bird)
	var slate: StandardMaterial3D = Stage3D.mat(Color("7a8090"), 0.0, 0.7)
	var body: MeshInstance3D = Stage3D.sphere(_bird, 0.16, Vector3.ZERO, slate)
	body.scale = Vector3(1.6, 0.9, 0.9)
	Stage3D.sphere(_bird, 0.09, Vector3(0.22, 0.07, 0), Stage3D.mat(Color("5a6a7a"), 0.3, 0.3))
	Stage3D.sphere(_bird, 0.07, Vector3(0.18, 0.0, 0), Stage3D.mat(Color("3a8a6a"), 0.5, 0.25))
	var beak_m: StandardMaterial3D = Stage3D.mat(Color("d8b080"), 0.0, 0.5)
	var beak: MeshInstance3D = Stage3D.cylinder(_bird, 0.02, 0.07, Vector3(0.33, 0.06, 0), beak_m, 0.0)
	beak.rotation.z = -PI * 0.5
	Stage3D.sphere(_bird, 0.015, Vector3(0.27, 0.1, 0.06), Stage3D.mat(Color("ff6a1a"), 0.0, 0.3))
	var tail_m: StandardMaterial3D = Stage3D.mat(Color("4a5060"), 0.0, 0.7)
	var tail: MeshInstance3D = Stage3D.box(_bird, Vector3(0.2, 0.02, 0.12), Vector3(-0.3, 0.0, 0), tail_m)
	tail.rotation.z = 0.1
	var paper: StandardMaterial3D = Stage3D.mat(Color("f4ecd8"), 0.0, 0.8)
	var scroll: MeshInstance3D = Stage3D.cylinder(_bird, 0.03, 0.08, Vector3(-0.02, -0.14, 0.05), paper)
	scroll.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		var w: Node3D = Node3D.new()
		w.position = Vector3(0.02, 0.06, side * 0.1)
		_bird.add_child(w)
		Stage3D.box(w, Vector3(0.26, 0.02, 0.42), Vector3(0, 0, side * 0.21), slate)
		Stage3D.box(w, Vector3(0.1, 0.021, 0.2), Vector3(-0.06, 0, side * 0.36), Stage3D.mat(Color("2a2e38"), 0.0, 0.7))
		w.set_meta("side", side)
		_wings.append(w)


func _sync_3d(dt: float) -> void:
	if _bird == null:
		return
	var st: Stage3D = stage
	var cam_x: float = (_wx + SCREEN_X + (960.0 - SCREEN_X) - 960.0) * PX3
	st.cam.position.x = cam_x
	(_deco["far"] as Node3D).position.x = cam_x * p("parallax")
	_bird.position = st.to3(Vector2(_wx + SCREEN_X, _y), 0.2)
	_bird.rotation.z = -_pitch
	var beat: float = sin(t * (8.0 + 22.0 * _flap_anim)) * (0.25 + 0.6 * _flap_anim)
	if _v < p("stall"):
		beat = sin(t * 30.0) * 0.8
	for w: Node3D in _wings:
		w.rotation.x = float(w.get_meta("side")) * beat
	for k: int in _ring3.size():
		var done: int = int(_rings[k]["done"])
		_ring3[k].rotation.z = sin(t * 2.0 + float(k)) * 0.12
		(_ring3[k] as MeshInstance3D).visible = done != 0
		if done == 1:
			_ring3[k].scale = _ring3[k].scale.lerp(Vector3.ONE * 0.01, minf(1.0, dt * 3.0))
		_people[k].animate(&"cheer" if done == 1 else (&"point" if done < 0 else &"idle"), t * 3.0, dt, 1.0)
	RooftopSet.animate(_deco, st, t, p("wind") * 200.0)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Barre de parcours avec les fenêtres, réserve de battements, vitesse.
	var bar: Rect2 = Rect2(560.0, 100.0, 800.0, 10.0)
	draw_rect(bar, Color(Palette.INK, 0.75))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf((_wx + SCREEN_X) / _length, 0.0, 1.0), bar.size.y)), Palette.GOLD)
	for r: Dictionary in _rings:
		var rx: float = bar.position.x + bar.size.x * float(r["x"]) / _length
		var col: Color = Palette.GOLD_LIGHT
		if int(r["done"]) >= 0:
			col = Palette.EMERALD if int(r["done"]) == 1 else Palette.ROULETTE_RED
		draw_circle(Vector2(rx, bar.get_center().y), 9.0, col)
	for k: int in FLAPS:
		var c: Vector2 = Vector2(100.0 + 52.0 * float(k), 160.0)
		draw_circle(c, 20.0, Color(Palette.INK, 0.8))
		draw_arc(c, 20.0, 0, TAU, 24, Palette.IVORY, 2.0)
		if k < _flaps:
			var wing: PackedVector2Array = PackedVector2Array([c + Vector2(-14, 4), c + Vector2(0, -12), c + Vector2(14, 4), c + Vector2(0, -2)])
			draw_colored_polygon(wing, Palette.IVORY)
	text(Vector2(178.0, 210.0), tr("TRIAL_PIGEON_FLAPS"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	var spd: float = clampf((_v - p("stall")) / (p("max_speed") - p("stall")), 0.0, 1.0)
	var gauge: Rect2 = Rect2(80.0, 250.0, 200.0, 14.0)
	draw_rect(gauge, Color(Palette.INK, 0.8))
	var slow_col: Color = Palette.ROULETTE_RED if _v < p("stall") * 1.15 else Palette.EMERALD
	draw_rect(Rect2(gauge.position, Vector2(gauge.size.x * spd, gauge.size.y)), slow_col)
	var label: String = tr("TRIAL_PIGEON_STALL") if _v < p("stall") else tr("TRIAL_PIGEON_SPEED")
	text(Vector2(180.0, 290.0), label, UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
