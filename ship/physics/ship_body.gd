class_name ShipBody
extends RigidBody3D
## El barco como cuerpo rígido (simulación, regla 3). Masa, centro de gravedad,
## inercia y celdas de flotación salen de su HullProfile (casco fijo, calculado
## una vez); las piezas (ShipPart hijas) suman su masa. Flota por celdas de 1 m.
## Congelado (`freeze`) no flota. La colisión va en un HullCollision hijo; este
## cuerpo no tiene formas.

const WATER_DENSITY: float = 1000.0

@export var waves: WaveSettings
## Ocupación del casco (sale de tools/hull_to_grid.py). Se ignora si `profile`
## se asigna antes de entrar al árbol (tests).
@export_file("*.grid") var grid_path: String
## Densidad de los voxels de casco: fija la masa (madera de 0,5 m de espesor).
@export_range(10.0, 2000.0, 1.0, "suffix:kg/m³") var hull_density: float = 600.0
## Arrastre vertical por kilo de agua desplazada (1/s): amortigua el subir y bajar
## y, en cada celda, el balanceo. El avance y el rumbo los frena el casco (ShipRig).
@export_range(0.0, 10.0, 0.05) var water_drag: float = 2.0
## Amortiguación de escora y cabeceo en el agua (1/s). Sin esto un casco liviano
## sigue cada pendiente del mar (medido: 20° → 7° de escora máx. con 3). No frena
## el giro de rumbo.
@export_range(0.0, 10.0, 0.1) var roll_damping: float = 3.0
## Escora o cabeceo desde donde empuja el adrizado (°): bajo esto manda el mar.
@export_range(0.0, 90.0, 1.0, "suffix:°") var max_heel: float = 25.0
## Rigidez del adrizado sobre `max_heel` (1/s²). El barco nunca se da vuelta, como
## en Sea of Thieves: dado vuelta, quien va en cubierta cae al agua y reaparece
## bajo el casco, en un bucle.
@export_range(0.0, 30.0, 0.5) var righting: float = 6.0

var profile: HullProfile
## Volumen sumergido en el último paso físico (m³). Lo usa ShipRig.
var submerged_volume: float = 0.0


func _enter_tree() -> void:
	if profile == null:
		profile = HullProfile.from_file(grid_path, hull_density)


func _ready() -> void:
	refresh_mass()


## Recalcula masa y centro de gravedad: llamar al poner o sacar piezas.
func refresh_mass() -> void:
	# Las piezas suman masa en su base; su inercia propia es despreciable.
	var total: float = profile.mass
	var moment: Vector3 = profile.center_of_mass * profile.mass
	for part: ShipPart in parts():
		total += part.mass
		moment += part.position * part.mass
	mass = maxf(total, 1.0)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = moment / total if total > 0.0 else Vector3.ZERO
	inertia = profile.inertia.max(Vector3.ONE)


## Piezas hijas; con `kind`, solo las de ese tipo.
func parts(kind: int = -1) -> Array[ShipPart]:
	var result: Array[ShipPart] = []
	for child: Node in get_children():
		var part: ShipPart = child as ShipPart
		if part and (kind < 0 or part.kind == kind):
			result.append(part)
	return result


func _physics_process(_delta: float) -> void:
	if freeze:
		return
	_apply_buoyancy()
	_apply_righting()


func _apply_righting() -> void:
	var up: Vector3 = global_basis.y
	var excess: float = up.angle_to(Vector3.UP) - deg_to_rad(max_heel)
	var axis: Vector3 = up.cross(Vector3.UP)
	if excess <= 0.0 or axis.is_zero_approx():
		return
	# Resorte en ejes del barco, escalado por la inercia: la misma respuesta en
	# cualquier casco.
	var local: Vector3 = global_basis.inverse() * axis.normalized()
	apply_torque(global_basis * (local * inertia * righting * excess))


func _apply_buoyancy() -> void:
	var xform: Transform3D = global_transform
	var columns: PackedVector2Array = PackedVector2Array()
	for point: Vector3 in profile.column_points:
		var world: Vector3 = xform * point
		columns.append(Vector2(world.x, world.z))
	var heights: PackedFloat32Array = waves.sample_heights(columns, Game.ocean_time)
	var gravity: float = get_gravity().length()
	var com: Vector3 = xform * center_of_mass
	var force: Vector3 = Vector3.ZERO
	var torque: Vector3 = Vector3.ZERO
	submerged_volume = 0.0
	for i: int in profile.cell_volumes.size():
		var volume: float = profile.cell_volumes[i]
		var world: Vector3 = xform * profile.cell_centers[i]
		var height: float = profile.cell_heights[i]
		var submerged: float = clampf((heights[profile.cell_columns[i]] - world.y) / height + 0.5, 0.0, 1.0)
		if submerged == 0.0:
			continue
		var displaced: float = WATER_DENSITY * volume * submerged
		submerged_volume += volume * submerged
		var arm: Vector3 = world - com
		var rise: float = (linear_velocity + angular_velocity.cross(arm)).y
		var f: Vector3 = Vector3.UP * displaced * (gravity - rise * water_drag)
		force += f
		torque += arm.cross(f)
	apply_central_force(force)
	if submerged_volume > 0.0:
		# Escora y cabeceo, en ejes del barco; el eje y (rumbo) queda libre.
		var spin: Vector3 = global_basis.inverse() * angular_velocity
		spin.y = 0.0
		torque -= global_basis * (spin * inertia * roll_damping)
	apply_torque(torque)
