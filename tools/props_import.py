# Hoja de props de Tripo (.glb con varios objetos sueltos) → un .glb por prop.
# Uso:
#   blender -b --python tools/props_import.py -- <spec.json>
# El spec ({"source": ruta .glb, "out": carpeta, "props": [...]}) nombra cada pieza
# suelta por su índice. Las piezas se ordenan por filas (de arriba abajo, como en
# la hoja) y de izquierda a derecha; `"list": true` solo imprime ese orden con
# centro y tamaño, para escribir el spec. Cada prop:
#   {"piece": índice o [índices], "name": "cofre_base", "size": metros de su lado
#    más largo, "material": opcional, textura de assets/textures sin extensión (sin
#    él se conserva la textura del .glb, que tiene prioridad), "tint": [r,g,b]
#    opcional, "tris": triángulos (0 = sin reducir; por defecto 4000 si lleva
#    "material" y completo si conserva su textura: reducir deforma la textura),
#    "split": opcional {"height": 0..1, "above": textura} pinta con otra textura
#    las caras cuyo centro queda sobre esa fracción del alto (p. ej. el tubo de
#    fierro sobre la cureña), "rotate": grados en el eje vertical antes de
#    centrarla, "box": [x0, x1, y0, y1, z0, z1] en fracciones de la caja de la
#    pieza (ejes de Blender, z = alto) con "keep": true deja solo lo de adentro y
#    false lo borra; así dos props salen de una pieza en los mismos ejes (el
#    mástil fijo y su verga que gira), "axis": "x" o "z" alinea el eje largo de la
#    pieza (componente principal) con x (acostada: caña, arpón) o z (parada:
#    ancla) cuando la hoja la trae inclinada, "flip": true la da vuelta (180° en x),
#    "inflate": factor engorda una pieza casi plana (peces de perfil: largo en x,
#    alto en z, grosor en y): el centro del cuerpo por `factor`, menos hacia arriba
#    y abajo y nada en la cola, así las aletas siguen delgadas; "lay_side": true la
#    acuesta de lado (el grosor queda vertical, como un pez en la cubierta)}
# Sale con la base apoyada en y = 0, centrado en x/z, en ejes de Godot.
import sys
import os
import json
import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(__file__))
from bake_uv import bake_texture_transform  # noqa: E402

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
bake_texture_transform(whole)
own_materials = list(whole.data.materials)
if "cluster" in spec:
    # `"cluster": fracción`: hojas de Meshy/Tripo sin "por piezas" salen trizadas en
    # miles de pedazos (cortes de UV). Se juntan los que se tocan (con ese margen, en
    # fracción de la hoja) y se separa por grupo. Con numpy: separate LOOSE con miles
    # de pedazos tarda más de 15 minutos.
    mesh = whole.data
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    edges = np.empty(len(mesh.edges) * 2, int)
    mesh.edges.foreach_get("vertices", edges)
    a_, b_ = edges.reshape(-1, 2).T
    # Pedazos que se tocan: vértices en la misma celda de lado `gap` (en dos grillas
    # corridas media celda, para no cortar justo en un borde) se unen como si
    # hubiera una arista entre ellos.
    gap = (co.max(0) - co.min(0)).max() * spec["cluster"]
    links = [a_]
    others = [b_]
    for offset in (0.0, 0.5):
        cell = np.floor(co / gap + offset).astype(np.int64)
        key = (cell[:, 0] * 1000003 + cell[:, 1]) * 1000003 + cell[:, 2]
        order = np.argsort(key, kind="stable")
        same = key[order[1:]] == key[order[:-1]]
        links.append(order[1:][same])
        others.append(order[:-1][same])
    a_ = np.concatenate(links)
    b_ = np.concatenate(others)
    # Componentes conexas: propagar la etiqueta mínima por las aristas + saltos de puntero.
    label = np.arange(len(co))
    while True:
        low = np.minimum(label[a_], label[b_])
        new = label.copy()
        np.minimum.at(new, a_, low)
        np.minimum.at(new, b_, low)
        new = new[new]
        if (new == label).all():
            break
        label = new
    _, vertex_group = np.unique(label, return_inverse=True)
    print("grupos", vertex_group.max() + 1, flush=True)
    face_vertex = np.empty(len(mesh.polygons), int)
    mesh.polygons.foreach_get("loop_start", face_vertex)
    loop_vertex = np.empty(len(mesh.loops), int)
    mesh.loops.foreach_get("vertex_index", loop_vertex)
    mesh.materials.clear()
    for i in range(vertex_group.max() + 1):
        mesh.materials.append(bpy.data.materials.new("grupo%d" % i))
    mesh.polygons.foreach_set("material_index", vertex_group[loop_vertex[face_vertex]])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="MATERIAL")
    bpy.ops.object.mode_set(mode="OBJECT")
    # Los grupos usaron los materiales: cada pieza vuelve al del .glb (Meshy trae uno).
    for o in [o for o in bpy.data.objects if o.type == "MESH"]:
        o.data.materials.clear()
        o.data.materials.append(own_materials[0])
else:
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


def inflate(mesh, factor):
    co = np.empty(len(mesh.vertices) * 3)
    mesh.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    lo, hi = co.min(0), co.max(0)
    u = (co[:, 0] - lo[0]) / (hi[0] - lo[0])  # 0..1 a lo largo
    # Cola: el extremo con el pedúnculo más angosto (alto del cuerpo al 15 % del largo).
    def height_at(f):
        band = co[np.abs(u - f) < 0.03]
        return np.ptp(band[:, 2]) if len(band) else 0.0
    tail_at_start = height_at(0.15) < height_at(0.85)
    from_tail = u if tail_at_start else 1.0 - u
    taper = np.clip((from_tail - 0.15) / 0.2, 0.0, 1.0)  # 0 en la cola, 1 desde el 35 %
    center = (lo[2] + hi[2]) / 2
    radius = (hi[2] - lo[2]) * 0.32  # el cuerpo; las aletas quedan fuera
    body = np.clip(1.0 - ((co[:, 2] - center) / radius) ** 2, 0.0, 1.0)
    mid = (lo[1] + hi[1]) / 2
    co[:, 1] = mid + (co[:, 1] - mid) * (1.0 + (factor - 1.0) * body * taper)
    mesh.vertices.foreach_set("co", co.ravel())
    mesh.update()


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
    if "axis" in prop:
        co = np.array([v.co[:] for v in obj.data.vertices])
        sample = co[:: max(1, len(co) // 20000)]
        main = np.linalg.svd(sample - sample.mean(0), full_matrices=False)[2][0]
        target = Vector((1, 0, 0)) if prop["axis"] == "x" else Vector((0, 0, 1))
        if Vector(main).dot(target) < 0:
            main = -main
        obj.data.transform(Vector(main).rotation_difference(target).to_matrix().to_4x4())
    if prop.get("flip"):
        obj.data.transform(Matrix.Rotation(np.pi, 4, "X"))
    if "inflate" in prop:
        inflate(obj.data, prop["inflate"])
    if prop.get("lay_side"):
        obj.data.transform(Matrix.Rotation(np.pi / 2, 4, "X"))
    if "rotate" in prop:
        obj.data.transform(Matrix.Rotation(np.radians(prop["rotate"]), 4, "Z"))
    # Con los vértices: bound_box no se recalcula después de transformar la malla.
    co = np.array([v.co[:] for v in obj.data.vertices])
    lo, hi = co.min(0) + np.array(obj.location), co.max(0) + np.array(obj.location)
    obj.data.transform(Matrix.Translation(Vector((-(lo[0] + hi[0]) / 2, -(lo[1] + hi[1]) / 2, -lo[2]))))
    obj.data.transform(Matrix.Scale(prop["size"] / (hi - lo).max(), 4))
    if "box" in prop:
        # En coordenadas de la malla (bounds() suma la posición del objeto).
        co = np.array([v.co[:] for v in obj.data.vertices])
        lo, hi = co.min(0), co.max(0)
        b = np.array(prop["box"]).reshape(3, 2)
        inside = []
        for face in obj.data.polygons:
            f = (np.array(face.center) - lo) / (hi - lo)
            inside.append(bool(((f >= b[:, 0]) & (f <= b[:, 1])).all()))
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.faces.ensure_lookup_table()
        keep = prop.get("keep", True)
        bmesh.ops.delete(bm, geom=[f for f, i in zip(bm.faces, inside) if i != keep], context="FACES")
        bm.to_mesh(obj.data)
        bm.free()
    obj.location = (0, 0, 0)
    if "material" in prop:
        obj.data.materials.clear()
        obj.data.materials.append(material(prop["material"], prop.get("tint", [1.0, 1.0, 1.0])))
    if "split" in prop:
        split = prop["split"]
        obj.data.materials.append(material(split["above"], split.get("tint", [1.0, 1.0, 1.0])))
        cut = split["height"] * prop["size"] * (hi - lo)[2] / (hi - lo).max()
        for face in obj.data.polygons:
            face.material_index = 1 if face.center.z > cut else 0
    if "material" in prop:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.cube_project(cube_size=TILE, correct_aspect=False, scale_to_bounds=False)
        bpy.ops.object.mode_set(mode="OBJECT")
    tris = prop.get("tris", 4000 if "material" in prop else 0)
    ratio = min(1.0, tris / max(1, len(obj.data.polygons))) if tris > 0 else 1.0
    if ratio < 1.0:
        mod = obj.modifiers.new("reduce", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    path = os.path.join(out_dir, prop["name"] + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_yup=True)
    print("prop %s: %d triángulos, %.2f m" % (prop["name"], len(obj.data.polygons), prop["size"]), flush=True)
    bpy.data.objects.remove(obj)
