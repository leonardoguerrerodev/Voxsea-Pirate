class_name ShipData
extends RefCounted
## Grilla voxel del barco (simulación pura, regla 3). Solo ShipEditor escribe en
## `voxels` (regla 2); el resto lee y escucha `changed`.

## Un chunk cambió y hay que recalcular lo que dependa de él.
signal changed(chunk: Vector3i)

const CHUNK: int = 16
const VOXEL_SIZE: float = 0.5
const MAX_SIZE: Vector3i = Vector3i(64, 32, 128)

var size: Vector3i
## Id de material por voxel (0 = aire). Orden ZXY, el mismo de VoxelBuffer de
## Voxel Tools, para copiarlo sin reordenar: índice = y + x·sy + z·sy·sx.
var voxels: PackedByteArray = PackedByteArray()


func _init(p_size: Vector3i) -> void:
	size = p_size.clamp(Vector3i.ONE, MAX_SIZE)
	voxels.resize(size.x * size.y * size.z)


func has_point(pos: Vector3i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.z >= 0 and pos.x < size.x and pos.y < size.y and pos.z < size.z


func index_of(pos: Vector3i) -> int:
	return pos.y + pos.x * size.y + pos.z * size.y * size.x


## Material en pos; fuera de la grilla es aire.
func get_voxel(pos: Vector3i) -> int:
	return voxels[index_of(pos)] if has_point(pos) else 0


## Cantidad de chunks por eje.
func chunk_grid() -> Vector3i:
	return (size + Vector3i.ONE * (CHUNK - 1)) / CHUNK
