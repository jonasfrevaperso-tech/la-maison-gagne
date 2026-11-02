class_name TrialMemory
extends ThrowTrial
## MÉMOIRE DES CARTES (écran dédié) : sur le tapis d'une table de blackjack poussiéreuse, des
## paires de cartes (symboles de la machine à sous) sont montrées face visible un court instant,
## puis retournées. Retrouver toutes les paires avant la fin du sablier : chaque erreur coûte.
## Croix / flèches / stick pour choisir, confirmer pour retourner ; à la souris, cliquer.

const SYMBOLS: Array[String] = ["cherry", "bell", "clover", "chip", "seven"]
const SYMBOL_PATH: String = "res://assets/slot/slot_%s.png"
const CARD: Vector2 = Vector2(170.0, 236.0)
const GAP: Vector2 = Vector2(36.0, 40.0)
const TOP: float = 300.0

var _faces: Array[int] = []
var _found: Array[bool] = []
var _open: Array[int] = []
var _cursor: int = 0
var _cols: int = 5
var _mistakes: int = 0
var _pairs: int = 4
var _preview: bool = true
var _close_t: float = 0.0
var _flip: PackedFloat32Array = PackedFloat32Array()
var _done_t: float = -1.0


func begin() -> void:
	_pairs = mini(pi("pairs"), SYMBOLS.size())
	_cols = _pairs
	for k: int in _pairs:
		_faces.append(k)
		_faces.append(k)
	for i: int in range(_faces.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = _faces[i]
		_faces[i] = _faces[j]
		_faces[j] = tmp
	for i: int in _faces.size():
		_found.append(false)
		_flip.append(1.0)
	AudioBus.play("card_flip", 1.0, -4.0)


func _card_rect(i: int) -> Rect2:
	var rows: int = int(ceil(float(_faces.size()) / float(_cols)))
	var w: float = _cols * CARD.x + (_cols - 1) * GAP.x
	var x0: float = size.x * 0.5 - w * 0.5
	var y0: float = TOP + (2 - rows) * (CARD.y + GAP.y) * 0.5
	return Rect2(Vector2(x0 + (i % _cols) * (CARD.x + GAP.x), y0 + (i / _cols) * (CARD.y + GAP.y)), CARD)


func _time_left() -> float:
	return p("time_limit") * slow - (t - p("preview_seconds"))


func handle(event: InputEvent) -> bool:
	if _preview or _done_t >= 0.0:
		return confirm_pressed(event) or dir_pressed(event) != Vector2i.ZERO
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		var hit: int = _at(mm.position)
		if hit >= 0:
			_cursor = hit
		return true
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit2: int = _at(mb.position)
			if hit2 >= 0:
				_cursor = hit2
				flip(hit2)
		return true
	var d: Vector2i = dir_pressed(event)
	if d != Vector2i.ZERO:
		move(d)
		return true
	if confirm_pressed(event):
		flip(_cursor)
		return true
	return false


func _at(pt: Vector2) -> int:
	for i: int in _faces.size():
		if _card_rect(i).has_point(pt):
			return i
	return -1


func move(d: Vector2i) -> void:
	var rows: int = int(ceil(float(_faces.size()) / float(_cols)))
	var cx: int = posmod(_cursor % _cols + d.x, _cols)
	var cy: int = posmod(_cursor / _cols + d.y, rows)
	_cursor = mini(cy * _cols + cx, _faces.size() - 1)
	AudioBus.play("hover", 1.0, -8.0)


func flip(i: int) -> void:
	if _preview or _found[i] or _open.has(i) or _open.size() >= 2 or _done_t >= 0.0:
		return
	_open.append(i)
	_flip[i] = 0.0
	AudioBus.play("card_flip", 1.0 + 0.1 * _open.size())
	if _open.size() == 2:
		if _faces[_open[0]] == _faces[_open[1]]:
			_found[_open[0]] = true
			_found[_open[1]] = true
			pop(_card_rect(i).get_center() + Vector2(0, -CARD.y * 0.6), 1.0, "TRIAL_MEMORY_PAIR")
			AudioBus.play("chime", 1.0 + 0.1 * _found.count(true), -4.0)
			_open.clear()
			if not _found.has(false):
				_end()
		else:
			_mistakes += 1
			pop(_card_rect(i).get_center() + Vector2(0, -CARD.y * 0.6), 0.0, "TRIAL_MEMORY_WRONG")
			AudioBus.play("error", 1.0, -6.0)
			_close_t = p("reveal_seconds")


func _end() -> void:
	if _done_t >= 0.0:
		return
	_done_t = 0.0
	var found: float = float(_found.count(true)) / float(_faces.size())
	score = clampf(found - float(_mistakes) * p("mistake_penalty"), 0.0, 1.0)


func tick(dt: float) -> void:
	for i: int in _flip.size():
		_flip[i] = minf(_flip[i] + dt * 5.0, 1.0)
	if _preview:
		if t >= p("preview_seconds"):
			_preview = false
			for i: int in _flip.size():
				_flip[i] = 0.0
			AudioBus.play("card_flip", 0.8)
		return
	if _done_t >= 0.0:
		_done_t += dt
		if _done_t > 0.6:
			finish(score)
		return
	if _close_t > 0.0:
		_close_t -= dt
		if _close_t <= 0.0:
			for i: int in _open:
				_flip[i] = 0.0
			_open.clear()
			AudioBus.play("card_flip", 0.9, -6.0)
	if _time_left() <= 0.0:
		AudioBus.play("clock", 1.0)
		_end()


## Bot : connaît le jeu, va vers la prochaine carte utile (une à la fois).
func bot_wants() -> Dictionary:
	if _preview or _done_t >= 0.0 or _close_t > 0.0:
		return {"do": ""}
	var goal: int = _goal()
	if goal < 0:
		return {"do": ""}
	if goal == _cursor:
		return {"do": "confirm"}
	var gx: int = goal % _cols - _cursor % _cols
	var gy: int = goal / _cols - _cursor / _cols
	if gx != 0:
		return {"do": "dir", "dir": Vector2i(signi(gx), 0)}
	return {"do": "dir", "dir": Vector2i(0, signi(gy))}


func _goal() -> int:
	if _open.size() == 1:
		for i: int in _faces.size():
			if i != _open[0] and _faces[i] == _faces[_open[0]]:
				return i
	for i: int in _faces.size():
		if not _found[i] and not _open.has(i):
			return i
	return -1


func bot_apply(w: Dictionary) -> void:
	match String(w.get("do", "")):
		"confirm":
			flip(_cursor)
		"dir":
			move(w["dir"] as Vector2i)


# --------------------------------------------------------------------------- dessin


func paint() -> void:
	# Tapis de blackjack délavé, arc de la donne, lampe au-dessus.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.12, 0.08))
	draw_circle(Vector2(size.x * 0.5, -400), 1100.0, Color(0.05, 0.2, 0.12))
	draw_arc(Vector2(size.x * 0.5, -300), 1080.0, 0.25 * PI, 0.75 * PI, 96, Color(Palette.GOLD_DARK, 0.6), 4.0, true)
	draw_circle(Vector2(size.x * 0.5, 120), 360.0, Color(1.0, 0.85, 0.5, 0.05))
	text(Vector2(size.x * 0.5, 150), tr("TRIAL_MEMORY_BANNER"), UiKit.SIZE_BODY, Color(Palette.GOLD, 0.7))
	for i: int in _faces.size():
		_draw_card(i)
	# Sablier.
	var tl: float = clampf(_time_left() / (p("time_limit") * slow), 0.0, 1.0) if not _preview else 1.0
	var bar: Rect2 = Rect2(size.x * 0.5 - 300.0, 920.0, 600.0, 14.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * tl, bar.size.y)), Palette.GOLD if tl > 0.3 else Palette.DANGER)
	var info: String = tr("TRIAL_MEMORY_LOOK") if _preview else tr("TRIAL_MEMORY_STATUS") % [_found.count(true) / 2, _pairs, _mistakes]
	text(Vector2(size.x * 0.5, 890.0), info, UiKit.SIZE_BODY, Palette.IVORY)


func _draw_card(i: int) -> void:
	var r: Rect2 = _card_rect(i)
	var up_now: bool = _preview or _found[i] or _open.has(i)
	# Retournement : la carte s'aplatit, puis montre son nouveau côté.
	var squash: float = maxf(absf(1.0 - 2.0 * _flip[i]), 0.05)
	var face_up: bool = up_now if _flip[i] >= 0.5 else not up_now
	var rr: Rect2 = Rect2(Vector2(r.get_center().x - r.size.x * 0.5 * squash, r.position.y), Vector2(r.size.x * squash, r.size.y))
	if i == _cursor and not _preview:
		draw_rect(rr.grow(8.0), Palette.CYAN, false, 4.0)
	draw_rect(rr.grow(2.0), Color(0, 0, 0, 0.4))
	if face_up:
		draw_rect(rr, Palette.IVORY if not _found[i] else Palette.IVORY.lerp(Palette.GOLD_LIGHT, 0.35))
		draw_rect(rr.grow(-6.0), Palette.GOLD_DARK, false, 2.0)
		var path: String = SYMBOL_PATH % SYMBOLS[_faces[i]]
		var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if tex != null and squash > 0.2:
			var s: float = minf(rr.size.x - 24.0, 120.0)
			draw_texture_rect(tex, Rect2(rr.get_center() - Vector2(s, s) * 0.5, Vector2(s, s)), false)
	else:
		draw_rect(rr, Palette.ROULETTE_RED.darkened(0.3))
		draw_rect(rr.grow(-8.0), Palette.GOLD_DARK, false, 2.0)
		for k: int in 5:
			draw_line(rr.position + Vector2(10, 30 + k * 44), rr.end - Vector2(10, rr.size.y - 60 - k * 44), Color(Palette.GOLD_DARK, 0.4), 2.0)
