class_name TrialDerby
extends ThrowTrial
## LE TIERCÉ (écran dédié, course de chevaux mécaniques de fête foraine) : quatre chevaux de
## bois sur leurs rails. Le tien galope quand on alterne gauche et droite au rythme du métronome
## (le sabot doré) : dans le temps, la poussée est pleine ; à côté, elle faiblit. Marteler trop
## vite vide la jauge de souffle et le cheval s'essouffle. Trois adversaires à allure fixe.
## Note = place (1er… 4e) et temps à l'arrivée, contre trois chevaux pilotés.

const LANES: int = 4
const TRACK_X: Vector2 = Vector2(300.0, 1640.0)
const LANE_Y0: float = 330.0
const LANE_H: float = 150.0
const HORSE_COLORS: Array[Color] = [Color("ffd23f"), Color("29e0ff"), Color("ff4d6d"), Color("2ee6a8")]
const PLACE_SCORES: Array[float] = [1.0, 0.7, 0.45, 0.2]
const ME: int = 0
## Décor 3D : mètres par pixel, ampoules de l'auvent, bandes de la toile rayée.
const PX3: float = 0.005
const BULBS: int = 30
const STRIPES: int = 22

var _dist: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _speed: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _finish_t: Array[float] = [-1.0, -1.0, -1.0, -1.0]
var _pace: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _last_side: int = -1
var _last_press: float = -10.0
var _breath: float = 1.0
var _winded: float = 0.0
var _beat_phase: float = 0.0
var _bot_side: int = -1
var _ended: bool = false
var _place: int = -1
var _bob: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _horses3: Array[Node3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _bulb_on: StandardMaterial3D = null
var _bulb_off: StandardMaterial3D = null
var _flag: Node3D = null


func begin() -> void:
	var paces: Array = Balance.arr("throw_trials.derby.rival_paces")
	for k: int in range(1, LANES):
		_pace[k] = float(paces[(k - 1) % paces.size()]) * rng.randf_range(0.98, 1.02) / slow
		_bob[k] = rng.randf() * TAU
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	st.env.background_color = Color("0c0610")
	st.env.ambient_light_color = Color(0.45, 0.32, 0.36)
	st.env.ambient_light_energy = 0.5
	var r: Node3D = st.root
	# Toile rayée du fond, auvent festonné, ampoules.
	var red: StandardMaterial3D = Stage3D.mat(Color("5e0e1c"), 0.0, 0.9)
	var ivory: StandardMaterial3D = Stage3D.mat(Color("a89878"), 0.0, 0.9)
	var span: float = 3600.0
	var sw: float = span / float(STRIPES)
	for k: int in STRIPES:
		var x: float = 960.0 - span * 0.5 + sw * (float(k) + 0.5)
		Stage3D.box(r, Vector3(sw * PX3, 900.0 * PX3, 0.05), st.to3(Vector2(x, 640.0), -1.4), red if k % 2 == 0 else ivory)
		var fest: MeshInstance3D = Stage3D.cylinder(r, sw * 0.5 * PX3, 0.06, st.to3(Vector2(x, 240.0), -0.2), red if k % 2 == 1 else ivory)
		fest.rotation.x = PI * 0.5
	Stage3D.box(r, Vector3(span * PX3, 110.0 * PX3, 0.5), st.to3(Vector2(960.0, 185.0), -0.4), Stage3D.mat(Palette.VELVET, 0.0, 0.7))
	var lbl: Label3D = Stage3D.text3d(r, tr("TRIAL_DERBY_MARQUEE"), st.to3(Vector2(960.0, 190.0), -0.12), 110, Palette.GOLD_LIGHT,
		Palette.INK)
	lbl.pixel_size = 0.0016
	_bulb_on = Stage3D.glow(Palette.GOLD_LIGHT, 3.0)
	_bulb_off = Stage3D.mat(Palette.GOLD_DARK, 0.3, 0.4)
	for k2: int in BULBS:
		var bx: float = 960.0 - span * 0.45 + span * 0.9 * float(k2) / float(BULBS - 1)
		_bulbs.append(Stage3D.sphere(r, 9.0 * PX3, st.to3(Vector2(bx, 135.0), -0.12), _bulb_off))
	# Rails de bois en gradins (une piste par cheval), rail de laiton.
	var wood: StandardMaterial3D = Stage3D.mat(Color("5a3220"), 0.0, 0.7)
	var wood2: StandardMaterial3D = Stage3D.mat(Color("4a2818"), 0.0, 0.7)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.BRONZE, 0.45, 0.3)
	for k3: int in LANES:
		var y: float = LANE_Y0 + float(k3) * LANE_H
		var len_px: float = TRACK_X.y - TRACK_X.x + 320.0
		Stage3D.box(r, Vector3(len_px * PX3, 26.0 * PX3, 0.8), st.to3(Vector2((TRACK_X.x + TRACK_X.y) * 0.5 + 20.0, y + 18.0), -0.3),
			wood if k3 % 2 == 0 else wood2)
		Stage3D.box(r, Vector3(len_px * PX3, 4.0 * PX3, 0.04), st.to3(Vector2((TRACK_X.x + TRACK_X.y) * 0.5 + 20.0, y + 5.0), 0.12), brass)
		_horses3.append(_build_horse(st, HORSE_COLORS[k3]))
	# Poteau d'arrivée en damier et fanion.
	for yy: int in 16:
		var fy: float = LANE_Y0 - 110.0 + (float(yy) + 0.5) * LANE_H * float(LANES) / 16.0
		Stage3D.box(r, Vector3(20.0 * PX3, LANE_H * float(LANES) / 16.0 * PX3, 0.1), st.to3(Vector2(TRACK_X.y + 70.0, fy), 0.05),
			ivory if yy % 2 == 0 else Stage3D.mat(Palette.INK, 0.0, 0.6))
	_flag = Node3D.new()
	_flag.position = st.to3(Vector2(TRACK_X.y + 70.0, LANE_Y0 - 150.0), 0.05)
	r.add_child(_flag)
	Stage3D.box(_flag, Vector3(0.3, 0.18, 0.01), Vector3(0.15, 0, 0), Stage3D.mat(Palette.GOLD, 0.2, 0.5))
	# Comptoir du stand au premier plan.
	Stage3D.box(r, Vector3(span * PX3, 150.0 * PX3, 0.5), st.to3(Vector2(960.0, 1040.0), 0.6), Stage3D.mat(Color("6a1020"), 0.2, 0.4))
	Stage3D.box(r, Vector3(span * PX3, 12.0 * PX3, 0.55), st.to3(Vector2(960.0, 965.0), 0.6), brass)
	Stage3D.omni(r, Color(1.0, 0.85, 0.65), 1.4, st.to3(Vector2(960.0, 300.0), 2.5), 9.0)


## Cheval de manège : corps laqué, encolure, tête, jambes repliées, selle dorée et barre de laiton.
func _build_horse(st: Stage3D, col: Color) -> Node3D:
	var n: Node3D = Node3D.new()
	st.root.add_child(n)
	var lacquer: StandardMaterial3D = Stage3D.mat(col, 0.1, 0.25)
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 0.7
	var dark: StandardMaterial3D = Stage3D.mat(col.darkened(0.45), 0.1, 0.4)
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = MeshPool.capsule(22.0 * PX3, 120.0 * PX3)
	body.material_override = lacquer
	body.rotation.z = PI * 0.5
	n.add_child(body)
	var neck: MeshInstance3D = Stage3D.box(n, Vector3(26.0 * PX3, 60.0 * PX3, 0.12), Vector3(52.0 * PX3, 30.0 * PX3, 0), lacquer)
	neck.rotation.z = -0.5
	Stage3D.box(n, Vector3(46.0 * PX3, 22.0 * PX3, 0.11), Vector3(78.0 * PX3, 56.0 * PX3, 0), lacquer)
	Stage3D.box(n, Vector3(10.0 * PX3, 40.0 * PX3, 0.13), Vector3(44.0 * PX3, 44.0 * PX3, 0), dark)  # crinière
	for k: int in 4:
		var lx: float = (-40.0 + float(k) * 26.0) * PX3
		var leg: MeshInstance3D = Stage3D.cylinder(n, 4.0 * PX3, 46.0 * PX3, Vector3(lx, -36.0 * PX3, 0.03 if k % 2 == 0 else -0.03), dark)
		leg.name = "leg%d" % k
	Stage3D.box(n, Vector3(40.0 * PX3, 10.0 * PX3, 0.13), Vector3(-6.0 * PX3, 24.0 * PX3, 0), gilt)
	Stage3D.cylinder(n, 3.0 * PX3, 200.0 * PX3, Vector3(-4.0 * PX3, 40.0 * PX3, 0), gilt)
	var tail: MeshInstance3D = Stage3D.box(n, Vector3(8.0 * PX3, 40.0 * PX3, 0.06), Vector3(-66.0 * PX3, -4.0 * PX3, 0), dark)
	tail.rotation.z = 0.6
	return n


func _sync_3d() -> void:
	if _horses3.is_empty():
		return
	var st: Stage3D = stage
	for k: int in LANES:
		var y: float = LANE_Y0 + float(k) * LANE_H
		var x: float = lerpf(TRACK_X.x, TRACK_X.y, _dist[k])
		var gait: float = _dist[k] * 90.0
		var lift: float = absf(sin(gait)) * 14.0
		var h: Node3D = _horses3[k]
		h.position = st.to3(Vector2(x, y - 60.0 - lift), 0.0)
		h.rotation.z = sin(gait) * 0.08
		for l: int in 4:
			(h.get_node("leg%d" % l) as Node3D).rotation.z = sin(gait + float(l) * 1.6) * 0.5
	for k2: int in _bulbs.size():
		_bulbs[k2].material_override = _bulb_on if (int(t * 6.0) + k2) % 2 == 0 else _bulb_off
	_flag.rotation.y = sin(t * 3.0) * 0.4


func _beat() -> float:
	return p("beat_seconds") * slow


## Position dans le temps : 0 sur le temps, 0.5 à contretemps.
func _off_beat() -> float:
	var ph: float = fmod(t / _beat(), 1.0)
	return minf(ph, 1.0 - ph)


func handle(event: InputEvent) -> bool:
	var k: int = sym_pressed(event)
	var d: Vector2i = dir_pressed(event)
	if k == 0 or d == Vector2i.LEFT:
		gallop(0)
		return true
	if (mouse and k == 1) or k == 2 or d == Vector2i.RIGHT:
		gallop(1)
		return true
	return false


func gallop(side: int) -> void:
	if _finish_t[ME] >= 0.0 or _ended:
		return
	if side == _last_side:
		AudioBus.play("sticky", 1.2, -10.0)
		return
	_last_side = side
	var gap: float = t - _last_press
	_last_press = t
	if gap < p("min_gap") * slow:
		_breath = maxf(0.0, _breath - p("breath_cost"))
		if _breath <= 0.0:
			_winded = p("winded_seconds")
			pop(Vector2(TRACK_X.x + 200.0, LANE_Y0 - 70.0), 0.0, "TRIAL_DERBY_WINDED")
	var timing: float = 1.0 - clampf(_off_beat() / (p("beat_window") * widen()), 0.0, 1.0)
	var push: float = lerpf(p("push_off"), 1.0, timing) * (0.25 if _winded > 0.0 else 1.0)
	_speed[ME] = minf(_speed[ME] + p("push") * push, p("max_speed"))
	AudioBus.play("decor_creak" if side == 0 else "tick", 0.9 + 0.3 * timing, -6.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_sync_3d()
	_winded = maxf(0.0, _winded - dt)
	_breath = minf(1.0, _breath + p("breath_regen") * dt)
	if _bot_side >= 0:
		gallop(_bot_side)
		_bot_side = -1
	_speed[ME] -= _speed[ME] * p("drag") * dt  # frottement proportionnel : allure d'équilibre
	for k: int in LANES:
		if k != ME:
			_speed[k] = _pace[k] * (1.0 + 0.08 * sin(t * 1.7 + _bob[k]))
		if _finish_t[k] < 0.0:
			_dist[k] = minf(1.0, _dist[k] + _speed[k] * dt)
			if _dist[k] >= 1.0:
				_finish_t[k] = t
				if k == ME:
					_place = _rank()
					AudioBus.play("slot_win" if _place == 0 else "chip_place", 1.0, -4.0)
					pop(Vector2(TRACK_X.y - 100.0, LANE_Y0 - 70.0), PLACE_SCORES[_place], "TRIAL_DERBY_PLACE_%d" % (_place + 1))
	if _finish_t[ME] >= 0.0 or t >= p("duration") * slow:
		_end()


func _rank() -> int:
	var ahead: int = 0
	for k: int in LANES:
		if k != ME and _finish_t[k] >= 0.0:
			ahead += 1
	return ahead


func _end() -> void:
	_ended = true
	var place: int = _place if _place >= 0 else LANES - 1
	var place_sc: float = PLACE_SCORES[place] if _place >= 0 else 0.0
	var time_sc: float = 0.0
	if _finish_t[ME] >= 0.0:
		var par: float = p("par_seconds") * slow
		var limit: float = p("duration") * slow
		time_sc = clampf((limit - _finish_t[ME]) / maxf(limit - par, 0.01), 0.0, 1.0)
	finish(clampf(place_sc * (1.0 - p("time_weight")) + time_sc * p("time_weight"), 0.0, 1.0))


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	# Frappe sur chaque temps (alterné), jamais plus vite que le souffle ne le permet.
	if _off_beat() < 0.03 and t - _last_press > _beat() * 0.6:
		return {"do": "sym", "symbol": 2 if _last_side == 0 else 0}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "sym":
		_bot_side = 0 if int(w.get("symbol", 0)) == 0 else 1
	else:
		_bot_side = -1


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	text(Vector2(TRACK_X.x - 160, LANE_Y0 + float(ME) * LANE_H - 50), tr("TRIAL_DERBY_YOU"), UiKit.SIZE_BODY, HORSE_COLORS[ME])
	# Métronome (sabot doré) et souffle.
	var m: Vector2 = Vector2(size.x * 0.5 - 200.0, size.y - 110.0)
	var ph: float = fmod(t / _beat(), 1.0)
	draw_arc(m, 34.0, 0, TAU, 32, Palette.GOLD_DARK, 3.0)
	draw_circle(m, 34.0 * (1.0 - ph), Color(Palette.GOLD, 0.25 + 0.6 * (1.0 - ph)))
	var bw: Rect2 = Rect2(size.x * 0.5 - 120.0, size.y - 120.0, 400.0, 20.0)
	draw_rect(bw, Color(Palette.INK, 0.9))
	var bc: Color = Palette.EMERALD if _winded <= 0.0 else Palette.MULT_RED
	draw_rect(Rect2(bw.position, Vector2(bw.size.x * _breath, bw.size.y)), bc)
	draw_rect(bw, Palette.GOLD, false, 2.0)
	text(Vector2(bw.get_center().x, bw.position.y - 22.0), tr("TRIAL_DERBY_BREATH"), UiKit.SIZE_SMALL, Palette.IVORY)
