class_name TrialSort
extends ThrowTrial
## TRI DES JETONS : le tapis roulant de la caisse s'est remis en marche. Chaque jeton qui passe
## dans la fenêtre de tri doit partir dans le bon bac. Les couleurs sont celles des boutons de
## la manette Xbox, disposés en losange autour de la fenêtre : X bleu à gauche, Y jaune en haut,
## B rouge à droite, A vert en bas (au clavier, les flèches dans les mêmes directions ; à la
## souris : bleu clic gauche, rouge clic droit). Le tapis accélère. Note = jetons bien triés, moins une
## pénalité par appui à vide ou mauvais bac.
## 2.0 : des jetons PIÉGÉS (noirs, croix rouge : à laisser passer), DOUBLES (deux couleurs : un
## appui par couleur), à RETOURNER (dos gris : la couleur n'apparaît qu'en entrant dans la
## fenêtre), et des bacs qui TOURNENT en cours de partie (les couleurs changent de bouton).

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
const TRAP_COLOR: Color = Color("16161c")
const BACK_COLOR: Color = Color("8a8a96")

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
## Couleur du bac de chaque bouton (bouton k → couleur _perm[k]) ; éclair au changement.
var _perm: Array[int] = [0, 1, 2, 3]
var _spin_flash: float = 0.0
var _half_credit: float = 0.0


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
	# Salle de comptage de la caisse : lambris de noyer à panneaux moulurés, filets de laiton,
	# bande de feutre vert derrière le tapis, deux lampes de bureau hors champ.
	var plate: StandardMaterial3D = Stage3D.textured("wood", Color(0.55, 0.36, 0.24), 1.2, 0.0, 0.55)
	Stage3D.box(root, Vector3(r.size.x * 2.0 * PX3, r.size.y * 2.0 * PX3, 0.04), st.to3(r.get_center(), -0.3), plate)
	var mould: StandardMaterial3D = Stage3D.textured("wood", Color(0.36, 0.22, 0.14), 1.2, 0.0, 0.5)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.85, 0.3)
	var panels: int = 6
	for k: int in panels:
		var pw: float = (r.size.x - 40.0) / float(panels)
		var px: float = r.position.x + 20.0 + pw * (float(k) + 0.5)
		for y: float in [r.position.y + r.size.y * 0.2, r.end.y - r.size.y * 0.2]:
			Stage3D.box(root, Vector3((pw - 24.0) * PX3, r.size.y * 0.26 * PX3, 0.03), st.to3(Vector2(px, y), -0.27), mould)
	for y3: float in [r.position.y + 6.0, r.end.y - 6.0]:
		Stage3D.box(root, Vector3(r.size.x * PX3, 6.0 * PX3, 0.03), st.to3(Vector2(r.get_center().x, y3), -0.25), brass)
	var felt_band: Rect2 = _belt().grow_individual(0.0, 26.0, 0.0, 26.0)
	Stage3D.box(root, Vector3(r.size.x * PX3, felt_band.size.y * PX3, 0.02), st.to3(felt_band.get_center(), -0.2),
		Stage3D.textured("felt", Color(0.1, 0.36, 0.22), 0.6))
	for lx: float in [r.position.x + r.size.x * 0.12, r.end.x - r.size.x * 0.12]:
		var lamp: Vector3 = st.to3(Vector2(lx, r.position.y + 40.0), 0.2)
		Stage3D.omni(root, Color(1.0, 0.82, 0.55), 0.6, lamp + Vector3(0, -0.3, 0.4), 3.0)
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
		var collar: TorusMesh = TorusMesh.new()
		collar.inner_radius = (BIN_R + 2.0) * PX3
		collar.outer_radius = (BIN_R + 7.0) * PX3
		var brim: MeshInstance3D = MeshInstance3D.new()
		brim.mesh = collar
		brim.material_override = brass
		brim.rotation.x = PI * 0.5
		brim.position = at + Vector3(0, 0, 0.018)
		root.add_child(brim)
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
			var chip: Node3D = CasinoChip3D.build(st.root, _chip_color(c), CHIP_R * PX3)
			if String(c["type"]) == "double":
				var inner: MeshInstance3D = Stage3D.cylinder(chip, CHIP_R * 0.55 * PX3, 0.03, Vector3(0, 0, 0.012),
					Stage3D.mat(_color(int(c["kind2"])), 0.1, 0.4))
				inner.rotation.x = PI * 0.5
			c["n"] = chip
		if String(c["type"]) == "flip" and not bool(c["shown"]) and _revealed(c):
			# Le jeton se retourne : on remplace le dos gris par la face colorée.
			c["shown"] = true
			(c["n"] as Node3D).queue_free()
			c["n"] = CasinoChip3D.build(st.root, _color(int(c["kind"])), CHIP_R * PX3)
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
		_bin_mats[k].emission_energy_multiplier = 0.2 + 2.5 * hot + 2.0 * _spin_flash
		_bins3[k].scale = Vector3.ONE * (1.0 + 0.15 * hot)


func _kinds() -> int:
	return 2 if mouse else 4


## Couleur effective : à la souris, le symbole 1 (clic droit) désigne le rouge (B, à droite).
## Couleur affichée d'un jeton : noir (piège), dos gris (pas encore retourné), sinon la sienne.
func _chip_color(c: Dictionary) -> Color:
	match String(c["type"]):
		"trap":
			return TRAP_COLOR
		"flip":
			return _color(int(c["kind"])) if _revealed(c) else BACK_COLOR
	return _color(int(c["kind"]))


## Jeton à retourner : sa couleur apparaît quand il entre dans la fenêtre.
func _revealed(c: Dictionary) -> bool:
	return String(c["type"]) != "flip" or (c["p"] as Vector2).x >= _window().position.x - CHIP_R * p("flip_lead")


## Bouton (0..kinds-1) qui mène au bac de la couleur `kind`.
func _key_for(kind: int) -> int:
	return _perm.find(kind)


## Les bacs tournent : chaque bouton envoie vers une autre couleur.
func _rotate_bins() -> void:
	if _kinds() == 2:
		_perm = [_perm[1], _perm[0], 2, 3]
	else:
		_perm = [_perm[3], _perm[0], _perm[1], _perm[2]]
	_spin_flash = 1.0
	_recolor_bins()
	AudioBus.play("whoosh", 0.8, -4.0)
	pop(_window().get_center() + Vector2(0, -BIN_GAP.y - 70.0), 0.5, "TRIAL_SORT_BINS_TURN")


func _recolor_bins() -> void:
	for k: int in _kinds():
		var d: int = _dir_of(k)
		if d >= _bins3.size():
			continue
		var col: Color = _color(_perm[k])
		(_bins3[d].material_override as StandardMaterial3D).albedo_color = col
		_bin_mats[d].albedo_color = col.darkened(0.6)
		_bin_mats[d].emission = col


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
			var color: int = _perm[k]
			var kind: String = String(c["type"])
			if kind == "double" and int(c["half"]) < 0 and (color == int(c["kind"]) or color == int(c["kind2"])):
				c["half"] = color  # première moitié : le jeton attend la seconde couleur
				AudioBus.play("chip_place", 1.0 + 0.1 * float(k), -4.0)
				return
			c["done"] = true
			c["to"] = k
			var want: int = int(c["kind"])
			if kind == "double":
				want = int(c["kind2"]) if int(c["half"]) == int(c["kind"]) else int(c["kind"])
			if kind != "trap" and _revealed(c) and color == want:
				_good += 1
				AudioBus.play("chip_place", 1.0 + 0.1 * float(k))
				pop(pos + Vector2(0, -60), 1.0, "")
			else:
				_wrong += 1
				AudioBus.play("error", 1.0, -6.0)
				pop(pos + Vector2(0, -60), 0.0, "TRIAL_SORT_TRAP" if kind == "trap" else "")
			return
	_wrong += 1
	AudioBus.play("sticky", 1.3, -10.0)


func tick(dt: float) -> void:
	if _ended:
		return
	_spin_flash = maxf(0.0, _spin_flash - dt * 2.0)
	_spawn_t -= dt
	if _spawn_t <= 0.0 and _spawned < pi("chips"):
		_spawned += 1
		var r: Rect2 = play_rect()
		var kind: int = rng.randi_range(0, _kinds() - 1)
		var kind2: int = (kind + 1 + rng.randi_range(0, _kinds() - 2)) % _kinds()
		var type: String = "normal"
		var roll: float = rng.randf()
		if _spawned > pi("plain_first"):
			if roll < p("trap_share"):
				type = "trap"
			elif roll < p("trap_share") + p("double_share"):
				type = "double"
			elif roll < p("trap_share") + p("double_share") + p("flip_share"):
				type = "flip"
		_chips.append({"p": Vector2(r.position.x + 24.0, r.get_center().y), "kind": kind, "kind2": kind2, "type": type,
			"half": -1, "shown": false, "done": false, "to": -1, "t": 0.0})
		_spawn_t = p("gap_px") / _speed() * (p("double_gap") if type == "double" else 1.0)
		for at: Variant in Balance.arr("throw_trials.sort.turn_at"):
			if _spawned == int(at):
				_rotate_bins()
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
			if String(c["type"]) == "trap":
				_good += 1  # piège laissé passer : bien joué
			elif String(c["type"]) == "double" and int(c["half"]) >= 0:
				_half_credit += 0.5
			else:
				AudioBus.play("lose_soft", 1.2, -10.0)
			if c.has("n"):
				(c["n"] as Node3D).queue_free()
				c.erase("n")
			continue
		kept.append(c)
	for c3: Dictionary in _chips:
		if not kept.has(c3) and c3.has("n"):
			(c3["n"] as Node3D).queue_free()
	_chips = kept
	_sync_3d()
	if _spawned >= pi("chips") and _chips.is_empty():
		_ended = true
		var sc: float = (float(_good) + _half_credit) / float(pi("chips")) - p("wrong_penalty") * float(_wrong)
		finish(clampf(sc, 0.0, 1.0))


func bot_wants() -> Dictionary:
	var w: Rect2 = _window()
	for c: Dictionary in _chips:
		if bool(c["done"]) or not w.has_point(c["p"] as Vector2) or String(c["type"]) == "trap" or not _revealed(c):
			continue
		var color: int = int(c["kind"])
		if String(c["type"]) == "double" and int(c["half"]) == color:
			color = int(c["kind2"])
		return {"do": "sym", "symbol": _key_for(color)}
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
	# Marques : croix du piège, « ? » du jeton pas encore retourné, moitié déjà triée du double.
	for c: Dictionary in _chips:
		if bool(c["done"]):
			continue
		var cp: Vector2 = c["p"]
		match String(c["type"]):
			"trap":
				draw_line(cp + Vector2(-12, -12), cp + Vector2(12, 12), Palette.MULT_RED, 5.0)
				draw_line(cp + Vector2(-12, 12), cp + Vector2(12, -12), Palette.MULT_RED, 5.0)
			"flip":
				if not _revealed(c):
					text(cp, "?", UiKit.SIZE_BODY, Palette.INK, "display", 0)
			"double":
				if int(c["half"]) >= 0:
					draw_arc(cp, CHIP_R + 6.0, 0, TAU, 28, _color(int(c["half"])), 4.0)
	var w: Rect2 = _window()
	draw_rect(w, Color(Palette.GOLD_LIGHT, 0.08))
	for corner: Vector2 in [w.position, Vector2(w.end.x, w.position.y), w.end, Vector2(w.position.x, w.end.y)]:
		var sx: float = 1.0 if corner.x < w.get_center().x else -1.0
		var sy: float = 1.0 if corner.y < w.get_center().y else -1.0
		draw_line(corner, corner + Vector2(22.0 * sx, 0), Palette.GOLD_LIGHT, 4.0)
		draw_line(corner, corner + Vector2(0, 22.0 * sy), Palette.GOLD_LIGHT, 4.0)
	text(Vector2(r.end.x - 110.0, r.position.y + 40.0), "%d / %d" % [_good, pi("chips")], UiKit.SIZE_BODY, Palette.IVORY, "mono")


## Au doigt : le bac touché (le plus proche).
func tap_action(pos: Vector2) -> StringName:
	var c0: Vector2 = _window().get_center()
	var best: int = 0
	for k: int in _kinds():
		var at: Vector2 = c0 + DIRS[_dir_of(k)] * BIN_GAP
		if pos.distance_to(at) < pos.distance_to(c0 + DIRS[_dir_of(best)] * BIN_GAP):
			best = k
	return QTE_ACTIONS[best]
