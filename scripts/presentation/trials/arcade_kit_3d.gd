class_name ArcadeKit3D
extends RefCounted
## Décor 3D des épreuves d'arcade (Envahisseurs, Cave) : salle du sous-sol (moquette, mur aux
## néons, bornes voisines allumées) et vraie borne autour de l'écran de jeu, posée dans le plan
## de la caméra frontale (`Stage3D.frontal`). Le jeu se joue dans la vitrine de la borne.

const WOOD: Color = Color("3a1c12")
const WOOD_LIGHT: Color = Color("6a351f")
const NEON_COLORS: Array[Color] = [Color("ff2e88"), Color("29e0ff"), Color("ffd23f"), Color("2ee6a8")]
## Profondeur de la vitrine derrière la vitre (m) et largeur des flancs de la borne (px).
const DEPTH: float = 0.9
const SIDE_PX: float = 70.0
const NEIGHBORS: int = 4


## Salle : sol, mur du fond aux néons, bornes voisines (écrans qui scintillent dans `screens`).
static func room(st: Stage3D, screens: Array[MeshInstance3D]) -> void:
	var r: Node3D = st.root
	st.env.background_color = Color("07040c")
	st.env.ambient_light_color = Color(0.3, 0.2, 0.38)
	st.env.ambient_light_energy = 0.35
	var floor_y: float = st.to3(Vector2(960, 1080)).y
	Stage3D.box(r, Vector3(30.0, 0.05, 14.0), Vector3(0, floor_y - 0.05, -4.0), Stage3D.mat(Color("1c0f2a"), 0.0, 0.95))
	# Motif de moquette : pastilles néon éteintes au sol.
	var dot: StandardMaterial3D = Stage3D.glow(Color("29e0ff"), 0.25)
	for k: int in 18:
		Stage3D.box(r, Vector3(0.14, 0.01, 0.14), Vector3(-6.0 + float(k) * 0.7, floor_y + 0.0, -1.0 - float(k % 3) * 0.9), dot)
	var wall_z: float = -6.0
	Stage3D.box(r, Vector3(30.0, 12.0, 0.1), Vector3(0, floor_y + 6.0, wall_z), Stage3D.mat(Color("120a1c"), 0.0, 0.9))
	for k2: int in 3:
		var col: Color = NEON_COLORS[k2 % NEON_COLORS.size()]
		Stage3D.box(r, Vector3(20.0, 0.05, 0.05), Vector3(0, floor_y + 4.2 + float(k2) * 0.5, wall_z + 0.1), Stage3D.glow(col, 1.6))
	# Bornes voisines, de biais, écrans allumés.
	for k3: int in NEIGHBORS:
		var side: float = -1.0 if k3 < NEIGHBORS / 2 else 1.0
		var rank: float = float(k3 % (NEIGHBORS / 2))
		var at: Vector3 = Vector3(side * (5.4 + rank * 2.4), floor_y + 1.6, -2.6 - rank * 0.8)
		var cab: Node3D = Node3D.new()
		cab.position = at
		cab.rotation.y = -side * 0.45
		r.add_child(cab)
		Stage3D.box(cab, Vector3(1.4, 3.2, 1.2), Vector3.ZERO, Stage3D.mat(WOOD, 0.0, 0.6))
		var scr_mat: StandardMaterial3D = Stage3D.glow(NEON_COLORS[k3 % NEON_COLORS.size()], 0.8)
		var scr: MeshInstance3D = Stage3D.box(cab, Vector3(1.0, 0.8, 0.02), Vector3(0, 0.55, 0.61), scr_mat)
		screens.append(scr)
		Stage3D.box(cab, Vector3(1.3, 0.3, 0.02), Vector3(0, 1.35, 0.61), Stage3D.glow(NEON_COLORS[(k3 + 1) % NEON_COLORS.size()], 1.4))
	Stage3D.omni(r, Color(0.9, 0.5, 1.0), 1.2, Vector3(0, floor_y + 5.0, -1.5), 12.0)


## Borne autour de `screen` (repère 2D) : flancs, fronton lumineux avec `title`, cadre doré,
## fond de vitrine. Renvoie le panneau de commandes (manche et bouton à animer).
static func cabinet(st: Stage3D, screen: Rect2, title: String, back_col: Color) -> Dictionary:
	var r: Node3D = st.root
	var px: float = st.px3
	var wood: StandardMaterial3D = Stage3D.mat(WOOD, 0.0, 0.5)
	var c: Vector3 = st.to3(screen.get_center())
	var w: float = screen.size.x * px
	var h: float = screen.size.y * px
	var side_w: float = SIDE_PX * px
	for s: float in [-1.0, 1.0]:
		Stage3D.box(r, Vector3(side_w, h + 1.6, DEPTH + 0.6), c + Vector3(s * (w * 0.5 + side_w * 0.5 + 0.04), 0.1, -DEPTH * 0.5), wood)
		Stage3D.box(r, Vector3(0.02, h + 1.6, 0.02), c + Vector3(s * (w * 0.5 + side_w + 0.05), 0.1, 0.06), Stage3D.glow(Color("ff2e88"), 1.2))
	# Fond de la vitrine (velours sombre éclairé par l'écran) et plafond / plancher.
	Stage3D.box(r, Vector3(w + 0.1, h + 0.1, 0.04), c + Vector3(0, 0, -DEPTH), Stage3D.mat(back_col, 0.0, 0.9))
	Stage3D.box(r, Vector3(w + 0.1, 0.04, DEPTH), c + Vector3(0, h * 0.5 + 0.02, -DEPTH * 0.5), wood)
	Stage3D.box(r, Vector3(w + 0.1, 0.04, DEPTH), c + Vector3(0, -h * 0.5 - 0.02, -DEPTH * 0.5), Stage3D.mat(Color("0d4630"), 0.0, 0.9))
	# Cadre doré.
	var gilt: StandardMaterial3D = Stage3D.mat(Palette.GOLD, 0.45, 0.3)
	var f: float = 18.0 * px
	Stage3D.box(r, Vector3(w + f * 2.0, f, 0.05), c + Vector3(0, h * 0.5 + f * 0.5, 0.02), gilt)
	Stage3D.box(r, Vector3(w + f * 2.0, f, 0.05), c + Vector3(0, -h * 0.5 - f * 0.5, 0.02), gilt)
	Stage3D.box(r, Vector3(f, h, 0.05), c + Vector3(-w * 0.5 - f * 0.5, 0, 0.02), gilt)
	Stage3D.box(r, Vector3(f, h, 0.05), c + Vector3(w * 0.5 + f * 0.5, 0, 0.02), gilt)
	# Fronton lumineux.
	var top: Vector3 = c + Vector3(0, h * 0.5 + 0.42, 0.05)
	Stage3D.box(r, Vector3(w + side_w * 2.0, 0.6, 0.4), top + Vector3(0, 0, -0.2), wood)
	var marquee: MeshInstance3D = Stage3D.box(r, Vector3(w, 0.42, 0.03), top + Vector3(0, 0, 0.01), Stage3D.glow(Color("3a0a2a"), 1.0))
	var lbl: Label3D = Stage3D.text3d(r, title, top + Vector3(0, 0, 0.04), 96, Palette.GOLD_LIGHT, Color("ff2e88"))
	lbl.pixel_size = 0.0016
	# Panneau de commandes en bas, incliné vers le joueur.
	var panel: Node3D = Node3D.new()
	panel.position = c + Vector3(0, -h * 0.5 - 0.3, 0.35)
	panel.rotation.x = -0.6
	r.add_child(panel)
	Stage3D.box(panel, Vector3(w * 0.7, 0.06, 0.6), Vector3.ZERO, Stage3D.mat(Color("1a0d18"), 0.2, 0.5))
	var stick: Node3D = Node3D.new()
	stick.position = Vector3(-w * 0.18, 0.03, 0)
	panel.add_child(stick)
	Stage3D.cylinder(stick, 0.025, 0.24, Vector3(0, 0.12, 0), Stage3D.mat(Color("cccccc"), 0.45, 0.2))
	Stage3D.sphere(stick, 0.07, Vector3(0, 0.26, 0), Stage3D.mat(Color("d11a3c"), 0.1, 0.3))
	var button: MeshInstance3D = Stage3D.cylinder(panel, 0.08, 0.06, Vector3(w * 0.15, 0.05, 0), Stage3D.glow(Color("ffd23f"), 0.8))
	var light: OmniLight3D = Stage3D.omni(r, back_col.lightened(0.6), 1.4, c + Vector3(0, 0, -DEPTH * 0.4), 3.0)
	return {"stick": stick, "button": button, "marquee": marquee, "light": light}
