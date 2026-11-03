class_name TitleHall3D
extends Stage3D
## Décor 3D de l'écran titre : la grande salle du Grand Zéro, abandonnée depuis 1987.
## Moquette et murs du casino, rangée de machines à sous éteintes, colonnes et tentures, un lustre
## qui se balance, poussière en suspension, l'enseigne « GRAND ZÉRO » qui grésille et un
## projecteur qui balaie la salle. Caméra en lent travelling. Purement cosmétique.

const CAM_FROM: Vector3 = Vector3(-1.2, 2.3, 7.4)
const CAM_TO: Vector3 = Vector3(1.4, 2.0, 6.6)
const LOOK_AT: Vector3 = Vector3(0.6, 1.5, 0.0)
const DRIFT_SECONDS: float = 26.0
const DUST: int = 70

var _t: float = 0.0
var _sign: Label3D = null
var _sign_light: OmniLight3D = null
var _sweep: SpotLight3D = null
var _chandelier: Node3D = null
var _dust: Array[MeshInstance3D] = []
var _dust_v: Array[Vector3] = []
var _bulbs: Array[StandardMaterial3D] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	super._ready()
	_rng.seed = 1987
	env.background_color = Color(0.02, 0.015, 0.025)
	env.ambient_light_energy = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.18, 0.1, 0.16)
	env.fog_density = 0.03
	key.light_energy = 0.15
	_build()
	look(CAM_FROM, LOOK_AT, 42.0)


func _build() -> void:
	var r: Node3D = root
	var carpet: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.95)
	carpet.albedo_texture = SlotCabinet3D.carpet_texture()
	carpet.uv1_scale = Vector3(14, 14, 1)
	carpet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	Stage3D.box(r, Vector3(30, 0.1, 30), Vector3(0, -0.05, 0), carpet)
	var wall: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, 0.9)
	wall.albedo_texture = SlotCabinet3D.wall_texture()
	wall.uv1_scale = Vector3(10, 2, 1)
	Stage3D.box(r, Vector3(30, 8, 0.2), Vector3(0, 4, -3.2), wall)
	# Colonnes dorées et tentures de velours entre elles.
	var gold: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.8, 0.35)
	var drape: StandardMaterial3D = Stage3D.mat(Color(0.32, 0.05, 0.1), 0.0, 0.85)
	for k: int in 7:
		var x: float = -9.0 + 3.0 * float(k)
		Stage3D.cylinder(r, 0.28, 6.0, Vector3(x, 3.0, -2.8), Stage3D.mat(Color(0.2, 0.12, 0.14), 0.2, 0.5))
		Stage3D.cylinder(r, 0.38, 0.3, Vector3(x, 0.15, -2.8), gold)
		Stage3D.cylinder(r, 0.38, 0.3, Vector3(x, 5.85, -2.8), gold)
		if k < 6:
			for f: int in 5:
				var fold: MeshInstance3D = Stage3D.box(r, Vector3(0.5, 5.2, 0.12), Vector3(x + 0.55 + 0.47 * float(f), 3.2, -2.95), drape)
				fold.rotation.y = 0.35 * (1.0 if f % 2 == 0 else -1.0)
	# Rangée de machines à sous éteintes (une seule clignote encore).
	for k: int in 5:
		var cab: Node3D = Node3D.new()
		cab.position = Vector3(-6.4 + 1.6 * float(k), 0, -1.6)
		cab.rotation.y = 0.12
		cab.scale = Vector3.ONE * 0.95
		r.add_child(cab)
		SlotCabinet3D.cabinet_shell(cab)
		var bulb: StandardMaterial3D = Stage3D.glow(Palette.GOLD_LIGHT, 0.0)
		_bulbs.append(bulb)
		for b: int in 6:
			Stage3D.sphere(cab, 0.04, Vector3(-0.5 + 0.2 * float(b), 2.85, 0.4), bulb)
	# Table de roulette renversée au premier plan, jetons épars.
	var felt: StandardMaterial3D = Stage3D.mat(Color(0.05, 0.25, 0.15), 0.0, 0.9)
	var table: MeshInstance3D = Stage3D.box(r, Vector3(3.2, 0.12, 1.6), Vector3(3.6, 0.55, 1.2), felt)
	table.rotation = Vector3(0.0, -0.4, 0.22)
	Stage3D.box(table, Vector3(3.3, 0.16, 1.7), Vector3(0, -0.1, 0), Stage3D.mat(Color(0.3, 0.16, 0.07), 0.1, 0.5))
	var chip_cols: Array[Color] = [Palette.ROULETTE_RED, Palette.CHIPS_BLUE, Palette.EMERALD, Palette.GOLD, Palette.IVORY]
	for k: int in 26:
		var at: Vector3 = Vector3(_rng.randf_range(-2.0, 5.5), 0.02, _rng.randf_range(-0.6, 3.6))
		var chip: MeshInstance3D = Stage3D.cylinder(r, 0.09, 0.03, at, Stage3D.mat(chip_cols[k % chip_cols.size()], 0.1, 0.4))
		chip.rotation = Vector3(_rng.randf_range(-0.2, 0.2), 0, _rng.randf_range(-0.2, 0.2))
	for k: int in 4:
		var pile_at: Vector3 = Vector3(-3.0 + 2.2 * float(k), 0, 2.2 - float(k % 2))
		for h: int in 2 + k:
			Stage3D.cylinder(r, 0.09, 0.03, pile_at + Vector3(0, 0.015 + 0.032 * float(h), 0), Stage3D.mat(chip_cols[(k + h) % 5], 0.1, 0.4))
	# Enseigne néon au fond.
	_sign = Stage3D.text3d(r, "GRAND ZERO", Vector3(5.2, 3.0, -2.6), 200, Palette.MAGENTA, Color("4a0a2a"))
	_sign_light = Stage3D.omni(r, Palette.MAGENTA, 2.0, Vector3(5.2, 2.9, -1.8), 7.0)
	# Lustre : couronne de bougies, suspendu, qui se balance.
	_chandelier = Node3D.new()
	_chandelier.position = Vector3(0.8, 7.4, 1.0)
	r.add_child(_chandelier)
	Stage3D.cylinder(_chandelier, 0.01, 2.0, Vector3(0, -1.0, 0), Stage3D.mat(Palette.SMOKE))
	Stage3D.cylinder(_chandelier, 0.8, 0.06, Vector3(0, -2.0, 0), gold)
	for k: int in 10:
		var a: float = TAU * float(k) / 10.0
		var at2: Vector3 = Vector3(cos(a) * 0.8, -1.88, sin(a) * 0.8)
		Stage3D.cylinder(_chandelier, 0.03, 0.16, at2, Stage3D.mat(Palette.IVORY))
		Stage3D.sphere(_chandelier, 0.035, at2 + Vector3(0, 0.12, 0), Stage3D.glow(Palette.GOLD_LIGHT, 3.0))
	var warm: OmniLight3D = Stage3D.omni(_chandelier, Color(1.0, 0.78, 0.5), 2.6, Vector3(0, -2.2, 0), 9.0)
	warm.shadow_enabled = RenderQuality.shadows()
	# Projecteur qui balaie la salle.
	_sweep = SpotLight3D.new()
	_sweep.light_color = Color(0.6, 0.85, 1.0)
	_sweep.light_energy = 6.0
	_sweep.spot_range = 16.0
	_sweep.spot_angle = 14.0
	_sweep.position = Vector3(-6.0, 7.0, 4.0)
	r.add_child(_sweep)
	# Poussière en suspension dans la lumière.
	var dust_m: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.92, 0.75), 0.6)
	for k: int in DUST:
		var d: MeshInstance3D = Stage3D.sphere(r, 0.012, _dust_spot(), dust_m)
		_dust.append(d)
		_dust_v.append(Vector3(_rng.randf_range(-0.05, 0.05), _rng.randf_range(-0.04, 0.02), _rng.randf_range(-0.03, 0.03)))


func _dust_spot() -> Vector3:
	return Vector3(_rng.randf_range(-4.0, 5.0), _rng.randf_range(0.3, 5.0), _rng.randf_range(-1.5, 4.5))


func _process(delta: float) -> void:
	_t += delta
	var u: float = 0.5 - 0.5 * cos(_t * TAU / DRIFT_SECONDS)
	look(CAM_FROM.lerp(CAM_TO, u), LOOK_AT + Vector3(0, sin(_t * 0.3) * 0.08, 0), 42.0)
	# Néon qui grésille : quelques coupures irrégulières.
	var flick: float = 1.0 if fposmod(_t * 3.7, 5.3) > 0.25 and fposmod(_t * 11.0, 7.9) > 0.15 else 0.25
	_sign.modulate = Color(Palette.MAGENTA, flick)
	_sign_light.light_energy = 2.0 * flick
	_chandelier.rotation.z = sin(_t * 0.7) * 0.03
	_chandelier.rotation.x = sin(_t * 0.5 + 1.0) * 0.02
	_sweep.look_at(Vector3(sin(_t * 0.35) * 5.0, 0.0, cos(_t * 0.27) * 2.0), Vector3.UP)
	for k: int in _bulbs.size():
		var on: bool = k == 3 and fposmod(_t * 2.0, 1.0) < 0.5
		_bulbs[k].emission_energy_multiplier = 2.5 if on else 0.0
	for k: int in _dust.size():
		var p: Vector3 = _dust[k].position + _dust_v[k] * delta + Vector3(sin(_t + float(k)) * 0.002, 0, 0)
		if p.y < 0.2:
			p = _dust_spot()
			p.y = 5.0
		_dust[k].position = p
