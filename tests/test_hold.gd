extends Node
## Chequeo de la bodega: desde la cubierta, caminando hacia proa por la escotilla,
## el jugador baja la escalera y llega al piso de la bodega; si sigue caminando,
## el casco lo contiene.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_hold

var _ship: ShipBody
var _player: Player
var _frame: int = 0
var _hold: HoldInterior
var _ok: bool = false


func _ready() -> void:
	_ship = ShipBody.new()
	_ship.grid_path = "res://assets/ships/sloop/sloop.grid"
	_ship.waves = WaveSettings.new()
	_ship.freeze = true
	var model: Node3D = (load("res://assets/ships/sloop/sloop.glb") as PackedScene).instantiate()
	_ship.add_child(model)
	var collision: HullCollision = HullCollision.new()
	collision.model = model
	_ship.add_child(collision)
	_hold = HoldInterior.new()
	_hold.hatch_min = Vector2(4.01, 10.21)
	_hold.hatch_max = Vector2(6.49, 12.72)
	_ship.add_child(_hold)
	add_child(_ship)
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	_player.platform_floor_layers = 0
	_ship.add_child(_player)
	_player.position = Vector3(5.25, 5.6, 14.0)
	_player.HEAD.rotation = Vector3.ZERO
	Input.action_press("move_forward")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 60 * 4:
		var p: Vector3 = _player.position
		_ok = p.y < _hold.floor_height + 0.3 and p.y > _hold.floor_height - 0.3 and p.z < _hold.hatch_min.y
		print("  %s a los 4 s está en el piso de la bodega, pasada la escotilla (%s)" % ["ok   " if _ok else "FALLA", p.snapped(Vector3.ONE * 0.01)])
	if _frame == 60 * 8:
		# Siguió caminando contra la proa: el casco lo contiene (no lo atraviesa).
		Input.action_release("move_forward")
		var p: Vector3 = _player.position
		var inside: bool = p.y > 1.0 and p.y < 4.0 and p.z > 0.5
		print("  %s a los 8 s sigue dentro de la bodega (%s)" % ["ok   " if inside else "FALLA", p.snapped(Vector3.ONE * 0.01)])
		_ok = _ok and inside
		print("OK" if _ok else "FALLA")
		get_tree().quit(0 if _ok else 1)
		set_physics_process(false)
