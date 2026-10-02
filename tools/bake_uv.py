# Hornea la transformación de textura (KHR_texture_transform: nodos Mapping que
# crea el importador glTF de Blender) en los UV de la malla y borra los nodos. Los
# .glb de Meshy (meshy2glb) traen los UV cuantizados en 1/16 y la escala ahí; sin
# hornearla, cualquier paso que no lea el nodo (otro importador, Workbench) ve
# parches al azar del atlas. Supone una transformación igual en todo el material
# (la de Meshy) y sin rotación.
import numpy as np


def bake_texture_transform(obj):
    for material in obj.data.materials:
        if material is None or not material.use_nodes:
            continue
        tree = material.node_tree
        maps = [n for n in tree.nodes if n.type == "MAPPING"]
        if not maps:
            continue
        scale = np.array(maps[0].inputs["Scale"].default_value[:2])
        offset = np.array(maps[0].inputs["Location"].default_value[:2])
        for layer in obj.data.uv_layers:
            uv = np.empty(len(obj.data.loops) * 2)
            layer.data.foreach_get("uv", uv)
            layer.data.foreach_set("uv", (uv.reshape(-1, 2) * scale + offset).ravel())
        for node in maps:
            tree.nodes.remove(node)
        return  # los UV se hornean una vez por malla
