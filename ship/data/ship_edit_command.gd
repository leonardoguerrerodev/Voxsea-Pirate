class_name ShipEditCommand
extends RefCounted
## Cambio al barco: voxels y el material que queda en cada uno (0 = aire).
## Todo cambio a ShipData pasa por aquí (regla 2); en coop esto viaja por red.

var positions: Array[Vector3i] = []
var values: PackedByteArray = PackedByteArray()


func add(pos: Vector3i, value: int) -> void:
	positions.append(pos)
	values.append(value)


func is_empty() -> bool:
	return positions.is_empty()
