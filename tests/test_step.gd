extends Node
## Chequeo del jugador: sube un escalón de un voxel y camina hacia donde mira
## aunque su padre esté girado.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_step

var _player: Player
var _frame: int = 0


func _box(size: Vector3, at: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	add_child(body)


func _ready() -> void:
	_box(Vector3(20, 1, 20), Vector3(0, -0.5, 0))  # piso
	_box(Vector3(20, 0.5, 4), Vector3(8, 0.25, 0))  # escalón de un voxel, hacia +x
	# El padre está girado 90°: el "adelante" de la cabeza (−z local) es +x en el mundo.
	var parent: Node3D = Node3D.new()
	parent.rotation.y = -PI / 2.0
	add_child(parent)
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	parent.add_child(_player)
	_player.global_position = Vector3(0, 0.05, 0)
	# La escena del controlador viene girada y su _ready pasa ese giro a la cabeza.
	_player.HEAD.rotation.y = 0.0
	Input.action_press("move_forward")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 150:
		Input.action_release("move_forward")
		var p: Vector3 = _player.global_position
		print("jugador en %s (empezó en 0,0,0; escalón desde x=6, alto 0,5)" % p.snapped(Vector3.ONE * 0.01))
		var ok: bool = p.x > 7.0 and absf(p.z) < 0.5 and p.y > 0.45 and p.y < 0.7
		print("OK" if ok else "FALLA")
		get_tree().quit(0 if ok else 1)
		set_physics_process(false)
