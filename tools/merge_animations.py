# Une animaciones a un personaje riggeado, en un solo .glb para Godot.
# Uso:
#   python3 tools/merge_animations.py <personaje.glb> <salida.glb> [--quitar NODO]... <anim.glb> <nombre> [<anim.glb> <nombre>]...
# Las animaciones (Tripo/Meshy: "Animation_*_withSkin.glb") traen solo el esqueleto,
# con los mismos nombres de huesos que el personaje: cada canal se reasigna al hueso
# del personaje con ese nombre. Sus datos binarios se agregan al buffer. --quitar
# saca un nodo de la escena (p. ej. la "Icosphere" de 2 m que deja el rigger).
# Python puro: lee y escribe el contenedor glb (JSON + BIN) sin Blender.
import json
import struct
import sys


def read(path):
    data = open(path, "rb").read()
    size = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + size]), bytearray(data[20 + size + 8:])


def write(path, gltf, binary):
    while len(binary) % 4:
        binary.append(0)
    gltf["buffers"] = [{"byteLength": len(binary)}]
    text = json.dumps(gltf, separators=(",", ":")).encode()
    text += b" " * (-len(text) % 4)
    header = struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(text) + 8 + len(binary))
    chunks = struct.pack("<II", len(text), 0x4E4F534A) + text + struct.pack("<II", len(binary), 0x004E4942) + bytes(binary)
    open(path, "wb").write(header + chunks)


args = sys.argv[1:]
character, binary = read(args.pop(0))
out = args.pop(0)
while args and args[0] == "--quitar":
    args.pop(0)
    name = args.pop(0)
    for scene in character["scenes"]:
        scene["nodes"] = [n for n in scene["nodes"] if character["nodes"][n].get("name") != name]
by_name = {node.get("name"): i for i, node in enumerate(character["nodes"])}
character.setdefault("animations", [])
for path, name in zip(args[0::2], args[1::2]):
    anim, anim_binary = read(path)
    while len(binary) % 4:
        binary.append(0)
    offset = len(binary)
    binary += anim_binary
    view_base = len(character["bufferViews"])
    for view in anim["bufferViews"]:
        character["bufferViews"].append(dict(view, buffer=0, byteOffset=view.get("byteOffset", 0) + offset))
    accessor_base = len(character["accessors"])
    for accessor in anim["accessors"]:
        character["accessors"].append(dict(accessor, bufferView=accessor["bufferView"] + view_base))
    for clip in anim["animations"]:
        samplers = [dict(s, input=s["input"] + accessor_base, output=s["output"] + accessor_base) for s in clip["samplers"]]
        channels = []
        for channel in clip["channels"]:
            bone = anim["nodes"][channel["target"]["node"]].get("name")
            if bone in by_name:
                channels.append({"sampler": channel["sampler"], "target": {"node": by_name[bone], "path": channel["target"]["path"]}})
        character["animations"].append({"name": name, "samplers": samplers, "channels": channels})
        print("%s: %d canales" % (name, len(channels)))
write(out, character, binary)
