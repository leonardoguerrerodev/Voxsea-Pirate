extends Node3D
## Depuración del barco, se alterna con F3: centro de gravedad (esfera roja).

@export var ship: ShipBody

@onready var _center: Node3D = $CenterOfMass


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F3:
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		_center.position = ship.center_of_mass
