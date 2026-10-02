# Casco modelado (.glb de Tripo u otro) → malla para el juego + grilla física.
# Uso:
#   blender -b --python tools/hull_to_grid.py -- <entrada.glb> <salida sin extensión> <eslora m> [triángulos, 0 = completa] [manga m] [alto m] [escotilla]
# Textura: si existe <salida>.materials.json se pinta con la paleta (abajo); si no,
# se conserva la textura del modelo (la que trae el .glb, con prioridad).
# Escotilla (solo modelos de una pieza, sin material 'rejilla'): "z0,z1,x0,x1,p" en
# fracción del largo (desde la proa) y del ancho, y p = metros bajo la cubierta
# donde terminan los barrotes. Se deja la rejilla y se borra lo que cuelga bajo
# ella (los modelos macizos traen una caja cerrada bajo la rejilla), hasta 1,5 m:
# así se ve a través de la rejilla y entra la luz a la bodega. La física la tapa.
# Sin manga ni alto (o con "-") la escala es pareja (según la eslora); con ellos, cada eje por
# separado. Escalar el modelo en el editor de Godot no sirve: la grilla (flotación,
# bodega, máscara de agua) sale de aquí.
# Si existe <salida>.materials.json ({"parts": {"N": "material"}}), pinta cada
# pieza tripo_part_N con un material de MATERIALS; las demás quedan 'casco'.
# Escribe <salida>.glb (malla reducida, en ejes de Godot, esquina mínima en el
# origen) y <salida>.grid (cabecera de 3 int32 con el tamaño + un byte por voxel
# en el orden ZXY: índice = y + x·sy + z·sy·sx). Cada voxel que toca la superficie
# del modelo es casco (1); el aire encerrado por el casco es interior (2). Con eso
# HullProfile calcula una vez la masa y las celdas de flotación; en juego no hay
# grilla.
# Supone que la proa del modelo mira a -x en Blender (como sale de Tripo); el
# script la deja en -z de Godot, el frente del barco en el juego.
import sys
import os
import json
import struct
import bpy
import bmesh
import numpy as np
from mathutils import Matrix

sys.path.append(os.path.dirname(__file__))
from bake_uv import bake_texture_transform  # noqa: E402

VOXEL = 0.5
SHELL = 1
INTERIOR = 2
TEXTURES = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
## Materiales estilizados: textura de la paleta (assets/textures, o ninguna) y color.
## Con textura, el color multiplica (Godot lo recibe como albedo_color).
MATERIALS = {
    "casco": ("wood_warm.jpg", (1.0, 1.0, 1.0)),
    "cubierta": ("wood_deck.jpg", (1.0, 1.0, 1.0)),
    "borda": ("wood_dark.jpg", (1.0, 1.0, 1.0)),
    "alquitran": ("tar.jpg", (1.0, 1.0, 1.0)),
    "franja": ("wood_teal.jpg", (1.0, 1.0, 1.0)),
    "oscura": ("wood_dark.jpg", (0.7, 0.7, 0.7)),
    # Rejilla de la escotilla: se borra de la malla (queda el hueco); la física
    # sí la cuenta, así la bodega sigue siendo aire estanco.
    "rejilla": ("wood_dark.jpg", (0.7, 0.7, 0.7)),
}
TILE = 1.5
## Triángulos de la malla de colisión (<salida>_colision.glb).
COLLISION_TRIS = 60000


def make_material(name):
    texture, color = MATERIALS[name]
    material = bpy.data.materials.new(name)
    # Doble cara: una cáscara abierta (cubierta, borda) se ve de los dos lados.
    material.use_backface_culling = False
    material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    if texture is None:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        return material
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(os.path.join(TEXTURES, texture))
    tint = nodes.new("ShaderNodeMix")
    tint.data_type = "RGBA"
    tint.blend_type = "MULTIPLY"
    tint.inputs["Factor"].default_value = 1.0
    tint.inputs["B"].default_value = (*color, 1.0)
    material.node_tree.links.new(image.outputs["Color"], tint.inputs["A"])
    material.node_tree.links.new(tint.outputs["Result"], bsdf.inputs["Base Color"])
    return material

args = sys.argv[sys.argv.index("--") + 1:]
src, out, length = args[0], args[1], float(args[2])
target_tris = int(args[3]) if len(args) > 3 else 40000
beam = float(args[4]) if len(args) > 4 and args[4] != "-" else None
height = float(args[5]) if len(args) > 5 and args[5] != "-" else None
hatch = [float(v) for v in args[6].split(",")] if len(args) > 6 else None

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
paint = os.path.exists(out + ".materials.json")
if paint:
    parts = json.load(open(out + ".materials.json"))["parts"]
    materials = {name: make_material(name) for name in MATERIALS}
    for o in meshes:
        o.data.materials.clear()
        o.data.materials.append(materials[parts.get(o.name.rsplit("_", 1)[-1], "casco")])
else:
    for o in meshes:
        bake_texture_transform(o)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
hull = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Proa de -x a +y en Blender (= -z en Godot) y eslora pedida.
hull.data.transform(Matrix.Rotation(-np.pi / 2, 4, "Z"))
verts = np.array([v.co[:] for v in hull.data.vertices])
size = verts.max(0) - verts.min(0)
uniform = length / size[1]
scale = Matrix.Diagonal((beam / size[0] if beam else uniform, uniform, height / size[2] if height else uniform, 1))
hull.data.transform(scale)
verts = np.array([v.co[:] for v in hull.data.vertices])
# Esquina mínima en el origen: la grilla empieza ahí.
hull.data.transform(Matrix.Translation(-verts.min(0)))
# La cubierta principal justo bajo un borde de voxel: así el tope del voxel (donde
# pisan el jugador y las piezas) coincide con la cubierta que se ve. Altura de la
# cubierta = mediana por área de las caras de 'cubierta' que miran arriba.
# Sin material 'cubierta' (modelo con su textura): todas las caras que miran arriba;
# la cubierta principal es la de más área.
names = [m.name for m in hull.data.materials]
deck_index = names.index("cubierta") if "cubierta" in names else -1
faces = [f for f in hull.data.polygons if f.normal.z > 0.9 and (deck_index < 0 or f.material_index == deck_index)]
if faces:
    heights = np.array([f.center.z for f in faces])
    areas = np.array([f.area for f in faces])
    order = np.argsort(heights)
    deck = heights[order][np.searchsorted(np.cumsum(areas[order]), areas.sum() / 2)]
    lift = (np.ceil(deck / VOXEL) * VOXEL - 0.01 - deck) % VOXEL
    hull.data.transform(Matrix.Translation((0, 0, lift)))
    deck += lift
    print("cubierta a %.2f m, subida %.2f m" % (deck, lift))

# Grilla: con la malla completa, antes de reducirla. Ejes de Godot: x = x,
# y = z de Blender, z = -y de Blender (después de la traslación, -y es negativo:
# se corre por el largo).
# Puntos sobre toda la superficie, a menos de 1/4 de voxel: con solo vértices y
# centros, un triángulo grande (fondo plano de un modelo de Meshy) deja voxels sin
# marcar y el aire de afuera entra a la bodega por ahí.
mesh = hull.data
mesh.calc_loop_triangles()
co = np.empty(len(mesh.vertices) * 3)
mesh.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
tris = np.empty(len(mesh.loop_triangles) * 3, int)
mesh.loop_triangles.foreach_get("vertices", tris)
a_, b_, c_ = (co[i] for i in tris.reshape(-1, 3).T)
longest = np.maximum(np.linalg.norm(b_ - a_, axis=1), np.maximum(np.linalg.norm(c_ - a_, axis=1), np.linalg.norm(c_ - b_, axis=1)))
steps = np.clip(np.ceil(longest / (VOXEL / 4)), 1, 64).astype(int)
samples = [co]
for n in np.unique(steps):
    pick = steps == n
    i, j = np.meshgrid(np.arange(n + 1), np.arange(n + 1))
    keep = i + j <= n
    u, w = i[keep] / n, j[keep] / n
    A, B, C = a_[pick], b_[pick], c_[pick]
    samples.append((A[:, None] + u[None, :, None] * (B - A)[:, None] + w[None, :, None] * (C - A)[:, None]).reshape(-1, 3))
p = np.concatenate(samples)
extent = np.array([p[:, 0].max(), p[:, 2].max(), p[:, 1].max()])
grid = np.ceil(extent / VOXEL).astype(int) + 1
# Centrado en x dentro de la grilla, para que el espejo calce voxel a voxel.
shift = (grid[0] * VOXEL - extent[0]) / 2
godot = np.stack([p[:, 0] + shift, p[:, 2], extent[2] - p[:, 1]], 1)
cells = np.minimum((godot / VOXEL).astype(int), grid - 1)
voxels = np.zeros((grid[2], grid[0], grid[1]), np.uint8)  # [z][x][y] = orden ZXY
voxels[cells[:, 2], cells[:, 0], cells[:, 1]] = SHELL
# Simetría babor-estribor: un modelo de IA nunca es exacto y un costado más
# grueso que el otro escora el barco.
voxels = np.maximum(voxels, voxels[:, ::-1, :])
# Escotilla por región: para la física se tapa (como la rejilla en los cascos por
# piezas), si no el aire de afuera entra por los huecos y no hay bodega.
if hatch and "rejilla" not in [m.name for m in hull.data.materials]:
    x0, x1 = (shift + extent[0] * np.array(hatch[2:4])) / VOXEL
    z0, z1 = extent[2] * np.array(hatch[0:2]) / VOXEL
    voxels[int(z0):int(np.ceil(z1)), int(x0):int(np.ceil(x1)), int(deck / VOXEL)] = SHELL
# Aire interior: lo que no alcanza el aire de afuera entrando por cualquier borde
# de la grilla (también por arriba) sin cruzar casco, con 6 vecinos.
free = voxels == 0
outside = np.zeros_like(free)
for face in (np.s_[0], np.s_[-1], np.s_[:, 0], np.s_[:, -1], np.s_[:, :, 0], np.s_[:, :, -1]):
    outside[face] = free[face]
while True:
    grown = outside.copy()
    grown[1:] |= outside[:-1]
    grown[:-1] |= outside[1:]
    grown[:, 1:] |= outside[:, :-1]
    grown[:, :-1] |= outside[:, 1:]
    grown[:, :, 1:] |= outside[:, :, :-1]
    grown[:, :, :-1] |= outside[:, :, 1:]
    grown &= free
    if (grown == outside).all():
        break
    outside = grown
voxels[free & ~outside] = INTERIOR
with open(out + ".grid", "wb") as f:
    f.write(struct.pack("<3i", *grid))
    f.write(voxels.tobytes())

# Malla del juego: reducida y en los mismos ejes que la grilla.
hull.data.transform(Matrix.Translation((shift, -extent[2], 0)))
# Las piezas de Tripo traen vértices duplicados en las uniones y normales
# cruzadas: sin soldarlas, reducir abre agujeros y caras que miran adentro.
bm = bmesh.new()
bm.from_mesh(hull.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.005)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
# Escotilla abierta: se borran la rejilla y la cubierta que queda bajo ella.
names = [m.name for m in hull.data.materials]
if "rejilla" in names:
    grate = names.index("rejilla")
    deck_index = names.index("cubierta")
    grate_faces = [f for f in bm.faces if f.material_index == grate]
    corners = np.array([v.co[:] for f in grate_faces for v in f.verts])
    lo, hi = corners.min(0), corners.max(0)
    cut = [f for f in grate_faces]
    for f in bm.faces:
        c = f.calc_center_median()
        if f.material_index == deck_index and lo[0] < c.x < hi[0] and lo[1] < c.y < hi[1] and abs(c.z - deck) < 0.6:
            cut.append(f)
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    # En ejes de Godot: x igual, z = -y de Blender, y = z de Blender.
    print("escotilla x %.2f..%.2f z %.2f..%.2f cubierta y %.2f" % (lo[0], hi[0], -hi[1], -lo[1], deck))
elif hatch:
    # Proa en y = 0 de Blender (z = 0 de Godot); el largo va hacia -y.
    corners = np.array([v.co[:] for v in bm.verts])
    lo, hi = corners.min(0), corners.max(0)
    x0, x1 = lo[0] + (hi[0] - lo[0]) * hatch[2], lo[0] + (hi[0] - lo[0]) * hatch[3]
    y0, y1 = hi[1] - (hi[1] - lo[1]) * hatch[1], hi[1] - (hi[1] - lo[1]) * hatch[0]
    bars = hatch[4]
    cut = [f for f in bm.faces if x0 < f.calc_center_median().x < x1 and y0 < f.calc_center_median().y < y1 and deck - 1.5 < f.calc_center_median().z < deck - bars]
    bmesh.ops.delete(bm, geom=cut, context="FACES")
    print("escotilla x %.2f..%.2f z %.2f..%.2f cubierta y %.2f (%d caras)" % (x0, x1, -y1, -y0, deck, len(cut)))
bm.to_mesh(hull.data)
bm.free()
# Coordenadas de textura: proyección de caja en metros, igual en todo el barco.
bpy.ops.object.select_all(action="DESELECT")
hull.select_set(True)
bpy.context.view_layer.objects.active = hull
if paint:
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=TILE, correct_aspect=False, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")


def reduce(tris):
    ratio = min(1.0, tris / max(1, len(hull.data.polygons)))
    mod = hull.modifiers.new("reduce", "DECIMATE")
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)


# Malla que se ve: reducir mucho deforma la textura (colapsa caras que cruzan los
# bordes del mapa UV: tablas en zigzag), así que va con `triángulos` (0 = completa).
if target_tris > 0:
    reduce(target_tris)
bpy.ops.export_scene.gltf(filepath=out + ".glb", use_selection=True, export_yup=True)
visible = len(hull.data.polygons)
# Malla de colisión (HullCollision.source): reducida, sin materiales; con la completa
# armar la forma cóncava tarda segundos y cientos de MB.
reduce(COLLISION_TRIS)
bpy.ops.export_scene.gltf(filepath=out + "_colision.glb", use_selection=True, export_yup=True, export_materials="NONE")
print("grilla", grid.tolist(), "casco", int((voxels == SHELL).sum()), "interior", int((voxels == INTERIOR).sum()), "eslora", length, "triángulos", visible, "colisión", len(hull.data.polygons))
