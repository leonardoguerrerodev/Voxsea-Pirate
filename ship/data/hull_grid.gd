class_name HullGrid
extends RefCounted
## Carga la grilla física de un casco modelado (.grid de tools/hull_to_grid.py):
## 3 int32 con el tamaño y un byte por voxel en el orden ZXY de ShipData. Escribe
## con un comando (regla 2), así la grilla queda igual que una construida a mano.


static func load_grid(path: String) -> ShipData:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var size: Vector3i = Vector3i(file.get_32(), file.get_32(), file.get_32())
	var bytes: PackedByteArray = file.get_buffer(size.x * size.y * size.z)
	var data: ShipData = ShipData.new(size)
	var command: ShipEditCommand = ShipEditCommand.new()
	for i: int in bytes.size():
		if bytes[i] != 0:
			command.add(Vector3i((i / size.y) % size.x, i % size.y, i / (size.y * size.x)), bytes[i])
	ShipEditor.apply(data, command)
	return data
