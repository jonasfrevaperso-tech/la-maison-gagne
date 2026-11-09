class_name TrialPalet
extends ThrowTrial
## LE PALET (Fumoir, 2.0) : curling de salon sur une longue table de noyer sablée. La table est
## creusée en gouttière : un palet lancé de biais s'écarte puis revient vers l'axe, ce qui permet
## de contourner les palets de garde. Pendant la glissade, maintenir = brosser : le palet freine
## moins et va plus loin (on ne peut que rallonger, jamais raccourcir).
## Stick haut / bas : viser ; maintenir puis relâcher : force (jauge qui va et vient) ;
## pendant la glissade, maintenir : brosser.
## Note = moyenne des lancers (plein au bouton, moins vers le bord de la maison, rien dehors).

const DT: float = 1.0 / 60.0
const TABLE_TOP: float = -1.25
const TABLE_Z: float = 0.45

var _throw: int = 0
var _aim: float = 0.0
var _axis: Vector2 = Vector2.ZERO
var _mouse_aim: float = INF
var _charging: bool = false
var _gauge_t: float = 0.0
var _brushing: bool = false
var _pucks: Array[Dictionary] = []  # p (u, v), vel, own, out
var _sliding: bool = false
var _acc: float = 0.0
var _rest: float = 0.0
var _throw_t0: float = 0.0
var _marks: Array[float] = []
var _brush_time: float = 0.0
var _ended: bool = false
var _plan: Vector2 = Vector2(INF, INF)
var _deco: Dictionary = {}
var _thrower: Figure3D = null
var _meshes: Array[Node3D] = []
var _brush: Node3D = null


func begin() -> void:
	_build_3d()
	_new_throw()


func _throws() -> int:
	return pi("throws")


func _len() -> float:
	return p("length")


func _half_w() -> float:
	return p("width") * 0.5


func _button() -> Vector2:
	return Vector2(p("house_u"), 0.0)


func _new_throw() -> void:
	_pucks.clear()
	_pucks.append({"p": Vector2(p("start_u"), 0.0), "vel": Vector2.ZERO, "own": true, "out": false})
	var guards: int = int(pk("guards", _throw))
	for k: int in guards:
		var gu: float = p("house_u") - rng.randf_range(p("guard_min"), p("guard_max"))
		var gv: float = 0.0 if k == 0 else rng.randf_range(-1.0, 1.0) * p("guard_side")
		_pucks.append({"p": Vector2(gu, gv), "vel": Vector2.ZERO, "own": false, "out": false})
	_aim = 0.0
	_gauge_t = 0.0
	_charging = false
	_sliding = false
	_brushing = false
	_plan = Vector2(INF, INF)
	_throw_t0 = t
	_sync_meshes()


func gauge() -> float:
	var u: float = fmod(_gauge_t / (p("gauge_seconds") * slow), 2.0)
	return u if u <= 1.0 else 2.0 - u


func _speed(power: float) -> float:
	return lerpf(p("v_min"), p("v_max"), clampf(power, 0.0, 1.0))


## Un pas de physique (pas fixe) : frottement le long de la vitesse (moindre en brossant le
## palet du joueur), rappel vers l'axe (table creusée), chocs élastiques entre palets, chutes.
static func step_pucks(pucks: Array[Dictionary], brush: bool, prm: Dictionary) -> bool:
	var moving: bool = false
	for puck: Dictionary in pucks:
		if bool(puck["out"]):
			continue
		var v: Vector2 = puck["vel"] as Vector2
		var sp: float = v.length()
		if sp <= 0.0:
			continue
		var pos: Vector2 = puck["p"] as Vector2
		var mu: float = float(prm["brush_friction"]) if brush and bool(puck["own"]) else float(prm["friction"])
		var dec: float = mu * DT
		v.y -= float(prm["bowl"]) * pos.y * DT
		sp = v.length()
		if sp <= dec:
			v = Vector2.ZERO
		else:
			v -= v / sp * dec
			moving = true
		pos += v * DT
		puck["vel"] = v
		puck["p"] = pos
		if pos.x > float(prm["length"]) or absf(pos.y) > float(prm["half_w"]):
			puck["out"] = true
			puck["vel"] = Vector2.ZERO
	var r2: float = float(prm["radius"]) * 2.0
	for i: int in pucks.size():
		for j: int in range(i + 1, pucks.size()):
			var a: Dictionary = pucks[i]
			var b: Dictionary = pucks[j]
			if bool(a["out"]) or bool(b["out"]):
				continue
			var d: Vector2 = (b["p"] as Vector2) - (a["p"] as Vector2)
			var dist: float = d.length()
			if dist >= r2 or dist <= 0.0:
				continue
			var n: Vector2 = d / dist
			var rel: float = ((a["vel"] as Vector2) - (b["vel"] as Vector2)).dot(n)
			if rel > 0.0:
				var imp: Vector2 = n * rel * float(prm["restitution"])
				a["vel"] = (a["vel"] as Vector2) - imp
				b["vel"] = (b["vel"] as Vector2) + imp
				moving = true
			var push: Vector2 = n * (r2 - dist) * 0.5
			a["p"] = (a["p"] as Vector2) - push
			b["p"] = (b["p"] as Vector2) + push
	return moving


func _prm() -> Dictionary:
	return {"friction": p("friction"), "brush_friction": p("brush_friction"), "bowl": p("bowl"), "length": _len(),
		"half_w": _half_w(), "radius": p("radius"), "restitution": p("restitution")}


static func copy_pucks(src: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in src:
		out.append(d.duplicate())
	return out


## Note d'une position finale du palet du joueur.
func quality_at(pos: Vector2, out: bool) -> float:
	if out:
		return 0.0
	var d: float = pos.distance_to(_button())
	var rh: float = p("house_r")
	if d > rh:
		return 0.0
	var u: float = d / rh
	if u <= p("perfect_ratio"):
		return 1.0
	return lerpf(1.0, p("edge_q"), (u - p("perfect_ratio")) / (1.0 - p("perfect_ratio")))


## Simule un lancer (angle, force) sans brosser : position finale du palet du joueur.
func predict(a: float, power: float, brush_from: float = INF) -> Dictionary:
	var pucks: Array[Dictionary] = copy_pucks(_pucks)
	pucks[0]["p"] = Vector2(p("start_u"), 0.0)
	pucks[0]["vel"] = Vector2.from_angle(a) * _speed(power)
	return _run(pucks, brush_from)


func _run(pucks: Array[Dictionary], brush_from: float = INF) -> Dictionary:
	var prm: Dictionary = _prm()
	var guard: int = 0
	while guard < 1200:
		var brush: bool = (pucks[0]["p"] as Vector2).x >= brush_from
		if not step_pucks(pucks, brush, prm):
			break
		guard += 1
	return {"p": pucks[0]["p"], "out": pucks[0]["out"]}


# --------------------------------------------------------------------------- jeu


func _launch() -> void:
	if not _charging:
		return
	_charging = false
	if _sliding or _rest > 0.0 or _ended:
		return
	var power: float = gauge()
	_pucks[0]["vel"] = Vector2.from_angle(_aim) * _speed(power)
	_sliding = true
	_acc = 0.0
	AudioBus.play("cloth", 0.7, -6.0)


func tick(dt: float) -> void:
	_steer(dt)
	_sync_3d(dt)
	if _ended:
		return
	if _charging:
		_gauge_t += dt
	if _sliding:
		_acc += dt
		while _acc >= DT and _sliding:
			_acc -= DT
			if _brushing:
				_brush_time += DT
			var before: Array[Vector2] = []
			for d: Dictionary in _pucks:
				before.append(d["vel"] as Vector2)
			if not step_pucks(_pucks, _brushing, _prm()):
				_sliding = false
				_settle()
			for k: int in _pucks.size():
				if ((_pucks[k]["vel"] as Vector2) - before[k]).length() > p("click_dv"):
					AudioBus.play("tick", 0.7, -4.0)
					break
		_sync_meshes()
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_throw += 1
			if _throw >= _throws():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_throw()
		return
	if t - _throw_t0 >= p("throw_seconds") * slow:
		_marks.append(0.0)
		pop(Vector2(960.0, 540.0), 0.0, "TRIAL_PALET_LATE")
		_rest = p("rest_seconds") * slow


func _settle() -> void:
	var own: Dictionary = _pucks[0]
	var q: float = quality_at(own["p"] as Vector2, bool(own["out"]))
	_marks.append(q)
	var key: String = "TRIAL_PALET_BUTTON" if q >= 1.0 else ("TRIAL_PALET_HOUSE" if q > 0.0 else "TRIAL_PALET_SHORT")
	if bool(own["out"]):
		key = "TRIAL_PALET_OUT"
	if not bool(own["out"]) and q <= 0.0 and (own["p"] as Vector2).x > p("house_u"):
		key = "TRIAL_PALET_LONG"
	pop(Vector2(960.0, 300.0), q, key)
	AudioBus.play("chime" if q > 0.0 else "lose_soft", 1.0 + 0.3 * q, -5.0)
	_rest = p("rest_seconds") * slow


func _steer(dt: float) -> void:
	if _sliding or _charging:
		return
	var lim: float = p("aim_max")
	if mouse and _mouse_aim != INF:
		_aim = move_toward(_aim, clampf(_mouse_aim, -lim, lim), p("aim_speed") * 2.0 * dt)
		return
	var v: float = clampf(held_vector().y + _axis.y, -1.0, 1.0)
	_aim = clampf(_aim + v * p("aim_speed") * dt, -lim, lim)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_mouse_aim = (mm.position.y - 620.0) / 260.0 * p("aim_max")
		return true
	if confirm_pressed(event):
		if _sliding:
			_brushing = true
		elif _rest <= 0.0 and not _ended:
			_charging = true
			_gauge_t = 0.0
		return true
	if confirm_released(event):
		if _brushing:
			_brushing = false
		else:
			_launch()
		return true
	return false


func journal() -> Dictionary:
	return {"throws": _marks.size(), "brush_s": snappedf(_brush_time, 0.01)}


# --------------------------------------------------------------------------- bot


## Plan : (angle, force) dont l'arrêt sans brosser tombe un peu avant le bouton (marge rattrapée
## au brossage), la meilleure note autour de ce point ; puis vise, charge, lâche, et brosse tant
## que le palet s'arrêterait trop court.
func _plan_shot() -> Vector2:
	var lim: float = p("aim_max")
	var best: Vector3 = _search(-lim, lim, p("bot_aim_step"), 0.1, 1.0, p("bot_power_step"), Vector3(0.0, 0.5, -1.0))
	var da: float = p("bot_aim_step")
	var dp: float = p("bot_power_step")
	best = _search(maxf(-lim, best.x - da), minf(lim, best.x + da), da * 0.25, maxf(0.0, best.y - dp), minf(1.0, best.y + dp), dp * 0.25, best)
	return Vector2(best.x, best.y)


## Meilleur (angle, force, note) d'une grille, l'arrêt visé un peu court (`bot_short`).
func _search(a0: float, a1: float, da: float, p0: float, p1: float, dp: float, best: Vector3) -> Vector3:
	var short: Vector2 = Vector2(p("bot_short"), 0.0)
	var a: float = a0
	while a <= a1 + 0.0001:
		var pw: float = p0
		while pw <= p1 + 0.0001:
			var r: Dictionary = predict(a, pw)
			var q: float = quality_at((r["p"] as Vector2) + short, bool(r["out"]))
			if q > best.z:
				best = Vector3(a, pw, q)
			pw += dp
		a += da
	return best


func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0:
		return {"do": "axis", "v": Vector2.ZERO}
	if _sliding:
		var sim: Array[Dictionary] = copy_pucks(_pucks)
		var r: Dictionary = _run(sim)
		var stop: Vector2 = r["p"] as Vector2
		var want_brush: bool = not bool(r["out"]) and stop.x < p("house_u") - p("bot_brush_margin")
		return {"do": "hold" if want_brush else "release"}
	if not _charging:
		if _plan.x == INF:
			_plan = _plan_shot()
		var miss: float = _plan.x - _aim
		if absf(miss) > p("bot_aim_tol"):
			return {"do": "axis", "v": Vector2(0.0, clampf(miss * 8.0, -1.0, 1.0))}
		return {"do": "hold"}
	var nxt_t: float = _gauge_t + DT
	var u: float = fmod(nxt_t / (p("gauge_seconds") * slow), 2.0)
	var nxt: float = u if u <= 1.0 else 2.0 - u
	if (gauge() - _plan.y) * (nxt - _plan.y) <= 0.0:
		return {"do": "release"}
	return {"do": "hold"}


func bot_apply(w: Dictionary) -> void:
	var mode: String = String(w.get("do", ""))
	_axis = w.get("v", Vector2.ZERO) as Vector2 if mode == "axis" else Vector2.ZERO
	if _sliding:
		_brushing = mode == "hold"
		return
	if mode == "hold" and not _charging and _rest <= 0.0 and not _ended:
		_charging = true
		_gauge_t = 0.0
	elif mode == "release" and _charging:
		_launch()


# --------------------------------------------------------------------------- décor 3D


func _table_pos(uv: Vector2, lift: float = 0.0) -> Vector3:
	return Vector3(uv.x - _len() * 0.5, TABLE_TOP + lift, TABLE_Z + uv.y)


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = SmokingSet.build(st, 960.0, 1500.0)
	var r: Node3D = st.root
	var floor_y: float = st.to3(Vector2(0.0, 960.0)).y
	var walnut: StandardMaterial3D = Stage3D.textured("wood", Color("c08850"), 0.8, 0.0, 0.2)
	var walnut_d: StandardMaterial3D = Stage3D.textured("wood", SmokingSet.WALNUT_D, 0.6, 0.0, 0.4)
	var tl: float = _len()
	var tw: float = p("width")
	# Table : plateau vernis, gouttières de chaque côté et au bout, pieds tournés.
	Stage3D.box(r, Vector3(tl, 0.06, tw), _table_pos(Vector2(tl * 0.5, 0.0), -0.03), walnut)
	for sv: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(tl + 0.2, 0.08, 0.1), _table_pos(Vector2(tl * 0.5, sv * (tw * 0.5 + 0.05)), -0.05), walnut_d)
		Stage3D.box(r, Vector3(tl + 0.2, 0.05, 0.03), _table_pos(Vector2(tl * 0.5, sv * (tw * 0.5 + 0.115)), 0.0), walnut_d)
	Stage3D.box(r, Vector3(0.12, 0.08, tw + 0.26), _table_pos(Vector2(tl + 0.06, 0.0), -0.05), walnut_d)
	Stage3D.box(r, Vector3(tl, 0.3, tw * 0.8), _table_pos(Vector2(tl * 0.5, 0.0), -0.24), walnut_d)
	var legs_h: float = TABLE_TOP - 0.38 - floor_y
	for k: int in 4:
		var lu: float = 0.3 + (tl - 0.6) * float(k % 2)
		var lv: float = (tw * 0.35) * (1.0 if k >= 2 else -1.0)
		var leg_at: Vector3 = _table_pos(Vector2(lu, lv), -0.38 - legs_h * 0.5)
		Stage3D.cylinder(r, 0.06, legs_h, leg_at, walnut_d, 0.045)
	# Maison : cercles peints (bleu, blanc, rouge, bouton) ; lignes de départ et de garde.
	var house_cols: Array[Color] = [Color("2a4a8a"), Color("f0e8d8"), Color("a82a24"), Color("f0e8d8")]
	var radii: Array[float] = [1.0, 0.72, 0.45, 0.18]
	for k2: int in house_cols.size():
		var disc_at: Vector3 = _table_pos(_button(), 0.002 + 0.001 * float(k2))
		var disc: MeshInstance3D = Stage3D.cylinder(r, p("house_r") * radii[k2], 0.004, disc_at, Stage3D.mat(house_cols[k2], 0.0, 0.35))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hog_at: Vector3 = _table_pos(Vector2(p("house_u") - p("house_r") - 0.6, 0.0), 0.002)
	Stage3D.box(r, Vector3(0.01, 0.003, tw), hog_at, Stage3D.mat(Palette.GOLD, 0.6, 0.4))
	Stage3D.omni(r, Color(1.0, 0.85, 0.6), 1.4, _table_pos(Vector2(tl * 0.6, 0.0), 1.4), 4.0)
	# Le lanceur au bout de la table, et le balai.
	_thrower = SmokingSet.gentleman(1.75, Color("2a2a3a"), Color("8a8a8a"))
	_thrower.position = Vector3(-tl * 0.5 - 0.45, floor_y, TABLE_Z - 0.7)
	_thrower.rotation.y = PI * 0.5
	r.add_child(_thrower)
	_brush = Node3D.new()
	r.add_child(_brush)
	Stage3D.box(_brush, Vector3(0.05, 0.03, 0.2), Vector3(0, 0.02, 0), Stage3D.mat(Color("c8a060"), 0.0, 0.9))
	var stick: MeshInstance3D = Stage3D.cylinder(_brush, 0.01, 0.7, Vector3(-0.2, 0.3, 0), Stage3D.mat(Color("3a2010"), 0.0, 0.5))
	stick.rotation.z = 0.6
	# Caméra en plongée sur la table.
	st.look(Vector3(-0.3, p("cam_h"), TABLE_Z + p("cam_back")), Vector3(-0.15, TABLE_TOP, TABLE_Z - 0.05), 40.0)


func _sync_meshes() -> void:
	if stage == null:
		return
	while _meshes.size() < _pucks.size():
		var n: Node3D = Node3D.new()
		stage.root.add_child(n)
		var own: bool = _meshes.is_empty()
		var col: Color = Palette.GOLD if own else Color("8a1a14")
		Stage3D.cylinder(n, p("radius"), 0.035, Vector3(0, 0.0175, 0), Stage3D.mat(col, 0.85 if own else 0.2, 0.3))
		Stage3D.cylinder(n, p("radius") * 0.55, 0.004, Vector3(0, 0.037, 0), Stage3D.mat(col.darkened(0.3), 0.6, 0.35))
		_meshes.append(n)
	for k: int in _meshes.size():
		var n2: Node3D = _meshes[k]
		if k >= _pucks.size():
			n2.visible = false
			continue
		var d: Dictionary = _pucks[k]
		n2.visible = not bool(d["out"])
		n2.position = _table_pos(d["p"] as Vector2)


func _sync_3d(dt: float) -> void:
	if _thrower == null:
		return
	var throw_ph: float = 0.0 if _charging else (1.0 if _sliding else 0.4)
	_thrower.animate(&"throw", throw_ph, dt)
	SmokingSet.animate(_deco, stage, 960.0, t)
	var own: Vector2 = _pucks[0]["p"] as Vector2 if not _pucks.is_empty() else Vector2.ZERO
	_brush.visible = _brushing and _sliding
	if _brush.visible:
		_brush.position = _table_pos(own + Vector2(p("radius") * 2.5 + 0.03 * sin(t * 40.0), 0.04 * sin(t * 25.0)))


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	# Ligne de visée (projetée) avant le lancer.
	if not _sliding and _rest <= 0.0 and not _ended:
		var from: Vector2 = stage.project(_table_pos(Vector2(p("start_u"), 0.0), 0.04))
		for k: int in 9:
			var uv: Vector2 = Vector2(p("start_u"), 0.0) + Vector2.from_angle(_aim) * (0.15 + 0.12 * float(k))
			draw_circle(stage.project(_table_pos(uv, 0.04)), 5.0 - 0.4 * float(k), Color(Palette.GOLD_LIGHT, 0.85 - 0.08 * float(k)))
		draw_circle(from, 3.0, Palette.IVORY)
	# Jauge de force.
	var g: Rect2 = Rect2(120.0, 780.0, 300.0, 26.0)
	draw_rect(g, Color(Palette.INK, 0.85))
	var val: float = gauge() if _charging else 0.0
	draw_rect(Rect2(g.position, Vector2(g.size.x * val, g.size.y)), Palette.GOLD.lerp(Palette.ROULETTE_RED, val))
	draw_rect(g, Palette.GOLD_DARK, false, 2.0)
	text(Vector2(g.get_center().x, g.end.y + 26.0), tr("TRIAL_PALET_FORCE"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	if _brushing and _sliding:
		text(Vector2(960.0, 160.0), tr("TRIAL_PALET_BRUSHING"), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	text(Vector2(960.0, 105.0), tr("TRIAL_PALET_STATUS") % [mini(_throw + 1, _throws()), _throws()], UiKit.SIZE_BODY, Palette.IVORY)
