class_name TrialAntenna
extends ThrowTrial
## L'ANTENNE (Toits, 2.0) : le poste de télévision posé sur le toit ne capte que de la neige.
## Deux molettes : la fréquence (stick gauche / droite) et le gain (haut / bas). Près d'une
## station, l'image perce la neige et le grésillement faiblit ; trop de gain sature. Il faut
## tenir l'image nette un instant pour l'accrocher, puis chercher la suivante. Le vent fait
## dériver la station, et un pigeon qui se pose sur l'antenne change le gain qu'il faut.
## Note = moyenne des stations (accrochée vite : plein ; tard : moins ; jamais : une part du
## meilleur signal obtenu).

const PX3: float = 0.005
const SCREEN: Rect2 = Rect2(560.0, 300.0, 520.0, 390.0)
const DIAL: Rect2 = Rect2(560.0, 760.0, 520.0, 40.0)
const METER_C: Vector2 = Vector2(290.0, 420.0)
const SNOW: int = 700
const MHZ_MIN: float = 88.0
const MHZ_MAX: float = 108.0

var _freq: float = 0.5
var _gain: float = 0.5
var _axis: Vector2 = Vector2.ZERO
var _mouse: Vector2 = Vector2(-1.0, -1.0)
var _drag: bool = false
var _station: int = 0
var _targets: Array[Vector2] = []  # (fréquence, gain idéal) de chaque station
var _st_t: float = 0.0
var _lock_t: float = 0.0
var _best_q: float = 0.0
var _q: float = 0.0
var _marks: Array[float] = []
var _pigeon_on: bool = false
var _pigeon_t: float = -1.0
var _crackle: float = 0.0
var _ended: bool = false
var _deco: Dictionary = {}
var _mast: Node3D = null
var _bird: Node3D = null
var _knobs: Array[Node3D] = []
var _screen3: MeshInstance3D = null


func begin() -> void:
	for k: int in pi("stations"):
		var f: float = rng.randf_range(0.1, 0.9)
		# Jamais deux stations proches, ni la première sous la position de départ des molettes.
		while (k > 0 and absf(f - _targets[-1].x) < 0.3) or (k == 0 and absf(f - 0.5) < 0.2):
			f = rng.randf_range(0.1, 0.9)
		_targets.append(Vector2(f, rng.randf_range(0.25, 0.75)))
	_pigeon_t = p("pigeon_at") * slow
	_build_3d()


## Station visée à l'instant présent : dérive lente au vent, gain décalé par le pigeon.
func _target() -> Vector2:
	var base: Vector2 = _targets[mini(_station, _targets.size() - 1)]
	var drift: float = p("drift") * sin(t / slow * p("drift_rate") + float(_station) * 1.7)
	var g_shift: float = p("pigeon_gain") if _pigeon_on else 0.0
	return Vector2(clampf(base.x + drift, 0.02, 0.98), clampf(base.y + g_shift, 0.05, 0.95))


## Qualité de l'image : bosse large (on sent qu'on approche) et pic étroit, multipliés par
## l'accord du gain (trop peu : faible ; trop : saturé).
func quality(f: float, g: float) -> float:
	var tg: Vector2 = _target()
	var df: float = f - tg.x
	var broad: float = exp(-pow(df / p("width_broad"), 2.0))
	var peak: float = exp(-pow(df / p("width_peak"), 2.0))
	var gain_fit: float = exp(-pow((g - tg.y) / p("width_gain"), 2.0))
	return clampf((p("broad_share") * broad + (1.0 - p("broad_share")) * peak) * gain_fit, 0.0, 1.0)


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	var v: Vector2 = held_vector() + _axis
	_freq = clampf(_freq + clampf(v.x, -1.0, 1.0) * dt / (p("freq_sweep") * slow), 0.0, 1.0)
	_gain = clampf(_gain - clampf(v.y, -1.0, 1.0) * dt / (p("gain_sweep") * slow), 0.0, 1.0)
	if mouse and _drag and _mouse.x >= 0.0:
		_freq = clampf((_mouse.x - DIAL.position.x) / DIAL.size.x, 0.0, 1.0)
		_gain = clampf(1.0 - (_mouse.y - 300.0) / 500.0, 0.0, 1.0)
	if not _pigeon_on and _pigeon_t > 0.0 and t >= _pigeon_t:
		_pigeon_on = true
		AudioBus.play("cloth", 1.5, -4.0)
		pop(Vector2(1500.0, 200.0), 0.0, "TRIAL_ANTENNA_PIGEON")
	_q = quality(_freq, _gain)
	_best_q = maxf(_best_q, _q)
	_st_t += dt
	_crackle -= dt
	if _crackle <= 0.0:
		_crackle = lerpf(0.04, 0.4, _q)
		AudioBus.play("tick", rng.randf_range(0.5, 1.6), lerpf(-10.0, -28.0, _q))
	if _q >= p("lock_q"):
		_lock_t += dt
		if _lock_t >= p("lock_seconds") * slow:
			var over: float = maxf(0.0, _st_t / (p("limit") * slow) - p("grace"))
			_score_station(clampf(1.0 - over * p("late_weight"), p("late_floor"), 1.0), "TRIAL_ANTENNA_LOCKED")
	else:
		_lock_t = maxf(0.0, _lock_t - dt * 2.0)
	if _st_t >= p("limit") * slow and not _ended:
		_score_station(_best_q * p("miss_share"), "TRIAL_ANTENNA_LOST")


func _score_station(q: float, key: String) -> void:
	_marks.append(q)
	pop(SCREEN.get_center(), q, key)
	AudioBus.play("chime" if q >= 0.5 else "lose_soft", 1.0 + 0.1 * float(_station), -4.0)
	_station += 1
	_st_t = 0.0
	_lock_t = 0.0
	_best_q = 0.0
	if _station >= _targets.size():
		_ended = true
		finish(ThrowTrial.mean(_marks))


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_drag = mb.pressed
		_mouse = mb.position
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse = mm.position
		return true
	return false


func journal() -> Dictionary:
	return {"stations": _marks.size(), "pigeon": _pigeon_on}


# --------------------------------------------------------------------------- bot


## Sait où est la station (le banc teste le geste, pas l'oreille) : tourne les deux molettes à
## la fois vers elle, proportionnellement à l'écart.
func bot_wants() -> Dictionary:
	if _ended:
		return {"do": ""}
	var tg: Vector2 = _target()
	var vx: float = clampf((tg.x - _freq) * p("bot_gain"), -1.0, 1.0)
	var vy: float = clampf(-(tg.y - _gain) * p("bot_gain"), -1.0, 1.0)
	return {"do": "axis", "v": Vector2(vx, vy)}


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = RooftopSet.build(st, 1000.0, [260.0], 31)
	var r: Node3D = st.root
	# Le poste : caisse en noyer, écran bombé, deux molettes de bakélite, pieds compas.
	var walnut: StandardMaterial3D = Stage3D.mat(Color("8a4a22"), 0.0, 0.3)
	var c: Vector3 = st.to3(Vector2(SCREEN.get_center().x + 60.0, SCREEN.get_center().y + 40.0), -0.32)
	Stage3D.box(r, Vector3(SCREEN.size.x * PX3 + 0.75, SCREEN.size.y * PX3 + 0.55, 0.6), c, walnut)
	var bezel: Vector3 = Vector3(SCREEN.size.x * PX3 + 0.18, SCREEN.size.y * PX3 + 0.18, 0.04)
	Stage3D.box(r, bezel, st.to3(SCREEN.get_center(), -0.01), Stage3D.mat(Palette.GOLD, 0.7, 0.3))
	var glass: Vector3 = Vector3(SCREEN.size.x * PX3, SCREEN.size.y * PX3, 0.02)
	_screen3 = Stage3D.box(r, glass, st.to3(SCREEN.get_center(), 0.0), Stage3D.glow(Color(0.5, 0.55, 0.6), 0.5))
	for k: int in 2:
		var knob: Node3D = Node3D.new()
		knob.position = st.to3(Vector2(SCREEN.end.x + 120.0, SCREEN.position.y + 90.0 + 190.0 * float(k)), 0.0)
		r.add_child(knob)
		var body: MeshInstance3D = Stage3D.cylinder(knob, 0.17, 0.08, Vector3.ZERO, Stage3D.mat(Color("1a1410"), 0.2, 0.3))
		body.rotation.x = PI * 0.5
		Stage3D.box(knob, Vector3(0.03, 0.14, 0.05), Vector3(0, 0.08, 0.05), Stage3D.mat(Palette.IVORY, 0.0, 0.4))
		_knobs.append(knob)
	for side: float in [-1.0, 1.0]:
		var leg: MeshInstance3D = Stage3D.cylinder(r, 0.035, 1.3, c + Vector3(side * 1.3, -1.75, 0.0), Stage3D.mat(Color("2a1a10"), 0.0, 0.5))
		leg.rotation.z = side * 0.15
	# L'antenne en arête de poisson sur son mât haubané.
	_mast = Node3D.new()
	_mast.position = st.to3(Vector2(1560.0, 960.0), -0.6)
	r.add_child(_mast)
	var alu: StandardMaterial3D = Stage3D.mat(Color("c8ccd4"), 0.9, 0.3)
	Stage3D.cylinder(_mast, 0.035, 3.6, Vector3(0, 1.8, 0), alu)
	var boom: MeshInstance3D = Stage3D.cylinder(_mast, 0.025, 1.8, Vector3(0, 3.4, 0), alu)
	boom.rotation.z = PI * 0.5
	for k2: int in 7:
		Stage3D.cylinder(_mast, 0.012, 1.1 - 0.1 * float(k2), Vector3(-0.8 + 0.27 * float(k2), 3.4, 0), alu).rotation.x = PI * 0.5
	for gx: float in [-1.2, 1.2]:
		var guy: MeshInstance3D = Stage3D.cylinder(_mast, 0.005, 3.2, Vector3(gx * 0.5, 1.5, 0), Stage3D.mat(Color("8a8c94"), 0.7, 0.4))
		guy.rotation.z = -gx * 0.33
	_bird = Node3D.new()
	_mast.add_child(_bird)
	var slate: StandardMaterial3D = Stage3D.mat(Color("7a8090"), 0.0, 0.7)
	Stage3D.sphere(_bird, 0.11, Vector3.ZERO, slate).scale = Vector3(1.5, 1.0, 1.0)
	Stage3D.sphere(_bird, 0.06, Vector3(0.14, 0.07, 0), slate)
	Stage3D.cylinder(_bird, 0.015, 0.05, Vector3(0.21, 0.07, 0), Stage3D.mat(Color("d8b080"), 0.0, 0.5), 0.0).rotation.z = -PI * 0.5
	_bird.visible = false


func _sync_3d(_dt: float) -> void:
	if _mast == null:
		return
	_knobs[0].rotation.z = lerpf(PI * 0.8, -PI * 0.8, _freq)
	_knobs[1].rotation.z = lerpf(PI * 0.8, -PI * 0.8, _gain)
	var gust: float = sin(t * 0.9) * 0.04 + sin(t * 2.3) * 0.015
	_mast.rotation.z = gust
	if _pigeon_on:
		_bird.visible = true
		var land: Vector3 = Vector3(0.55, 3.47, 0.0)
		var from: Vector3 = Vector3(2.5, 4.5, 0.4)
		var u: float = clampf((t - _pigeon_t) / 0.8, 0.0, 1.0)
		_bird.position = from.lerp(land, 1.0 - pow(1.0 - u, 3.0))
	(_screen3.material_override as StandardMaterial3D).emission_energy_multiplier = 0.4 + 0.8 * _q
	RooftopSet.animate(_deco, stage, t, 60.0)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# L'écran : neige (de moins en moins), image de la station qui apparaît, puis nette.
	var q: float = _q
	var station: int = mini(_station, _targets.size() - 1)
	draw_rect(SCREEN, Color(0.08, 0.09, 0.1))
	_picture(station, clampf((q - 0.15) / 0.85, 0.0, 1.0))
	var snow_n: int = int(float(SNOW) * (1.0 - q))
	var seed_t: int = int(t * 30.0)
	for k: int in snow_n:
		var h: int = hash(Vector2i(k, seed_t))
		var x: float = SCREEN.position.x + float(h % 1000) / 1000.0 * SCREEN.size.x
		var y: float = SCREEN.position.y + float((h / 1000) % 1000) / 1000.0 * SCREEN.size.y
		var lum: float = float((h / 1000000) % 100) / 100.0
		draw_rect(Rect2(x, y, 10.0, 5.0), Color(lum, lum, lum, 0.9))
	if q > p("lock_q"):
		var lock: float = clampf(_lock_t / (p("lock_seconds") * slow), 0.0, 1.0)
		draw_arc(SCREEN.get_center(), 60.0, -PI * 0.5, -PI * 0.5 + TAU * lock, 32, Palette.EMERALD, 8.0)
	# Cadran des fréquences.
	draw_rect(DIAL, Color("f0e4c4"))
	draw_rect(DIAL, Palette.GOLD_DARK, false, 3.0)
	for k2: int in 21:
		var x2: float = DIAL.position.x + DIAL.size.x * float(k2) / 20.0
		var tick_h: float = 18.0 if k2 % 5 == 0 else 10.0
		draw_line(Vector2(x2, DIAL.position.y + 4.0), Vector2(x2, DIAL.position.y + tick_h), Palette.INK, 2.0)
		if k2 % 5 == 0:
			var mhz: String = "%d" % int(lerpf(MHZ_MIN, MHZ_MAX, float(k2) / 20.0))
			text(Vector2(x2, DIAL.end.y - 10.0), mhz, UiKit.SIZE_SMALL, Palette.INK, "body", 0)
	var nx: float = DIAL.position.x + DIAL.size.x * _freq
	draw_line(Vector2(nx, DIAL.position.y - 6.0), Vector2(nx, DIAL.end.y + 6.0), Palette.ROULETTE_RED, 4.0)
	# Vumètre du signal et réglette du gain.
	draw_circle(METER_C, 110.0, Color(Palette.INK, 0.88))
	draw_arc(METER_C, 110.0, 0, TAU, 48, Palette.GOLD, 3.0)
	draw_arc(METER_C, 86.0, PI * 1.15, PI * 1.85, 32, Color(Palette.IVORY, 0.3), 12.0)
	draw_arc(METER_C, 86.0, lerpf(PI * 1.15, PI * 1.85, p("lock_q")), PI * 1.85, 16, Palette.EMERALD, 12.0)
	var na: float = lerpf(PI * 1.15, PI * 1.85, q)
	draw_line(METER_C, METER_C + Vector2.from_angle(na) * 96.0, Palette.GOLD_LIGHT, 5.0)
	text(METER_C + Vector2(0, 40.0), tr("TRIAL_ANTENNA_SIGNAL"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 0)
	var gbar: Rect2 = Rect2(METER_C.x - 14.0, METER_C.y + 140.0, 28.0, 200.0)
	draw_rect(gbar, Color(Palette.INK, 0.85))
	var gfill: Rect2 = Rect2(gbar.position + Vector2(0, gbar.size.y * (1.0 - _gain)), Vector2(gbar.size.x, gbar.size.y * _gain))
	draw_rect(gfill, Palette.ROULETTE_RED.lerp(Palette.GOLD, 0.4))
	text(Vector2(gbar.get_center().x, gbar.end.y + 26.0), tr("TRIAL_ANTENNA_GAIN"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	var status: String = tr("TRIAL_ANTENNA_STATUS") % [mini(_station + 1, _targets.size()), _targets.size()]
	text(Vector2(960.0, 105.0), status, UiKit.SIZE_BODY, Palette.IVORY)


## Mire de chaque station (dessinée, sans texte de marque) : roue de roulette, mire de barres,
## horloge. `a` : netteté 0..1.
func _picture(station: int, a: float) -> void:
	if a <= 0.0:
		return
	var c: Vector2 = SCREEN.get_center()
	match station % 3:
		0:
			for k: int in 18:
				var a0: float = TAU * float(k) / 18.0 + t * 0.6
				var col: Color = Palette.ROULETTE_RED if k % 2 == 0 else Palette.INK
				if k == 0:
					col = Palette.EMERALD
				var wedge: PackedVector2Array = PackedVector2Array([c, c + Vector2.from_angle(a0) * 150.0,
					c + Vector2.from_angle(a0 + TAU / 18.0) * 150.0])
				draw_colored_polygon(wedge, Color(col, a))
			draw_circle(c, 50.0, Color(Palette.GOLD, a))
		1:
			var cols: Array[Color] = [Color.WHITE, Color.YELLOW, Color.CYAN, Color.GREEN, Color.MAGENTA, Color.RED, Color.BLUE]
			for k2: int in cols.size():
				var w: float = SCREEN.size.x / float(cols.size())
				draw_rect(Rect2(SCREEN.position.x + w * float(k2), SCREEN.position.y, w, SCREEN.size.y * 0.7), Color(cols[k2], a))
			draw_circle(c + Vector2(0, 110.0), 30.0, Color(Palette.IVORY, a))
		_:
			draw_circle(c, 140.0, Color(Palette.IVORY, a))
			draw_arc(c, 140.0, 0, TAU, 48, Color(Palette.INK, a), 6.0)
			var hand: float = t * 0.8
			draw_line(c, c + Vector2.from_angle(hand) * 110.0, Color(Palette.INK, a), 6.0)
			draw_line(c, c + Vector2.from_angle(hand * 0.1 - PI * 0.5) * 70.0, Color(Palette.INK, a), 10.0)
