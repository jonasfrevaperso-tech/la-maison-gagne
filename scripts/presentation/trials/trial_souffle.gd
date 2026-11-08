class_name TrialSouffle
extends ThrowTrial
## LE SOUFFLÉ (Cuisines, 2.0) : tenir le four dans la bonne zone pendant la cuisson. Le bouton du
## gaz (stick haut / bas, ou glisser) règle la flamme, mais le four a de l'inertie : la résistance
## chauffe d'abord, puis l'air du four suit, et la température continue de monter après qu'on a
## baissé. La recette change de palier (préchauffe, montée, finition), annoncés à l'avance sur la
## frise ; un commis ouvre la porte une fois (annoncé), l'air retombe d'un coup.
## Note = part du temps passé dans la zone (avec une tolérance douce), après une courte mise en route.

const PX3: float = 0.005
const COUNTER_Y: float = 820.0
const GAUGE_C: Vector2 = Vector2(1500.0, 420.0)
const GAUGE_R: float = 170.0
const T_MIN: float = 100.0
const T_MAX: float = 260.0
const STRIP: Rect2 = Rect2(360.0, 130.0, 1200.0, 46.0)
const OVEN_X: float = 760.0
const OVEN_W: float = 560.0
const OVEN_H: float = 400.0

var _valve: float = 0.5
var _heater: float = 0.0
var _temp: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _drag: bool = false
var _rise: float = 0.0
var _samples: Array[float] = []
var _door_done: bool = false
var _door_open: float = 0.0
var _ended: bool = false
var _deco: Dictionary = {}
var _commis: Figure3D = null
var _glow_light: OmniLight3D = null
var _element: MeshInstance3D = null
var _knob: Node3D = null
var _dome: MeshInstance3D = null
var _door: Node3D = null


func begin() -> void:
	_heater = p("start_temp")
	_temp = p("start_temp")
	_valve = p("start_temp") / p("heat_max")
	_build_3d()


func _total() -> float:
	var s: float = 0.0
	for d: float in _durations():
		s += d
	return s * slow


func _durations() -> Array[float]:
	var out: Array[float] = []
	for v: Variant in Balance.arr("throw_trials.%s.step_seconds" % String(entry["id"])):
		out.append(float(v))
	return out


## Consigne à l'instant `at` (secondes de jeu).
func _target_at(at: float) -> float:
	var acc: float = 0.0
	var steps: Array[float] = _durations()
	for k: int in steps.size():
		acc += steps[k] * slow
		if at < acc:
			return pk("step_target", k)
	return pk("step_target", steps.size() - 1)


func _door_t() -> float:
	return p("door_at") * slow


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	# Bouton du gaz : le stick le tourne, il reste où on le laisse.
	var turn: float = -(held_vector().y + _axis.y)
	_valve = clampf(_valve + clampf(turn, -1.0, 1.0) * dt / (p("knob_seconds") * slow), 0.0, 1.0)
	# Deux étages d'inertie : résistance puis air du four.
	_heater += (_valve * p("heat_max") - _heater) * minf(1.0, dt * p("k_heater") / slow)
	_temp += (_heater - _temp) * minf(1.0, dt * p("k_oven") / slow)
	if not _door_done and t >= _door_t():
		_door_done = true
		_door_open = 1.0
		_temp -= p("door_drop")
		AudioBus.play("decor_creak", 0.8, -3.0)
		pop(Vector2(OVEN_X, 300.0), 0.0, "TRIAL_SOUFFLE_DOOR")
	_door_open = maxf(0.0, _door_open - dt / (p("door_seconds") * slow))
	var err: float = absf(_temp - _target_at(t))
	var band: float = p("band")
	var q: float = 1.0 if err <= band else clampf(1.0 - (err - band) / (band * p("soft")), 0.0, 1.0)
	if t >= p("grace") * slow:
		_samples.append(q)
		_rise = clampf(_rise + (q - 0.45) * dt / (p("rise_seconds") * slow), 0.0, 1.0)
	if t >= _total():
		_ended = true
		var s: float = ThrowTrial.mean(_samples) if not _samples.is_empty() else 0.0
		pop(Vector2(OVEN_X, 360.0), s, "TRIAL_SOUFFLE_DONE")
		AudioBus.play("chime" if s >= 0.6 else "lose_soft", 1.0, -3.0)
		finish(s)


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_drag = mb.pressed
		if mb.pressed:
			_set_from_y(mb.position.y)
		return true
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		if _drag:
			_set_from_y(mm.position.y)
		return true
	return false


## Glisser : la hauteur du pointeur règle directement le bouton (haut = fort).
func _set_from_y(y: float) -> void:
	_valve = clampf(1.0 - (y - 220.0) / 640.0, 0.0, 1.0)


func journal() -> Dictionary:
	return {"valve": snappedf(_valve, 0.01), "temp": snappedf(_temp, 0.1)}


# --------------------------------------------------------------------------- bot


## Anticipe : vise la consigne d'un peu plus tard (inertie), corrige par l'écart et la pente,
## et monte la flamme juste avant l'ouverture annoncée de la porte.
func bot_wants() -> Dictionary:
	var ahead: float = t + p("bot_lead") * slow
	var goal: float = _target_at(ahead)
	if not _door_done and _door_t() - t < p("bot_lead") * slow and _door_t() - t > 0.0:
		goal += p("door_drop") * p("bot_door_boost")
	var slope: float = (_heater - _temp) * p("k_oven")
	var want: float = (goal + p("bot_kp") * (goal - _temp) - p("bot_kd") * slope) / p("heat_max")
	want = clampf(want, 0.0, 1.0)
	return {"do": "axis", "v": Vector2(0.0, -clampf((want - _valve) * p("bot_gain"), -1.0, 1.0))}


func bot_apply(w: Dictionary) -> void:
	_axis = w.get("v", Vector2.ZERO) as Vector2


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = KitchenSet.build(st, COUNTER_Y, false)
	var r: Node3D = st.root
	# Le four : caisson noir émaillé, liserés laiton, porte vitrée, plaque « La Maison ».
	var enamel: StandardMaterial3D = Stage3D.mat(Color("1c1a1e"), 0.3, 0.35)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.8, 0.3)
	var top: float = COUNTER_Y - OVEN_H - 80.0
	var c: Vector3 = st.to3(Vector2(OVEN_X, COUNTER_Y - OVEN_H * 0.5 - 40.0), -0.7)
	# Caisson creux : dos, flancs, dessus, sole et cadre avant (on voit l'intérieur par la vitre).
	var ow: float = OVEN_W * PX3 * 1.25
	var oh: float = OVEN_H * PX3 * 1.35
	Stage3D.box(r, Vector3(ow, oh, 0.05), c + Vector3(0, 0, -0.5), enamel)
	for side2: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(0.06, oh, 1.0), c + Vector3(side2 * ow * 0.5, 0, 0), enamel)
		Stage3D.box(r, Vector3(ow, 0.06, 1.0), c + Vector3(0, side2 * oh * 0.5, 0), enamel)
		Stage3D.box(r, Vector3((ow - OVEN_W * PX3 * 1.1) * 0.5, oh, 0.05), c + Vector3(side2 * (ow + OVEN_W * PX3 * 1.1) * 0.25, 0, 0.5), enamel)
	Stage3D.box(r, Vector3(ow, (oh - OVEN_H * PX3) * 0.5, 0.05), c + Vector3(0, (oh + OVEN_H * PX3) * 0.25, 0.5), enamel)
	Stage3D.box(r, Vector3(OVEN_W * PX3 * 1.27, 0.03, 1.02), st.to3(Vector2(OVEN_X, top), -0.7), brass)
	# Intérieur : parois chaudes, grille, résistance, ramequin et soufflé.
	var inner: StandardMaterial3D = Stage3D.mat(Color("3a2416"), 0.0, 0.8)
	Stage3D.box(r, Vector3(OVEN_W * PX3, OVEN_H * PX3 * 0.8, 0.05), c + Vector3(0, 0, -0.45), inner)
	var el_at: Vector3 = c + Vector3(0, OVEN_H * PX3 * 0.35, -0.3)
	_element = Stage3D.cylinder(r, 0.012, OVEN_W * PX3 * 0.85, el_at, Stage3D.glow(Color(1.0, 0.3, 0.05), 0.5))
	_element.rotation.z = PI * 0.5
	var shelf: Vector3 = c + Vector3(0, -OVEN_H * PX3 * 0.22, -0.15)
	for k: int in 7:
		var bar_at: Vector3 = shelf + Vector3(0, 0, -0.3 + 0.1 * float(k))
		var bar: MeshInstance3D = Stage3D.cylinder(r, 0.006, 0.7, bar_at, Stage3D.mat(Color("8a8c94"), 0.9, 0.3))
		bar.rotation.z = PI * 0.5
	var ramekin: StandardMaterial3D = Stage3D.mat(Color("f8f6f0"), 0.0, 0.25)
	Stage3D.cylinder(r, 0.24, 0.22, shelf + Vector3(0, 0.11, 0), ramekin)
	for k2: int in 16:
		var a: float = TAU * float(k2) / 16.0
		Stage3D.box(r, Vector3(0.02, 0.2, 0.02), shelf + Vector3(cos(a) * 0.245, 0.11, sin(a) * 0.245), ramekin)
	_dome = Stage3D.sphere(r, 0.23, shelf + Vector3(0, 0.22, 0), Stage3D.mat(Color("e8b860"), 0.0, 0.7))
	_glow_light = Stage3D.omni(r, Color(1.0, 0.55, 0.2), 0.5, c + Vector3(0, 0.3, 0.0), 2.5)
	# Porte vitrée (pivote vers le bas quand le commis l'ouvre).
	_door = Node3D.new()
	r.add_child(_door)
	_door.position = c + Vector3(0, -OVEN_H * PX3 * 0.5, 0.52)
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.35, 0.22, 0.12, 0.18), 0.2, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Stage3D.box(_door, Vector3(OVEN_W * PX3 * 1.1, OVEN_H * PX3, 0.03), Vector3(0, OVEN_H * PX3 * 0.5, 0), glass)
	for side: float in [-1.0, 1.0]:
		Stage3D.box(_door, Vector3(0.05, OVEN_H * PX3, 0.04), Vector3(side * OVEN_W * PX3 * 0.55, OVEN_H * PX3 * 0.5, 0), brass)
	var handle: MeshInstance3D = Stage3D.cylinder(_door, 0.025, OVEN_W * PX3 * 0.9, Vector3(0, OVEN_H * PX3 + 0.05, 0.08), brass)
	handle.rotation.z = PI * 0.5
	# Bouton du gaz, à droite du four.
	_knob = Node3D.new()
	r.add_child(_knob)
	_knob.position = st.to3(Vector2(OVEN_X + OVEN_W * 0.5 + 130.0, COUNTER_Y - 250.0), -0.15)
	var dial: MeshInstance3D = Stage3D.cylinder(_knob, 0.17, 0.06, Vector3.ZERO, Stage3D.mat(Color("2a2a30"), 0.4, 0.4))
	dial.rotation.x = PI * 0.5
	Stage3D.box(_knob, Vector3(0.04, 0.16, 0.05), Vector3(0, 0.07, 0.05), brass)
	# Le commis attend près de la porte : il viendra l'ouvrir.
	_commis = KitchenSet.chef(1.7, true)
	_commis.position = st.to3(Vector2(160.0, COUNTER_Y + 40.0), 0.4)
	r.add_child(_commis)


func _sync_3d(dt: float) -> void:
	if _commis == null:
		return
	var heat: float = clampf((_heater - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0)
	(_element.material_override as StandardMaterial3D).emission_energy_multiplier = 0.3 + 4.0 * heat
	_glow_light.light_energy = 0.3 + 2.2 * clampf((_temp - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0)
	_knob.rotation.z = lerpf(PI * 0.75, -PI * 0.75, _valve)
	_dome.scale = Vector3(1.0, 0.25 + 1.4 * _rise, 1.0)
	var burnt: float = clampf((_temp - 200.0) / 60.0, 0.0, 1.0)
	(_dome.material_override as StandardMaterial3D).albedo_color = Color("f0d08a").lerp(Color("8a4a1a"), burnt)
	_door.rotation.x = _door_open * 1.1
	# Le commis s'approche avant l'ouverture, ouvre, puis repart.
	var st: Stage3D = stage
	var until: float = _door_t() - t
	var near: bool = until < p("door_warn") * slow and (until > 0.0 or _door_open > 0.0)
	var goal_x: float = (st.to3(Vector2(OVEN_X - OVEN_W * 0.5 - 60.0, 0.0)) if near else st.to3(Vector2(160.0, 0.0))).x
	var dx: float = goal_x - _commis.position.x
	_commis.position.x += clampf(dx, -dt * 1.6, dt * 1.6)
	_commis.rotation.y = 0.0 if absf(dx) < 0.05 else signf(dx) * PI * 0.5
	if absf(dx) >= 0.05:
		_commis.animate(&"walk", t * 3.0, dt)
	elif _door_open > 0.0 or (near and until < 0.6 * slow):
		_commis.animate(&"point", 0.0, dt, 1.0)
	else:
		_commis.animate(&"idle", t, dt)
	KitchenSet.animate(_deco, st, COUNTER_Y, t, _valve)


# --------------------------------------------------------------------------- dessin


func _angle(temp: float) -> float:
	return lerpf(PI * 0.8, PI * 2.2, clampf((temp - T_MIN) / (T_MAX - T_MIN), 0.0, 1.0))


func paint() -> void:
	# Thermomètre à cadran : zone verte autour de la consigne, aiguille du four, repère de la flamme.
	draw_circle(GAUGE_C, GAUGE_R + 16.0, Color(Palette.INK, 0.88))
	draw_arc(GAUGE_C, GAUGE_R + 16.0, 0, TAU, 64, Palette.GOLD, 4.0)
	draw_arc(GAUGE_C, GAUGE_R - 10.0, PI * 0.8, PI * 2.2, 64, Color(Palette.IVORY, 0.25), 18.0)
	var goal: float = _target_at(t)
	var band: float = p("band")
	draw_arc(GAUGE_C, GAUGE_R - 10.0, _angle(goal - band), _angle(goal + band), 24, Palette.EMERALD, 18.0)
	var soft: float = band * (1.0 + p("soft"))
	var faint: Color = Color(Palette.EMERALD, 0.35)
	draw_arc(GAUGE_C, GAUGE_R - 10.0, _angle(goal - soft), _angle(goal - band), 12, faint, 18.0)
	draw_arc(GAUGE_C, GAUGE_R - 10.0, _angle(goal + band), _angle(goal + soft), 12, faint, 18.0)
	for k: int in 9:
		var v: float = T_MIN + (T_MAX - T_MIN) * float(k) / 8.0
		var a: float = _angle(v)
		var u: Vector2 = Vector2.from_angle(a)
		draw_line(GAUGE_C + u * (GAUGE_R - 34.0), GAUGE_C + u * (GAUGE_R - 22.0), Palette.IVORY, 3.0)
		if k % 2 == 0:
			text(GAUGE_C + Vector2.from_angle(a) * (GAUGE_R - 60.0), "%d°" % int(v), UiKit.SIZE_SMALL, Palette.IVORY, "body", 0)
	var heat_a: float = _angle(_valve * p("heat_max"))
	draw_circle(GAUGE_C + Vector2.from_angle(heat_a) * (GAUGE_R + 2.0), 9.0, Palette.ROULETTE_RED)
	var na: float = _angle(_temp)
	draw_line(GAUGE_C, GAUGE_C + Vector2.from_angle(na) * (GAUGE_R - 24.0), Palette.GOLD_LIGHT, 6.0)
	draw_circle(GAUGE_C, 14.0, Palette.GOLD)
	text(GAUGE_C + Vector2(0, 70.0), "%d°" % int(round(_temp)), UiKit.SIZE_H2, Palette.IVORY)
	var flame: String = tr("TRIAL_SOUFFLE_FLAME") % int(round(_valve * 100.0))
	text(GAUGE_C + Vector2(0, GAUGE_R + 50.0), flame, UiKit.SIZE_SMALL, Palette.ROULETTE_RED.lightened(0.3), "body", 4)
	# Frise de la recette : paliers à venir, porte annoncée, curseur du temps.
	draw_rect(STRIP.grow(6.0), Color(Palette.INK, 0.85))
	var steps: Array[float] = _durations()
	var tot: float = _total()
	var x: float = STRIP.position.x
	for k2: int in steps.size():
		var w: float = STRIP.size.x * steps[k2] * slow / tot
		var tgt: float = pk("step_target", k2)
		var col: Color = Color("4a6aa8").lerp(Palette.ROULETTE_RED, clampf((tgt - 150.0) / 70.0, 0.0, 1.0))
		draw_rect(Rect2(x + 2.0, STRIP.position.y, w - 4.0, STRIP.size.y), Color(col, 0.75))
		text(Vector2(x + w * 0.5, STRIP.get_center().y), "%d°" % int(tgt), UiKit.SIZE_BODY, Palette.IVORY, "body", 4)
		x += w
	var dx: float = STRIP.position.x + STRIP.size.x * _door_t() / tot
	draw_line(Vector2(dx, STRIP.position.y - 14.0), Vector2(dx, STRIP.end.y + 14.0), Palette.GOLD_LIGHT, 4.0)
	text(Vector2(dx, STRIP.end.y + 34.0), tr("TRIAL_SOUFFLE_DOOR_MARK"), UiKit.SIZE_SMALL, Palette.GOLD_LIGHT, "body", 4)
	var cx: float = STRIP.position.x + STRIP.size.x * clampf(t / tot, 0.0, 1.0)
	draw_line(Vector2(cx, STRIP.position.y - 10.0), Vector2(cx, STRIP.end.y + 10.0), Palette.IVORY, 6.0)
	# Hauteur du soufflé.
	text(Vector2(OVEN_X, 230.0), tr("TRIAL_SOUFFLE_RISE") % int(round(_rise * 100.0)), UiKit.SIZE_BODY, Palette.IVORY)
