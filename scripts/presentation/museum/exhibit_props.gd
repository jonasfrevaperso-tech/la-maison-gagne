class_name ExhibitProps
extends RefCounted
## Objets exposés du Musée : une maquette 3D par épreuve, construite en code (cosmétique pur).
## Chaque maquette tient dans un cube d'environ 0,8 m posé sur le plateau du piédestal (y = 0).

const CHIP_COLORS: Array[Color] = [Palette.ROULETTE_RED, Palette.CHIPS_BLUE, Palette.EMERALD, Palette.GOLD, Palette.IVORY]


## Maquette de l'épreuve `trial_id` ; repli : un jeton géant.
static func build(trial_id: String) -> Node3D:
	var n: Node3D = Node3D.new()
	n.name = "exhibit_" + trial_id
	match trial_id:
		"bottles":
			_bottles(n)
		"shaker":
			_shaker(n)
		"pour":
			_pour(n)
		"simon":
			_simon(n)
		"darts":
			_darts(n)
		"shells":
			_shells(n)
		"memory":
			_memory(n)
		"blackjack":
			_blackjack(n)
		"highlow":
			_highlow(n)
		"scratch":
			_scratch(n)
		"dice":
			_dice(n)
		"invaders":
			_invaders(n)
		"pachinko":
			_pachinko(n)
		"derby":
			_derby(n)
		"rhythm":
			_rhythm(n)
		"fishing":
			_fishing(n)
		"juggle":
			_juggle(n)
		"catch":
			_catch(n)
		"billiards":
			_billiards(n)
		"charge":
			_charge(n)
		"safe":
			_safe(n)
		"lasers":
			_lasers(n)
		"cave":
			_cave(n)
		"tower":
			_tower(n)
		"sort":
			_sort(n)
		"tapdance":
			_tapdance(n)
		"spotlight":
			_spotlight(n)
		"tightrope":
			_tightrope(n)
		"hattoss":
			_hattoss(n)
		"mentalist":
			_mentalist(n)
		_:
			var c: Node3D = CasinoChip3D.build(n, Palette.GOLD, 0.3)
			c.position.y = 0.3
	return n


static func _m(col: Color, metal: float = 0.0, rough: float = 0.55) -> StandardMaterial3D:
	return Stage3D.mat(col, metal, rough)


static func _glass(col: Color, alpha: float = 0.35) -> StandardMaterial3D:
	var m: StandardMaterial3D = Stage3D.mat(Color(col, alpha), 0.0, 0.08)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


static func _bottle(n: Node3D, col: Color, at: Vector3, h: float = 0.42) -> void:
	var g: StandardMaterial3D = _glass(col.darkened(0.2), 0.8)
	Stage3D.cylinder(n, 0.07, h * 0.62, at + Vector3(0, h * 0.31, 0), g)
	Stage3D.cylinder(n, 0.025, h * 0.3, at + Vector3(0, h * 0.77, 0), g, 0.022)
	Stage3D.cylinder(n, 0.072, h * 0.18, at + Vector3(0, h * 0.32, 0), _m(Palette.IVORY, 0.0, 0.8))
	Stage3D.cylinder(n, 0.027, 0.04, at + Vector3(0, h * 0.94, 0), _m(Palette.GOLD, 0.45, 0.3))


static func _stack(n: Node3D, at: Vector3, count: int, first: int = 0, r: float = 0.14) -> void:
	for k: int in count:
		var c: Node3D = CasinoChip3D.build(n, CHIP_COLORS[(first + k) % CHIP_COLORS.size()], r)
		c.rotation.x = PI * 0.5
		c.position = at + Vector3(0, CasinoChip3D.THICK * (0.5 + 1.05 * float(k)), 0)


static func _card(n: Node3D, rank: int, suit: int, at: Vector3, rot: Vector3, up: bool = true, k: float = 0.6) -> PlayingCard3D:
	var c: PlayingCard3D = PlayingCard3D.new()
	n.add_child(c)
	c.set_card(rank, suit)
	c.position = at
	c.rotation = rot
	c.scale = Vector3.ONE * k
	if not up:
		c.rotation.z += PI
	return c


# --------------------------------------------------------------------------- le Bar


static func _bottles(n: Node3D) -> void:
	Stage3D.box(n, Vector3(0.8, 0.04, 0.22), Vector3(0, 0.02, 0), _m(Color(0.25, 0.12, 0.06)))
	var cols: Array[Color] = [Color(0.2, 0.5, 0.2), Color(0.55, 0.3, 0.1), Color(0.6, 0.55, 0.2), Color(0.3, 0.12, 0.1)]
	for k: int in 4:
		_bottle(n, cols[k], Vector3(-0.3 + 0.2 * float(k), 0.04, 0), 0.4 + 0.04 * float(k % 2))


static func _shaker(n: Node3D) -> void:
	var steel: StandardMaterial3D = _m(Color(0.78, 0.8, 0.84), 0.45, 0.2)
	Stage3D.cylinder(n, 0.11, 0.34, Vector3(0, 0.17, 0), steel, 0.13)
	Stage3D.cylinder(n, 0.12, 0.14, Vector3(0, 0.41, 0), steel, 0.07)
	Stage3D.cylinder(n, 0.035, 0.06, Vector3(0, 0.51, 0), steel)
	Stage3D.cylinder(n, 0.13, 0.015, Vector3(0, 0.34, 0), _m(Palette.GOLD, 0.45, 0.3))
	_glass_at(n, Vector3(0.26, 0, 0.05), Color(0.95, 0.5, 0.3))


static func _glass_at(n: Node3D, at: Vector3, drink: Color) -> void:
	Stage3D.cylinder(n, 0.07, 0.16, at + Vector3(0, 0.08, 0), _m(drink, 0.0, 0.3), 0.08)
	Stage3D.cylinder(n, 0.082, 0.22, at + Vector3(0, 0.11, 0), _glass(Color(0.9, 0.95, 1.0), 0.22), 0.092)


static func _pour(n: Node3D) -> void:
	Stage3D.cylinder(n, 0.14, 0.34, Vector3(0, 0.17, 0), _glass(Color(0.9, 0.95, 1.0), 0.2), 0.16)
	Stage3D.cylinder(n, 0.13, 0.22, Vector3(0, 0.11, 0), _m(Color(0.95, 0.72, 0.25), 0.0, 0.3), 0.145)
	Stage3D.cylinder(n, 0.15, 0.06, Vector3(0, 0.25, 0), _m(Palette.IVORY, 0.0, 0.9), 0.152)
	_bottle(n, Color(0.55, 0.3, 0.1), Vector3(0.3, 0, -0.05), 0.46)


static func _simon(n: Node3D) -> void:
	Stage3D.box(n, Vector3(0.52, 0.72, 0.3), Vector3(0, 0.36, 0), _m(Color(0.45, 0.06, 0.08), 0.1, 0.4))
	Stage3D.cylinder(n, 0.26, 0.3, Vector3(0, 0.72, 0), _m(Color(0.45, 0.06, 0.08), 0.1, 0.4)).rotation.x = PI * 0.5
	var cols: Array[Color] = [Palette.GOLD, Palette.CHIPS_BLUE, Palette.ROULETTE_RED, Palette.EMERALD]
	var offs: Array[Vector2] = [Vector2(0, 0.1), Vector2(-0.12, 0), Vector2(0.12, 0), Vector2(0, -0.1)]
	for k: int in 4:
		var b: MeshInstance3D = Stage3D.cylinder(n, 0.05, 0.03, Vector3(offs[k].x, 0.42 + offs[k].y, 0.16), Stage3D.glow(cols[k], 1.2))
		b.rotation.x = PI * 0.5
	for side: float in [-1.0, 1.0]:
		Stage3D.box(n, Vector3(0.04, 0.6, 0.04), Vector3(side * 0.24, 0.4, 0.15),
			Stage3D.glow(Palette.MAGENTA if side < 0 else Palette.CYAN, 1.6))


static func _darts(n: Node3D) -> void:
	Stage3D.box(n, Vector3(0.64, 0.64, 0.05), Vector3(0, 0.45, -0.08), _m(Color(0.22, 0.12, 0.06)))
	var rings: Array[Color] = [Color(0.1, 0.1, 0.1), Color(0.85, 0.8, 0.65), Palette.ROULETTE_RED, Color(0.1, 0.1, 0.1), Palette.ZERO_GREEN]
	for k: int in rings.size():
		var d: MeshInstance3D = Stage3D.cylinder(n, 0.27 - 0.05 * float(k), 0.02 + 0.004 * float(k), Vector3(0, 0.45, -0.04),
			_m(rings[k], 0.0, 0.8))
		d.rotation.x = PI * 0.5
	for k2: int in 3:
		var dart: MeshInstance3D = Stage3D.cylinder(n, 0.008, 0.16, Vector3(-0.04 + 0.05 * float(k2), 0.47 - 0.03 * float(k2), 0.04),
			_m(Palette.GOLD, 0.45, 0.3))
		dart.rotation.x = PI * 0.5


# --------------------------------------------------------------------------- le Salon des cartes


static func _felt(n: Node3D, w: float = 0.8, d: float = 0.5) -> void:
	Stage3D.box(n, Vector3(w, 0.03, d), Vector3(0, 0.015, 0), _m(Palette.FELT_LIGHT, 0.0, 0.95))


static func _shells(n: Node3D) -> void:
	_felt(n)
	for k: int in 3:
		Stage3D.cylinder(n, 0.08, 0.16, Vector3(-0.24 + 0.24 * float(k), 0.11, 0), _m(Color(0.62, 0.3, 0.15), 0.0, 0.5), 0.06)
	Stage3D.sphere(n, 0.03, Vector3(0.12, 0.06, 0.12), _m(Palette.IVORY, 0.0, 0.3))


static func _memory(n: Node3D) -> void:
	_felt(n)
	for k: int in 6:
		# Cartes réduites et espacées : elles ne se chevauchent jamais (sinon elles scintillent).
		var at: Vector3 = Vector3(-0.24 + 0.24 * float(k % 3), 0.04, -0.12 + 0.24 * float(floori(k / 3.0)))
		_card(n, 1 + k * 2, k % 4, at, Vector3.ZERO, k % 2 == 0, 0.36)


static func _blackjack(n: Node3D) -> void:
	_felt(n)
	_card(n, 1, 3, Vector3(-0.08, 0.04, 0.05), Vector3(-0.5, 0.1, 0))
	_card(n, 13, 1, Vector3(0.1, 0.06, 0.05), Vector3(-0.5, -0.15, 0))
	_stack(n, Vector3(0.3, 0.03, -0.12), 5, 0, 0.07)


static func _highlow(n: Node3D) -> void:
	_felt(n)
	_card(n, 7, 2, Vector3(-0.16, 0.04, 0.0), Vector3(-0.6, 0, 0), true, 0.48)
	_card(n, 7, 0, Vector3(0.16, 0.04, 0.0), Vector3(-0.6, 0, 0), false, 0.48)
	Stage3D.text3d(n, "▲ ▼", Vector3(0, 0.38, 0), 64, Palette.GOLD_LIGHT)


static func _scratch(n: Node3D) -> void:
	var t: MeshInstance3D = Stage3D.box(n, Vector3(0.5, 0.01, 0.32), Vector3(0, 0.1, 0), _m(Color(0.95, 0.85, 0.5), 0.0, 0.7))
	t.rotation.x = -0.7
	var foil: MeshInstance3D = Stage3D.box(t, Vector3(0.38, 0.012, 0.16), Vector3(0, 0.002, 0.02), _m(Color(0.75, 0.76, 0.8), 0.45, 0.35))
	foil.name = "foil"
	_stack(n, Vector3(0.3, 0.0, 0.18), 1, 3, 0.06)


static func _dice(n: Node3D) -> void:
	_felt(n)
	for k: int in 2:
		var d: MeshInstance3D = Stage3D.box(n, Vector3.ONE * 0.13, Vector3(-0.1 + 0.2 * float(k), 0.1, 0),
			_m(Color(0.92, 0.08, 0.12), 0.0, 0.25))
		d.rotation = Vector3(0.3 * float(k), 0.6 - float(k), 0.2)
		for p: int in 3:
			Stage3D.sphere(d, 0.014, Vector3(-0.035 + 0.035 * float(p), 0.066, -0.035 + 0.035 * float(p)), _m(Palette.IVORY, 0.0, 0.4))


# --------------------------------------------------------------------------- la Salle d'arcade


static func _cabinet(n: Node3D, body: Color, screen: Color) -> MeshInstance3D:
	var b: StandardMaterial3D = _m(body, 0.1, 0.45)
	Stage3D.box(n, Vector3(0.46, 0.9, 0.36), Vector3(0, 0.45, 0), b)
	Stage3D.box(n, Vector3(0.5, 0.1, 0.42), Vector3(0, 0.95, 0.02), b)
	var scr: MeshInstance3D = Stage3D.box(n, Vector3(0.34, 0.28, 0.02), Vector3(0, 0.64, 0.18), Stage3D.glow(screen, 0.9))
	Stage3D.box(n, Vector3(0.44, 0.06, 0.16), Vector3(0, 0.42, 0.24), b)
	return scr


static func _invaders(n: Node3D) -> void:
	var scr: MeshInstance3D = _cabinet(n, Color(0.1, 0.1, 0.25), Color(0.02, 0.05, 0.1))
	for r: int in 3:
		for c: int in 5:
			Stage3D.box(scr, Vector3(0.035, 0.025, 0.01), Vector3(-0.12 + 0.06 * float(c), 0.08 - 0.05 * float(r), 0.012),
				Stage3D.glow([Palette.MAGENTA, Palette.CYAN, Palette.EMERALD][r], 2.0))
	Stage3D.box(scr, Vector3(0.05, 0.02, 0.01), Vector3(0, -0.1, 0.012), Stage3D.glow(Palette.GOLD_LIGHT, 2.0))


static func _pachinko(n: Node3D) -> void:
	var scr: MeshInstance3D = _cabinet(n, Color(0.5, 0.08, 0.3), Color(0.15, 0.1, 0.05))
	for r: int in 5:
		for c: int in 6:
			Stage3D.sphere(scr, 0.008, Vector3(-0.13 + 0.052 * float(c) + 0.026 * float(r % 2), 0.11 - 0.05 * float(r), 0.014),
				_m(Palette.GOLD, 0.45, 0.3))
	Stage3D.sphere(scr, 0.016, Vector3(0.03, 0.04, 0.02), _m(Color(0.85, 0.86, 0.9), 0.45, 0.15))


static func _derby(n: Node3D) -> void:
	Stage3D.cylinder(n, 0.38, 0.05, Vector3(0, 0.025, 0), _m(Color(0.5, 0.1, 0.12), 0.0, 0.5))
	Stage3D.cylinder(n, 0.03, 0.7, Vector3(0, 0.38, 0), _m(Palette.GOLD, 0.45, 0.3))
	Stage3D.cylinder(n, 0.42, 0.14, Vector3(0, 0.78, 0), _m(Palette.IVORY, 0.0, 0.6), 0.02)
	for k: int in 3:
		var a: float = TAU * float(k) / 3.0
		var at: Vector3 = Vector3(cos(a) * 0.26, 0, sin(a) * 0.26)
		Stage3D.cylinder(n, 0.008, 0.7, at + Vector3(0, 0.38, 0), _m(Palette.GOLD, 0.45, 0.3))
		var horse: MeshInstance3D = Stage3D.box(n, Vector3(0.16, 0.08, 0.05), at + Vector3(0, 0.3 + 0.06 * float(k), 0),
			_m([Palette.IVORY, Palette.ROULETTE_RED, Palette.CHIPS_BLUE][k], 0.0, 0.4))
		horse.rotation.y = -a
		Stage3D.box(horse, Vector3(0.04, 0.1, 0.04), Vector3(0.08, 0.06, 0), horse.material_override)
	for k2: int in 8:
		var b: float = TAU * float(k2) / 8.0
		Stage3D.sphere(n, 0.02, Vector3(cos(b) * 0.42, 0.72, sin(b) * 0.42), Stage3D.glow(Palette.GOLD_LIGHT, 2.0))


static func _rhythm(n: Node3D) -> void:
	Stage3D.box(n, Vector3(0.62, 0.12, 0.44), Vector3(0, 0.06, 0), _m(Color(0.2, 0.1, 0.06), 0.0, 0.4))
	var disc: MeshInstance3D = Stage3D.cylinder(n, 0.19, 0.01, Vector3(-0.05, 0.125, 0), _m(Color(0.04, 0.04, 0.05), 0.0, 0.25))
	disc.name = "spin"
	Stage3D.cylinder(disc, 0.06, 0.012, Vector3.ZERO, _m(Palette.ROULETTE_RED, 0.0, 0.6))
	var arm: MeshInstance3D = Stage3D.box(n, Vector3(0.02, 0.02, 0.3), Vector3(0.22, 0.15, -0.02), _m(Color(0.78, 0.8, 0.84), 0.45, 0.2))
	arm.rotation.y = 0.4
	for k: int in 4:
		Stage3D.box(n, Vector3(0.035, 0.025, 0.035), Vector3(0.17 + 0.045 * float(k), 0.13, 0.14), _m(Palette.IVORY))


# --------------------------------------------------------------------------- le Hall et la Fontaine


static func _fishing(n: Node3D) -> void:
	var stone: StandardMaterial3D = _m(Color(0.45, 0.42, 0.4), 0.0, 0.7)
	Stage3D.cylinder(n, 0.38, 0.16, Vector3(0, 0.08, 0), stone)
	Stage3D.cylinder(n, 0.33, 0.02, Vector3(0, 0.15, 0), _m(Color(0.04, 0.2, 0.26), 0.0, 0.12))
	for k: int in 3:
		var koi: MeshInstance3D = Stage3D.sphere(n, 0.04, Vector3(-0.15 + 0.14 * float(k), 0.12, 0.08 * float(k - 1)),
			_m(Color(1.0, 0.45, 0.1)))
		koi.scale = Vector3(1.8, 0.5, 0.8)
		koi.rotation.y = float(k)
	var rod: MeshInstance3D = Stage3D.cylinder(n, 0.008, 0.7, Vector3(0.3, 0.45, 0.1), _m(Color(0.35, 0.2, 0.08)))
	rod.rotation.z = 0.7
	Stage3D.sphere(n, 0.02, Vector3(0.05, 0.17, 0.05), _m(Palette.ROULETTE_RED, 0.0, 0.3))


static func _juggle(n: Node3D) -> void:
	Stage3D.cylinder(n, 0.02, 0.4, Vector3(0, 0.2, 0), _m(Palette.GOLD, 0.45, 0.3))
	for k: int in 3:
		var a: float = PI * (0.2 + 0.3 * float(k))
		var c: Node3D = CasinoChip3D.build(n, CHIP_COLORS[k], 0.09)
		c.position = Vector3(cos(a) * 0.26, 0.38 + sin(a) * 0.26, 0)
		c.rotation = Vector3(PI * 0.5, 0, float(k))
	Stage3D.cylinder(n, 0.16, 0.02, Vector3(0, 0.01, 0), _m(Palette.VELVET, 0.0, 0.8))


static func _catch(n: Node3D) -> void:
	var brass: StandardMaterial3D = _m(Palette.GOLD, 0.45, 0.3)
	Stage3D.cylinder(n, 0.012, 0.3, Vector3(0, 0.75, 0), brass)
	Stage3D.cylinder(n, 0.26, 0.03, Vector3(0, 0.58, 0), brass, 0.18)
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		Stage3D.cylinder(n, 0.012, 0.06, Vector3(cos(a) * 0.24, 0.63, sin(a) * 0.24), Stage3D.glow(Palette.GOLD_LIGHT, 2.5))
		Stage3D.sphere(n, 0.02, Vector3(cos(a) * 0.2, 0.52, sin(a) * 0.2), _glass(Color(0.9, 0.95, 1.0), 0.6))
	for k2: int in 4:
		CasinoChip3D.build(n, CHIP_COLORS[k2], 0.05).position = Vector3(-0.18 + 0.12 * float(k2), 0.12 + 0.1 * float(k2 % 2), 0.1)
	Stage3D.box(n, Vector3(0.3, 0.03, 0.12), Vector3(0, 0.015, 0.1), _m(Color(0.4, 0.22, 0.1)))


static func _billiards(n: Node3D) -> void:
	var wood: StandardMaterial3D = _m(Color(0.3, 0.13, 0.06), 0.0, 0.4)
	Stage3D.box(n, Vector3(0.8, 0.06, 0.46), Vector3(0, 0.22, 0), wood)
	Stage3D.box(n, Vector3(0.7, 0.02, 0.36), Vector3(0, 0.26, 0), _m(Color(0.05, 0.35, 0.2), 0.0, 0.95))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			Stage3D.box(n, Vector3(0.05, 0.2, 0.05), Vector3(sx * 0.34, 0.1, sz * 0.18), wood)
	var cols: Array[Color] = [Palette.IVORY, Palette.ROULETTE_RED, Palette.GOLD]
	for k: int in 3:
		Stage3D.sphere(n, 0.025, Vector3(-0.15 + 0.15 * float(k), 0.295, 0.04 * float(k - 1)), _m(cols[k], 0.0, 0.15))
	var cue: MeshInstance3D = Stage3D.cylinder(n, 0.008, 0.6, Vector3(-0.32, 0.32, 0.02), _m(Color(0.75, 0.6, 0.35)), 0.004)
	cue.rotation.z = PI * 0.5 - 0.15


static func _charge(n: Node3D) -> void:
	var rim: MeshInstance3D = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.24
	tor.outer_radius = 0.32
	rim.mesh = tor
	rim.material_override = _m(Color(0.35, 0.16, 0.07), 0.0, 0.35)
	rim.position = Vector3(0, 0.4, 0)
	rim.rotation.x = PI * 0.5
	n.add_child(rim)
	for k: int in 12:
		var a: float = TAU * float(k) / 12.0
		Stage3D.box(n, Vector3(0.05, 0.05, 0.02), Vector3(cos(a) * 0.28, 0.4 + sin(a) * 0.28, 0.03),
			_m(Palette.ROULETTE_RED if k % 2 == 0 else Palette.ROULETTE_BLACK, 0.0, 0.4))
	var needle: MeshInstance3D = Stage3D.box(n, Vector3(0.015, 0.22, 0.01), Vector3(0, 0.48, 0.05), _m(Palette.GOLD, 0.45, 0.3))
	needle.rotation.z = -0.5
	Stage3D.box(n, Vector3(0.2, 0.08, 0.12), Vector3(0, 0.04, 0), _m(Palette.GOLD_DARK, 0.45, 0.35))


# --------------------------------------------------------------------------- les Coffres


static func _safe(n: Node3D) -> void:
	var steel: StandardMaterial3D = _m(Color(0.32, 0.34, 0.38), 0.45, 0.35)
	Stage3D.box(n, Vector3(0.6, 0.66, 0.5), Vector3(0, 0.33, 0), steel)
	var dial: MeshInstance3D = Stage3D.cylinder(n, 0.11, 0.04, Vector3(-0.05, 0.38, 0.26), _m(Color(0.75, 0.76, 0.8), 0.45, 0.25))
	dial.rotation.x = PI * 0.5
	dial.name = "spin_z"
	Stage3D.box(n, Vector3(0.03, 0.16, 0.04), Vector3(0.2, 0.3, 0.26), _m(Palette.GOLD, 0.45, 0.3))
	Stage3D.text3d(n, "12 · 37", Vector3(-0.05, 0.56, 0.26), 40, Palette.EMERALD)


static func _lasers(n: Node3D) -> void:
	var steel: StandardMaterial3D = _m(Color(0.3, 0.32, 0.36), 0.45, 0.35)
	for side: float in [-1.0, 1.0]:
		Stage3D.box(n, Vector3(0.06, 0.7, 0.06), Vector3(side * 0.34, 0.35, 0), steel)
	for k: int in 4:
		var beam: MeshInstance3D = Stage3D.box(n, Vector3(0.68, 0.008, 0.008), Vector3(0, 0.14 + 0.15 * float(k), 0),
			Stage3D.glow(Palette.DANGER, 3.0))
		beam.rotation.z = 0.25 * float(k % 2 * 2 - 1)
	Stage3D.box(n, Vector3(0.22, 0.12, 0.16), Vector3(0, 0.06, 0.05), _m(Palette.GOLD, 0.45, 0.3))


static func _cave(n: Node3D) -> void:
	var wood: StandardMaterial3D = _m(Color(0.42, 0.24, 0.1), 0.0, 0.7)
	var barrel: MeshInstance3D = Stage3D.cylinder(n, 0.17, 0.4, Vector3(-0.12, 0.17, 0), wood, 0.17)
	barrel.rotation.z = PI * 0.5
	for k: int in 3:
		var hoop: MeshInstance3D = Stage3D.cylinder(barrel, 0.175, 0.02, Vector3(0, -0.14 + 0.14 * float(k), 0),
			_m(Color(0.2, 0.2, 0.22), 0.45, 0.4))
		hoop.name = "hoop%d" % k
	Stage3D.box(n, Vector3(0.18, 0.12, 0.12), Vector3(0.24, 0.06, 0.08), _m(Color(0.35, 0.2, 0.08)))
	_stack(n, Vector3(0.24, 0.12, 0.08), 3, 3, 0.05)
	Stage3D.cylinder(n, 0.006, 0.6, Vector3(0.0, 0.6, -0.1), _m(Color(0.6, 0.5, 0.3)))
	Stage3D.sphere(n, 0.04, Vector3(0.3, 0.5, -0.1), Stage3D.glow(Color(1.0, 0.6, 0.2), 2.0))


static func _tower(n: Node3D) -> void:
	var w: float = 0.36
	for k: int in 7:
		var b: MeshInstance3D = Stage3D.box(n, Vector3(w, 0.05, 0.12), Vector3(0.02 * float(k % 3 - 1), 0.025 + 0.055 * float(k), 0),
			_m(CHIP_COLORS[k % CHIP_COLORS.size()].darkened(0.2), 0.1, 0.45))
		Stage3D.box(b, Vector3(w, 0.008, 0.005), Vector3(0, 0, 0.062), _m(Palette.IVORY))
		w -= 0.03


static func _sort(n: Node3D) -> void:
	Stage3D.box(n, Vector3(0.8, 0.04, 0.2), Vector3(0, 0.12, -0.1), _m(Color(0.12, 0.12, 0.14), 0.0, 0.8))
	for k: int in 3:
		Stage3D.cylinder(n, 0.1, 0.04, Vector3(-0.25 + 0.25 * float(k), 0.02, 0.18), _m(CHIP_COLORS[k].darkened(0.3), 0.1, 0.5))
		var chip: Node3D = CasinoChip3D.build(n, CHIP_COLORS[k], 0.06)
		chip.position = Vector3(-0.25 + 0.25 * float(k), 0.16, -0.1)
		chip.rotation.x = PI * 0.5


# --------------------------------------------------------------------------- le Cabaret


## Plancher de scène miniature : planches, nez doré (socle commun du Cabaret).
static func _boards(n: Node3D, w: float = 0.6) -> void:
	for k: int in 4:
		var col: Color = Color("4a2a16") if k % 2 == 0 else Color("3e2412")
		Stage3D.box(n, Vector3(w, 0.03, 0.12), Vector3(0, 0.015, -0.18 + 0.12 * float(k)), _m(col, 0.0, 0.45))
	Stage3D.box(n, Vector3(w, 0.012, 0.02), Vector3(0, 0.03, 0.25), _m(Palette.GOLD, 0.7, 0.3))


static func _tapdance(n: Node3D) -> void:
	_boards(n)
	# Paire de souliers à claquettes vernis, plaques de métal à la pointe et au talon.
	var patent: StandardMaterial3D = _m(Color("0c0a0e"), 0.3, 0.12)
	var steel: StandardMaterial3D = _m(Color("c8ccd8"), 0.9, 0.2)
	for sx: float in [-0.09, 0.09]:
		var shoe: Node3D = Node3D.new()
		shoe.position = Vector3(sx, 0.03, 0.0)
		shoe.rotation.y = sx * 2.0
		n.add_child(shoe)
		Stage3D.box(shoe, Vector3(0.09, 0.06, 0.24), Vector3(0, 0.04, 0), patent)
		Stage3D.box(shoe, Vector3(0.085, 0.05, 0.08), Vector3(0, 0.09, -0.07), patent)
		Stage3D.box(shoe, Vector3(0.08, 0.01, 0.07), Vector3(0, 0.005, 0.08), steel)
		Stage3D.box(shoe, Vector3(0.07, 0.01, 0.05), Vector3(0, 0.005, -0.09), steel)
		Stage3D.sphere(shoe, 0.018, Vector3(0, 0.08, 0.04), _m(Palette.ROULETTE_RED, 0.0, 0.4))
	Stage3D.cylinder(n, 0.03, 0.02, Vector3(0.2, 0.04, 0.12), _m(Palette.GOLD, 0.8, 0.25))


static func _spotlight(n: Node3D) -> void:
	_boards(n)
	# Projecteur de poursuite sur pied : fût laqué, lentille allumée, poignée.
	Stage3D.cylinder(n, 0.12, 0.02, Vector3(0, 0.04, -0.05), _m(Color("15151a"), 0.5, 0.4))
	Stage3D.cylinder(n, 0.015, 0.36, Vector3(0, 0.22, -0.05), _m(Palette.GOLD, 0.8, 0.3))
	var head: Node3D = Node3D.new()
	head.position = Vector3(0, 0.44, -0.05)
	head.rotation.x = -0.45
	n.add_child(head)
	var barrel: MeshInstance3D = Stage3D.cylinder(head, 0.09, 0.34, Vector3.ZERO, _m(Color("1a1a22"), 0.6, 0.3), 0.07)
	barrel.rotation.x = PI * 0.5
	var lens: MeshInstance3D = Stage3D.cylinder(head, 0.07, 0.01, Vector3(0, 0, 0.17), Stage3D.glow(Color(1.0, 0.92, 0.7), 3.0))
	lens.rotation.x = PI * 0.5
	Stage3D.box(head, Vector3(0.02, 0.02, 0.14), Vector3(0.0, 0.1, -0.08), _m(Palette.GOLD, 0.8, 0.3))
	Stage3D.omni(n, Color(1.0, 0.9, 0.7), 0.6, Vector3(0, 0.3, 0.3), 1.0)


static func _tightrope(n: Node3D) -> void:
	# Deux mâts de laiton, le fil, et le funambule de fer-blanc avec sa perche.
	var brass: StandardMaterial3D = _m(Palette.GOLD, 0.8, 0.28)
	for sx: float in [-0.3, 0.3]:
		Stage3D.cylinder(n, 0.012, 0.5, Vector3(sx, 0.25, 0), brass)
		Stage3D.sphere(n, 0.02, Vector3(sx, 0.51, 0), brass)
	var wire: MeshInstance3D = Stage3D.cylinder(n, 0.003, 0.6, Vector3(0, 0.45, 0), _m(Color("c8ccd8"), 0.9, 0.2))
	wire.rotation.z = PI * 0.5
	var fig: Figure3D = Figure3D.new().build(0.22, {"coat": Color("f0ece0"), "trousers": Color("f0ece0"), "trim": Color("ff2e88"), "hat": ""})
	fig.position = Vector3(0.05, 0.45, 0)
	fig.rotation.z = -0.12
	n.add_child(fig)
	fig.animate(&"balance", 0.0, 1.0, 0.3)
	var pole: MeshInstance3D = Stage3D.cylinder(n, 0.004, 0.36, Vector3(0.05, 0.6, 0.03), _m(Color("8a5a2a"), 0.0, 0.5))
	pole.rotation.z = PI * 0.5 + 0.2
	Stage3D.cylinder(n, 0.2, 0.02, Vector3(0, 0.01, 0), _m(Palette.VELVET, 0.0, 0.8))


static func _hattoss(n: Node3D) -> void:
	_boards(n)
	# Portemanteau de bois tourné, un haut-de-forme accroché, un autre en vol.
	var wood: StandardMaterial3D = _m(Color("3a2010"), 0.0, 0.45)
	Stage3D.cylinder(n, 0.1, 0.02, Vector3(0.1, 0.04, 0), wood, 0.07)
	Stage3D.cylinder(n, 0.014, 0.5, Vector3(0.1, 0.29, 0), wood)
	Stage3D.sphere(n, 0.025, Vector3(0.1, 0.55, 0), _m(Palette.GOLD, 0.8, 0.25))
	_hat(n, Vector3(0.12, 0.49, 0.02), Vector3(0, 0, 0.3))
	_hat(n, Vector3(-0.18, 0.42, 0.05), Vector3(0.4, 0.6, -0.5))


static func _hat(n: Node3D, at: Vector3, rot: Vector3) -> void:
	var h: Node3D = Node3D.new()
	h.position = at
	h.rotation = rot
	n.add_child(h)
	var felt: StandardMaterial3D = _m(Color("101014"), 0.1, 0.35)
	Stage3D.cylinder(h, 0.075, 0.008, Vector3.ZERO, felt)
	Stage3D.cylinder(h, 0.045, 0.09, Vector3(0, 0.045, 0), felt)
	Stage3D.cylinder(h, 0.046, 0.016, Vector3(0, 0.014, 0), _m(Palette.ROULETTE_RED, 0.0, 0.5))


static func _mentalist(n: Node3D) -> void:
	# Guéridon drapé, boule de cristal qui luit, trois jetons alignés devant.
	Stage3D.cylinder(n, 0.2, 0.26, Vector3(0, 0.13, 0), _m(Color("3a0a4a"), 0.0, 0.8), 0.16)
	Stage3D.cylinder(n, 0.21, 0.012, Vector3(0, 0.265, 0), _m(Palette.GOLD, 0.7, 0.3))
	Stage3D.cylinder(n, 0.04, 0.04, Vector3(0, 0.29, 0), _m(Palette.GOLD, 0.8, 0.25), 0.06)
	var ball: StandardMaterial3D = Stage3D.glow(Color(0.55, 0.3, 1.0), 1.5)
	ball.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ball.albedo_color.a = 0.7
	Stage3D.sphere(n, 0.09, Vector3(0, 0.39, 0), ball)
	Stage3D.omni(n, Color(0.6, 0.35, 1.0), 0.8, Vector3(0, 0.45, 0.15), 1.0)
	var cols: Array[Color] = [Color("ffd23f"), Color("2ee6a8"), Color("b03aff")]
	for k: int in 3:
		var c: Node3D = CasinoChip3D.build(n, cols[k], 0.04)
		c.position = Vector3(-0.09 + 0.09 * float(k), 0.31, 0.15)

