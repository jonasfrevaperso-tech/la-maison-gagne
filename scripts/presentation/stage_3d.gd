class_name Stage3D
extends SubViewportContainer
## Petite scène 3D autonome dans l'interface (machine à sous, épreuves du lancer) : SubViewport
## à monde propre, environnement sombre de casino avec bloom, caméra, lumière principale.
## Respecte le mode portable (résolution 3D réduite, sans ombres) et le réglage de bloom.
## Le contenu se construit dans `root` ; la présentation reste purement cosmétique.

const AMBIENT: Color = Color(0.32, 0.22, 0.3)

var root: Node3D = null
var cam: Camera3D = null
var env: Environment = null
var key: DirectionalLight3D = null
## Caméra frontale (frontal()) : mètres par pixel et pixel visé par l'origine du plan z = 0.
var px3: float = 0.01
var origin_px: Vector2 = Vector2.ZERO
var _vp: SubViewport = null


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.gui_disable_input = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	root = Node3D.new()
	_vp.add_child(root)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.INK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	cam = Camera3D.new()
	cam.fov = 40.0
	root.add_child(cam)
	key = DirectionalLight3D.new()
	key.light_energy = 0.7
	key.rotation_degrees = Vector3(-50, 25, 0)
	root.add_child(key)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	EventBus.settings_changed.connect(_apply_quality)
	_apply_quality()


func _apply_quality() -> void:
	RenderQuality.configure(_vp, env, _vp.transparent_bg)
	key.shadow_enabled = RenderQuality.shadows()
	env.glow_enabled = Settings.f("video", "bloom") > 0.0 and not _vp.transparent_bg
	env.glow_intensity = 0.4 + 0.8 * Settings.f("video", "bloom")


## Fond transparent : seule la géométrie se dessine (décor 3D posé sur une interface 2D).
func set_transparent(on: bool) -> void:
	_vp.transparent_bg = on
	RenderQuality.configure(_vp, env, on)
	if on:
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.glow_enabled = false


func look(from: Vector3, at: Vector3, fov: float = 40.0) -> void:
	cam.fov = fov
	cam.look_at_from_position(from, at, Vector3.UP)


## Caméra de face calée sur le repère 2D de l'épreuve : dans le plan z = 0, un pixel vaut
## `p_px3` mètres et `p_origin` (pixels) est l'origine 3D. `view_h` : hauteur du contrôle.
func frontal(p_px3: float, p_origin: Vector2, view_h: float, fov: float = 40.0) -> void:
	px3 = p_px3
	origin_px = p_origin
	cam.fov = fov
	cam.rotation = Vector3.ZERO
	var dist: float = view_h * 0.5 * px3 / tan(deg_to_rad(fov) * 0.5)
	cam.position = Vector3(0, (p_origin.y - view_h * 0.5) * px3, dist)


## Pixel du repère 2D → point 3D (plan z, par défaut celui de la caméra frontale).
func to3(p2: Vector2, z: float = 0.0) -> Vector3:
	var d: Vector2 = (p2 - origin_px) * px3
	return Vector3(d.x, -d.y, z)


## Point 3D → position dans le repère du parent (pour accrocher textes et effets 2D ; égal au
## repère de ce contrôle quand il est à l'origine, débord du décor sur téléphone compris).
func project(p: Vector3) -> Vector2:
	var vp_size: Vector2 = Vector2(_vp.size)
	if vp_size.x <= 0.0 or size.x <= 0.0:
		return Vector2.ZERO
	return cam.unproject_position(p) * (size / vp_size) + position


# --------------------------------------------------------------------------- fabrique


static func mat(col: Color, metallic: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metallic
	m.roughness = rough
	return m


static func glow(col: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(col, 0.0, 0.4)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


static func box(parent: Node3D, size_v: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size_v
	return _inst(parent, bm, at, m)


static func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, m: Material, top: float = -1.0) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius if top < 0.0 else top
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 32
	return _inst(parent, cm, at, m)


static func sphere(parent: Node3D, radius: float, at: Vector3, m: Material) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	return _inst(parent, sm, at, m)


static func text3d(parent: Node3D, txt: String, at: Vector3, px: int, col: Color, outline: Color = Palette.INK) -> Label3D:
	var l: Label3D = Label3D.new()
	l.text = txt
	l.font = UiKit.font("display")
	l.font_size = px
	l.pixel_size = 0.0025
	l.modulate = col
	l.outline_modulate = outline
	l.outline_size = maxi(4, px / 8)
	l.position = at
	l.shaded = false
	parent.add_child(l)
	return l


static func omni(parent: Node3D, col: Color, energy: float, at: Vector3, range_m: float = 3.0) -> OmniLight3D:
	var o: OmniLight3D = OmniLight3D.new()
	o.light_color = col
	o.light_energy = energy
	o.omni_range = range_m
	o.position = at
	parent.add_child(o)
	return o


static func _inst(parent: Node3D, mesh: Mesh, at: Vector3, m: Material) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	parent.add_child(mi)
	return mi
