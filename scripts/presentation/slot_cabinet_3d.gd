class_name SlotCabinet3D
extends Node3D
## Lucette, la machine à sous du Grand Zéro, en 3D : caisson laqué rouge et laiton, fronton
## lumineux, quatre rouleaux (tambours garnis des symboles pixel art), levier, bac à pièces,
## yeux qui suivent les rouleaux. Autour : la salle des machines abandonnée (moquette de casino,
## papier peint, néon, machines voisines éteintes, tabourets). Purement cosmétique : la
## surcouche pilote les angles des rouleaux, le levier, les ampoules et les pièces.

const REELS: int = 4
const CELLS: int = 12
const REEL_R: float = 0.28
const REEL_W: float = 0.24
const REEL_GAP: float = 0.045
const REEL_Y: float = 1.52
const REEL_Z: float = 0.05
const BULBS_TOP: int = 15
const BULBS_SIDE: int = 7
const COIN_R: float = 0.035
const TRAY_Y: float = 0.98
const TRAY_Z: float = 0.52
const TRAY_MAX: int = 90
const LACQUER: Color = Color("7a1024")
const LACQUER_DARK: Color = Color("3c0712")
const BRASS: Color = Color("d4af37")

## Symbole de chaque case de chaque rouleau (ids de data/slots).
var strips: Array[Array] = []
var _reels: Array[Node3D] = []
var _bulbs: Array[MeshInstance3D] = []
var _bulb_on: StandardMaterial3D = null
var _bulb_off: StandardMaterial3D = null
var _bulb_alt: StandardMaterial3D = null
var _lever: Node3D = null
var _pupils: Array[MeshInstance3D] = []
var _lids: Array[MeshInstance3D] = []
var _coins: Array[MeshInstance3D] = []
var _falling: Array[Dictionary] = []
var _coin_mat: StandardMaterial3D = null
var _marquee: Label3D = null
var _neon: OmniLight3D = null
var _win_light: OmniLight3D = null
var _textures: Dictionary[String, Texture2D] = {}


func build(symbol_ids: Array[String], rng: RandomNumberGenerator) -> void:
	_bulb_on = Stage3D.glow(Color("ffe9a0"), 4.0)
	_bulb_alt = Stage3D.glow(Palette.MAGENTA, 3.0)
	_bulb_off = Stage3D.mat(Color("5a4a30"), 0.2, 0.5)
	_coin_mat = Stage3D.mat(BRASS, 0.9, 0.25)
	_build_room(rng)
	_build_cabinet(Vector3.ZERO, true)
	for k: int in REELS:
		var strip: Array[String] = []
		for c: int in CELLS:
			strip.append(symbol_ids[(c + k * 3) % symbol_ids.size()])
		# Mélange cosmétique : chaque rouleau a son ordre.
		for i: int in range(strip.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: String = strip[i]
			strip[i] = strip[j]
			strip[j] = tmp
		strips.append(strip)
		_build_reel(k, strip)


## Case où s'arrêter pour afficher `symbol` au centre (le plus proche après `from`).
func cell_for(k: int, symbol: String, from: float) -> int:
	var strip: Array = strips[k]
	var base: int = int(floor(from))
	for step: int in range(0, CELLS * 2):
		var c: int = base + step
		if String(strip[posmod(c, CELLS)]) == symbol and float(c) >= from:
			return c
	return base


## Position du rouleau en cases (fractionnaire) : la case entière n est centrée sur la ligne.
func set_reel(k: int, pos: float) -> void:
	_reels[k].rotation.x = pos * TAU / float(CELLS)


func reel_center(k: int) -> Vector3:
	return Vector3(_reel_x(k), REEL_Y, REEL_Z + REEL_R)


func lever(t: float) -> void:
	_lever.rotation.x = -t * deg_to_rad(95.0)


## Ampoules : chenillard (phase), `win` 0–1 = tout clignote en rythme.
func bulbs(phase: float, win: float) -> void:
	var n: int = _bulbs.size()
	for i: int in n:
		var on: bool
		if win > 0.0:
			on = int(phase * 2.0) % 2 == i % 2
		else:
			on = (i + int(phase)) % 5 < 2
		_bulbs[i].material_override = (_bulb_alt if win > 0.0 and i % 3 == 0 else _bulb_on) if on else _bulb_off
	if win <= 0.0:
		_marquee.modulate = Palette.GOLD_LIGHT.lerp(Color.WHITE, 0.5 + 0.5 * sin(phase * 1.3))
	else:
		_marquee.modulate = Palette.MAGENTA.lerp(Palette.GOLD_LIGHT, float(int(phase * 3.0) % 2))
	_win_light.light_energy = 0.3 + 0.9 * win
	_neon.light_energy = 1.4 + 0.25 * sin(phase * 7.0) + (0.6 if RngService.cosmetic().randf() < 0.02 else 0.0)


## Yeux de Lucette : regard horizontal (-1..1), paupières fermées (clin d'œil) ou ravies.
func eyes(look: float, closed: bool) -> void:
	for i: int in _pupils.size():
		_pupils[i].position.x = (-0.25 if i == 0 else 0.25) + clampf(look, -1.0, 1.0) * 0.035
		_lids[i].visible = closed


## Pièces qui tombent de la goulotte dans le bac et s'y entassent.
func drop_coins(n: int, rng: RandomNumberGenerator) -> void:
	for i: int in n:
		var at: Vector3 = Vector3(rng.randf_range(-0.08, 0.08), TRAY_Y + 0.14 + 0.04 * float(i), TRAY_Z - 0.05)
		var c: MeshInstance3D = Stage3D.cylinder(self, COIN_R, 0.012, at, _coin_mat)
		c.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		_falling.append({"m": c, "v": Vector3(rng.randf_range(-0.6, 0.6), 0.0, rng.randf_range(0.0, 0.25)), "spin": rng.randf_range(4.0, 12.0)})


func _process(delta: float) -> void:
	var still: Array[Dictionary] = []
	for f: Dictionary in _falling:
		var m: MeshInstance3D = f["m"]
		var v: Vector3 = f["v"]
		v.y -= 9.8 * delta
		m.position += v * delta
		m.rotation.x += float(f["spin"]) * delta
		var floor_y: float = TRAY_Y + 0.012 + 0.006 * float(_coins.size() % 6)
		if m.position.y <= floor_y and absf(m.position.x) < 0.42:
			m.position.y = floor_y
			var r: RandomNumberGenerator = RngService.cosmetic()
			m.rotation = Vector3(r.randf_range(-0.2, 0.2), r.randf_range(0, TAU), r.randf_range(-0.2, 0.2))
			m.position.x = clampf(m.position.x, -0.4, 0.4)
			m.position.z = clampf(m.position.z, TRAY_Z - 0.1, TRAY_Z + 0.08)
			_coins.append(m)
			if _coins.size() > TRAY_MAX:
				_coins.pop_front().queue_free()
			AudioBus.play("coin", r.randf_range(0.9, 1.3), -14.0)
			continue
		f["v"] = v
		still.append(f)
	_falling = still


# --------------------------------------------------------------------------- construction


func _reel_x(k: int) -> float:
	var total: float = float(REELS) * REEL_W + float(REELS - 1) * REEL_GAP
	return -total * 0.5 + REEL_W * 0.5 + float(k) * (REEL_W + REEL_GAP)


func _build_reel(k: int, strip: Array[String]) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3(_reel_x(k), REEL_Y, REEL_Z)
	add_child(pivot)
	_reels.append(pivot)
	var drum: MeshInstance3D = Stage3D.cylinder(pivot, REEL_R * 0.985, REEL_W, Vector3.ZERO, Stage3D.mat(Palette.IVORY, 0.0, 0.85))
	drum.rotation.z = PI * 0.5
	for c: int in CELLS:
		var a: float = float(c) * TAU / float(CELLS)
		var s: Sprite3D = Sprite3D.new()
		s.texture = _symbol(String(strip[c]))
		s.pixel_size = 0.0022
		s.shaded = true
		s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		s.position = Vector3(0, REEL_R * sin(a), REEL_R * cos(a))
		s.rotation.x = -a
		pivot.add_child(s)
		# Fine séparation entre deux cases.
		var b: float = a + PI / float(CELLS)
		var sep_at: Vector3 = Vector3(0, REEL_R * sin(b), REEL_R * cos(b))
		var sep: MeshInstance3D = Stage3D.box(pivot, Vector3(REEL_W * 0.9, 0.004, 0.004), sep_at, Stage3D.mat(Palette.SMOKE))
		sep.rotation.x = -b


func _symbol(id: String) -> Texture2D:
	if not _textures.has(id):
		_textures[id] = load("res://assets/slot/slot_%s.png" % id) as Texture2D
	return _textures[id]


func _build_cabinet(at: Vector3, hero: bool) -> void:
	var lac: StandardMaterial3D = Stage3D.mat(LACQUER if hero else LACQUER_DARK, 0.25, 0.32)
	var dark: StandardMaterial3D = Stage3D.mat(Color("140308"), 0.0, 0.9)
	var brass: StandardMaterial3D = Stage3D.mat(BRASS if hero else Color("6e5a20"), 0.85, 0.3)
	var chrome: StandardMaterial3D = Stage3D.mat(Color("c9ccd4"), 0.95, 0.18)
	var n: Node3D = Node3D.new()
	n.position = at
	add_child(n)
	# Socle, flancs, dos, chapeau.
	Stage3D.box(n, Vector3(1.56, 0.92, 0.95), Vector3(0, 0.46, 0.0), lac)
	Stage3D.box(n, Vector3(1.6, 0.06, 1.0), Vector3(0, 0.93, 0.0), brass)
	Stage3D.box(n, Vector3(0.08, 1.4, 0.95), Vector3(-0.76, 1.62, 0.0), lac)
	Stage3D.box(n, Vector3(0.08, 1.4, 0.95), Vector3(0.76, 1.62, 0.0), lac)
	Stage3D.box(n, Vector3(1.5, 1.4, 0.1), Vector3(0, 1.62, -0.42), dark)
	# Façade autour de la fenêtre des rouleaux.
	var win_w: float = float(REELS) * REEL_W + float(REELS - 1) * REEL_GAP + 0.08
	var side_w: float = (1.44 - win_w) * 0.5
	Stage3D.box(n, Vector3(side_w, 0.72, 0.12), Vector3(-0.72 + side_w * 0.5, REEL_Y, 0.4), lac)
	Stage3D.box(n, Vector3(side_w, 0.72, 0.12), Vector3(0.72 - side_w * 0.5, REEL_Y, 0.4), lac)
	Stage3D.box(n, Vector3(1.44, 0.22, 0.12), Vector3(0, REEL_Y + 0.47, 0.4), lac)
	Stage3D.box(n, Vector3(1.44, 0.36, 0.12), Vector3(0, REEL_Y - 0.54, 0.4), lac)
	# Cadre de laiton de la fenêtre.
	for y: float in [REEL_Y + 0.36, REEL_Y - 0.36]:
		Stage3D.box(n, Vector3(win_w + 0.06, 0.03, 0.03), Vector3(0, y, 0.47), brass)
	for x: float in [-win_w * 0.5 - 0.015, win_w * 0.5 + 0.015]:
		Stage3D.box(n, Vector3(0.03, 0.75, 0.03), Vector3(x, REEL_Y, 0.47), brass)
	# Fronton : caisson lumineux et chapeau arrondi.
	Stage3D.box(n, Vector3(1.6, 0.5, 0.9), Vector3(0, 2.57, 0.0), lac)
	Stage3D.box(n, Vector3(1.36, 0.3, 0.02), Vector3(0, 2.57, 0.455), Stage3D.glow(Color("2a0410") if hero else Color("120206"), 1.0))
	var cap: MeshInstance3D = Stage3D.cylinder(n, 0.45, 1.6, Vector3(0, 2.82, 0.0), brass)
	cap.rotation.z = PI * 0.5
	cap.scale = Vector3(0.35, 1.0, 1.0)
	if not hero:
		return
	_marquee = Stage3D.text3d(n, "JACKPOT", Vector3(0, 2.57, 0.47), 120, Palette.GOLD_LIGHT, Color("5a0e1e"))
	_marquee.pixel_size = 0.0022
	# Ampoules : rangée du fronton et colonnes de part et d'autre de la fenêtre.
	for i: int in BULBS_TOP:
		var x: float = -0.7 + 1.4 * float(i) / float(BULBS_TOP - 1)
		_bulbs.append(Stage3D.sphere(n, 0.022, Vector3(x, 2.37, 0.47), _bulb_on))
		_bulbs.append(Stage3D.sphere(n, 0.022, Vector3(x, 2.78, 0.47), _bulb_on))
	for i2: int in BULBS_SIDE:
		var y: float = REEL_Y - 0.33 + 0.66 * float(i2) / float(BULBS_SIDE - 1)
		_bulbs.append(Stage3D.sphere(n, 0.02, Vector3(-0.68, y, 0.47), _bulb_on))
		_bulbs.append(Stage3D.sphere(n, 0.02, Vector3(0.68, y, 0.47), _bulb_on))
	# Ligne de gain et vitre.
	Stage3D.box(n, Vector3(win_w, 0.008, 0.008), Vector3(0, REEL_Y, REEL_Z + REEL_R + 0.03), Stage3D.glow(Palette.MULT_RED, 2.5))
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.8, 0.9, 1.0, 0.07), 0.0, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Stage3D.box(n, Vector3(win_w, 0.72, 0.01), Vector3(0, REEL_Y, 0.42), glass)
	# Ombre intérieure en haut et en bas de la fenêtre (les tambours s'enfoncent).
	var shade: StandardMaterial3D = Stage3D.mat(Color(0, 0, 0, 0.55))
	shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Stage3D.box(n, Vector3(win_w, 0.12, 0.01), Vector3(0, REEL_Y + 0.3, 0.41), shade)
	Stage3D.box(n, Vector3(win_w, 0.12, 0.01), Vector3(0, REEL_Y - 0.3, 0.41), shade)
	# Visage de Lucette sous la fenêtre : deux yeux à cils.
	for side: float in [-0.25, 0.25]:
		Stage3D.sphere(n, 0.07, Vector3(side, REEL_Y - 0.5, 0.42), Stage3D.mat(Palette.IVORY.darkened(0.15), 0.0, 0.6))
		var pupil: MeshInstance3D = Stage3D.sphere(n, 0.036, Vector3(side, REEL_Y - 0.5, 0.505), Stage3D.mat(Palette.INK))
		_pupils.append(pupil)
		var lid: MeshInstance3D = Stage3D.sphere(n, 0.074, Vector3(side, REEL_Y - 0.5, 0.425), lac)
		lid.visible = false
		_lids.append(lid)
		for j: int in 3:
			var lash_at: Vector3 = Vector3(side + (float(j) - 1.0) * 0.04, REEL_Y - 0.41, 0.47)
			var lash: MeshInstance3D = Stage3D.box(n, Vector3(0.008, 0.06, 0.008), lash_at, brass)
			lash.rotation.z = (float(j) - 1.0) * 0.5
	# Bac à pièces chromé et goulotte.
	Stage3D.box(n, Vector3(0.9, 0.04, 0.3), Vector3(0, TRAY_Y - 0.02, TRAY_Z - 0.02), chrome)
	Stage3D.box(n, Vector3(0.9, 0.12, 0.03), Vector3(0, TRAY_Y + 0.04, TRAY_Z + 0.13), chrome)
	Stage3D.box(n, Vector3(0.2, 0.08, 0.06), Vector3(0, TRAY_Y + 0.12, 0.47), Stage3D.mat(Palette.INK))
	# Levier à droite : rotule, bras chromé, boule rouge.
	Stage3D.cylinder(n, 0.07, 0.08, Vector3(0.83, REEL_Y - 0.1, 0.2), chrome).rotation.z = PI * 0.5
	_lever = Node3D.new()
	_lever.position = Vector3(0.89, REEL_Y - 0.1, 0.2)
	n.add_child(_lever)
	Stage3D.cylinder(_lever, 0.022, 0.62, Vector3(0, 0.31, 0), chrome)
	Stage3D.sphere(_lever, 0.075, Vector3(0, 0.66, 0), Stage3D.mat(Palette.ROULETTE_RED, 0.2, 0.15))
	_win_light = Stage3D.omni(n, Palette.GOLD_LIGHT, 0.3, Vector3(0, REEL_Y + 0.9, 1.4), 3.5)
	# Table des gains au-dessus de la fenêtre : les symboles du plus banal au plus rare.
	Stage3D.box(n, Vector3(1.3, 0.2, 0.02), Vector3(0, REEL_Y + 0.47, 0.465), Stage3D.mat(Color("1a0408"), 0.0, 0.8))
	var order: Array[String] = ["lemon", "cherry", "bell", "clover", "chip", "horseshoe", "seven", "diamond"]
	for i: int in order.size():
		var sp: Sprite3D = Sprite3D.new()
		sp.texture = _symbol(order[i])
		sp.pixel_size = 0.0018
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.position = Vector3(-0.56 + 0.16 * float(i), REEL_Y + 0.47, 0.478)
		n.add_child(sp)


func _build_room(rng: RandomNumberGenerator) -> void:
	# Moquette de casino (motif procédural), mur à rayures, lambris, néon.
	var floor_m: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.95)
	floor_m.albedo_texture = carpet_texture()
	floor_m.uv1_scale = Vector3(6, 6, 1)
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(14, 10)
	var fl: MeshInstance3D = MeshInstance3D.new()
	fl.mesh = plane
	fl.material_override = floor_m
	fl.position = Vector3(0, 0, 2.0)
	add_child(fl)
	var wall_m: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.9)
	wall_m.albedo_texture = wall_texture()
	wall_m.uv1_scale = Vector3(5, 1, 1)
	var wall: MeshInstance3D = Stage3D.box(self, Vector3(14, 6, 0.1), Vector3(0, 3, -1.2), wall_m)
	wall.name = "Wall"
	Stage3D.box(self, Vector3(14, 0.9, 0.12), Vector3(0, 0.45, -1.12), Stage3D.mat(Color("2a120c"), 0.0, 0.6))
	Stage3D.box(self, Vector3(14, 0.04, 0.16), Vector3(0, 0.92, -1.1), Stage3D.mat(BRASS, 0.8, 0.3))
	var sign: Label3D = Stage3D.text3d(self, "LUCETTE", Vector3(-2.3, 2.9, -1.1), 110, Palette.MAGENTA, Color("4a0a2a"))
	sign.pixel_size = 0.003
	_neon = Stage3D.omni(self, Palette.MAGENTA, 1.4, Vector3(-2.3, 2.9, -0.7), 5.0)
	# Machines voisines, éteintes, et tabourets.
	for side: float in [-1.0, 1.0]:
		var nb: Node3D = Node3D.new()
		nb.position = Vector3(side * 2.35, 0, -0.55)
		nb.rotation.y = -side * 0.5
		nb.scale = Vector3.ONE * 0.9
		add_child(nb)
		cabinet_shell(nb)
		var stool: Node3D = Node3D.new()
		stool.position = Vector3(side * 1.9, 0, 0.9)
		add_child(stool)
		Stage3D.cylinder(stool, 0.03, 0.7, Vector3(0, 0.35, 0), Stage3D.mat(Color("8a8f99"), 0.9, 0.3))
		Stage3D.cylinder(stool, 0.2, 0.08, Vector3(0, 0.72, 0), Stage3D.mat(Palette.ROULETTE_RED.darkened(0.3), 0.0, 0.5))
		Stage3D.cylinder(stool, 0.18, 0.02, Vector3(0, 0.01, 0), Stage3D.mat(Color("8a8f99"), 0.9, 0.3))
	# Jetons et verres oubliés au sol, poussière de lumière.
	for i: int in 9:
		var chip_at: Vector3 = Vector3(rng.randf_range(-2.5, 2.5), 0.006, rng.randf_range(0.6, 2.2))
		var chip_col: Color = [Palette.ROULETTE_RED, Palette.CHIPS_BLUE, Palette.EMERALD][i % 3]
		var c: MeshInstance3D = Stage3D.cylinder(self, 0.04, 0.012, chip_at, Stage3D.mat(chip_col, 0.1, 0.5))
		c.rotation.y = rng.randf() * TAU
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = Color("ffe2b0")
	spot.light_energy = 6.0
	spot.spot_range = 7.0
	spot.spot_angle = 32.0
	spot.position = Vector3(0, 4.6, 2.2)
	add_child(spot)
	spot.look_at(Vector3(0, 1.4, 0), Vector3.UP)
	Stage3D.omni(self, Palette.CYAN, 0.6, Vector3(-3, 2.2, 0.8), 4.0)
	Stage3D.omni(self, Color("ffb070"), 0.5, Vector3(3, 2.2, 0.8), 4.0)


## Machine voisine (éteinte, plus sombre) dans un nœud donné.
static func cabinet_shell(n: Node3D) -> void:
	var lac: StandardMaterial3D = Stage3D.mat(LACQUER_DARK, 0.2, 0.4)
	var brass: StandardMaterial3D = Stage3D.mat(Color("6e5a20"), 0.8, 0.35)
	Stage3D.box(n, Vector3(1.4, 0.92, 0.9), Vector3(0, 0.46, 0), lac)
	Stage3D.box(n, Vector3(1.4, 1.4, 0.8), Vector3(0, 1.62, -0.05), lac)
	Stage3D.box(n, Vector3(1.0, 0.6, 0.02), Vector3(0, 1.55, 0.36), Stage3D.mat(Color("0c0a10"), 0.2, 0.1))
	Stage3D.box(n, Vector3(1.44, 0.45, 0.85), Vector3(0, 2.55, -0.05), lac)
	Stage3D.box(n, Vector3(1.2, 0.26, 0.02), Vector3(0, 2.55, 0.38), Stage3D.glow(Color("26060c"), 0.6))
	Stage3D.box(n, Vector3(1.44, 0.05, 0.95), Vector3(0, 0.93, 0), brass)


static func carpet_texture() -> ImageTexture:
	var s: int = 64
	var img: Image = Image.create(s, s, false, Image.FORMAT_RGB8)
	var base: Color = Color("3a0a14")
	for y: int in s:
		for x: int in s:
			var u: float = float(x) / float(s) - 0.5
			var v: float = float(y) / float(s) - 0.5
			var d: float = absf(u) + absf(v)
			var c: Color = base
			if absf(d - 0.32) < 0.035:
				c = Color("b8902a")
			elif d < 0.12:
				c = Color("0f4a46")
			elif (x + y) % 16 == 0 or absi(x - y) % 16 == 0:
				c = base.lightened(0.12)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func wall_texture() -> ImageTexture:
	var w: int = 64
	var h: int = 16
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGB8)
	for y: int in h:
		for x: int in w:
			var stripe: bool = (x >> 3) % 2 == 0
			var c: Color = Color("143326") if stripe else Color("0e261c")
			if x % 8 == 0:
				c = Color("6e5a20")
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
