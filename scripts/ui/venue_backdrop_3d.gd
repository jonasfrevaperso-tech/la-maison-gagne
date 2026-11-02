class_name VenueBackdrop3D
extends Stage3D
## Décors 3D plein écran derrière les menus, dans la même salle abandonnée que l'écran titre :
##   « bazaar »  : l'arrière-boutique du Bazar (étagères de bric-à-brac, ampoules qui se
##                 balancent, caisse enregistreuse, enseigne néon) — boutique ;
##   « victory » : la table du triomphe (tours de jetons, champagne, confettis dorés, projecteurs) ;
##   « defeat »  : la table désertée (une lampe qui se balance, jetons épars, verre renversé).
## Hasard décoratif à graine fixe ; caméra en lent travelling. Purement cosmétique.

const DUST: int = 50
const CONFETTI: int = 90
const BULBS: int = 5

var mood: String = "bazaar"
var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _swing: Array[Node3D] = []
var _bulb_mats: Array[StandardMaterial3D] = []
var _sign: Label3D = null
var _sign_light: OmniLight3D = null
var _dust: Array[MeshInstance3D] = []
var _confetti: Array[MeshInstance3D] = []
var _confetti_v: Array[Vector3] = []
var _spots: Array[SpotLight3D] = []
var _cam_from: Vector3 = Vector3(0, 2.2, 6.5)
var _cam_to: Vector3 = Vector3(0.6, 2.0, 6.0)
var _look: Vector3 = Vector3(0, 1.4, 0)


static func create(p_mood: String) -> Control:
	if not Settings.b("video", "wheel_3d"):
		return DecoBackground.new()
	var b: VenueBackdrop3D = VenueBackdrop3D.new()
	b.mood = p_mood
	return b


func _ready() -> void:
	super._ready()
	_rng.seed = 1987
	env.fog_enabled = true
	env.fog_density = 0.035
	key.light_energy = 0.2
	match mood:
		"victory":
			_build_room(Color(0.22, 0.12, 0.08))
			_build_victory()
		"defeat":
			_build_room(Color(0.1, 0.08, 0.12))
			_build_defeat()
		_:
			_build_room(Color(0.16, 0.1, 0.08))
			_build_bazaar()
	_build_dust()
	look(_cam_from, _look, 42.0)


# --------------------------------------------------------------------------- pièces communes


func _build_room(fog: Color) -> void:
	env.background_color = Color(0.02, 0.015, 0.02)
	env.fog_light_color = fog
	var carpet: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.95)
	carpet.albedo_texture = SlotCabinet3D.carpet_texture()
	carpet.uv1_scale = Vector3(12, 12, 1)
	carpet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	Stage3D.box(root, Vector3(30, 0.1, 30), Vector3(0, -0.05, 0), carpet)
	var wall: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.9)
	wall.albedo_texture = SlotCabinet3D.wall_texture()
	wall.uv1_scale = Vector3(10, 2, 1)
	Stage3D.box(root, Vector3(30, 8, 0.2), Vector3(0, 4, -3.0), wall)


func _build_dust() -> void:
	var m: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.92, 0.75), 0.5)
	for k: int in DUST:
		_dust.append(Stage3D.sphere(root, 0.011, _dust_spot(), m))


func _dust_spot() -> Vector3:
	return Vector3(_rng.randf_range(-5.0, 5.0), _rng.randf_range(0.2, 4.5), _rng.randf_range(-2.0, 4.0))


func _bulb(at: Vector3, col: Color) -> void:
	var pivot: Node3D = Node3D.new()
	pivot.position = at
	root.add_child(pivot)
	Stage3D.cylinder(pivot, 0.008, 1.2, Vector3(0, -0.6, 0), Stage3D.mat(Palette.INK))
	var m: StandardMaterial3D = Stage3D.glow(col, 3.0)
	_bulb_mats.append(m)
	Stage3D.sphere(pivot, 0.07, Vector3(0, -1.25, 0), m)
	Stage3D.cylinder(pivot, 0.035, 0.08, Vector3(0, -1.16, 0), Stage3D.mat(Palette.GOLD_DARK, 0.8, 0.3))
	Stage3D.omni(pivot, col, 1.3, Vector3(0, -1.3, 0), 4.0)
	pivot.set_meta("phase", _rng.randf() * TAU)
	_swing.append(pivot)


func _neon(txt: String, at: Vector3, col: Color, px: int) -> void:
	_sign = Stage3D.text3d(root, txt, at, px, col, col.darkened(0.7))
	_sign_light = Stage3D.omni(root, col, 1.6, at + Vector3(0, -0.1, 0.8), 6.0)


# --------------------------------------------------------------------------- bazar


func _build_bazaar() -> void:
	var wood: StandardMaterial3D = Stage3D.mat(Color(0.3, 0.17, 0.08), 0.0, 0.7)
	var dark_wood: StandardMaterial3D = Stage3D.mat(Color(0.18, 0.1, 0.05), 0.0, 0.75)
	# Étagères sur toute la largeur, chargées de bric-à-brac.
	for lvl: int in 3:
		var y: float = 0.9 + 1.0 * float(lvl)
		Stage3D.box(root, Vector3(11.0, 0.06, 0.55), Vector3(0, y, -2.6), wood)
		var x: float = -5.2
		while x < 5.2:
			x += _rng.randf_range(0.25, 0.5)
			_junk(Vector3(x, y + 0.03, -2.6 + _rng.randf_range(-0.12, 0.12)))
	for x2: float in [-5.4, -1.8, 1.8, 5.4]:
		Stage3D.box(root, Vector3(0.08, 3.2, 0.55), Vector3(x2, 1.9, -2.6), dark_wood)
	# Comptoir et caisse enregistreuse au premier plan, à gauche.
	Stage3D.box(root, Vector3(3.6, 1.0, 0.9), Vector3(-3.2, 0.5, 1.1), dark_wood)
	Stage3D.box(root, Vector3(3.7, 0.06, 1.0), Vector3(-3.2, 1.03, 1.1), wood)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.85, 0.3)
	var till: Node3D = Node3D.new()
	till.position = Vector3(-3.6, 1.06, 1.1)
	till.rotation.y = 0.4
	root.add_child(till)
	Stage3D.box(till, Vector3(0.7, 0.35, 0.5), Vector3(0, 0.18, 0), brass)
	Stage3D.box(till, Vector3(0.6, 0.25, 0.08), Vector3(0, 0.45, -0.18), brass).rotation.x = -0.4
	for k: int in 6:
		Stage3D.cylinder(till, 0.03, 0.04, Vector3(-0.22 + 0.09 * float(k), 0.38, 0.12), Stage3D.mat(Palette.IVORY))
	Stage3D.text3d(till, "8,00", Vector3(0, 0.5, -0.13), 60, Palette.EMERALD).rotation.x = -0.4
	# Mannequin-présentoir à droite : tête de bois coiffée d'un haut-de-forme.
	var stand: Node3D = Node3D.new()
	stand.position = Vector3(3.6, 0, 0.8)
	root.add_child(stand)
	Stage3D.cylinder(stand, 0.04, 1.5, Vector3(0, 0.75, 0), dark_wood)
	Stage3D.sphere(stand, 0.2, Vector3(0, 1.65, 0), wood)
	Stage3D.cylinder(stand, 0.28, 0.03, Vector3(0, 1.82, 0), Stage3D.mat(Palette.INK, 0.0, 0.5))
	Stage3D.cylinder(stand, 0.16, 0.32, Vector3(0, 1.99, 0), Stage3D.mat(Palette.INK, 0.0, 0.5))
	Stage3D.cylinder(stand, 0.165, 0.05, Vector3(0, 1.88, 0), Stage3D.mat(Palette.ROULETTE_RED))
	for k2: int in BULBS:
		_bulb(Vector3(-4.0 + 2.0 * float(k2), 4.6, -0.6 + 0.4 * float(k2 % 2)), Color(1.0, 0.75, 0.42))
	_neon("BAZAR", Vector3(2.8, 3.95, -2.45), Palette.CYAN, 170)
	_cam_from = Vector3(-0.8, 2.3, 6.4)
	_cam_to = Vector3(0.9, 2.1, 5.8)
	_look = Vector3(0, 1.8, -1.0)


## Un objet de brocante au hasard : flacon, boîte, globe, pendule, vase.
func _junk(at: Vector3) -> void:
	var cols: Array[Color] = [
		Color(0.45, 0.25, 0.08), Color(0.13, 0.4, 0.18), Palette.ROULETTE_RED.darkened(0.3), Palette.GOLD_DARK, Color(0.2, 0.3, 0.5)
	]
	var col: Color = cols[_rng.randi_range(0, cols.size() - 1)]
	match _rng.randi_range(0, 4):
		0:
			var h: float = _rng.randf_range(0.2, 0.4)
			Stage3D.cylinder(root, 0.05, h, at + Vector3(0, h * 0.5, 0), Stage3D.mat(col, 0.2, 0.15))
			Stage3D.cylinder(root, 0.018, 0.1, at + Vector3(0, h + 0.05, 0), Stage3D.mat(col, 0.2, 0.15))
		1:
			var s: float = _rng.randf_range(0.14, 0.26)
			Stage3D.box(root, Vector3(s, s * 0.8, s), at + Vector3(0, s * 0.4, 0), Stage3D.mat(col.darkened(0.2), 0.0, 0.8)).rotation.y = (
				_rng.randf_range(-0.4, 0.4)
			)
		2:
			Stage3D.sphere(root, 0.12, at + Vector3(0, 0.15, 0), Stage3D.mat(Color(0.2, 0.4, 0.6), 0.3, 0.3))
			Stage3D.cylinder(root, 0.05, 0.04, at + Vector3(0, 0.02, 0), Stage3D.mat(Palette.GOLD_DARK, 0.8, 0.3))
		3:
			var face: MeshInstance3D = Stage3D.cylinder(root, 0.13, 0.05, at + Vector3(0, 0.15, 0), Stage3D.mat(Palette.IVORY, 0.0, 0.6))
			face.rotation.x = PI * 0.5
			Stage3D.box(root, Vector3(0.012, 0.09, 0.01), at + Vector3(0, 0.18, 0.03), Stage3D.mat(Palette.INK))
		_:
			Stage3D.cylinder(root, 0.07, 0.28, at + Vector3(0, 0.14, 0), Stage3D.mat(col, 0.1, 0.35), 0.04)


# --------------------------------------------------------------------------- victoire / défaite


func _table(at: Vector3) -> void:
	var felt: StandardMaterial3D = Stage3D.mat(Palette.FELT.lightened(0.1), 0.0, 0.95)
	Stage3D.box(root, Vector3(4.6, 0.12, 2.4), at + Vector3(0, 0.9, 0), felt)
	Stage3D.box(root, Vector3(4.8, 0.16, 2.6), at + Vector3(0, 0.8, 0), Stage3D.mat(Color(0.3, 0.12, 0.06), 0.0, 0.45))
	for sx: float in [-2.0, 2.0]:
		for sz: float in [-0.9, 0.9]:
			Stage3D.cylinder(root, 0.08, 0.8, at + Vector3(sx, 0.4, sz), Stage3D.mat(Color(0.2, 0.1, 0.05), 0.0, 0.6))


func _chip_pile(at: Vector3, n: int, col: Color) -> void:
	var m: StandardMaterial3D = Stage3D.mat(col, 0.0, 0.35)
	var edge: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.4)
	for k: int in n:
		var y: float = 0.02 + 0.042 * float(k)
		Stage3D.cylinder(root, 0.12, 0.04, at + Vector3(_rng.randf_range(-0.006, 0.006), y, 0), m)
		if k % 2 == 0:
			Stage3D.cylinder(root, 0.122, 0.012, at + Vector3(0, y, 0), edge)


func _build_victory() -> void:
	_table(Vector3(0, 0, 0.4))
	var cols: Array[Color] = [Palette.ROULETTE_RED, Palette.CHIPS_BLUE, Palette.EMERALD, Palette.GOLD, Palette.MAGENTA]
	for k: int in 9:
		_chip_pile(Vector3(-1.8 + 0.45 * float(k), 0.96, 0.2 + 0.35 * float(k % 2)), 6 + (k * 7) % 11, cols[k % cols.size()])
	# Champagne : bouteille dans son seau, coupes.
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.95, 1.0, 0.35), 0.1, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var bottle: StandardMaterial3D = Stage3D.mat(Color(0.08, 0.22, 0.12), 0.3, 0.15)
	Stage3D.cylinder(root, 0.22, 0.4, Vector3(1.7, 1.16, 1.0), Stage3D.mat(Palette.GOLD_LIGHT, 0.9, 0.25), 0.26)
	var b: MeshInstance3D = Stage3D.cylinder(root, 0.09, 0.55, Vector3(1.7, 1.45, 1.0), bottle)
	b.rotation.z = -0.25
	for k2: int in 3:
		var gx: float = 0.6 + 0.35 * float(k2)
		Stage3D.cylinder(root, 0.015, 0.18, Vector3(gx, 1.05, 1.25), glass)
		Stage3D.cylinder(root, 0.08, 0.06, Vector3(gx, 1.17, 1.25), glass, 0.1)
		Stage3D.cylinder(root, 0.07, 0.03, Vector3(gx, 1.18, 1.25), Stage3D.glow(Palette.GOLD_LIGHT, 0.8))
	# Projecteurs qui balaient, confettis dorés.
	for k3: int in 2:
		var sp: SpotLight3D = SpotLight3D.new()
		sp.light_color = Palette.GOLD_LIGHT if k3 == 0 else Palette.MAGENTA
		sp.light_energy = 7.0
		sp.spot_range = 14.0
		sp.spot_angle = 16.0
		sp.position = Vector3(-4.0 + 8.0 * float(k3), 5.0, 3.0)
		root.add_child(sp)
		_spots.append(sp)
	var conf_cols: Array[Color] = [Palette.GOLD_LIGHT, Palette.GOLD, Palette.IVORY, Palette.MAGENTA, Palette.CYAN]
	for k4: int in CONFETTI:
		var m: StandardMaterial3D = Stage3D.glow(conf_cols[k4 % conf_cols.size()], 0.6)
		var c: MeshInstance3D = Stage3D.box(root, Vector3(0.05, 0.03, 0.005), _confetti_spot(true), m)
		_confetti.append(c)
		_confetti_v.append(Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.9, -0.5), _rng.randf_range(-3.0, 3.0)))
	_neon("JACKPOT", Vector3(0, 3.6, -2.85), Palette.GOLD_LIGHT, 220)
	_cam_from = Vector3(-1.2, 2.6, 5.6)
	_cam_to = Vector3(1.2, 2.3, 5.2)
	_look = Vector3(0, 1.3, 0)


func _confetti_spot(anywhere: bool) -> Vector3:
	return Vector3(_rng.randf_range(-4.5, 4.5), _rng.randf_range(0.5, 5.0) if anywhere else 5.0, _rng.randf_range(-1.5, 3.0))


func _build_defeat() -> void:
	_table(Vector3(0, 0, 0.4))
	var cols: Array[Color] = [Palette.ROULETTE_RED, Palette.CHIPS_BLUE, Palette.IVORY]
	for k: int in 14:
		var at: Vector3 = Vector3(_rng.randf_range(-2.0, 2.0), 0.975, _rng.randf_range(-0.6, 1.4))
		var chip: MeshInstance3D = Stage3D.cylinder(root, 0.12, 0.04, at, Stage3D.mat(cols[k % cols.size()], 0.0, 0.4))
		chip.rotation = Vector3(_rng.randf_range(-0.15, 0.15), 0, _rng.randf_range(-0.15, 0.15))
	for k2: int in 6:
		var at2: Vector3 = Vector3(_rng.randf_range(-4.0, 4.0), 0.02, _rng.randf_range(-1.0, 3.0))
		Stage3D.cylinder(root, 0.12, 0.04, at2, Stage3D.mat(cols[k2 % cols.size()], 0.0, 0.4))
	# Verre renversé et reconnaissances de dette froissées.
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.95, 1.0, 0.35), 0.1, 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var g: MeshInstance3D = Stage3D.cylinder(root, 0.08, 0.22, Vector3(1.3, 1.04, 0.9), glass, 0.1)
	g.rotation.z = PI * 0.5
	Stage3D.cylinder(root, 0.3, 0.004, Vector3(1.0, 0.965, 0.9), Stage3D.mat(Color(0.5, 0.3, 0.1, 0.6), 0.0, 0.1))
	for k3: int in 5:
		var paper_at: Vector3 = Vector3(_rng.randf_range(-1.8, 0.5), 0.97, _rng.randf_range(-0.4, 1.2))
		var paper: MeshInstance3D = Stage3D.box(root, Vector3(0.3, 0.005, 0.2), paper_at, Stage3D.mat(Palette.IVORY, 0.0, 0.9))
		paper.rotation.y = _rng.randf_range(-1.0, 1.0)
		Stage3D.text3d(paper, "IOU", Vector3(0, 0.004, 0), 36, Palette.ROULETTE_RED).rotation.x = -PI * 0.5
	_bulb(Vector3(0, 4.6, 0.4), Color(1.0, 0.7, 0.4))
	_neon("RIEN NE VA PLUS", Vector3(-1.6, 3.5, -2.85), Palette.ROULETTE_RED, 120)
	_cam_from = Vector3(-1.5, 2.8, 5.4)
	_cam_to = Vector3(0.8, 2.5, 5.0)
	_look = Vector3(0, 1.0, 0.2)


# --------------------------------------------------------------------------- vie


func _process(delta: float) -> void:
	_t += delta
	var u: float = 0.5 - 0.5 * cos(_t * TAU / 30.0)
	look(_cam_from.lerp(_cam_to, u), _look + Vector3(0, sin(_t * 0.3) * 0.05, 0), 42.0)
	for p: Node3D in _swing:
		var ph: float = float(p.get_meta("phase", 0.0))
		p.rotation.z = sin(_t * 0.9 + ph) * (0.18 if mood == "defeat" else 0.06)
	if _sign != null:
		var flick: float = 1.0 if fposmod(_t * 3.1, 6.1) > 0.22 and fposmod(_t * 9.0, 7.3) > 0.12 else 0.25
		_sign.modulate = Color(_sign.modulate, flick)
		_sign_light.light_energy = 1.6 * flick
	for k: int in _spots.size():
		_spots[k].look_at(Vector3(sin(_t * 0.5 + float(k) * 2.0) * 3.0, 0.9, cos(_t * 0.4 + float(k)) * 1.0), Vector3.UP)
	for k2: int in _confetti.size():
		var c: MeshInstance3D = _confetti[k2]
		var v: Vector3 = _confetti_v[k2]
		c.position += Vector3(v.x + sin(_t * 2.0 + float(k2)) * 0.15, v.y, 0.0) * delta
		c.rotation += Vector3(v.z, v.z * 0.7, 0.0) * delta
		if c.position.y < 0.05:
			c.position = _confetti_spot(false)
	for k3: int in _dust.size():
		var d: MeshInstance3D = _dust[k3]
		d.position += Vector3(sin(_t * 0.4 + float(k3)) * 0.02, -0.03, 0.0) * delta
		if d.position.y < 0.15:
			d.position = _dust_spot()
			d.position.y = 4.5
