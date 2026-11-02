class_name TrialSort
extends ThrowTrial
## TRI DES JETONS : le tapis roulant de la caisse s'est remis en marche. Chaque jeton qui passe
## dans la fenêtre de tri doit partir dans le bon bac. Les couleurs sont celles des boutons de
## la manette Xbox, disposés en losange autour de la fenêtre : X bleu à gauche, Y jaune en haut,
## B rouge à droite, A vert en bas (au clavier, les flèches dans les mêmes directions ; à la
## souris : bleu clic gauche, rouge clic droit). Le tapis accélère. Note = jetons bien triés, moins une
## pénalité par appui à vide ou mauvais bac.

const CHIP_R: float = 26.0
## Couleur de chaque symbole (0 gauche/X, 1 haut/Y, 2 droite/B, 3 bas/A).
const COLORS: Array[Color] = [Color("2f7bff"), Color("ffc81e"), Color("e8343e"), Color("38c14a")]
const KEYS_LABEL: Array[String] = ["←", "↑", "→", "↓"]
const PAD_LABEL: Array[String] = ["X", "Y", "B", "A"]
const DIRS: Array[Vector2] = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN]
## Distance entre la fenêtre de tri et chaque bac du losange.
const BIN_GAP: Vector2 = Vector2(175.0, 122.0)

var _chips: Array[Dictionary] = []
var _spawned: int = 0
var _spawn_t: float = 0.3
var _good: int = 0
var _wrong: int = 0
var _ended: bool = false


func _kinds() -> int:
	return 2 if mouse else 4


## Couleur effective : à la souris, le symbole 1 (clic droit) désigne le rouge (B, à droite).
func _color(kind: int) -> Color:
	return COLORS[_dir_of(kind)]


## Direction (et bac) d'un symbole : à la souris, clic gauche → gauche, clic droit → droite.
func _dir_of(kind: int) -> int:
	return 2 if mouse and kind == 1 else kind


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
		_chips.append({"p": Vector2(r.position.x + 24.0, r.get_center().y), "kind": kind, "done": false, "to": -1, "t": 0.0})
		_spawn_t = p("gap_px") / _speed()
	var kept: Array[Dictionary] = []
	for c: Dictionary in _chips:
		var pos: Vector2 = c["p"]
		if bool(c["done"]):
			c["t"] = float(c["t"]) + dt
			var goal: Vector2 = _window().get_center() + DIRS[_dir_of(clampi(int(c["to"]), 0, 3))] * BIN_GAP
			pos = pos.lerp(goal, minf(dt * 12.0, 1.0))
			if float(c["t"]) < 0.45:
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
	var c0: Vector2 = _window().get_center()
	# Fond : tôle de la salle des coffres, rivets.
	draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), Color(0.07, 0.07, 0.09))
	for k: int in 14:
		var x: float = r.position.x + 30.0 + float(k) * (r.size.x - 60.0) / 13.0
		draw_circle(Vector2(x, r.position.y + 16.0), 3.0, Color(0.25, 0.25, 0.3))
		draw_circle(Vector2(x, r.end.y - 14.0), 3.0, Color(0.25, 0.25, 0.3))
	# Tapis roulant : rebords d'acier, lattes qui défilent, rouleaux aux bouts.
	var belt: Rect2 = Rect2(r.position.x + 20.0, c0.y - 38.0, r.size.x - 40.0, 76.0)
	draw_rect(belt.grow(6.0), Color(0.3, 0.31, 0.36))
	draw_rect(belt, Color(0.1, 0.1, 0.12))
	var off: float = fmod(t * _speed(), 36.0)
	var x2: float = belt.position.x - 36.0 + off
	while x2 < belt.end.x:
		if x2 > belt.position.x:
			draw_line(Vector2(x2, belt.position.y + 3), Vector2(x2, belt.end.y - 3), Color(0.2, 0.2, 0.24), 4.0)
		x2 += 36.0
	draw_line(belt.position, Vector2(belt.end.x, belt.position.y), Color(0.55, 0.56, 0.62), 2.0)
	for side: float in [belt.position.x, belt.end.x]:
		draw_circle(Vector2(side, c0.y), 40.0, Color(0.22, 0.22, 0.26))
		draw_circle(Vector2(side, c0.y), 12.0, Color(0.45, 0.46, 0.5))
	# Bacs en losange, comme les boutons de la manette : la couleur EST la touche.
	var n: int = _kinds()
	for k: int in n:
		var d: int = _dir_of(k)
		var at: Vector2 = c0 + DIRS[d] * BIN_GAP
		var col: Color = COLORS[d]
		var hot: float = 0.0
		for ch: Dictionary in _chips:
			if bool(ch["done"]) and int(ch["to"]) == k:
				hot = maxf(hot, 1.0 - float(ch["t"]) / 0.45)
		draw_circle(at, 44.0 + 6.0 * hot, Color(col, 0.18 + 0.3 * hot))
		draw_circle(at, 34.0, col.darkened(0.45))
		draw_circle(at, 30.0, col.lerp(Color.WHITE, 0.25 * hot))
		draw_circle(at + Vector2(-9, -10), 8.0, Color(1, 1, 1, 0.25))
		var lbl: String
		if mouse:
			lbl = tr("TRIAL_SORT_LEFT_CLICK") if k == 0 else tr("TRIAL_SORT_RIGHT_CLICK")
			text(at + Vector2(0, 52.0), lbl, UiKit.SIZE_SMALL, Palette.IVORY)
		else:
			lbl = PAD_LABEL[k] if InputGlyphs.using_pad else KEYS_LABEL[k]
			text(at, lbl, UiKit.SIZE_H2, Palette.INK, "display", 0)
	# Fenêtre de tri : équerres dorées.
	var w: Rect2 = _window()
	draw_rect(w, Color(Palette.GOLD_LIGHT, 0.08))
	for corner: Vector2 in [w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)]:
		var sx: float = 1.0 if corner.x < w.get_center().x else -1.0
		var sy: float = 1.0 if corner.y < w.get_center().y else -1.0
		draw_line(corner, corner + Vector2(22.0 * sx, 0), Palette.GOLD_LIGHT, 4.0)
		draw_line(corner, corner + Vector2(0, 22.0 * sy), Palette.GOLD_LIGHT, 4.0)
	for ch: Dictionary in _chips:
		var pos: Vector2 = ch["p"]
		var col2: Color = _color(int(ch["kind"]))
		var a: float = 1.0 - clampf(float(ch["t"]) / 0.45, 0.0, 1.0) if bool(ch["done"]) else 1.0
		var rad: float = CHIP_R * (1.0 - 0.4 * (1.0 - a))
		draw_circle(pos + Vector2(3, 5), rad, Color(0, 0, 0, 0.4 * a))
		draw_circle(pos, rad, Color(col2.darkened(0.3), a))
		draw_circle(pos, rad - 5.0, Color(col2, a))
		for e: int in 6:
			var ang: float = float(e) * TAU / 6.0 + t * 0.5
			draw_circle(pos + Vector2.from_angle(ang) * (rad - 2.5), 3.0, Color(Palette.IVORY, a))
		draw_arc(pos, rad * 0.5, 0, TAU, 20, Color(Palette.IVORY, a * 0.8), 2.0)
	text(Vector2(r.end.x - 110.0, r.position.y + 40.0), "%d / %d" % [_good, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")
