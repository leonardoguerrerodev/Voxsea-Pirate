class_name ShipBody
extends RigidBody3D
## El barco como cuerpo rígido (simulación, regla 3). Masa, centro de gravedad e
## inercia salen de los voxels; flota por celdas de 1 m y se inunda por sus
## aberturas sumergidas. `data` se asigna antes de entrar al árbol.
# ponytail: sin forma de colisión todavía (Jolt no acepta mallas cóncavas en
# cuerpos dinámicos). Cajas por greedy de voxels cuando el jugador camine encima.

const WATER_DENSITY: float = 1000.0
## Cada cuánto avanza la inundación (s). Es lenta: no hace falta cada paso físico.
const FLOOD_INTERVAL: float = 0.1

@export var waves: WaveSettings
@export var catalog: MaterialCatalog
## Arrastre por kilo de agua desplazada (1/s). Amortigua movimiento y giro.
@export_range(0.0, 10.0, 0.05) var water_drag: float = 2.0
## Voxels por segundo que entran por cada abertura sumergida.
@export_range(0.0, 50.0, 0.5) var flood_rate: float = 4.0

var data: ShipData
var hydro: ShipHydrostatics

var _dirty: bool = false
var _flood_time: float = 0.0


func _enter_tree() -> void:
	if hydro:
		return
	hydro = ShipHydrostatics.new(data, catalog)
	data.changed.connect(func(_chunk: Vector3i) -> void: _dirty = true)
	_rebuild()


func _physics_process(delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()
	_flood_time += delta
	if _flood_time >= FLOOD_INTERVAL:
		hydro.update_flooding(global_transform, waves, Game.ocean_time, _flood_time, flood_rate)
		_flood_time = 0.0
	_apply_buoyancy()


func _rebuild() -> void:
	hydro.rebuild()
	mass = maxf(hydro.mass, 1.0)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = hydro.center_of_mass
	inertia = hydro.inertia.max(Vector3.ONE)


func _apply_buoyancy() -> void:
	var xform: Transform3D = global_transform
	var columns: PackedVector2Array = PackedVector2Array()
	for point: Vector3 in hydro.column_points:
		var world: Vector3 = xform * point
		columns.append(Vector2(world.x, world.z))
	var heights: PackedFloat32Array = waves.sample_heights(columns, Game.ocean_time)
	var gravity: float = get_gravity().length()
	var com: Vector3 = xform * center_of_mass
	var force: Vector3 = Vector3.ZERO
	var torque: Vector3 = Vector3.ZERO
	for i: int in hydro.cell_volumes.size():
		var volume: float = hydro.cell_volumes[i]
		if volume <= 0.0:
			continue
		var world: Vector3 = xform * hydro.cell_centers[i]
		var height: float = hydro.cell_heights[i]
		var submerged: float = clampf((heights[hydro.cell_columns[i]] - world.y) / height + 0.5, 0.0, 1.0)
		if submerged == 0.0:
			continue
		var displaced: float = WATER_DENSITY * volume * submerged
		var arm: Vector3 = world - com
		var velocity: Vector3 = linear_velocity + angular_velocity.cross(arm)
		var f: Vector3 = Vector3.UP * displaced * gravity - velocity * displaced * water_drag
		force += f
		torque += arm.cross(f)
	apply_central_force(force)
	apply_torque(torque)
