class_name TrialTelescope
extends ThrowTrial
## LE TÉLESCOPE (Toits, 2.0) : dans l'oculaire, le ciel est découpé en trois anneaux concentriques
## qui tournent par crans. Il faut les remettre en place pour retrouver la constellation de la
## carte. Les anneaux sont engrenés : tourner l'anneau extérieur entraîne celui du milieu d'un
## cran, et celui du milieu entraîne l'intérieur d'un cran en sens inverse. Trois ciels.
## Haut / bas : choisir l'anneau ; gauche / droite : le tourner. Au doigt : toucher la moitié
## gauche ou droite d'un anneau.
## Note = moyenne des ciels (plein si retrouvé vite, moins ensuite ; rien hors délai).

const RINGS: int = 3
const STEPS: int = 12
const VIEW_C: Vector2 = Vector2(1080.0, 560.0)
const VIEW_R: float = 360.0
const CHART: Rect2 = Rect2(150.0, 170.0, 300.0, 300.0)
const PX3: float = 0.005

var _sky: int = 0
var _stars: Array[Vector2] = []  # (rayon 0..1, angle) dans la position juste
var _ring_of: Array[int] = []
var _links: Array[Vector2i] = []
var _off: Array[int] = [0, 0, 0]
var _shown: Array[float] = [0.0, 0.0, 0.0]
var _sel: int = 0
var _sky_t: float = 0.0
var _moves: int = 0
var _rest: float = 0.0
var _marks: Array[float] = []
var _ended: bool = false
var _deco: Dictionary = {}
var _scope: Node3D = null
var _astro: Figure3D = null


func begin() -> void:
	_build_3d()
	_new_sky()


func _skies() -> int:
	return pi("skies")


func _limit() -> float:
	return pk("limit", _sky) * slow


## Constellation : quelques étoiles réparties sur les trois anneaux, reliées en un tracé ; les
## anneaux sont ensuite décalés (par de vrais coups, donc toujours soluble).
func _new_sky() -> void:
	_stars.clear()
	_ring_of.clear()
	_links.clear()
	var n: int = int(pk("stars", _sky))
	for k: int in n:
		var ring: int = k % RINGS
		var r: float = (float(ring) + rng.randf_range(0.25, 0.8)) / float(RINGS)
		_stars.append(Vector2(r, rng.randf_range(0.0, TAU)))
		_ring_of.append(ring)
	# Tracé : chaque étoile reliée à sa plus proche voisine encore libre (chemin ouvert).
	var order: Array[int] = [0]
	var left: Array[int] = []
	for k2: int in range(1, n):
		left.append(k2)
	while not left.is_empty():
		var last: Vector2 = _cart(_stars[order[-1]])
		var best: int = left[0]
		for c: int in left:
			if _cart(_stars[c]).distance_to(last) < _cart(_stars[best]).distance_to(last):
				best = c
		_links.append(Vector2i(order[-1], best))
		order.append(best)
		left.erase(best)
	_off = [0, 0, 0]
	for _m: int in int(pk("scramble", _sky)):
		_turn(rng.randi_range(0, RINGS - 1), -1 if rng.randf() < 0.5 else 1, false)
	if _solved():
		_turn(0, 1, false)
	for i: int in RINGS:
		_shown[i] = float(_off[i])
	_sel = 0
	_sky_t = 0.0


func _cart(polar: Vector2) -> Vector2:
	return Vector2.from_angle(polar.y) * polar.x


## Tourne l'anneau `ring` d'un cran (`dir` ±1) avec ses engrenages.
func _turn(ring: int, dir: int, counted: bool = true) -> void:
	_off[ring] = posmod(_off[ring] + dir, STEPS)
	if ring == 0:
		_off[1] = posmod(_off[1] + dir, STEPS)
	elif ring == 1:
		_off[2] = posmod(_off[2] - dir, STEPS)
	if counted:
		_moves += 1


func _solved() -> bool:
	return _off[0] == 0 and _off[1] == 0 and _off[2] == 0


func turn_selected(dir: int) -> void:
	if _ended or _rest > 0.0:
		return
	_turn(_sel, dir)
	AudioBus.play("decor_switch", 1.0 + 0.15 * float(_sel), -8.0)
	if _solved():
		var over: float = maxf(0.0, _sky_t / _limit() - p("grace"))
		var q: float = clampf(1.0 - over * p("late_weight"), p("late_floor"), 1.0)
		_finish_sky(q, "TRIAL_TELESCOPE_FOUND")


func _finish_sky(q: float, key: String) -> void:
	_marks.append(q)
	_rest = p("rest_seconds") * slow
	pop(VIEW_C, q, key)
	AudioBus.play("chime" if q > 0.0 else "lose_soft", 1.2, -4.0)


func tick(dt: float) -> void:
	for i: int in RINGS:
		var want: float = float(_off[i])
		var diff: float = wrapf(want - _shown[i], -float(STEPS) * 0.5, float(STEPS) * 0.5)
		_shown[i] += diff * minf(1.0, dt * 12.0)
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_sky += 1
			if _sky >= _skies():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_sky()
		return
	_sky_t += dt
	if _sky_t >= _limit():
		_finish_sky(0.0, "TRIAL_TELESCOPE_DAWN")


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_tap(mb.position)
		return true
	var d: Vector2i = dir_pressed(event)
	if d.y != 0:
		_sel = clampi(_sel + d.y, 0, RINGS - 1)
		AudioBus.play("tick", 1.3, -14.0)
		return true
	if d.x != 0:
		turn_selected(d.x)
		return true
	return false


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_tap(mb.position)
	return true


## Toucher un anneau : moitié droite = sens horaire, moitié gauche = sens inverse.
func _tap(pos: Vector2) -> void:
	var rel: Vector2 = pos - VIEW_C
	var r: float = rel.length() / VIEW_R
	if r > 1.05:
		return
	_sel = RINGS - 1 - clampi(int(r * float(RINGS)), 0, RINGS - 1)
	turn_selected(1 if rel.x >= 0.0 else -1)


func journal() -> Dictionary:
	return {"skies": _marks.size(), "moves": _moves}


# --------------------------------------------------------------------------- bot


## Résout de l'extérieur vers l'intérieur (les engrenages ne remontent jamais) : choisit
## l'anneau, puis le tourne au plus court.
func bot_wants() -> Dictionary:
	if _rest > 0.0 or _ended:
		return {"do": ""}
	for ring: int in RINGS:
		if _off[ring] == 0:
			continue
		if _sel != ring:
			return {"do": "dir", "dir": Vector2i(0, signi(ring - _sel))}
		return {"do": "dir", "dir": Vector2i(-1 if _off[ring] <= STEPS / 2 else 1, 0)}
	return {"do": ""}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) != "dir":
		return
	var d: Vector2i = w["dir"] as Vector2i
	if d.y != 0:
		_sel = clampi(_sel + d.y, 0, RINGS - 1)
	elif d.x != 0:
		turn_selected(d.x)


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = RooftopSet.build(st, 1000.0, [1840.0], 53)
	var r: Node3D = st.root
	# Lunette de laiton sur trépied, et l'astronome penché sur l'oculaire.
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.85, 0.25)
	var wood: StandardMaterial3D = Stage3D.mat(Color("5a3418"), 0.0, 0.5)
	_scope = Node3D.new()
	_scope.position = st.to3(Vector2(330.0, 760.0), 0.0)
	r.add_child(_scope)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		var leg: MeshInstance3D = Stage3D.cylinder(_scope, 0.025, 1.3, Vector3(cos(a) * 0.25, -0.6, sin(a) * 0.25), wood)
		leg.rotation = Vector3(sin(a) * 0.35, 0.0, -cos(a) * 0.35)
	var tube: Node3D = Node3D.new()
	tube.rotation.z = 0.55
	_scope.add_child(tube)
	var barrel: MeshInstance3D = Stage3D.cylinder(tube, 0.11, 1.5, Vector3(0.0, 0.0, 0.0), brass, 0.08)
	barrel.rotation.z = -PI * 0.5
	Stage3D.cylinder(tube, 0.13, 0.08, Vector3(0.72, 0, 0), brass).rotation.z = -PI * 0.5
	Stage3D.cylinder(tube, 0.035, 0.18, Vector3(-0.82, 0, 0), brass).rotation.z = -PI * 0.5
	Stage3D.cylinder(tube, 0.115, 0.03, Vector3(0.2, 0, 0), Stage3D.mat(Color("1a1410"), 0.4, 0.4)).rotation.z = -PI * 0.5
	_astro = Figure3D.new().build(1.7, {"coat": Color("2a3a5a"), "trim": Palette.GOLD, "hat": "", "hair": Color("a0a0a0")})
	_astro.position = st.to3(Vector2(190.0, 1000.0), -0.2)
	_astro.rotation.y = PI * 0.5
	r.add_child(_astro)


func _sync_3d(dt: float) -> void:
	if _scope == null:
		return
	_astro.animate(&"point", t, dt, 0.4)
	RooftopSet.animate(_deco, stage, t, 40.0)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Oculaire : fond de ciel profond, anneaux, étoiles et tracé à leur position actuelle.
	draw_circle(VIEW_C, VIEW_R + 26.0, Palette.GOLD_DARK)
	draw_circle(VIEW_C, VIEW_R + 14.0, Palette.GOLD)
	draw_circle(VIEW_C, VIEW_R, Color("05081a"))
	for k: int in 90:
		var h: int = hash(Vector2i(k, _sky))
		var pos: Vector2 = Vector2.from_angle(float(h % 6283) / 1000.0) * float((h / 7000) % 1000) / 1000.0 * VIEW_R
		draw_circle(VIEW_C + pos, 1.5, Color(0.7, 0.75, 0.9, 0.5))
	for i: int in RINGS:
		var rr: float = VIEW_R * float(RINGS - i) / float(RINGS)
		var col: Color = Palette.GOLD_LIGHT if i == _sel else Color(Palette.IVORY, 0.25)
		draw_arc(VIEW_C, rr, 0, TAU, 96, col, 4.0 if i == _sel else 2.0)
		for c: int in STEPS:
			var ta: float = TAU * float(c) / float(STEPS) + _ring_angle(i)
			draw_line(VIEW_C + Vector2.from_angle(ta) * (rr - 10.0), VIEW_C + Vector2.from_angle(ta) * rr, Color(Palette.IVORY, 0.3), 2.0)
	var aligned: bool = _solved()
	for l: Vector2i in _links:
		var a: Vector2 = _now(l.x)
		var b: Vector2 = _now(l.y)
		draw_line(a, b, Color(Palette.GOLD_LIGHT, 0.95) if aligned else Color(0.6, 0.7, 1.0, 0.45), 3.0 if aligned else 2.0)
	for k2: int in _stars.size():
		var at: Vector2 = _now(k2)
		draw_circle(at, 13.0, Color(1.0, 0.95, 0.7, 0.18))
		draw_circle(at, 6.0, Color(1.0, 0.97, 0.85))
	# Carte de la constellation à retrouver.
	draw_rect(CHART, Color("e8dcc0"))
	draw_rect(CHART, Palette.GOLD_DARK, false, 4.0)
	var cc: Vector2 = CHART.get_center()
	var sc: float = CHART.size.x * 0.44
	draw_arc(cc, sc, 0, TAU, 48, Color(Palette.INK, 0.25), 2.0)
	for l2: Vector2i in _links:
		draw_line(cc + _cart(_stars[l2.x]) * sc, cc + _cart(_stars[l2.y]) * sc, Color("2a3a6a"), 3.0)
	for st: Vector2 in _stars:
		draw_circle(cc + _cart(st) * sc, 6.0, Color("1a2440"))
	text(Vector2(cc.x, CHART.end.y + 30.0), tr("TRIAL_TELESCOPE_CHART"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	# Délai avant l'aube.
	var left: float = clampf(1.0 - _sky_t / maxf(_limit(), 0.01), 0.0, 1.0)
	var bar: Rect2 = Rect2(CHART.position.x, CHART.end.y + 70.0, CHART.size.x, 12.0)
	draw_rect(bar, Color(Palette.INK, 0.8))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
	text(Vector2(960.0, 105.0), tr("TRIAL_TELESCOPE_STATUS") % [mini(_sky + 1, _skies()), _skies()], UiKit.SIZE_BODY, Palette.IVORY)


func _ring_angle(i: int) -> float:
	return TAU * _shown[i] / float(STEPS)


func _now(k: int) -> Vector2:
	var s: Vector2 = _stars[k]
	var ring: int = RINGS - 1 - _ring_of[k]  # anneau 0 = extérieur ; étoiles rangées de l'intérieur
	return VIEW_C + Vector2.from_angle(s.y + _ring_angle(ring)) * s.x * VIEW_R
