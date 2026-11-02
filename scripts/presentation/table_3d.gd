class_name Table3D
extends Stage3D
## Tapis de jeu en 3D, derrière le dessin du TableView (survol, curseur et surbrillances restent
## en 2D par-dessus). Caméra frontale calée au pixel : la géométrie tombe exactement sous les
## zones cliquables. Feutrine éclairée par une suspension, boudin de cuir, filets dorés en relief,
## pastilles des numéros vernies, jetons en piles qui projettent leur ombre. Purement cosmétique.

## Marge autour du tapis (pixels) pour le boudin et l'ombre portée.
const MARGIN: float = 46.0
const PX3: float = 0.01
const FOV: float = 30.0
const CHIP_H: float = 0.055
const MAX_STACK: int = 6
const LINE_W: float = 2.5
const DISC_RATIO: float = 0.36
const FELT_NOISE_SEED: int = 1987

var view: TableView = null
var _chips: Dictionary = {}  # spot_id -> Node3D (pile)
var _chip_mats: Array[StandardMaterial3D] = []
var _discs: Dictionary = {}  # numéro -> StandardMaterial3D (pour l'éclat des gagnants)
var _board: Node3D = null
var _lamp: SpotLight3D = null
var _t: float = 0.0


func _init() -> void:
	super._init()
	set_transparent(true)


func _ready() -> void:
	super._ready()
	show_behind_parent = true
	env.ambient_light_energy = 0.55
	key.light_energy = 0.35
	key.rotation_degrees = Vector3(-35, -20, 0)
	rebuild()


## Reconstruit le plateau (appelé quand le TableView change de taille).
func rebuild() -> void:
	# Rien à construire tant que la grille du TableView n'est pas calculée.
	if view == null or view.size.x <= 0.0 or view.cell_w() <= 0.0 or view.cell_h() <= 0.0:
		return
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(-MARGIN, -MARGIN)
	size = view.size + Vector2(MARGIN, MARGIN) * 2.0
	frontal(PX3, size * 0.5, size.y, FOV)
	if _board != null:
		_board.queue_free()
	_chips.clear()
	_discs.clear()
	_board = Node3D.new()
	root.add_child(_board)
	_build_felt()
	_build_rail()
	_build_lines()
	_build_numbers()
	_build_outside()
	_build_light()


func _p(local: Vector2, z: float = 0.0) -> Vector3:
	return to3(local + Vector2(MARGIN, MARGIN), z)


# --------------------------------------------------------------------------- construction


func _build_felt() -> void:
	var felt: StandardMaterial3D = Stage3D.mat(Palette.FELT.lightened(0.08), 0.0, 1.0)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = FELT_NOISE_SEED
	noise.frequency = 0.9
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = Gradient.new()
	tex.color_ramp.set_color(0, Color(0.78, 0.82, 0.8))
	tex.color_ramp.set_color(1, Color(1.0, 1.0, 1.0))
	felt.albedo_texture = tex
	felt.uv1_scale = Vector3(6, 3, 1)
	var sz: Vector2 = view.size + Vector2(MARGIN, MARGIN) * 1.2
	var c: Vector3 = _p(view.size * 0.5, -0.1)
	Stage3D.box(_board, Vector3(sz.x * PX3, sz.y * PX3, 0.2), c, felt)


## Boudin de cuir capitonné et liseré de laiton tout autour du tapis.
func _build_rail() -> void:
	var leather: StandardMaterial3D = Stage3D.mat(Color(0.3, 0.1, 0.06), 0.0, 0.42)
	leather.clearcoat_enabled = true
	leather.clearcoat = 0.4
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.85, 0.3)
	var r: float = 16.0 * PX3
	var tl: Vector2 = Vector2(-MARGIN * 0.62, -MARGIN * 0.62)
	var br: Vector2 = view.size + Vector2(MARGIN, MARGIN) * 0.62
	var edges: Array[Array] = [[tl, Vector2(br.x, tl.y)], [Vector2(tl.x, br.y), br], [tl, Vector2(tl.x, br.y)], [Vector2(br.x, tl.y), br]]
	for e: Array in edges:
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var horiz: bool = absf(a.y - b.y) < 0.5
		var length: float = (b - a).length() * PX3 + r * 2.0
		var mid: Vector3 = _p((a + b) * 0.5, r * 0.6)
		var pad: MeshInstance3D = Stage3D.cylinder(_board, r, length, mid, leather)
		pad.rotation.z = PI * 0.5 if horiz else 0.0
		var trim_off: Vector2 = (Vector2(0, r / PX3 + 3.0) if horiz else Vector2(r / PX3 + 3.0, 0))
		var inward: float = 1.0 if (a.y < view.size.y * 0.5 and horiz) or (a.x < view.size.x * 0.5 and not horiz) else -1.0
		var trim_at: Vector3 = _p((a + b) * 0.5 + trim_off * inward, 0.012)
		var trim_size: Vector3 = Vector3(length, 4.0 * PX3, 0.02) if horiz else Vector3(4.0 * PX3, length, 0.02)
		Stage3D.box(_board, trim_size, trim_at, brass)
	# Boutons de capiton sur le cuir.
	var stud: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.9, 0.25)
	var step: float = 90.0
	var x: float = tl.x + step * 0.5
	while x < br.x:
		Stage3D.sphere(_board, 3.0 * PX3, _p(Vector2(x, tl.y), r * 1.55), stud)
		Stage3D.sphere(_board, 3.0 * PX3, _p(Vector2(x, br.y), r * 1.55), stud)
		x += step


## Filets dorés en relief entre les cases.
func _build_lines() -> void:
	var gold: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.8, 0.32)
	var rects: Array[Rect2] = [Rect2(Vector2.ZERO, Vector2(view.zero_width(), view.grid_bottom()))]
	for c: int in WheelLayout.TABLE_COLS:
		for r: int in WheelLayout.TABLE_ROWS:
			rects.append(view.cell_rect(c, r))
	for r2: int in 3:
		rects.append(view.outside_rect("column:%d" % r2))
	for d: int in 3:
		rects.append(view.outside_rect("dozen:%d" % d))
	for k: String in TableView.EVEN_ORDER:
		rects.append(view.outside_rect(k))
	var done: Dictionary = {}
	for rc: Rect2 in rects:
		var segs: Array[Array] = [
			[rc.position, Vector2(rc.end.x, rc.position.y)],
			[Vector2(rc.position.x, rc.end.y), rc.end],
			[rc.position, Vector2(rc.position.x, rc.end.y)],
			[Vector2(rc.end.x, rc.position.y), rc.end],
		]
		for sg: Array in segs:
			var a: Vector2 = sg[0]
			var b: Vector2 = sg[1]
			var key_s: String = "%d,%d,%d,%d" % [roundi(a.x), roundi(a.y), roundi(b.x), roundi(b.y)]
			if done.has(key_s):
				continue
			done[key_s] = true
			var horiz: bool = absf(a.y - b.y) < 0.5
			var len_px: float = (b - a).length() + LINE_W
			var sz: Vector3 = Vector3(len_px * PX3, LINE_W * PX3, 0.012) if horiz else Vector3(LINE_W * PX3, len_px * PX3, 0.012)
			Stage3D.box(_board, sz, _p((a + b) * 0.5, 0.006), gold)


## Pastilles vernies des numéros (rouge / noir) et le Zéro, chiffres peints.
func _build_numbers() -> void:
	var fs: int = int(view.cell_h() * 0.36)
	var zr: Rect2 = Rect2(Vector2.ZERO, Vector2(view.zero_width(), view.grid_bottom()))
	var zm: StandardMaterial3D = Stage3D.mat(Palette.ZERO_GREEN, 0.0, 0.85)
	Stage3D.box(_board, Vector3(zr.size.x * PX3 - 0.06, zr.size.y * PX3 - 0.06, 0.01), _p(zr.get_center(), 0.002), zm)
	_label(_board, "0", _p(zr.get_center(), 0.03), fs, Palette.IVORY)
	var rad: float = minf(view.cell_w(), view.cell_h()) * DISC_RATIO * PX3
	for c: int in WheelLayout.TABLE_COLS:
		for r: int in WheelLayout.TABLE_ROWS:
			var n: int = WheelLayout.number_on_table(c, r)
			var center: Vector2 = view.cell_rect(c, r).get_center()
			var m: StandardMaterial3D = Stage3D.mat(Palette.pocket_color(WheelLayout.color_of(n)), 0.0, 0.5)
			m.clearcoat_enabled = true
			m.clearcoat = 0.15
			m.emission_enabled = true
			m.emission = Palette.GOLD_LIGHT
			m.emission_energy_multiplier = 0.0
			_discs[n] = m
			var disc: MeshInstance3D = Stage3D.cylinder(_board, rad, 0.03, _p(center, 0.015), m)
			disc.rotation.x = PI * 0.5
			_label(_board, str(n), _p(center, 0.035), fs, Palette.IVORY)


func _build_outside() -> void:
	var fs: int = int(view.cell_h() * 0.36 * 0.8)
	for r: int in 3:
		_label(_board, "2:1", _p(view.outside_rect("column:%d" % r).get_center(), 0.02), fs, Palette.GOLD_LIGHT)
	var dozen_labels: Array[String] = ["1–12", "13–24", "25–36"]
	for d: int in 3:
		_label(_board, dozen_labels[d], _p(view.outside_rect("dozen:%d" % d).get_center(), 0.02), fs, Palette.GOLD_LIGHT)
	for k: String in TableView.EVEN_ORDER:
		var er: Rect2 = view.outside_rect(k)
		if k == "red" or k == "black":
			var gem: StandardMaterial3D = Stage3D.mat(Palette.pocket_color(StringName(k)), 0.1, 0.22)
			gem.clearcoat_enabled = true
			gem.clearcoat = 1.0
			var w: float = er.size.x * 0.22 * PX3
			var h: float = er.size.y * 0.32 * PX3
			# Losange : prisme à 4 pans vu de face, étiré en hauteur.
			var holder: Node3D = Node3D.new()
			holder.position = _p(er.get_center(), 0.02)
			holder.scale = Vector3(1.0, h / w, 1.0)
			_board.add_child(holder)
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = w
			cm.bottom_radius = w
			cm.height = 0.04
			cm.radial_segments = 4
			var gem_mi: MeshInstance3D = MeshInstance3D.new()
			gem_mi.mesh = cm
			gem_mi.material_override = gem
			gem_mi.rotation.x = PI * 0.5
			holder.add_child(gem_mi)
		else:
			_label(_board, view.tr("BET_" + k.to_upper()), _p(er.get_center(), 0.02), UiKit.fs(int(fs * 0.78)), Palette.IVORY)


## Suspension au-dessus du tapis : cône de lumière chaude qui fait briller le vernis et porter
## l'ombre des jetons.
func _build_light() -> void:
	_lamp = SpotLight3D.new()
	_lamp.light_color = Color(1.0, 0.88, 0.7)
	_lamp.light_energy = 2.2
	_lamp.spot_range = 40.0
	_lamp.spot_angle = 55.0
	_lamp.spot_attenuation = 0.4
	_lamp.shadow_enabled = not Settings.b("video", "handheld")
	# Lampe décalée (en haut à gauche) : son reflet tombe hors du tapis, pas sur les numéros.
	_lamp.position = _p(view.size * Vector2(0.15, -0.9), 11.0)
	_board.add_child(_lamp)
	_lamp.look_at(_p(view.size * 0.5, 0.0), Vector3.UP)
	Stage3D.omni(_board, Color(0.5, 0.75, 1.0), 0.6, _p(Vector2(view.size.x * 1.05, -40.0), 2.0), 9.0)


func _label(parent: Node3D, txt: String, at: Vector3, fs: int, col: Color) -> Label3D:
	var l: Label3D = Stage3D.text3d(parent, txt, at, maxi(fs, 8), col)
	l.pixel_size = PX3
	l.outline_size = maxi(3, fs / 10)
	l.double_sided = false
	return l


# --------------------------------------------------------------------------- jetons


## Piles de jetons des mises posées (et petit saut à la pose), éclat des numéros gagnants.
func sync(slip: BetSlip, pops: Dictionary, flash: float, winners: Dictionary) -> void:
	if _board == null:
		return
	var want: Dictionary = {}
	if slip != null:
		for spot_id: String in slip.order:
			want[spot_id] = int(slip.chips[spot_id])
	for sid: Variant in _chips.keys():
		if not want.has(sid):
			(_chips[sid] as Node3D).queue_free()
			_chips.erase(sid)
	var rad: float = minf(view.cell_w(), view.cell_h()) * TableView.CHIP_RADIUS_RATIO * PX3
	for sid2: Variant in want.keys():
		var count: int = int(want[sid2])
		var pile: Node3D = _chips.get(sid2, null)
		if pile == null or int(pile.get_meta("count", -1)) != count:
			if pile != null:
				pile.queue_free()
			pile = _make_pile(count, rad)
			_board.add_child(pile)
			_chips[sid2] = pile
		var pop: float = float(pops.get(sid2, 0.0)) / TableView.CHIP_POP_TIME
		var lift: float = sin(clampf(pop, 0.0, 1.0) * PI) * TableView.CHIP_POP_HEIGHT * PX3 * 2.0
		pile.position = _p(view.spot_anchor(String(sid2)), 0.0) + Vector3(0, 0, lift)
	for n: Variant in _discs.keys():
		var m: StandardMaterial3D = _discs[n]
		var on: bool = winners.has(n) and flash > 0.0
		m.emission_energy_multiplier = (0.6 + 0.6 * sin(flash * 20.0)) * clampf(flash, 0.0, 1.0) if on else 0.0


func _make_pile(count: int, rad: float) -> Node3D:
	var pile: Node3D = Node3D.new()
	pile.set_meta("count", count)
	var stack: int = mini(count, MAX_STACK)
	for k: int in stack:
		var chip: MeshInstance3D = Stage3D.cylinder(pile, rad, CHIP_H, Vector3(0, 0, CHIP_H * (float(k) + 0.5)), _chip_mat(k))
		chip.rotation.x = PI * 0.5
		# Liseré blanc du jeton (anneau plus fin, légèrement en retrait).
		var ring: MeshInstance3D = Stage3D.cylinder(pile, rad * 0.78, CHIP_H * 1.04, chip.position, _chip_mat(-1))
		ring.rotation.x = PI * 0.5
		ring.scale = Vector3(1.0, 1.0, 1.0)
		var inner: MeshInstance3D = Stage3D.cylinder(pile, rad * 0.62, CHIP_H * 1.08, chip.position, _chip_mat(k))
		inner.rotation.x = PI * 0.5
	var top_z: float = CHIP_H * float(stack) + 0.01
	var l: Label3D = Stage3D.text3d(pile, str(count), Vector3(0, 0, top_z), int(rad / PX3 * 1.0), Palette.IVORY)
	l.pixel_size = PX3
	l.outline_size = 4
	return pile


func _chip_mat(k: int) -> StandardMaterial3D:
	if _chip_mats.is_empty():
		_chip_mats.append(Stage3D.mat(Palette.IVORY, 0.0, 0.35))
		_chip_mats.append(Stage3D.mat(Palette.MAGENTA, 0.0, 0.3))
		_chip_mats.append(Stage3D.mat(Palette.MAGENTA.darkened(0.15), 0.0, 0.3))
	if k < 0:
		return _chip_mats[0]
	return _chip_mats[1 + k % 2]


func _process(delta: float) -> void:
	_t += delta
	if _lamp != null:
		# La suspension oscille à peine : la lumière vit sur le vernis.
		_lamp.light_energy = 2.2 + 0.12 * sin(_t * 1.3)
