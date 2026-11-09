class_name RooftopSet
extends RefCounted
## Décor commun des Toits (2.0, salle 8 du Musée) : nuit bleue étoilée, lune, deux plans de
## silhouettes de ville aux fenêtres allumées (une instance multiple par plan), toits de zinc
## à la mansarde avec lucarnes éclairées, souches de cheminée en brique et leurs pots de terre
## cuite, fumées qui montent. Caméra frontale (`Stage3D.frontal`), pixels de la maquette 1920×1080.

const STARS: int = 160
const FAR_BLOCKS: int = 26
const NEAR_BLOCKS: int = 14
const SMOKE_PER: int = 6
const ZINC: Color = Color("5a6478")
const ZINC_D: Color = Color("3a4252")
const BRICK: Color = Color("8a3a26")
const TERRACOTTA: Color = Color("c8603a")
const NIGHT: Color = Color("0a1024")
const WINDOW: Color = Color(1.0, 0.78, 0.4)


## Monte le décor. `roof_y` : faîtage des toits du premier plan (pixels) ; `chimneys` : abscisses
## (pixels) des souches de cheminée qui fument ; `span` : largeur couverte par les toits (pixels).
## Rend {"smoke": Array[Node3D], "chimneys": Array[Vector3], "far": Node3D (plan lointain)}.
static func build(st: Stage3D, roof_y: float, chimneys: Array[float] = [], seed: int = 7, span: float = 2400.0) -> Dictionary:
	var r: Node3D = Node3D.new()  # plan lointain (ciel, ville) : suit la caméra en parallaxe
	st.root.add_child(r)
	var near: Node3D = st.root
	var px: float = st.px3
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed  # décor purement cosmétique : graine fixe, hors des flux de jeu
	st.env.background_color = NIGHT
	st.env.ambient_light_color = Color(0.45, 0.55, 0.85)
	st.env.ambient_light_energy = 0.35
	st.key.light_energy = 0.25
	st.key.light_color = Color(0.7, 0.8, 1.0)
	# Ciel : dégradé en bandes, étoiles, lune et son halo.
	for k: int in 6:
		var col: Color = NIGHT.lerp(Color("2a3a6a"), float(k) / 5.0)
		var band_at: Vector3 = far(st, Vector2(960.0, -400.0 + 260.0 * float(k)), -6.0)
		Stage3D.box(r, Vector3(80.0, 260.0 * px * depth(st, -6.0), 0.02), band_at, _unshaded(col))
	var star_xf: Array[Transform3D] = []
	var star_col: Array[Color] = []
	for k2: int in STARS:
		var at: Vector3 = far(st, Vector2(rng.randf_range(-200.0, 2120.0), rng.randf_range(-100.0, roof_y - 200.0)), -5.8)
		star_xf.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.5, 1.6)), at))
		star_col.append(Color(1.0, 1.0, 0.9).lerp(Color(0.7, 0.8, 1.0), rng.randf()))
	_multi_unshaded(r, Vector3(0.03, 0.03, 0.01), star_xf, star_col)
	var moon_at: Vector3 = far(st, Vector2(1580.0, 170.0), -5.5)
	Stage3D.sphere(r, 0.55, moon_at, Stage3D.glow(Color(1.0, 0.96, 0.82), 1.6))
	var halo: StandardMaterial3D = _unshaded(Color(0.8, 0.85, 1.0, 0.08))
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Stage3D.sphere(r, 1.3, moon_at + Vector3(0, 0, -0.1), halo)
	# Deux plans de ville : immeubles sombres, fenêtres allumées au hasard (fixe).
	_skyline(st, r, rng, roof_y - 120.0, -4.6, FAR_BLOCKS, Color("141a30"), 0.25)
	_skyline(st, r, rng, roof_y - 40.0, -3.4, NEAR_BLOCKS, Color("1a1f34"), 0.4)
	# Premier plan : toits de zinc à la mansarde, lucarnes, souches de cheminée.
	var zinc: StandardMaterial3D = Stage3D.mat(ZINC, 0.7, 0.45)
	var zinc_d: StandardMaterial3D = Stage3D.mat(ZINC_D, 0.6, 0.5)
	var wall: StandardMaterial3D = Stage3D.mat(Color("c8b89a"), 0.0, 0.85)
	var depth_z: float = -1.6
	for k3: int in int(ceil((span + 800.0) / 400.0)):
		var cx: float = -400.0 + float(k3) * 400.0
		var ridge: float = roof_y + float((k3 * 37) % 60)
		var c: Vector3 = st.to3(Vector2(cx, ridge + 120.0), depth_z)
		var slope: MeshInstance3D = Stage3D.box(near, Vector3(400.0 * px, 260.0 * px, 0.6), c, zinc)
		slope.rotation.x = -0.5
		Stage3D.box(near, Vector3(400.0 * px, 600.0 * px, 0.5), st.to3(Vector2(cx, ridge + 520.0), depth_z - 0.1), wall)
		Stage3D.box(near, Vector3(404.0 * px, 10.0 * px, 0.62), st.to3(Vector2(cx, ridge), depth_z + 0.12), zinc_d)
		for w: int in 2:
			var dx: float = cx - 90.0 + 180.0 * float(w)
			var dorm: Vector3 = st.to3(Vector2(dx, ridge + 120.0), depth_z + 0.32)
			Stage3D.box(near, Vector3(70.0 * px, 90.0 * px, 0.12), dorm, zinc_d)
			var lit: bool = (k3 + w) % 3 != 0
			Stage3D.box(near, Vector3(46.0 * px, 60.0 * px, 0.02), dorm + Vector3(0, -0.03, 0.07),
				Stage3D.glow(WINDOW, 1.4) if lit else Stage3D.mat(Color("101420"), 0.3, 0.2))
			var cap: MeshInstance3D = Stage3D.cylinder(near, 40.0 * px, 0.12, dorm + Vector3(0, 55.0 * px, 0.0), zinc_d)
			cap.rotation.x = PI * 0.5
	var out: Dictionary = {"smoke": [] as Array[Node3D], "chimneys": [] as Array[Vector3], "far": r}
	for x: float in chimneys:
		chimney(st, near, x, roof_y, 150.0, out)
	return out


## Souche de cheminée en brique dressée de `height` pixels au-dessus de `base_y`, trois pots de
## terre cuite, et sa fumée (`z` : profondeur de la souche).
static func chimney(st: Stage3D, r: Node3D, x: float, base_y: float, height: float, out: Dictionary, z: float = -1.45) -> void:
	var px: float = st.px3
	var brick: StandardMaterial3D = Stage3D.mat(BRICK, 0.0, 0.9)
	var top: Vector3 = st.to3(Vector2(x, base_y - height), z)
	Stage3D.box(r, Vector3(120.0 * px, (height + 120.0) * px, 0.4), top + Vector3(0, -(height + 120.0) * 0.5 * px, 0), brick)
	Stage3D.box(r, Vector3(132.0 * px, 16.0 * px, 0.44), top, Stage3D.mat(BRICK.darkened(0.3), 0.0, 0.9))
	for k: int in 3:
		var pot_at: Vector3 = top + Vector3((-36.0 + 36.0 * float(k)) * px, 30.0 * px, 0)
		Stage3D.cylinder(r, 13.0 * px, 46.0 * px, pot_at, Stage3D.mat(TERRACOTTA, 0.0, 0.7), 10.0 * px)
	(out["chimneys"] as Array[Vector3]).append(top)
	var m: StandardMaterial3D = _unshaded(Color(0.75, 0.78, 0.85, 0.12))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k2: int in SMOKE_PER:
		var s: MeshInstance3D = Stage3D.sphere(r, 0.14, top, m)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.set_meta("base", top + Vector3(0, 50.0 * px, 0))
		s.set_meta("k", k2)
		(out["smoke"] as Array[Node3D]).append(s)


static func _skyline(st: Stage3D, r: Node3D, rng: RandomNumberGenerator, base_y: float, z: float, n: int, col: Color,
		lit: float) -> void:
	var px: float = st.px3
	var span: float = 2600.0
	var w: float = span / float(n)
	var block_m: StandardMaterial3D = Stage3D.mat(col, 0.0, 0.95)
	var win_xf: Array[Transform3D] = []
	var win_col: Array[Color] = []
	var depth_k: float = depth(st, z)  # plus loin, plus grand en mètres pour garder l'échelle à l'écran
	for k: int in n:
		var x0: float = -340.0 + float(k) * w
		var h: float = rng.randf_range(180.0, 420.0)
		var c: Vector3 = far(st, Vector2(x0 + w * 0.5, base_y - h * 0.5 + 200.0), z)
		Stage3D.box(r, Vector3(w * px * depth_k * 0.96, (h + 400.0) * px * depth_k, 0.1), c, block_m)
		if rng.randf() < 0.3:
			var spire: Vector3 = c + Vector3(w * px * 0.25, (h + 400.0) * px * depth_k * 0.5 + 0.1, 0)
			Stage3D.box(r, Vector3(14.0 * px * depth_k, 70.0 * px * depth_k, 0.05), spire, block_m)
		for row: int in int(h / 36.0):
			for col2: int in int(w / 30.0):
				if rng.randf() > lit:
					continue
				var wx: float = c.x + (-w * 0.5 + 15.0 + 30.0 * float(col2)) * px * depth_k
				var wy: float = c.y + ((h + 400.0) * 0.5 - 30.0 - 36.0 * float(row)) * px * depth_k
				win_xf.append(Transform3D(Basis.IDENTITY, Vector3(wx, wy, z + 0.06)))
				win_col.append(WINDOW.lerp(Color(0.7, 0.85, 1.0), rng.randf() * 0.4).darkened(rng.randf() * 0.4))
	if not win_xf.is_empty():
		_multi_unshaded(r, Vector3(12.0 * px * depth_k, 16.0 * px * depth_k, 0.01), win_xf, win_col)


## Point du repère 2D placé à la profondeur `z` mais vu au même endroit de l'écran.
static func far(st: Stage3D, p2: Vector2, z: float) -> Vector3:
	var a: Vector3 = st.to3(p2, 0.0)
	var c: Vector3 = st.cam.position
	var k: float = depth(st, z)
	return Vector3(c.x + (a.x - c.x) * k, c.y + (a.y - c.y) * k, z)


## Facteur d'agrandissement qui garde la taille à l'écran d'un objet placé à la profondeur `z`.
static func depth(st: Stage3D, z: float) -> float:
	return (st.cam.position.z - z) / st.cam.position.z


static func _unshaded(col: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = Stage3D.mat(col, 0.0, 1.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _multi_unshaded(parent: Node3D, size_v: Vector3, xf: Array[Transform3D], cols: Array[Color]) -> void:
	var mi: MultiMeshInstance3D = KitchenSet.multi(parent, size_v, xf, cols, 1.0)
	(mi.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Fumées : bouffées qui montent, grossissent et se couchent sous le vent `wind` (pixels/s).
static func animate(deco: Dictionary, st: Stage3D, t: float, wind: float = 30.0) -> void:
	for n: Variant in deco.get("smoke", []):
		var s: Node3D = n as Node3D
		var k: int = int(s.get_meta("k"))
		var u: float = fmod(t * 0.3 + float(k) / float(SMOKE_PER), 1.0)
		var base: Vector3 = s.get_meta("base") as Vector3
		s.position = base + Vector3(wind * u * 2.2 * st.px3 + sin(t * 1.3 + float(k)) * 0.05, u * 1.6, 0.0)
		s.scale = Vector3.ONE * (0.6 + 2.4 * u)
