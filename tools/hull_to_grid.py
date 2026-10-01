# Casco modelado (.glb de Tripo u otro) → malla para el juego + grilla física.
# Uso:
#   blender -b --python tools/hull_to_grid.py -- <entrada.glb> <salida sin extensión> <eslora m> [triángulos]
# Si existe <salida>.materials.json ({"parts": {"N": "material"}}), pinta cada
# pieza tripo_part_N con un material de MATERIALS; las demás quedan 'casco'.
# Escribe <salida>.glb (malla reducida, en ejes de Godot, esquina mínima en el
# origen) y <salida>.grid (cabecera de 3 int32 con el tamaño + un byte por voxel
# en el orden ZXY de ShipData). Cada voxel que toca la superficie del modelo es
# tablón; el aire de adentro lo encuentra ShipHydrostatics.
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

VOXEL = 0.5
PLANK = 2
TEXTURES = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
## Materiales estilizados: textura (o ninguna) y color. Con textura, el color
## multiplica (Godot lo recibe como albedo_color). Metros por repetición de textura.
MATERIALS = {
    "casco": ("planks.jpg", (1.0, 0.85, 0.75)),
    "cubierta": ("planks.jpg", (1.0, 0.95, 0.85)),
    "borda": ("planks.jpg", (0.85, 0.65, 0.5)),
    "alquitran": ("planks.jpg", (0.22, 0.22, 0.26)),
    "franja": (None, (0.15, 0.45, 0.42)),
    "oscura": (None, (0.25, 0.15, 0.08)),
}
TILE = 1.5


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

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
parts = {}
if os.path.exists(out + ".materials.json"):
    parts = json.load(open(out + ".materials.json"))["parts"]
materials = {name: make_material(name) for name in MATERIALS}
for o in meshes:
    o.data.materials.clear()
    o.data.materials.append(materials[parts.get(o.name.rsplit("_", 1)[-1], "casco")])
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
hull.data.transform(Matrix.Scale(length / size[1], 4))
verts = np.array([v.co[:] for v in hull.data.vertices])
# Esquina mínima en el origen: la grilla empieza ahí.
hull.data.transform(Matrix.Translation(-verts.min(0)))
# La cubierta principal justo bajo un borde de voxel: así el tope del voxel (donde
# pisan el jugador y las piezas) coincide con la cubierta que se ve. Altura de la
# cubierta = mediana por área de las caras de 'cubierta' que miran arriba.
deck_index = [m.name for m in hull.data.materials].index("cubierta")
faces = [f for f in hull.data.polygons if f.material_index == deck_index and f.normal.z > 0.9]
if faces:
    heights = np.array([f.center.z for f in faces])
    areas = np.array([f.area for f in faces])
    order = np.argsort(heights)
    deck = heights[order][np.searchsorted(np.cumsum(areas[order]), areas.sum() / 2)]
    lift = (np.ceil(deck / VOXEL) * VOXEL - 0.01 - deck) % VOXEL
    hull.data.transform(Matrix.Translation((0, 0, lift)))
    print("cubierta a %.2f m, subida %.2f m" % (deck + lift, lift))

# Grilla: con la malla completa, antes de reducirla. Ejes de Godot: x = x,
# y = z de Blender, z = -y de Blender (después de la traslación, -y es negativo:
# se corre por el largo).
bm = bmesh.new()
bm.from_mesh(hull.data)
pts = [v.co[:] for v in bm.verts] + [f.calc_center_median()[:] for f in bm.faces]
bm.free()
p = np.array(pts)
extent = np.array([p[:, 0].max(), p[:, 2].max(), p[:, 1].max()])
grid = np.ceil(extent / VOXEL).astype(int) + 1
# Centrado en x dentro de la grilla, para que el espejo calce voxel a voxel.
shift = (grid[0] * VOXEL - extent[0]) / 2
godot = np.stack([p[:, 0] + shift, p[:, 2], extent[2] - p[:, 1]], 1)
cells = np.minimum((godot / VOXEL).astype(int), grid - 1)
voxels = np.zeros((grid[2], grid[0], grid[1]), np.uint8)  # [z][x][y] = orden ZXY
voxels[cells[:, 2], cells[:, 0], cells[:, 1]] = PLANK
# Simetría babor-estribor: un modelo de IA nunca es exacto y un costado más
# grueso que el otro escora el barco.
voxels = np.maximum(voxels, voxels[:, ::-1, :])
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
bm.to_mesh(hull.data)
bm.free()
# Coordenadas de textura: proyección de caja en metros, igual en todo el barco.
bpy.ops.object.select_all(action="DESELECT")
hull.select_set(True)
bpy.context.view_layer.objects.active = hull
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.cube_project(cube_size=TILE, correct_aspect=False, scale_to_bounds=False)
bpy.ops.object.mode_set(mode="OBJECT")
ratio = min(1.0, target_tris / max(1, len(hull.data.polygons)))
mod = hull.modifiers.new("reduce", "DECIMATE")
mod.ratio = ratio
bpy.ops.object.modifier_apply(modifier=mod.name)
bpy.ops.export_scene.gltf(filepath=out + ".glb", use_selection=True, export_yup=True)
print("grilla", grid.tolist(), "voxels", int((voxels > 0).sum()), "eslora", length, "triángulos", len(hull.data.polygons))
