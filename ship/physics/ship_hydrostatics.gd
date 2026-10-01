class_name ShipHydrostatics
extends RefCounted
## Hidrostática del barco (simulación pura, regla 3). Desde ShipData calcula masa,
## centro de gravedad e inercia; el aire interior por compartimentos; el volumen
## desplazado por celdas de 1 m; y la inundación por aberturas sumergidas.

const VOXEL_VOLUME: float = 0.125  # 0,5³ m³
## Voxels por lado de una celda de flotabilidad (1 m).
const CELL: int = 2
## Voxels por lado de una columna donde se muestrea la altura del mar (2 m).
## ponytail: un barco no siente olas más cortas que esto; bajar si se nota escalonado.
const COLUMN: int = 4
const DIRS: Array[Vector3i] = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]


## Un volumen de aire interior conectado.
class Compartment:
	## Voxels de abajo hacia arriba: se inunda en ese orden.
	var cells: PackedInt32Array = PackedInt32Array()
	## Voxels que tocan aire exterior: por ahí entra el agua.
	var openings: PackedInt32Array = PackedInt32Array()
	## Agua que ya entró (en voxels) y falta ubicar.
	var pending: float = 0.0
	var next_index: int = 0


var data: ShipData
var catalog: MaterialCatalog

var mass: float = 0.0
var center_of_mass: Vector3 = Vector3.ZERO
var inertia: Vector3 = Vector3.ZERO
## Eslora (largo en z) y manga (ancho en x) de lo construido, en metros.
var length: float = 0.0
var beam: float = 0.0
## Piezas funcionales: VoxelMaterial.Part → Array[Vector3i] de sus celdas.
var parts: Dictionary = {}

var compartments: Array[Compartment] = []
## Aire interior seco: id de compartimento + 1 por voxel (0 = no). Es un dato
## derivado que solo escribe esta clase; lo leen la máscara de agua y la depuración.
var dry_air: ShipData
## 1 = aire interior inundado. Sobrevive a las ediciones: tapar el agujero no achica.
var flooded: PackedByteArray = PackedByteArray()

## Celdas de flotabilidad, en metros locales al barco. Una celda reparte su
## volumen entre la base y el tope de los voxels que la ocupan.
var cell_centers: PackedVector3Array = PackedVector3Array()
var cell_heights: PackedFloat32Array = PackedFloat32Array()
var cell_volumes: PackedFloat32Array = PackedFloat32Array()
var cell_columns: PackedInt32Array = PackedInt32Array()
## Puntos (base del barco) donde se muestrea la altura del mar, uno por columna.
var column_points: PackedVector3Array = PackedVector3Array()

var _interior: PackedByteArray = PackedByteArray()
var _cell_of_voxel: PackedInt32Array = PackedInt32Array()


func _init(p_data: ShipData, p_catalog: MaterialCatalog) -> void:
	data = p_data
	catalog = p_catalog
	dry_air = ShipData.new(data.size)
	flooded.resize(data.voxels.size())


## Recalcula todo tras una edición del barco.
func rebuild() -> void:
	_compute_mass()
	_find_interior()
	_find_compartments()
	_compute_cells()
	_write_dry_air()


## Avanza la inundación dt segundos con `rate` voxels/s por abertura sumergida.
## Devuelve true si entró agua (cambian cell_volumes y dry_air).
func update_flooding(xform: Transform3D, waves: WaveSettings, t: float, dt: float, rate: float) -> bool:
	var dirty: Dictionary = {}
	for c: int in compartments.size():
		var comp: Compartment = compartments[c]
		if comp.openings.is_empty():
			continue
		# ponytail: muestrea hasta ~16 aberturas; una cubierta abierta tiene cientos.
		var step: int = maxi(1, comp.openings.size() / 16)
		var submerged: int = 0
		for k: int in range(0, comp.openings.size(), step):
			if _is_underwater(comp.openings[k], xform, waves, t):
				submerged += step
		comp.pending += submerged * rate * dt
		while comp.pending >= 1.0:
			while comp.next_index < comp.cells.size() and flooded[comp.cells[comp.next_index]] == 1:
				comp.next_index += 1
			# Vasos comunicantes: el agua de adentro no sube más que la de afuera.
			if comp.next_index == comp.cells.size() or not _is_underwater(comp.cells[comp.next_index], xform, waves, t):
				comp.pending = 0.0
				break
			var voxel: int = comp.cells[comp.next_index]
			flooded[voxel] = 1
			dry_air.voxels[voxel] = 0
			cell_volumes[_cell_of_voxel[voxel]] -= VOXEL_VOLUME
			dirty[_voxel_position(voxel) / ShipData.CHUNK] = true
			comp.pending -= 1.0
	for chunk: Vector3i in dirty:
		dry_air.changed.emit(chunk)
	return not dirty.is_empty()


func flooded_count() -> int:
	return flooded.count(1)


func _compute_mass() -> void:
	var densities: PackedFloat32Array = PackedFloat32Array()
	densities.resize(256)
	var part_of: PackedByteArray = PackedByteArray()
	part_of.resize(256)
	for id: int in catalog.materials.size():
		var material: VoxelMaterial = catalog.get_material(id)
		if material:
			densities[id] = material.density
			part_of[id] = material.part
	var s: Vector3i = data.size
	var total: float = 0.0
	var moment: Vector3 = Vector3.ZERO
	var second: Vector3 = Vector3.ZERO
	var low: Vector2i = Vector2i(s.x, s.z)
	var high: Vector2i = Vector2i(-1, -1)
	parts.clear()
	for z: int in s.z:
		for x: int in s.x:
			var base: int = x * s.y + z * s.y * s.x
			for y: int in s.y:
				var id: int = data.voxels[base + y]
				if id == 0:
					continue
				low = low.min(Vector2i(x, z))
				high = high.max(Vector2i(x, z))
				if part_of[id] != VoxelMaterial.Part.NONE:
					if not parts.has(part_of[id]):
						parts[part_of[id]] = [] as Array[Vector3i]
					parts[part_of[id]].append(Vector3i(x, y, z))
				var m: float = densities[id] * VOXEL_VOLUME
				var p: Vector3 = (Vector3(x, y, z) + Vector3.ONE * 0.5) * ShipData.VOXEL_SIZE
				total += m
				moment += m * p
				second += m * p * p
	mass = total
	beam = maxf(high.x - low.x + 1, 1) * ShipData.VOXEL_SIZE
	length = maxf(high.y - low.y + 1, 1) * ShipData.VOXEL_SIZE
	if total == 0.0:
		center_of_mass = Vector3.ZERO
		inertia = Vector3.ZERO
		return
	center_of_mass = moment / total
	# Ejes paralelos: varianza de la posición por eje, más la inercia propia de
	# cada voxel (m·a²/6). Sin productos de inercia: Godot solo acepta la diagonal.
	var spread: Vector3 = second / total - center_of_mass * center_of_mass
	var own: float = ShipData.VOXEL_SIZE * ShipData.VOXEL_SIZE / 6.0
	inertia = Vector3(spread.y + spread.z + own, spread.x + spread.z + own, spread.x + spread.y + own) * total


## Aire interior: mirando hacia abajo y hacia los 4 lados se choca con casco.
## Hacia arriba no se mira, así un bote sin cubierta tiene interior.
# ponytail: un agujero deja como exterior la fila de aire alineada con él; el
# resto del compartimento se inunda por esa fila. Flood fill real si molesta.
func _find_interior() -> void:
	var s: Vector3i = data.size
	var v: PackedByteArray = data.voxels
	var hits: PackedByteArray = PackedByteArray()
	hits.resize(v.size())
	var sxy: int = s.y * s.x
	for z: int in s.z:
		for x: int in s.x:
			var base: int = x * s.y + z * sxy
			var seen: bool = false
			for y: int in s.y:
				if v[base + y] != 0:
					seen = true
				elif seen:
					hits[base + y] += 1
	for z: int in s.z:
		for y: int in s.y:
			var seen_low: bool = false
			var seen_high: bool = false
			for x: int in s.x:
				var i: int = y + x * s.y + z * sxy
				if v[i] != 0:
					seen_low = true
				elif seen_low:
					hits[i] += 1
				var j: int = y + (s.x - 1 - x) * s.y + z * sxy
				if v[j] != 0:
					seen_high = true
				elif seen_high:
					hits[j] += 1
	for x: int in s.x:
		for y: int in s.y:
			var seen_low: bool = false
			var seen_high: bool = false
			for z: int in s.z:
				var i: int = y + x * s.y + z * sxy
				if v[i] != 0:
					seen_low = true
				elif seen_low:
					hits[i] += 1
				var j: int = y + x * s.y + (s.z - 1 - z) * sxy
				if v[j] != 0:
					seen_high = true
				elif seen_high:
					hits[j] += 1
	_interior.resize(v.size())
	for i: int in v.size():
		_interior[i] = 1 if hits[i] == 5 else 0
		if _interior[i] == 0:
			flooded[i] = 0


func _find_compartments() -> void:
	compartments.clear()
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(data.voxels.size())
	label.fill(-1)
	for start: int in data.voxels.size():
		if _interior[start] == 0 or label[start] != -1:
			continue
		var id: int = compartments.size()
		var comp: Compartment = Compartment.new()
		compartments.append(comp)
		var members: Array[int] = [start]
		label[start] = id
		var head: int = 0
		while head < members.size():
			var i: int = members[head]
			head += 1
			var pos: Vector3i = _voxel_position(i)
			var open: bool = false
			for dir: Vector3i in DIRS:
				var n: Vector3i = pos + dir
				if not data.has_point(n):
					open = true
					continue
				var j: int = data.index_of(n)
				if _interior[j] == 1:
					if label[j] == -1:
						label[j] = id
						members.append(j)
				elif data.voxels[j] == 0:
					open = true
			if open:
				comp.openings.append(i)
		var height: int = data.size.y
		members.sort_custom(func(a: int, b: int) -> bool: return a % height < b % height)
		comp.cells = PackedInt32Array(members)


func _compute_cells() -> void:
	cell_centers.clear()
	cell_heights.clear()
	cell_volumes.clear()
	cell_columns.clear()
	column_points.clear()
	_cell_of_voxel.resize(data.voxels.size())
	_cell_of_voxel.fill(-1)
	var columns: Dictionary = {}
	var cells: Vector3i = (data.size + Vector3i.ONE * (CELL - 1)) / CELL
	for cz: int in cells.z:
		for cx: int in cells.x:
			for cy: int in cells.y:
				var lower: int = 0
				var upper: int = 0
				var members: PackedInt32Array = PackedInt32Array()
				for dz: int in CELL:
					for dx: int in CELL:
						for dy: int in CELL:
							var p: Vector3i = Vector3i(cx, cy, cz) * CELL + Vector3i(dx, dy, dz)
							if not data.has_point(p):
								continue
							var i: int = data.index_of(p)
							members.append(i)
							if data.voxels[i] != 0 or (_interior[i] == 1 and flooded[i] == 0):
								if dy == 0:
									lower += 1
								else:
									upper += 1
				if lower + upper == 0:
					continue
				var cell: int = cell_volumes.size()
				for i: int in members:
					_cell_of_voxel[i] = cell
				# Si solo hay voxels en una capa, el volumen vive en esa mitad.
				var y0: int = cy * CELL + (1 if lower == 0 else 0)
				var y1: int = cy * CELL + (1 if upper == 0 else CELL)
				cell_centers.append(Vector3(cx * CELL + 1, (y0 + y1) * 0.5, cz * CELL + 1) * ShipData.VOXEL_SIZE)
				cell_heights.append((y1 - y0) * ShipData.VOXEL_SIZE)
				cell_volumes.append((lower + upper) * VOXEL_VOLUME)
				var column: Vector2i = Vector2i(cx, cz) * CELL / COLUMN
				if not columns.has(column):
					columns[column] = column_points.size()
					column_points.append(Vector3(column.x * COLUMN + COLUMN * 0.5, 0.0, column.y * COLUMN + COLUMN * 0.5) * ShipData.VOXEL_SIZE)
				cell_columns.append(columns[column])


func _write_dry_air() -> void:
	dry_air.voxels.fill(0)
	for c: int in compartments.size():
		for i: int in compartments[c].cells:
			if flooded[i] == 0:
				dry_air.voxels[i] = mini(c + 1, 255)
	var grid: Vector3i = dry_air.chunk_grid()
	for z: int in grid.z:
		for y: int in grid.y:
			for x: int in grid.x:
				dry_air.changed.emit(Vector3i(x, y, z))


func _is_underwater(voxel: int, xform: Transform3D, waves: WaveSettings, t: float) -> bool:
	var world: Vector3 = xform * ((Vector3(_voxel_position(voxel)) + Vector3.ONE * 0.5) * ShipData.VOXEL_SIZE)
	return waves.get_wave_height(world.x, world.z, t) > world.y


func _voxel_position(i: int) -> Vector3i:
	var s: Vector3i = data.size
	return Vector3i((i / s.y) % s.x, i % s.y, i / (s.y * s.x))
