class_name CabaretSet
extends RefCounted
## Décor commun du Cabaret (2.0, salle 6 du Musée) : rideaux de velours plissés, lambrequin doré,
## éventail art déco au fond, plancher de scène, rampe d'ampoules et public attablé en
## silhouettes au premier plan (lampes de table allumées). Cosmétique pur, construit en code
## pour une caméra frontale (`Stage3D.frontal`) : coordonnées en pixels de la maquette 1920×1080.

const FOLDS: int = 14
const FOOTLIGHTS: int = 18
const FAN_RAYS: int = 13
const TABLES: int = 5
const VELVET: Color = Color(0.42, 0.04, 0.09)
const BACK: Color = Color("12060c")
const PLANK_A: Color = Color("4a2a16")
const PLANK_B: Color = Color("3e2412")
const SILHOUETTE: Color = Color("07040a")
const SKINS: Array[Color] = [Color("e8b896"), Color("c68e64"), Color("8d5a3c"), Color("f0c8a8")]


## Monte le décor. `floor_y` : ligne du plancher (pixels) ; `opening` : demi-largeur de scène
## entre les rideaux ; `audience` : silhouettes du public au premier plan.
static func build(st: Stage3D, floor_y: float, opening: float = 640.0, audience: bool = true) -> Dictionary:
	var r: Node3D = st.root
	var px: float = st.px3
	st.env.background_color = Color("0a0306")
	st.env.ambient_light_color = Color(0.45, 0.2, 0.25)
	st.env.ambient_light_energy = 0.3
	st.key.light_energy = 0.2
	# Fond : mur sombre, éventail art déco doré.
	Stage3D.box(r, Vector3(40.0, 12.0, 0.05), st.to3(Vector2(960.0, 400.0), -2.0), Stage3D.mat(BACK, 0.0, 0.9))
	var gold: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.6, 0.35)
	var fan_c: Vector3 = st.to3(Vector2(960.0, floor_y - 40.0), -1.9)
	for k: int in FAN_RAYS:
		var a: float = PI * (0.08 + 0.84 * float(k) / float(FAN_RAYS - 1))
		var ray: MeshInstance3D = Stage3D.box(r, Vector3(6.0 * px, 620.0 * px, 0.01), fan_c, gold)
		ray.rotation.z = a - PI * 0.5
		ray.position = fan_c + Vector3(cos(a), sin(a), 0) * 310.0 * px
	for k2: int in 3:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = (200.0 + 160.0 * float(k2)) * px
		tm.outer_radius = tm.inner_radius + 7.0 * px
		ring.mesh = tm
		ring.material_override = gold
		ring.rotation.x = PI * 0.5
		ring.position = fan_c
		r.add_child(ring)
	# Rideaux plissés de part et d'autre, lambrequin et franges dorées en haut.
	var velvet: StandardMaterial3D = Stage3D.mat(VELVET, 0.0, 0.75)
	var velvet_d: StandardMaterial3D = Stage3D.mat(VELVET.darkened(0.35), 0.0, 0.8)
	for side: float in [-1.0, 1.0]:
		for k3: int in FOLDS:
			var x: float = 960.0 + side * (opening + float(k3) * 64.0)
			Stage3D.cylinder(r, 40.0 * px, 1500.0 * px, st.to3(Vector2(x, 360.0), -0.8 - 0.06 * float(k3 % 2)),
				velvet if k3 % 2 == 0 else velvet_d)
		Stage3D.cylinder(r, 9.0 * px, 70.0 * px, st.to3(Vector2(960.0 + side * (opening + 20.0), 560.0), -0.7), gold)
	for k4: int in 34:
		var vx: float = -700.0 + float(k4) * 100.0
		Stage3D.cylinder(r, 52.0 * px, 130.0 * px, st.to3(Vector2(vx, 30.0), -0.5), velvet)
	Stage3D.box(r, Vector3(40.0, 14.0 * px, 0.06), st.to3(Vector2(960.0, 100.0), -0.45), gold)
	for k5: int in 60:
		Stage3D.box(r, Vector3(5.0 * px, 26.0 * px, 0.01), st.to3(Vector2(-500.0 + float(k5) * 50.0, 120.0), -0.42), gold)
	# Plancher de scène, nez de scène doré, rampe d'ampoules.
	var pa: StandardMaterial3D = Stage3D.mat(PLANK_A, 0.0, 0.45)
	var pb: StandardMaterial3D = Stage3D.mat(PLANK_B, 0.0, 0.45)
	var base: Vector3 = st.to3(Vector2(960.0, floor_y), 0.0)
	for k6: int in 8:
		Stage3D.box(r, Vector3(30.0, 0.04, 0.34), base + Vector3(0, -0.02, -2.0 + 0.36 * float(k6)), pa if k6 % 2 == 0 else pb)
	Stage3D.box(r, Vector3(30.0, 0.5, 0.06), base + Vector3(0, -0.27, 0.9), Stage3D.mat(Color("1a0c08"), 0.0, 0.7))
	Stage3D.box(r, Vector3(30.0, 0.03, 0.08), base + Vector3(0, -0.01, 0.9), gold)
	var bulb: StandardMaterial3D = Stage3D.glow(Palette.GOLD_LIGHT, 2.5)
	for k7: int in FOOTLIGHTS:
		var fx: float = 960.0 - 900.0 + 1800.0 * float(k7) / float(FOOTLIGHTS - 1)
		Stage3D.sphere(r, 11.0 * px, st.to3(Vector2(fx, floor_y), 0.0) + Vector3(0, 0.03, 0.82), bulb)
	var foot: OmniLight3D = Stage3D.omni(r, Color(1.0, 0.8, 0.5), 1.3, base + Vector3(0, 0.5, 1.4), 6.0)
	var out: Dictionary = {"floor": base, "footlight": foot}
	if audience:
		out["audience"] = _audience(st, floor_y)
	return out


## Public attablé au premier plan : têtes et épaules en contre-jour, lampes de table allumées.
## Rend la liste des têtes (elles hochent la tête au rythme : `bob_audience`).
static func _audience(st: Stage3D, floor_y: float) -> Array[Node3D]:
	var r: Node3D = st.root
	var px: float = st.px3
	var sil: StandardMaterial3D = Stage3D.mat(SILHOUETTE, 0.0, 0.9)
	sil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # contre-jour : pures silhouettes
	var heads: Array[Node3D] = []
	var lamp: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.72, 0.4), 2.2)
	var shade: StandardMaterial3D = Stage3D.mat(Color(0.5, 0.08, 0.1), 0.0, 0.6)
	for k: int in TABLES:
		var tx: float = 160.0 + 1600.0 * float(k) / float(TABLES - 1)
		var at: Vector3 = st.to3(Vector2(tx, floor_y + 200.0), 1.4)
		Stage3D.cylinder(r, 90.0 * px, 10.0 * px, at, Stage3D.mat(Color("1a0e0a"), 0.0, 0.5))
		Stage3D.cylinder(r, 6.0 * px, 40.0 * px, at + Vector3(0, 25.0 * px, 0), Stage3D.mat(Palette.GOLD_DARK, 0.7, 0.3))
		Stage3D.cylinder(r, 22.0 * px, 26.0 * px, at + Vector3(0, 55.0 * px, 0), shade, 12.0 * px)
		Stage3D.sphere(r, 9.0 * px, at + Vector3(0, 45.0 * px, 0), lamp)
		Stage3D.omni(r, Color(1.0, 0.6, 0.35), 0.5, at + Vector3(0, 60.0 * px, 0.1), 1.2)
		for s: float in [-1.0, 1.0]:
			var h: Node3D = Node3D.new()
			h.position = at + Vector3(s * 120.0 * px, 0, 0.15)
			r.add_child(h)
			var body: MeshInstance3D = MeshInstance3D.new()
			body.mesh = MeshPool.capsule(44.0 * px, 130.0 * px)
			body.material_override = sil
			body.position = Vector3(0, 20.0 * px, 0)
			h.add_child(body)
			Stage3D.sphere(h, 27.0 * px, Vector3(0, 100.0 * px, 0), sil)
			heads.append(h)
	return heads


## Le public hoche la tête (cosmétique) : `beat` en tours de mesure, `amount` 0..1.
static func bob_audience(heads: Array[Node3D], beat: float, amount: float) -> void:
	for k: int in heads.size():
		heads[k].rotation.x = sin(beat * TAU + float(k) * 1.7) * 0.08 * amount
		heads[k].rotation.z = sin(beat * PI + float(k)) * 0.04 * amount


## Poursuite : spot qui suit un point (pixels), avec son cône de lumière visible.
static func follow_spot(st: Stage3D, energy: float = 6.0, angle: float = 14.0) -> Dictionary:
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = Color(1.0, 0.95, 0.82)
	spot.light_energy = energy
	spot.spot_range = 14.0
	spot.spot_angle = angle
	spot.shadow_enabled = RenderQuality.shadows()
	spot.position = st.to3(Vector2(960.0, -260.0), 3.0)
	st.root.add_child(spot)
	var cone: MeshInstance3D = MeshInstance3D.new()
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 1.0
	cm.height = 1.0
	cone.mesh = cm
	var beam: StandardMaterial3D = Stage3D.glow(Color(1.0, 0.95, 0.75), 0.4)
	beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam.albedo_color.a = 0.03
	beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = beam
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	st.root.add_child(cone)
	return {"spot": spot, "cone": cone}


## Oriente la poursuite `fs` (follow_spot) vers `target` (3D) avec un rayon au sol `radius` (m).
static func aim_spot(fs: Dictionary, target: Vector3, radius: float) -> void:
	var spot: SpotLight3D = fs["spot"] as SpotLight3D
	var cone: MeshInstance3D = fs["cone"] as MeshInstance3D
	var from: Vector3 = spot.position
	var d: Vector3 = target - from
	var dist: float = d.length()
	spot.look_at_from_position(from, target, Vector3.UP)
	spot.spot_angle = rad_to_deg(atan2(radius * 1.15, dist))
	var y: Vector3 = -d.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z: Vector3 = x.cross(y)
	cone.transform = Transform3D(Basis(x * radius, y * dist, z * radius), (from + target) * 0.5)
