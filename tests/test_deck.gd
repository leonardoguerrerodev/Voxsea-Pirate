extends Node
## Chequeo de la fase 3: un personaje parado en la cubierta viaja con el barco.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_deck

var _ship: ShipBody
var _player: CharacterBody3D
var _start_local: Vector3
var _frame: int = 0


func _ready() -> void:
	_ship = ShipBody.new()
	_ship.profile = HullProfile.box(Vector3i(10, 8, 16), 600.0)
	_ship.waves = WaveSettings.new()
	# Casco visible de 5 × 4 × 8 m (cubierta a 4 m): de ahí sale la colisión.
	var model: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(5, 4, 8)
	model.mesh = box
	model.position = Vector3(2.5, 2, 4)
	_ship.add_child(model)
	var collision: HullCollision = HullCollision.new()
	collision.model = model
	_ship.add_child(collision)
	add_child(_ship)

	_player = CharacterBody3D.new()
	var capsule: CollisionShape3D = CollisionShape3D.new()
	capsule.shape = CapsuleShape3D.new()
	capsule.position.y = 1.0
	_player.add_child(capsule)
	# Hijo del barco: lo lleva la transformación (ver HullCollision). Sin velocidad de
	# plataforma, o el movimiento del barco se le suma dos veces.
	_player.platform_floor_layers = 0
	_ship.add_child(_player)
	# Sobre la cubierta (tope a 4 m locales), al centro.
	_player.global_position = _ship.global_transform * Vector3(2.5, 4.2, 4.0)


func _physics_process(delta: float) -> void:
	_frame += 1
	_player.velocity.y -= 9.8 * delta
	_player.move_and_slide()
	if _frame == 120:
		_start_local = _ship.global_transform.affine_inverse() * _player.global_position
	if _frame > 120:
		# El barco avanza y gira, como navegando.
		_ship.linear_velocity = Vector3(3.0, _ship.linear_velocity.y, 0.0)
		_ship.angular_velocity = Vector3(0.0, 0.3, 0.0)
	if _frame == 120 + 300:
		var local: Vector3 = _ship.global_transform.affine_inverse() * _player.global_position
		var drift: float = Vector2(local.x - _start_local.x, local.z - _start_local.z).length()
		var on_deck: bool = local.y > 3.9 and local.y < 4.5
		print("barco recorrió %.1f m; el personaje se corrió %.2f m sobre la cubierta (y local %.2f)" % [Vector2(_ship.global_position.x, _ship.global_position.z).length(), drift, local.y])
		var ok: bool = drift < 0.5 and on_deck
		print("OK" if ok else "FALLA")
		get_tree().quit(0 if ok else 1)
		set_physics_process(false)
