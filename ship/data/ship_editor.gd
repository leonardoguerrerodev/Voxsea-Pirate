class_name ShipEditor
extends RefCounted
## Único punto de escritura en ShipData (regla 2).


## Aplica el comando y devuelve su inverso (para deshacer). Ignora posiciones
## fuera de la grilla y voxels que no cambian. Avisa cada chunk afectado una vez.
static func apply(data: ShipData, command: ShipEditCommand) -> ShipEditCommand:
	var inverse: ShipEditCommand = ShipEditCommand.new()
	var dirty: Dictionary = {}
	for i: int in command.positions.size():
		var pos: Vector3i = command.positions[i]
		if not data.has_point(pos):
			continue
		var old: int = data.voxels[data.index_of(pos)]
		var value: int = command.values[i]
		if old == value:
			continue
		inverse.add(pos, old)
		data.voxels[data.index_of(pos)] = value
		for chunk: Vector3i in _chunks_touching(pos):
			dirty[chunk] = true
	# Al revés: si un comando toca dos veces el mismo voxel, deshacer deja el original.
	inverse.positions.reverse()
	inverse.values.reverse()
	var grid: Vector3i = data.chunk_grid()
	for chunk: Vector3i in dirty:
		if chunk.x >= 0 and chunk.y >= 0 and chunk.z >= 0 and chunk.x < grid.x and chunk.y < grid.y and chunk.z < grid.z:
			data.changed.emit(chunk)
	return inverse


## El chunk del voxel y, si está en una cara del chunk, el vecino de esa cara
## (su malla depende de este voxel). Solo caras: el mesher no mira diagonales.
static func _chunks_touching(pos: Vector3i) -> Array[Vector3i]:
	var chunk: Vector3i = pos / ShipData.CHUNK
	var result: Array[Vector3i] = [chunk]
	for axis: int in 3:
		var local: int = pos[axis] % ShipData.CHUNK
		var step: Vector3i = Vector3i.ZERO
		step[axis] = 1
		if local == 0:
			result.append(chunk - step)
		elif local == ShipData.CHUNK - 1:
			result.append(chunk + step)
	return result
