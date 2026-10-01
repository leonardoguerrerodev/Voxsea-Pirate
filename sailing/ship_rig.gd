class_name ShipRig
extends Node
## Navegación (simulación, regla 3): velas, timón, resistencia del casco y ancla.
## Va como hijo del ShipBody. Sus mandos (sail_amount, rudder, anchored) los fija
## quien esté al timón; en coop serán comandos de red. Proa = -z local.

const AIR_DENSITY: float = 1.225
const WATER_DENSITY: float = 1000.0
## Arrastre de costado (como una pared): con la quilla, lo que permite ceñir.
const DRAG_SIDE: float = 1.0
const RUDDER_AREA: float = 2.0
## Coeficiente de sustentación del timón a fondo (~35°).
const RUDDER_LIFT: float = 1.2
## Ángulos de vela que se prueban para orientarla sola, a cada banda: de TRIM_MIN
## (la jarcia no deja cazarla más cerca de la crujía; abre la zona prohibida
## contra el viento) a TRIM_LIMIT.
const TRIM_STEPS: int = 12
const TRIM_MIN: float = deg_to_rad(25.0)
const TRIM_LIMIT: float = deg_to_rad(80.0)

# Perillas de calibración (las ajusta el menú dev).
## Un casco de voxels pesa ~10 veces uno real (tablones de 0,5 m); la vela escala
## igual para que acelere como un barco. Subir = más rápido.
@export_range(0.0, 30.0, 0.5) var sail_scale: float = 6.0
## Arrastre de frente (casco en bloques, poco afinado): fija la velocidad máxima.
@export_range(0.05, 3.0, 0.05) var drag_forward: float = 0.4
## El casco avanzando actúa como una aleta: un ángulo de deriva chico ya da una
## fuerza lateral grande (∝ avance · deriva, ~2π·0,5). Sin esto el barco se va de
## costado con el viento y no puede ceñir.
@export_range(0.0, 10.0, 0.1) var keel_lift: float = 3.0
## Freno del ancla (1/s): fracción de la velocidad horizontal que quita por segundo.
@export_range(0.0, 20.0, 0.5) var anchor_drag: float = 6.0

## 0 = velas recogidas, 1 = desplegadas.
var sail_amount: float = 0.0
## -1 = a babor (izquierda), 1 = a estribor (derecha).
var rudder: float = 0.0
var anchored: bool = false
## Ángulo de cada vela respecto de la crujía (rad), por pieza. Lo lee la presentación.
var sail_trims: Dictionary = {}

@onready var ship: ShipBody = get_parent() as ShipBody


func _physics_process(_delta: float) -> void:
	if ship.freeze or ship.submerged_volume <= 0.0:
		return
	var up: Vector3 = Vector3.UP
	var forward: Vector3 = Vector3(-ship.global_basis.z.x, 0.0, -ship.global_basis.z.z).normalized()
	var side: Vector3 = up.cross(forward)  # hacia babor
	var com: Vector3 = ship.global_transform * ship.center_of_mass
	var velocity: Vector3 = Vector3(ship.linear_velocity.x, 0.0, ship.linear_velocity.z)
	var surge: float = velocity.dot(forward)
	var sway: float = velocity.dot(side)
	var yaw_rate: float = ship.angular_velocity.dot(up)
	var hull: HullProfile = ship.profile
	# Áreas mojadas aproximadas: volumen sumergido repartido en el largo o en el ancho.
	var front_area: float = ship.submerged_volume / hull.length
	var side_area: float = ship.submerged_volume / hull.beam
	var q: float = 0.5 * WATER_DENSITY

	# Casco: poca resistencia de frente, mucha de costado.
	var lateral: float = side_area * (DRAG_SIDE * sway * absf(sway) + keel_lift * absf(surge) * sway)
	ship.apply_central_force(-q * (drag_forward * front_area * surge * absf(surge) * forward + lateral * side))
	# Girar empuja agua de costado en toda la eslora: frena el rumbo, más en barcos
	# largos (∫ x·(ωx)² a lo largo del casco ∝ L³).
	var yaw_drag: float = q * DRAG_SIDE * side_area * pow(hull.length, 3.0) / 32.0 * yaw_rate * absf(yaw_rate)
	# Timón en popa: sin avance no hace nada. Positivo = gira a estribor (rumbo horario).
	var rudder_torque: float = -q * RUDDER_AREA * RUDDER_LIFT * rudder * surge * absf(surge) * hull.length * 0.5
	ship.apply_torque(up * (rudder_torque - yaw_drag))

	_apply_sails(forward, com)

	if anchored and not ship.parts(ShipPart.Kind.ANCHOR).is_empty():
		ship.apply_central_force(-velocity * ship.mass * anchor_drag)


func _apply_sails(forward: Vector3, com: Vector3) -> void:
	var sails: Array[ShipPart] = ship.parts(ShipPart.Kind.SAIL)
	if sails.is_empty() or sail_amount <= 0.0:
		return
	var wind: Vector3 = Wind.velocity_at(Game.ocean_time)
	var xform: Transform3D = ship.global_transform
	for sail: ShipPart in sails:
		# La fuerza actúa a media altura del mástil: con mucha vela, el barco escora.
		var local: Vector3 = sail.position + Vector3.UP * sail.mast_height * 0.5
		var point: Vector3 = xform * local
		var moving: Vector3 = ship.linear_velocity + ship.angular_velocity.cross(point - com)
		var apparent: Vector3 = wind - Vector3(moving.x, 0.0, moving.z)
		var best_force: Vector3 = Vector3.ZERO
		var best_trim: float = 0.0
		var best_drive: float = -INF
		for trim: float in trims():
			var force: Vector3 = sail_force(apparent, forward.rotated(Vector3.UP, trim), sail.sail_area * sail_amount) * sail_scale
			if force.dot(forward) > best_drive:
				best_drive = force.dot(forward)
				best_force = force
				best_trim = trim
		sail_trims[sail] = best_trim
		ship.apply_force(best_force, point - ship.global_position)


## Ángulos de vela posibles respecto de la crujía (rad), a ambas bandas.
static func trims() -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	for i: int in TRIM_STEPS:
		var angle: float = lerpf(TRIM_MIN, TRIM_LIMIT, float(i) / (TRIM_STEPS - 1))
		result.append(angle)
		result.append(-angle)
	return result


## Fuerza (sin sail_scale) del viento aparente sobre una vela plana de cuerda `chord` (horizontal).
## Sustentación perpendicular al viento y arrastre a favor; ambas según el ángulo
## de ataque. La sustentación es lo que deja navegar con el viento de costado.
static func sail_force(apparent: Vector3, chord: Vector3, area: float) -> Vector3:
	var speed: float = apparent.length()
	if speed < 0.1 or area <= 0.0:
		return Vector3.ZERO
	var wind_dir: Vector3 = apparent / speed
	var normal: Vector3 = Vector3.UP.cross(chord)
	if normal.dot(wind_dir) < 0.0:
		normal = -normal  # la cara de sotavento
	var attack: float = asin(clampf(normal.dot(wind_dir), 0.0, 1.0))
	var lift_dir: Vector3 = (normal - wind_dir * normal.dot(wind_dir)).normalized()
	# Sustentación máxima a 30° (una vela entra en pérdida ahí) y nula a 90°.
	var lift: float = 1.6 * (sin(3.0 * attack) if attack < PI / 6.0 else cos((attack - PI / 6.0) * 1.5))
	var drag: float = 0.08 + 1.2 * sin(attack) * sin(attack)
	return 0.5 * AIR_DENSITY * speed * speed * area * (lift * lift_dir + drag * wind_dir)
