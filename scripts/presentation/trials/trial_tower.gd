class_name TrialTower
extends ThrowTrial
## TOUR DE JETONS : empiler des jetons qui glissent de gauche à droite, de plus en plus vite.
## Confirmer pour lâcher : ce qui dépasse de la pile tombe, et le jeton suivant est plus étroit.
## Lâcher pile dessus (à quelques pixels) garde toute la largeur. Note = largeur finale.

const CHIP_H: float = 24.0
const COLORS: Array[Color] = [Palette.ROULETTE_RED, Palette.CYAN, Palette.EMERALD, Palette.GOLD, Palette.MAGENTA, Palette.IVORY]

## Jetons posés : x (gauche) et largeur.
var _stack: Array[Vector2] = []
var _x: float = 0.0
var _w: float = 0.0
var _dir: float = 1.0
var _falling: Array[Dictionary] = []
var _perfects: int = 0
var _end_t: float = -1.0
var _chip_t: float = 0.0


func begin() -> void:
	_w = p("chip_w")
	var r: Rect2 = play_rect()
	_stack.append(Vector2(r.get_center().x - _w * 0.5, _w))
	_x = r.position.x + 20.0


func _speed() -> float:
	var k: float = float(_stack.size() - 1) / maxf(float(pi("chips") - 1), 1.0)
	var sp: Array = Balance.arr("throw_trials.tower.slide_speed")
	return lerpf(float(sp[0]), float(sp[1]), k) / slow


func _base_y() -> float:
	return play_rect().end.y - 18.0


func handle(event: InputEvent) -> bool:
	if confirm_pressed(event):
		drop()
		return true
	return false


func drop() -> void:
	if _end_t >= 0.0:
		return
	var top: Vector2 = _stack[-1]
	var left: float = maxf(_x, top.x)
	var right: float = minf(_x + _w, top.x + top.y)
	var y: float = _base_y() - CHIP_H * float(_stack.size() + 1)
	if absf(_x - top.x) <= p("perfect_px") * widen():
		left = top.x
		right = top.x + top.y
		_perfects += 1
		pop(Vector2(left + (right - left) * 0.5, y - 20.0), 1.0, "TRIAL_TOWER_PERFECT")
		AudioBus.play("chime", 1.0 + 0.1 * _perfects, -4.0)
	elif right <= left:
		_falling.append({"x": _x, "w": _w, "y": y, "v": 0.0, "c": COLORS[_stack.size() % COLORS.size()]})
		AudioBus.play("decor_topple", 1.0, -2.0)
		_stack.append(Vector2(top.x, 0.0))
		_end()
		return
	else:
		var cut_x: float = _x if _x < left else right
		var cut_w: float = _w - (right - left)
		_falling.append({"x": cut_x, "w": cut_w, "y": y, "v": 0.0, "c": COLORS[_stack.size() % COLORS.size()]})
	_chip_t = 0.0
	AudioBus.play("chip_place", 0.9 + 0.08 * float(_stack.size()))
	_stack.append(Vector2(left, right - left))
	_w = right - left
	_x = play_rect().position.x + 20.0 if _stack.size() % 2 == 0 else play_rect().end.x - 20.0 - _w
	_dir = 1.0 if _stack.size() % 2 == 0 else -1.0
	if _stack.size() > pi("chips"):
		_end()


func _end() -> void:
	_end_t = 0.0


func tick(dt: float) -> void:
	for f: Dictionary in _falling:
		f["v"] = float(f["v"]) + 1400.0 * dt
		f["y"] = float(f["y"]) + float(f["v"]) * dt
	_falling = _falling.filter(func(q: Dictionary) -> bool: return float(q["y"]) < size.y + 60.0)
	if _end_t >= 0.0:
		_end_t += dt
		if _end_t > 0.8:
			finish(_stack[-1].y / p("chip_w"))
		return
	_chip_t += dt
	if _chip_t > p("drop_seconds") * slow:
		drop()  # la main tremble : le jeton finit par tomber
		return
	var r: Rect2 = play_rect()
	_x += _dir * _speed() * dt
	if _x + _w > r.end.x - 20.0:
		_x = r.end.x - 20.0 - _w
		_dir = -1.0
	elif _x < r.position.x + 20.0:
		_x = r.position.x + 20.0
		_dir = 1.0


func bot_wants() -> Dictionary:
	if _end_t >= 0.0:
		return {"do": ""}
	return {"do": "confirm"} if absf(_x - _stack[-1].x) <= _speed() / 60.0 + 0.5 else {"do": ""}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "confirm":
		drop()


func paint() -> void:
	var r: Rect2 = play_rect()
	draw_rect(Rect2(r.position.x + 10, _base_y(), r.size.x - 20, 10), Color(0.07, 0.24, 0.13))
	for k: int in _stack.size():
		var c: Vector2 = _stack[k]
		if c.y > 0.0:
			_chip(Rect2(c.x, _base_y() - CHIP_H * float(k + 1), c.y, CHIP_H - 2.0), COLORS[k % COLORS.size()])
	if _end_t < 0.0:
		var y: float = _base_y() - CHIP_H * float(_stack.size() + 1)
		_chip(Rect2(_x, y, _w, CHIP_H - 2.0), COLORS[_stack.size() % COLORS.size()])
		var top: Vector2 = _stack[-1]
		draw_line(Vector2(top.x, y - 8), Vector2(top.x, _base_y()), Color(Palette.GOLD_LIGHT, 0.25), 1.0)
		draw_line(Vector2(top.x + top.y, y - 8), Vector2(top.x + top.y, _base_y()), Color(Palette.GOLD_LIGHT, 0.25), 1.0)
	for f: Dictionary in _falling:
		_chip(Rect2(float(f["x"]), float(f["y"]), float(f["w"]), CHIP_H - 2.0), f["c"] as Color)
	var n: int = mini(_stack.size() - 1, pi("chips"))
	text(Vector2(r.end.x - 80.0, r.position.y + 30.0), "%d / %d" % [n, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")
	var width_txt: String = tr("TRIAL_TOWER_WIDTH") % roundi(_stack[-1].y / p("chip_w") * 100.0)
	text(Vector2(r.position.x + 110.0, r.position.y + 30.0), width_txt, UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)


## Jeton vu de profil : tranche colorée, liseré ivoire, encoches.
func _chip(r: Rect2, col: Color) -> void:
	if r.size.x <= 0.5:
		return
	draw_rect(r, col.darkened(0.2))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 5.0)), col.lightened(0.15))
	var k: float = r.position.x + 12.0
	while k < r.end.x - 8.0:
		draw_rect(Rect2(k, r.position.y + 6.0, 8.0, r.size.y - 8.0), Color(Palette.IVORY, 0.8))
		k += 34.0
