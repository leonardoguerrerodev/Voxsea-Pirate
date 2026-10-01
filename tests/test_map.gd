extends Node
## Chequeo de MapCoords: ejes, ida y vuelta, rumbos y rosa de los vientos.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --path . res://tests/run.tscn -- test_map

var _failed: bool = false


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	_expect(MapCoords.from_world(Vector3(10, 5, -20)) == Vector2(10, 20), "x = este, y = norte (-z)")
	var back: Vector3 = MapCoords.to_world(MapCoords.from_world(Vector3(-3, 0, 7)))
	_expect(back.is_equal_approx(Vector3(-3, 0, 7)), "ida y vuelta mundo → mapa → mundo")
	_expect(is_equal_approx(MapCoords.heading(Vector3.FORWARD), 0.0), "adelante de Godot (-z) es rumbo 0 (N)")
	_expect(is_equal_approx(MapCoords.heading(Vector3.RIGHT), 90.0), "+x es rumbo 90 (E)")
	_expect(is_equal_approx(MapCoords.heading(Vector3.BACK), 180.0), "+z es rumbo 180 (S)")
	_expect(is_equal_approx(MapCoords.heading(Vector3.LEFT), 270.0), "-x es rumbo 270 (O)")
	_expect(MapCoords.compass(44.0) == "NE" and MapCoords.compass(350.0) == "N" and MapCoords.compass(200.0) == "S", "rosa de 8 vientos")
	print("FALLA" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
