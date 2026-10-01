extends Node
## Chequeo del guardado: capturar una partida, pasarla por JSON y restaurarla en
## un barco y un jugador nuevos deja todo igual.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_save

var _failed: bool = false


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ship() -> ShipBody:
	var ship: ShipBody = ShipBody.new()
	ship.profile = HullProfile.box(Vector3i(10, 8, 16), 600.0)
	ship.waves = WaveSettings.new()
	ship.freeze = true
	add_child(ship)
	return ship


func _player() -> Player:
	var player: Player = (load("res://player/player.tscn") as PackedScene).instantiate()
	add_child(player)
	return player


func _ready() -> void:
	var fish: ItemData = load("res://items/data/pescado_cocido.tres")
	var chest: ItemData = load("res://items/data/cofre.tres")
	var ship: ShipBody = _ship()
	var player: Player = _player()
	ship.global_transform = Transform3D(Basis(Vector3.UP, 0.7), Vector3(12, 0, -30))
	player.position = Vector3(1, 4, 2)
	player.inventory.add(fish, 7)
	var piece: DecorPiece = DecorPiece.create(chest)
	piece.transform = Transform3D(Basis(Vector3.UP, 1.2), Vector3(0.5, 4, 4))
	ship.add_child(piece)
	(piece.model as OpenableProp).open = true
	ship.refresh_mass()
	Game.hour = 17.5
	var text: String = JSON.stringify(SaveGame.capture(ship, player))

	Game.hour = 9.0
	var ship2: ShipBody = _ship()
	var player2: Player = _player()
	SaveGame.restore(JSON.parse_string(text), ship2, player2)
	var pieces: Array = ship2.get_children().filter(func(n: Node) -> bool: return n is DecorPiece)
	_expect(is_equal_approx(Game.hour, 17.5), "la hora vuelve")
	_expect(ship2.global_transform.is_equal_approx(ship.global_transform), "el barco vuelve a su lugar y rumbo")
	_expect(player2.position.is_equal_approx(player.position), "el jugador vuelve a su lugar en el barco")
	_expect(player2.inventory.count_of(fish) == 7, "el inventario vuelve (7 pescados)")
	_expect(pieces.size() == 1 and (pieces[0] as DecorPiece).item == chest, "el cofre colocado vuelve")
	_expect(pieces.size() == 1 and (pieces[0] as DecorPiece).transform.is_equal_approx(piece.transform), "en su lugar y con su giro")
	_expect(pieces.size() == 1 and ((pieces[0] as DecorPiece).model as OpenableProp).open, "y abierto")
	_expect(is_equal_approx(ship2.mass, ship.mass), "la masa del barco incluye el cofre")
	print("FALLA" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
