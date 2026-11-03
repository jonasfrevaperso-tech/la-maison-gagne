class_name ChipBurst3D
extends SubViewportContainer
## Gerbe de jetons et de pièces en 3D (gros gains, échéance remboursée) : un MultiMesh dans un
## SubViewport transparent plein écran, physique simple (vitesse, gravité, rotation), puis
## autodestruction. Jamais plus d'une seconde de calcul par jeton ; 0 jeton si le jus est coupé.

const LIFETIME: float = 2.4
const GRAVITY: float = -26.0
const DEPTH: float = 12.0
const FOV: float = 40.0
const CHIP_RADIUS: float = 0.3
const CHIP_HEIGHT: float = 0.07
const SPEED_MIN: float = 9.0
const SPEED_MAX: float = 17.0
const SPIN_MAX: float = 14.0
const MAX_CHIPS: int = 160
const CHIP_COLORS: Array[Color] = [Color("ff2e88"), Color("29e0ff"), Color("2ee6a8"), Color("f5f0e6"), Color("d4af37")]

var _vp: SubViewport = null
var _cam: Camera3D = null
var _mm: MultiMesh = null
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _axis: PackedVector3Array = PackedVector3Array()
var _spin: PackedFloat32Array = PackedFloat32Array()
var _angle: PackedFloat32Array = PackedFloat32Array()
var _t: float = 0.0


## `at` : point d'émission (coordonnées du conteneur) ; `coins` : pièces d'or seulement.
static func spawn(parent: Control, at: Vector2, amount: int, coins: bool = false) -> void:
	var n: int = mini(RenderQuality.particles(int(float(amount) * JuiceProfile.intensity())), MAX_CHIPS)
	if n <= 0 or DisplayServer.get_name() == "headless":
		return
	var b: ChipBurst3D = ChipBurst3D.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	b._start(at, n, coins)


func _start(at: Vector2, n: int, coins: bool) -> void:
	stretch = true
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	RenderQuality.configure(_vp, null, true)
	add_child(_vp)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.IVORY
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.position = Vector3(0, 0, DEPTH)
	_vp.add_child(_cam)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.light_color = Palette.GOLD_LIGHT
	sun.light_energy = 1.6
	sun.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(30.0), 0.0)
	_vp.add_child(sun)
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = CHIP_RADIUS
	mesh.bottom_radius = CHIP_RADIUS
	mesh.height = CHIP_HEIGHT
	mesh.radial_segments = 18
	mesh.rings = 1
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.metallic = 0.9 if coins else 0.25
	mat.roughness = 0.25 if coins else 0.4
	mesh.material = mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.mesh = mesh
	_mm.instance_count = n
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	_vp.add_child(mmi)
	var origin: Vector3 = _to_world(at)
	var rng: RandomNumberGenerator = RngService.cosmetic()
	for i: int in n:
		var a: float = rng.randf_range(-PI * 0.42, PI * 0.42)
		var sp: float = rng.randf_range(SPEED_MIN, SPEED_MAX)
		_pos.append(origin + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.5, 0.5)))
		_vel.append(Vector3(sin(a) * sp, cos(a) * sp, rng.randf_range(-3.0, 3.0)))
		_axis.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized())
		_spin.append(rng.randf_range(-SPIN_MAX, SPIN_MAX))
		_angle.append(rng.randf() * TAU)
		var col: Color = Palette.GOLD if coins else CHIP_COLORS[i % CHIP_COLORS.size()]
		_mm.set_instance_color(i, col)
	_update(0.0)


## Point écran → point du plan z = 0 vu par la caméra.
func _to_world(p: Vector2) -> Vector3:
	var vs: Vector2 = size if size.x > 0.0 else get_viewport_rect().size
	var half_h: float = DEPTH * tan(deg_to_rad(FOV) * 0.5)
	var half_w: float = half_h * vs.x / maxf(vs.y, 1.0)
	return Vector3((p.x / vs.x * 2.0 - 1.0) * half_w, (1.0 - p.y / vs.y * 2.0) * half_h, 0.0)


func _process(delta: float) -> void:
	if _mm == null:
		return
	_t += delta
	_update(delta)
	modulate.a = clampf((LIFETIME - _t) / 0.4, 0.0, 1.0)
	if _t >= LIFETIME:
		queue_free()


func _update(delta: float) -> void:
	for i: int in _pos.size():
		_vel[i] += Vector3(0.0, GRAVITY * delta, 0.0)
		_pos[i] += _vel[i] * delta
		_angle[i] += _spin[i] * delta
		_mm.set_instance_transform(i, Transform3D(Basis(_axis[i], _angle[i]), _pos[i]))
