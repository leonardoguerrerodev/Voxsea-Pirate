extends Camera3D
## Cámara orbital de depuración: botón derecho para orbitar, rueda para zoom.

@export var target: Vector3 = Vector3.ZERO
@export var distance: float = 20.0
@export var sensitivity: float = 0.005

var _yaw: float = 0.0
var _pitch: float = -0.4


func _ready() -> void:
	_update_transform()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var motion: InputEventMouseMotion = event
		_yaw -= motion.relative.x * sensitivity
		# Límite antes de ±90° para que look_at no se trabe en el polo.
		_pitch = clampf(_pitch - motion.relative.y * sensitivity, -1.5, 1.5)
		_update_transform()
	elif event is InputEventMouseButton and event.is_pressed():
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance * 0.9, 2.0)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance * 1.1, 500.0)
		_update_transform()


func _update_transform() -> void:
	var offset: Vector3 = Basis.from_euler(Vector3(_pitch, _yaw, 0.0)) * Vector3(0.0, 0.0, distance)
	global_position = target + offset
	look_at(target)
