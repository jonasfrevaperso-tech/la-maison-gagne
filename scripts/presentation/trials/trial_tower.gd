class_name TrialTower
extends ThrowTrial
## TOUR DE JETONS : empiler des jetons qui glissent de gauche à droite, de plus en plus vite.
## Confirmer pour lâcher : ce qui dépasse de la pile tombe, et le jeton suivant est plus étroit.
## Lâcher pile dessus (à quelques pixels) garde toute la largeur. Note = largeur finale.
## Rendu 3D : des plaques de casino laquées, vues de face en légère plongée (caméra
## orthographique : 1 px du repère de l'épreuve = PX3 m, la logique reste en pixels).

const CHIP_H: float = 24.0
const PX3: float = 0.01
const DEPTH3: float = 0.7
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
var _plates: Array[MeshInstance3D] = []
var _mats: Array[StandardMaterial3D] = []
var _root3: Node3D = null


func begin() -> void:
	_w = p("chip_w")
	var r: Rect2 = play_rect()
	_stack.append(Vector2(r.get_center().x - _w * 0.5, _w))
	_x = r.position.x + 20.0
	_build_3d()


func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.05, 0.03, 0.05)
	st.key.light_energy = 0.55
	st.key.rotation_degrees = Vector3(-40, -30, 0)
	var r: Rect2 = play_rect()
	var a: float = 0.32
	var yc: float = (_base_y() - r.get_center().y) * PX3
	st.cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	st.cam.size = r.size.y * PX3
	st.cam.position = Vector3(0, yc + sin(a) * 20.0, cos(a) * 20.0)
	st.cam.look_at(Vector3(0, yc, 0), Vector3.UP)
	_root3 = st.root
	Stage3D.box(_root3, Vector3(r.size.x * PX3, 0.3, 4.0), Vector3(0, -0.15, 0), Stage3D.mat(Color(0.07, 0.26, 0.15), 0.0, 0.95))
	Stage3D.box(_root3, Vector3(r.size.x * PX3, 0.06, 0.08), Vector3(0, 0.0, 2.0), Stage3D.mat(Palette.GOLD_DARK, 0.7, 0.35))
	Stage3D.box(_root3, Vector3(r.size.x * PX3 * 1.2, 12.0, 0.2), Vector3(0, 5.0, -3.0), Stage3D.mat(Color(0.1, 0.05, 0.08), 0.0, 1.0))
	var lamp: OmniLight3D = Stage3D.omni(_root3, Color(1.0, 0.88, 0.65), 1.2, Vector3(0, 4.0, 2.0), 9.0)
	lamp.shadow_enabled = RenderQuality.shadows()
	# Piles de jetons décoratives sur les côtés du tapis.
	var half: float = r.size.x * PX3 * 0.5
	for side: float in [-1.0, 1.0]:
		for pile: int in 3:
			var at: Vector3 = Vector3(side * (half - 0.5 - 0.55 * float(pile)), 0, -0.6 + 0.35 * float(pile % 2))
			for k: int in 3 + pile * 2:
				var cm: StandardMaterial3D = Stage3D.mat(COLORS[(pile + k) % COLORS.size()].darkened(0.35), 0.1, 0.45)
				Stage3D.cylinder(_root3, 0.22, 0.07, at + Vector3(0, 0.035 + 0.075 * float(k), 0), cm)
	for col: Color in COLORS:
		_mats.append(Stage3D.mat(col.darkened(0.35), 0.1, 0.45))


## Plaque n° k (réutilisée d'une image à l'autre) : boîte laquée et liseré doré en façade.
func _plate(k: int) -> MeshInstance3D:
	while _plates.size() <= k:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		_root3.add_child(mi)
		var trim: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.4)
		var band: MeshInstance3D = Stage3D.box(mi, Vector3(1, 0.035, 0.02), Vector3(0, 0, DEPTH3 * 0.5 + 0.005), trim)
		band.name = "band"
		_plates.append(mi)
	return _plates[k]


## Place une plaque de la logique (rect en pixels) dans la scène 3D.
func _place(k: int, x: float, w: float, top_y: float, col_i: int, tilt: float = 0.0) -> void:
	var mi: MeshInstance3D = _plate(k)
	mi.visible = w > 0.5
	if not mi.visible:
		return
	(mi.mesh as BoxMesh).size = Vector3(w * PX3, (CHIP_H - 2.0) * PX3, DEPTH3)
	mi.material_override = _mats[col_i % _mats.size()]
	var cx: float = (x + w * 0.5 - play_rect().get_center().x) * PX3
	var cy: float = (_base_y() - top_y - (CHIP_H - 2.0) * 0.5) * PX3
	mi.position = Vector3(cx, cy, 0)
	mi.rotation.z = tilt
	var band: MeshInstance3D = mi.get_node("band") as MeshInstance3D
	band.scale = Vector3(maxf(w * PX3 - 0.12, 0.01), 1, 1)


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
	var used: int = 0
	if _root3 != null:
		for k: int in _stack.size():
			var c: Vector2 = _stack[k]
			_place(used, c.x, c.y, _base_y() - CHIP_H * float(k + 1), k)
			used += 1
		if _end_t < 0.0:
			var y: float = _base_y() - CHIP_H * float(_stack.size() + 1)
			_place(used, _x, _w, y, _stack.size())
			used += 1
		for f: Dictionary in _falling:
			var col_i: int = COLORS.find(f["c"] as Color)
			var spin: float = float(f["v"]) * 0.0006 * (1.0 if float(f["x"]) > r.get_center().x else -1.0)
			_place(used, float(f["x"]), float(f["w"]), float(f["y"]), maxi(col_i, 0), spin)
			used += 1
		for k: int in range(used, _plates.size()):
			_plates[k].visible = false
	if _end_t < 0.0:
		var y2: float = _base_y() - CHIP_H * float(_stack.size() + 1)
		var top: Vector2 = _stack[-1]
		for gx: float in [top.x, top.x + top.y]:
			draw_line(Vector2(gx, y2 - 8), Vector2(gx, y2 + CHIP_H * 2.0), Color(Palette.GOLD_LIGHT, 0.35), 2.0)
	var n: int = mini(_stack.size() - 1, pi("chips"))
	text(Vector2(r.end.x - 80.0, r.position.y + 30.0), "%d / %d" % [n, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")
	var width_txt: String = tr("TRIAL_TOWER_WIDTH") % roundi(_stack[-1].y / p("chip_w") * 100.0)
	text(Vector2(r.position.x + 110.0, r.position.y + 30.0), width_txt, UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
