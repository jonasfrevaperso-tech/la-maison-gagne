class_name KitchenSet
extends RefCounted
## Décor commun des Cuisines (2.0, salle 7 du Musée) : mur en carreaux de métro crème, frise
## noire, sol en damier, piano de cuisson inox à feux bleus, hotte, rail de casseroles de cuivre,
## étagère de bocaux, vapeur qui monte. Caméra frontale (`Stage3D.frontal`), pixels 1920×1080.

const TILE: float = 60.0
const TILE_ROWS: int = 26
const TILE_COLS: int = 44
const PANS: int = 7
const JARS: int = 9
const STEAM: int = 14
const CREAM: Color = Color("e8e0cc")
const GROUT: Color = Color("6a6458")
const STEEL: Color = Color("b8bcc6")
const COPPER: Color = Color("c87840")


## Monte le décor ; `counter_y` : dessus du comptoir (pixels). Rend {"steam": Array[Node3D],
## "flames": Array[MeshInstance3D]}.
static func build(st: Stage3D, counter_y: float, stove: bool = true) -> Dictionary:
	var r: Node3D = st.root
	var px: float = st.px3
	st.env.background_color = Color("120c08")
	st.env.ambient_light_color = Color(0.9, 0.8, 0.65)
	st.env.ambient_light_energy = 0.45
	st.key.light_energy = 0.55
	# Mur : joints sombres, carreaux crème légèrement irréguliers, frise noire et or.
	var wall_at: Vector3 = st.to3(Vector2(960.0, counter_y - TILE_ROWS * TILE * 0.5), -1.62)
	Stage3D.box(r, Vector3(TILE_COLS * TILE * px, TILE_ROWS * TILE * px, 0.04), wall_at,
		Stage3D.mat(GROUT, 0.0, 0.9))
	var tile_xf: Array[Transform3D] = []
	var tile_col: Array[Color] = []
	for row: int in TILE_ROWS:
		for col: int in TILE_COLS:
			var x: float = 960.0 + (float(col) - TILE_COLS * 0.5 + (0.5 if row % 2 == 0 else 0.0)) * TILE
			var y: float = counter_y - (float(row) + 0.5) * TILE * 0.5
			tile_xf.append(Transform3D(Basis.IDENTITY, st.to3(Vector2(x, y), -1.59)))
			tile_col.append([CREAM, CREAM.darkened(0.06), CREAM.lightened(0.05)][(row * 7 + col * 3) % 3])
	multi(r, Vector3((TILE - 5.0) * px, (TILE * 0.5 - 5.0) * px, 0.02), tile_xf, tile_col, 0.25)
	var frieze_y: float = counter_y - 380.0
	Stage3D.box(r, Vector3(40.0, 22.0 * px, 0.03), st.to3(Vector2(960.0, frieze_y), -1.58), Stage3D.mat(Color("15110e"), 0.0, 0.4))
	Stage3D.box(r, Vector3(40.0, 4.0 * px, 0.035), st.to3(Vector2(960.0, frieze_y - 13.0), -1.575), Stage3D.mat(Palette.GOLD, 0.7, 0.3))
	Stage3D.box(r, Vector3(40.0, 8.0, 0.05), st.to3(Vector2(960.0, frieze_y - 820.0), -1.7), Stage3D.mat(Color("2a2018"), 0.0, 0.9))
	# Sol en damier noir et blanc devant le comptoir.
	var base: Vector3 = st.to3(Vector2(960.0, counter_y + 260.0), 0.0)
	var fl_xf: Array[Transform3D] = []
	var fl_col: Array[Color] = []
	for i: int in 26:
		for j: int in 6:
			fl_xf.append(Transform3D(Basis.IDENTITY, base + Vector3(-6.25 + 0.5 * float(i), -0.01, -1.4 + 0.5 * float(j))))
			fl_col.append(Color("ece6da") if (i + j) % 2 == 0 else Color("16120f"))
	multi(r, Vector3(0.5, 0.02, 0.5), fl_xf, fl_col, 0.35)
	# Rail de casseroles de cuivre suspendues.
	var brass: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.8, 0.3)
	var rail_y: float = counter_y - 500.0
	var rail: MeshInstance3D = Stage3D.cylinder(r, 0.015, 9.0, st.to3(Vector2(960.0, rail_y), -1.3), brass)
	rail.rotation.z = PI * 0.5
	var copper: StandardMaterial3D = Stage3D.mat(COPPER, 0.9, 0.25)
	for k: int in PANS:
		var x2: float = 960.0 + (float(k) - float(PANS - 1) * 0.5) * 230.0
		var rad: float = (52.0 + 14.0 * float(k % 3)) * px
		Stage3D.cylinder(r, 0.006, 0.12, st.to3(Vector2(x2, rail_y + 12.0), -1.3), brass)
		var pan_at: Vector3 = st.to3(Vector2(x2, rail_y + 40.0) + Vector2(0, rad / px), -1.3)
		var pan: MeshInstance3D = Stage3D.cylinder(r, rad, rad * 0.7, pan_at, copper, rad * 0.8)
		pan.rotation.x = PI * 0.5
		Stage3D.box(r, Vector3(0.025, 0.2, 0.012), st.to3(Vector2(x2, rail_y + 30.0), -1.29), copper)
	# Étagère de bocaux.
	var shelf_y: float = counter_y - 290.0
	Stage3D.box(r, Vector3(6.0, 0.03, 0.22), st.to3(Vector2(960.0, shelf_y), -1.45), Stage3D.mat(Color("5a3418"), 0.0, 0.6))
	var jar_cols: Array[Color] = [Color("d84a2a"), Color("e8c040"), Color("6a9a3a"), Color("8a4a8a"), Color("e8e0d0")]
	for k2: int in JARS:
		var jx: float = 960.0 + (float(k2) - float(JARS - 1) * 0.5) * 110.0
		var jm: StandardMaterial3D = Stage3D.mat(Color(jar_cols[k2 % jar_cols.size()], 0.85), 0.0, 0.15)
		jm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var jh: float = (60.0 + 16.0 * float(k2 % 3)) * px
		Stage3D.cylinder(r, 0.06, jh, st.to3(Vector2(jx, shelf_y), -1.45) + Vector3(0, jh * 0.5 + 0.015, 0), jm)
		Stage3D.cylinder(r, 0.062, 0.02, st.to3(Vector2(jx, shelf_y), -1.45) + Vector3(0, jh + 0.025, 0), brass)
	# Comptoir inox.
	var steel: StandardMaterial3D = Stage3D.mat(STEEL, 0.85, 0.28)
	var c_at: Vector3 = st.to3(Vector2(960.0, counter_y), -0.4)
	Stage3D.box(r, Vector3(14.0, 0.06, 1.3), c_at + Vector3(0, -0.03, 0), steel)
	Stage3D.box(r, Vector3(14.0, 1.6, 0.04), c_at + Vector3(0, -0.85, 0.66), Stage3D.mat(STEEL.darkened(0.25), 0.8, 0.35))
	for k3: int in 12:
		Stage3D.box(r, Vector3(0.01, 1.4, 0.01), c_at + Vector3(-6.0 + 1.1 * float(k3), -0.85, 0.69), Stage3D.mat(STEEL.darkened(0.45), 0.8, 0.4))
	var out: Dictionary = {"counter": c_at, "steam": [] as Array[Node3D], "flames": [] as Array[MeshInstance3D]}
	if stove:
		_stove(st, counter_y, out)
	_steam(st, counter_y, out)
	return out


## Pavage en une seule instance multiple (un appel de dessin) : boîtes `size` teintées une à une.
static func multi(parent: Node3D, size_v: Vector3, xf: Array[Transform3D], cols: Array[Color], rough: float) -> MultiMeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size_v
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = bm
	mm.instance_count = xf.size()
	for k: int in xf.size():
		mm.set_instance_transform(k, xf[k])
		mm.set_instance_color(k, cols[k])
	var m: StandardMaterial3D = Stage3D.mat(Color.WHITE, 0.0, rough)
	m.vertex_color_use_as_albedo = true
	var mi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	parent.add_child(mi)
	return mi


## Feux de gaz bleus au bout du comptoir, hotte inox au-dessus.
static func _stove(st: Stage3D, counter_y: float, out: Dictionary) -> void:
	var r: Node3D = st.root
	var flames: Array[MeshInstance3D] = out["flames"]
	var iron: StandardMaterial3D = Stage3D.mat(Color("1a1a1e"), 0.6, 0.5)
	for k: int in 2:
		var at: Vector3 = st.to3(Vector2(1640.0 + 160.0 * float(k), counter_y), -0.6)
		Stage3D.cylinder(r, 0.2, 0.03, at + Vector3(0, 0.015, 0), iron)
		for f: int in 8:
			var a: float = TAU * float(f) / 8.0
			var fl: MeshInstance3D = Stage3D.cylinder(r, 0.012, 0.06, at + Vector3(cos(a) * 0.12, 0.05, sin(a) * 0.12),
				Stage3D.glow(Color(0.3, 0.55, 1.0), 3.0), 0.0)
			flames.append(fl)
	var hood: MeshInstance3D = Stage3D.cylinder(r, 0.9, 0.5, st.to3(Vector2(1720.0, counter_y - 560.0), -0.9),
		Stage3D.mat(Color("c8ccd4"), 0.85, 0.3), 0.3)
	hood.scale = Vector3(1.0, 1.0, 0.5)


static func _steam(st: Stage3D, counter_y: float, out: Dictionary) -> void:
	var puffs: Array[Node3D] = out["steam"]
	var m: StandardMaterial3D = Stage3D.mat(Color(1, 1, 1, 0.08), 0.0, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k: int in STEAM:
		var s: MeshInstance3D = Stage3D.sphere(st.root, 0.12, st.to3(Vector2(1720.0, counter_y), -0.6), m)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		puffs.append(s)


## Anime la vapeur et les flammes (cosmétique) ; `heat` 0..1 règle la hauteur des flammes.
static func animate(deco: Dictionary, st: Stage3D, counter_y: float, t: float, heat: float = 0.6) -> void:
	var puffs: Array = deco.get("steam", [])
	for k: int in puffs.size():
		var u: float = fmod(t * 0.35 + float(k) / float(puffs.size()), 1.0)
		var p: Node3D = puffs[k] as Node3D
		p.position = st.to3(Vector2(1720.0 + sin(t + float(k) * 2.1) * 40.0 * u + (float(k % 2) - 0.5) * 120.0, counter_y - 520.0 * u), -0.6)
		p.scale = Vector3.ONE * (0.4 + 2.2 * u)
	for f: Variant in deco.get("flames", []):
		var fl: MeshInstance3D = f as MeshInstance3D
		fl.scale.y = 0.4 + heat * (1.2 + 0.3 * sin(t * 30.0 + fl.position.x * 40.0))


## Un cuisinier (veste blanche, toque) ou un commis (tablier) prêt à l'emploi.
static func chef(height: float, apprentice: bool = false) -> Figure3D:
	var out: Dictionary = {"coat": Color("f2efe8"), "trim": Color("1a1a24") if not apprentice else Color("2a4a8a"),
		"trousers": Color("1a1a1e") if not apprentice else Color("4a4038"), "hat": "chef", "hat_col": Color("f8f6f0"),
		"hair": Color("3a2416"), "shoes": Color("101010")}
	return Figure3D.new().build(height, out)
