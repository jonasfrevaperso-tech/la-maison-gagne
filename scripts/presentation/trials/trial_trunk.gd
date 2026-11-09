class_name TrialTrunk
extends ThrowTrial
## LE COFFRE (Garage, 2.0) : charger tous les bagages d'un client dans le coffre de sa voiture.
## Le chariot apporte les bagages dans un ordre imposé (on voit les deux suivants) ; chacun se
## pose où l'on veut, tourné si besoin. Le chargement complet tombe pile : le coffre est
## découpé en bagages au départ, il existe toujours une solution — encore faut-il ne pas se
## fermer de porte. On peut reprendre un bagage déjà rangé (le dernier, ou au doigt n'importe lequel).
## Croix : déplacer · confirmer : poser · haut (Y) : tourner · gauche (X) : reprendre le dernier.
## Note = moyenne des coffres (part de la surface remplie ; plein = bonus de rapidité).

const CELL: float = 0.2  # mètres par case du coffre
const FLOOR_Y: float = 0.62
const LEATHER: Array[Color] = [Color("6a3a1a"), Color("2a3a5a"), Color("5a1a1a"), Color("3a4a2a"), Color("8a6a3a"), Color("1a1a1a"),
	Color("7a5a8a")]

var _round: int = 0
var _w: int = 0
var _h: int = 0
var _grid: Array[int] = []  # -1 vide, sinon indice du bagage
var _pieces: Array[Dictionary] = []  # base (cellules), sol (cellules absolues), col, kind, rot, at, placed
var _queue: Array[int] = []
var _cur: int = -1
var _rot: int = 0
var _cursor: Vector2i = Vector2i.ZERO
var _history: Array[int] = []
var _round_t0: float = 0.0
var _rest: float = 0.0
var _marks: Array[float] = []
var _ended: bool = false
var _undos: int = 0
var _models: Dictionary[int, Node3D] = {}
var _ghost: Node3D = null
var _cart_slots: Array[Node3D] = []
var _valet: Figure3D = null
var _deco: Dictionary = {}
var _lid: Node3D = null
var _car_root: Node3D = null
var _origin: Vector3 = Vector3.ZERO
var _shown_rot: int = -9
var _shown_cur: int = -9


func begin() -> void:
	_build_3d()
	_new_round()


func _rounds() -> int:
	return pi("rounds")


func _new_round() -> void:
	_w = int(pk("cols", _round))
	_h = int(pk("rows", _round))
	_grid.resize(_w * _h)
	_grid.fill(-1)
	_pieces = partition(_w, _h, rng, pi("max_area"), p("merge_p"))
	_queue.clear()
	for k: int in _pieces.size():
		_pieces[k]["rot"] = rng.randi_range(0, 3)
		_queue.append(k)
	for k2: int in range(_queue.size() - 1, 0, -1):  # mélange de Fisher-Yates
		var j: int = rng.randi_range(0, k2)
		var tmp: int = _queue[k2]
		_queue[k2] = _queue[j]
		_queue[j] = tmp
	_history.clear()
	_round_t0 = t
	_origin = Vector3(-float(_w) * CELL * 0.5, FLOOR_Y, -float(_h) * CELL * 0.5)
	_next_piece()
	if _car_root != null:
		_build_car()
	_rebuild_scene()


# --------------------------------------------------------------------------- formes


## Découpe le coffre `w` × `h` en bagages rectangulaires (coupes franches successives), puis
## soude quelques petits bagages voisins en sacs en L. Chaque bagage garde sa place d'origine
## (`sol`) : la solution. Formes normalisées (coin haut-gauche en 0, 0).
static func partition(w: int, h: int, r: RandomNumberGenerator, max_area: int, merge_p: float) -> Array[Dictionary]:
	var rects: Array[Rect2i] = []
	var todo: Array[Rect2i] = [Rect2i(0, 0, w, h)]
	while not todo.is_empty():
		var rc: Rect2i = todo.pop_back()
		var area: int = rc.size.x * rc.size.y
		var stop: bool = area <= max_area and (area <= 2 or r.randf() < 0.55)
		if area == 1 or (stop and rc.size.x <= 3 and rc.size.y <= 3):
			rects.append(rc)
			continue
		var cut_x: bool = rc.size.x > rc.size.y or (rc.size.x == rc.size.y and r.randf() < 0.5)
		if cut_x and rc.size.x > 1:
			var c: int = r.randi_range(1, rc.size.x - 1)
			todo.append(Rect2i(rc.position, Vector2i(c, rc.size.y)))
			todo.append(Rect2i(rc.position + Vector2i(c, 0), Vector2i(rc.size.x - c, rc.size.y)))
		else:
			var c2: int = r.randi_range(1, rc.size.y - 1)
			todo.append(Rect2i(rc.position, Vector2i(rc.size.x, c2)))
			todo.append(Rect2i(rc.position + Vector2i(0, c2), Vector2i(rc.size.x, rc.size.y - c2)))
	var shapes: Array[Array] = []
	for rc2: Rect2i in rects:
		var cells: Array[Vector2i] = []
		for x: int in rc2.size.x:
			for y: int in rc2.size.y:
				cells.append(rc2.position + Vector2i(x, y))
		shapes.append(cells)
	# Sacs en L : un petit bagage (1 ou 2 cases) soudé à un voisin de 2 cases.
	var k: int = 0
	while k < shapes.size():
		if shapes[k].size() <= 2 and r.randf() < merge_p:
			for j: int in shapes.size():
				if j != k and shapes[j].size() == 2 and shapes[k].size() + 2 <= 4 and _touching(shapes[k], shapes[j]):
					var merged: Array = shapes[k] + shapes[j]
					if not _is_rect(merged):
						shapes[k] = merged
						shapes.remove_at(j)
						if j < k:
							k -= 1
						break
		k += 1
	var out: Array[Dictionary] = []
	for s: Array in shapes:
		var sol: Array[Vector2i] = []
		for c3: Variant in s:
			sol.append(c3 as Vector2i)
		out.append({"sol": sol, "base": normalized(sol), "rot": 0, "at": Vector2i(-1, -1), "placed": false})
	return out


static func _touching(a: Array, b: Array) -> bool:
	for ca: Variant in a:
		for cb: Variant in b:
			var d: Vector2i = (ca as Vector2i) - (cb as Vector2i)
			if absi(d.x) + absi(d.y) == 1:
				return true
	return false


static func _is_rect(cells: Array) -> bool:
	var lo: Vector2i = Vector2i(1 << 20, 1 << 20)
	var hi: Vector2i = Vector2i(-1, -1)
	for c: Variant in cells:
		lo = Vector2i(mini(lo.x, (c as Vector2i).x), mini(lo.y, (c as Vector2i).y))
		hi = Vector2i(maxi(hi.x, (c as Vector2i).x), maxi(hi.y, (c as Vector2i).y))
	return (hi.x - lo.x + 1) * (hi.y - lo.y + 1) == cells.size()


## Cellules ramenées au coin haut-gauche (0, 0), triées.
static func normalized(cells: Array[Vector2i]) -> Array[Vector2i]:
	var lo: Vector2i = Vector2i(1 << 20, 1 << 20)
	for c: Vector2i in cells:
		lo = Vector2i(mini(lo.x, c.x), mini(lo.y, c.y))
	var out: Array[Vector2i] = []
	for c2: Vector2i in cells:
		out.append(c2 - lo)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


## Forme tournée de `rot` quarts de tour (normalisée).
static func rotated(base: Array[Vector2i], rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in base:
		var v: Vector2i = c
		for _k: int in posmod(rot, 4):
			v = Vector2i(-v.y, v.x)
		out.append(v)
	return normalized(out)


func _shape(idx: int, rot: int) -> Array[Vector2i]:
	return rotated(_pieces[idx]["base"] as Array[Vector2i], rot)


func _size_of(cells: Array[Vector2i]) -> Vector2i:
	var hi: Vector2i = Vector2i.ZERO
	for c: Vector2i in cells:
		hi = Vector2i(maxi(hi.x, c.x), maxi(hi.y, c.y))
	return hi + Vector2i.ONE


## Vrai si le bagage `idx`, tourné `rot`, tient à `at` (dans le coffre, sur des cases vides).
func fits(idx: int, rot: int, at: Vector2i) -> bool:
	for c: Vector2i in _shape(idx, rot):
		var q: Vector2i = at + c
		if q.x < 0 or q.y < 0 or q.x >= _w or q.y >= _h or _grid[q.y * _w + q.x] != -1:
			return false
	return true


# --------------------------------------------------------------------------- jeu


func _next_piece() -> void:
	_cur = _queue.pop_front() if not _queue.is_empty() else -1
	if _cur >= 0:
		_rot = int(_pieces[_cur]["rot"])
		_clamp_cursor()


func _clamp_cursor() -> void:
	if _cur < 0:
		return
	var sz: Vector2i = _size_of(_shape(_cur, _rot))
	_cursor = Vector2i(clampi(_cursor.x, 0, maxi(0, _w - sz.x)), clampi(_cursor.y, 0, maxi(0, _h - sz.y)))


func _place() -> void:
	if _cur < 0 or _rest > 0.0 or _ended:
		return
	if not fits(_cur, _rot, _cursor):
		AudioBus.play("error", 1.0, -8.0)
		return
	for c: Vector2i in _shape(_cur, _rot):
		var q: Vector2i = _cursor + c
		_grid[q.y * _w + q.x] = _cur
	_pieces[_cur]["rot"] = _rot
	_pieces[_cur]["at"] = _cursor
	_pieces[_cur]["placed"] = true
	_history.append(_cur)
	AudioBus.play("decor_trunk", 0.9 + 0.1 * float(_shape(_cur, _rot).size()), -4.0)
	_next_piece()
	_rebuild_scene()
	if _cur < 0:
		_end_round()


## Reprend le bagage `idx` déjà rangé : il redevient le bagage en main, l'actuel retourne au chariot.
func _take_back(idx: int) -> void:
	if idx < 0 or not bool(_pieces[idx]["placed"]) or _rest > 0.0 or _ended:
		return
	for k: int in _grid.size():
		if _grid[k] == idx:
			_grid[k] = -1
	_pieces[idx]["placed"] = false
	_history.erase(idx)
	if _cur >= 0:
		_pieces[_cur]["rot"] = _rot
		_queue.push_front(_cur)
	_cur = idx
	_rot = int(_pieces[idx]["rot"])
	_cursor = _pieces[idx]["at"] as Vector2i
	_undos += 1
	AudioBus.play("cloth", 1.1, -6.0)
	_rebuild_scene()


func filled() -> float:
	var n: int = 0
	for g: int in _grid:
		if g != -1:
			n += 1
	return float(n) / float(maxi(_grid.size(), 1))


func _end_round() -> void:
	var f: float = filled()
	var q: float = f * p("partial_k")
	if f >= 1.0:
		var used: float = (t - _round_t0) / (p("round_seconds") * slow)
		q = lerpf(1.0, p("full_slow_q"), clampf((used - p("fast_frac")) / (1.0 - p("fast_frac")), 0.0, 1.0))
	_marks.append(q)
	pop(Vector2(960.0, 260.0), q, "TRIAL_TRUNK_FULL" if f >= 1.0 else "TRIAL_TRUNK_LEFT")
	AudioBus.play("chime" if f >= 1.0 else "lose_soft", 1.0 + 0.3 * q, -5.0)
	if f >= 1.0:
		AudioBus.play("decor_trunk", 0.7, -2.0)
	_rest = p("rest_seconds") * slow


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _rest > 0.0:
		_rest -= dt
		if _rest <= 0.0:
			_round += 1
			if _round >= _rounds():
				_ended = true
				finish(ThrowTrial.mean(_marks))
				return
			_new_round()
		return
	if t - _round_t0 >= p("round_seconds") * slow:
		pop(Vector2(960.0, 330.0), 0.0, "TRIAL_TRUNK_LATE")
		_end_round()


func _rotate() -> void:
	if _cur < 0 or _rest > 0.0:
		return
	_rot = posmod(_rot + 1, 4)
	_clamp_cursor()
	AudioBus.play("cloth", 1.3, -9.0)


func handle(event: InputEvent) -> bool:
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and mouse:
		var cell: Vector2i = _cell_at(mm.position)
		if cell.x >= 0:
			_cursor = cell
			_clamp_cursor()
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mouse:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_rotate()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_pointer(mb.position)
		return true
	var d: Vector2i = dir_pressed(event)
	if d != Vector2i.ZERO:
		_cursor += d
		_clamp_cursor()
		AudioBus.play("tick", 1.3, -12.0)
		return true
	var s: int = sym_pressed(event)
	if s == 1:
		_rotate()
		return true
	if s == 0:
		if not _history.is_empty():
			_take_back(_history[_history.size() - 1])
		return true
	if confirm_pressed(event):
		_place()
		return true
	return false


## Toucher / cliquer : un bagage rangé = le reprendre ; une case libre = y poser le bagage en main
## (ajusté pour tenir) ; le bagage en main (sur le chariot) = le tourner.
func _pointer(pos: Vector2) -> void:
	if stage != null and _cur >= 0 and pos.distance_to(stage.project(_cart_slots[0].global_position)) < p("tap_radius"):
		_rotate()
		return
	var cell: Vector2i = _cell_at(pos)
	if cell.x < 0:
		return
	var g: int = _grid[cell.y * _w + cell.x]
	if g != -1:
		_take_back(g)
		return
	# Le bagage se pose de façon à couvrir la case touchée.
	var shape: Array[Vector2i] = _shape(_cur, _rot) if _cur >= 0 else []
	for c: Vector2i in shape:
		if fits(_cur, _rot, cell - c):
			_cursor = cell - c
			_place()
			return
	AudioBus.play("error", 1.0, -8.0)


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_pointer(mb.position)
	return true


func _cell_at(pos: Vector2) -> Vector2i:
	if stage == null:
		return Vector2i(-1, -1)
	var w: Vector3 = stage.unproject_to_plane(pos, FLOOR_Y)
	if w == Vector3.INF:
		return Vector2i(-1, -1)
	var c: Vector2i = Vector2i(floori((w.x - _origin.x) / CELL), floori((w.z - _origin.z) / CELL))
	return c if c.x >= 0 and c.y >= 0 and c.x < _w and c.y < _h else Vector2i(-1, -1)


func journal() -> Dictionary:
	return {"rounds": _marks.size(), "undos": _undos}


# --------------------------------------------------------------------------- bot


## Le bot connaît la découpe d'origine : il tourne le bagage dans le sens de sa place, l'y amène
## à la croix et le pose.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0 or _cur < 0:
		return {"do": ""}
	var sol: Array[Vector2i] = _pieces[_cur]["sol"] as Array[Vector2i]
	var target: Array[Vector2i] = normalized(sol)
	var at: Vector2i = Vector2i(1 << 20, 1 << 20)
	for c: Vector2i in sol:
		at = Vector2i(mini(at.x, c.x), mini(at.y, c.y))
	if _shape(_cur, _rot) != target:
		return {"do": "sym", "symbol": 1}
	if _cursor != at:
		var d: Vector2i = at - _cursor
		var step_v: Vector2i = Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y))
		return {"do": "dir", "dir": step_v}
	return {"do": "confirm"}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"sym":
			if int(w.get("symbol", -1)) == 1:
				_rotate()
		"dir":
			_cursor += w.get("dir", Vector2i.ZERO) as Vector2i
			_clamp_cursor()
		"confirm":
			_place()


# --------------------------------------------------------------------------- décor 3D


func _cell_pos(c: Vector2, lift: float = 0.0) -> Vector3:
	return _origin + Vector3(c.x * CELL, lift, c.y * CELL)


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	_deco = GarageSet.build(st, Vector3(0.0, 0.0, -1.0), Vector2(10.0, 8.0), [Vector2(-2.6, -2.8), Vector2(2.6, -2.8)], -3.4)
	var r: Node3D = st.root
	_car_root = Node3D.new()
	r.add_child(_car_root)
	var tw: float = float(pk("cols", pi("rounds") - 1)) * CELL + 0.1
	# Chariot à bagages du casino (laiton, tapis rouge) à droite, avec le voiturier.
	var brass: StandardMaterial3D = Stage3D.mat(SmokingSet.BRASS, 0.85, 0.25)
	var cart: Vector3 = Vector3(tw * 0.5 + 1.3, 0.0, 0.2)
	Stage3D.box(r, Vector3(1.0, 0.05, 0.7), cart + Vector3(0, 0.3, 0), Stage3D.mat(Color("8a1a24"), 0.0, 0.9))
	for k: int in 2:
		var bar: MeshInstance3D = Stage3D.cylinder(r, 0.02, 1.2, cart + Vector3(-0.45 + 0.9 * float(k), 0.9, -0.3), brass)
		bar.rotation.x = 0.0
	Stage3D.cylinder(r, 0.02, 0.92, cart + Vector3(0, 1.5, -0.3), brass).rotation.z = PI * 0.5
	for k2: int in 4:
		Stage3D.cylinder(r, 0.06, 0.04, cart + Vector3(-0.42 + 0.84 * float(k2 % 2), 0.06, -0.3 + 0.6 * float(k2 / 2)),
			Stage3D.mat(Color("141414"), 0.0, 0.8)).rotation.z = PI * 0.5
	for k3: int in 3:
		var slot: Node3D = Node3D.new()
		slot.position = cart + Vector3(-0.25 + 0.3 * float(k3), 0.34 + 0.0 * float(k3), 0.05)
		r.add_child(slot)
		_cart_slots.append(slot)
	_valet = GarageSet.valet()
	_valet.position = cart + Vector3(0.75, 0.0, 0.2)
	_valet.rotation.y = -PI * 0.5
	r.add_child(_valet)
	_ghost = Node3D.new()
	r.add_child(_ghost)
	st.look(Vector3(0.3, p("cam_h"), p("cam_back")), Vector3(0.55, FLOOR_Y - 0.15, -0.1), 38.0)


## Arrière de la berline taillé au coffre de la manche : ailes, pare-chocs, feux, couvercle levé.
func _build_car() -> void:
	for c: Node in _car_root.get_children():
		c.queue_free()
	var r: Node3D = _car_root
	var paint: StandardMaterial3D = Stage3D.mat(GarageSet.CAR_COLORS[1], 0.55, 0.22)
	paint.clearcoat_enabled = true
	var chrome: StandardMaterial3D = Stage3D.mat(Color("e8ecf0"), 1.0, 0.12)
	var tw: float = float(_w) * CELL + 0.1
	var td: float = float(_h) * CELL + 0.1
	# Arrière de la berline : ailes, bas de caisse, pare-chocs chromé, feux, coffre ouvert.
	Stage3D.box(r, Vector3(tw + 0.5, 0.5, td + 1.6), Vector3(0, 0.35, -0.6), paint)
	Stage3D.box(r, Vector3(tw + 0.1, 0.02, td + 0.05), Vector3(0, FLOOR_Y - 0.01, 0), Stage3D.mat(Color("2a2420"), 0.0, 1.0))  # moquette
	for sx: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(0.22, 0.3, td + 1.6), Vector3(sx * (tw * 0.5 + 0.13), 0.75, -0.6), paint)
		var tail: MeshInstance3D = Stage3D.cylinder(r, 0.07, 0.2, Vector3(sx * (tw * 0.5 + 0.13), 0.86, td * 0.5 + 0.12),
			Stage3D.glow(Color(0.9, 0.05, 0.05), 1.2))
		tail.rotation.x = PI * 0.5
	Stage3D.box(r, Vector3(tw + 0.1, 0.32, 0.06), Vector3(0, 0.75, td * 0.5 + 0.06), paint)
	Stage3D.box(r, Vector3(tw + 0.1, 0.32, 0.06), Vector3(0, 0.75, -td * 0.5 - 0.06), paint)
	var bumper: MeshInstance3D = Stage3D.cylinder(r, 0.07, tw + 0.6, Vector3(0, 0.38, td * 0.5 + 0.18), chrome)
	bumper.rotation.z = PI * 0.5
	Stage3D.box(r, Vector3(tw + 0.4, 0.4, 0.5), Vector3(0, 1.1, -td * 0.5 - 0.5), Stage3D.mat(Color(0.12, 0.18, 0.24), 0.6, 0.05))  # lunette
	# Couvercle du coffre levé.
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.92, -td * 0.5 - 0.05)
	r.add_child(_lid)
	var lid_m: MeshInstance3D = Stage3D.box(_lid, Vector3(tw + 0.2, 0.04, td + 0.1), Vector3(0, 0, td * 0.5), paint)
	lid_m.position = Vector3(0, (td * 0.5) * sin(1.2), (td * 0.5) * cos(1.2) - td * 0.1)
	lid_m.rotation.x = -1.2


## Modèle d'un bagage selon sa forme : valise (rectangle), carton à chapeau (1 case), sac de
## golf (1 × 3), sac de voyage (en L).
func _model(idx: int, cells: Array[Vector2i], ghost: bool = false) -> Node3D:
	var n: Node3D = Node3D.new()
	var col: Color = LEATHER[idx % LEATHER.size()]
	var m: StandardMaterial3D = Stage3D.mat(col, 0.05, 0.5)
	if ghost:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(col, 0.7)
	var brass: StandardMaterial3D = Stage3D.mat(SmokingSet.BRASS, 0.85, 0.25)
	var sz: Vector2i = _size_of(cells)
	var h: float = 0.1 + 0.03 * float(idx % 3)
	var rect: bool = sz.x * sz.y == cells.size()
	if cells.size() == 1:
		Stage3D.cylinder(n, CELL * 0.45, h * 1.4, Vector3(CELL * 0.5, h * 0.7, CELL * 0.5), Stage3D.mat(Color("e8c8d0"), 0.0, 0.6))
		Stage3D.cylinder(n, CELL * 0.46, 0.02, Vector3(CELL * 0.5, h * 1.35, CELL * 0.5), Stage3D.mat(Color("8a1a3a"), 0.0, 0.5))
	elif rect and (sz.x == 1 or sz.y == 1) and cells.size() == 3:
		var bag: MeshInstance3D = Stage3D.cylinder(n, CELL * 0.42, CELL * 3.0 - 0.02, Vector3(sz.x * CELL * 0.5, CELL * 0.42, sz.y * CELL * 0.5),
			Stage3D.mat(Color("e8dcc0"), 0.0, 0.6))
		bag.rotation = Vector3(PI * 0.5, 0, 0) if sz.y == 3 else Vector3(0, 0, PI * 0.5)
		for k: int in 3:
			var off: Vector3 = Vector3(0.0, 0.0, -0.05 + 0.05 * float(k)) if sz.x == 3 else Vector3(-0.05 + 0.05 * float(k), 0.0, 0.0)
			var head_at: Vector3 = Vector3(sz.x * CELL * 0.5, CELL * 0.8, sz.y * CELL * 0.5) + off
			head_at += Vector3(0, 0, -CELL * 1.4) if sz.y == 3 else Vector3(-CELL * 1.4, 0, 0)
			Stage3D.sphere(n, 0.035, head_at, Stage3D.mat(Color("c8ccd0"), 0.9, 0.2))
	elif rect:
		var body: Vector3 = Vector3(sz.x * CELL - 0.02, h, sz.y * CELL - 0.02)
		Stage3D.box(n, body, Vector3(sz.x * CELL * 0.5, h * 0.5, sz.y * CELL * 0.5), m)
		for k2: int in 2:  # sangles
			var strap_at: Vector3 = Vector3(sz.x * CELL * (0.3 + 0.4 * float(k2)), h * 0.5 + 0.002, sz.y * CELL * 0.5)
			Stage3D.box(n, Vector3(0.025, h + 0.006, sz.y * CELL - 0.015), strap_at, Stage3D.mat(col.darkened(0.45), 0.0, 0.6))
		Stage3D.box(n, Vector3(0.08, 0.025, 0.02), Vector3(sz.x * CELL * 0.5, h + 0.012, sz.y * CELL - 0.04), brass)  # poignée
		for k3: int in 4:
			var corner: Vector3 = Vector3(0.02 + (sz.x * CELL - 0.04) * float(k3 % 2), h, 0.02 + (sz.y * CELL - 0.04) * float(k3 / 2))
			Stage3D.box(n, Vector3(0.03, 0.012, 0.03), corner, brass)
	else:
		var canvas: StandardMaterial3D = Stage3D.mat(Color("5a6a4a"), 0.0, 0.85)
		if ghost:
			canvas.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			canvas.albedo_color.a = 0.7
		for c: Vector2i in cells:
			Stage3D.box(n, Vector3(CELL - 0.01, h * 0.9, CELL - 0.01), Vector3((c.x + 0.5) * CELL, h * 0.45, (c.y + 0.5) * CELL), canvas)
		var first: Vector2i = cells[0]
		var handle_at: Vector3 = Vector3((first.x + 0.5) * CELL, h * 0.92, (first.y + 0.5) * CELL)
		Stage3D.box(n, Vector3(0.1, 0.02, 0.02), handle_at, Stage3D.mat(Color("3a2a1a"), 0.0, 0.6))
	return n


func _rebuild_scene() -> void:
	if stage == null:
		return
	for k: int in _models.keys():
		(_models[k] as Node3D).queue_free()
	_models.clear()
	for i: int in _pieces.size():
		if not bool(_pieces[i]["placed"]):
			continue
		var cells: Array[Vector2i] = _shape(i, int(_pieces[i]["rot"]))
		var mdl: Node3D = _model(i, cells)
		mdl.position = _cell_pos(Vector2(_pieces[i]["at"] as Vector2i))
		stage.root.add_child(mdl)
		_models[i] = mdl
	for c0: Node in _ghost.get_children():
		c0.queue_free()
	if _cur >= 0:
		_ghost.add_child(_model(_cur, _shape(_cur, _rot), true))
	for s: Node3D in _cart_slots:
		for c1: Node in s.get_children():
			c1.queue_free()
	if _cur >= 0:  # le bagage en main, aussi sur le chariot (le toucher le tourne)
		_cart_slots[0].add_child(_model(_cur, _shape(_cur, _rot)))
	for k2: int in mini(2, _queue.size()):
		var nxt: int = _queue[k2]
		var mdl2: Node3D = _model(nxt, _shape(nxt, int(_pieces[nxt]["rot"])))
		mdl2.scale = Vector3.ONE * 0.8
		_cart_slots[k2 + 1].add_child(mdl2)


func _sync_3d(dt: float) -> void:
	if _ghost == null:
		return
	GarageSet.animate(_deco, t)
	if _cur != _shown_cur or _rot != _shown_rot:
		_shown_cur = _cur
		_shown_rot = _rot
		_rebuild_scene()
	var ok: bool = _cur >= 0 and fits(_cur, _rot, _cursor)
	var target: Vector3 = _cell_pos(Vector2(_cursor), 0.08 + 0.02 * sin(t * 4.0))
	_ghost.position = _ghost.position.lerp(target, minf(1.0, dt * 18.0)) if _ghost.position.length() > 0.0 else target
	_ghost.visible = _cur >= 0 and _rest <= 0.0
	for c: Node in _ghost.get_children():
		for mi: Node in c.get_children():
			var mesh: MeshInstance3D = mi as MeshInstance3D
			if mesh != null and mesh.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = mesh.material_override as StandardMaterial3D
				mat.emission_enabled = true
				mat.emission = Palette.EMERALD if ok else Palette.ROULETTE_RED
				mat.emission_energy_multiplier = 0.35
	if _rest > 0.0 and not _marks.is_empty() and _marks[_marks.size() - 1] > 0.6:
		_valet.animate(&"cheer", t * 8.0, dt)
	elif _cur >= 0:
		_valet.animate(&"carry", t * 3.0, dt)
	else:
		_valet.animate(&"idle", t * 2.0, dt)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	if stage == null:
		return
	# Contour du coffre et cases libres (pointillés discrets).
	for y: int in _h:
		for x: int in _w:
			if _grid[y * _w + x] != -1:
				continue
			var cpos: Vector2 = stage.project(_cell_pos(Vector2(x + 0.5, y + 0.5), 0.005))
			draw_circle(cpos, 3.0, Color(Palette.IVORY, 0.35))
	text(Vector2(960.0, 105.0), tr("TRIAL_TRUNK_STATUS") % [mini(_round + 1, _rounds()), _rounds(), int(round(filled() * 100.0))],
		UiKit.SIZE_BODY, Palette.IVORY)
	if _cur >= 0 and _rest <= 0.0:
		text(stage.project(_cart_slots[0].global_position) + Vector2(0.0, 60.0), tr("TRIAL_TRUNK_NEXT") % (_queue.size()), UiKit.SIZE_SMALL,
			Palette.IVORY, "body", 4)
	var left: float = clampf(1.0 - (t - _round_t0) / (p("round_seconds") * slow), 0.0, 1.0)
	var bar: Rect2 = Rect2(660.0, 1000.0, 600.0, 16.0)
	draw_rect(bar, Color(Palette.INK, 0.85))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * left, bar.size.y)), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
