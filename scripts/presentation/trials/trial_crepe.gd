class_name TrialCrepe
extends ThrowTrial
## LA CRÊPE SUZETTE (Cuisines, 2.0) : faire sauter la crêpe. Maintenir arme le coup de poêle,
## relâcher la lance : plus l'élan est fort, plus elle monte et plus elle tourne. Il faut qu'elle
## retombe face dorée en dessous — un demi-tour, puis un tour et demi pour les deux derniers sauts.
## En l'air, elle dérive : déplacer la poêle pour la rattraper. Après le dernier saut, on flambe.
## Note = moyenne des sauts (justesse de la rotation × réception dans la poêle).

enum Phase { READY, CHARGE, FLIGHT, REST, FLAMBE }

const PX3: float = 0.005
const COUNTER_Y: float = 760.0
const PAN_Y: float = 660.0
const PAN_MIN: float = 640.0
const PAN_MAX: float = 1280.0
const PAN_R: float = 95.0
const GAUGE: Rect2 = Rect2(1420.0, 300.0, 34.0, 360.0)
const CREPE_R: float = 0.36

var _phase: Phase = Phase.READY
var _flip: int = 0
var _marks: Array[float] = []
var _charge: float = 0.0
var _pan_x: float = 960.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_x: float = -1.0
var _crepe: Vector2 = Vector2(960.0, PAN_Y)
var _vel: Vector2 = Vector2.ZERO
var _turns: float = 0.0
var _turns_total: float = 0.0
var _flight_t: float = 0.0
var _flight_len: float = 1.0
var _rest: float = 0.0
var _idle: float = 0.0
var _bot_release: bool = false
var _ended: bool = false
var _deco: Dictionary = {}
var _chef: Figure3D = null
var _pan3: Node3D = null
var _crepe3: Node3D = null
var _fire: Array[MeshInstance3D] = []
var _fire_light: OmniLight3D = null


func begin() -> void:
	_build_3d()


func _flips() -> int:
	return pi("flips")


func _target() -> float:
	return pk("target_turns", _flip)


## Tours donnés par une charge c (0..1) : linéaire entre les bornes du réglage.
func _turns_for(c: float) -> float:
	return lerpf(p("turns_min"), p("turns_max"), c)


func _charge_rate() -> float:
	return 1.0 / (p("charge_seconds") * slow)


func press() -> void:
	if _phase == Phase.READY and not _ended:
		_phase = Phase.CHARGE
		_charge = 0.0


func release() -> void:
	if _phase != Phase.CHARGE:
		return
	_turns_total = _turns_for(_charge)
	_flight_len = lerpf(p("flight_min"), p("flight_max"), _charge) * slow
	var drift: float = rng.randf_range(0.5, 1.0) * pk("drift", _flip) * (-1.0 if rng.randf() < 0.5 else 1.0)
	# Dérive bornée : la crêpe retombe toujours au-dessus du feu.
	var land: float = clampf(_pan_x + drift * _flight_len, PAN_MIN + 40.0, PAN_MAX - 40.0)
	_crepe = Vector2(_pan_x, PAN_Y)
	_vel = Vector2((land - _pan_x) / _flight_len, -0.5 * _gravity() * _flight_len)
	_turns = 0.0
	_flight_t = 0.0
	_phase = Phase.FLIGHT
	AudioBus.play("whoosh", 1.2 + 0.3 * _charge, -4.0)


func _gravity() -> float:
	return p("gravity") / (slow * slow)


func tick(dt: float) -> void:
	_move_pan(dt)
	_sync_3d(dt)
	if _ended:
		return
	match _phase:
		Phase.READY:
			_idle += dt
			if _idle > p("idle_seconds") * slow:
				_score_flip(0.0, "TRIAL_CREPE_TOO_LATE")
		Phase.CHARGE:
			_charge = minf(1.0, _charge + _charge_rate() * dt)
			if _bot_release:
				release()
		Phase.FLIGHT:
			_flight_t += dt
			_vel.y += _gravity() * dt
			_crepe += _vel * dt
			_turns = _turns_total * clampf(_flight_t / _flight_len, 0.0, 1.0)
			if _flight_t >= _flight_len:
				_land()
		Phase.REST:
			_rest -= dt
			if _rest <= 0.0:
				_flip += 1
				if _flip >= _flips():
					_phase = Phase.FLAMBE
					_rest = p("flambe_seconds") * slow
					AudioBus.play("fire", 1.0, -2.0)
				else:
					_phase = Phase.READY
					_idle = 0.0
		Phase.FLAMBE:
			_rest -= dt
			if _rest <= 0.0:
				_ended = true
				finish(ThrowTrial.mean(_marks))
	_bot_release = false


func _move_pan(dt: float) -> void:
	var v: float = clampf(held_vector().x + _axis.x, -1.0, 1.0)
	if mouse and _mouse_x >= 0.0:
		_pan_x = move_toward(_pan_x, clampf(_mouse_x, PAN_MIN, PAN_MAX), p("pan_speed") * dt)
	else:
		_pan_x = clampf(_pan_x + v * p("pan_speed") * dt, PAN_MIN, PAN_MAX)
	if _phase == Phase.READY or _phase == Phase.CHARGE:
		_crepe = Vector2(_pan_x, PAN_Y)


## Réception : rotation juste (face dorée dessous) × crêpe dans la poêle.
func _land() -> void:
	var err: float = absf(_turns_total - _target())
	var ok: float = p("turn_ok") * widen()
	var rot_q: float = 1.0 if err <= ok else clampf(1.0 - (err - ok) / maxf(p("turn_miss") - ok, 0.01), 0.0, 1.0)
	var off: float = absf(_crepe.x - _pan_x)
	var r: float = PAN_R * widen()
	var catch_q: float = 1.0 if off <= r else clampf(1.0 - (off - r) / maxf(p("catch_miss") - r, 1.0), 0.0, 1.0)
	var key: String = ""
	if catch_q <= 0.0:
		key = "TRIAL_CREPE_FLOOR"
	elif rot_q < 0.5:
		key = "TRIAL_CREPE_WRONG_SIDE"
	_score_flip(rot_q * catch_q, key)
	AudioBus.play("sticky" if catch_q > 0.0 else "cloth", 1.0, -3.0)


func _score_flip(q: float, key: String) -> void:
	_marks.append(q)
	pop(Vector2(_pan_x, PAN_Y - 160.0), q, key)
	_phase = Phase.REST
	_rest = p("rest_seconds") * slow
	_crepe = Vector2(_pan_x, PAN_Y)
	_turns = 0.0


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_x = mm.position.x
		return true
	if confirm_pressed(event):
		press()
		return true
	if confirm_released(event):
		release()
		return true
	return false


func journal() -> Dictionary:
	return {"flips": _flips(), "marks": _marks}


# --------------------------------------------------------------------------- bot


func bot_wants() -> Dictionary:
	match _phase:
		Phase.READY:
			if absf(_pan_x - 960.0) > 30.0:
				return {"do": "axis", "v": Vector2(clampf((960.0 - _pan_x) / 150.0, -1.0, 1.0), 0)}
			return {"do": "hold"}
		Phase.CHARGE:
			var want_c: float = inverse_lerp(p("turns_min"), p("turns_max"), _target())
			if _charge + _charge_rate() / 60.0 >= want_c:
				return {"do": "release"}
			return {"do": "hold"}
		Phase.FLIGHT:
			var land: float = _crepe.x + _vel.x * (_flight_len - _flight_t)
			return {"do": "axis", "v": Vector2(clampf((land - _pan_x) / 80.0, -1.0, 1.0), 0)}
	return {"do": "axis", "v": Vector2.ZERO}


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2
	match String(w.get("do", "")):
		"hold":
			press()
		"release":
			_bot_release = true
			if _phase == Phase.CHARGE:
				release()


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = KitchenSet.build(st, COUNTER_Y)
	var r: Node3D = st.root
	# Le feu central sous la poêle : couronne de flammes bleues.
	var burner: Vector3 = st.to3(Vector2(960.0, COUNTER_Y), -0.2)
	Stage3D.cylinder(r, 0.32, 0.04, burner + Vector3(0, 0.02, 0), Stage3D.mat(Color("1a1a1e"), 0.6, 0.5))
	for f: int in 12:
		var a: float = TAU * float(f) / 12.0
		var fl: MeshInstance3D = Stage3D.cylinder(r, 0.014, 0.07, burner + Vector3(cos(a) * 0.18, 0.07, sin(a) * 0.18),
			Stage3D.glow(Color(0.3, 0.55, 1.0), 3.0), 0.0)
		(_deco["flames"] as Array[MeshInstance3D]).append(fl)
	_chef = KitchenSet.chef(1.9)
	_chef.position = st.to3(Vector2(960.0, COUNTER_Y), -1.0)
	r.add_child(_chef)
	# Poêle à crêpes en fonte, manche vers le cuisinier.
	_pan3 = Node3D.new()
	r.add_child(_pan3)
	var iron: StandardMaterial3D = Stage3D.mat(Color("202024"), 0.7, 0.35)
	Stage3D.cylinder(_pan3, PAN_R * PX3 * 1.15, 0.03, Vector3.ZERO, iron, PAN_R * PX3 * 1.05)
	var handle: MeshInstance3D = Stage3D.cylinder(_pan3, 0.025, 0.55, Vector3(0, 0.02, -0.42), Stage3D.mat(Color("3a2010"), 0.0, 0.5))
	handle.rotation.x = PI * 0.5 - 0.1
	_crepe3 = Node3D.new()
	r.add_child(_crepe3)
	var gold: StandardMaterial3D = Stage3D.mat(Color("d89a40"), 0.0, 0.6)
	var pale: StandardMaterial3D = Stage3D.mat(Color("f0d8a0"), 0.0, 0.7)
	Stage3D.cylinder(_crepe3, CREPE_R, 0.008, Vector3(0, -0.004, 0), gold)
	Stage3D.cylinder(_crepe3, CREPE_R * 0.99, 0.008, Vector3(0, 0.004, 0), pale)
	for k: int in 6:
		var a2: float = TAU * float(k) / 6.0 + 0.4
		Stage3D.cylinder(_crepe3, 0.04, 0.002, Vector3(cos(a2) * 0.18, -0.009, sin(a2) * 0.18), Stage3D.mat(Color("a0602a"), 0.0, 0.7))
	# Flambée finale : langues de feu orangé au-dessus de la poêle.
	var fire_m: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.55, 0.15), 4.0)
	for k2: int in 9:
		var fl2: MeshInstance3D = Stage3D.cylinder(_pan3, 0.05, 0.4, Vector3((float(k2) - 4.0) * 0.06, 0.2, 0.0), fire_m, 0.0)
		fl2.visible = false
		_fire.append(fl2)
	_fire_light = Stage3D.omni(_pan3, Color(1.0, 0.6, 0.2), 0.0, Vector3(0, 0.4, 0.3), 3.0)


func _sync_3d(dt: float) -> void:
	if _chef == null:
		return
	var st: Stage3D = stage
	var lift: float = 0.0
	if _phase == Phase.CHARGE:
		lift = -_charge * 0.08
	elif _phase == Phase.FLIGHT:
		lift = 0.08 * maxf(0.0, 1.0 - _flight_t * 6.0)
	_pan3.position = st.to3(Vector2(_pan_x, PAN_Y), -0.2) + Vector3(0, lift, 0)
	_pan3.rotation.x = -_charge * 0.35 if _phase == Phase.CHARGE else 0.0
	_crepe3.position = st.to3(_crepe, -0.2) + Vector3(0, 0.03 + (lift if _phase != Phase.FLIGHT else 0.0), 0)
	_crepe3.rotation.x = _turns * TAU
	_chef.position.x = st.to3(Vector2(_pan_x, COUNTER_Y), -1.0).x
	var fl: bool = _phase == Phase.FLAMBE
	for k: int in _fire.size():
		_fire[k].visible = fl
		if fl:
			_fire[k].scale = Vector3(1.0, 0.6 + 0.7 * absf(sin(t * 9.0 + float(k) * 1.3)), 1.0)
	_fire_light.light_energy = 3.0 + sin(t * 20.0) if fl else 0.0
	_chef.animate(&"cheer" if fl else &"carry", t * 2.0, dt, -_charge * 0.5)
	KitchenSet.animate(_deco, st, COUNTER_Y, t, 0.5 + (0.5 if fl else 0.0))


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	pips(Vector2(960.0, 120.0), _marks, _flips())
	if _flip < _flips():
		var key: String = "TRIAL_CREPE_HALF" if _target() < 1.0 else "TRIAL_CREPE_ONE_HALF"
		text(Vector2(960.0, 175.0), tr(key), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	else:
		text(Vector2(960.0, 175.0), tr("TRIAL_CREPE_FLAMBE"), UiKit.SIZE_H2, Color("ff9a3a"))
	# Jauge d'élan : remplit pendant la charge ; graduée en tours (½, 1, 1½).
	draw_rect(GAUGE, Color(Palette.INK, 0.85))
	draw_rect(GAUGE, Palette.GOLD_DARK, false, 2.0)
	var c: float = _charge if _phase == Phase.CHARGE else 0.0
	draw_rect(Rect2(GAUGE.position + Vector2(4, GAUGE.size.y * (1.0 - c)), Vector2(GAUGE.size.x - 8, GAUGE.size.y * c)),
		Palette.GOLD.lerp(Color("ff6a2a"), c))
	for mark: float in [0.5, 1.0, 1.5]:
		var u: float = inverse_lerp(p("turns_min"), p("turns_max"), mark)
		var y: float = GAUGE.end.y - GAUGE.size.y * u
		draw_line(Vector2(GAUGE.position.x - 10, y), Vector2(GAUGE.end.x + 10, y), Color(Palette.IVORY, 0.7), 2.0)
		text(Vector2(GAUGE.end.x + 46, y), "%s" % ["½", "1", "1½"][[0.5, 1.0, 1.5].find(mark)], UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	# Ombre portée de la crêpe en vol : où elle va retomber.
	if _phase == Phase.FLIGHT:
		var land: float = _crepe.x + _vel.x * (_flight_len - _flight_t)
		draw_arc(Vector2(land, PAN_Y + 8.0), 36.0, 0, TAU, 24, Color(Palette.INK, 0.5), 6.0)
