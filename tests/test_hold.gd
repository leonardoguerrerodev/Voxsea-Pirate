extends Node
## Chequeo de la bodega: el jugador camina sobre la rejilla sin caer; con E
## (HatchControl.teleport) baja al piso de la bodega, caminando adentro el casco lo
## contiene, y con E sube de nuevo a la cubierta.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_hold

var _ship: ShipBody
var _player: Player
var _frame: int = 0
var _hold: HoldInterior
var _ok: bool = true
var _hatch: HatchControl


func _ready() -> void:
	_ship = ShipBody.new()
	_ship.grid_path = "res://assets/ships/sloop/sloop.grid"
	_ship.waves = WaveSettings.new()
	_ship.freeze = true
	var model: Node3D = (load("res://assets/ships/sloop/sloop.glb") as PackedScene).instantiate()
	_ship.add_child(model)
	var collision: HullCollision = HullCollision.new()
	collision.source = load("res://assets/ships/sloop/sloop_colision.glb")
	collision.model = model
	_ship.add_child(collision)
	_hold = HoldInterior.new()
	_hold.hatch_min = Vector2(3.21, 6.99)
	_hold.hatch_max = Vector2(5.5, 9.49)
	_hold.deck_height = 3.85
	_hold.floor_height = 1.0
	_ship.add_child(_hold)
	add_child(_ship)
	_player = (load("res://player/player.tscn") as PackedScene).instantiate()
	_player.platform_floor_layers = 0
	_ship.add_child(_player)
	_player.position = Vector3(4.25, 4.3, 11.5)
	_player.HEAD.rotation = Vector3.ZERO
	_hatch = HatchControl.new()
	_hatch.player = _player
	_hatch.hold = _hold
	add_child(_hatch)
	Input.action_press("move_forward")


func _physics_process(_delta: float) -> void:
	_frame += 1
	var p: Vector3 = _player.position
	if _frame == 150:
		# Caminó 2,5 s hacia proa por encima de la rejilla: la tapa lo sostiene.
		Input.action_release("move_forward")
		_expect(p.y > _hold.deck_height - 0.4 and p.z < _hold.hatch_max.y, "camina sobre la rejilla sin caer (%s)" % p.snapped(Vector3.ONE * 0.01))
		_hatch.teleport(true)
	if _frame == 210:
		_expect(absf(p.y - _hold.floor_height) < 0.3, "E abajo: queda en el piso de la bodega (%s)" % p.snapped(Vector3.ONE * 0.01))
		Input.action_press("move_forward")
	if _frame == 390:
		# Siguió caminando contra la proa: el casco lo contiene (no lo atraviesa).
		Input.action_release("move_forward")
		_expect(p.y > _hold.floor_height - 0.3 and p.y < _hold.deck_height and p.z > 0.5, "caminando adentro sigue en la bodega (%s)" % p.snapped(Vector3.ONE * 0.01))
		_hatch.teleport(false)
	if _frame == 450:
		_expect(p.y > _hold.deck_height - 0.5, "E arriba: vuelve a la cubierta (%s)" % p.snapped(Vector3.ONE * 0.01))
		print("OK" if _ok else "FALLA")
		get_tree().quit(0 if _ok else 1)
		set_physics_process(false)


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	_ok = _ok and ok
