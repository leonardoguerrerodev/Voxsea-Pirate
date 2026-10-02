class_name Cannonball
extends Node3D
## Bala de cañón (simulación + presentación mínima): vuela con gravedad y en cada
## paso físico tira un rayo del punto anterior al nuevo; si toca algo o cae bajo
## la superficie del mar (WaveSettings, la misma fuente que la flotación) se
## detiene, salpica y avisa con `landed`. Va en el mundo, no en el barco.

signal landed(at: Vector3, in_water: bool)

const GRAVITY: float = 9.8
const LIFETIME: float = 20.0
## Al salir no choca con el propio cañón ni con el barco (s).
const ARM_TIME: float = 0.12
const MODEL: PackedScene = preload("res://assets/props/bala.glb")

var velocity: Vector3 = Vector3.ZERO
var waves: WaveSettings
var _age: float = 0.0


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	# El modelo apoya en y = 0: se centra en la trayectoria.
	model.position.y = -0.075
	add_child(model)


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y -= GRAVITY * delta
	var from: Vector3 = global_position
	var to: Vector3 = from + velocity * delta
	if _age > ARM_TIME:
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
		if not hit.is_empty():
			_impact(hit.position, false)
			return
	var water: float = waves.get_wave_height(to.x, to.z, Game.ocean_time)
	if to.y < water:
		_impact(Vector3(to.x, water, to.z), true)
		return
	global_position = to
	if _age > LIFETIME:
		queue_free()


func _impact(at: Vector3, in_water: bool) -> void:
	var splash: CPUParticles3D = Effects.burst(Color(0.85, 0.93, 1.0) if in_water else Color(0.45, 0.32, 0.2), 9.0 if in_water else 5.0)
	get_parent().add_child(splash)
	splash.global_position = at
	landed.emit(at, in_water)
	queue_free()
