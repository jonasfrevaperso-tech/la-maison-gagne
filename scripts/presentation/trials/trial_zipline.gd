class_name TrialZipline
extends ThrowTrial
## LA TYROLIENNE (Toits, 2.0) : d'un toit à l'autre, suspendu à une poulie. Le câble ploie : on
## prend de la vitesse dans la descente, puis le dernier tronçon remonte vers la plateforme
## d'en face. Maintenir freine — mais le frein chauffe et perd de son mordant : mieux vaut
## freiner par à-coups. Il faut s'arrêter pile sur le repère doré : trop court, on redescend
## au creux du câble ; trop vite, on percute le butoir. Trois lignes, vent annoncé par les fanions.
## Note = moyenne des lignes (écart au repère à l'arrêt ; butoir : une petite part).

const PX3: float = 0.005
const SCREEN_X: float = 760.0
const START: Vector2 = Vector2(300.0, 300.0)
const SEGMENTS: int = 40

var _line: int = 0
var _len: float = 2000.0
var _drop: float = 400.0
var _sag: float = 260.0
var _target_s: float = 1800.0
var _wind: float = 0.0
var _s: float = 0.0
var _v: float = 0.0
var _heat: float = 0.0
var _braking: bool = false
var _still: float = 0.0
var _rest: float = 0.0
var _started: float = 0.0
var _marks: Array[float] = []
var _ended: bool = false
var _deco: Dictionary = {}
var _rider: Figure3D = null
var _trolley: Node3D = null
var _cable: Node3D = null
var _far_roof: Node3D = null
var _flags: Array[Node3D] = []


func begin() -> void:
	_build_3d()
	_new_line()


func _lines() -> int:
	return pi("lines")


## Ligne k : longueur, dénivelé, flèche du câble et vent tirés dans les bornes du réglage.
func _new_line() -> void:
	_len = pk("length", _line)
	_drop = pk("drop", _line)
	_sag = pk("sag", _line)
	_wind = rng.randf_range(p("wind_min"), p("wind_max")) * (-1.0 if rng.randf() < 0.5 else 1.0)
	_target_s = _len - p("target_back")
	_s = 0.0
	_v = p("push")
	_heat = 0.0
	_still = 0.0
	_started = t
	# Équité : le repère reste atteignable en laissant filer (vent de face compris).
	var free_stop: float = _predict(false)
	if free_stop < _target_s + p("fair_margin"):
		_target_s = free_stop - p("fair_margin")
	_rebuild_line()


## Hauteur du câble (pixels, vers le bas) à l'abscisse curviligne s : pente + flèche, puis le
## dernier tronçon remonte (fin du câble au-dessus du creux).
func height(s: float) -> float:
	var u: float = clampf(s / _len, 0.0, 1.0)
	return START.y + _drop * u + 4.0 * _sag * u * (1.0 - u) - p("end_rise") * pow(u, 6.0)


func slope(s: float) -> float:
	return (height(s + 2.0) - height(s - 2.0)) / 4.0


## Accélération le long du câble ; `brake` : frein serré.
func accel(s: float, v: float, heat: float, brake: bool) -> float:
	var k: float = slope(s)
	var a: float = p("gravity") * k / sqrt(1.0 + k * k) + _wind - p("drag") * v * absf(v)
	if brake and absf(v) > 0.5:
		a -= signf(v) * p("brake") * (1.0 - heat)
	return a


## Un pas de physique : (s, v, échauffement) après h secondes. Frein serré presque à l'arrêt :
## il retient (adhérence) tant qu'il est plus fort que la pente et le vent.
func advance(s: float, v: float, heat: float, brake: bool, h: float) -> Vector3:
	var hold: float = p("brake") * (1.0 - heat)
	if brake and absf(v) < p("stop_speed") and absf(accel(s, 0.0, heat, false)) <= hold:
		return Vector3(s, 0.0, maxf(0.0, heat - p("cool_rate") * h))
	var v2: float = v + accel(s, v, heat, brake) * h
	if brake and absf(v) > 0.5 and signf(v2) != signf(v):
		v2 = 0.0  # le frein arrête, il ne fait pas reculer
	var heat2: float = heat
	if brake and absf(v2) > 0.5:
		heat2 = minf(1.0, heat + p("heat_rate") * absf(v2) / 400.0 * h)
	else:
		heat2 = maxf(0.0, heat - p("cool_rate") * h)
	return Vector3(s + v2 * h, v2, heat2)


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_line += 1
			if _line >= _lines():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_line()
		return
	var h: float = dt / slow
	var st: Vector3 = advance(_s, _v, _heat, _braking, h)
	_s = st.x
	_v = st.y
	_heat = st.z
	if _s >= _len:
		_s = _len
		var crash: float = absf(_v)
		_v = 0.0
		AudioBus.play("decor_topple", 1.0, -2.0)
		var soft: float = clampf(p("buffer_share") * (1.0 - crash / p("crash_speed")), 0.0, p("buffer_share"))
		_score_line(soft, "TRIAL_ZIPLINE_BUFFER")
		return
	_s = maxf(_s, 0.0)
	_still = _still + h if absf(_v) < p("stop_speed") else 0.0
	var timed_out: bool = t - _started > p("line_limit") * slow
	if _still >= p("stop_seconds") or timed_out:
		var err: float = absf(_s - _target_s)
		var tol: float = p("tolerance") * widen()
		var q: float = 1.0 if err <= tol else clampf(1.0 - (err - tol) / (p("miss") - tol), 0.0, 1.0)
		var key: String = "TRIAL_ZIPLINE_PILE"
		if q < 0.95:
			key = "TRIAL_ZIPLINE_SHORT" if _s < _target_s else "TRIAL_ZIPLINE_LONG"
		_score_line(q, key)


func _score_line(q: float, key: String) -> void:
	_marks.append(q)
	_rest = p("rest_seconds") * slow
	_braking = false
	pop(Vector2(SCREEN_X, height(_s) - 180.0), q, key)
	AudioBus.play("chime" if q >= 0.6 else "lose_soft", 1.0, -4.0)


func press() -> void:
	if _rest <= 0.0 and not _ended:
		_braking = true


func release() -> void:
	_braking = false


func handle(event: InputEvent) -> bool:
	if confirm_pressed(event):
		press()
		return true
	if confirm_released(event):
		release()
		return true
	return false


func journal() -> Dictionary:
	return {"lines": _marks.size(), "heat": snappedf(_heat, 0.01)}


# --------------------------------------------------------------------------- bot


## Freine le plus tard possible : si, en serrant dès maintenant (échauffement compris), on
## s'arrêterait encore au-delà du repère, il faut serrer ; sinon on laisse filer.
func bot_wants() -> Dictionary:
	if _rest > 0.0 or _ended:
		return {"do": "release"} if _braking else {"do": ""}
	var want: bool = _predict(true) > _target_s + p("bot_margin")
	if _v < 0.0 or _s > _target_s - p("tolerance") * 0.5 and absf(_v) < p("stop_speed") * 3.0:
		want = _s >= _target_s - p("tolerance") * 0.5  # au repère : on tient le frein
	if want and not _braking:
		return {"do": "hold"}
	if not want and _braking:
		return {"do": "release"}
	return {"do": ""}


## Point d'arrêt prévu (abscisse) depuis l'état présent, frein serré ou relâché tout du long.
func _predict(brake: bool) -> float:
	var st: Vector3 = Vector3(_s, _v, _heat)
	var h: float = 1.0 / 30.0
	for _k: int in 360:
		st = advance(st.x, st.y, st.z, brake, h)
		if st.x >= _len:
			return _len + absf(st.y)
		if absf(st.y) < 0.5 or st.y < 0.0:
			return st.x
	return st.x


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"hold":
			press()
		"release":
			release()


# --------------------------------------------------------------------------- décor 3D


func _x_at(s: float) -> float:
	return START.x + s * 0.98


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 42.0)
	var longest: float = 0.0
	for k: int in _lines():
		longest = maxf(longest, pk("length", k))
	_deco = RooftopSet.build(st, 1010.0, [1100.0, 1900.0], 41, longest + 1600.0)
	var r: Node3D = st.root
	# Toit de départ : plateforme, pylône, et un aide qui pousse au départ.
	var wood: StandardMaterial3D = Stage3D.mat(Color("6a4422"), 0.0, 0.6)
	var steel: StandardMaterial3D = Stage3D.mat(Color("3a3e48"), 0.7, 0.4)
	Stage3D.box(r, Vector3(1.6, 0.1, 1.0), st.to3(Vector2(START.x - 80.0, START.y + 340.0), -0.2), wood)
	Stage3D.box(r, Vector3(1.6, 3.6, 0.8), st.to3(Vector2(START.x - 80.0, START.y + 700.0), -0.4), Stage3D.mat(Color("c8b89a"), 0.0, 0.85))
	Stage3D.box(r, Vector3(0.12, 2.0, 0.12), st.to3(Vector2(START.x - 20.0, START.y + 150.0), -0.1), steel)
	_cable = Node3D.new()
	r.add_child(_cable)
	_far_roof = Node3D.new()
	r.add_child(_far_roof)
	_trolley = Node3D.new()
	r.add_child(_trolley)
	var wheel: MeshInstance3D = Stage3D.cylinder(_trolley, 0.09, 0.05, Vector3.ZERO, Stage3D.mat(Color("c8ccd4"), 0.9, 0.25))
	wheel.rotation.x = PI * 0.5
	Stage3D.box(_trolley, Vector3(0.06, 0.4, 0.04), Vector3(0, -0.22, 0), steel)
	_rider = Figure3D.new().build(1.6, {"coat": Color("c83a2a"), "trousers": Color("2a2a34"), "hat": "", "hair": Color("3a2416")})
	_trolley.add_child(_rider)
	_rider.position = Vector3(0, -1.95, 0)
	_rider.rotation.y = PI * 0.5  # face au sens de la marche


## Câble (tronçons), toit d'arrivée, plateforme, repère doré, butoir, fanions de vent.
func _rebuild_line() -> void:
	var st: Stage3D = stage
	for n: Node in _cable.get_children():
		n.queue_free()
	for n2: Node in _far_roof.get_children():
		n2.queue_free()
	_flags.clear()
	var steel_m: StandardMaterial3D = Stage3D.mat(Color("8a8c94"), 0.8, 0.3)
	for k: int in SEGMENTS:
		var s0: float = _len * float(k) / float(SEGMENTS)
		var s1: float = _len * float(k + 1) / float(SEGMENTS)
		var a: Vector3 = st.to3(Vector2(_x_at(s0), height(s0)), 0.0)
		var b: Vector3 = st.to3(Vector2(_x_at(s1), height(s1)), 0.0)
		var seg: MeshInstance3D = Stage3D.cylinder(_cable, 0.012, a.distance_to(b), (a + b) * 0.5, steel_m)
		seg.rotation.z = atan2(b.y - a.y, b.x - a.x) - PI * 0.5
	var end_x: float = _x_at(_len)
	var plat_y: float = height(_target_s) + 440.0  # sous les pieds du voyageur à l'arrêt
	var wood: StandardMaterial3D = Stage3D.mat(Color("6a4422"), 0.0, 0.6)
	var deck_w: float = (_len - _target_s + 300.0) * PX3
	var deck_at: Vector3 = st.to3(Vector2(end_x - (_len - _target_s + 300.0) * 0.5 + 60.0, plat_y), -0.2)
	Stage3D.box(_far_roof, Vector3(deck_w, 0.1, 1.0), deck_at, wood)
	var house_at: Vector3 = st.to3(Vector2(end_x - (_len - _target_s) * 0.5, plat_y + 610.0), -0.45)
	Stage3D.box(_far_roof, Vector3(deck_w + 0.6, 6.0, 0.8), house_at, Stage3D.mat(Color("b8a88a"), 0.0, 0.85))
	var pylon_at: Vector3 = st.to3(Vector2(end_x + 30.0, height(_len) + 80.0), -0.1)
	Stage3D.box(_far_roof, Vector3(0.14, 2.6, 0.14), pylon_at, Stage3D.mat(Color("3a3e48"), 0.7, 0.4))
	# Butoir : matelas rouge au bout du câble.
	var pad_at: Vector3 = st.to3(Vector2(end_x - 10.0, height(_len) + 40.0), 0.0)
	Stage3D.box(_far_roof, Vector3(0.35, 0.9, 0.7), pad_at, Stage3D.mat(Palette.ROULETTE_RED, 0.0, 0.8))
	# Repère doré à l'aplomb de l'arrêt idéal.
	var mark_x: float = _x_at(_target_s)
	Stage3D.box(_far_roof, Vector3(0.06, 0.3, 1.02), st.to3(Vector2(mark_x, plat_y - 20.0), -0.2), Stage3D.glow(Palette.GOLD_LIGHT, 2.0))
	var post_at: Vector3 = st.to3(Vector2(mark_x, (plat_y + height(_target_s)) * 0.5), -0.25)
	Stage3D.box(_far_roof, Vector3(0.03, 1.8, 0.03), post_at, Stage3D.glow(Palette.GOLD_LIGHT, 0.7))
	# Fanions de vent le long de la ligne.
	for k2: int in 4:
		var fx: float = START.x + 300.0 + float(k2) * (_len - 400.0) / 3.0
		var pole: Node3D = Node3D.new()
		pole.position = st.to3(Vector2(fx, height(fx - START.x) - 60.0), 0.0)
		_far_roof.add_child(pole)
		Stage3D.cylinder(pole, 0.01, 0.4, Vector3(0, 0.2, 0), Stage3D.mat(Color("c8ccd4"), 0.9, 0.3))
		Stage3D.box(pole, Vector3(0.3, 0.14, 0.01), Vector3(0.15, 0.33, 0), Stage3D.mat(Color("ffd23f"), 0.0, 0.6))
		_flags.append(pole)


func _sync_3d(dt: float) -> void:
	if _rider == null:
		return
	var st: Stage3D = stage
	var x: float = _x_at(_s)
	var target_cam: float = (x + (960.0 - SCREEN_X) - 960.0) * PX3
	st.cam.position.x = lerpf(st.cam.position.x, target_cam, minf(1.0, dt * 6.0))
	(_deco["far"] as Node3D).position.x = st.cam.position.x * 0.9
	_trolley.position = st.to3(Vector2(x, height(_s) - 8.0), 0.05)
	var lean: float = clampf(-_v / 900.0, -0.5, 0.5)
	_trolley.rotation.z = lerpf(_trolley.rotation.z, lean, minf(1.0, dt * 4.0))
	_rider.animate(&"hang", t * 2.0, dt, 1.0 if _braking else 0.0)
	for f: Node3D in _flags:
		f.rotation.y = 0.0 if _wind >= 0.0 else PI
		var flag: Node3D = f.get_child(1) as Node3D
		flag.rotation.x = sin(t * (6.0 + absf(_wind) * 0.05)) * 0.3
	RooftopSet.animate(_deco, st, t, _wind)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Échauffement du frein, vitesse, ligne en cours, vent.
	var gauge: Rect2 = Rect2(90.0, 300.0, 30.0, 300.0)
	draw_rect(gauge, Color(Palette.INK, 0.85))
	var hcol: Color = Color(0.3, 0.6, 1.0).lerp(Palette.ROULETTE_RED, _heat)
	var fill: Rect2 = Rect2(gauge.position + Vector2(0, gauge.size.y * (1.0 - _heat)), Vector2(gauge.size.x, gauge.size.y * _heat))
	draw_rect(fill, hcol)
	text(Vector2(105.0, gauge.end.y + 30.0), tr("TRIAL_ZIPLINE_HEAT"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	if _braking:
		text(Vector2(105.0, gauge.position.y - 30.0), tr("TRIAL_ZIPLINE_BRAKE"), UiKit.SIZE_SMALL, Palette.GOLD_LIGHT, "body", 4)
	var arrow: float = signf(_wind) * clampf(absf(_wind) / p("wind_max"), 0.2, 1.0) * 70.0
	var wc: Vector2 = Vector2(1760.0, 160.0)
	draw_line(wc - Vector2(arrow, 0), wc + Vector2(arrow, 0), Palette.IVORY, 5.0)
	var head: PackedVector2Array = PackedVector2Array([wc + Vector2(arrow, -12), wc + Vector2(arrow + signf(arrow) * 20.0, 0),
		wc + Vector2(arrow, 12)])
	draw_colored_polygon(head, Palette.IVORY)
	text(wc + Vector2(0, 40.0), tr("TRIAL_ZIPLINE_WIND"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	var status: String = tr("TRIAL_ZIPLINE_STATUS") % [mini(_line + 1, _lines()), _lines()]
	text(Vector2(960.0, 105.0), status, UiKit.SIZE_BODY, Palette.IVORY)
