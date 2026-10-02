extends Node
## Chequeo de la decoración: un objeto colocado suma masa y mueve el centro de
## gravedad hacia su lado; recogerlo lo deshace; el cofre se abre y se cierra;
## el timón es una pieza timón con rueda que gira; el farol se prende y se apaga.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_decor

var _failed: bool = false


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	var chest: ItemData = load("res://items/data/cofre.tres")
	var ship: ShipBody = ShipBody.new()
	ship.profile = HullProfile.box(Vector3i(10, 8, 16), 600.0)
	ship.waves = WaveSettings.new()
	ship.freeze = true
	add_child(ship)
	var empty_mass: float = ship.mass
	var empty_com: Vector3 = ship.center_of_mass
	var piece: DecorPiece = DecorPiece.create(chest)
	piece.position = Vector3(0.5, 4.0, 4.0)  # contra el costado de babor (x bajo)
	ship.add_child(piece)
	ship.refresh_mass()
	_expect(is_equal_approx(ship.mass, empty_mass + chest.mass), "suma la masa del cofre (%.0f kg)" % chest.mass)
	_expect(ship.center_of_mass.x < empty_com.x, "el centro de gravedad se corre hacia el cofre")
	_expect(piece.model is OpenableProp, "el cofre armado es abrible")
	var openable: OpenableProp = piece.model
	_expect(openable.toggle() and openable.open, "se abre")
	_expect(openable.toggle() and not openable.open, "se cierra")
	var box: BoxShape3D = (piece.get_child(1).get_child(0) as CollisionShape3D).shape
	_expect(box.size.x > 0.5 and box.size.y > 0.5, "tiene colisión del tamaño del modelo (%s)" % box.size)
	ship.remove_child(piece)
	piece.free()
	ship.refresh_mass()
	_expect(is_equal_approx(ship.mass, empty_mass), "al recogerlo vuelve la masa original")
	# El timón es un objeto: colocado es la pieza timón del barco y su rueda gira.
	var helm: DecorPiece = DecorPiece.create(load("res://items/data/timon.tres"))
	ship.add_child(helm)
	_expect(ship.parts(ShipPart.Kind.HELM) == [helm], "el timón colocado es la pieza timón del barco")
	var wheel: OpenableProp = helm.model
	_expect(not wheel.toggle(), "el timón no se abre (E queda para tomarlo)")
	wheel.set_turn(PI / 2.0)
	var spoke: Node3D = wheel.get_child(1)
	_expect(spoke.basis.x.is_equal_approx(Vector3.UP), "la rueda gira en su eje")
	# El farol se prende y se apaga con E (toggle); apagado no da luz.
	var lamp: DecorPiece = DecorPiece.create(load("res://items/data/farol.tres"))
	ship.add_child(lamp)
	var lantern: Lantern = lamp.model
	var light: OmniLight3D = lantern.get_node("Luz")
	_expect(lantern.open and light.visible, "el farol empieza encendido")
	_expect(lantern.toggle() and not lantern.open and not light.visible, "E lo apaga")
	_expect(lantern.toggle() and lantern.open and light.visible, "E lo prende")
	print("FALLA" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
