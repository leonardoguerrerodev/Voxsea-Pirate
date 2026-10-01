# Hoja de props de Tripo (.glb con varios objetos sueltos) → un .glb por prop.
# Uso:
#   blender -b --python tools/props_import.py -- <spec.json>
# El spec ({"source": ruta .glb, "out": carpeta, "props": [...]}) nombra cada pieza
# suelta por su índice. Las piezas se ordenan por filas (de arriba abajo, como en
# la hoja) y de izquierda a derecha; `"list": true` solo imprime ese orden con
# centro y tamaño, para escribir el spec. Cada prop:
#   {"piece": índice o [índices], "name": "cofre_base", "size": metros de su lado
#    más largo, "material": textura de assets/textures sin extensión, "tint": [r,g,b]
#    opcional, "tris": triángulos (por defecto 4000), "split": opcional
#    {"height": 0..1, "above": textura} pinta con otra textura las caras cuyo centro
#    queda sobre esa fracción del alto (p. ej. el tubo de fierro sobre la cureña)}
# Sale con la base apoyada en y = 0, centrado en x/z, en ejes de Godot.
import sys
import os
import json
import bpy
import numpy as np
from mathutils import Matrix, Vector

TEXTURES = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
## Metros por repetición de textura en los props (más chico que en el casco).
TILE = 0.6

spec_path = sys.argv[sys.argv.index("--") + 1]
spec = json.load(open(spec_path))
root = os.path.dirname(os.path.abspath(spec_path))


def resolve(path):
    return path if os.path.isabs(path) else os.path.normpath(os.path.join(root, path))


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=resolve(spec["source"]))
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
bpy.ops.object.join()
whole = bpy.context.view_layer.objects.active
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.separate(type="LOOSE")
bpy.ops.object.mode_set(mode="OBJECT")


def bounds(o):
    v = np.array([o.matrix_world @ Vector(c) for c in o.bound_box])
    return v.min(0), v.max(0)


pieces = [o for o in bpy.data.objects if o.type == "MESH"]
# Basura de Tripo: fragmentos diminutos.
extent = max((bounds(o)[1] - bounds(o)[0]).max() for o in pieces)
pieces = [o for o in pieces if (bounds(o)[1] - bounds(o)[0]).max() > extent * 0.02]
# Filas: por altura en la hoja (z de Blender) en bandas, luego de izquierda a derecha.
band = extent * 0.08
pieces.sort(key=lambda o: (-round(((bounds(o)[0] + bounds(o)[1]) / 2)[2] / band), ((bounds(o)[0] + bounds(o)[1]) / 2)[0]))

if spec.get("list"):
    for i, o in enumerate(pieces):
        lo, hi = bounds(o)
        print("pieza %02d centro %s tamaño %s tris %d" % (i, np.round((lo + hi) / 2, 3).tolist(), np.round(hi - lo, 3).tolist(), len(o.data.polygons)))
    sys.exit(0)

out_dir = resolve(spec["out"])
os.makedirs(out_dir, exist_ok=True)
materials = {}


def material(name, tint):
    key = (name, tuple(tint))
    if key in materials:
        return materials[key]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.8
    image = nodes.new("ShaderNodeTexImage")
    image.image = bpy.data.images.load(os.path.join(TEXTURES, name + ".jpg"))
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = (*tint, 1.0)
    mat.node_tree.links.new(image.outputs["Color"], mix.inputs["A"])
    mat.node_tree.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    materials[key] = mat
    return mat


for prop in spec["props"]:
    picks = prop["piece"] if isinstance(prop["piece"], list) else [prop["piece"]]
    bpy.ops.object.select_all(action="DESELECT")
    copies = []
    for i in picks:
        copy = pieces[i].copy()
        copy.data = pieces[i].data.copy()
        bpy.context.collection.objects.link(copy)
        copies.append(copy)
    for c in copies:
        c.select_set(True)
    bpy.context.view_layer.objects.active = copies[0]
    if len(copies) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    # Base en y = 0 (z de Blender), centrado, lado más largo = size.
    lo, hi = bounds(obj)
    obj.data.transform(Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    obj.data.transform(Matrix.Scale(prop["size"] / (hi - lo).max(), 4))
    obj.location = (0, 0, 0)
    obj.data.materials.clear()
    obj.data.materials.append(material(prop["material"], prop.get("tint", [1.0, 1.0, 1.0])))
    if "split" in prop:
        split = prop["split"]
        obj.data.materials.append(material(split["above"], split.get("tint", [1.0, 1.0, 1.0])))
        cut = split["height"] * prop["size"] * (hi - lo)[2] / (hi - lo).max()
        for face in obj.data.polygons:
            face.material_index = 1 if face.center.z > cut else 0
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.cube_project(cube_size=TILE, correct_aspect=False, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    ratio = min(1.0, prop.get("tris", 4000) / max(1, len(obj.data.polygons)))
    if ratio < 1.0:
        mod = obj.modifiers.new("reduce", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    path = os.path.join(out_dir, prop["name"] + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True)
    print("prop %s: %d triángulos, %.2f m" % (prop["name"], len(obj.data.polygons), prop["size"]))
    bpy.data.objects.remove(obj)
