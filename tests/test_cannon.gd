extends Node
## Chequeo del cañón: tomarlo oculta al jugador y pasa a la cámara del cañón; el
## mouse apunta dentro de los límites; disparar gasta una bala, no dispara de nuevo
## hasta recargar y la bala cae al mar a la distancia de un tiro balístico; sin
## balas no dispara; soltarlo devuelve la cámara y el movimiento.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_cannon

var _ship: ShipBody
var _player: Player
var _control: CannonControl
var _piece: DecorPiece
var _failed: bool = false
var _muzzle: Vector3
var _landed: Vector3 = Vector3.INF
var _in_water: bool = false
var _frame: int = 0


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	_ship = ShipBody.new()
	_ship.profile = HullProfile.box(Vector3i(10, 8, 16), 600.0)
	_ship.waves = WaveSettings.new()
	_ship.freeze = true
	_ship.position.y = 2.0
	add_child(_ship)
	_piece = DecorPiece.create(load("res://items/data/canon.tres"))
	_piece.position = Vector3(2.5, 4.0, 4.0)
	_ship.add_child(_piece)
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	_ship.add_child(_player)
	_player.position = Vector3(4.0, 4.0, 4.0)
	_player.inventory.add(load("res://items/data/bala.tres"), 1)
	_control = CannonControl.new()
	_control.ship = _ship
	_control.player = _player
	add_child(_control)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 5:
		_expect(_piece.kind == ShipPart.Kind.CANNON, "el cañón colocado es una pieza cañón")
		_control.enter(_piece)
		_expect(_player.immobile and _player.hidden and get_viewport().get_camera_3d() != _player.CAMERA, "al tomarlo queda quieto, oculto y con la cámara del cañón")
		_control.aim(200.0, 200.0)
		_expect(is_equal_approx(_control.yaw, _control.yaw_limit) and is_equal_approx(_control.pitch, _control.pitch_max), "la puntería se limita (%.0f°, %.0f°)" % [_control.yaw, _control.pitch])
		_control.aim(-_control.yaw, 20.0 - _control.pitch)
	if _frame == 10:
		var barrel: Node3D = (_piece.model as OpenableProp).pivot()
		var direction: Vector3 = -barrel.global_basis.x
		_expect(absf(rad_to_deg(asin(direction.y)) - 20.0) < 1.0, "el tubo sube 20° (%.1f°)" % rad_to_deg(asin(direction.y)))
		var ball: Cannonball = _control.fire()
		_expect(ball != null and _player.inventory.count_of(_control.ammo) == 0, "dispara y gasta la bala")
		_muzzle = barrel.global_transform * CannonControl.MUZZLE
		ball.landed.connect(func(at: Vector3, in_water: bool) -> void:
			_landed = at
			_in_water = in_water)
		_expect(_control.fire() == null, "no dispara de nuevo mientras recarga (ni sin balas)")
	if _frame == 60 * 12:
		# 70 m/s a 20°: alcance v²·sen(2θ)/g ≈ 320 m (sale de 2 m sobre el agua).
		var reach: float = Vector2(_landed.x - _muzzle.x, _landed.z - _muzzle.z).length()
		_expect(_in_water and reach > 280.0 and reach < 380.0, "la bala cae al mar a %.0f m" % reach)
		_control.exit()
		_expect(not _player.immobile and not _player.hidden and get_viewport().get_camera_3d() == _player.CAMERA, "al soltarlo vuelve la cámara y el movimiento")
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)
