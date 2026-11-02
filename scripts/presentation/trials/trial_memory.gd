class_name TrialMemory
extends ThrowTrial
## MÉMOIRE DES CARTES (écran dédié) : sur le tapis d'une table de blackjack poussiéreuse, des
## paires de cartes (symboles de la machine à sous) sont montrées face visible un court instant,
## puis retournées. Retrouver toutes les paires avant la fin du sablier : chaque erreur coûte.
## Croix / flèches / stick pour choisir, confirmer pour retourner ; à la souris, cliquer.

const SYMBOLS: Array[String] = ["cherry", "bell", "clover", "chip", "seven", "diamond"]
const SYMBOL_PATH: String = "res://assets/slot/slot_%s.png"
const CARD: Vector2 = Vector2(170.0, 236.0)
const GAP: Vector2 = Vector2(36.0, 40.0)
const TOP: float = 300.0
const CARD3: Vector2 = Vector2(0.6, 0.84)
const STEP3: Vector2 = Vector2(0.78, 1.08)

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
## Textures gardées en vie : une texture chargée dans _draw puis libérée s'affiche en blanc.
var _textures: Array[Texture2D] = []
## Scène 3D : cartes posées à plat sur le tapis, retournées sur leur longueur.
var _cards3: Array[Node3D] = []
var _fronts: Array[StandardMaterial3D] = []


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
	_build_3d()
	AudioBus.play("card_flip", 1.0, -4.0)


## Tapis de blackjack en 3D, lampe de table, cartes (dos bordeaux à filets dorés, face ivoire).
func _build_3d() -> void:
	var st: Stage3D = use_3d()
	st.env.background_color = Color(0.02, 0.05, 0.035)
	st.key.light_energy = 0.35
	st.look(Vector3(0, 4.3, 2.9), Vector3(0, 0, 0.25), 40.0)
	var r: Node3D = st.root
	Stage3D.box(r, Vector3(9, 0.05, 6), Vector3(0, -0.04, 0), Stage3D.mat(Color(0.05, 0.22, 0.13), 0.0, 0.95))
	# Arc de la donne et rebord matelassé.
	for k: int in 40:
		var a: float = lerpf(-0.9, 0.9, float(k) / 39.0)
		Stage3D.box(r, Vector3(0.1, 0.006, 0.03), Vector3(sin(a) * 3.6, -0.012, -3.4 + cos(a) * 2.1), Stage3D.mat(Palette.GOLD_DARK, 0.6, 0.4))
	Stage3D.box(r, Vector3(9, 0.25, 0.5), Vector3(0, 0.05, 2.6), Stage3D.mat(Color(0.18, 0.07, 0.05), 0.0, 0.5))
	var lamp: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.88, 0.6), 4.0, Vector3(0, 2.4, 0.2), 7.0)
	lamp.shadow_enabled = not Settings.b("video", "handheld")
	var edge: StandardMaterial3D = Stage3D.mat(Color(0.9, 0.86, 0.78), 0.0, 0.6)
	var back: StandardMaterial3D = Stage3D.mat(Palette.ROULETTE_RED.darkened(0.35), 0.1, 0.5)
	var filet: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.7, 0.35)
	for i: int in _faces.size():
		var card: Node3D = Node3D.new()
		r.add_child(card)
		Stage3D.box(card, Vector3(CARD3.x, 0.014, CARD3.y), Vector3.ZERO, edge)
		var front: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.55)
		Stage3D.box(card, Vector3(CARD3.x - 0.03, 0.002, CARD3.y - 0.03), Vector3(0, 0.008, 0), front)
		_fronts.append(front)
		var sym: Sprite3D = Sprite3D.new()
		sym.texture = _symbol(_faces[i])
		sym.pixel_size = 0.4 / float(maxi(sym.texture.get_width(), 1)) if sym.texture != null else 0.01
		sym.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sym.rotation.x = -PI * 0.5
		sym.position = Vector3(0, 0.011, 0)
		card.add_child(sym)
		Stage3D.box(card, Vector3(CARD3.x - 0.03, 0.002, CARD3.y - 0.03), Vector3(0, -0.008, 0), back)
		Stage3D.box(card, Vector3(CARD3.x - 0.12, 0.002, 0.02), Vector3(0, -0.0095, CARD3.y * 0.36), filet)
		Stage3D.box(card, Vector3(CARD3.x - 0.12, 0.002, 0.02), Vector3(0, -0.0095, -CARD3.y * 0.36), filet)
		Stage3D.box(card, Vector3(0.02, 0.002, CARD3.y * 0.72), Vector3(-CARD3.x * 0.4, -0.0095, 0), filet)
		Stage3D.box(card, Vector3(0.02, 0.002, CARD3.y * 0.72), Vector3(CARD3.x * 0.4, -0.0095, 0), filet)
		Stage3D.box(card, Vector3(0.12, 0.002, 0.12), Vector3(0, -0.0095, 0), filet)
		_cards3.append(card)


func _rows() -> int:
	return int(ceil(float(_faces.size()) / float(_cols)))


## Centre 3D de la carte i sur le tapis.
func _card3(i: int) -> Vector3:
	var x: float = (float(i % _cols) - float(_cols - 1) * 0.5) * STEP3.x
	var z: float = (float(i / _cols) - float(_rows() - 1) * 0.5) * STEP3.y
	return Vector3(x, 0.0, z)


func _symbol(k: int) -> Texture2D:
	if _textures.is_empty():
		for id: String in SYMBOLS:
			var path: String = SYMBOL_PATH % id
			_textures.append(load(path) as Texture2D if ResourceLoader.exists(path) else null)
	return _textures[k]


func _card_rect(i: int) -> Rect2:
	if stage != null and not _cards3.is_empty():
		# Rectangle d'écran englobant la carte 3D (clic souris, curseur, notes).
		var c: Vector3 = _card3(i)
		var r: Rect2 = Rect2(stage.project(c), Vector2.ZERO)
		for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			r = r.expand(stage.project(c + Vector3(k.x * CARD3.x * 0.5, 0, k.y * CARD3.y * 0.5)))
		return r
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
	for i: int in _cards3.size():
		_sync_card(i)
	text(Vector2(size.x * 0.5, 120), tr("TRIAL_MEMORY_BANNER"), UiKit.SIZE_BODY, Color(Palette.GOLD, 0.8))
	if not _preview and _cursor >= 0 and _cursor < _cards3.size():
		var c: Vector3 = _card3(_cursor)
		var pts: PackedVector2Array = PackedVector2Array()
		for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
			pts.append(stage.project(c + Vector3(k.x * (CARD3.x * 0.5 + 0.05), 0.02, k.y * (CARD3.y * 0.5 + 0.05))))
		draw_polyline(pts, Color(Palette.CYAN, 0.6 + 0.4 * sin(t * 8.0)), 5.0, true)
	# Sablier.
	var tl: float = clampf(_time_left() / (p("time_limit") * slow), 0.0, 1.0) if not _preview else 1.0
	var bar: Rect2 = Rect2(size.x * 0.5 - 300.0, 960.0, 600.0, 14.0)
	draw_rect(bar, Palette.VELVET_DEEP)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * tl, bar.size.y)), Palette.GOLD if tl > 0.3 else Palette.DANGER)
	var info: String = tr("TRIAL_MEMORY_LOOK") if _preview else tr("TRIAL_MEMORY_STATUS") % [_found.count(true) / 2, _pairs, _mistakes]
	text(Vector2(size.x * 0.5, 930.0), info, UiKit.SIZE_BODY, Palette.IVORY)


## Carte 3D : retournement sur la longueur avec un petit saut, dorure quand la paire est trouvée.
func _sync_card(i: int) -> void:
	var up_now: bool = _preview or _found[i] or _open.has(i)
	var u: float = _flip[i]
	u = u * u * (3.0 - 2.0 * u)
	var target: float = 0.0 if up_now else PI
	var card: Node3D = _cards3[i]
	card.position = _card3(i) + Vector3(0, 0.05 + sin(u * PI) * 0.3, 0)
	card.rotation.z = lerpf(PI - target, target, u)
	_fronts[i].albedo_color = Palette.IVORY.lerp(Palette.GOLD_LIGHT, 0.45) if _found[i] else Palette.IVORY
	if _found[i]:
		_fronts[i].emission_enabled = true
		_fronts[i].emission = Palette.GOLD
		_fronts[i].emission_energy_multiplier = 0.15
