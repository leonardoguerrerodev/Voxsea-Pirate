class_name MaterialCatalog
extends Resource
## Materiales del barco. El id de cada material es su índice; el 0 es aire (vacío).
## Solo agregar al final: los barcos guardados usan estos ids.

@export var materials: Array[VoxelMaterial] = []


func get_material(id: int) -> VoxelMaterial:
	return materials[id] if id < materials.size() else null
