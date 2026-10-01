extends Node
## Chequeo de la fase 2. Correr con (ver tests/run.gd):
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/run.tscn -- test_ship

var _emitted: Array[Vector3i] = []
var _failed: bool = false


func _ready() -> void:
	_check_editor()
	_check_mesh()
	print("FALLA" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failed = true
		print("  FALLA: ", what)


func _edit(data: ShipData, pos: Vector3i, value: int) -> ShipEditCommand:
	var command: ShipEditCommand = ShipEditCommand.new()
	command.add(pos, value)
	_emitted.clear()
	return ShipEditor.apply(data, command)


func _check_editor() -> void:
	var data: ShipData = ShipData.new(Vector3i(32, 16, 32))
	data.changed.connect(func(chunk: Vector3i) -> void: _emitted.append(chunk))
	_expect(data.chunk_grid() == Vector3i(2, 1, 2), "chunk_grid")

	_edit(data, Vector3i(5, 5, 5), 1)
	_expect(data.get_voxel(Vector3i(5, 5, 5)) == 1, "escribe el voxel")
	_expect(_emitted == [Vector3i(0, 0, 0)], "voxel interior avisa solo su chunk: %s" % [_emitted])

	_edit(data, Vector3i(15, 5, 5), 1)
	_expect(_emitted.size() == 2 and Vector3i(1, 0, 0) in _emitted, "voxel en cara avisa al vecino: %s" % [_emitted])

	_edit(data, Vector3i(16, 0, 5), 1)
	_expect(_emitted.size() == 2 and Vector3i(0, 0, 0) in _emitted, "vecino fuera de la grilla se ignora: %s" % [_emitted])

	_edit(data, Vector3i(100, 0, 0), 1)
	_expect(_emitted.is_empty(), "fuera de la grilla no hace nada")

	_edit(data, Vector3i(5, 5, 5), 1)
	_expect(_emitted.is_empty(), "sin cambio no avisa")

	# Deshacer con el mismo voxel dos veces en un comando.
	var command: ShipEditCommand = ShipEditCommand.new()
	command.add(Vector3i(1, 1, 1), 2)
	command.add(Vector3i(1, 1, 1), 3)
	var inverse: ShipEditCommand = ShipEditor.apply(data, command)
	_expect(data.get_voxel(Vector3i(1, 1, 1)) == 3, "aplica en orden")
	ShipEditor.apply(data, inverse)
	_expect(data.get_voxel(Vector3i(1, 1, 1)) == 0, "deshacer deja el original")


func _check_mesh() -> void:
	var data: ShipData = ShipData.new(Vector3i(32, 16, 32))
	var ship: ShipMesh = ShipMesh.new()
	ship.catalog = load("res://ship/data/materials.tres")
	add_child(ship)
	ship.set_data(data)

	_edit(data, Vector3i(0, 0, 0), 2)
	_expect(ship.flush() == 1, "un voxel remalla un chunk")
	var mesh_instance: MeshInstance3D = ship.get_child(0)
	var box: AABB = mesh_instance.transform * mesh_instance.mesh.get_aabb()
	_expect(box.position.is_equal_approx(Vector3.ZERO) and box.size.is_equal_approx(Vector3.ONE * ShipData.VOXEL_SIZE), "el voxel (0,0,0) ocupa 0..0,5 m: %s" % box)

	_edit(data, Vector3i(20, 3, 20), 2)
	_expect(ship.flush() == 1, "editar otro chunk remalla solo ese")

	# Chunk lleno: criterio de la fase 2 (< 8 ms).
	var fill: ShipEditCommand = ShipEditCommand.new()
	for z: int in ShipData.CHUNK:
		for y: int in ShipData.CHUNK:
			for x: int in ShipData.CHUNK:
				fill.add(Vector3i(x, y, z), 2)
	ShipEditor.apply(data, fill)
	ship.flush()
	_edit(data, Vector3i(8, 8, 8), 3)
	var t0: int = Time.get_ticks_usec()
	ship.flush()
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("remallado de un chunk lleno: %.3f ms" % ms)
	_expect(ms < 8.0, "remallado bajo 8 ms")
