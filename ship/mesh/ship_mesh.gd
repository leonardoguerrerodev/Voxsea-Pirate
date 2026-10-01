class_name ShipMesh
extends Node3D
## Presentación del barco: una malla por chunk, con el VoxelMesherCubes de Voxel
## Tools (greedy meshing). Escucha ShipData.changed y remalla lo pendiente una vez
## por frame.
# ponytail: remalla en el hilo principal. Medido en el MacPro: 0,15 ms un chunk
# realista y 6,6 ms el peor caso (ajedrez). Pasar a WorkerThreadPool si una
# edición grande (relleno de caja, cañonazo) se nota.

## Colores de la paleta. Sin catálogo, cada id recibe un color distinto
## (sirve para ver compartimentos).
@export var catalog: MaterialCatalog
## Si se asigna, toma sus datos al entrar: el casco o, con show_dry_air, el aire
## interior seco de cada compartimento.
@export var ship: ShipBody
@export var show_dry_air: bool = false
## Material de las superficies. Vacío = color por vértice opaco.
@export var surface_material: Material

var data: ShipData

var _mesher: VoxelMesherCubes
var _full: VoxelBuffer
var _chunk_buffer: VoxelBuffer
var _instances: Dictionary = {}
var _dirty: Dictionary = {}


func _ready() -> void:
	if ship:
		set_data(ship.hydro.dry_air if show_dry_air else ship.data)


func set_data(p_data: ShipData) -> void:
	if data:
		data.changed.disconnect(_on_changed)
	data = p_data
	data.changed.connect(_on_changed)
	if _mesher == null:
		_setup_mesher()
	_full = _make_buffer(data.size)
	_chunk_buffer = _make_buffer(Vector3i.ONE * (ShipData.CHUNK + 2))
	for child: Node in _instances.values():
		child.queue_free()
	_instances.clear()
	var grid: Vector3i = data.chunk_grid()
	for z: int in grid.z:
		for y: int in grid.y:
			for x: int in grid.x:
				_dirty[Vector3i(x, y, z)] = true
	flush()


func _process(_delta: float) -> void:
	if not _dirty.is_empty():
		flush()


## Remalla los chunks pendientes y devuelve cuántos fueron.
func flush() -> int:
	_full.set_channel_from_byte_array(VoxelBuffer.CHANNEL_COLOR, data.voxels)
	var count: int = _dirty.size()
	for chunk: Vector3i in _dirty:
		_rebuild(chunk)
	_dirty.clear()
	return count


func _on_changed(chunk: Vector3i) -> void:
	_dirty[chunk] = true


func _rebuild(chunk: Vector3i) -> void:
	# El mesher necesita el chunk más 1 voxel de borde; fuera de la grilla es aire.
	var origin: Vector3i = chunk * ShipData.CHUNK
	var padded_min: Vector3i = origin - Vector3i.ONE
	var src_min: Vector3i = padded_min.max(Vector3i.ZERO)
	var src_max: Vector3i = (origin + Vector3i.ONE * (ShipData.CHUNK + 1)).min(data.size)
	_chunk_buffer.fill(0, VoxelBuffer.CHANNEL_COLOR)
	_chunk_buffer.copy_channel_from_area(_full, src_min, src_max, src_min - padded_min, VoxelBuffer.CHANNEL_COLOR)
	var instance: MeshInstance3D = _instances.get(chunk)
	if instance == null:
		instance = MeshInstance3D.new()
		instance.position = Vector3(origin) * ShipData.VOXEL_SIZE
		instance.scale = Vector3.ONE * ShipData.VOXEL_SIZE
		add_child(instance)
		_instances[chunk] = instance
	# Un chunk vacío devuelve null: la instancia queda sin malla.
	instance.mesh = _mesher.build_mesh(_chunk_buffer, [], {})


func _setup_mesher() -> void:
	_mesher = VoxelMesherCubes.new()
	_mesher.greedy_meshing_enabled = true
	_mesher.color_mode = VoxelMesherCubes.COLOR_MESHER_PALETTE
	var palette: VoxelColorPalette = VoxelColorPalette.new()
	for id: int in range(1, 256):
		var material: VoxelMaterial = catalog.get_material(id) if catalog else null
		if material:
			palette.set_color(id, material.color)
		elif catalog == null:
			palette.set_color(id, Color.from_hsv(fmod(id * 0.618, 1.0), 0.7, 0.9))
	_mesher.palette = palette
	if surface_material == null:
		var surface: StandardMaterial3D = StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		# La paleta está en sRGB, como los colores del inspector.
		surface.vertex_color_is_srgb = true
		surface_material = surface
	_mesher.set_material_by_index(VoxelMesherCubes.MATERIAL_OPAQUE, surface_material)


func _make_buffer(buffer_size: Vector3i) -> VoxelBuffer:
	var buffer: VoxelBuffer = VoxelBuffer.new()
	buffer.create(buffer_size.x, buffer_size.y, buffer_size.z)
	buffer.set_channel_depth(VoxelBuffer.CHANNEL_COLOR, VoxelBuffer.DEPTH_8_BIT)
	return buffer
