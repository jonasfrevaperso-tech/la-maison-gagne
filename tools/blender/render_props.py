"""Rendu des props 3D low-poly en sprites (Blender 4.x/5.x, mode arrière-plan).

Usage : blender -b --factory-startup -P tools/blender/render_props.py -- <dossier_sortie>
Produit : chip_<couleur>.png (128²), ball.png (64²), title_wheel.png (1024², vue 3/4), fond transparent.
Aucune ressource externe : géométrie et matériaux construits en code, palette de la bible artistique.
"""
import math
import pathlib
import sys

import bpy

OUT = pathlib.Path(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "assets/sprites")
OUT.mkdir(parents=True, exist_ok=True)

PAL = {
    "red": (0.58, 0.006, 0.027), "black": (0.024, 0.02, 0.03), "green": (0.004, 0.25, 0.08), "gold": (0.66, 0.43, 0.04),
    "ivory": (0.91, 0.87, 0.79), "magenta": (1.0, 0.027, 0.24), "cyan": (0.022, 0.75, 1.0), "emerald": (0.027, 0.79, 0.39),
    "wood": (0.12, 0.035, 0.018),
}
ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
RED = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    try:
        sc.render.engine = "CYCLES"
        sc.cycles.samples = 48
        sc.cycles.device = "CPU"
    except (TypeError, AttributeError):
        pass
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.05, 0.03, 0.05, 1)
    bg.inputs[1].default_value = 0.6
    sc.world = world
    return sc


def mat(name, color, metal=0.0, rough=0.4, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0 and "Emission Strength" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*color, 1)
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def light(loc, energy, size=2.0):
    d = bpy.data.lights.new("l", "AREA")
    d.energy = energy
    d.size = size
    o = bpy.data.objects.new("l", d)
    o.location = loc
    o.rotation_euler = (0, 0, 0)
    bpy.context.scene.collection.objects.link(o)
    direction = -o.location
    o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def camera(loc, target=(0, 0, 0), ortho=None, lens=50):
    cd = bpy.data.cameras.new("c")
    if ortho:
        cd.type = "ORTHO"
        cd.ortho_scale = ortho
    else:
        cd.lens = lens
    co = bpy.data.objects.new("c", cd)
    co.location = loc
    import mathutils
    co.rotation_euler = (mathutils.Vector(target) - mathutils.Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.collection.objects.link(co)
    bpy.context.scene.camera = co


def render(path, res):
    sc = bpy.context.scene
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def chip(color_name):
    reset()
    bpy.ops.mesh.primitive_cylinder_add(vertices=48, radius=1, depth=0.18)
    body = bpy.context.object
    body.data.materials.append(mat("body", PAL[color_name], rough=0.35))
    for k in range(8):
        a = k * math.pi / 4
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 0.93, math.sin(a) * 0.93, 0))
        s = bpy.context.object
        s.scale = (0.12, 0.2, 0.1)
        s.rotation_euler = (0, 0, a)
        s.data.materials.append(mat("stripe", PAL["ivory"], rough=0.5))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.03, location=(0, 0, 0.09))
    bpy.context.object.data.materials.append(mat("ring", PAL["gold"], metal=1.0, rough=0.25))
    camera((0, -0.3, 4), ortho=2.3)
    light((2, -2, 4), 160)
    light((-3, 2, 3), 60)
    render(OUT / f"chip_{color_name}.png", 128)


def ball():
    reset()
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=1)
    bpy.ops.object.shade_smooth()
    bpy.context.object.data.materials.append(mat("ball", PAL["ivory"], rough=0.12))
    camera((0, -0.5, 4), ortho=2.2)
    light((2, -2, 4), 400, 1.0)
    light((-3, 1, 2), 80)
    render(OUT / "ball.png", 64)


def wheel():
    reset()
    n = len(ORDER)
    # Cuvette en bois
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=3.2, depth=0.5, location=(0, 0, -0.25))
    bpy.context.object.data.materials.append(mat("wood", PAL["wood"], rough=0.45))
    bpy.ops.mesh.primitive_torus_add(major_radius=3.15, minor_radius=0.09, location=(0, 0, 0.02))
    bpy.context.object.data.materials.append(mat("rim", PAL["gold"], metal=1.0, rough=0.2))
    # Secteurs des cases (prismes)
    mats = {"red": mat("r", PAL["red"], rough=0.35), "black": mat("b", PAL["black"], rough=0.35), "green": mat("g", PAL["green"], rough=0.35)}
    for i, num in enumerate(ORDER):
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 1) / n
        r0, r1 = 1.6, 2.6
        verts = [(math.cos(a0) * r0, math.sin(a0) * r0, 0), (math.cos(a1) * r0, math.sin(a1) * r0, 0),
                 (math.cos(a1) * r1, math.sin(a1) * r1, 0), (math.cos(a0) * r1, math.sin(a0) * r1, 0)]
        top = [(x, y, 0.05) for x, y, _ in verts]
        me = bpy.data.meshes.new("p")
        me.from_pydata(verts + top, [], [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
        ob = bpy.data.objects.new("p", me)
        bpy.context.scene.collection.objects.link(ob)
        key = "green" if num == 0 else ("red" if num in RED else "black")
        ob.data.materials.append(mats[key])
        # séparateurs dorés
        bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a0) * 2.1, math.sin(a0) * 2.1, 0.09))
        sep = bpy.context.object
        sep.scale = (1.0, 0.025, 0.06)
        sep.rotation_euler = (0, 0, a0)
        sep.data.materials.append(mat("sep", PAL["gold"], metal=1.0, rough=0.3))
    # Cône central et tourelle
    bpy.ops.mesh.primitive_cone_add(vertices=64, radius1=1.6, radius2=0.5, depth=0.5, location=(0, 0, 0.25))
    bpy.context.object.data.materials.append(mat("cone", PAL["wood"], rough=0.4))
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=0.18, depth=0.9, location=(0, 0, 0.7))
    bpy.context.object.data.materials.append(mat("turret", PAL["gold"], metal=1.0, rough=0.15))
    for k in range(4):
        a = k * math.pi / 2
        bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.05, depth=1.4, location=(math.cos(a) * 0.6, math.sin(a) * 0.6, 0.95))
        arm = bpy.context.object
        arm.rotation_euler = (math.pi / 2, 0, a + math.pi / 2)
        arm.data.materials.append(mat("arm", PAL["gold"], metal=1.0, rough=0.2))
    # Bille
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(2.25, 0.4, 0.2))
    bpy.ops.object.shade_smooth()
    bpy.context.object.data.materials.append(mat("ball", PAL["ivory"], rough=0.1))
    camera((0, -9.5, 6.8), lens=50)
    light((4, -4, 6), 420, 3)
    light((-5, 2, 4), 160, 3)
    light((0, 5, 3), 120, 2)
    render(OUT / "title_wheel.png", 1024)


for c in ("magenta", "cyan", "emerald", "gold"):
    chip(c)
ball()
wheel()
print("RENDER_DONE", OUT)
