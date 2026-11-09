class_name TrialDominoes
extends ThrowTrial
## LES DOMINOS (Fumoir, 2.0) : sur le tapis vert de la table de jeu, prolonger la chaîne au plus
## vite. Un domino se pose au bout dont il porte le nombre ; un double se pose en travers et
## rapporte double. Le partenaire d'en face pose lui aussi, de temps en temps, et change un bout :
## il faut suivre. Aucun domino ne va ? Piocher (cela prend un instant). Poser à faux bloque la main.
## Gauche / droite : choisir un domino ; confirmer : le poser ; bas : piocher. Au doigt : toucher
## le domino, ou la pioche.
## Note = points posés / objectif.

const HAND_Y: float = 930.0
const HAND_W: float = 92.0
const TILE_L: float = 84.0
const TILE_S: float = 42.0
const CHAIN_C: Vector2 = Vector2(960.0, 560.0)
const CHAIN_HALF_W: float = 640.0
const ROW_H: float = 120.0
const PILE_AT: Vector2 = Vector2(1680.0, 930.0)

var _hand: Array[Vector2i] = []
var _pile: Array[Vector2i] = []
var _left: Array[Vector2i] = []  # tuiles posées vers la gauche (bout extérieur en .y)
var _right: Array[Vector2i] = []  # tuiles posées vers la droite (bout extérieur en .y)
var _root: Vector2i = Vector2i.ZERO
var _sel: int = 0
var _points: int = 0
var _lock: float = 0.0
var _opp_t: float = 0.0
var _opp_anim: float = 0.0
var _wrong: int = 0
var _draws: int = 0
var _ended: bool = false
var _flash_end: int = -1
var _flash_t: float = 0.0
var _deco: Dictionary = {}
var _opp: Figure3D = null
var _me: Figure3D = null


func begin() -> void:
	_refill_pile()
	_root = _pile.pop_back()
	for _k: int in pi("hand"):
		_hand.append(_pile.pop_back())
	_opp_t = p("opp_first")
	_build_3d()


## Pioche : deux jeux double-six mélangés (les tuiles en main restent en main).
func _refill_pile() -> void:
	var tiles: Array[Vector2i] = []
	for _s: int in 2:
		for a: int in 7:
			for b: int in range(a, 7):
				tiles.append(Vector2i(a, b))
	for i: int in range(tiles.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = tiles[i]
		tiles[i] = tiles[j]
		tiles[j] = tmp
	_pile.append_array(tiles)


func end_value(side: int) -> int:
	var arr: Array[Vector2i] = _left if side == 0 else _right
	if arr.is_empty():
		return _root.x if side == 0 else _root.y
	return arr[-1].y


## Bouts où la tuile se pose (0 gauche, 1 droite).
func fits(tile: Vector2i) -> Array[int]:
	var out: Array[int] = []
	for side: int in 2:
		var e: int = end_value(side)
		if tile.x == e or tile.y == e:
			out.append(side)
	return out


func _orient(tile: Vector2i, e: int) -> Vector2i:
	return tile if tile.x == e else Vector2i(tile.y, tile.x)


## Pose la tuile `i` de la main ; vrai si posée.
func play(i: int) -> bool:
	if _ended or _lock > 0.0 or i < 0 or i >= _hand.size():
		return false
	var tile: Vector2i = _hand[i]
	var sides: Array[int] = fits(tile)
	if sides.is_empty():
		_wrong += 1
		_lock = p("wrong_seconds") * slow
		pop(_hand_pos(i) + Vector2(0, -80), 0.0, "TRIAL_DOMINOES_WRONG")
		AudioBus.play("lose_soft", 1.3, -6.0)
		return false
	# Deux bouts possibles : celui qui laisse le plus de jeu à la main.
	var side: int = sides[0]
	if sides.size() == 2 and _options_after(i, 1) > _options_after(i, 0):
		side = 1
	var placed: Vector2i = _orient(tile, end_value(side))
	(_left if side == 0 else _right).append(placed)
	_hand.remove_at(i)
	if _pile.is_empty():
		_refill_pile()
	_hand.insert(i, _pile.pop_back())
	var gain: int = 2 if tile.x == tile.y else 1
	_points += gain
	_lock = p("place_seconds") * slow
	_flash_end = side
	_flash_t = 0.5
	pop(_end_pos(side), 1.0, "TRIAL_DOMINOES_DOUBLE" if gain == 2 else "")
	AudioBus.play("tick", 0.9 + 0.05 * float(_points % 6), -4.0)
	if _points >= pi("target"):
		_ended = true
		finish(1.0)
	return true


func _options_after(i: int, side: int) -> int:
	var e: int = _orient(_hand[i], end_value(side)).y
	var other: int = end_value(1 - side)
	var n: int = 0
	for k: int in _hand.size():
		if k != i and (_hand[k].x in [e, other] or _hand[k].y in [e, other]):
			n += 1
	return n


func draw_tile() -> void:
	if _ended or _lock > 0.0:
		return
	_draws += 1
	if _pile.is_empty():
		_refill_pile()
	# La plus ancienne tuile de la main retourne sous la pioche.
	_pile.insert(0, _hand[_sel])
	_hand[_sel] = _pile.pop_back()
	_lock = p("draw_seconds") * slow
	AudioBus.play("paper", 1.2, -8.0)


func _opp_play() -> void:
	var side: int = rng.randi_range(0, 1)
	var e: int = end_value(side)
	var other: int = rng.randi_range(0, 6)
	(_left if side == 0 else _right).append(Vector2i(e, other))
	_flash_end = side
	_flash_t = 0.6
	_opp_anim = 1.0
	AudioBus.play("tick", 0.7, -6.0)


func tick(dt: float) -> void:
	_flash_t = maxf(0.0, _flash_t - dt)
	_opp_anim = maxf(0.0, _opp_anim - dt * 2.0)
	_sync_3d(dt)
	if _ended:
		return
	_lock = maxf(0.0, _lock - dt)
	_opp_t -= dt
	if _opp_t <= 0.0:
		_opp_play()
		_opp_t = p("opp_period") * slow * rng.randf_range(0.8, 1.2)
	if t >= p("duration") * slow:
		_ended = true
		finish(clampf(float(_points) / float(pi("target")), 0.0, 1.0))


func handle(event: InputEvent) -> bool:
	var d: Vector2i = dir_pressed(event)
	if d.x != 0:
		_sel = posmod(_sel + d.x, _hand.size())
		AudioBus.play("tick", 1.4, -16.0)
		return true
	if d.y > 0:
		draw_tile()
		return true
	if confirm_pressed(event):
		play(_sel)
		return true
	return false


func direct_input(event: InputEvent) -> bool:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return true
	if mb.position.distance_to(PILE_AT) < 90.0:
		draw_tile()
		return true
	for i: int in _hand.size():
		if Rect2(_hand_pos(i) - Vector2(HAND_W * 0.45, 80.0), Vector2(HAND_W * 0.9, 160.0)).has_point(mb.position):
			_sel = i
			play(i)
			break
	return true


func journal() -> Dictionary:
	return {"points": _points, "wrong": _wrong, "draws": _draws}


# --------------------------------------------------------------------------- bot


## Va au premier domino qui se pose (le plus proche du curseur), le pose ; sinon pioche.
func bot_wants() -> Dictionary:
	if _ended or _lock > 0.0:
		return {"do": ""}
	var best: int = -1
	for k: int in _hand.size():
		if not fits(_hand[k]).is_empty():
			var dk: int = absi(k - _sel)
			if best < 0 or dk < absi(best - _sel) or (dk == absi(best - _sel) and _hand[k].x == _hand[k].y):
				best = k
	if best < 0:
		return {"do": "dir", "dir": Vector2i(0, 1)}
	if best != _sel:
		return {"do": "dir", "dir": Vector2i(signi(best - _sel), 0)}
	return {"do": "confirm"}


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"dir":
			var d: Vector2i = w["dir"] as Vector2i
			if d.x != 0:
				_sel = posmod(_sel + d.x, _hand.size())
			elif d.y > 0:
				draw_tile()
		"confirm":
			play(_sel)


# --------------------------------------------------------------------------- décor 3D


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.frontal(0.005, Vector2(960.0, 540.0), 1080.0, 40.0)
	_deco = SmokingSet.build(st, 960.0, 1500.0)
	var r: Node3D = st.root
	var floor_y: float = st.to3(Vector2(0.0, 960.0)).y
	var top_y: float = floor_y + 0.78
	# Table de jeu : tapis vert, ceinture d'acajou, pieds.
	var felt: StandardMaterial3D = Stage3D.textured("felt", Color("1e5a34"), 0.5, 0.0, 1.0)
	var maho: StandardMaterial3D = Stage3D.textured("wood", Color("5a2412"), 0.6, 0.0, 0.3)
	Stage3D.box(r, Vector3(4.2, 0.04, 2.0), Vector3(0, top_y, 0.6), felt)
	for sz: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(4.4, 0.08, 0.12), Vector3(0, top_y - 0.01, 0.6 + sz * 1.05), maho)
	for sx: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(0.12, 0.08, 2.2), Vector3(sx * 2.15, top_y - 0.01, 0.6), maho)
	SmokingSet.banker_lamp(r, Vector3(1.7, top_y + 0.02, -0.25), true)
	Stage3D.cylinder(r, 0.09, 0.03, Vector3(-1.75, top_y + 0.035, -0.2), Stage3D.mat(Color("8a8a90"), 0.8, 0.3), 0.07)
	# Le partenaire en face, l'autre joueur à côté (accoudé).
	SmokingSet.club_chair(r, Vector3(0.0, floor_y, -0.75))
	_opp = SmokingSet.gentleman(1.75, Color("1a2a1a"), Color("5a5a5a"))
	_opp.position = Vector3(0.0, floor_y, -0.65)
	r.add_child(_opp)
	_me = SmokingSet.gentleman(1.75, Color("3a1a2a"))
	_me.position = Vector3(-2.9, floor_y, 0.2)
	_me.rotation.y = PI * 0.5
	r.add_child(_me)
	st.look(Vector3(0.0, top_y + p("cam_h"), 0.6 + p("cam_back")), Vector3(0.0, top_y + 0.1, 0.1), 40.0)


func _sync_3d(dt: float) -> void:
	if _opp == null:
		return
	_opp.animate(&"tic", 1.0 - _opp_anim if _opp_anim > 0.0 else 0.0, dt, 3.0)
	_me.animate(&"sit", t, dt, 0.8)
	SmokingSet.animate(_deco, stage, 960.0, t)


# --------------------------------------------------------------------------- dessin


## Position (centre) de la k-ième tuile d'un côté : la chaîne serpente pour rester sur le tapis.
func _chain_pos(side: int, k: int) -> Dictionary:
	var dir: float = -1.0 if side == 0 else 1.0
	var per_row: int = int(CHAIN_HALF_W / TILE_L)
	var row: int = k / per_row
	var col: int = k % per_row
	var reach: float = float(col) + 1.0 if row % 2 == 0 else float(per_row - col)
	var y: float = CHAIN_C.y - dir * ROW_H * float(row)
	return {"at": Vector2(CHAIN_C.x + dir * TILE_L * reach, y), "flip": row % 2 == 1}


func _end_pos(side: int) -> Vector2:
	var arr: Array[Vector2i] = _left if side == 0 else _right
	if arr.is_empty():
		return CHAIN_C + Vector2(-TILE_L * 0.5 if side == 0 else TILE_L * 0.5, 0)
	return _chain_pos(side, arr.size() - 1)["at"] as Vector2


func _hand_pos(i: int) -> Vector2:
	return Vector2(960.0 + (float(i) - float(_hand.size() - 1) * 0.5) * (HAND_W + 20.0), HAND_Y)


## Tuile : demi-cases `a` puis `b` dans le sens `axis` (unitaire), centrée en `at`.
func _tile(at: Vector2, a: int, b: int, axis: Vector2, scale_k: float, glow: float = 0.0) -> void:
	var l: float = TILE_L * scale_k
	var w: float = TILE_S * scale_k
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var half_l: Vector2 = axis * l * 0.5
	var half_w: Vector2 = across * w * 0.5
	var corners: PackedVector2Array = [at - half_l - half_w, at + half_l - half_w, at + half_l + half_w, at - half_l + half_w]
	var shadow: PackedVector2Array = PackedVector2Array()
	for c: Vector2 in corners:
		shadow.append(c + Vector2(4, 6) * scale_k)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.35))
	draw_colored_polygon(corners, Color("f4ecd8").lerp(Palette.GOLD_LIGHT, glow))
	corners.append(corners[0])
	draw_polyline(corners, Color("8a7a5a"), 2.0)
	draw_line(at - half_w * 0.8, at + half_w * 0.8, Color("6a5a40"), 2.0)
	draw_circle(at, 2.5 * scale_k, Palette.GOLD)
	for half: int in 2:
		var n: int = a if half == 0 else b
		var c2: Vector2 = at + axis * l * (-0.25 if half == 0 else 0.25)
		for off: Vector2 in pip_offsets(n, axis, w):
			draw_circle(c2 + off, 3.6 * scale_k, Color("141014"))


## Décalages des points d'une demi-case de valeur `n` (axe de la tuile `axis`, largeur `w`).
static func pip_offsets(n: int, axis: Vector2, w: float) -> PackedVector2Array:
	var across: Vector2 = Vector2(-axis.y, axis.x)
	var out: PackedVector2Array = PackedVector2Array()
	for pp: Vector2 in pip_layout(n):
		out.append((axis * pp.x + across * pp.y) * w * 0.26)
	return out


## Points d'une demi-case (repère -1..1), construits en code (une table constante
## `Array[PackedVector2Array]` s'est relue faussée pendant le dessin).
static func pip_layout(n: int) -> Array[Vector2]:
	var c: Vector2 = Vector2.ZERO
	var tl: Vector2 = Vector2(-1, -1)
	var br: Vector2 = Vector2(1, 1)
	var top_r: Vector2 = Vector2(1, -1)
	var bl: Vector2 = Vector2(-1, 1)
	match n:
		1:
			return [c]
		2:
			return [tl, br]
		3:
			return [tl, c, br]
		4:
			return [tl, top_r, bl, br]
		5:
			return [tl, top_r, c, bl, br]
		6:
			return [tl, top_r, Vector2(-1, 0), Vector2(1, 0), bl, br]
	return []


func paint() -> void:
	# Chaîne : la tuile de départ, puis chaque côté.
	var root_double: bool = _root.x == _root.y
	_tile(CHAIN_C, _root.x, _root.y, Vector2.DOWN if root_double else Vector2.RIGHT, 1.0)
	for side: int in 2:
		var arr: Array[Vector2i] = _left if side == 0 else _right
		for k: int in arr.size():
			var info: Dictionary = _chain_pos(side, k)
			var tl: Vector2i = arr[k]
			var out_dir: float = (-1.0 if side == 0 else 1.0) * (-1.0 if bool(info["flip"]) else 1.0)
			var axis: Vector2 = Vector2(out_dir, 0.0)
			if tl.x == tl.y:
				axis = Vector2.DOWN
			var g: float = _flash_t * 1.6 if k == arr.size() - 1 and side == _flash_end else 0.0
			_tile(info["at"] as Vector2, tl.x, tl.y, axis, 1.0 if tl.x != tl.y else 0.9, clampf(g, 0.0, 0.8))
	# Bouts ouverts.
	for side2: int in 2:
		var ep: Vector2 = _end_pos(side2)
		text(ep + Vector2(0, -62), str(end_value(side2)), UiKit.SIZE_H2, Palette.GOLD_LIGHT)
	# Main du joueur.
	for i: int in _hand.size():
		var hp: Vector2 = _hand_pos(i)
		var ok: bool = not fits(_hand[i]).is_empty()
		if i == _sel:
			draw_rect(Rect2(hp - Vector2(HAND_W * 0.5, 90.0), Vector2(HAND_W, 180.0)), Color(Palette.GOLD_LIGHT, 0.25))
			draw_rect(Rect2(hp - Vector2(HAND_W * 0.5, 90.0), Vector2(HAND_W, 180.0)), Palette.GOLD_LIGHT, false, 3.0)
		_tile(hp + Vector2(0, -6.0 if i == _sel else 0.0), _hand[i].x, _hand[i].y, Vector2.DOWN, 1.8, 0.15 if ok and assist else 0.0)
	# Pioche.
	for k2: int in 4:
		var pp2: Vector2 = PILE_AT + Vector2(-4.0 * float(k2), -6.0 * float(k2))
		draw_rect(Rect2(pp2 - Vector2(40, 70), Vector2(80, 140)), Color("2a1a10"))
		draw_rect(Rect2(pp2 - Vector2(40, 70), Vector2(80, 140)), Color("8a6a3a"), false, 2.0)
	text(PILE_AT + Vector2(0, 100), tr("TRIAL_DOMINOES_PILE"), UiKit.SIZE_SMALL, Palette.IVORY, "body", 4)
	# Score et temps.
	text(Vector2(960.0, 105.0), tr("TRIAL_DOMINOES_STATUS") % [_points, pi("target")], UiKit.SIZE_BODY, Palette.IVORY)
	var left: float = clampf(1.0 - t / (p("duration") * slow), 0.0, 1.0)
	draw_rect(Rect2(760.0, 130.0, 400.0 * left, 8.0), Palette.GOLD.lerp(Palette.ROULETTE_RED, 1.0 - left))
	if _lock > 0.0 and _wrong > 0 and _lock > p("place_seconds") * slow:
		text(Vector2(960.0, 800.0), tr("TRIAL_DOMINOES_BLOCKED"), UiKit.SIZE_BODY, Palette.ROULETTE_RED)
