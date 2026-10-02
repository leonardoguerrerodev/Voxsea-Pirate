extends Node
## Chequeo de la brújula: con el jugador en un barco girado y mirando en varias
## direcciones, la aguja apunta al norte del mapa. Y equipada no impide
## caminar; en la mano fuerza la primera persona, al guardarla vuelve la tercera
## y V cambia a primera persona; la rueda acerca la cámara hasta el hombro.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_compass

const LOOKS: Array[float] = [0.0, 1.2, -2.5, 3.0]

var _player: Player
var _compass: Compass
var _failed: bool = false
var _frame: int = 0
var _look: int = 0


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	var floor_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	add_child(floor_body)
	# Como un barco con otro rumbo y algo escorado.
	var ship: Node3D = Node3D.new()
	ship.rotation = Vector3(0.0, 0.7, 0.08)
	add_child(ship)
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	ship.add_child(_player)
	_player.global_position = Vector3(0, 0.1, 0)
	_compass = _player.compass
	_compass.set_equipped(true)


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % 90 == 1 and _look < LOOKS.size():
		_player.HEAD.rotation = Vector3(-0.3, LOOKS[_look], 0.0)
	if _frame % 90 == 89 and _look < LOOKS.size():
		# La brújula está inclinada hacia la cámara: la aguja debe apuntar al norte del
		# mapa proyectado sobre su plano, como una brújula real inclinada.
		var card: Node3D = _compass.get_child(_compass.get_child_count() - 1) as Node3D
		var normal: Vector3 = card.global_basis.y.normalized()
		var north: Vector3 = MapCoords.to_world(Vector2(0.0, 1.0))
		var expected: Vector3 = (north - normal * north.dot(normal)).normalized()
		var error: float = rad_to_deg((-card.global_basis.z).angle_to(expected))
		_expect(error < 3.0 and _compass.visible, "mirando a %.1f rad, la aguja se desvía %.1f° del norte" % [LOOKS[_look], error])
		_look += 1
	if _frame == 90 * LOOKS.size():
		Input.action_press("move_forward")
	var end: int = 90 * LOOKS.size() + 90
	if _frame == end:
		Input.action_release("move_forward")
		_expect(_player.global_position.length() > 2.0, "con la brújula en la mano camina (%.1f m)" % _player.global_position.length())
		_expect(_camera_distance() < 0.3, "con la brújula en la mano la vista es en primera persona (cámara a %.2f m de la cabeza)" % _camera_distance())
		_compass.set_equipped(false)
	if _frame == end + 60:
		_expect(_camera_distance() > 2.0, "al guardarla vuelve a tercera persona (cámara a %.2f m)" % _camera_distance())
		_player.first_person = true  # lo que hace V
	if _frame == end + 120:
		_expect(_camera_distance() < 0.3, "V cambia a primera persona (cámara a %.2f m)" % _camera_distance())
		_player.first_person = false
		# Rueda hacia adentro muchas veces: se acerca hasta el hombro, no más.
		for i: int in 10:
			var wheel: InputEventMouseButton = InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			_player._unhandled_input(wheel)
	if _frame == end + 180:
		_expect(absf(_camera_distance() - _player.zoom_min) < 0.15, "la rueda acerca hasta el hombro y no más (cámara a %.2f m)" % _camera_distance())
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)


func _camera_distance() -> float:
	return _player.CAMERA.global_position.distance_to(_player.HEAD.global_position)
