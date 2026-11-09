class_name TrialChess
extends ThrowTrial
## LES ÉCHECS ÉCLAIR (Fumoir, 2.0) : sur l'échiquier de buis et d'ébène, les Blancs matent en un
## coup — trouver lequel avant que la pendule ne tombe. Trois positions de plus en plus chargées
## (tirées des données, chacune vérifiée : un seul coup mate). Un coup qui ne mate pas coûte cher.
## Croix : déplacer le curseur ; confirmer : prendre la pièce, puis la poser. Au doigt : toucher
## la pièce, puis la case.
## Note = moyenne des positions (plein si trouvé vite, moins ensuite et à chaque faux coup).

const SQ: float = 0.3
const BOARD_Z: float = 0.45
const IVORY_WOOD: Color = Color("efe0bc")
const EBONY: Color = Color("2a1a14")

var _round: int = 0
var _pos: ChessMini = null
var _solutions: Array[Vector2i] = []
var _cursor: Vector2i = Vector2i(4, 1)
var _picked: int = -1
var _round_t: float = 0.0
var _wrong_n: int = 0
var _wrong_total: int = 0
var _rest: float = 0.0
var _undo: float = 0.0
var _undo_pos: ChessMini = null
var _marks: Array[float] = []
var _ended: bool = false
var _mated: bool = false
var _top_y: float = 0.0
var _deco: Dictionary = {}
var _pieces: Dictionary[int, Node3D] = {}
var _cursor_n: MeshInstance3D = null
var _pick_n: MeshInstance3D = null
var _dots: Array[MeshInstance3D] = []
var _opp: Figure3D = null
var _slide: Dictionary = {}
var _king_fall: float = 0.0


func begin() -> void:
	_build_3d()
	_new_round()


func _rounds() -> int:
	return pi("rounds")


func _limit() -> float:
	return pk("limit", _round) * slow


func _new_round() -> void:
	var pool: Array[Dictionary] = []
	for e: Variant in entry.get("puzzles", []):
		var d: Dictionary = e as Dictionary
		if int(d.get("tier", 0)) == int(pk("tier", _round)):
			pool.append(d)
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	_pos = ChessMini.from_fen(String(pick["fen"]))
	_solutions = _pos.mating_moves()
	_picked = -1
	_round_t = 0.0
	_wrong_n = 0
	_mated = false
	_king_fall = 0.0
	_cursor = Vector2i(4, 1)
	_rebuild_pieces()


## Prendre / poser sur la case `s`.
func choose(s: int) -> void:
	if _ended or _rest > 0.0 or _undo > 0.0:
		return
	var p: String = _pos.piece_at(s)
	if _picked < 0:
		if ChessMini.is_white(p):
			_picked = s
			AudioBus.play("tick", 1.2, -10.0)
		return
	if s == _picked:
		_picked = -1
		return
	if ChessMini.is_white(p):
		_picked = s
		AudioBus.play("tick", 1.2, -10.0)
		return
	var mv: Vector2i = Vector2i(_picked, s)
	if not mv in _pos.moves(true):
		AudioBus.play("lose_soft", 1.6, -14.0)
		return
	_play(mv)


func _play(mv: Vector2i) -> void:
	_picked = -1
	var before: ChessMini = _pos
	_pos = _pos.apply(mv)
	_slide = {"from": mv.x, "to": mv.y, "u": 0.0}
	_rebuild_pieces()
	AudioBus.play("decor_topple", 1.3, -6.0)
	if mv in _solutions:
		_mated = true
		var over: float = maxf(0.0, _round_t / _limit() - p("grace"))
		var q: float = clampf(1.0 - over * p("late_weight"), p("late_floor"), 1.0) * pow(p("wrong_mult"), float(_wrong_n))
		_close(q, "TRIAL_CHESS_MATE")
	else:
		_wrong_n += 1
		_wrong_total += 1
		_undo = p("undo_seconds") * slow
		_undo_pos = before
		_round_t += p("wrong_seconds")
		pop(Vector2(960.0, 300.0), 0.0, "TRIAL_CHESS_NOT_MATE")


func _close(q: float, key: String) -> void:
	_marks.append(q)
	pop(Vector2(960.0, 300.0), q, key)
	if q > 0.0:
		AudioBus.play("chime", 1.0, -4.0)
	_rest = p("rest_seconds") * slow


func tick(dt: float) -> void:
	if not _slide.is_empty():
		_slide["u"] = minf(1.0, float(_slide["u"]) + dt / 0.22)
	if _mated:
		_king_fall = minf(1.0, _king_fall + dt * 2.0)
	_sync_3d(dt)
	if _ended:
		return
	if _undo > 0.0:
		_undo -= dt
		if _undo <= 0.0:
			_pos = _undo_pos
			_slide = {}
			_rebuild_pieces()
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
	_round_t += dt
	if _round_t >= _limit():
		_close(0.0, "TRIAL_CHESS_FLAG")


func handle(event: InputEvent) -> bool:
	var d: Vector2i = dir_pressed(event)
	if d != Vector2i.ZERO:
		_cursor = Vector2i(clampi(_cursor.x + d.x, 0, 7), clampi(_cursor.y - d.y, 0, 7))
		return true
	if confirm_pressed(event):
		choose(ChessMini.sq(_cursor.x, _cursor.y))
		return true
	return false


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or stage == null:
		return true
	var hit: Vector3 = stage.unproject_to_plane(mb.position, _top_y)
	if hit == Vector3.INF:
		return true
	var f: int = int(floor(hit.x / SQ + 4.0))
	var rk: int = int(floor(4.0 - (hit.z - BOARD_Z) / SQ))
	if f >= 0 and f < 8 and rk >= 0 and rk < 8:
		_cursor = Vector2i(f, rk)
		choose(ChessMini.sq(f, rk))
	return true


func journal() -> Dictionary:
	return {"positions": _marks.size(), "wrong": _wrong_total}


# --------------------------------------------------------------------------- bot


## Le bot connaît le mat : il mène le curseur à la pièce, la prend, puis à la case d'arrivée.
func bot_wants() -> Dictionary:
	if _ended or _rest > 0.0 or _undo > 0.0 or _solutions.is_empty():
		return {"do": ""}
	var mv: Vector2i = _solutions[0]
	var goal: int = mv.x if _picked != mv.x else mv.y
	var g: Vector2i = ChessMini.coord(goal)
	if g == _cursor:
		return {"do": "confirm"}
	var step: Vector2i = Vector2i(signi(g.x - _cursor.x), 0) if g.x != _cursor.x else Vector2i(0, -signi(g.y - _cursor.y))
	return {"do": "dir", "dir": step}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"dir":
			var d: Vector2i = w["dir"] as Vector2i
			_cursor = Vector2i(clampi(_cursor.x + d.x, 0, 7), clampi(_cursor.y - d.y, 0, 7))
		"confirm":
			choose(ChessMini.sq(_cursor.x, _cursor.y))


# --------------------------------------------------------------------------- décor 3D


func _sq_pos(s: int, lift: float = 0.0) -> Vector3:
	var c: Vector2i = ChessMini.coord(s)
	return Vector3((float(c.x) - 3.5) * SQ, _top_y + lift, BOARD_Z + (3.5 - float(c.y)) * SQ)


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = SmokingSet.build(st, 960.0, 1560.0, [])
	var r: Node3D = st.root
	var floor3: float = st.to3(Vector2(0.0, 960.0)).y
	_top_y = floor3 + 0.8
	# Guéridon, échiquier marqueté et son cadre, coordonnées.
	var wood: StandardMaterial3D = Stage3D.textured("wood", SmokingSet.WALNUT, 0.6, 0.0, 0.3)
	Stage3D.box(r, Vector3(3.6, 0.06, 3.0), Vector3(0, _top_y - 0.075, BOARD_Z), wood)
	Stage3D.cylinder(r, 0.12, 0.74, Vector3(0, floor3 + 0.37, BOARD_Z), wood)
	var frame: StandardMaterial3D = Stage3D.mat(Color("3a1a0c"), 0.0, 0.3)
	Stage3D.box(r, Vector3(SQ * 8.0 + 0.16, 0.04, SQ * 8.0 + 0.16), Vector3(0, _top_y - 0.025, BOARD_Z), frame)
	var light: StandardMaterial3D = Stage3D.textured("wood", Color("e8cc98"), 0.4, 0.0, 0.3)
	var dark: StandardMaterial3D = Stage3D.textured("wood", Color("5a2e14"), 0.4, 0.0, 0.3)
	for s: int in 64:
		var c: Vector2i = ChessMini.coord(s)
		Stage3D.box(r, Vector3(SQ, 0.02, SQ), _sq_pos(s, -0.005), light if (c.x + c.y) % 2 == 1 else dark)
	for k: int in 8:
		var file_at: Vector3 = Vector3((float(k) - 3.5) * SQ, _top_y + 0.005, BOARD_Z + SQ * 4.0 + 0.08)
		Stage3D.text3d(r, "abcdefgh"[k], file_at, 44, Palette.GOLD_LIGHT)
		Stage3D.text3d(r, str(k + 1), Vector3(-SQ * 4.0 - 0.06, _top_y + 0.005, BOARD_Z + (3.5 - float(k)) * SQ), 44, Palette.GOLD_LIGHT)
	_cursor_n = Stage3D.box(r, Vector3(SQ * 0.96, 0.006, SQ * 0.96), Vector3.ZERO, Stage3D.glow(Palette.GOLD_LIGHT, 1.2))
	_pick_n = Stage3D.box(r, Vector3(SQ * 0.96, 0.007, SQ * 0.96), Vector3.ZERO, Stage3D.glow(Palette.EMERALD, 1.2))
	for _k2: int in 28:
		var dot: MeshInstance3D = Stage3D.cylinder(r, SQ * 0.12, 0.006, Vector3.ZERO, Stage3D.glow(Palette.EMERALD, 0.8))
		dot.visible = false
		_dots.append(dot)
	# Pendule d'échecs et l'adversaire qui réfléchit.
	var clock_at: Vector3 = Vector3(SQ * 4.0 + 0.45, _top_y + 0.1, BOARD_Z - 0.2)
	Stage3D.box(r, Vector3(0.42, 0.2, 0.16), clock_at, wood)
	for sx: float in [-0.1, 0.1]:
		Stage3D.cylinder(r, 0.065, 0.02, clock_at + Vector3(sx, 0.02, 0.085), Stage3D.mat(Color("f4ecd8"), 0.0, 0.5)).rotation.x = PI * 0.5
		Stage3D.cylinder(r, 0.015, 0.05, clock_at + Vector3(sx, 0.13, 0), Stage3D.mat(Palette.GOLD, 0.85, 0.3))
	SmokingSet.club_chair(r, Vector3(0.0, floor3, BOARD_Z - 1.9))
	_opp = SmokingSet.gentleman(1.75, Color("1a1a2a"), Color("b0b0b0"))
	_opp.position = Vector3(0.0, floor3, BOARD_Z - 1.75)
	r.add_child(_opp)
	SmokingSet.banker_lamp(r, Vector3(-SQ * 4.0 - 0.45, _top_y - 0.03, BOARD_Z - 0.6), true)
	st.look(Vector3(0.0, _top_y + p("cam_h"), BOARD_Z + p("cam_back")), Vector3(0.0, _top_y, BOARD_Z - 0.35), 40.0)


func _rebuild_pieces() -> void:
	if stage == null:
		return
	for n: Node3D in _pieces.values():
		n.queue_free()
	_pieces.clear()
	for s: int in 64:
		var p: String = _pos.piece_at(s)
		if p == "":
			continue
		var n2: Node3D = piece_model(p)
		n2.position = _sq_pos(s)
		stage.root.add_child(n2)
		_pieces[s] = n2


## Pièce de style Staunton construite en primitives (hauteur ≈ 0.12 à 0.3).
static func piece_model(p: String) -> Node3D:
	var n: Node3D = Node3D.new()
	var white: bool = ChessMini.is_white(p)
	var m: StandardMaterial3D = Stage3D.mat(IVORY_WOOD if white else EBONY, 0.0, 0.3)
	var felt: StandardMaterial3D = Stage3D.mat(Color("1e4a2a"), 0.0, 1.0)
	Stage3D.cylinder(n, 0.1, 0.012, Vector3(0, 0.006, 0), felt)
	Stage3D.cylinder(n, 0.1, 0.04, Vector3(0, 0.03, 0), m, 0.085)
	match p.to_lower():
		"p":
			Stage3D.cylinder(n, 0.05, 0.08, Vector3(0, 0.09, 0), m, 0.03)
			Stage3D.sphere(n, 0.045, Vector3(0, 0.15, 0), m)
		"r":
			Stage3D.cylinder(n, 0.065, 0.15, Vector3(0, 0.125, 0), m, 0.055)
			Stage3D.cylinder(n, 0.075, 0.04, Vector3(0, 0.215, 0), m)
			for k: int in 4:
				var a: float = TAU * float(k) / 4.0 + PI * 0.25
				Stage3D.box(n, Vector3(0.035, 0.03, 0.035), Vector3(cos(a) * 0.05, 0.25, sin(a) * 0.05), m)
		"n":
			Stage3D.cylinder(n, 0.06, 0.08, Vector3(0, 0.09, 0), m, 0.05)
			var head: MeshInstance3D = Stage3D.box(n, Vector3(0.07, 0.16, 0.1), Vector3(0, 0.19, 0.01), m)
			head.rotation.x = -0.35
			var snout: MeshInstance3D = Stage3D.box(n, Vector3(0.065, 0.06, 0.12), Vector3(0, 0.235, 0.07), m)
			snout.rotation.x = 0.4
			Stage3D.box(n, Vector3(0.02, 0.1, 0.04), Vector3(0, 0.24, -0.05), m)
			n.rotation.y = 0.0 if white else PI
		"b":
			Stage3D.cylinder(n, 0.055, 0.14, Vector3(0, 0.12, 0), m, 0.03)
			var mitre: MeshInstance3D = Stage3D.sphere(n, 0.05, Vector3(0, 0.23, 0), m)
			mitre.scale = Vector3(1.0, 1.5, 1.0)
			Stage3D.sphere(n, 0.018, Vector3(0, 0.31, 0), m)
		"q":
			Stage3D.cylinder(n, 0.06, 0.2, Vector3(0, 0.15, 0), m, 0.03)
			Stage3D.cylinder(n, 0.065, 0.05, Vector3(0, 0.27, 0), m, 0.04)
			for k2: int in 8:
				var a2: float = TAU * float(k2) / 8.0
				Stage3D.sphere(n, 0.014, Vector3(cos(a2) * 0.055, 0.3, sin(a2) * 0.055), m)
			Stage3D.sphere(n, 0.022, Vector3(0, 0.31, 0), m)
		"k":
			Stage3D.cylinder(n, 0.065, 0.22, Vector3(0, 0.16, 0), m, 0.032)
			Stage3D.cylinder(n, 0.06, 0.05, Vector3(0, 0.29, 0), m, 0.045)
			Stage3D.box(n, Vector3(0.018, 0.08, 0.018), Vector3(0, 0.355, 0), m)
			Stage3D.box(n, Vector3(0.06, 0.018, 0.018), Vector3(0, 0.36, 0), m)
	return n


func _sync_3d(dt: float) -> void:
	if _opp == null:
		return
	_opp.animate(&"tic", fposmod(t * 0.45, 1.0), dt, 2.0)
	SmokingSet.animate(_deco, stage, 960.0, t)
	_cursor_n.position = _sq_pos(ChessMini.sq(_cursor.x, _cursor.y), 0.004)
	_cursor_n.visible = not _ended and _rest <= 0.0
	_pick_n.visible = _picked >= 0
	if _picked >= 0:
		_pick_n.position = _sq_pos(_picked, 0.005)
	var targets: Array[int] = []
	if _picked >= 0:
		for mv: Vector2i in _pos.moves(true):
			if mv.x == _picked:
				targets.append(mv.y)
	for k: int in _dots.size():
		_dots[k].visible = k < targets.size()
		if k < targets.size():
			_dots[k].position = _sq_pos(targets[k], 0.006)
	if not _slide.is_empty() and _pieces.has(int(_slide["to"])):
		var u: float = float(_slide["u"])
		var e: float = u * u * (3.0 - 2.0 * u)
		var a: Vector3 = _sq_pos(int(_slide["from"]))
		var b: Vector3 = _sq_pos(int(_slide["to"]))
		_pieces[int(_slide["to"])].position = a.lerp(b, e) + Vector3(0, sin(u * PI) * 0.08, 0)
	if _mated:
		var ks: int = _pos.king_square(false)
		if _pieces.has(ks):
			_pieces[ks].rotation.z = -PI * 0.5 * _king_fall * _king_fall
			_pieces[ks].position = _sq_pos(ks, 0.0) + Vector3(0.06 * _king_fall, 0.05 * _king_fall, 0)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	text(Vector2(960.0, 105.0), tr("TRIAL_CHESS_STATUS") % [mini(_round + 1, _rounds()), _rounds()], UiKit.SIZE_BODY, Palette.IVORY)
	text(Vector2(960.0, 150.0), tr("TRIAL_CHESS_TASK"), UiKit.SIZE_SMALL, Palette.GOLD_LIGHT, "body", 4)
	if _rest <= 0.0 and not _ended:
		var left: float = clampf(1.0 - _round_t / _limit(), 0.0, 1.0)
		draw_rect(Rect2(760.0, 175.0, 400.0 * left, 8.0), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
