class_name Wheel3D
extends SubViewportContainer
## Rendu 3D temps réel de la roue (SubViewport, monde 3D propre) : cuvette en bois verni,
## piste de bille et losanges déflecteurs, rotor à cases colorées et frettes dorées, cône et
## tourelle à croisillons, bille métallique avec traînée, éclairage de salle de jeu.
## La logique et la chronologie restent dans WheelView (angles, visée, trajectoire de la bille) :
## ce nœud ne fait que les montrer en 3D (`sync`) et convertir écran ↔ roue (`project`, `pick`).
## Repère : roue de rayon 1 dans le plan XZ ; un angle écran a ↦ (cos a, ·, sin a).

## Rayons (fractions du rayon de la roue, identiques au rendu 2D) et hauteurs.
const R_HUB: float = 0.3
const R_POCKET_IN: float = 0.58
const R_POCKET_OUT: float = 0.82
const R_RIM_OUT: float = 0.86
const R_TRACK_OUT: float = 1.0
const R_CABINET: float = 1.12
const Y_POCKET: float = 0.02
const Y_RIM: float = 0.06
const Y_TRACK_IN: float = 0.07
const Y_TRACK_OUT: float = 0.17
const Y_CABINET: float = 0.24
const Y_HUB: float = 0.2
const FRET_H: float = 0.045
const FRET_W: float = 0.012
const BALL_R: float = 0.04
const LABEL_R: float = 0.74
const ICON_R: float = 0.64
const SEAL_R: float = 0.605
const DIAMONDS: int = 8
const TRAIL: int = 10
const SECTOR_STEPS: int = 4
const LATHE_STEPS: int = 96
## Caméra : élévation (degrés au-dessus du plan), champ vertical, marge autour du coffre.
const CAM_ELEVATION: float = 54.0
const CAM_FOV: float = 30.0
const CAM_FIT: float = 1.03
## Plongée de la caméra en fin de lancer et au résultat.
const CAM_DIVE_FOV: float = 0.86
const CAM_LAND_PUNCH: float = 0.06
const CAM_SWAY: float = 0.8

## Débordement du rendu 3D autour du cadre de la roue (px de maquette).
const BLEED: float = 280.0

var wheel: WheelModel = null
var db: ContentDB = null
var camera: Camera3D = null
var _vp: SubViewport = null
var _root3d: Node3D = null
var _rotor: Node3D = null
var _pockets_root: Node3D = null
var _ball: MeshInstance3D = null
var _trail: Array[MeshInstance3D] = []
var _pointer: MeshInstance3D = null
var _key_light: SpotLight3D = null
var _land_light: OmniLight3D = null
var _env: Environment = null
var _signature: String = ""
var _pocket_mats: Array[StandardMaterial3D] = []
var _zone_mats: Array[StandardMaterial3D] = []
var _zone_nodes: Array[MeshInstance3D] = []
var _prob_nodes: Array[MeshInstance3D] = []
var _labels: Array[Label3D] = []
var _icons: Array[Sprite3D] = []
var _base_colors: Array[Color] = []
var _cam_fov: float = CAM_FOV
var _cam_target: Vector3 = Vector3.ZERO
var _cam_dist: float = 4.0
var _land_t: float = 0.0
var _land_pos: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _framed_size: Vector2 = Vector2.ZERO


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.positional_shadow_atlas_size = 1024
	add_child(_vp)
	_root3d = Node3D.new()
	_vp.add_child(_root3d)
	_build_scene()


func _ready() -> void:
	resized.connect(_frame_camera)
	EventBus.settings_changed.connect(_apply_quality)
	_apply_quality()
	_frame_camera()


func setup(p_wheel: WheelModel, p_db: ContentDB) -> void:
	wheel = p_wheel
	db = p_db
	_signature = ""


## Qualité selon les réglages : bloom → lueur 3D, mode portable → MSAA et ombres réduits.
func _apply_quality() -> void:
	var handheld: bool = Settings.b("video", "handheld")
	_vp.msaa_3d = Viewport.MSAA_2X if handheld else Viewport.MSAA_4X
	if _key_light != null:
		_key_light.shadow_enabled = not handheld
	if _env != null:
		_env.glow_enabled = Settings.f("video", "bloom") > 0.0
		_env.glow_intensity = 0.4 + 0.8 * Settings.f("video", "bloom")


# --------------------------------------------------------------------------- construction


func _build_scene() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_CLEAR_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Palette.VELVET.lightened(0.2)
	_env.ambient_light_energy = 0.55
	var sky: Sky = Sky.new()
	var sky_mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Palette.VELVET_DEEP
	sky_mat.sky_horizon_color = Palette.GOLD_DARK
	sky_mat.ground_horizon_color = Palette.GOLD_DARK
	sky_mat.ground_bottom_color = Palette.INK
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.glow_enabled = true
	_env.glow_bloom = 0.08
	_env.glow_hdr_threshold = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = _env
	_root3d.add_child(we)
	camera = Camera3D.new()
	camera.fov = CAM_FOV
	_root3d.add_child(camera)
	# Lumière principale chaude au-dessus de la table, néons de salle en contre-jour.
	_key_light = SpotLight3D.new()
	_key_light.light_color = Palette.IVORY.lerp(Palette.GOLD_LIGHT, 0.35)
	_key_light.light_energy = 6.0
	_key_light.spot_range = 8.0
	_key_light.spot_angle = 38.0
	_key_light.shadow_enabled = true
	var key_pos: Vector3 = Vector3(0.6, 3.4, 1.2)
	_key_light.transform = Transform3D(Basis.looking_at(-key_pos, Vector3.UP), key_pos)
	_root3d.add_child(_key_light)
	for side: Array in [[Vector3(-2.2, 0.8, -0.6), Palette.MAGENTA], [Vector3(2.2, 0.8, -0.6), Palette.CYAN]]:
		var o: OmniLight3D = OmniLight3D.new()
		o.position = side[0] as Vector3
		o.light_color = side[1] as Color
		o.light_energy = 1.4
		o.omni_range = 4.0
		_root3d.add_child(o)
	_land_light = OmniLight3D.new()
	_land_light.light_color = Palette.GOLD_LIGHT
	_land_light.light_energy = 0.0
	_land_light.omni_range = 0.8
	_root3d.add_child(_land_light)
	_build_bowl()
	_rotor = Node3D.new()
	_root3d.add_child(_rotor)
	_build_hub()
	_pockets_root = Node3D.new()
	_rotor.add_child(_pockets_root)
	_build_ball()
	_build_pointer()


func _mat(col: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	return m


func _unshaded(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = col
	m.no_depth_test = false
	return m


func _wood() -> StandardMaterial3D:
	var m: StandardMaterial3D = _mat(Color("4a1f14"), 0.0, 0.38)
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.frequency = 0.02
	noise.fractal_octaves = 2
	var tex: NoiseTexture2D = NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 64
	tex.seamless = true
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color("2a0f0a"))
	grad.set_color(1, Color("7a3a22"))
	tex.color_ramp = grad
	m.albedo_texture = tex
	m.albedo_color = Color.WHITE
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.2
	return m


## Surface de révolution : profil [(rayon, hauteur)] tourné autour de l'axe Y.
func _lathe(profile: Array[Vector2], mat: Material) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in LATHE_STEPS:
		var a0: float = TAU * float(k) / float(LATHE_STEPS)
		var a1: float = TAU * float(k + 1) / float(LATHE_STEPS)
		for j: int in profile.size() - 1:
			var p0: Vector2 = profile[j]
			var p1: Vector2 = profile[j + 1]
			var v00: Vector3 = Vector3(cos(a0) * p0.x, p0.y, sin(a0) * p0.x)
			var v01: Vector3 = Vector3(cos(a1) * p0.x, p0.y, sin(a1) * p0.x)
			var v10: Vector3 = Vector3(cos(a0) * p1.x, p1.y, sin(a0) * p1.x)
			var v11: Vector3 = Vector3(cos(a1) * p1.x, p1.y, sin(a1) * p1.x)
			var u0: float = float(k) / float(LATHE_STEPS)
			var u1: float = float(k + 1) / float(LATHE_STEPS)
			_quad(st, v00, v01, v11, v10, Vector2(u0 * 4.0, float(j)), Vector2(u1 * 4.0, float(j + 1)))
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv0: Vector2, uv1: Vector2) -> void:
	st.set_uv(uv0)
	st.add_vertex(a)
	st.set_uv(Vector2(uv1.x, uv0.y))
	st.add_vertex(b)
	st.set_uv(uv1)
	st.add_vertex(c)
	st.set_uv(uv0)
	st.add_vertex(a)
	st.set_uv(uv1)
	st.add_vertex(c)
	st.set_uv(Vector2(uv0.x, uv1.y))
	st.add_vertex(d)


func _build_bowl() -> void:
	# Coffre en bois : lèvre extérieure, puis piste inclinée vers le rotor.
	var outer: Array[Vector2] = [
		Vector2(R_CABINET + 0.04, -0.08),
		Vector2(R_CABINET + 0.04, Y_CABINET - 0.03),
		Vector2(R_CABINET, Y_CABINET),
		Vector2(R_TRACK_OUT + 0.03, Y_CABINET),
		Vector2(R_TRACK_OUT, Y_TRACK_OUT),
	]
	_root3d.add_child(_lathe(outer, _wood()))
	var track: Array[Vector2] = [Vector2(R_TRACK_OUT, Y_TRACK_OUT), Vector2(R_RIM_OUT + 0.01, Y_TRACK_IN)]
	_root3d.add_child(_lathe(track, _mat(Color("1d1418"), 0.2, 0.18)))
	var gold_lip: Array[Vector2] = [Vector2(R_CABINET + 0.005, Y_CABINET + 0.004), Vector2(R_TRACK_OUT + 0.035, Y_CABINET + 0.004)]
	_root3d.add_child(_lathe(gold_lip, _mat(Palette.GOLD, 1.0, 0.28)))
	# Losanges déflecteurs sur la piste.
	var gold: StandardMaterial3D = _mat(Palette.GOLD_LIGHT, 1.0, 0.22)
	for k: int in DIAMONDS:
		var a: float = TAU * float(k) / float(DIAMONDS) + PI / float(DIAMONDS)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var pm: PrismMesh = PrismMesh.new()
		pm.size = Vector3(0.05, 0.022, 0.09)
		mi.mesh = pm
		mi.material_override = gold
		var r: float = (R_TRACK_OUT + R_RIM_OUT) * 0.5 + 0.02
		mi.position = Vector3(cos(a) * r, _track_y(r) + 0.012, sin(a) * r)
		mi.rotation = Vector3(0.0, -a, 0.0)
		_root3d.add_child(mi)


func _build_hub() -> void:
	var cone: Array[Vector2] = [Vector2(R_POCKET_IN, Y_POCKET + 0.01), Vector2(R_HUB + 0.04, Y_HUB - 0.03), Vector2(R_HUB, Y_HUB)]
	_rotor.add_child(_lathe(cone, _wood()))
	var gold: StandardMaterial3D = _mat(Palette.GOLD, 1.0, 0.25)
	var cap: Array[Vector2] = [
		Vector2(R_HUB, Y_HUB), Vector2(R_HUB * 0.55, Y_HUB + 0.03), Vector2(0.08, Y_HUB + 0.06), Vector2(0.0, Y_HUB + 0.065)
	]
	_rotor.add_child(_lathe(cap, gold))
	# Tourelle : fût et croisillons à boules.
	var stem: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.06
	cyl.height = 0.22
	stem.mesh = cyl
	stem.material_override = gold
	stem.position = Vector3(0, Y_HUB + 0.15, 0)
	_rotor.add_child(stem)
	var chrome: StandardMaterial3D = _mat(Palette.GOLD_LIGHT, 1.0, 0.12)
	for k: int in 4:
		var a: float = TAU * float(k) / 4.0
		var arm: MeshInstance3D = MeshInstance3D.new()
		var bar: CylinderMesh = CylinderMesh.new()
		bar.top_radius = 0.012
		bar.bottom_radius = 0.016
		bar.height = 0.26
		arm.mesh = bar
		arm.material_override = gold
		arm.position = Vector3(cos(a) * 0.13, Y_HUB + 0.21, sin(a) * 0.13)
		arm.rotation = Vector3(0, -a, PI * 0.5)
		_rotor.add_child(arm)
		var knob: MeshInstance3D = MeshInstance3D.new()
		var sph: SphereMesh = SphereMesh.new()
		sph.radius = 0.028
		sph.height = 0.056
		knob.mesh = sph
		knob.material_override = chrome
		knob.position = Vector3(cos(a) * 0.26, Y_HUB + 0.21, sin(a) * 0.26)
		_rotor.add_child(knob)
	var top: MeshInstance3D = MeshInstance3D.new()
	var ts: SphereMesh = SphereMesh.new()
	ts.radius = 0.04
	ts.height = 0.08
	top.mesh = ts
	top.material_override = chrome
	top.position = Vector3(0, Y_HUB + 0.28, 0)
	_rotor.add_child(top)
	# Anneau doré du rotor (bord des cases).
	var rim: Array[Vector2] = [Vector2(R_POCKET_OUT, Y_RIM), Vector2(R_RIM_OUT, Y_RIM), Vector2(R_RIM_OUT + 0.01, Y_TRACK_IN - 0.01)]
	_rotor.add_child(_lathe(rim, _mat(Palette.GOLD_DARK, 1.0, 0.3)))


func _build_ball() -> void:
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = BALL_R
	sph.height = BALL_R * 2.0
	_ball = MeshInstance3D.new()
	_ball.mesh = sph
	var bm: StandardMaterial3D = _mat(Palette.IVORY, 0.35, 0.12)
	bm.emission_enabled = true
	bm.emission = Palette.IVORY
	bm.emission_energy_multiplier = 0.25
	bm.clearcoat_enabled = true
	bm.clearcoat = 1.0
	_ball.material_override = bm
	_ball.visible = false
	_root3d.add_child(_ball)
	for k: int in TRAIL:
		var g: MeshInstance3D = MeshInstance3D.new()
		var gs: SphereMesh = SphereMesh.new()
		var f: float = 1.0 - float(k + 1) / float(TRAIL + 1)
		gs.radius = BALL_R * f
		gs.height = BALL_R * 2.0 * f
		gs.radial_segments = 12
		gs.rings = 6
		g.mesh = gs
		g.material_override = _unshaded(Color(Palette.GOLD_LIGHT, 0.35 * f))
		g.visible = false
		_root3d.add_child(g)
		_trail.append(g)


func _build_pointer() -> void:
	_pointer = MeshInstance3D.new()
	var pm: PrismMesh = PrismMesh.new()
	pm.size = Vector3(0.09, 0.12, 0.03)
	_pointer.mesh = pm
	var m: StandardMaterial3D = _mat(Palette.CYAN, 0.2, 0.3)
	m.emission_enabled = true
	m.emission = Palette.CYAN
	m.emission_energy_multiplier = 1.6
	_pointer.material_override = m
	_pointer.rotation = Vector3(0, 0, PI)
	_pointer.position = Vector3(0, Y_TRACK_OUT + 0.12, -R_RIM_OUT - 0.02)
	_pointer.visible = false
	_root3d.add_child(_pointer)


# --------------------------------------------------------------------------- cases


func _wheel_signature() -> String:
	if wheel == null:
		return ""
	var parts: PackedStringArray = []
	for p: Pocket in wheel.pockets:
		parts.append("%d|%s|%s|%s|%d|%s" % [p.number, p.type_id, p.edition, p.seal, p.level, p.color()])
	return ",".join(parts)


func _rebuild_pockets() -> void:
	for c: Node in _pockets_root.get_children():
		c.queue_free()
	_pocket_mats.clear()
	_zone_mats.clear()
	_zone_nodes.clear()
	_prob_nodes.clear()
	_labels.clear()
	_icons.clear()
	_base_colors.clear()
	var n: int = wheel.size()
	var span: float = TAU / float(maxi(n, 1))
	var fret_mat: StandardMaterial3D = _mat(Palette.GOLD, 1.0, 0.25)
	var font: Font = UiKit.font("mono")
	var fs: int = int(clampf(44.0 * 37.0 / float(maxi(n, 20)), 24.0, 60.0))
	for i: int in n:
		var p: Pocket = wheel.at(i)
		var a0: float = float(i) * span
		var a1: float = a0 + span
		var col: Color = Palette.pocket_color(p.color())
		var m: StandardMaterial3D = _mat(col, 0.05, 0.42)
		m.clearcoat_enabled = true
		m.clearcoat = 0.4
		if p.edition != &"":
			m.emission_enabled = true
			m.emission = PocketInfo.edition_color(p.edition)
			m.emission_energy_multiplier = 0.0
		_pocket_mats.append(m)
		_base_colors.append(col)
		_pockets_root.add_child(_sector(R_POCKET_IN, R_POCKET_OUT, Y_POCKET, Y_POCKET + 0.012, a0, a1, m))
		if p.type_id != Pocket.TYPE_STANDARD:
			var tdef: Dictionary = db.get_entry("pocket_types", String(p.type_id)) if db != null else {}
			var tcol: Color = Color(String(tdef.get("color", ""))) if tdef.has("color") else PocketInfo.type_color(p.type_id)
			var tm: StandardMaterial3D = _mat(tcol, 0.6, 0.3)
			tm.emission_enabled = true
			tm.emission = tcol
			tm.emission_energy_multiplier = 0.35
			_pockets_root.add_child(_sector(R_POCKET_OUT - 0.035, R_POCKET_OUT, Y_POCKET + 0.013, Y_POCKET + 0.016, a0, a1, tm))
			var tex: Texture2D = IconLibrary.icon(String(tdef.get("icon", "")))
			if tex != null:
				var sp: Sprite3D = Sprite3D.new()
				sp.texture = tex
				sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				sp.pixel_size = 0.0014 * clampf(37.0 / float(maxi(n, 1)), 0.6, 1.2)
				sp.shaded = false
				sp.position = Vector3(cos(a0 + span * 0.5) * ICON_R, Y_POCKET + 0.02, sin(a0 + span * 0.5) * ICON_R)
				_pockets_root.add_child(sp)
				_icons.append(sp)
		# Frette dorée au bord gauche de la case.
		var fret: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(R_POCKET_OUT - R_POCKET_IN + 0.02, FRET_H, FRET_W)
		fret.mesh = bm
		fret.material_override = fret_mat
		var rm: float = (R_POCKET_IN + R_POCKET_OUT) * 0.5
		fret.position = Vector3(cos(a0) * rm, Y_POCKET + FRET_H * 0.5, sin(a0) * rm)
		fret.rotation = Vector3(0, -a0, 0)
		_pockets_root.add_child(fret)
		# Numéro posé à plat, toujours lisible depuis la caméra (orienté en `sync`).
		var l: Label3D = Label3D.new()
		l.text = str(p.number) + ("+%d" % p.level if p.level > 0 else "")
		l.font = font
		l.font_size = fs
		l.outline_size = 6
		l.outline_modulate = Palette.INK
		l.modulate = Palette.GOLD_LIGHT if p.level > 0 else Palette.IVORY
		l.pixel_size = 0.0021
		l.shaded = false
		l.double_sided = true
		l.position = Vector3(cos(a0 + span * 0.5) * LABEL_R, Y_POCKET + 0.022, sin(a0 + span * 0.5) * LABEL_R)
		_pockets_root.add_child(l)
		_labels.append(l)
		if p.seal != &"":
			var seal: MeshInstance3D = MeshInstance3D.new()
			var ss: SphereMesh = SphereMesh.new()
			ss.radius = 0.016
			ss.height = 0.02
			seal.mesh = ss
			var sm: StandardMaterial3D = _mat(PocketInfo.seal_color(p.seal), 0.8, 0.25)
			sm.emission_enabled = true
			sm.emission = PocketInfo.seal_color(p.seal)
			sm.emission_energy_multiplier = 0.6
			seal.material_override = sm
			seal.position = Vector3(cos(a0 + span * 0.5) * SEAL_R, Y_POCKET + 0.02, sin(a0 + span * 0.5) * SEAL_R)
			_pockets_root.add_child(seal)
		# Bande de visée (sur l'anneau doré) et barre de probabilité (bord intérieur).
		var zm: StandardMaterial3D = _unshaded(Color(Palette.CYAN, 0.0))
		zm.emission_enabled = true
		var zone: MeshInstance3D = _sector(R_POCKET_OUT + 0.002, R_RIM_OUT, Y_RIM + 0.003, Y_RIM + 0.004, a0, a1, zm)
		_pockets_root.add_child(zone)
		_zone_mats.append(zm)
		_zone_nodes.append(zone)
		var pm: StandardMaterial3D = _unshaded(Color(Palette.EMERALD, 0.85))
		var py: float = Y_POCKET + 0.03
		var pr: MeshInstance3D = _sector(R_POCKET_IN - 0.06, R_POCKET_IN - 0.005, py, py, a0 + span * 0.15, a1 - span * 0.15, pm)
		pr.visible = false
		_pockets_root.add_child(pr)
		_prob_nodes.append(pr)


## Secteur d'anneau (dessus plat incliné de y0 à y1 vers l'extérieur, plus la face avant).
func _sector(r0: float, r1: float, y0: float, y1: float, a0: float, a1: float, mat: Material) -> MeshInstance3D:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in SECTOR_STEPS:
		var b0: float = lerpf(a0, a1, float(k) / float(SECTOR_STEPS))
		var b1: float = lerpf(a0, a1, float(k + 1) / float(SECTOR_STEPS))
		var i0: Vector3 = Vector3(cos(b0) * r0, y0, sin(b0) * r0)
		var i1: Vector3 = Vector3(cos(b1) * r0, y0, sin(b1) * r0)
		var o0: Vector3 = Vector3(cos(b0) * r1, y1, sin(b0) * r1)
		var o1: Vector3 = Vector3(cos(b1) * r1, y1, sin(b1) * r1)
		_quad(st, i0, o0, o1, i1, Vector2.ZERO, Vector2.ONE)
		var d0: Vector3 = Vector3(cos(b0) * r0, y0 - 0.02, sin(b0) * r0)
		var d1: Vector3 = Vector3(cos(b1) * r0, y0 - 0.02, sin(b1) * r0)
		_quad(st, d0, i0, i1, d1, Vector2.ZERO, Vector2.ONE)
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


# --------------------------------------------------------------------------- synchronisation


## Hauteur de la piste à un rayon donné (la bille roule sur la pente du coffre).
func _track_y(r: float) -> float:
	if r >= R_RIM_OUT:
		return lerpf(Y_TRACK_IN, Y_TRACK_OUT, clampf((r - R_RIM_OUT) / (R_TRACK_OUT - R_RIM_OUT), 0.0, 1.0))
	if r >= R_POCKET_OUT:
		return Y_RIM
	return Y_POCKET


func to_3d(screen_angle: float, r: float, y: float) -> Vector3:
	return Vector3(cos(screen_angle) * r, y, sin(screen_angle) * r)


## Recopie l'état de WheelView (appelé à chaque image).
func sync(v: WheelView, delta: float) -> void:
	if wheel == null:
		return
	_time += delta
	if size != _framed_size:
		_frame_camera()
	var sig: String = _wheel_signature()
	if sig != _signature:
		_signature = sig
		_rebuild_pockets()
	var n: int = wheel.size()
	# Angle écran de la case i = rotation + (i + 0,5)·pas − π/2 ; le rotor 3D tourne de même.
	_rotor.rotation.y = -(v.rotation_angle - PI * 0.5)
	var flat: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	for l: Label3D in _labels:
		l.global_basis = flat
	for sp: Sprite3D in _icons:
		sp.global_basis = flat
	var zone: Dictionary[int, float] = {}
	var center_idx: int = v.aim_index if v.aiming else v.locked_index
	if center_idx >= 0:
		var half: int = v.zone_width / 2
		for o: int in range(-half, half + 1):
			zone[posmod(center_idx + o, n)] = 0.85 if o == 0 else 0.45
	var pmax: float = 0.0
	for x: float in v.probabilities:
		pmax = maxf(pmax, x)
	for i: int in mini(n, _pocket_mats.size()):
		var p: Pocket = wheel.at(i)
		var col: Color = _base_colors[i]
		if v.highlight_numbers.has(p.number):
			col = col.lightened(0.22)
		if i == v.hover_index:
			col = col.lightened(0.3)
		if i == v.flash_index and v.flash_amount() > 0.0:
			col = col.lerp(Palette.GOLD_LIGHT, v.flash_amount() * 0.8)
		_pocket_mats[i].albedo_color = col
		if p.edition != &"":
			_pocket_mats[i].emission_energy_multiplier = 0.25 + 0.25 * sin(_time * 4.0 + float(i))
		var zm: StandardMaterial3D = _zone_mats[i]
		if zone.has(i):
			var zc: Color = Palette.GOLD_LIGHT if v.highlight_numbers.has(p.number) else Palette.CYAN
			zm.albedo_color = Color(zc, zone[i])
		else:
			zm.albedo_color = Color(Palette.CYAN, 0.0)
		var show_p: bool = not v.probabilities.is_empty() and i < v.probabilities.size() and not v.is_ball_active()
		_prob_nodes[i].visible = show_p and v.probabilities[i] > 0.0
		if show_p:
			var share: float = v.probabilities[i] / maxf(pmax, 0.0001)
			(_prob_nodes[i].material_override as StandardMaterial3D).albedo_color = Color(Palette.EMERALD, 0.25 + 0.7 * share)
	_pointer.visible = v.aiming
	if v.aiming:
		_pointer.position.y = Y_TRACK_OUT + 0.12 + 0.015 * sin(_time * 6.0)
	_sync_ball(v)
	_sync_camera(v, delta)


func _sync_ball(v: WheelView) -> void:
	var show: bool = v.is_ball_active() or v.is_ball_resting()
	_ball.visible = show
	if not show:
		for g: MeshInstance3D in _trail:
			g.visible = false
		return
	var pos: Vector3 = ball_position(v)
	var prev: Vector3 = _ball.position
	_ball.position = pos
	_ball.rotate_y(-0.4)
	for k: int in range(TRAIL - 1, 0, -1):
		_trail[k].position = _trail[k - 1].position
		_trail[k].visible = v.is_ball_active() and JuiceProfile.intensity() > 0.0
	_trail[0].position = prev
	_trail[0].visible = v.is_ball_active() and JuiceProfile.intensity() > 0.0


func ball_position(v: WheelView) -> Vector3:
	var r: float = v.ball_radius_ratio()
	var a: float = v.ball_screen_angle()
	if v.is_ball_resting():
		a = v.pocket_angle(v.ball_landing())
		r = (R_POCKET_IN + R_POCKET_OUT) * 0.5 + 0.06
	var lift: float = maxf(r - (R_POCKET_IN + R_POCKET_OUT) * 0.5 - 0.06, 0.0) if r < R_POCKET_OUT else 0.0
	return to_3d(a, r, _track_y(r) + BALL_R + lift * 0.8 + v.ball_bounce())


func _sync_camera(v: WheelView, delta: float) -> void:
	var dive: float = 0.0
	var aim_pt: Vector3 = Vector3.ZERO
	if v.is_ball_active():
		dive = smoothstep(0.62, 1.0, v.ball_progress()) * JuiceProfile.intensity()
		aim_pt = _ball.position * 0.35
	elif v.is_ball_resting():
		aim_pt = _ball.position * 0.3
		dive = 0.5 * JuiceProfile.intensity()
	var want_fov: float = lerpf(CAM_FOV, CAM_FOV * CAM_DIVE_FOV, dive)
	_cam_fov = lerpf(_cam_fov, want_fov, clampf(delta * 3.0, 0.0, 1.0))
	_cam_target = _cam_target.lerp(aim_pt, clampf(delta * 2.5, 0.0, 1.0))
	if _land_t > 0.0:
		_land_t = maxf(_land_t - delta, 0.0)
	_land_light.light_energy = 3.0 * _land_t
	_land_light.position = _land_pos + Vector3(0, 0.15, 0)
	var sway: float = deg_to_rad(CAM_SWAY) * sin(_time * 0.35) * JuiceProfile.intensity()
	var el: float = deg_to_rad(CAM_ELEVATION)
	var dist: float = _cam_dist * (1.0 - CAM_LAND_PUNCH * _land_t)
	var dir: Vector3 = Vector3(sin(sway), sin(el), cos(el) * cos(sway)).normalized()
	# Le conteneur déborde du cadre (BLEED) : champ élargi d'autant, la roue garde sa taille.
	var widen: float = size.y / maxf(inner_size().y, 1.0)
	camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_cam_fov) * 0.5) * widen))
	camera.position = _cam_target + dir * dist
	camera.look_at(_cam_target, Vector3.UP)


## Coup de lumière et petite poussée de caméra quand la bille se pose.
func land_flash() -> void:
	_land_t = 1.0
	_land_pos = _ball.position


## Cadre la roue entière dans le rectangle (aucun débordement quelle que soit la taille).
func _frame_camera() -> void:
	_framed_size = size
	var inner: Vector2 = inner_size()
	var aspect: float = inner.x / maxf(inner.y, 1.0)
	var vfov: float = deg_to_rad(CAM_FOV)
	var hfov: float = 2.0 * atan(tan(vfov * 0.5) * aspect)
	var el: float = deg_to_rad(CAM_ELEVATION)
	# Demi-étendues apparentes du coffre : largeur = rayon, hauteur ≈ rayon·sin(élévation) + relief.
	var half_w: float = R_CABINET * CAM_FIT
	var half_h: float = (R_CABINET * sin(el) + Y_CABINET * cos(el)) * CAM_FIT
	_cam_dist = maxf(half_w / tan(hfov * 0.5), half_h / tan(vfov * 0.5))


# --------------------------------------------------------------------------- écran ↔ roue


## Taille du cadre de la roue (le conteneur déborde de BLEED de chaque côté pour que le coffre
## ne soit jamais coupé net ; l'interface passe par-dessus).
func inner_size() -> Vector2:
	return (size - Vector2(BLEED, BLEED) * 2.0).max(Vector2.ONE)


## Position écran (locale au cadre de la roue) d'un point 3D.
func project(p: Vector3) -> Vector2:
	if camera == null or not is_inside_tree():
		return inner_size() * 0.5
	return camera.unproject_position(p) * (size / Vector2(_vp.size).max(Vector2.ONE)) - Vector2(BLEED, BLEED)


## Rayon et angle écran du point du plan des cases sous `local` ; null hors de la roue.
func pick(local: Vector2) -> Vector2:
	if camera == null or not is_inside_tree():
		return Vector2(-1, 0)
	var vp_pt: Vector2 = (local + Vector2(BLEED, BLEED)) * (Vector2(_vp.size) / size.max(Vector2.ONE))
	var origin: Vector3 = camera.project_ray_origin(vp_pt)
	var dir: Vector3 = camera.project_ray_normal(vp_pt)
	if absf(dir.y) < 0.0001:
		return Vector2(-1, 0)
	var t: float = (Y_POCKET - origin.y) / dir.y
	var hit: Vector3 = origin + dir * t
	return Vector2(Vector2(hit.x, hit.z).length(), atan2(hit.z, hit.x))
