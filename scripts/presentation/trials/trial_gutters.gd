class_name TrialGutters
extends ThrowTrial
## LES GOUTTIÈRES (Toits, 2.0) : l'orage monte. La pluie tombe dans la gargouille en haut du mur
## de zinc ; il faut tourner les coudes et les tés de la tuyauterie pour la mener jusqu'au
## tonneau, avant que le chéneau ne déborde. Trois réseaux, de plus en plus grands, avec des
## pièces en trop qui mènent nulle part. Curseur (croix / stick) et bouton pour tourner, ou
## toucher / cliquer directement une pièce.
## Note = moyenne des réseaux (plein si raccordé vite, moins ensuite ; rien s'il déborde).

enum Kind { STRAIGHT, ELBOW, TEE }

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8
const DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const BITS: Array[int] = [N, E, S, W]
const BASE: Array[int] = [N | S, N | E, N | E | S]
const TILE: float = 128.0
const PX3: float = 0.005
const TOP_Y: float = 250.0

var _cols: int = 5
var _rows: int = 4
var _round: int = 0
var _kind: Array[int] = []
var _rot: Array[int] = []
var _sol: Array[int] = []
var _src: int = 0
var _dst: int = 0
var _wet: Dictionary[int, bool] = {}
var _cursor: Vector2i = Vector2i.ZERO
var _round_t: float = 0.0
var _drain: float = 0.0
var _marks: Array[float] = []
var _rotations: int = 0
var _ended: bool = false
var _deco: Dictionary = {}
var _pieces: Array[Node3D] = []
var _pipe_mats: Array[StandardMaterial3D] = []
var _board3: Node3D = null
var _barrel_water: MeshInstance3D = null
var _gutter_water: MeshInstance3D = null
var _spout: Node3D = null
var _barrel3: Node3D = null


func begin() -> void:
	_build_3d()
	_new_round()


func _rounds() -> int:
	return pi("rounds")


func _limit() -> float:
	return pk("limit", _round) * slow


func _origin() -> Vector2:
	return Vector2(960.0 - float(_cols) * TILE * 0.5, minf(TOP_Y, 520.0 - float(_rows) * TILE * 0.5 - 20.0))


func _cell_center(c: Vector2i) -> Vector2:
	return _origin() + Vector2((float(c.x) + 0.5) * TILE, (float(c.y) + 0.5) * TILE)


func _idx(c: Vector2i) -> int:
	return c.y * _cols + c.x


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < _cols and c.y < _rows


## Ouvertures d'une pièce tournée de r quarts de tour (sens horaire).
static func mask(kind: int, r: int) -> int:
	var m: int = BASE[kind]
	for _k: int in posmod(r, 4):
		m = ((m << 1) | (m >> 3)) & 15
	return m


# --------------------------------------------------------------------------- réseau


## Tire un chemin sans boucle de la gargouille (haut, colonne src) au tonneau (bas, colonne dst),
## pose les pièces qui le réalisent, remplit le reste de pièces au hasard, puis mélange les
## orientations (jamais déjà raccordé).
func _new_round() -> void:
	_cols = int(pk("cols", _round))
	_rows = int(pk("rows", _round))
	_kind.clear()
	_rot.clear()
	_sol.clear()
	for _k: int in _cols * _rows:
		_kind.append(rng.randi_range(0, 2))
		_rot.append(rng.randi_range(0, 3))
		_sol.append(-1)
	_src = rng.randi_range(0, _cols - 1)
	var path: Array[Vector2i] = _walk()
	_dst = path[-1].x
	for k: int in path.size():
		var c: Vector2i = path[k]
		var need: int = N if k == 0 else _bit_toward(c, path[k - 1])
		need |= S if k == path.size() - 1 else _bit_toward(c, path[k + 1])
		var placed: bool = false
		for kind: int in [Kind.STRAIGHT, Kind.ELBOW]:
			for r: int in 4:
				if not placed and mask(kind, r) == need:
					_kind[_idx(c)] = kind
					_sol[_idx(c)] = r
					placed = true
		if not placed:
			_kind[_idx(c)] = Kind.TEE
			for r2: int in 4:
				if mask(Kind.TEE, r2) & need == need and _sol[_idx(c)] < 0:
					_sol[_idx(c)] = r2
	for k2: int in path.size():
		var i: int = _idx(path[k2])
		_rot[i] = posmod(_sol[i] + rng.randi_range(1, 3), 4)
	_flow()
	if _solved():
		var i0: int = _idx(path[0])
		_rot[i0] = posmod(_rot[i0] + 1, 4)
		_flow()
	_cursor = Vector2i(_src, 0)
	_round_t = 0.0
	_rebuild_pieces()


## Marche aléatoire autoévitante vers le bas (jamais vers le haut), qui serpente.
func _walk() -> Array[Vector2i]:
	for _attempt: int in 64:
		var path: Array[Vector2i] = [Vector2i(_src, 0)]
		var seen: Dictionary[Vector2i, bool] = {Vector2i(_src, 0): true}
		var ok: bool = true
		while path[-1].y < _rows - 1 or path.size() < int(pk("min_path", _round)):
			var c: Vector2i = path[-1]
			var options: Array[Vector2i] = []
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1)]:
				var nc: Vector2i = c + d
				if _inside(nc) and not seen.has(nc):
					options.append(nc)
					if d.y == 0:
						options.append(nc)  # favorise les détours latéraux
			if options.is_empty():
				ok = false
				break
			var pick: Vector2i = options[rng.randi_range(0, options.size() - 1)]
			if path[-1].y == _rows - 1 and pick.y == path[-1].y and path.size() >= int(pk("min_path", _round)):
				break
			path.append(pick)
			seen[pick] = true
		if ok and path[-1].y == _rows - 1 and path.size() >= int(pk("min_path", _round)):
			return path
	var straight: Array[Vector2i] = []
	for y: int in _rows:
		straight.append(Vector2i(_src, y))
	return straight


func _bit_toward(from: Vector2i, to: Vector2i) -> int:
	return BITS[DIRS.find(to - from)]


## L'eau entre par le haut de la case source et suit les raccords (les deux pièces ouvertes).
func _flow() -> void:
	_wet.clear()
	var start: Vector2i = Vector2i(_src, 0)
	if mask(_kind[_idx(start)], _rot[_idx(start)]) & N == 0:
		return
	var todo: Array[Vector2i] = [start]
	_wet[_idx(start)] = true
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		var m: int = mask(_kind[_idx(c)], _rot[_idx(c)])
		for d: int in 4:
			if m & BITS[d] == 0:
				continue
			var nc: Vector2i = c + DIRS[d]
			if not _inside(nc) or _wet.has(_idx(nc)):
				continue
			if mask(_kind[_idx(nc)], _rot[_idx(nc)]) & BITS[(d + 2) % 4] != 0:
				_wet[_idx(nc)] = true
				todo.append(nc)


func _solved() -> bool:
	var end: Vector2i = Vector2i(_dst, _rows - 1)
	return _wet.has(_idx(end)) and mask(_kind[_idx(end)], _rot[_idx(end)]) & S != 0


func rotate_at(c: Vector2i) -> void:
	if _ended or _drain > 0.0 or not _inside(c):
		return
	_cursor = c
	var i: int = _idx(c)
	_rot[i] = posmod(_rot[i] + 1, 4)
	_rotations += 1
	AudioBus.play("decor_switch", rng.randf_range(0.9, 1.1), -8.0)
	_flow()
	if _solved():
		var over: float = maxf(0.0, _round_t / _limit() - p("grace"))
		var q: float = clampf(1.0 - over * p("late_weight"), p("late_floor"), 1.0)
		_marks.append(q)
		_drain = p("drain_seconds") * slow
		pop(_cell_center(Vector2i(_dst, _rows - 1)) + Vector2(0, 120.0), q, "TRIAL_GUTTERS_FLOWING")
		AudioBus.play("decor_puff", 0.8, -4.0)


func tick(dt: float) -> void:
	_sync_3d(dt)
	if _ended:
		return
	if _drain > 0.0:
		_drain -= dt
		if _drain <= 0.0:
			_next()
		return
	_round_t += dt
	if _round_t >= _limit():
		_marks.append(0.0)
		pop(Vector2(960.0, TOP_Y - 60.0), 0.0, "TRIAL_GUTTERS_OVERFLOW")
		AudioBus.play("decor_puff", 0.6, -2.0)
		_drain = p("drain_seconds") * 0.6 * slow
		_round_t = _limit()


func _next() -> void:
	_round += 1
	if _round >= _rounds():
		_ended = true
		finish(ThrowTrial.mean(_marks))
		return
	_new_round()


func handle(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_tap(mb.position)
		return true
	var d: Vector2i = dir_pressed(event)
	if d != Vector2i.ZERO:
		_cursor = Vector2i(clampi(_cursor.x + d.x, 0, _cols - 1), clampi(_cursor.y + d.y, 0, _rows - 1))
		AudioBus.play("tick", 1.4, -14.0)
		return true
	if confirm_pressed(event):
		rotate_at(_cursor)
		return true
	return false


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_tap(mb.position)
	return true


func _tap(pos: Vector2) -> void:
	var rel: Vector2 = (pos - _origin()) / TILE
	var c: Vector2i = Vector2i(floori(rel.x), floori(rel.y))
	if _inside(c):
		rotate_at(c)


func journal() -> Dictionary:
	return {"rounds": _marks.size(), "rotations": _rotations}


# --------------------------------------------------------------------------- bot


## Va à la prochaine pièce du chemin mal orientée (dans l'ordre de l'eau) et la tourne.
func bot_wants() -> Dictionary:
	if _drain > 0.0 or _ended:
		return {"do": ""}
	var target: Vector2i = Vector2i(-1, -1)
	var best: int = 1 << 20
	for i: int in _sol.size():
		if _sol[i] < 0 or _sound(i):
			continue
		var c: Vector2i = Vector2i(i % _cols, i / _cols)
		var dist: int = absi(c.x - _cursor.x) + absi(c.y - _cursor.y)
		if dist < best:
			best = dist
			target = c
	if target.x < 0:
		return {"do": ""}
	if target != _cursor:
		var d: Vector2i = target - _cursor
		return {"do": "dir", "dir": Vector2i(signi(d.x), 0) if d.x != 0 else Vector2i(0, signi(d.y))}
	return {"do": "confirm"}


## La pièce i ouvre-t-elle déjà ce que le chemin demande ?
func _sound(i: int) -> bool:
	var need: int = mask(_kind[i], _sol[i])
	return mask(_kind[i], _rot[i]) & need == need and (_kind[i] == Kind.TEE or mask(_kind[i], _rot[i]) == need)


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"dir":
			var d: Vector2i = w["dir"] as Vector2i
			_cursor = Vector2i(clampi(_cursor.x + d.x, 0, _cols - 1), clampi(_cursor.y + d.y, 0, _rows - 1))
		"confirm":
			rotate_at(_cursor)


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(PX3, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = RooftopSet.build(st, 980.0, [180.0, 1760.0], 23)
	var r: Node3D = st.root
	# Mur de zinc à joints debout derrière la tuyauterie, chéneau en haut, gargouille.
	var zinc: StandardMaterial3D = Stage3D.mat(RooftopSet.ZINC.lightened(0.1), 0.75, 0.4)
	Stage3D.box(r, Vector3(5.6, 4.3, 0.06), st.to3(Vector2(960.0, 560.0), -0.35), zinc)
	for k: int in 15:
		var seam: Vector3 = st.to3(Vector2(960.0 - 560.0 + 80.0 * float(k), 560.0), -0.3)
		Stage3D.box(r, Vector3(0.025, 4.3, 0.05), seam, Stage3D.mat(RooftopSet.ZINC_D, 0.7, 0.4))
	var gutter: MeshInstance3D = Stage3D.cylinder(r, 0.14, 5.8, st.to3(Vector2(960.0, 150.0), -0.1), zinc)
	gutter.rotation.z = PI * 0.5
	_gutter_water = Stage3D.box(r, Vector3(5.7, 0.02, 0.2), st.to3(Vector2(960.0, 160.0), -0.1), Stage3D.glow(Color(0.35, 0.6, 1.0), 0.8))
	_spout = Node3D.new()
	r.add_child(_spout)
	var stone: StandardMaterial3D = Stage3D.mat(Color("8a8478"), 0.0, 0.9)
	Stage3D.box(_spout, Vector3(0.22, 0.2, 0.4), Vector3(0, 0, 0.1), stone)
	Stage3D.sphere(_spout, 0.13, Vector3(0, 0.08, 0.3), stone)
	for ex: float in [-0.05, 0.05]:
		Stage3D.sphere(_spout, 0.025, Vector3(ex, 0.12, 0.42), Stage3D.glow(Color(1.0, 0.6, 0.2), 2.0))
	# Tonneau de chêne cerclé.
	var oak: StandardMaterial3D = Stage3D.mat(Color("6a4422"), 0.0, 0.6)
	_barrel3 = Node3D.new()
	r.add_child(_barrel3)
	Stage3D.cylinder(_barrel3, 0.32, 0.6, Vector3.ZERO, oak, 0.28)
	for hy: float in [-0.2, 0.0, 0.2]:
		Stage3D.cylinder(_barrel3, 0.33, 0.04, Vector3(0, hy, 0), Stage3D.mat(Color("2a2a30"), 0.8, 0.4))
	_barrel_water = Stage3D.cylinder(_barrel3, 0.27, 0.02, Vector3(0, -0.26, 0), Stage3D.glow(Color(0.35, 0.6, 1.0), 0.8))
	# Descente de zinc entre la dernière rangée et le tonneau.
	Stage3D.cylinder(_barrel3, 0.06, 0.5, Vector3(0, 0.5, -0.05), zinc)
	_board3 = Node3D.new()
	r.add_child(_board3)


func _rebuild_pieces() -> void:
	for n: Node3D in _pieces:
		n.queue_free()
	_pieces.clear()
	_pipe_mats.clear()
	var st: Stage3D = stage
	var half: float = TILE * PX3 * 0.5
	for i: int in _kind.size():
		var c: Vector2i = Vector2i(i % _cols, i / _cols)
		var piece: Node3D = Node3D.new()
		piece.position = st.to3(_cell_center(c), 0.0)
		_board3.add_child(piece)
		var m: StandardMaterial3D = Stage3D.mat(RooftopSet.TERRACOTTA.lerp(Color("c87840"), 0.6), 0.85, 0.3)
		_pipe_mats.append(m)
		Stage3D.sphere(piece, 0.09, Vector3.ZERO, m)
		var base: int = BASE[_kind[i]]
		for d: int in 4:
			if base & BITS[d] == 0:
				continue
			var dir3: Vector3 = Vector3(float(DIRS[d].x), -float(DIRS[d].y), 0)
			var arm: MeshInstance3D = Stage3D.cylinder(piece, 0.065, half, dir3 * half * 0.5, m)
			var collar: MeshInstance3D = Stage3D.cylinder(piece, 0.08, 0.04, dir3 * (half - 0.02), Stage3D.mat(Color("2a2a30"), 0.8, 0.4))
			if DIRS[d].x != 0:
				arm.rotation.z = PI * 0.5
				collar.rotation.z = PI * 0.5
		piece.rotation.z = -float(_rot[i]) * PI * 0.5
		_pieces.append(piece)
	_spout.position = st.to3(_cell_center(Vector2i(_src, 0)) - Vector2(0, TILE * 0.75), 0.0)
	_barrel3.position = st.to3(Vector2(_cell_center(Vector2i(_dst, 0)).x, _origin().y + float(_rows) * TILE + 170.0), 0.2)


func _sync_3d(dt: float) -> void:
	if _board3 == null:
		return
	for i: int in _pieces.size():
		var want: float = -float(_rot[i]) * PI * 0.5
		var cur: float = _pieces[i].rotation.z
		# Toujours le plus court chemin vers le quart de tour visé.
		var diff: float = wrapf(want - cur, -PI, PI)
		_pieces[i].rotation.z = cur + diff * minf(1.0, dt * 14.0)
		var wet: bool = _wet.has(i)
		_pipe_mats[i].emission_enabled = wet
		_pipe_mats[i].emission = Color(0.3, 0.55, 1.0)
		_pipe_mats[i].emission_energy_multiplier = 0.6 + 0.3 * sin(t * 6.0 + float(i))
	var level: float = clampf(_round_t / maxf(_limit(), 0.01), 0.0, 1.0)
	_gutter_water.scale.y = 1.0 + level * 6.0
	var filled: float = float(_marks.size()) / float(maxi(1, _rounds()))
	_barrel_water.position.y = -0.26 + 0.54 * filled
	RooftopSet.animate(_deco, stage, t, 80.0)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Pluie (de plus en plus drue avec le temps du réseau).
	var level: float = clampf(_round_t / maxf(_limit(), 0.01), 0.0, 1.0)
	var drops: int = 40 + int(level * 80.0)
	for k: int in drops:
		var x: float = fmod(float(k) * 97.3 + t * 140.0, 2000.0) - 40.0
		var y: float = fmod(float(k) * 53.1 + t * 900.0, 1100.0) - 20.0
		draw_line(Vector2(x, y), Vector2(x - 6.0, y + 26.0), Color(0.7, 0.8, 1.0, 0.35), 2.0)
	# Curseur, entrée et sortie.
	var o: Vector2 = _origin()
	draw_rect(Rect2(o, Vector2(float(_cols), float(_rows)) * TILE), Color(Palette.INK, 0.25), false, 2.0)
	if not mouse or InputGlyphs.using_pad:
		draw_rect(Rect2(o + Vector2(_cursor) * TILE, Vector2(TILE, TILE)).grow(-4.0), Palette.GOLD_LIGHT, false, 5.0)
	var end_c: Vector2 = _cell_center(Vector2i(_dst, _rows - 1)) + Vector2(0, TILE * 0.62)
	var arrow: PackedVector2Array = PackedVector2Array([end_c + Vector2(-16, -8), end_c + Vector2(16, -8), end_c + Vector2(0, 12)])
	draw_colored_polygon(arrow, Palette.EMERALD)
	# Chéneau qui monte : jauge de débordement.
	var gauge: Rect2 = Rect2(1520.0, 260.0, 26.0, 420.0)
	draw_rect(gauge, Color(Palette.INK, 0.85))
	draw_rect(Rect2(gauge.position + Vector2(0, gauge.size.y * (1.0 - level)), Vector2(gauge.size.x, gauge.size.y * level)),
		Color(0.3, 0.55, 1.0).lerp(Palette.ROULETTE_RED, maxf(0.0, level - 0.6) * 2.5))
	var cap_at: Vector2 = gauge.position + Vector2(13.0, gauge.size.y + 30.0)
	text(cap_at, tr("TRIAL_GUTTERS_LEVEL"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	text(Vector2(960.0, 105.0), tr("TRIAL_GUTTERS_STATUS") % [mini(_round + 1, _rounds()), _rounds()], UiKit.SIZE_BODY, Palette.IVORY)
