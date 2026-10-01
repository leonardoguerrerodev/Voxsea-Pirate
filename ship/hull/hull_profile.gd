class_name HullProfile
extends RefCounted
## Perfil físico de un casco fijo (simulación, regla 3): masa, centro de gravedad,
## inercia, eslora y manga, y las celdas de flotación. Se calcula una sola vez
## desde la ocupación que deja tools/hull_to_grid.py (1 = casco, 2 = aire
## interior); en juego no hay grilla.

const VOXEL_SIZE: float = 0.5
const VOXEL_VOLUME: float = 0.125  # 0,5³ m³
const SHELL: int = 1
const INTERIOR: int = 2
## Voxels por lado de una celda de flotación (1 m).
const CELL: int = 2
## Voxels por lado de una columna donde se muestrea la altura del mar (2 m).
## ponytail: un barco no siente olas más cortas que esto; bajar si se nota escalonado.
const COLUMN: int = 4

var size: Vector3i
## 1 = aire interior, por voxel, en orden ZXY (índice = y + x·sy + z·sy·sx). Lo usa
## la máscara de agua.
var interior: PackedByteArray = PackedByteArray()
var mass: float = 0.0
var center_of_mass: Vector3 = Vector3.ZERO
var inertia: Vector3 = Vector3.ZERO
## Eslora (largo en z) y manga (ancho en x) del casco, en metros.
var length: float = 0.0
var beam: float = 0.0
## Celdas de flotación en metros locales al barco: casco más aire interior. Cada
## una reparte su volumen entre la base y el tope de los voxels que la ocupan.
var cell_centers: PackedVector3Array = PackedVector3Array()
var cell_heights: PackedFloat32Array = PackedFloat32Array()
var cell_volumes: PackedFloat32Array = PackedFloat32Array()
var cell_columns: PackedInt32Array = PackedInt32Array()
## Puntos (base del barco) donde se muestrea la altura del mar, uno por columna.
var column_points: PackedVector3Array = PackedVector3Array()


## Lee un .grid (3 int32 con el tamaño + un byte por voxel). No se llama `load`
## para no tapar la función global.
static func from_file(path: String, density: float) -> HullProfile:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	var p_size: Vector3i = Vector3i(file.get_32(), file.get_32(), file.get_32())
	return from_occupancy(p_size, file.get_buffer(p_size.x * p_size.y * p_size.z), density)


## Caja cerrada de pared simple (casco en las caras, aire adentro). Con alto 1
## es una balsa maciza. Para tests.
static func box(p_size: Vector3i, density: float) -> HullProfile:
	var occupancy: PackedByteArray = PackedByteArray()
	occupancy.resize(p_size.x * p_size.y * p_size.z)
	for z: int in p_size.z:
		for x: int in p_size.x:
			for y: int in p_size.y:
				var face: bool = x == 0 or y == 0 or z == 0 or x == p_size.x - 1 or y == p_size.y - 1 or z == p_size.z - 1
				occupancy[y + x * p_size.y + z * p_size.y * p_size.x] = SHELL if face else INTERIOR
	return from_occupancy(p_size, occupancy, density)


static func from_occupancy(p_size: Vector3i, occupancy: PackedByteArray, density: float) -> HullProfile:
	var profile: HullProfile = HullProfile.new()
	profile.size = p_size
	profile._compute_mass(occupancy, density)
	profile._compute_cells(occupancy)
	return profile


func _compute_mass(occupancy: PackedByteArray, density: float) -> void:
	interior.resize(occupancy.size())
	var m: float = density * VOXEL_VOLUME
	var total: float = 0.0
	var moment: Vector3 = Vector3.ZERO
	var second: Vector3 = Vector3.ZERO
	var low: Vector2i = Vector2i(size.x, size.z)
	var high: Vector2i = Vector2i(-1, -1)
	for z: int in size.z:
		for x: int in size.x:
			var base: int = x * size.y + z * size.y * size.x
			for y: int in size.y:
				var value: int = occupancy[base + y]
				if value == INTERIOR:
					interior[base + y] = 1
				if value != SHELL:
					continue
				low = low.min(Vector2i(x, z))
				high = high.max(Vector2i(x, z))
				var p: Vector3 = (Vector3(x, y, z) + Vector3.ONE * 0.5) * VOXEL_SIZE
				total += m
				moment += m * p
				second += m * p * p
	mass = total
	beam = maxf(high.x - low.x + 1, 1) * VOXEL_SIZE
	length = maxf(high.y - low.y + 1, 1) * VOXEL_SIZE
	if total == 0.0:
		return
	center_of_mass = moment / total
	# Ejes paralelos: varianza de la posición por eje, más la inercia propia de
	# cada voxel (m·a²/6). Sin productos de inercia: Godot solo acepta la diagonal.
	var spread: Vector3 = second / total - center_of_mass * center_of_mass
	var own: float = VOXEL_SIZE * VOXEL_SIZE / 6.0
	inertia = Vector3(spread.y + spread.z + own, spread.x + spread.z + own, spread.x + spread.y + own) * total


func _compute_cells(occupancy: PackedByteArray) -> void:
	var columns: Dictionary = {}
	var cells: Vector3i = (size + Vector3i.ONE * (CELL - 1)) / CELL
	for cz: int in cells.z:
		for cx: int in cells.x:
			for cy: int in cells.y:
				var count: int = 0
				var center: Vector3 = Vector3.ZERO
				var y_min: int = size.y
				var y_max: int = -1
				for dz: int in CELL:
					for dx: int in CELL:
						for dy: int in CELL:
							var p: Vector3i = Vector3i(cx, cy, cz) * CELL + Vector3i(dx, dy, dz)
							if p.x >= size.x or p.y >= size.y or p.z >= size.z:
								continue
							if occupancy[p.y + p.x * size.y + p.z * size.y * size.x] == 0:
								continue
							count += 1
							center += Vector3(p) + Vector3.ONE * 0.5
							y_min = mini(y_min, p.y)
							y_max = maxi(y_max, p.y)
				if count == 0:
					continue
				cell_centers.append(center / count * VOXEL_SIZE)
				cell_heights.append((y_max - y_min + 1) * VOXEL_SIZE)
				cell_volumes.append(count * VOXEL_VOLUME)
				var column: Vector2i = Vector2i(cx, cz) * CELL / COLUMN
				if not columns.has(column):
					columns[column] = column_points.size()
					column_points.append(Vector3(column.x * COLUMN + COLUMN * 0.5, 0.0, column.y * COLUMN + COLUMN * 0.5) * VOXEL_SIZE)
				cell_columns.append(columns[column])
