class_name BarSet3D
extends RefCounted
## Décor 3D commun aux épreuves du bar (shaker, verre parfait) : mur de lambris, étagère de
## bouteilles poussiéreuses rétroéclairée, comptoir en acajou au premier plan. Se construit dans
## une Stage3D déjà calée en caméra frontale (Stage3D.frontal) sur la zone de jeu `r`.

const BOTTLE_COLORS: Array[Color] = [
	Color(0.45, 0.25, 0.08), Color(0.13, 0.4, 0.18), Color(0.55, 0.42, 0.12), Color(0.5, 0.1, 0.18), Color(0.2, 0.3, 0.5)
]


static func build(st: Stage3D, r: Rect2) -> void:
	# Hasard purement décoratif, graine fixe : ne consomme pas le flux de l'épreuve.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1987
	var root: Node3D = st.root
	var px: float = st.px3
	var w: float = r.size.x * px * 1.6
	# Lambris : lattes verticales d'acajou sombre.
	for k: int in 40:
		var shade: float = 0.1 + 0.02 * float(k % 3)
		var lath: StandardMaterial3D = Stage3D.mat(Color(shade * 1.4, shade * 0.75, shade * 0.5), 0.0, 0.75)
		var lx: float = -w * 0.5 + w / 40.0 * (float(k) + 0.5)
		Stage3D.box(root, Vector3(w / 40.0 - 0.01, r.size.y * px * 1.6, 0.05), Vector3(lx, 0, -1.2), lath)
	# Étagère du fond, bouteilles en verre teinté, néon ambré derrière.
	var shelf_y: float = st.to3(Vector2(0, r.position.y + r.size.y * 0.42)).y
	Stage3D.box(root, Vector3(w, 0.05, 0.35), Vector3(0, shelf_y, -1.0), Stage3D.mat(Color(0.3, 0.17, 0.08), 0.0, 0.6))
	for k: int in 26:
		var col: Color = BOTTLE_COLORS[rng.randi_range(0, BOTTLE_COLORS.size() - 1)]
		var glass: StandardMaterial3D = Stage3D.mat(col, 0.2, 0.15)
		glass.rim_enabled = true
		glass.rim = 0.4
		var h: float = rng.randf_range(0.32, 0.5)
		var x: float = -w * 0.45 + w * 0.9 * (float(k) + rng.randf_range(0.2, 0.8)) / 26.0
		var base: Vector3 = Vector3(x, shelf_y + 0.025, -1.0)
		Stage3D.cylinder(root, 0.055, h * 0.65, base + Vector3(0, h * 0.325, 0), glass)
		Stage3D.cylinder(root, 0.055, h * 0.15, base + Vector3(0, h * 0.725, 0), glass, 0.022)
		Stage3D.cylinder(root, 0.022, h * 0.2, base + Vector3(0, h * 0.9, 0), glass)
	Stage3D.omni(root, Color(1.0, 0.65, 0.3), 1.4, Vector3(0, shelf_y + 0.6, -0.7), 5.0)
	# Comptoir : plateau verni et façade capitonnée.
	var top_y: float = st.to3(Vector2(0, r.end.y - 16.0)).y
	Stage3D.box(root, Vector3(w, 0.06, 1.2), Vector3(0, top_y - 0.03, 0.2), Stage3D.mat(Color(0.4, 0.2, 0.09), 0.25, 0.25))
	Stage3D.box(root, Vector3(w, 0.03, 0.06), Vector3(0, top_y - 0.03, 0.82), Stage3D.mat(Palette.GOLD_DARK, 0.8, 0.3))
	var lamp: OmniLight3D = Stage3D.omni(root, Color(1.0, 0.86, 0.62), 2.2, Vector3(0, top_y + 1.6, 1.4), 6.0)
	lamp.shadow_enabled = not Settings.b("video", "handheld")
