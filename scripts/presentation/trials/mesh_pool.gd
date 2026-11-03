class_name MeshPool
extends RefCounted
## Réserve de MeshInstance3D identiques pour les objets nombreux et changeants d'une épreuve 3D
## (projectiles, éclats, pièces) : `at(i)` crée à la demande, `hide_from(n)` range le reste.

var parent: Node3D = null
var mesh: Mesh = null
var material: Material = null
var items: Array[MeshInstance3D] = []


func _init(p_parent: Node3D, p_mesh: Mesh, p_material: Material) -> void:
	parent = p_parent
	mesh = p_mesh
	material = p_material


## Instance `i` (visible), créée au besoin.
func at(i: int) -> MeshInstance3D:
	while items.size() <= i:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = material
		parent.add_child(mi)
		items.append(mi)
	items[i].visible = true
	return items[i]


## Cache les instances à partir de `n` (celles qui ne servent pas à cette image).
func hide_from(n: int) -> void:
	for k: int in range(n, items.size()):
		items[k].visible = false


## Disque face à la caméra frontale (cylindre couché sur l'axe z).
static func disc(radius: float, thickness: float, segments: int = 24) -> CylinderMesh:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = thickness
	cm.radial_segments = segments
	cm.rings = 1
	return cm


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var c: CapsuleMesh = CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 8
	c.rings = 2
	return c
