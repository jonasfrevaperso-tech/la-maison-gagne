class_name TrialSort
extends ThrowTrial
## TRI DES JETONS : le tapis roulant de la caisse s'est remis en marche. Chaque jeton qui passe
## dans la fenêtre de tri doit partir dans le bon bac : rouge, vert, or ou noir (à la souris :
## rouge clic gauche, noir clic droit). Le tapis accélère. Note = jetons bien triés, moins une
## pénalité par appui à vide ou mauvais bac.

const CHIP_R: float = 26.0
## Couleur de chaque symbole (0 gauche/X, 1 haut/Y, 2 droite/B, 3 bas/A).
const COLORS: Array[Color] = [Palette.ROULETTE_RED, Palette.EMERALD, Palette.GOLD, Color(0.12, 0.11, 0.14)]
const KEYS_LABEL: Array[String] = ["←", "↑", "→", "↓"]

var _chips: Array[Dictionary] = []
var _spawned: int = 0
var _spawn_t: float = 0.3
var _good: int = 0
var _wrong: int = 0
var _ended: bool = false


func _kinds() -> int:
	return 2 if mouse else 4


## Couleur effective : à la souris, le symbole 1 (clic droit) désigne le noir.
func _color(kind: int) -> Color:
	return COLORS[3] if mouse and kind == 1 else COLORS[kind]


func _window() -> Rect2:
	var r: Rect2 = play_rect()
	return Rect2(Vector2(r.get_center().x - 70.0, r.get_center().y - 60.0), Vector2(140.0, 120.0))


func _speed() -> float:
	var k: float = float(_spawned) / maxf(float(pi("chips")), 1.0)
	return lerpf(p("speed_start"), p("speed_end"), k) / slow


func handle(event: InputEvent) -> bool:
	var k: int = sym_pressed(event)
	if k < 0 or k >= _kinds():
		return false
	sort(k)
	return true


## Envoie le jeton présent dans la fenêtre vers le bac `k`.
func sort(k: int) -> void:
	var w: Rect2 = _window().grow(CHIP_R * 0.5 * widen())
	for c: Dictionary in _chips:
		if bool(c["done"]):
			continue
		var pos: Vector2 = c["p"]
		if w.has_point(pos):
			c["done"] = true
			c["to"] = k
			if int(c["kind"]) == k:
				_good += 1
				AudioBus.play("chip_place", 1.0 + 0.1 * float(k))
				pop(pos + Vector2(0, -60), 1.0, "")
			else:
				_wrong += 1
				AudioBus.play("error", 1.0, -6.0)
				pop(pos + Vector2(0, -60), 0.0, "")
			return
	_wrong += 1
	AudioBus.play("sticky", 1.3, -10.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_spawn_t -= dt
	if _spawn_t <= 0.0 and _spawned < pi("chips"):
		_spawned += 1
		var r: Rect2 = play_rect()
		var kind: int = rng.randi_range(0, _kinds() - 1)
		_chips.append({"p": Vector2(r.position.x - 30.0, r.get_center().y), "kind": kind, "done": false, "to": -1, "t": 0.0})
		_spawn_t = p("gap_px") / _speed()
	var kept: Array[Dictionary] = []
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		if bool(c["done"]):
			c["t"] = float(c["t"]) + dt
			var dirs: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
			pos += dirs[clampi(int(c["to"]), 0, 3)] * 700.0 * dt
			if float(c["t"]) < 0.5:
				c["p"] = pos
				kept.append(c)
			continue
		pos.x += _speed() * dt
		c["p"] = pos
		if pos.x > play_rect().end.x + 30.0:
			AudioBus.play("lose_soft", 1.2, -10.0)
			continue
		kept.append(c)
	_chips = kept
	if _spawned >= pi("chips") and _chips.is_empty():
		_ended = true
		var sc: float = float(_good) / float(pi("chips")) - p("wrong_penalty") * float(_wrong)
		finish(clampf(sc, 0.0, 1.0))


func bot_wants() -> Dictionary:
	var w: Rect2 = _window()
	for c: Dictionary in _chips:
		if not bool(c["done"]) and w.has_point(c["p"] as Vector2):
			return {"do": "sym", "symbol": int(c["kind"])}
	return {"do": ""}


func bot_apply(want: Dictionary) -> void:
	if String(want.get("do", "")) == "sym":
		sort(int(want["symbol"]))


func paint() -> void:
	var r: Rect2 = play_rect()
	var belt: Rect2 = Rect2(r.position.x + 10.0, r.get_center().y - 40.0, r.size.x - 20.0, 80.0)
	draw_rect(belt, Color(0.12, 0.12, 0.14))
	var off: float = fmod(t * _speed(), 40.0)
	var x: float = belt.position.x - 40.0 + off
	while x < belt.end.x:
		if x > belt.position.x:
			draw_line(Vector2(x, belt.position.y), Vector2(x, belt.end.y), Color(0.25, 0.25, 0.28), 3.0)
		x += 40.0
	var w: Rect2 = _window()
	draw_rect(w, Color(Palette.GOLD_LIGHT, 0.12))
	draw_rect(w, Palette.GOLD_LIGHT, false, 3.0)
	# Bacs : une rangée de couleurs avec leur touche, au-dessus du tapis.
	var n: int = _kinds()
	for k: int in n:
		var at: Vector2 = Vector2(r.get_center().x + (float(k) - float(n - 1) * 0.5) * 170.0, r.position.y + 50.0)
		var lbl: String = KEYS_LABEL[k] if not mouse else (tr("TRIAL_SORT_LEFT_CLICK") if k == 0 else tr("TRIAL_SORT_RIGHT_CLICK"))
		draw_circle(at, 28.0, _color(k).darkened(0.1))
		draw_arc(at, 28.0, 0, TAU, 24, Palette.GOLD_DARK, 2.0, true)
		text(at + Vector2(0, 50.0), lbl, UiKit.SIZE_SMALL if mouse else UiKit.SIZE_BODY, Palette.IVORY)
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		var col: Color = _color(int(c["kind"]))
		var a: float = 1.0 - clampf(float(c["t"]) / 0.5, 0.0, 1.0) if bool(c["done"]) else 1.0
		draw_circle(pos, CHIP_R, Color(col.darkened(0.25), a))
		draw_circle(pos, CHIP_R - 6.0, Color(col, a))
		draw_arc(pos, CHIP_R - 10.0, 0, TAU, 20, Color(Palette.IVORY, a), 3.0)
	text(Vector2(r.end.x - 110.0, r.position.y + 30.0), "%d / %d" % [_good, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")
