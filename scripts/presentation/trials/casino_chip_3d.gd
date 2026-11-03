class_name CasinoChip3D
extends RefCounted
## Jeton de casino 3D (Jonglage, Tri) : tranche colorée à plots ivoire, faces à couronne ivoire.
## Construit face à la caméra frontale (axe du disque sur z). Purement cosmétique.

const THICK: float = 0.04
const EDGE_PLOTS: int = 6
const SEGMENTS: int = 28


## Jeton de rayon `radius` (m) sous `parent`.
static func build(parent: Node3D, col: Color, radius: float) -> Node3D:
	var n: Node3D = Node3D.new()
	parent.add_child(n)
	var body_m: StandardMaterial3D = Stage3D.mat(col, 0.1, 0.35)
	_disc(n, radius, THICK, 0.0, body_m)
	var ivory: StandardMaterial3D = Stage3D.mat(Palette.IVORY, 0.0, 0.4)
	for f: float in [-1.0, 1.0]:
		_disc(n, radius * 0.77, 0.004, f * (THICK * 0.5 + 0.001), ivory)
		_disc(n, radius * 0.63, 0.005, f * (THICK * 0.5 + 0.002), body_m)
	for k: int in EDGE_PLOTS:
		var a: float = TAU * float(k) / float(EDGE_PLOTS)
		var plot: MeshInstance3D = Stage3D.box(n, Vector3(radius * 0.27, radius * 0.27, THICK * 1.05),
			Vector3(cos(a), sin(a), 0) * radius * 0.97, ivory)
		plot.rotation.z = a
	return n


static func _disc(n: Node3D, radius: float, thick: float, z: float, m: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = MeshPool.disc(radius, thick, SEGMENTS)
	mi.material_override = m
	mi.rotation.x = PI * 0.5
	mi.position.z = z
	n.add_child(mi)
