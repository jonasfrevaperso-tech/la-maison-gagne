class_name MuseumRoom3D
extends Stage3D
## Salle du Musée : galerie en enfilade, un piédestal par épreuve exposée (maquette ExhibitProps,
## cartel de laiton, projecteur), cordons de velours, boiseries aux couleurs de la salle.
## La caméra glisse d'objet en objet ; l'objet choisi s'éclaire et tourne doucement.

## Écart entre deux piédestaux (m) et hauteur du plateau.
const SPACING: float = 1.7
const PEDESTAL_H: float = 0.95
const PEDESTAL_W: float = 0.7
const WALL_Z: float = -1.5
const CAM_HEIGHT: float = 2.0
const CAM_BACK: float = 3.7
const CAM_AIM_Y: float = 1.05
## Décalage de visée : l'objet choisi se tient à gauche du cartel.
const CAM_SHIFT: float = 0.55
## Projecteur : éclairage d'un objet au repos et choisi.
const SPOT_IDLE: float = 1.2
const SPOT_FOCUS: float = 3.6
const SPIN_SPEED: float = 0.35
const FOLLOW: float = 5.0
## Tableau au-dessus de chaque piédestal (carton illustré 160 × 100 de l'épreuve).
const ART_W: float = 0.96
const ART_H: float = 0.6
const ART_Y: float = 1.92
const ART_PATH: String = "res://assets/trials/trial_%s.png"

var exhibits: Array[String] = []
var focus: int = 0
var _props: Array[Node3D] = []
var _spots: Array[SpotLight3D] = []
var _cam_x: float = 0.0
var _room: Node3D = null


## Construit la salle `room` (entrée de data/museum/rooms.json).
func build_room(room: Dictionary) -> void:
	if _room != null:
		_room.queue_free()
	_room = Node3D.new()
	root.add_child(_room)
	_props.clear()
	_spots.clear()
	exhibits.clear()
	for e: Variant in room.get("exhibits", []):
		exhibits.append(String(e))
	var wall: Color = Color(String(room.get("wall", "2a1a20")))
	var floor_c: Color = Color(String(room.get("floor", "1a1010")))
	var accent: Color = Color(String(room.get("accent", "d4af37")))
	env.background_color = wall.darkened(0.7)
	env.ambient_light_color = wall.lightened(0.3)
	env.ambient_light_energy = 0.35
	key.light_energy = 0.25
	var span: float = SPACING * float(maxi(exhibits.size() - 1, 0))
	var w: float = span + 8.0
	_build_shell(w, span * 0.5, wall, floor_c, accent)
	for k: int in exhibits.size():
		_build_exhibit(k, Vector3(SPACING * float(k), 0, 0))
	for k3: int in 3:
		Stage3D.omni(_room, wall.lightened(0.5), 0.6, Vector3(span * float(k3) / 2.0, 2.6, 0.4), span * 0.5 + 3.0)
	focus = clampi(focus, 0, maxi(exhibits.size() - 1, 0))
	_cam_x = _x_of(focus)
	_place_cam()


func _x_of(k: int) -> float:
	return SPACING * float(k)


func _build_shell(w: float, cx: float, wall: Color, floor_c: Color, accent: Color) -> void:
	var wm: StandardMaterial3D = Stage3D.mat(wall, 0.0, 0.85)
	var panel: StandardMaterial3D = Stage3D.textured("wood", wall.darkened(0.1).lightened(0.25), 0.9, 0.0, 0.8)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.75, 0.3)
	# Sol en damier, mur du fond, plinthe, cimaise et lambris.
	var tiles: int = int(ceil(w / 0.8))
	var fa: StandardMaterial3D = Stage3D.textured("marble", floor_c.lightened(0.5), 1.6, 0.0, 0.6)
	var fb: StandardMaterial3D = Stage3D.textured("marble", floor_c.lightened(0.62), 1.6, 0.0, 0.6)
	for i: int in tiles:
		for j: int in 6:
			Stage3D.box(_room, Vector3(0.8, 0.02, 0.8), Vector3(cx - w * 0.5 + 0.4 + 0.8 * float(i), -0.01, WALL_Z + 0.4 + 0.8 * float(j)),
				fa if (i + j) % 2 == 0 else fb)
	Stage3D.box(_room, Vector3(w, 5.0, 0.1), Vector3(cx, 2.5, WALL_Z - 0.05), wm)
	Stage3D.box(_room, Vector3(w, 1.0, 0.04), Vector3(cx, 0.5, WALL_Z + 0.02), panel)
	Stage3D.box(_room, Vector3(w, 0.05, 0.06), Vector3(cx, 1.02, WALL_Z + 0.03), brass)
	Stage3D.box(_room, Vector3(w, 0.12, 0.05), Vector3(cx, 0.06, WALL_Z + 0.04), Stage3D.mat(wall.darkened(0.6), 0.0, 0.6))
	Stage3D.box(_room, Vector3(w, 0.1, 0.08), Vector3(cx, 3.4, WALL_Z + 0.04), brass)
	# Au-dessus de chaque piédestal, le carton illustré de l'épreuve dans un cadre doré à gorge ;
	# entre deux piédestaux, un pilastre de bois et une applique à globe.
	for k: int in exhibits.size():
		var x: float = SPACING * float(k)
		var frame: MeshInstance3D = Stage3D.box(_room, Vector3(ART_W + 0.16, ART_H + 0.16, 0.05), Vector3(x, ART_Y, WALL_Z + 0.03), brass)
		Stage3D.box(frame, Vector3(ART_W + 0.06, ART_H + 0.06, 0.02), Vector3(0, 0, 0.02), Stage3D.mat(wall.darkened(0.7), 0.0, 0.8))
		var canvas: MeshInstance3D = Stage3D.box(frame, Vector3(ART_W, ART_H, 0.01), Vector3(0, 0, 0.035), _art_mat(exhibits[k], accent))
		canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Stage3D.box(_room, Vector3(0.22, 0.03, 0.12), Vector3(x, ART_Y + ART_H * 0.5 + 0.16, WALL_Z + 0.08), brass)
		Stage3D.box(_room, Vector3(0.3, 0.02, 0.02), Vector3(x, ART_Y + ART_H * 0.5 + 0.15, WALL_Z + 0.15), Stage3D.glow(Palette.GOLD_LIGHT, 1.2))
	for k4: int in exhibits.size() + 1:
		var px2: float = SPACING * (float(k4) - 0.5)
		Stage3D.box(_room, Vector3(0.22, 2.3, 0.08), Vector3(px2, 2.2, WALL_Z + 0.04), panel)
		Stage3D.box(_room, Vector3(0.28, 0.08, 0.1), Vector3(px2, 3.3, WALL_Z + 0.05), brass)
		Stage3D.box(_room, Vector3(0.28, 0.08, 0.1), Vector3(px2, 1.08, WALL_Z + 0.05), brass)
		Stage3D.box(_room, Vector3(0.04, 0.18, 0.12), Vector3(px2, 2.45, WALL_Z + 0.1), brass)
		Stage3D.sphere(_room, 0.07, Vector3(px2, 2.62, WALL_Z + 0.16), Stage3D.glow(Color(1.0, 0.86, 0.62), 2.0))
	# Tapis de couloir à la couleur de la salle, bordé d'or, devant les cordons.
	Stage3D.box(_room, Vector3(w, 0.012, 0.9), Vector3(cx, 0.006, 1.45), Stage3D.textured("felt", accent.darkened(0.6).lerp(wall, 0.4), 2.0))
	for sz: float in [1.0, 1.9]:
		Stage3D.box(_room, Vector3(w, 0.014, 0.04), Vector3(cx, 0.007, sz), Stage3D.mat(Palette.GOLD_DARK, 0.5, 0.4))
	# Néon d'accent sous la corniche et cordons de velours devant les piédestaux.
	Stage3D.box(_room, Vector3(w, 0.025, 0.025), Vector3(cx, 3.3, WALL_Z + 0.1), Stage3D.glow(accent, 1.4))
	var velvet: StandardMaterial3D = Stage3D.mat(Palette.VELVET.lightened(0.1), 0.0, 0.8)
	for k2: int in exhibits.size() + 1:
		var px: float = SPACING * (float(k2) - 0.5)
		Stage3D.cylinder(_room, 0.025, 0.85, Vector3(px, 0.425, 0.75), brass)
		Stage3D.sphere(_room, 0.04, Vector3(px, 0.87, 0.75), brass)
		if k2 < exhibits.size():
			for s: int in 6:
				var u: float = (float(s) + 0.5) / 6.0
				var sag: float = 0.12 * sin(PI * u)
				var seg: MeshInstance3D = Stage3D.cylinder(_room, 0.018, SPACING / 6.0 + 0.01, Vector3(px + SPACING * u, 0.8 - sag, 0.75),
					velvet)
				seg.rotation.z = PI * 0.5 - 0.2 * cos(PI * u)


func _build_exhibit(k: int, at: Vector3) -> void:
	# Socle de marbre veiné : plinthe sombre, fût, bagues de laiton, plateau débordant.
	var stone: StandardMaterial3D = Stage3D.textured("stone", Color(0.92, 0.9, 0.86), 0.9, 0.0, 0.3)
	var base: StandardMaterial3D = Stage3D.textured("stone", Color(0.3, 0.27, 0.27), 0.9, 0.0, 0.25)
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD_DARK, 0.45, 0.3)
	var ring: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.85, 0.25)
	Stage3D.box(_room, Vector3(PEDESTAL_W + 0.14, 0.12, PEDESTAL_W + 0.14), at + Vector3(0, 0.06, 0), base)
	Stage3D.box(_room, Vector3(PEDESTAL_W, PEDESTAL_H - 0.2, PEDESTAL_W), at + Vector3(0, PEDESTAL_H * 0.5 + 0.02, 0), stone)
	for ry: float in [0.15, PEDESTAL_H - 0.1]:
		Stage3D.box(_room, Vector3(PEDESTAL_W + 0.03, 0.025, PEDESTAL_W + 0.03), at + Vector3(0, ry, 0), ring)
	Stage3D.box(_room, Vector3(PEDESTAL_W + 0.1, 0.06, PEDESTAL_W + 0.1), at + Vector3(0, PEDESTAL_H - 0.03, 0), base)
	var plaque: MeshInstance3D = Stage3D.box(_room, Vector3(0.44, 0.12, 0.01),
		at + Vector3(0, PEDESTAL_H * 0.62, PEDESTAL_W * 0.5 + 0.005), brass)
	var name_l: Label3D = Stage3D.text3d(plaque, Localization.name_of("throw_trials", exhibits[k]), Vector3(0, 0, 0.008), 26, Palette.INK,
		Palette.GOLD_LIGHT)
	name_l.outline_size = 0
	name_l.pixel_size = 0.0017
	name_l.width = 250.0
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var holder: Node3D = Node3D.new()
	holder.position = at + Vector3(0, PEDESTAL_H, 0)
	_room.add_child(holder)
	holder.add_child(ExhibitProps.build(exhibits[k]))
	_props.append(holder)
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = Color(1.0, 0.92, 0.78)
	spot.light_energy = SPOT_IDLE
	spot.spot_range = 5.0
	spot.spot_angle = 22.0
	spot.position = at + Vector3(0, 3.6, 1.2)
	spot.shadow_enabled = RenderQuality.shadows() and k == focus
	_room.add_child(spot)
	spot.look_at_from_position(spot.position, at + Vector3(0, PEDESTAL_H + 0.3, 0), Vector3.UP)
	_spots.append(spot)


## Matériau du tableau : le carton de l'épreuve en pixels nets, légèrement lumineux pour rester
## lisible dans la pénombre ; à défaut, une toile à la couleur d'accent.
static func _art_mat(id: String, accent: Color) -> StandardMaterial3D:
	var path: String = ART_PATH % id
	if not ResourceLoader.exists(path):
		return Stage3D.mat(accent.darkened(0.6), 0.0, 0.9)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load(path) as Texture2D
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.7
	m.emission_enabled = true
	m.emission_texture = m.albedo_texture
	m.emission_energy_multiplier = 0.35
	return m


## Choisit l'objet `k` : la caméra s'en approche, son projecteur s'allume.
func set_focus(k: int) -> void:
	focus = clampi(k, 0, maxi(exhibits.size() - 1, 0))
	for i: int in _spots.size():
		_spots[i].shadow_enabled = RenderQuality.shadows() and i == focus


func _place_cam() -> void:
	cam.fov = 42.0
	cam.position = Vector3(_cam_x + CAM_SHIFT, CAM_HEIGHT, CAM_BACK)
	cam.look_at_from_position(cam.position, Vector3(_cam_x + CAM_SHIFT, CAM_AIM_Y, 0), Vector3.UP)


func _process(delta: float) -> void:
	if exhibits.is_empty():
		return
	_cam_x = lerpf(_cam_x, _x_of(focus), 1.0 - exp(-FOLLOW * delta))
	_place_cam()
	for i: int in _props.size():
		var target: float = SPOT_FOCUS if i == focus else SPOT_IDLE
		_spots[i].light_energy = lerpf(_spots[i].light_energy, target, 1.0 - exp(-FOLLOW * delta))
		if i == focus:
			_props[i].rotation.y += SPIN_SPEED * delta
		else:
			_props[i].rotation.y = lerp_angle(_props[i].rotation.y, 0.0, 1.0 - exp(-2.0 * delta))
