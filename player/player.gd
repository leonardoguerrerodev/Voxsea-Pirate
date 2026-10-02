class_name Player
extends Character
## Jugador en tercera persona: el Quality First Person Controller (addons/fpc)
## mueve el cuerpo y la cabeza; la cámara va atrás en un brazo con resorte (no
## atraviesa el casco) y se ve el personaje (assets/characters/joyero), que mira
## hacia donde camina y anima según la velocidad. Además:
## - Camina hacia donde mira la cámara aunque su padre (el barco) esté girado.
## - Sube solo escalones de un voxel (0,5 m), como los de cualquier bloque puesto.
## - Si cae al agua reaparece donde empezó (no hay nado todavía).
## - B baila.
## - Rueda del mouse: acerca o aleja la cámara (de sobre el hombro a lejos).
## - V cambia a primera persona y vuelve; con la brújula en la mano (Q) siempre es
##   primera persona, y al guardarla vuelve a la vista elegida.

## Un voxel y un poco.
const STEP_HEIGHT: float = 0.55
## Cuánto avanza sobre el escalón al subirlo.
const STEP_AHEAD: float = 0.15
## Bajo esta altura de mundo se considera caído al agua.
const FALL_LIMIT: float = -12.0

## Personaje: modelo con sus animaciones (tools/merge_animations.py).
const CHARACTER: PackedScene = preload("res://assets/characters/joyero/joyero.glb")
## Velocidad (m/s) a la que cada animación de andar se ve sin patinar.
const WALK_PACE: float = 1.4
const RUN_PACE: float = 4.5
## Qué tan rápido gira el personaje hacia donde camina (1/s).
const TURN_RATE: float = 10.0
## Sobre esta escora del barco camina tambaleándose.
const UNSTEADY_HEEL: float = deg_to_rad(15.0)

## Distancia de la cámara detrás de la cabeza (m) y su corrimiento al hombro. La
## rueda la mueve entre `zoom_min` (sobre el hombro, como Fortnite) y `zoom_max`.
@export_range(0.5, 8.0, 0.1) var camera_distance: float = 3.2
@export_range(0.5, 8.0, 0.1) var zoom_min: float = 1.5
@export_range(0.5, 12.0, 0.1) var zoom_max: float = 6.0
@export_range(0.1, 2.0, 0.05) var zoom_step: float = 0.4
@export var camera_shoulder: Vector3 = Vector3(0.4, 0.25, 0.0)

## Qué tan rápido entra o sale la cámara al cambiar de vista (m/s).
const ZOOM_RATE: float = 12.0

## Vista elegida con V (la brújula en la mano fuerza primera persona aparte).
@export var first_person: bool = false

## Lo que lleva encima.
var inventory: Inventory = Inventory.new(24)
## Cuánto más lejos que la cabeza está la cámara: lo suman los rayos de interacción.
var camera_reach: float = 0.0

## La brújula en la mano (hija de la cámara, que pasa al brazo en _ready: no usar su ruta).
@onready var compass: Compass = $Head/Camera/Compass

var _spawn: Transform3D
var _model: Node3D
var _anim: AnimationPlayer
var _dancing: bool = false
var _oneshot: String = ""
var _arm: SpringArm3D
## Oculta el personaje (p. ej. al cañón, que tiene su propia cámara).
var hidden: bool = false


func _ready() -> void:
	super()
	_spawn = transform
	_setup_third_person()


func _setup_third_person() -> void:
	$Mesh.visible = false
	view_bobbing = false
	_arm = SpringArm3D.new()
	_arm.spring_length = camera_distance
	_arm.margin = 0.2
	_arm.position = camera_shoulder
	_arm.add_excluded_object(get_rid())
	HEAD.add_child(_arm)
	CAMERA.reparent(_arm, false)
	CAMERA.transform = Transform3D.IDENTITY
	camera_reach = camera_distance
	_model = CHARACTER.instantiate()
	# El modelo mira a +z (glTF); empieza de espaldas a la cámara, hacia donde mira.
	_model.rotation.y = HEAD.rotation.y + PI
	add_child(_model)
	_anim = _model.find_children("*", "AnimationPlayer", true, false)[0]
	for loop: String in ["reposo", "caminar", "correr", "tambalear", "bailar"]:
		_anim.get_animation(loop).loop_mode = Animation.LOOP_LINEAR
	_anim.play("reposo")


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if event.is_action_pressed("dance") and is_on_floor():
		_dancing = not _dancing
	elif event.is_action_pressed("view"):
		first_person = not first_person
	var wheel: InputEventMouseButton = event as InputEventMouseButton
	if wheel and wheel.pressed and not (first_person or compass.equipped):
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(zoom_min, camera_distance - zoom_step)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(zoom_max, camera_distance + zoom_step)


func _process(delta: float) -> void:
	super(delta)
	_animate(delta)
	_update_view(delta)


## Primera persona = brazo de largo 0 en la cabeza, sin corrimiento, y el personaje
## oculto (la cámara quedaría dentro de él). La transición es corta, no instantánea.
func _update_view(delta: float) -> void:
	var inside: bool = first_person or compass.equipped
	var length: float = 0.0 if inside else camera_distance
	_arm.spring_length = move_toward(_arm.spring_length, length, ZOOM_RATE * delta)
	_arm.position = _arm.position.move_toward(Vector3.ZERO if inside else camera_shoulder, ZOOM_RATE * delta * 0.2)
	camera_reach = _arm.spring_length
	_model.visible = _arm.spring_length > 0.6 and not hidden


## Animación de una vez (levantarse, atacar, morir, golpe_vuelo): manda sobre andar
## y reposo hasta que termina.
func play_once(clip: String) -> void:
	_dancing = false
	_anim.speed_scale = 1.0
	_anim.play(clip, 0.15)
	_oneshot = clip


## Mira hacia donde camina (en ejes del padre: el barco) y elige la animación.
func _animate(delta: float) -> void:
	if _oneshot != "" and _anim.current_animation == _oneshot and _anim.is_playing():
		return
	_oneshot = ""
	# velocity es del mundo; el modelo gira en ejes del jugador (hijo del barco).
	var local: Vector3 = global_basis.inverse() * velocity
	var pace: float = Vector2(local.x, local.z).length()
	if pace > 0.3:
		_dancing = false
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(local.x, local.z), minf(1.0, TURN_RATE * delta))
	var clip: String = "reposo"
	var speed_scale: float = 1.0
	if _dancing:
		clip = "bailar"
	elif pace > 0.3:
		var running: bool = state == "sprinting"
		var heel: float = global_basis.y.angle_to(Vector3.UP)
		clip = "correr" if running else ("tambalear" if heel > UNSTEADY_HEEL else "caminar")
		speed_scale = clampf(pace / (RUN_PACE if running else WALK_PACE), 0.5, 2.0)
	if _anim.current_animation != clip:
		_anim.play(clip, 0.2)
	_anim.speed_scale = speed_scale


func _physics_process(delta: float) -> void:
	super(delta)
	if global_position.y < FALL_LIMIT:
		transform = _spawn
		velocity = Vector3.ZERO
		play_once("levantarse")


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
