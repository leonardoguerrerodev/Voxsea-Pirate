class_name Player
extends Character
## Jugador: el Quality First Person Controller (addons/fpc) con tres cambios.
## - Camina hacia donde mira la cámara aunque su padre (el barco) esté girado.
## - Sube solo escalones de un voxel (0,5 m), como los de cualquier bloque puesto.
## - Si cae al agua reaparece donde empezó (no hay nado todavía).

## Un voxel y un poco.
const STEP_HEIGHT: float = 0.55
## Cuánto avanza sobre el escalón al subirlo.
const STEP_AHEAD: float = 0.15
## Bajo esta altura de mundo se considera caído al agua.
const FALL_LIMIT: float = -12.0

## Lo que lleva encima.
var inventory: Inventory = Inventory.new(24)

var _spawn: Transform3D


func _ready() -> void:
	super()
	_spawn = transform


func _physics_process(delta: float) -> void:
	super(delta)
	if global_position.y < FALL_LIMIT:
		transform = _spawn
		velocity = Vector3.ZERO


## Igual al original, pero la dirección sale de la cámara en el mundo (el original
## usa solo el giro de la cabeza, que es relativo al barco) y sube escalones.
func _handle_movement(delta: float, p_input_dir: Vector2) -> void:
	var direction: Vector3 = HEAD.global_basis * Vector3(p_input_dir.x, 0.0, p_input_dir.y)
	direction = Vector3(direction.x, 0.0, direction.z).normalized() * p_input_dir.length()
	var was_grounded: bool = is_on_floor()
	move_and_slide()
	if was_grounded and is_on_wall() and direction.dot(get_wall_normal()) < 0.0:
		_step_up(direction)
	if is_on_floor() or not in_air_momentum:
		var weight: float = acceleration * delta if motion_smoothing else 1.0
		velocity.x = lerp(velocity.x, direction.x * speed, weight)
		velocity.z = lerp(velocity.z, direction.z * speed, weight)


func _step_up(direction: Vector3) -> void:
	var lift: Vector3 = up_direction * STEP_HEIGHT
	var ahead: Vector3 = direction.normalized() * STEP_AHEAD
	# Hay techo encima, o el escalón es más alto que un voxel.
	if test_move(global_transform, lift) or test_move(global_transform.translated(lift), ahead):
		return
	global_position += lift + ahead
