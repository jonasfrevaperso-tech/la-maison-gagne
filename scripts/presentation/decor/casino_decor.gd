class_name CasinoDecor
extends SubViewportContainer
## Décor global de la partie : la table d'un casino abandonné, rendue en 3D derrière toute
## l'interface (feutre usé, lustre qui vacille, poussière dans le faisceau), avec des objets
## décoratifs interactifs posés sur les zones libres de l'écran (cf. DecorProp, DecorCritter).
## Les objets sont ancrés sur des points de la maquette 1920×1080 : ils suivent la scène quelle
## que soit la résolution, et les marges des écrans larges reçoivent quelques objets en plus.

const CAM_HEIGHT: float = 14.0
const CAM_BACK: float = 6.8
const CAM_FOV: float = 34.0
const DESIGN_UNIT_PX: float = 100.0
## Grossissement des objets par rapport à l'échelle « réelle » de la maquette.
const PROP_SCALE: float = 1.45
const FLICKER_CHANCE: float = 0.006
const NEON_TICK: float = 0.09
const AMBIENT: Color = Color(0.32, 0.26, 0.3)
const LAMP_COLOR: Color = Color(1.0, 0.86, 0.62)

## [type, point de maquette (px), rotation Y]. Zones libres : haut-droite (à droite du score),
## à droite des boutons, bas-centre (entre grigris et Fortune) et bas-droite.
const LAYOUT: Array = [
	["neon", Vector2(1650, 285), -0.08],
	["lamp", Vector2(1850, 330), 2.6],
	["chips", Vector2(1805, 790), 0.0],
	["bottle", Vector2(1805, 1000), 0.0],
	["ashtray", Vector2(810, 1000), 0.3],
	["glass", Vector2(960, 985), 0.0],
	["dice", Vector2(1110, 1000), 0.0],
	["cards", Vector2(1300, 990), 0.2],
]
## Objets supplémentaires des marges latérales (écrans plus larges que 16:9).
const MARGIN_LAYOUT: Array = [
	["chips", Vector2(-110, 520), 0.0],
	["glass", Vector2(-120, 820), 0.0],
	["cards", Vector2(2030, 520), -0.3],
	["ashtray", Vector2(2040, 780), 0.0],
]
## Téléphone (scène 2200×1080, cf. RunScreenLayoutMobile) : zones libres en haut, autour du score.
## Téléphone : les cartes Fortune occupent le coin haut droit ; le décor se range à leur gauche.
const LAYOUT_MOBILE: Array = [
	["neon", Vector2(1780, 215), -0.08],
	["chips", Vector2(860, 235), 0.0],
	["glass", Vector2(1010, 250), 0.0],
]
const CRITTERS_MOBILE: Array = [["spider", Vector2(1900, -60), Vector2(1880, 300)]]
## Bestioles : [type, entrée (bord), arrêt].
const CRITTERS: Array = [
	["spider", Vector2(2000, 180), Vector2(1560, 200)],
	["rat", Vector2(1440, 1180), Vector2(1430, 1020)],
]

var stage: Control = null
var props: Array[DecorProp] = []
var _vp: SubViewport = null
var _root3d: Node3D = null
var _cam: Camera3D = null
var _env: Environment = null
var _key: SpotLight3D = null
var _key_energy: float = 4.0
var _hover: DecorProp = null
var _neon_t: float = 0.0
var _dust: CPUParticles3D = null
var _felt: MeshInstance3D = null


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.gui_disable_input = true
	_vp.positional_shadow_atlas_size = 2048
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_root3d = Node3D.new()
	_vp.add_child(_root3d)
	_build_world()
	_build_props()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_layout.call_deferred)
	EventBus.settings_changed.connect(_apply_quality)
	_apply_quality()
	_layout.call_deferred()


## Réglage « portable » : rendu 3D du décor à demi-résolution, sans ombres ni MSAA.
func _apply_quality() -> void:
	_vp.msaa_3d = RenderQuality.msaa(Viewport.MSAA_2X, Viewport.MSAA_DISABLED)
	_vp.scaling_3d_scale = RenderQuality.scale_3d(0.6)
	_key.shadow_enabled = RenderQuality.shadows()
	_env.glow_enabled = Settings.f("video", "bloom") > 0.0
	_env.glow_intensity = 0.3 + 0.7 * Settings.f("video", "bloom")
	_dust.amount = int(RenderQuality.pick(110, 50))


func set_tint(c: Color) -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_env, "ambient_light_color", AMBIENT.lerp(c, 0.35 * c.a), 1.2)


# --------------------------------------------------------------------------- monde


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Palette.INK
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = AMBIENT
	_env.ambient_light_energy = 0.42
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.0
	_env.glow_enabled = true
	_env.glow_bloom = 0.05
	_env.glow_hdr_threshold = 0.95
	_env.fog_enabled = false
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = _env
	_root3d.add_child(we)
	_cam = Camera3D.new()
	_cam.fov = CAM_FOV
	_cam.position = Vector3(0, CAM_HEIGHT, CAM_BACK)
	_root3d.add_child(_cam)
	_cam.look_at_from_position(_cam.position, Vector3.ZERO, Vector3.FORWARD)
	# Le tapis : un grand plan de feutre usé.
	_felt = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60, 40)
	_felt.mesh = plane
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = load("res://shaders/worn_felt.gdshader") as Shader
	_felt.material_override = sm
	_root3d.add_child(_felt)
	# Lustre au-dessus de la table (vacille de temps en temps) + contre-jour froid.
	_key = SpotLight3D.new()
	_key.light_color = LAMP_COLOR
	_key.light_energy = _key_energy
	_key.spot_range = 30.0
	_key.spot_angle = 38.0
	_key.spot_attenuation = 0.6
	_key.shadow_enabled = true
	_key.shadow_blur = 2.0
	_key.position = Vector3(-1.5, 16.0, 1.5)
	_root3d.add_child(_key)
	_key.look_at_from_position(_key.position, Vector3(-0.5, 0, 0.5), Vector3.FORWARD)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.light_color = Color(0.45, 0.5, 0.75)
	fill.light_energy = 0.25
	fill.rotation = Vector3(-1.1, 0.6, 0)
	_root3d.add_child(fill)
	_dust = _make_dust()
	_root3d.add_child(_dust)


func _make_dust() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = DecorProp.soft_dot()
	q.material = m
	p.mesh = q
	p.amount = 110
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(13, 4, 8)
	p.position = Vector3(0, 4.5, 0)
	p.direction = Vector3(1, 0.2, 0)
	p.spread = 180.0
	p.gravity = Vector3(0, -0.01, 0)
	p.initial_velocity_min = 0.02
	p.initial_velocity_max = 0.12
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.6
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.9, 0.7, 0.0))
	ramp.add_point(0.5, Color(1.0, 0.92, 0.75, 0.55))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.9, 0.7, 0.0))
	p.color_ramp = ramp
	return p


func _build_props() -> void:
	var rows: Array = LAYOUT_MOBILE if Platform.is_mobile() else LAYOUT + MARGIN_LAYOUT
	for row: Array in rows:
		var pr: DecorProp = DecorProp.new(String(row[0]))
		pr.call("build_" + String(row[0]))
		pr.rotation.y = float(row[2])
		pr.set_meta("design", row[1])
		_root3d.add_child(pr)
		props.append(pr)
	for row: Array in CRITTERS_MOBILE if Platform.is_mobile() else CRITTERS:
		var c: DecorCritter = DecorCritter.new(String(row[0]))
		c.call("build_" + String(row[0]))
		c.set_meta("design", row[2])
		c.set_meta("entry", row[1])
		_root3d.add_child(c)
		props.append(c)


# --------------------------------------------------------------------------- placement


## Point de canevas → point sur le plan de la table (y = 0).
func table_point(canvas: Vector2) -> Vector3:
	var local: Vector2 = get_global_transform().affine_inverse() * canvas
	var from: Vector3 = _cam.project_ray_origin(local)
	var dir: Vector3 = _cam.project_ray_normal(local)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	return hit as Vector3 if hit != null else Vector3.ZERO


func _design_to_canvas(p: Vector2) -> Vector2:
	if stage == null:
		return p * (size / UiLayout.DESIGN_SIZE)
	return UiLayout.canvas_point(stage, p)


func _layout() -> void:
	if not is_inside_tree() or size.x <= 0.0:
		return
	var a: Vector3 = table_point(_design_to_canvas(Vector2(860, 540)))
	var b: Vector3 = table_point(_design_to_canvas(Vector2(860 + DESIGN_UNIT_PX, 540)))
	var unit: float = maxf(a.distance_to(b), 0.001)
	var view: Rect2 = Rect2(Vector2.ZERO, size)
	for pr: DecorProp in props:
		var canvas: Vector2 = _design_to_canvas(pr.get_meta("design"))
		var local: Vector2 = get_global_transform().affine_inverse() * canvas
		pr.position = table_point(canvas)
		pr.scale = Vector3.ONE * unit * PROP_SCALE
		# Objets des marges : seulement s'ils tombent entièrement dans l'écran.
		var margin_item: bool = Rect2(Vector2.ZERO, UiLayout.DESIGN_SIZE).has_point(pr.get_meta("design")) == false
		if margin_item and not (pr is DecorCritter):
			pr.visible = view.grow(-pr.radius_px).has_point(local)
		if pr is DecorCritter:
			var entry: Vector2 = pr.get_meta("entry")
			var edge: Vector2 = _design_to_canvas(entry)
			edge = _push_offscreen(edge, local)
			(pr as DecorCritter).place(table_point(edge), table_point(canvas))


## Repousse un point d'entrée hors du cadre visible (bords réels de la fenêtre, marges comprises).
func _push_offscreen(p: Vector2, rest: Vector2) -> Vector2:
	var local: Vector2 = get_global_transform().affine_inverse() * p
	var dir: Vector2 = (local - rest).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var guard: int = 0
	while Rect2(Vector2.ZERO, size).grow(80.0).has_point(local) and guard < 400:
		local += dir * 10.0
		guard += 1
	return get_global_transform() * local


# --------------------------------------------------------------------------- vie


func _process(delta: float) -> void:
	RenderQuality.sleep_if_covered(_vp)
	var rng: RandomNumberGenerator = RngService.cosmetic()
	# Le lustre a de mauvais contacts.
	if rng.randf() < FLICKER_CHANCE * JuiceProfile.intensity():
		_key.light_energy = _key_energy * rng.randf_range(0.25, 0.7)
	else:
		_key.light_energy = move_toward(_key.light_energy, _key_energy, delta * 6.0)
	_neon_t -= delta
	if _neon_t <= 0.0:
		_neon_t = NEON_TICK
		for pr: DecorProp in props:
			if pr.kind == "neon":
				pr.neon_tick()


# --------------------------------------------------------------------------- interaction


func prop_at(canvas: Vector2) -> DecorProp:
	var local: Vector2 = get_global_transform().affine_inverse() * canvas
	var s: float = stage.scale.x if stage != null else 1.0
	var best: DecorProp = null
	var best_d: float = INF
	for pr: DecorProp in props:
		if not pr.visible:
			continue
		if pr is DecorCritter and not (pr as DecorCritter).can_poke():
			continue
		var aim: Vector3 = pr.global_position + Vector3.UP * pr.aim_height * pr.scale.y
		if _cam.is_position_behind(aim):
			continue
		var sp: Vector2 = _cam.unproject_position(aim)
		var d: float = sp.distance_to(local)
		if d <= pr.radius_px * s and d < best_d:
			best = pr
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hover(prop_at(get_global_transform() * (event as InputEventMouseMotion).position))
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var pr: DecorProp = prop_at(get_global_transform() * mb.position)
			if pr != null:
				pr.poke()
				accept_event()


func _set_hover(pr: DecorProp) -> void:
	if pr == _hover:
		return
	if _hover != null and is_instance_valid(_hover):
		_hover.set_hover(false)
	_hover = pr
	if pr != null:
		pr.set_hover(true)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pr != null else Control.CURSOR_ARROW


## Manette (R3) : secoue un objet visible au hasard.
func poke_random() -> void:
	var pool: Array[DecorProp] = []
	for pr: DecorProp in props:
		if pr.visible and (not (pr is DecorCritter) or (pr as DecorCritter).can_poke()):
			pool.append(pr)
	if not pool.is_empty():
		pool[RngService.cosmetic().randi_range(0, pool.size() - 1)].poke()
