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
## Décor 3D (caméra frontale du panneau) : mètres par pixel, pas des lattes du tapis.
const PX3: float = 0.005
const SLAT_PX: float = 36.0
const BIN_R: float = 34.0

var _chips: Array[Dictionary] = []
var _spawned: int = 0
var _spawn_t: float = 0.3
var _good: int = 0
var _wrong: int = 0
var _ended: bool = false
var _slats: MeshPool = null
var _rollers: Array[Node3D] = []
var _bins3: Array[MeshInstance3D] = []
var _bin_mats: Array[StandardMaterial3D] = []


func begin() -> void:
	_build_3d()


# --------------------------------------------------------------------------- décor 3D


func _belt() -> Rect2:
	var r: Rect2 = play_rect()
	return Rect2(r.position.x + 20.0, _window().get_center().y - 38.0, r.size.x - 40.0, 76.0)


## Caisse des jetons : tôle rivetée, tapis roulant à lattes, rouleaux, bacs-gobelets de couleur.
func _build_3d() -> void:
	var r: Rect2 = play_rect()
	var st: Stage3D = use_3d()
	st.frontal(PX3, r.get_center(), r.size.y, 36.0)
	st.env.background_color = Color(0.05, 0.05, 0.07)
	st.env.ambient_light_energy = 0.4
	var root: Node3D = st.root
	var plate: StandardMaterial3D = Stage3D.mat(Color(0.14, 0.14, 0.17), 0.45, 0.45)
	Stage3D.box(root, Vector3(r.size.x * 2.0 * PX3, r.size.y * 2.0 * PX3, 0.04), st.to3(r.get_center(), -0.3), plate)
	var rivet: StandardMaterial3D = Stage3D.mat(Color(0.35, 0.35, 0.4), 0.45, 0.3)
	for k: int in 14:
		var x: float = r.position.x + 30.0 + float(k) * (r.size.x - 60.0) / 13.0
		for y: float in [r.position.y + 16.0, r.end.y - 14.0]:
			Stage3D.sphere(root, 4.0 * PX3, st.to3(Vector2(x, y), -0.28), rivet)
	var belt: Rect2 = _belt()
	Stage3D.box(root, Vector3(belt.size.x * PX3, belt.size.y * PX3, 0.04), st.to3(belt.get_center(), -0.04),
		Stage3D.mat(Color(0.08, 0.08, 0.1), 0.0, 0.8))
	var steel: StandardMaterial3D = Stage3D.mat(Color(0.5, 0.52, 0.58), 0.45, 0.3)
	for y2: float in [belt.position.y - 4.0, belt.end.y + 4.0]:
		Stage3D.box(root, Vector3((belt.size.x + 20.0) * PX3, 10.0 * PX3, 0.08), st.to3(Vector2(belt.get_center().x, y2), 0.0), steel)
	var slat: BoxMesh = BoxMesh.new()
	slat.size = Vector3(6.0 * PX3, (belt.size.y - 8.0) * PX3, 0.012)
	_slats = MeshPool.new(root, slat, Stage3D.mat(Color(0.2, 0.2, 0.24), 0.2, 0.6))
	for side: float in [belt.position.x, belt.end.x]:
		var roll: Node3D = Node3D.new()
		roll.position = st.to3(Vector2(side, belt.get_center().y), -0.02)
		root.add_child(roll)
		Stage3D.cylinder(roll, 36.0 * PX3, (belt.size.y + 24.0) * PX3, Vector3.ZERO, Stage3D.mat(Color(0.25, 0.25, 0.3), 0.45, 0.35))
		Stage3D.box(roll, Vector3(10.0 * PX3, (belt.size.y + 26.0) * PX3, 74.0 * PX3), Vector3.ZERO,
			Stage3D.mat(Color(0.45, 0.46, 0.5), 0.45, 0.3))
		_rollers.append(roll)
	# Bacs en losange (la couleur est la touche).
	var c0: Vector2 = _window().get_center()
	for d: int in 4:
		var col: Color = COLORS[d]
		var at: Vector3 = st.to3(c0 + DIRS[d] * BIN_GAP, 0.0)
		var cup: MeshInstance3D = Stage3D.cylinder(root, BIN_R * PX3, 0.04, at + Vector3(0, 0, 0.0),
			Stage3D.mat(col.darkened(0.35), 0.2, 0.35))
		cup.rotation.x = PI * 0.5
		var inner_m: StandardMaterial3D = Stage3D.mat(col.darkened(0.6), 0.0, 0.7)
		inner_m.emission_enabled = true
		inner_m.emission = col
		inner_m.emission_energy_multiplier = 0.2
		var inner: MeshInstance3D = Stage3D.cylinder(root, (BIN_R - 5.0) * PX3, 0.005, at + Vector3(0, 0, 0.021), inner_m)
		inner.rotation.x = PI * 0.5
		var ring: TorusMesh = TorusMesh.new()
		ring.inner_radius = (BIN_R - 4.0) * PX3
		ring.outer_radius = (BIN_R + 2.0) * PX3
		var rim: MeshInstance3D = MeshInstance3D.new()
		rim.mesh = ring
		rim.material_override = Stage3D.mat(col, 0.3, 0.3)
		rim.rotation.x = PI * 0.5
		rim.position = at + Vector3(0, 0, 0.022)
		root.add_child(rim)
		_bins3.append(rim)
		_bin_mats.append(inner_m)
	Stage3D.omni(root, Color(1.0, 0.92, 0.8), 0.8, st.to3(c0, 2.0), 5.0)


func _sync_3d() -> void:
	if _slats == null:
		return
	var st: Stage3D = stage
	var belt: Rect2 = _belt()
	var off: float = fmod(t * _speed(), SLAT_PX)
	var n: int = 0
	var x: float = belt.position.x + off
	while x < belt.end.x:
		_slats.at(n).position = st.to3(Vector2(x, belt.get_center().y), -0.015)
		n += 1
		x += SLAT_PX
	_slats.hide_from(n)
	for roll: Node3D in _rollers:
		roll.rotation.y = t * _speed() / 36.0
	# Jetons : sur le tapis, puis envolés vers leur bac.
	for c: Dictionary in _chips:
		if not c.has("n"):
			var chip: Node3D = CasinoChip3D.build(st.root, _color(int(c["kind"])), CHIP_R * PX3)
			c["n"] = chip
		var node: Node3D = c["n"]
		var pos: Vector2 = c["p"]
		var lift: float = 0.0
		var sc: float = 1.0
		if bool(c["done"]):
			var u: float = clampf(float(c["t"]) / 0.45, 0.0, 1.0)
			lift = sin(u * PI) * 0.25
			sc = 1.0 - 0.5 * u
		node.position = st.to3(pos, 0.07 + lift)
		node.scale = Vector3.ONE * sc
		node.rotation.z = -pos.x * 0.01
	for k: int in 4:
		var hot: float = 0.0
		for ch: Dictionary in _chips:
			if bool(ch["done"]) and _dir_of(int(ch["to"])) == k:
				hot = maxf(hot, 1.0 - float(ch["t"]) / 0.45)
		_bin_mats[k].emission_energy_multiplier = 0.2 + 2.5 * hot
		_bins3[k].scale = Vector3.ONE * (1.0 + 0.15 * hot)


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
	for c3: Dictionary in _chips:
		if not kept.has(c3) and c3.has("n"):
			(c3["n"] as Node3D).queue_free()
	_chips = kept
	_sync_3d()
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
	if stage == null:
		return
	var r: Rect2 = play_rect()
	var c0: Vector2 = _window().get_center()
	# Bacs en losange : étiquette de la touche sur chaque bac.
	var n: int = _kinds()
	for k: int in n:
		var d: int = _dir_of(k)
		var at: Vector2 = c0 + DIRS[d] * BIN_GAP
		if mouse:
			var lbl: String = tr("TRIAL_SORT_LEFT_CLICK") if k == 0 else tr("TRIAL_SORT_RIGHT_CLICK")
			text(at + Vector2(0, 52.0), lbl, UiKit.SIZE_SMALL, Palette.IVORY)
		else:
			text(at, PAD_LABEL[k] if InputGlyphs.using_pad else KEYS_LABEL[k], UiKit.SIZE_H2, Palette.IVORY, "display", 0)
	# Fenêtre de tri : équerres dorées.
	var w: Rect2 = _window()
	draw_rect(w, Color(Palette.GOLD_LIGHT, 0.08))
	for corner: Vector2 in [w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)]:
		var sx: float = 1.0 if corner.x < w.get_center().x else -1.0
		var sy: float = 1.0 if corner.y < w.get_center().y else -1.0
		draw_line(corner, corner + Vector2(22.0 * sx, 0), Palette.GOLD_LIGHT, 4.0)
		draw_line(corner, corner + Vector2(0, 22.0 * sy), Palette.GOLD_LIGHT, 4.0)
	text(Vector2(r.end.x - 110.0, r.position.y + 40.0), "%d / %d" % [_good, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")
