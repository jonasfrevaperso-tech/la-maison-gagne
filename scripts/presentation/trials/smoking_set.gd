class_name SmokingSet
extends RefCounted
## Décor commun du Fumoir (2.0, salle 9 du Musée) : boiseries de noyer à panneaux, tenture vert
## bouteille rayée, cheminée de marbre au feu vivant, bibliothèque, appliques et lampes de banquier
## à abat-jour vert, fauteuils club en cuir sang-de-bœuf, parquet à bâtons rompus, tapis persan,
## volutes de fumée qui dérivent. Caméra frontale (`Stage3D.frontal`), pixels 1920×1080.

const PANELS: int = 9
const BOOKS: int = 80
const HAZE: int = 10
const EMBERS: int = 8
const WALNUT: Color = Color("4a2a16")
const WALNUT_D: Color = Color("2a160a")
const DRAPE: Color = Color("143a2a")
const LEATHER: Color = Color("6a1a14")
const LAMP_GREEN: Color = Color(0.2, 0.75, 0.4)
const FIRE: Color = Color(1.0, 0.55, 0.2)
const BRASS: Color = Color("c8a040")


## Monte le décor ; `floor_y` : ligne du sol au pied du mur (pixels). `fire_x` : abscisse de la
## cheminée (négative = pas de cheminée) ; `chairs` : abscisses des fauteuils club.
## Rend {"fire": OmniLight3D, "flames": Array[MeshInstance3D], "haze": Array[MeshInstance3D]}.
static func build(st: Stage3D, floor_y: float, fire_x: float = 1500.0, chairs: Array[float] = []) -> Dictionary:
	var r: Node3D = st.root
	var px: float = st.px3
	st.env.background_color = Color("0c0806")
	st.env.ambient_light_color = Color(1.0, 0.8, 0.6)
	st.env.ambient_light_energy = 0.32
	st.key.light_energy = 0.45
	st.key.light_color = Color(1.0, 0.85, 0.65)
	var wz: float = -1.7
	var walnut: StandardMaterial3D = Stage3D.textured("wood", WALNUT, 0.6, 0.0, 0.55)
	var walnut_d: StandardMaterial3D = Stage3D.textured("wood", WALNUT_D, 0.6, 0.0, 0.5)
	# Tenture rayée vert bouteille (haut du mur) : bandes alternées en une instance multiple.
	var stripe_xf: Array[Transform3D] = []
	var stripe_col: Array[Color] = []
	for k: int in 60:
		var x: float = -1000.0 + 66.0 * float(k)
		stripe_xf.append(Transform3D(Basis.IDENTITY, st.to3(Vector2(x, floor_y - 900.0), wz)))
		stripe_col.append(DRAPE if k % 2 == 0 else DRAPE.darkened(0.25))
	KitchenSet.multi(r, Vector3(66.0 * px, 1200.0 * px, 0.02), stripe_xf, stripe_col, 0.85)
	# Lambris : soubassement à panneaux moulurés, cimaise dorée.
	var wain_h: float = 420.0
	Stage3D.box(r, Vector3(30.0, wain_h * px, 0.05), st.to3(Vector2(960.0, floor_y - wain_h * 0.5), wz + 0.03), walnut_d)
	for k2: int in PANELS * 3:
		var x2: float = -1300.0 + 200.0 * float(k2)
		var panel_at: Vector3 = st.to3(Vector2(x2, floor_y - wain_h * 0.5 + 10.0), wz + 0.07)
		Stage3D.box(r, Vector3(150.0 * px, (wain_h - 90.0) * px, 0.03), panel_at, walnut)
	Stage3D.box(r, Vector3(30.0, 14.0 * px, 0.09), st.to3(Vector2(960.0, floor_y - wain_h), wz + 0.06), Stage3D.mat(BRASS, 0.75, 0.3))
	Stage3D.box(r, Vector3(30.0, 40.0 * px, 0.12), st.to3(Vector2(960.0, floor_y - 20.0), wz + 0.08), walnut_d)  # plinthe
	Stage3D.box(r, Vector3(30.0, 60.0 * px, 0.14), st.to3(Vector2(960.0, floor_y - 1130.0), wz + 0.08), walnut_d)  # corniche
	# Parquet à bâtons rompus et tapis persan.
	var floor_at: Vector3 = st.to3(Vector2(960.0, floor_y), 0.0)
	var pq_xf: Array[Transform3D] = []
	var pq_col: Array[Color] = []
	for j: int in 18:
		for i: int in 14:
			var x: float = -8.4 + 1.2 * float(i) + (0.6 if j % 2 == 1 else 0.0) + 0.3 * float(j % 3)
			pq_xf.append(Transform3D(Basis.IDENTITY, Vector3(x, floor_at.y - 0.01, wz + 0.1 + 0.2 * float(j))))
			pq_col.append(Color("3e2410").lerp(Color("5a3618"), float((i * 7 + j * 3) % 5) / 4.0))
	KitchenSet.multi(r, Vector3(1.19, 0.02, 0.19), pq_xf, pq_col, 0.4)
	_rug(r, Vector3(floor_at.x, floor_at.y, wz + 2.2))
	if fire_x >= 0.0:
		_fireplace(st, r, fire_x, floor_y, wz)
	# Bibliothèque à gauche, appliques, tableau doré.
	_bookcase(st, r, 160.0, floor_y, wz)
	for sx: float in [560.0, 1060.0]:
		var at: Vector3 = st.to3(Vector2(sx, floor_y - 640.0), wz + 0.1)
		Stage3D.box(r, Vector3(0.05, 0.16, 0.05), at, Stage3D.mat(BRASS, 0.8, 0.3))
		Stage3D.cylinder(r, 0.09, 0.14, at + Vector3(0, 0.14, 0.08), Stage3D.glow(Color(1.0, 0.8, 0.5), 1.4), 0.05)
		Stage3D.omni(r, Color(1.0, 0.75, 0.45), 0.5, at + Vector3(0, 0.1, 0.3), 2.2)
	var frame_at: Vector3 = st.to3(Vector2(810.0, floor_y - 760.0), wz + 0.05)
	Stage3D.box(r, Vector3(1.3, 0.9, 0.04), frame_at, Stage3D.mat(BRASS, 0.8, 0.35))
	Stage3D.box(r, Vector3(1.16, 0.76, 0.02), frame_at + Vector3(0, 0, 0.03), Stage3D.mat(Color("2a3a2a"), 0.0, 0.8))
	Stage3D.box(r, Vector3(1.16, 0.25, 0.02), frame_at + Vector3(0, -0.2, 0.031), Stage3D.mat(Color("5a6a3a"), 0.0, 0.8))
	Stage3D.sphere(r, 0.09, frame_at + Vector3(0.3, 0.15, 0.04), Stage3D.mat(Color("e8c070"), 0.0, 0.6))
	for cx: float in chairs:
		club_chair(r, st.to3(Vector2(cx, floor_y), wz + 1.0))
	var out: Dictionary = {"fire": null, "flames": [] as Array[MeshInstance3D], "haze": [] as Array[MeshInstance3D], "fire_x": fire_x}
	if fire_x >= 0.0:
		_flames(st, r, fire_x, floor_y, wz, out)
	_haze(st, r, floor_y, out)
	return out


static func _rug(r: Node3D, at: Vector3) -> void:
	var bands: Array[Color] = [Color("3a1410"), Color("8a6a30"), Color("141c30"), Color("5a1c16")]
	for k: int in bands.size():
		var w: float = 6.0 - 0.6 * float(k)
		var d: float = 2.0 - 0.3 * float(k)
		Stage3D.box(r, Vector3(w, 0.01, d), at + Vector3(0, 0.005 * float(k + 1), 0), Stage3D.mat(bands[k], 0.0, 0.95))
	for k2: int in 7:
		var motif: MeshInstance3D = Stage3D.box(r, Vector3(0.18, 0.03, 0.18), at + Vector3(-1.8 + 0.6 * float(k2), 0.02, 0),
			Stage3D.mat(Color("e8d0a0"), 0.0, 0.9))
		motif.rotation.y = PI * 0.25


static func _fireplace(st: Stage3D, r: Node3D, x: float, floor_y: float, wz: float) -> void:
	var marble: StandardMaterial3D = Stage3D.mat(Color("d8d0c4"), 0.05, 0.22)
	var at: Vector3 = st.to3(Vector2(x, floor_y), wz + 0.25)
	Stage3D.box(r, Vector3(0.28, 1.25, 0.4), at + Vector3(-0.8, 0.625, 0), marble)
	Stage3D.box(r, Vector3(0.28, 1.25, 0.4), at + Vector3(0.8, 0.625, 0), marble)
	Stage3D.box(r, Vector3(2.1, 0.2, 0.5), at + Vector3(0, 1.32, 0.03), marble)
	Stage3D.box(r, Vector3(1.32, 1.05, 0.05), at + Vector3(0, 0.55, -0.15), Stage3D.mat(Color("140a06"), 0.0, 1.0))
	Stage3D.box(r, Vector3(1.4, 0.04, 0.6), at + Vector3(0, 0.02, 0.15), Stage3D.mat(Color("2a2420"), 0.3, 0.6))
	for k: int in 3:  # bûches
		var log_at: Vector3 = at + Vector3(-0.1 + 0.1 * float(k), 0.1 + 0.08 * float(k % 2), -0.05 * float(k))
		var log_n: MeshInstance3D = Stage3D.cylinder(r, 0.07, 0.8, log_at, Stage3D.mat(Color("3a2010"), 0.0, 0.9))
		log_n.rotation = Vector3(0, 0.3 * float(k - 1), PI * 0.5)
	# Pendule et chandeliers sur le manteau.
	var brass: StandardMaterial3D = Stage3D.mat(BRASS, 0.85, 0.25)
	Stage3D.box(r, Vector3(0.3, 0.36, 0.14), at + Vector3(0, 1.6, 0.05), brass)
	Stage3D.cylinder(r, 0.1, 0.02, at + Vector3(0, 1.62, 0.13), Stage3D.mat(Color("f4ecd8"), 0.0, 0.5)).rotation.x = PI * 0.5
	for sx: float in [-0.75, 0.75]:
		Stage3D.cylinder(r, 0.03, 0.3, at + Vector3(sx, 1.57, 0.05), brass)
		Stage3D.cylinder(r, 0.018, 0.12, at + Vector3(sx, 1.78, 0.05), Stage3D.mat(Color("f4ecd8"), 0.0, 0.6))
		Stage3D.sphere(r, 0.025, at + Vector3(sx, 1.87, 0.05), Stage3D.glow(Color(1.0, 0.8, 0.4), 3.0))


static func _flames(st: Stage3D, r: Node3D, x: float, floor_y: float, wz: float, out: Dictionary) -> void:
	var at: Vector3 = st.to3(Vector2(x, floor_y), wz + 0.25)
	var flames: Array[MeshInstance3D] = out["flames"]
	for k: int in EMBERS:
		var col: Color = FIRE.lerp(Color(1.0, 0.85, 0.3), float(k % 3) / 2.0)
		var f_at: Vector3 = at + Vector3(-0.35 + 0.1 * float(k), 0.32, 0.02 - 0.03 * float(k % 2))
		var f: MeshInstance3D = Stage3D.cylinder(r, 0.07, 0.3, f_at, Stage3D.glow(col, 4.0), 0.0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(f)
	out["fire"] = Stage3D.omni(r, FIRE, 2.2, at + Vector3(0, 0.5, 0.6), 6.0)


static func _bookcase(st: Stage3D, r: Node3D, x: float, floor_y: float, wz: float) -> void:
	var at: Vector3 = st.to3(Vector2(x, floor_y), wz + 0.2)
	var wood: StandardMaterial3D = Stage3D.textured("wood", WALNUT_D, 0.6, 0.0, 0.5)
	Stage3D.box(r, Vector3(1.9, 3.6, 0.05), at + Vector3(0, 1.8, -0.15), wood)
	for sx: float in [-0.95, 0.95]:
		Stage3D.box(r, Vector3(0.06, 3.6, 0.35), at + Vector3(sx, 1.8, 0), wood)
	var book_xf: Array[Transform3D] = []
	var book_col: Array[Color] = []
	var cols: Array[Color] = [Color("5a1a14"), Color("1a3a2a"), Color("2a2a4a"), Color("6a4a20"), Color("3a1a2a"), Color("8a6a3a")]
	for shelf: int in 5:
		var sy: float = 0.15 + 0.68 * float(shelf)
		Stage3D.box(r, Vector3(1.86, 0.04, 0.33), at + Vector3(0, sy, 0), wood)
		var bx: float = -0.88
		var n: int = 0
		while bx < 0.86 and n < BOOKS / 5:
			var w: float = 0.05 + 0.03 * float((shelf * 5 + n * 3) % 3)
			var h: float = 0.4 + 0.06 * float((shelf + n * 7) % 4)
			var tilt: float = 0.25 if (shelf * 11 + n) % 13 == 0 else 0.0
			var b_basis: Basis = Basis(Vector3.FORWARD, tilt).scaled(Vector3(w, h, 0.26))
			book_xf.append(Transform3D(b_basis, at + Vector3(bx + w * 0.5, sy + 0.02 + h * 0.5, 0.0)))
			book_col.append(cols[(shelf * 3 + n * 5) % cols.size()])
			bx += w + 0.005
			n += 1
	KitchenSet.multi(r, Vector3.ONE, book_xf, book_col, 0.6)


## Fauteuil club en cuir capitonné (posé au sol en `at`, face à la caméra).
static func club_chair(r: Node3D, at: Vector3, rot_y: float = 0.0) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = at
	n.rotation.y = rot_y
	r.add_child(n)
	var leather: StandardMaterial3D = Stage3D.mat(LEATHER, 0.1, 0.35)
	var dark: StandardMaterial3D = Stage3D.mat(LEATHER.darkened(0.35), 0.1, 0.4)
	Stage3D.box(n, Vector3(0.9, 0.4, 0.8), Vector3(0, 0.25, 0), dark)
	Stage3D.box(n, Vector3(0.66, 0.14, 0.62), Vector3(0, 0.5, 0.06), leather)
	Stage3D.box(n, Vector3(0.9, 0.62, 0.2), Vector3(0, 0.66, -0.32), leather)
	for sx: float in [-0.39, 0.39]:
		Stage3D.box(n, Vector3(0.14, 0.5, 0.76), Vector3(sx, 0.48, 0.01), leather)
		var roll: MeshInstance3D = Stage3D.cylinder(n, 0.09, 0.78, Vector3(sx, 0.74, 0.01), leather)
		roll.rotation.x = PI * 0.5
	for k: int in 6:
		Stage3D.sphere(n, 0.015, Vector3(-0.25 + 0.1 * float(k), 0.78 - 0.15 * float(k % 2), -0.215), dark)
	for k2: int in 4:
		var foot_at: Vector3 = Vector3(-0.38 + 0.76 * float(k2 % 2), 0.03, -0.32 + 0.64 * float(k2 / 2))
		Stage3D.cylinder(n, 0.03, 0.06, foot_at, Stage3D.mat(Color("1a0c06"), 0.3, 0.4))
	return n


## Lampe de banquier (laiton, abat-jour vert lumineux) posée en `at`.
static func banker_lamp(r: Node3D, at: Vector3, light: bool = true) -> void:
	var brass: StandardMaterial3D = Stage3D.mat(BRASS, 0.85, 0.25)
	Stage3D.cylinder(r, 0.1, 0.03, at + Vector3(0, 0.015, 0), brass)
	Stage3D.cylinder(r, 0.015, 0.32, at + Vector3(0, 0.18, 0), brass)
	var shade: MeshInstance3D = Stage3D.cylinder(r, 0.08, 0.36, at + Vector3(0, 0.36, 0.04), Stage3D.glow(LAMP_GREEN, 0.8), 0.06)
	shade.rotation.z = PI * 0.5
	if light:
		Stage3D.omni(r, Color(1.0, 0.9, 0.7), 0.9, at + Vector3(0, 0.25, 0.15), 2.5)


static func _haze(st: Stage3D, r: Node3D, floor_y: float, out: Dictionary) -> void:
	var haze: Array[MeshInstance3D] = out["haze"]
	var m: StandardMaterial3D = Stage3D.mat(Color(0.85, 0.82, 0.75, 0.022), 0.0, 1.0)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k: int in HAZE:
		var q: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 1.0
		sm.height = 0.35
		sm.radial_segments = 16
		sm.rings = 6
		q.mesh = sm
		q.material_override = m
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.position = st.to3(Vector2(200.0 * float(k), floor_y - 600.0 - 60.0 * float(k % 3)), -0.8 - 0.1 * float(k % 4))
		r.add_child(q)
		haze.append(q)


## Feu qui danse, volutes qui dérivent lentement (cosmétique).
static func animate(deco: Dictionary, st: Stage3D, floor_y: float, t: float) -> void:
	var fl: Array = deco.get("flames", [])
	for k: int in fl.size():
		var f: MeshInstance3D = fl[k] as MeshInstance3D
		f.scale = Vector3(1.0, 0.7 + 0.45 * absf(sin(t * (5.0 + float(k)) + float(k) * 1.7)), 1.0)
	var light: OmniLight3D = deco.get("fire") as OmniLight3D
	if light != null:
		light.light_energy = 2.0 + 0.4 * sin(t * 9.0) + 0.25 * sin(t * 23.0)
	var hz: Array = deco.get("haze", [])
	for k2: int in hz.size():
		var q: MeshInstance3D = hz[k2] as MeshInstance3D
		var x: float = fposmod(200.0 * float(k2) + t * (18.0 + 4.0 * float(k2 % 3)), 2400.0) - 240.0
		var hy: float = floor_y - 600.0 - 60.0 * float(k2 % 3) + 20.0 * sin(t * 0.3 + float(k2))
		q.position = st.to3(Vector2(x, hy), -0.8 - 0.1 * float(k2 % 4))
		q.scale = Vector3(1.6 + 0.3 * sin(t * 0.2 + float(k2)), 1.0, 1.0)


## Un gentleman du club (smoking, nœud papillon) prêt à l'emploi.
static func gentleman(height: float, coat: Color = Color("1a1a22"), hair: Color = Color("3a2416")) -> Figure3D:
	return Figure3D.new().build(height, {"coat": coat, "trim": Color("e8e0cc"), "trousers": Color("121216"),
		"hat": "", "hair": hair, "shoes": Color("0a0a0a")})
