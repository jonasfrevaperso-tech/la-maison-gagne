class_name TrialSafe
extends ThrowTrial
## COFFRE-FORT : le vieux coffre du caissier. Tourner la molette (stick, flèches, molette ou
## glisser à la souris) en écoutant les crans : plus on approche du bon chiffre, plus le
## stéthoscope s'affole. Confirmer pour valider chacun des trois chiffres avant la fin du temps.

const DIAL_N: int = 40
const DIAL_R: float = 92.0

var _codes: Array[int] = []
var _locked: Array[float] = []
var _dial: float = 0.0
var _last_notch: int = 0
var _bot_axis: float = 0.0
var _drag: bool = false
var _open_t: float = -1.0
var _scores: Array[float] = []
## Scène 3D : porte de coffre en acier, molette graduée qui tourne vraiment, voyant du cran.
var _dial3: Node3D = null
var _dial_home: Vector3 = Vector3.ZERO
var _lamp3: StandardMaterial3D = null


func begin() -> void:
	for k: int in pi("numbers"):
		var c: int = rng.randi_range(0, DIAL_N - 1)
		while not _codes.is_empty() and absi(c - _codes[-1]) < 8:
			c = rng.randi_range(0, DIAL_N - 1)
		_codes.append(c)
	_dial = float(rng.randi_range(0, DIAL_N - 1))
	_last_notch = int(round(_dial))
	_build_3d()


func _dial_center() -> Vector2:
	var r: Rect2 = play_rect()
	return Vector2(r.position.x + 185.0, r.get_center().y + 4.0)


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	var r: Rect2 = play_rect()
	st.env.background_color = Color(0.04, 0.04, 0.05)
	st.key.light_energy = 0.5
	st.key.rotation_degrees = Vector3(-35, -40, 0)
	st.frontal(0.005, r.get_center(), r.size.y, 36.0)
	var root: Node3D = st.root
	var px: float = st.px3
	# Mur de la salle des coffres : plaques d'acier rivetées.
	var plate: StandardMaterial3D = Stage3D.mat(Color(0.13, 0.14, 0.16), 0.7, 0.55)
	for k: int in 8:
		var at: Vector3 = st.to3(Vector2(r.position.x + 70.0 + 140.0 * float(k), r.get_center().y), -0.8)
		Stage3D.box(root, Vector3(136.0 * px, r.size.y * px * 1.3, 0.05), at, plate)
		for y: float in [-0.7, 0.7]:
			Stage3D.sphere(root, 0.025, at + Vector3(-0.28, y, 0.04), Stage3D.mat(Color(0.3, 0.3, 0.33), 0.9, 0.3))
	# Le coffre, légèrement de trois quarts.
	var c3: Vector3 = st.to3(_dial_center(), 0.0)
	var body: Node3D = Node3D.new()
	body.position = c3 + Vector3(0, 0, -0.35)
	body.rotation.y = 0.18
	root.add_child(body)
	var steel: StandardMaterial3D = Stage3D.mat(Color(0.24, 0.26, 0.28), 0.8, 0.4)
	Stage3D.box(body, Vector3(300.0 * px, 330.0 * px, 0.7), Vector3.ZERO, steel)
	Stage3D.box(body, Vector3(262.0 * px, 290.0 * px, 0.04), Vector3(0, 0, 0.36), Stage3D.mat(Color(0.3, 0.32, 0.34), 0.85, 0.3))
	for y: float in [-0.45, 0.45]:
		Stage3D.cylinder(body, 0.05, 0.22, Vector3(-150.0 * px, y, 0.3), Stage3D.mat(Palette.GOLD_DARK, 0.9, 0.3))
	for k: int in 4:
		var corner: Vector3 = Vector3((-112.0 if k % 2 == 0 else 112.0) * px, (-120.0 if k < 2 else 120.0) * px, 0.39)
		Stage3D.sphere(body, 0.03, corner, Stage3D.mat(Color(0.5, 0.5, 0.55), 0.9, 0.25))
	var bright: StandardMaterial3D = Stage3D.mat(Color(0.7, 0.7, 0.75), 1.0, 0.2)
	var handle: MeshInstance3D = Stage3D.box(body, Vector3(0.05, 0.4, 0.06), Vector3(118.0 * px, 0, 0.42), bright)
	handle.rotation.z = 0.4
	# Molette : couronne noire, cadran gradué, chiffres en relief, bouton central.
	_dial_home = c3 + Vector3(0, 0, 0.12)
	var bezel: StandardMaterial3D = Stage3D.mat(Color(0.08, 0.08, 0.09), 0.6, 0.4)
	Stage3D.cylinder(root, (DIAL_R + 10.0) * px, 0.06, c3 + Vector3(0, 0, 0.06), bezel).rotation.x = PI * 0.5
	_dial3 = Node3D.new()
	_dial3.position = _dial_home
	root.add_child(_dial3)
	var face: MeshInstance3D = Stage3D.cylinder(_dial3, DIAL_R * px, 0.05, Vector3.ZERO, Stage3D.mat(Color(0.34, 0.35, 0.37), 0.9, 0.25))
	face.rotation.x = PI * 0.5
	var ivory: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.5)
	for n: int in DIAL_N:
		var th: float = PI * 0.5 - TAU * float(n) / float(DIAL_N)
		var big: bool = n % 5 == 0
		var len: float = (14.0 if big else 8.0) * px
		var tick: MeshInstance3D = Stage3D.box(_dial3, Vector3(len, (2.5 if big else 1.5) * px * 2.0, 0.01), Vector3.ZERO, ivory)
		tick.position = Vector3(cos(th), sin(th), 0) * (DIAL_R * px - len * 0.5 - 2.0 * px) + Vector3(0, 0, 0.03)
		tick.rotation.z = th
		if big:
			var at: Vector3 = Vector3(cos(th), sin(th), 0) * (DIAL_R - 32.0) * px + Vector3(0, 0, 0.032)
			var lbl: Label3D = Stage3D.text3d(_dial3, str(n), at, 48, Palette.IVORY)
			lbl.font = UiKit.font("mono")
			lbl.pixel_size = 0.0022
			lbl.rotation.z = th - PI * 0.5
	Stage3D.cylinder(_dial3, 26.0 * px, 0.1, Vector3(0, 0, 0.04), Stage3D.mat(Color(0.18, 0.18, 0.2), 0.9, 0.3)).rotation.x = PI * 0.5
	# Repère doré du haut et voyant qui s'allume quand on approche du cran.
	var mark_at: Vector3 = c3 + Vector3(0, (DIAL_R + 18.0) * px, 0.14)
	var mark: MeshInstance3D = Stage3D.cylinder(root, 0.05, 0.04, mark_at, Stage3D.glow(Palette.GOLD_LIGHT, 1.5), 0.001)
	mark.rotation.z = PI
	_lamp3 = Stage3D.glow(Palette.EMERALD, 0.2)
	Stage3D.sphere(root, 0.05, c3 + Vector3(-110.0 * px, (DIAL_R + 18.0) * px, 0.14), _lamp3)
	Stage3D.omni(root, Color(1.0, 0.9, 0.75), 1.6, c3 + Vector3(0.6, 0.6, 1.4), 4.0)


func _target() -> int:
	return _codes[_locked.size()] if _locked.size() < _codes.size() else 0


## Écart circulaire au bon chiffre (en crans).
func _dist() -> float:
	var d: float = absf(fposmod(_dial - float(_target()) + DIAL_N * 0.5, float(DIAL_N)) - DIAL_N * 0.5)
	return d


func _closeness() -> float:
	return clampf(1.0 - _dist() / 10.0, 0.0, 1.0)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			turn(1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			turn(-1.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			lock()
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if _drag:
			turn(mm.relative.x * 0.08)
		return true
	if confirm_pressed(event):
		lock()
		return true
	return false


func turn(d: float) -> void:
	if _open_t >= 0.0:
		return
	_dial = fposmod(_dial + d, float(DIAL_N))
	var notch: int = int(round(_dial)) % DIAL_N
	if notch != _last_notch:
		_last_notch = notch
		var c: float = _closeness()
		AudioBus.play("tick", 0.8 + c * 0.9, -14.0 + c * 10.0)
		if _dist() < 0.5:
			AudioBus.play("lock", 0.7, -4.0)


func lock() -> void:
	if _open_t >= 0.0 or _locked.size() >= _codes.size():
		return
	var d: float = _dist()
	var tol: float = p("tolerance") * widen()
	var sc: float = 1.0 if d <= tol * 0.5 else clampf(1.0 - (d - tol * 0.5) / p("falloff"), 0.0, 1.0)
	_locked.append(_dial)
	_scores.append(sc)
	pop(Vector2(_slot_x(_locked.size() - 1), 70.0), sc)
	AudioBus.play("vault" if sc >= 0.7 else "clang", 1.0, -4.0)
	if _locked.size() >= _codes.size():
		_open_t = 0.0


func _time_left() -> float:
	return p("time_limit") * slow - t


func tick(dt: float) -> void:
	if _open_t >= 0.0:
		_open_t += dt
		if _open_t > 0.9:
			var vals: Array[float] = _scores.duplicate()
			while vals.size() < _codes.size():
				vals.append(0.0)
			finish(mean(vals))
		return
	var v: float = held_vector().x + _bot_axis
	if absf(v) > 0.0:
		turn(v * p("dial_speed") * dt * (0.35 if absf(v) < 0.6 else 1.0))
	if _time_left() <= 0.0:
		AudioBus.play("error", 0.8)
		_open_t = 0.0


func bot_wants() -> Dictionary:
	if _open_t >= 0.0:
		return {"do": ""}
	var d: float = fposmod(float(_target()) - _dial + DIAL_N * 0.5, float(DIAL_N)) - DIAL_N * 0.5
	if absf(d) < 0.25:
		return {"do": "confirm"}
	return {"do": "axis", "v": Vector2(clampf(d * 0.8, -1.0, 1.0), 0)}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			_bot_axis = 0.0
			lock()
		"axis":
			_bot_axis = (w["v"] as Vector2).x
		_:
			_bot_axis = 0.0


func _slot_x(k: int) -> float:
	return size.x * 0.52 + float(k) * 92.0


func paint() -> void:
	var r: Rect2 = play_rect()
	# Molette 3D : rotation réelle, tremblement quand le stéthoscope s'affole.
	if _dial3 != null:
		var shake: Vector3 = Vector3(sin(t * 60.0), cos(t * 53.0), 0) * 0.008 * _closeness() * _closeness()
		_dial3.position = _dial_home + shake
		_dial3.rotation.z = TAU * _dial / float(DIAL_N)
		_lamp3.emission_energy_multiplier = 0.2 + 3.0 * _closeness() * _closeness()
		_lamp3.emission = Palette.EMERALD.lerp(Palette.GOLD_LIGHT, _closeness())
	# Combinaison : trois cases, chiffre en cours qui clignote.
	for k: int in _codes.size():
		var box: Rect2 = Rect2(Vector2(_slot_x(k) - 36.0, r.position.y + 96.0), Vector2(72, 64))
		draw_rect(box, Palette.VELVET_DEEP)
		var col: Color = Palette.GOLD_DARK
		var lbl2: String = "--"
		if k < _locked.size():
			lbl2 = "%02d" % (int(round(_locked[k])) % DIAL_N)
			col = GRADE_COLORS[int(ThrowSkill.beat_grade(_scores[k]))]
		elif k == _locked.size():
			col = Color(Palette.CYAN, 0.6 + 0.4 * sin(t * 6.0))
		draw_rect(box, col, false, 3.0)
		text(box.get_center(), lbl2, UiKit.SIZE_H2, Palette.IVORY, "mono", 0)
	# Stéthoscope : jauge de proximité qui s'affole.
	var meter: Rect2 = Rect2(Vector2(size.x * 0.52 - 36.0, r.position.y + 190.0), Vector2(256.0, 16.0))
	draw_rect(meter, Palette.VELVET_DEEP)
	var jitter: float = 0.05 * sin(t * 47.0) * _closeness()
	var fill: float = meter.size.x * clampf(_closeness() + jitter, 0.0, 1.0)
	draw_rect(Rect2(meter.position, Vector2(fill, meter.size.y)), Palette.EMERALD.lerp(Palette.GOLD_LIGHT, _closeness()))
	text(Vector2(meter.position.x + meter.size.x * 0.5, meter.position.y - 14.0), tr("TRIAL_SAFE_LISTEN"), UiKit.SIZE_SMALL, Palette.SMOKE)
	var tl: float = clampf(_time_left() / (p("time_limit") * slow), 0.0, 1.0)
	var secs: String = "%d s" % ceili(maxf(_time_left(), 0.0))
	text(Vector2(r.end.x - 70.0, r.position.y + 40.0), secs, UiKit.SIZE_BODY, Palette.GOLD if tl > 0.3 else Palette.DANGER, "mono")
