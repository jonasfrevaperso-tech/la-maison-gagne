class_name GarageSet
extends RefCounted
## Décor commun du Garage (2.0, salle 10 du Musée) : parking souterrain du casino. Dalles de béton
## aux joints marqués et taches d'huile, piliers à bandes de sécurité jaune et noir, réglettes de
## néon (dont une qui grésille), mur du fond peint (« −2 », flèche, « P »), voitures des années 50
## construites en primitives (carrosserie bicolore, chromes, pneus à flanc blanc, roues
## directrices, feux stop et de recul qui s'allument), plots de chantier.
## Repère monde : sol y = 0, plan (x, z) ; une voiture regarde vers +x dans son repère local.

const SLAB: float = 2.5
const CONCRETE: Color = Color("4e4c48")
const CONCRETE_D: Color = Color("38362f")
const HAZARD: Color = Color("e8b820")
const NEON: Color = Color(0.82, 0.95, 1.0)
const CAR_COLORS: Array[Color] = [Color("8a1a24"), Color("1a3a6a"), Color("2a5a3a"), Color("e8dcc0"), Color("1a1a1e"),
	Color("6a9ab0"), Color("c87a2a")]
## Gabarit d'une berline (mètres) : longueur, largeur, empattement, porte-à-faux arrière.
const CAR_LEN: float = 4.4
const CAR_W: float = 1.8
const WHEELBASE: float = 2.7
const REAR_OVERHANG: float = 0.85
const WHEEL_R: float = 0.33


## Monte le parking autour de `center` sur `size` (mètres). `pillars` : positions (x, z) des
## piliers ; `wall_z` : mur du fond (INF = aucun). Rend {"tubes": Array, "lights": Array}.
static func build(st: Stage3D, center: Vector3, size: Vector2, pillars: Array[Vector2] = [], wall_z: float = INF) -> Dictionary:
	var r: Node3D = st.root
	st.env.background_color = Color("06080a")
	st.env.ambient_light_color = Color(0.7, 0.85, 0.9)
	st.env.ambient_light_energy = 0.3
	st.key.light_energy = 0.35
	st.key.light_color = Color(0.85, 0.95, 1.0)
	# Dalles de béton (instance multiple, teintes voisines), joints sombres en dessous.
	Stage3D.box(r, Vector3(size.x + 4.0, 0.02, size.y + 4.0), center + Vector3(0, -0.02, 0), Stage3D.mat(Color("2a2826"), 0.0, 1.0))
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	var nx: int = int(ceil((size.x + 4.0) / SLAB))
	var nz: int = int(ceil((size.y + 4.0) / SLAB))
	for i: int in nx:
		for j: int in nz:
			var at: Vector3 = center + Vector3((float(i) - float(nx - 1) * 0.5) * SLAB, -0.005, (float(j) - float(nz - 1) * 0.5) * SLAB)
			xf.append(Transform3D(Basis.IDENTITY, at))
			cols.append(CONCRETE.lerp(CONCRETE_D, float((i * 7 + j * 13) % 6) / 8.0))
	var slabs: MultiMeshInstance3D = KitchenSet.multi(r, Vector3(SLAB - 0.03, 0.02, SLAB - 0.03), xf, cols, 0.85)
	(slabs.material_override as StandardMaterial3D).vertex_color_is_srgb = true
	# Taches d'huile : disques sombres semi-transparents (positions fixes, purement décoratives).
	var oil: StandardMaterial3D = Stage3D.mat(Color(0.04, 0.04, 0.045, 0.5), 0.0, 0.7)
	oil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k: int in 9:
		var ox: float = sin(float(k) * 2.39) * size.x * 0.45
		var oz: float = cos(float(k) * 1.71) * size.y * 0.45
		var stain: MeshInstance3D = Stage3D.cylinder(r, 0.25 + 0.12 * float(k % 3), 0.002, center + Vector3(ox, 0.012, oz), oil)
		stain.scale = Vector3(1.0 + 0.4 * float(k % 2), 1.0, 0.8)
		stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for pp: Vector2 in pillars:
		pillar(r, Vector3(pp.x, center.y, pp.y))
	if wall_z != INF:
		_wall(r, center, size, wall_z)
	var out: Dictionary = {"tubes": [] as Array[MeshInstance3D], "lights": [] as Array[OmniLight3D]}
	for k2: int in 3:
		var lx: float = center.x + (float(k2) - 1.0) * size.x * 0.33
		var tube_at: Vector3 = Vector3(lx, center.y + 3.4, center.z - size.y * 0.15)
		out["tubes"].append(Stage3D.box(r, Vector3(1.4, 0.05, 0.08), tube_at, Stage3D.glow(NEON, 3.0)))
		Stage3D.box(r, Vector3(1.5, 0.04, 0.16), tube_at + Vector3(0, 0.05, 0), Stage3D.mat(Color("8a8a8a"), 0.6, 0.4))
		out["lights"].append(Stage3D.omni(r, NEON, 0.9, tube_at + Vector3(0, -0.3, 0), 8.0))
	return out


## Pilier carré de béton, bandes de sécurité jaune et noir au pied, numéro de travée.
static func pillar(r: Node3D, at: Vector3, label: String = "") -> void:
	Stage3D.box(r, Vector3(0.55, 3.6, 0.55), at + Vector3(0, 1.8, 0), Stage3D.mat(Color("8a8880"), 0.0, 0.9))
	for k: int in 4:
		var col: Color = HAZARD if k % 2 == 0 else Color("141414")
		Stage3D.box(r, Vector3(0.57, 0.2, 0.57), at + Vector3(0, 0.1 + 0.2 * float(k), 0), Stage3D.mat(col, 0.0, 0.6))
	if label != "":
		Stage3D.text3d(r, label, at + Vector3(0, 1.6, 0.29), 96, Palette.IVORY)


## Mur du fond : béton, bande verte peinte, « −2 » géant et flèche de sortie.
static func _wall(r: Node3D, center: Vector3, size: Vector2, wall_z: float) -> void:
	var w: float = size.x + 4.0
	var y: float = center.y
	Stage3D.box(r, Vector3(w, 3.6, 0.3), Vector3(center.x, y + 1.8, wall_z), Stage3D.mat(Color("7a7870"), 0.0, 0.95))
	Stage3D.box(r, Vector3(w, 0.5, 0.02), Vector3(center.x, y + 1.2, wall_z + 0.16), Stage3D.mat(Color("1e6a4a"), 0.0, 0.7))
	var lvl: Label3D = Stage3D.text3d(r, "−2", Vector3(center.x - size.x * 0.3, y + 2.3, wall_z + 0.17), 420, Color("e8dcc0"))
	lvl.outline_size = 0
	var exit_l: Label3D = Stage3D.text3d(r, "SORTIE →", Vector3(center.x + size.x * 0.25, y + 2.4, wall_z + 0.17), 160, HAZARD)
	exit_l.outline_size = 0


## Une berline des années 50. `col` : caisse ; le pavillon est crème. Rend un dictionnaire :
## "node" (Node3D, origine au centre de l'essieu arrière, regarde vers +x), "steer" (pivots des
## roues avant), "spin" (toutes les roues), "brake" et "reverse" (matériaux des feux).
static func car(col: Color, roof: Color = Color("e8dcc0")) -> Dictionary:
	var n: Node3D = Node3D.new()
	var body: Node3D = Node3D.new()
	body.position = Vector3(CAR_LEN * 0.5 - REAR_OVERHANG, 0, 0)  # centre de la caisse
	n.add_child(body)
	var paint: StandardMaterial3D = Stage3D.mat(col, 0.55, 0.22)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.7
	var top: StandardMaterial3D = Stage3D.mat(roof, 0.3, 0.3)
	var chrome: StandardMaterial3D = Stage3D.mat(Color("e8ecf0"), 1.0, 0.12)
	var glass: StandardMaterial3D = Stage3D.mat(Color(0.12, 0.18, 0.24), 0.6, 0.05)
	# Caisse : soubassement, ailes arrondies (cylindres couchés), capot et malle.
	Stage3D.box(body, Vector3(CAR_LEN, 0.42, CAR_W), Vector3(0, 0.55, 0), paint)
	for sz: float in [-1.0, 1.0]:
		var wing: MeshInstance3D = Stage3D.cylinder(body, 0.26, CAR_LEN - 0.3, Vector3(0, 0.6, sz * (CAR_W * 0.5 - 0.24)), paint)
		wing.rotation.z = PI * 0.5
		Stage3D.box(body, Vector3(CAR_LEN - 0.6, 0.04, 0.02), Vector3(0, 0.62, sz * (CAR_W * 0.5 + 0.005)), chrome)  # jonc
	Stage3D.box(body, Vector3(1.3, 0.1, CAR_W - 0.12), Vector3(1.4, 0.8, 0), paint)  # capot
	Stage3D.box(body, Vector3(0.9, 0.1, CAR_W - 0.12), Vector3(-1.65, 0.8, 0), paint)  # malle
	# Habitacle : vitres latérales sombres, pare-brise et lunette inclinés, pavillon crème.
	Stage3D.box(body, Vector3(1.5, 0.38, CAR_W - 0.24), Vector3(-0.25, 1.03, 0), glass)
	Stage3D.box(body, Vector3(1.25, 0.07, CAR_W - 0.2), Vector3(-0.25, 1.25, 0), top)
	for k: int in 2:
		var sx: float = 1.0 if k == 0 else -1.0
		var pane: MeshInstance3D = Stage3D.box(body, Vector3(0.62, 0.03, CAR_W - 0.3), Vector3(-0.25 + sx * 0.83, 1.04, 0), glass)
		pane.rotation.z = -sx * 0.72
		var pillar_a: MeshInstance3D = Stage3D.box(body, Vector3(0.62, 0.05, 0.06), Vector3(-0.25 + sx * 0.83, 1.05, 0), top)
		pillar_a.rotation.z = -sx * 0.72
	# Calandre et pare-chocs chromés, phares, feux.
	Stage3D.box(body, Vector3(0.06, 0.26, CAR_W * 0.7), Vector3(CAR_LEN * 0.5 + 0.01, 0.56, 0), chrome)
	for bx: float in [CAR_LEN * 0.5 + 0.06, -CAR_LEN * 0.5 - 0.06]:
		var bumper: MeshInstance3D = Stage3D.cylinder(body, 0.07, CAR_W + 0.04, Vector3(bx, 0.4, 0), chrome)
		bumper.rotation.x = PI * 0.5
	var brake: StandardMaterial3D = Stage3D.glow(Color(0.9, 0.05, 0.05), 0.6)
	var rev: StandardMaterial3D = Stage3D.glow(Color(0.95, 0.95, 0.9), 0.0)
	for sz2: float in [-1.0, 1.0]:
		var head_at: Vector3 = Vector3(CAR_LEN * 0.5 - 0.02, 0.66, sz2 * (CAR_W * 0.5 - 0.26))
		var lamp: MeshInstance3D = Stage3D.cylinder(body, 0.12, 0.06, head_at, Stage3D.glow(Color(1.0, 0.95, 0.75), 2.5))
		lamp.rotation.z = PI * 0.5
		var tail: MeshInstance3D = Stage3D.box(body, Vector3(0.05, 0.22, 0.14), Vector3(-CAR_LEN * 0.5, 0.64, sz2 * (CAR_W * 0.5 - 0.22)), brake)
		tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Stage3D.box(body, Vector3(0.05, 0.08, 0.1), Vector3(-CAR_LEN * 0.5, 0.48, sz2 * (CAR_W * 0.5 - 0.42)), rev)
	# Roues : pneu noir, flanc blanc, enjoliveur chromé ; les avant sur un pivot de direction.
	var steer: Array[Node3D] = []
	var spin: Array[Node3D] = []
	var tyre: StandardMaterial3D = Stage3D.mat(Color("141414"), 0.0, 0.85)
	var white: StandardMaterial3D = Stage3D.mat(Color("ece8dc"), 0.0, 0.6)
	for k: int in 4:
		var front: bool = k < 2
		var wz: float = (CAR_W * 0.5 - 0.2) * (1.0 if k % 2 == 0 else -1.0)
		var pivot: Node3D = Node3D.new()
		pivot.position = Vector3(WHEELBASE if front else 0.0, WHEEL_R, wz)
		n.add_child(pivot)
		var wheel: Node3D = Node3D.new()
		pivot.add_child(wheel)
		var t_mesh: MeshInstance3D = Stage3D.cylinder(wheel, WHEEL_R, 0.22, Vector3.ZERO, tyre)
		t_mesh.rotation.x = PI * 0.5
		var side: float = signf(wz)
		var ww: MeshInstance3D = Stage3D.cylinder(wheel, WHEEL_R * 0.8, 0.01, Vector3(0, 0, side * 0.112), white)
		ww.rotation.x = PI * 0.5
		var hub: MeshInstance3D = Stage3D.cylinder(wheel, WHEEL_R * 0.5, 0.02, Vector3(0, 0, side * 0.118), chrome)
		hub.rotation.x = PI * 0.5
		Stage3D.box(wheel, Vector3(WHEEL_R * 0.9, 0.04, 0.005), Vector3(0, 0, side * 0.13), Stage3D.mat(Color("8a8a8a"), 0.8, 0.3))
		spin.append(wheel)
		if front:
			steer.append(pivot)
	return {"node": n, "steer": steer, "spin": spin, "brake": brake, "reverse": rev, "paint": paint}


## Pose une voiture : position (x, z) de l'essieu arrière, cap `heading` (radians, 0 = +x,
## positif vers +z), braquage, rotation cumulée des roues, feux stop et de recul.
static func pose_car(c: Dictionary, at: Vector2, heading: float, steer: float = 0.0, roll: float = 0.0,
		braking: bool = false, reversing: bool = false) -> void:
	var n: Node3D = c["node"] as Node3D
	n.position = Vector3(at.x, 0.0, at.y)
	n.rotation.y = -heading
	for p: Node3D in c["steer"]:
		p.rotation.y = -steer
	for w: Node3D in c["spin"]:
		w.rotation.z = -roll
	(c["brake"] as StandardMaterial3D).emission_energy_multiplier = 3.5 if braking else 0.6
	(c["reverse"] as StandardMaterial3D).emission_energy_multiplier = 2.5 if reversing else 0.0


## Coins (plan x, z) de la caisse d'une voiture posée en `at` (essieu arrière), cap `heading`.
static func car_corners(at: Vector2, heading: float, grow: float = 0.0) -> PackedVector2Array:
	var f: Vector2 = Vector2.from_angle(heading)
	var s: Vector2 = f.orthogonal()
	var c: Vector2 = at + f * (CAR_LEN * 0.5 - REAR_OVERHANG)
	var hl: float = CAR_LEN * 0.5 + grow
	var hw: float = CAR_W * 0.5 + grow
	return PackedVector2Array([c + f * hl + s * hw, c + f * hl - s * hw, c - f * hl - s * hw, c - f * hl + s * hw])


## Plot de chantier orange à bandes blanches posé en `at`.
static func cone(r: Node3D, at: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = at
	r.add_child(n)
	Stage3D.box(n, Vector3(0.36, 0.03, 0.36), Vector3(0, 0.015, 0), Stage3D.mat(Color("c84a10"), 0.0, 0.7))
	Stage3D.cylinder(n, 0.15, 0.55, Vector3(0, 0.3, 0), Stage3D.mat(Color("ff6a1a"), 0.0, 0.5), 0.03)
	for k: int in 2:
		var ry: float = 0.22 + 0.16 * float(k)
		Stage3D.cylinder(n, 0.122 - 0.05 * float(k), 0.06, Vector3(0, ry, 0), Stage3D.mat(Color("f4f0e8"), 0.0, 0.4), 0.11 - 0.05 * float(k))
	return n


## Ligne peinte au sol, de `a` à `b` (plan x, z).
static func paint_line(r: Node3D, a: Vector2, b: Vector2, width: float = 0.12, col: Color = Color("e8e0c8")) -> void:
	var d: Vector2 = b - a
	var mi: MeshInstance3D = Stage3D.box(r, Vector3(d.length(), 0.004, width), Vector3((a.x + b.x) * 0.5, 0.008, (a.y + b.y) * 0.5),
		Stage3D.mat(col, 0.0, 0.7))
	mi.rotation.y = -d.angle()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Le néon du milieu grésille de temps en temps (cosmétique).
static func animate(deco: Dictionary, t: float) -> void:
	var lights: Array = deco.get("lights", [])
	var tubes: Array = deco.get("tubes", [])
	if lights.size() < 2:
		return
	var flick: bool = fmod(t, 7.3) > 6.6 and sin(t * 47.0) > 0.0
	(lights[1] as OmniLight3D).light_energy = 0.2 if flick else 0.9
	((tubes[1] as MeshInstance3D).material_override as StandardMaterial3D).emission_energy_multiplier = 0.4 if flick else 3.0


## Le voiturier du casino (veste rouge à galons, calot).
static func valet() -> Figure3D:
	return Figure3D.new().build(1.75)


## Le mécanicien (combinaison bleue, casquette absente, cheveux courts).
static func mechanic() -> Figure3D:
	return Figure3D.new().build(1.75, {"coat": Color("2a4a7a"), "trousers": Color("2a4a7a"), "trim": Color("c8c8c8"), "hat": ""})
