class_name TrialTower
extends ThrowTrial
## TOUR DE JETONS : empiler des jetons qui glissent de gauche à droite, de plus en plus vite.
## Confirmer pour lâcher : ce qui dépasse de la pile tombe, et le jeton suivant est plus étroit.
## Lâcher pile dessus (à quelques pixels) garde toute la largeur. Note = largeur finale.
## Rendu 3D : des plaques de casino laquées, vues de face en légère plongée (caméra
## orthographique : 1 px du repère de l'épreuve = PX3 m, la logique reste en pixels).
## 2.0 : la pile OSCILLE (d'autant plus qu'elle est haute et chargée de jetons légers : on vise
## un sommet qui bouge), des RAFALES de vent poussent le jeton qui glisse (flèche), et trois
## sortes de jetons : normal, LOURD (or : lent, calme la pile), LÉGER (verre : rapide, la fait
## osciller, deux fois plus sensible au vent).

enum Kind { NORMAL, HEAVY, LIGHT }

const CHIP_H: float = 24.0
const PX3: float = 0.01
## Inclinaison visuelle d'un étage selon son décalage d'oscillation (rad/px).
const TILT_K: float = 0.0012
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
## Sorte de chaque jeton posé (parallèle à _stack) et du jeton qui glisse.
var _kinds: Array[int] = [Kind.NORMAL]
var _kind: int = Kind.NORMAL
## Oscillation : décalage du sommet (px) ; vent : poussée signée (px/s) et minuteur de rafale.
var _sway: float = 0.0
var _sway_phase: float = 0.0
var _wind: float = 0.0
var _gust_t: float = 0.0
var _gust_left: float = 0.0
var _heavy_mat: StandardMaterial3D = null
var _light_mat: StandardMaterial3D = null


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
	st.cam.look_at_from_position(Vector3(0, yc + sin(a) * 20.0, cos(a) * 20.0), Vector3(0, yc, 0), Vector3.UP)
	_root3 = st.root
	Stage3D.box(_root3, Vector3(r.size.x * PX3, 0.3, 4.0), Vector3(0, -0.15, 0), Stage3D.textured("felt", Color(0.12, 0.4, 0.24), 0.5))
	Stage3D.box(_root3, Vector3(r.size.x * PX3, 0.06, 0.08), Vector3(0, 0.0, 2.0), Stage3D.mat(Palette.GOLD_DARK, 0.7, 0.35))
	Stage3D.box(_root3, Vector3(r.size.x * PX3 * 1.2, 12.0, 0.2), Vector3(0, 5.0, -3.0), Stage3D.mat(Color(0.1, 0.05, 0.08), 0.0, 1.0))
	_build_cashier(r)
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
	_heavy_mat = Stage3D.mat(Palette.GOLD, 0.9, 0.25)
	_light_mat = Stage3D.mat(Palette.CYAN.lightened(0.3), 0.2, 0.05)
	_light_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_light_mat.albedo_color.a = 0.55
	_light_mat.rim_enabled = true


## Fond de la caisse : boiseries, guichet à barreaux de laiton, présentoirs de jetons, appliques.
func _build_cashier(r: Rect2) -> void:
	var w: float = r.size.x * PX3 * 1.2
	var wood: StandardMaterial3D = Stage3D.textured("wood", Color(0.42, 0.22, 0.13), 1.5, 0.0, 0.5)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.85, 0.3)
	for k: int in 9:
		var x: float = -w * 0.5 + w * (float(k) + 0.5) / 9.0
		Stage3D.box(_root3, Vector3(w / 9.0 - 0.08, 7.0, 0.06), Vector3(x, 3.6, -2.88), wood)
	Stage3D.box(_root3, Vector3(w, 0.08, 0.3), Vector3(0, 1.3, -2.8), brass)
	for k2: int in 15:
		Stage3D.cylinder(_root3, 0.02, 2.4, Vector3(-2.8 + float(k2) * 0.4, 2.5, -2.7), brass)
		# Présentoirs : rangées de jetons debout derrière le guichet.
	for row: int in 2:
		Stage3D.box(_root3, Vector3(w * 0.8, 0.06, 0.4), Vector3(0, 0.25 + float(row) * 0.5, -2.85), wood)
		for c: int in 18:
			var col: Color = COLORS[(c + row) % COLORS.size()].darkened(0.68)
			var chip: MeshInstance3D = Stage3D.cylinder(_root3, 0.16, 0.05, Vector3(-3.2 + float(c) * 0.38, 0.44 + float(row) * 0.5, -2.85),
				Stage3D.mat(col, 0.1, 0.45))
			chip.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		Stage3D.sphere(_root3, 0.1, Vector3(side * 3.6, 1.0, -2.75), Stage3D.glow(Palette.GOLD_LIGHT, 2.0))
		Stage3D.omni(_root3, Color(1.0, 0.75, 0.45), 0.8, Vector3(side * 3.6, 1.0, -2.4), 3.0)


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
func _place(k: int, x: float, w: float, top_y: float, col_i: int, tilt: float = 0.0, kind: int = Kind.NORMAL) -> void:
	var mi: MeshInstance3D = _plate(k)
	mi.visible = w > 0.5
	if not mi.visible:
		return
	(mi.mesh as BoxMesh).size = Vector3(w * PX3, (CHIP_H - 2.0) * PX3, DEPTH3)
	match kind:
		Kind.HEAVY:
			mi.material_override = _heavy_mat
		Kind.LIGHT:
			mi.material_override = _light_mat
		_:
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
	var mass: float = p("heavy_speed") if _kind == Kind.HEAVY else (p("light_speed") if _kind == Kind.LIGHT else 1.0)
	return lerpf(float(sp[0]), float(sp[1]), k) * mass / slow


## Décalage d'oscillation de l'étage n° k (0 = socle, immobile ; le sommet bouge le plus).
func _off(k: int) -> float:
	return _sway * float(k) / maxf(float(pi("chips")), 1.0)


## Amplitude de l'oscillation : croît avec la hauteur, les légers l'aggravent, les lourds la calment.
func _sway_amp() -> float:
	var lights: int = _kinds.count(Kind.LIGHT)
	var heavies: int = _kinds.count(Kind.HEAVY)
	var h: float = float(_stack.size() - 1) / maxf(float(pi("chips")), 1.0)
	var m: float = 1.0 + p("light_sway") * float(lights) - p("heavy_calm") * float(heavies)
	return p("sway_px") * float(pi("chips")) * h * maxf(m, 0.2)


## Poussée du vent sur le jeton qui glisse (les légers la sentent double, les lourds moitié).
func _push() -> float:
	var m: float = p("light_wind") if _kind == Kind.LIGHT else (p("heavy_wind") if _kind == Kind.HEAVY else 1.0)
	return _wind * m / slow


## Erreur de pose : où tomberait le jeton par rapport au sommet (repère de la pile).
func _error() -> float:
	return _x - _off(_stack.size()) - _stack[-1].x


func _next_kind() -> void:
	_kind = Kind.NORMAL
	if _stack.size() > pi("plain_first"):
		var roll: float = rng.randf()
		if roll < p("heavy_share"):
			_kind = Kind.HEAVY
		elif roll < p("heavy_share") + p("light_share"):
			_kind = Kind.LIGHT


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
	var off: float = _off(_stack.size())
	var lx: float = _x - off  # position dans le repère de la pile (qui oscille)
	var left: float = maxf(lx, top.x)
	var right: float = minf(lx + _w, top.x + top.y)
	var y: float = _base_y() - CHIP_H * float(_stack.size() + 1)
	if absf(lx - top.x) <= p("perfect_px") * widen():
		left = top.x
		right = top.x + top.y
		_perfects += 1
		pop(Vector2(left + (right - left) * 0.5, y - 20.0), 1.0, "TRIAL_TOWER_PERFECT")
		AudioBus.play("chime", 1.0 + 0.1 * _perfects, -4.0)
	elif right <= left:
		_falling.append({"x": _x, "w": _w, "y": y, "v": 0.0, "c": COLORS[_stack.size() % COLORS.size()], "k": _kind})
		AudioBus.play("decor_topple", 1.0, -2.0)
		_stack.append(Vector2(top.x, 0.0))
		_kinds.append(_kind)
		_end()
		return
	else:
		var cut_x: float = (_x if lx < left else right + off)
		var cut_w: float = _w - (right - left)
		_falling.append({"x": cut_x, "w": cut_w, "y": y, "v": 0.0, "c": COLORS[_stack.size() % COLORS.size()], "k": _kind})
	_chip_t = 0.0
	AudioBus.play("chip_place", 0.9 + 0.08 * float(_stack.size()))
	_stack.append(Vector2(left, right - left))
	_kinds.append(_kind)
	if _kind == Kind.HEAVY:
		EventBus.juice_shake.emit(0.12)
	_next_kind()
	_w = right - left
	_x = play_rect().position.x + 20.0 if _stack.size() % 2 == 0 else play_rect().end.x - 20.0 - _w
	_dir = 1.0 if _stack.size() % 2 == 0 else -1.0
	if _stack.size() > pi("chips"):
		_end()


func _end() -> void:
	_end_t = 0.0


## Oscillation et rafales (aussi pendant la chute finale, pour le spectacle).
func _weather(dt: float) -> void:
	_sway_phase += dt * TAU / (p("sway_seconds") * slow)
	_sway = lerpf(_sway, _sway_amp() * sin(_sway_phase), minf(dt * 4.0, 1.0))
	if _stack.size() <= pi("wind_from"):
		_wind = 0.0
		return
	if _gust_left > 0.0:
		_gust_left -= dt
		if _gust_left <= 0.0:
			_wind = 0.0
			_gust_t = p("gust_every") * rng.randf_range(0.7, 1.3) * slow
		return
	_gust_t -= dt
	if _gust_t <= 0.0:
		_gust_left = p("gust_seconds") * slow
		_wind = (1.0 if rng.randf() < 0.5 else -1.0) * p("wind_push")
		AudioBus.play("whoosh", 0.7, -8.0)


func tick(dt: float) -> void:
	_weather(dt)
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
	_x += (_dir * _speed() + _push()) * dt
	if _x + _w > r.end.x - 20.0:
		_x = r.end.x - 20.0 - _w
		_dir = -1.0
	elif _x < r.position.x + 20.0:
		_x = r.position.x + 20.0
		_dir = 1.0


func bot_wants() -> Dictionary:
	if _end_t >= 0.0:
		return {"do": ""}
	var step: float = (absf(_dir * _speed() + _push()) + absf(_sway_amp()) * TAU / p("sway_seconds")) / 60.0
	return {"do": "confirm"} if absf(_error()) <= step * 0.6 + 0.5 else {"do": ""}


func bot_apply(w: Dictionary) -> void:
	if String(w.get("do", "")) == "confirm":
		drop()


func paint() -> void:
	var r: Rect2 = play_rect()
	var used: int = 0
	if _root3 != null:
		for k: int in _stack.size():
			var c: Vector2 = _stack[k]
			_place(used, c.x + _off(k), c.y, _base_y() - CHIP_H * float(k + 1), k, _off(k) * TILT_K, _kinds[mini(k, _kinds.size() - 1)])
			used += 1
		if _end_t < 0.0:
			var y: float = _base_y() - CHIP_H * float(_stack.size() + 1)
			_place(used, _x, _w, y, _stack.size(), 0.0, _kind)
			used += 1
		for f: Dictionary in _falling:
			var col_i: int = COLORS.find(f["c"] as Color)
			var spin: float = float(f["v"]) * 0.0006 * (1.0 if float(f["x"]) > r.get_center().x else -1.0)
			_place(used, float(f["x"]), float(f["w"]), float(f["y"]), maxi(col_i, 0), spin, int(f.get("k", Kind.NORMAL)))
			used += 1
		for k: int in range(used, _plates.size()):
			_plates[k].visible = false
	if _end_t < 0.0:
		var y2: float = _base_y() - CHIP_H * float(_stack.size() + 1)
		var top: Vector2 = _stack[-1]
		var off2: float = _off(_stack.size())
		for gx: float in [top.x + off2, top.x + top.y + off2]:
			draw_line(Vector2(gx, y2 - 8), Vector2(gx, y2 + CHIP_H * 2.0), Color(Palette.GOLD_LIGHT, 0.35), 2.0)
	if _wind != 0.0 and _end_t < 0.0:
		# Flèche de rafale au-dessus de la pile.
		var wy: float = r.position.y + 90.0
		var d: float = signf(_wind)
		var c0: Vector2 = Vector2(r.get_center().x, wy)
		draw_line(c0 - Vector2(d * 70.0, 0), c0 + Vector2(d * 70.0, 0), Palette.CYAN, 6.0)
		var tip: Vector2 = c0 + Vector2(d * 90.0, 0)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-d * 24, -16), tip + Vector2(-d * 24, 16)]), Palette.CYAN)
		text(c0 + Vector2(0, -32.0), tr("TRIAL_TOWER_GUST"), UiKit.SIZE_SMALL, Palette.CYAN)
	if _end_t < 0.0 and _kind != Kind.NORMAL:
		var lbl: String = tr("TRIAL_TOWER_HEAVY") if _kind == Kind.HEAVY else tr("TRIAL_TOWER_LIGHT")
		text(Vector2(_x + _w * 0.5, _base_y() - CHIP_H * float(_stack.size() + 1) - 34.0), lbl, UiKit.SIZE_SMALL,
			Palette.GOLD_LIGHT if _kind == Kind.HEAVY else Palette.CYAN)
	var n: int = mini(_stack.size() - 1, pi("chips"))
	text(Vector2(r.end.x - 80.0, r.position.y + 30.0), "%d / %d" % [n, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")
	var width_txt: String = tr("TRIAL_TOWER_WIDTH") % roundi(_stack[-1].y / p("chip_w") * 100.0)
	text(Vector2(r.position.x + 110.0, r.position.y + 30.0), width_txt, UiKit.SIZE_SMALL, Palette.GOLD_LIGHT)
