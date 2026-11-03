class_name DecorProp
extends Node3D
## Objet décoratif interactif du casino abandonné (inspiré des plateaux de Hearthstone) :
## un clic (ou R3 à la manette) le fait réagir — verre qui tinte, bouteille qui tombe, cendrier
## qui fume, dés qui roulent, jetons qui s'écroulent, lampe qui s'allume… Purement cosmétique
## (flux de hasard `cosmetic`). Modèles construits en code ; unité = 100 px de maquette.

signal poked(kind: String)

const PIPS: Dictionary = {
	1: [Vector2(0, 0)],
	2: [Vector2(-1, -1), Vector2(1, 1)],
	3: [Vector2(-1, -1), Vector2(0, 0), Vector2(1, 1)],
	4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
	5: [Vector2(-1, -1), Vector2(1, -1), Vector2(0, 0), Vector2(-1, 1), Vector2(1, 1)],
	6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)],
}
const FACE_NORMALS: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN]
const CARD_FACES: Array[String] = ["A♥", "K♠", "7♦", "Q♣", "J♥", "A♠", "3♦", "10♣"]
const CHIP_COLS: Array[Color] = [Color("c8102e"), Color("1e1a24"), Color("f5f0e6"), Color("2e7d4f"), Color("3d6bff")]
const NEON_TEXT: String = "CASINO"

var kind: String = ""
## Rayon de clic (px de maquette) et hauteur du point visé (unités).
var radius_px: float = 60.0
var aim_height: float = 0.2
var busy: bool = false
var pokes: int = 0
var parts: Dictionary[String, Node3D] = {}
var light: Light3D = null
var smoke: CPUParticles3D = null
var _hover: bool = false
var _root: Node3D = null


func _init(p_kind: String) -> void:
	kind = p_kind
	_root = Node3D.new()
	add_child(_root)


static func rng() -> RandomNumberGenerator:
	return RngService.cosmetic()


# --------------------------------------------------------------------------- matériaux et pièces


static func mat(col: Color, rough: float = 0.6, metal: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(col, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Disque doux (particules de fumée, poussière).
static func soft_dot() -> GradientTexture2D:
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.8))
	g.set_color(1, Color(1, 1, 1, 0))
	tex.gradient = g
	return tex


static func glow(col: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = mat(col, 0.4)
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	return m


func add_mesh(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func cyl(top: float, bottom: float, h: float, seg: int = 24) -> CylinderMesh:
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


static func box(s: Vector3) -> BoxMesh:
	var b: BoxMesh = BoxMesh.new()
	b.size = s
	return b


static func ball(r: float) -> SphereMesh:
	var s: SphereMesh = SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


func pivot(pname: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = pos
	_root.add_child(n)
	parts[pname] = n
	return n


# --------------------------------------------------------------------------- survol / réactions


func set_hover(on: bool) -> void:
	if on == _hover:
		return
	_hover = on
	var tw: Tween = create_tween()
	tw.tween_property(_root, "scale", Vector3.ONE * (1.07 if on else 1.0), 0.12)
	if on:
		AudioBus.play("hover", 0.9, -8.0)


func wobble(n: Node3D, amount: float, cycles: int = 4, dur: float = 0.7) -> void:
	var tw: Tween = create_tween()
	var step: float = dur / float(cycles * 2)
	for i: int in cycles:
		var a: float = amount * (1.0 - float(i) / float(cycles))
		tw.tween_property(n, "rotation:z", a, step).set_trans(Tween.TRANS_SINE)
		tw.tween_property(n, "rotation:z", -a * 0.7, step).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "rotation:z", 0.0, step)


func hop(n: Node3D, h: float, dur: float) -> Tween:
	var base: float = n.position.y
	var tw: Tween = create_tween()
	tw.tween_property(n, "position:y", base + h, dur * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", base, dur * 0.55).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	return tw


func puff(amount: int) -> void:
	if smoke == null:
		return
	var p: CPUParticles3D = smoke.duplicate() as CPUParticles3D
	p.one_shot = true
	p.amount = RenderQuality.particles(amount)
	p.explosiveness = 0.85
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	p.spread = 70.0
	smoke.get_parent().add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Petite fumée continue (cendrier, cigare) : quads gris qui montent et s'estompent.
func make_smoke(parent: Node3D, at: Vector3) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_dot()
	q.material = m
	p.mesh = q
	p.amount = RenderQuality.particles(18)
	p.lifetime = 3.2
	p.position = at
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0.05, 0.12, 0.0)
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.18
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0, 0.4))
	sc.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = sc
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(0.75, 0.72, 0.7, 0.35))
	ramp.set_color(1, Color(0.6, 0.58, 0.6, 0.0))
	p.color_ramp = ramp
	parent.add_child(p)
	smoke = p
	return p


func poke() -> void:
	pokes += 1
	poked.emit(kind)
	if has_method("_poke_" + kind):
		call("_poke_" + kind)


# --------------------------------------------------------------------------- verre de whisky


func build_glass() -> void:
	radius_px = 42.0
	aim_height = 0.25
	var g: Node3D = pivot("body")
	var glass: StandardMaterial3D = mat(Color(0.85, 0.92, 1.0), 0.05, 0.0, 0.28)
	glass.rim_enabled = true
	glass.rim = 0.6
	add_mesh(g, cyl(0.3, 0.26, 0.55), glass, Vector3(0, 0.275, 0))
	add_mesh(g, cyl(0.26, 0.26, 0.06), mat(Color(0.8, 0.9, 1.0), 0.05, 0.0, 0.6), Vector3(0, 0.03, 0))
	add_mesh(g, cyl(0.27, 0.25, 0.22), mat(Color(0.75, 0.38, 0.08), 0.1, 0.0, 0.8), Vector3(0, 0.17, 0))
	var ice: StandardMaterial3D = mat(Color(0.9, 0.97, 1.0), 0.1, 0.0, 0.65)
	var i1: MeshInstance3D = add_mesh(g, box(Vector3(0.16, 0.14, 0.16)), ice, Vector3(-0.07, 0.3, 0.04), Vector3(0.2, 0.5, 0.1))
	var i2: MeshInstance3D = add_mesh(g, box(Vector3(0.14, 0.13, 0.14)), ice, Vector3(0.08, 0.31, -0.05), Vector3(-0.1, 1.1, 0.2))
	parts["ice1"] = i1
	parts["ice2"] = i2


func _poke_glass() -> void:
	AudioBus.play("decor_glass", rng().randf_range(0.95, 1.08))
	AudioBus.play("decor_ice", 1.0, -4.0)
	wobble(parts["body"], 0.12, 3, 0.5)
	for k: String in ["ice1", "ice2"]:
		hop(parts[k], 0.06, 0.35)
		var tw: Tween = create_tween()
		tw.tween_property(parts[k], "rotation:y", parts[k].rotation.y + rng().randf_range(1.0, 2.5), 0.4)


# --------------------------------------------------------------------------- bouteille


func build_bottle() -> void:
	radius_px = 46.0
	aim_height = 0.45
	var b: Node3D = pivot("body")
	var glass: StandardMaterial3D = mat(Color(0.12, 0.35, 0.16), 0.08, 0.1, 0.82)
	glass.rim_enabled = true
	add_mesh(b, cyl(0.24, 0.24, 0.62), glass, Vector3(0, 0.31, 0))
	add_mesh(b, cyl(0.08, 0.24, 0.2), glass, Vector3(0, 0.72, 0))
	add_mesh(b, cyl(0.075, 0.08, 0.3), glass, Vector3(0, 0.97, 0))
	add_mesh(b, cyl(0.085, 0.085, 0.06), mat(Palette.GOLD, 0.3, 0.8), Vector3(0, 1.14, 0))
	add_mesh(b, cyl(0.245, 0.245, 0.26), mat(Color(0.9, 0.84, 0.66), 0.8), Vector3(0, 0.33, 0))
	add_mesh(b, cyl(0.247, 0.247, 0.05), mat(Palette.ROULETTE_RED, 0.6), Vector3(0, 0.4, 0))


func _poke_bottle() -> void:
	if busy:
		return
	var b: Node3D = parts["body"]
	if pokes % 4 != 0:
		AudioBus.play("decor_bottle", rng().randf_range(0.92, 1.06))
		wobble(b, 0.22, 4, 0.8)
		return
	# Quatrième coup : elle tombe, roule un peu, puis le patron fantôme la redresse.
	busy = true
	AudioBus.play("decor_bottle", 0.8)
	var side: float = 1.0 if rng().randf() < 0.5 else -1.0
	var tw: Tween = create_tween()
	tw.tween_property(b, "rotation:z", side * PI * 0.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(AudioBus.play.bind("decor_glass", 0.7, -2.0))
	tw.tween_property(b, "position:x", -side * 0.25, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(b, "rotation:y", side * 1.2, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(b, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(func() -> void:
		b.rotation = Vector3.ZERO
		b.position = Vector3.ZERO)
	tw.tween_property(b, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: busy = false)


# --------------------------------------------------------------------------- cendrier et cigare


func build_ashtray() -> void:
	radius_px = 48.0
	aim_height = 0.08
	var a: Node3D = pivot("body")
	add_mesh(a, cyl(0.42, 0.38, 0.12, 8), mat(Color(0.25, 0.22, 0.28), 0.15, 0.2, 0.9), Vector3(0, 0.06, 0))
	add_mesh(a, cyl(0.3, 0.28, 0.02, 8), mat(Color(0.12, 0.11, 0.1), 0.95), Vector3(0, 0.115, 0))
	for i: int in 5:
		var p: Vector3 = Vector3(rng().randf_range(-0.18, 0.18), 0.13, rng().randf_range(-0.18, 0.18))
		add_mesh(a, cyl(0.02, 0.02, 0.12, 6), mat(Color(0.85, 0.8, 0.7), 0.9), p, Vector3(PI * 0.5, rng().randf() * TAU, 0))
	var cig: Node3D = Node3D.new()
	cig.position = Vector3(0.12, 0.16, 0.0)
	cig.rotation = Vector3(0, 0.5, -0.12)
	a.add_child(cig)
	add_mesh(cig, cyl(0.055, 0.055, 0.6, 10), mat(Color(0.33, 0.19, 0.08), 0.8), Vector3(0.2, 0, 0), Vector3(0, 0, PI * 0.5))
	add_mesh(cig, cyl(0.057, 0.057, 0.08, 10), mat(Palette.GOLD, 0.4, 0.6), Vector3(0.36, 0, 0), Vector3(0, 0, PI * 0.5))
	var ember: MeshInstance3D = add_mesh(cig, ball(0.056), glow(Color(1.0, 0.35, 0.05), 3.0), Vector3(-0.1, 0, 0))
	parts["ember"] = ember
	make_smoke(cig, Vector3(-0.12, 0.03, 0))


func _poke_ashtray() -> void:
	AudioBus.play("decor_puff", rng().randf_range(0.9, 1.1))
	puff(26)
	var em: Node3D = parts["ember"]
	var tw: Tween = create_tween()
	tw.tween_property(em, "scale", Vector3.ONE * 1.6, 0.15)
	tw.tween_property(em, "scale", Vector3.ONE, 0.8)


# --------------------------------------------------------------------------- dés


func _die(parent: Node3D, at: Vector3) -> Node3D:
	var d: Node3D = Node3D.new()
	d.position = at
	parent.add_child(d)
	var s: float = 0.26
	add_mesh(d, box(Vector3.ONE * s), mat(Color(0.93, 0.9, 0.84), 0.35), Vector3.ZERO)
	var pip_m: StandardMaterial3D = mat(Palette.ROULETTE_RED.darkened(0.2), 0.5)
	var pip: CylinderMesh = cyl(0.025, 0.025, 0.012, 10)
	for f: int in 6:
		var n: Vector3 = FACE_NORMALS[f]
		var basis: Basis = Basis(Quaternion(Vector3.UP, n)) if n != Vector3.DOWN else Basis(Vector3.RIGHT, PI)
		for o: Vector2 in PIPS[f + 1]:
			var local: Vector3 = Vector3(o.x * 0.068, s * 0.5, o.y * 0.068)
			var mi: MeshInstance3D = add_mesh(d, pip, pip_m, basis * local)
			mi.basis = basis
	return d


func build_dice() -> void:
	radius_px = 50.0
	aim_height = 0.13
	var root: Node3D = pivot("body")
	parts["d1"] = _die(root, Vector3(-0.2, 0.13, 0.05))
	parts["d2"] = _die(root, Vector3(0.2, 0.13, -0.08))
	parts["d1"].rotation.y = 0.4
	parts["d2"].rotation.y = -0.7


func _poke_dice() -> void:
	if busy:
		return
	busy = true
	AudioBus.play("dice", rng().randf_range(0.95, 1.1))
	var total: int = 0
	for k: String in ["d1", "d2"]:
		var d: Node3D = parts[k]
		var face: int = rng().randi_range(0, 5)
		total += face + 1
		var final_basis: Basis = Basis(Vector3.UP, rng().randf() * TAU) * Basis(Quaternion(FACE_NORMALS[face], Vector3.UP))
		if FACE_NORMALS[face] == Vector3.DOWN:
			final_basis = Basis(Vector3.UP, rng().randf() * TAU) * Basis(Vector3.RIGHT, PI)
		var start: Quaternion = d.quaternion
		var spin: Quaternion = Quaternion(Vector3(rng().randf(), 1.0, rng().randf()).normalized(), PI)
		var target: Quaternion = final_basis.get_rotation_quaternion()
		var to_x: float = clampf(d.position.x + rng().randf_range(-0.15, 0.15), -0.35, 0.35)
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_method(func(u: float) -> void:
			d.quaternion = (start * spin).slerp(target, u) if u > 0.5 else start.slerp(start * spin, u * 2.0), 0.0, 1.0, 0.7)
		tw.tween_property(d, "position:x", to_x, 0.7)
		hop(d, 0.45, 0.7)
	var done: Tween = create_tween()
	done.tween_interval(0.75)
	done.tween_callback(func() -> void:
		busy = false
		if total == 7 or total == 12:
			AudioBus.play("wink"))


# --------------------------------------------------------------------------- cartes


func build_cards() -> void:
	radius_px = 52.0
	aim_height = 0.03
	var root: Node3D = pivot("body")
	var back: StandardMaterial3D = mat(Color(0.5, 0.06, 0.12), 0.7)
	for i: int in 4:
		var at: Vector3 = Vector3(0.08 * float(i) - 0.15, 0.006 * float(i + 1), 0.02 * float(i))
		add_mesh(root, box(Vector3(0.62, 0.008, 0.88)), back, at, Vector3(0, -0.25 + 0.18 * float(i), 0))
	var top: Node3D = Node3D.new()
	top.position = Vector3(0.12, 0.04, 0.05)
	top.rotation.y = 0.35
	root.add_child(top)
	parts["top"] = top
	var flip: Node3D = Node3D.new()
	top.add_child(flip)
	parts["flip"] = flip
	add_mesh(flip, box(Vector3(0.62, 0.008, 0.88)), mat(Palette.IVORY, 0.7), Vector3.ZERO)
	add_mesh(flip, box(Vector3(0.6, 0.004, 0.86)), back, Vector3(0, -0.006, 0))
	var face: Label3D = Label3D.new()
	face.text = "A♠"
	face.font_size = 96
	face.pixel_size = 0.0035
	face.modulate = Palette.INK
	face.outline_size = 0
	face.rotation = Vector3(-PI * 0.5, 0, 0)
	face.position = Vector3(0, 0.006, 0)
	flip.add_child(face)
	parts["face"] = face


func _poke_cards() -> void:
	if busy:
		return
	busy = true
	AudioBus.play("card_flip", rng().randf_range(0.95, 1.1))
	var flip: Node3D = parts["flip"]
	var face: Label3D = parts["face"] as Label3D
	var tw: Tween = create_tween()
	tw.tween_property(flip, "position:y", 0.25, 0.15)
	tw.parallel().tween_property(flip, "rotation:z", PI * 0.5, 0.15)
	tw.tween_callback(func() -> void:
		face.text = CARD_FACES[rng().randi_range(0, CARD_FACES.size() - 1)]
		var red: bool = face.text.contains("♥") or face.text.contains("♦")
		face.modulate = Palette.ROULETTE_RED if red else Palette.INK)
	tw.tween_property(flip, "rotation:z", 0.0, 0.18)
	tw.parallel().tween_property(flip, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: busy = false)


# --------------------------------------------------------------------------- pile de jetons


func build_chips() -> void:
	radius_px = 44.0
	aim_height = 0.25
	var root: Node3D = pivot("body")
	var stack: Array[Node3D] = []
	for i: int in 11:
		var c: Node3D = Node3D.new()
		c.position = Vector3(rng().randf_range(-0.012, 0.012), 0.03 + 0.055 * float(i), rng().randf_range(-0.012, 0.012))
		root.add_child(c)
		var col: Color = CHIP_COLS[i % CHIP_COLS.size()]
		add_mesh(c, cyl(0.2, 0.2, 0.05, 20), mat(col, 0.45), Vector3.ZERO)
		add_mesh(c, cyl(0.12, 0.12, 0.052, 20), mat(col.lightened(0.25), 0.45), Vector3.ZERO)
		stack.append(c)
	parts["body"] = root
	set_meta("stack", stack)


func _poke_chips() -> void:
	if busy:
		return
	var stack: Array = get_meta("stack")
	if pokes % 3 != 0:
		AudioBus.play("chips", rng().randf_range(0.95, 1.05))
		var top: Node3D = stack[stack.size() - 1]
		hop(top, 0.2, 0.3)
		return
	busy = true
	AudioBus.play("decor_topple")
	var homes: Array[Vector3] = []
	var tw: Tween = create_tween().set_parallel(true)
	for i: int in stack.size():
		var c: Node3D = stack[i]
		homes.append(c.position)
		var ang: float = rng().randf() * TAU
		var dist: float = rng().randf_range(0.2, 0.75)
		var dest: Vector3 = Vector3(cos(ang) * dist, 0.03, sin(ang) * dist)
		tw.tween_property(c, "position", dest, 0.45 + 0.03 * float(i)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "rotation", Vector3(rng().randf_range(-0.2, 0.2), rng().randf() * TAU, rng().randf_range(-0.2, 0.2)), 0.45)
	tw.chain().tween_interval(2.6)
	tw.chain().tween_callback(AudioBus.play.bind("chip_sweep", 1.0, -3.0))
	var back: Tween = tw.chain()
	for i: int in stack.size():
		back.parallel().tween_property(stack[i], "position", homes[i], 0.35).set_delay(0.04 * float(i))
		back.parallel().tween_property(stack[i], "rotation", Vector3.ZERO, 0.35).set_delay(0.04 * float(i))
	back.chain().tween_callback(func() -> void: busy = false)


# --------------------------------------------------------------------------- lampe de banquier


func build_lamp() -> void:
	radius_px = 62.0
	aim_height = 0.6
	var root: Node3D = pivot("body")
	var brass: StandardMaterial3D = mat(Palette.GOLD.darkened(0.15), 0.3, 0.85)
	add_mesh(root, cyl(0.2, 0.3, 0.08, 20), brass, Vector3(0, 0.04, 0))
	add_mesh(root, cyl(0.035, 0.035, 0.62, 10), brass, Vector3(0, 0.38, 0))
	var shade: Node3D = Node3D.new()
	shade.position = Vector3(0, 0.72, 0)
	root.add_child(shade)
	parts["shade"] = shade
	var green: StandardMaterial3D = glow(Color(0.08, 0.5, 0.25), 0.6)
	green.albedo_color = Color(0.05, 0.38, 0.2)
	green.metallic = 0.2
	green.roughness = 0.15
	parts["shade_mat"] = null
	set_meta("shade_mat", green)
	var cyl_shade: CylinderMesh = cyl(0.22, 0.22, 0.85, 20)
	add_mesh(shade, cyl_shade, green, Vector3.ZERO, Vector3(0, 0, PI * 0.5))
	add_mesh(shade, box(Vector3(0.86, 0.02, 0.3)), mat(Color(0.95, 0.85, 0.6), 0.5), Vector3(0, -0.13, 0))
	var chain: MeshInstance3D = add_mesh(shade, cyl(0.008, 0.008, 0.22, 6), brass, Vector3(0.25, -0.24, 0.12))
	add_mesh(chain, ball(0.025), brass, Vector3(0, -0.12, 0))
	parts["chain"] = chain
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.55)
	l.light_energy = 2.2
	l.omni_range = 3.2
	l.omni_attenuation = 1.4
	l.position = Vector3(0, 0.45, 0.2)
	shade.add_child(l)
	light = l


func _poke_lamp() -> void:
	var on: bool = not light.visible
	AudioBus.play("decor_switch", 1.1 if on else 0.9)
	var chain: Node3D = parts["chain"]
	var tw: Tween = create_tween()
	tw.tween_property(chain, "position:y", -0.3, 0.08)
	tw.tween_property(chain, "position:y", -0.24, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var m: StandardMaterial3D = get_meta("shade_mat")
	if not on:
		light.visible = false
		m.emission_energy_multiplier = 0.0
		return
	# Rallumage capricieux : deux hoquets avant de tenir.
	var fl: Tween = create_tween()
	for v: bool in [true, false, true, false, true]:
		fl.tween_callback(func() -> void:
			light.visible = v
			m.emission_energy_multiplier = 0.6 if v else 0.0)
		fl.tween_interval(rng().randf_range(0.04, 0.12))


# --------------------------------------------------------------------------- enseigne néon tombée


func build_neon() -> void:
	radius_px = 120.0
	aim_height = 0.05
	var root: Node3D = pivot("body")
	root.rotation.y = 0.12
	add_mesh(root, box(Vector3(2.2, 0.06, 0.56)), mat(Color(0.08, 0.06, 0.09), 0.5, 0.4), Vector3(0, 0.03, 0))
	var letters: Array[Label3D] = []
	for i: int in NEON_TEXT.length():
		var l: Label3D = Label3D.new()
		l.text = NEON_TEXT[i]
		l.font = UiKit.font("display")
		l.font_size = 120
		l.pixel_size = 0.0036
		l.shaded = false
		l.modulate = Color(Palette.MAGENTA, 1.0) * 2.2
		l.outline_modulate = Color(Palette.MAGENTA, 0.35)
		l.outline_size = 18
		l.rotation = Vector3(-PI * 0.5, 0, 0)
		l.position = Vector3(-0.85 + 0.34 * float(i), 0.075, 0.0)
		root.add_child(l)
		letters.append(l)
	set_meta("letters", letters)
	set_meta("dead", 2)
	var lt: OmniLight3D = OmniLight3D.new()
	lt.light_color = Palette.MAGENTA
	lt.light_energy = 1.4
	lt.omni_range = 2.6
	lt.position = Vector3(0, 0.4, 0)
	root.add_child(lt)
	light = lt


## Grésillement permanent : une lettre morte (qui ressuscite parfois), des sautes aléatoires.
func neon_tick() -> void:
	var letters: Array = get_meta("letters")
	var dead: int = int(get_meta("dead"))
	var r: RandomNumberGenerator = rng()
	for i: int in letters.size():
		var l: Label3D = letters[i]
		var on: bool = i != dead or r.randf() < 0.06
		if r.randf() < 0.015:
			on = false
		l.modulate.a = 1.0 if on else 0.12
	light.light_energy = 1.4 * (0.75 + 0.25 * r.randf())


func _poke_neon() -> void:
	AudioBus.play("decor_neon", rng().randf_range(0.9, 1.1))
	var letters: Array = get_meta("letters")
	# Un coup sec : la lettre morte change et la couleur bascule (magenta ↔ cyan).
	set_meta("dead", rng().randi_range(0, letters.size() - 1) if pokes % 3 != 0 else -1)
	var col: Color = Palette.CYAN if pokes % 2 == 1 else Palette.MAGENTA
	for l: Label3D in letters:
		l.modulate = Color(col, 1.0) * 2.2
		l.outline_modulate = Color(col, 0.35)
	(light as OmniLight3D).light_color = col
	var b: Node3D = parts["body"]
	hop(b, 0.06, 0.25)
