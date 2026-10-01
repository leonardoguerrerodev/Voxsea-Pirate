class_name BuoyantBody
extends RigidBody3D
## Cuerpo que flota por puntos. Cada punto es el centro de una celda cúbica de
## lado cell_size; empuja según la fracción de la celda bajo el agua.

const WATER_DENSITY: float = 1000.0

@export var waves: WaveSettings
## Centros de celda en coordenadas locales.
@export var points: PackedVector3Array = PackedVector3Array()
@export_range(0.1, 2.0, 0.05, "suffix:m") var cell_size: float = 0.5
## Arrastre por kilo de agua desplazada (1/s). Amortigua movimiento y giro.
@export_range(0.0, 10.0, 0.1) var water_drag: float = 2.0


func _physics_process(_delta: float) -> void:
	var gravity: float = get_gravity().length()
	var cell_volume: float = cell_size * cell_size * cell_size
	for point: Vector3 in points:
		var offset: Vector3 = global_basis * point
		var world: Vector3 = global_position + offset
		var depth: float = waves.get_wave_height(world.x, world.z, Game.ocean_time) - world.y
		var submerged: float = clampf(depth / cell_size + 0.5, 0.0, 1.0)
		if submerged == 0.0:
			continue
		var displaced: float = WATER_DENSITY * cell_volume * submerged
		var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(offset)
		apply_force(Vector3.UP * displaced * gravity - point_velocity * displaced * water_drag, offset)
