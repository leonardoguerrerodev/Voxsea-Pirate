extends Node
## Chequeo de la fase 3: regiones, espejo, línea y deshacer/rehacer.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/run.tscn -- test_build

var _failed: bool = false


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	var size: Vector3i = Vector3i(10, 6, 12)
	var data: ShipData = ShipData.new(size)
	var history: BuildHistory = BuildHistory.new()

	history.apply(data, ShipBuilder.region_command(Vector3i(1, 0, 2), Vector3i(3, 1, 4), 2, false, size))
	_expect(data.voxels.count(2) == 3 * 2 * 3, "caja de 3·2·3 voxels")

	history.apply(data, ShipBuilder.region_command(Vector3i(0, 5, 0), Vector3i(0, 5, 0), 3, true, size))
	_expect(data.get_voxel(Vector3i(0, 5, 0)) == 3 and data.get_voxel(Vector3i(9, 5, 0)) == 3, "espejo pone el voxel en la otra banda")

	var to: Vector3i = ShipBuilder.constrain(Vector3i(2, 2, 2), Vector3i(3, 2, 8), ShipBuilder.Tool.LINE)
	_expect(to == Vector3i(2, 2, 8), "línea se queda con el eje de mayor avance: %s" % to)

	history.undo(data)
	_expect(data.get_voxel(Vector3i(0, 5, 0)) == 0 and data.get_voxel(Vector3i(9, 5, 0)) == 0, "deshacer quita el par espejado")
	history.undo(data)
	_expect(data.voxels.count(0) == data.voxels.size(), "deshacer todo deja el barco vacío")
	_expect(not history.undo(data), "no hay más que deshacer")
	history.redo(data)
	history.redo(data)
	_expect(data.voxels.count(2) == 18 and data.voxels.count(3) == 2, "rehacer todo vuelve al final")

	history.undo(data)
	history.apply(data, ShipBuilder.region_command(Vector3i(5, 0, 5), Vector3i(5, 0, 5), 1, false, size))
	_expect(not history.redo(data), "una edición nueva borra lo que se podía rehacer")

	print("FALLA" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
