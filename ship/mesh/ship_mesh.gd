class_name ShipMesh
extends Node3D
## Presentación del barco: una malla por chunk (ChunkMesher). Escucha
## ShipData.changed y remalla lo pendiente una vez por frame.

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

var _mesher: ChunkMesher
var _solids: ImageTexture3D
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
	_mesher.sync(data)
	var count: int = _dirty.size()
	for chunk: Vector3i in _dirty:
		_rebuild(chunk)
	_dirty.clear()
	# El shader del casco (hull.gdshader) mira los vecinos para biselar aristas.
	var shader: ShaderMaterial = surface_material as ShaderMaterial
	if shader:
		var fresh: bool = _solids == null
		_solids = VoxelTexture.upload(_solids, data)
		if fresh:
			shader.set_shader_parameter("solids", _solids)
			shader.set_shader_parameter("grid_size", data.size)
	return count


func _on_changed(chunk: Vector3i) -> void:
	_dirty[chunk] = true


func _rebuild(chunk: Vector3i) -> void:
	var origin: Vector3i = chunk * ShipData.CHUNK
	var instance: MeshInstance3D = _instances.get(chunk)
	if instance == null:
		instance = MeshInstance3D.new()
		instance.position = Vector3(origin) * ShipData.VOXEL_SIZE
		instance.scale = Vector3.ONE * ShipData.VOXEL_SIZE
		add_child(instance)
		_instances[chunk] = instance
		if surface_material is ShaderMaterial:
			instance.set_instance_shader_parameter("chunk_origin", Vector3(origin))
	# Un chunk vacío devuelve null: la instancia queda sin malla.
	instance.mesh = _mesher.build(chunk)


func _setup_mesher() -> void:
	var mesher: VoxelMesherCubes = VoxelMesherCubes.new()
	mesher.color_mode = VoxelMesherCubes.COLOR_MESHER_PALETTE
	var palette: VoxelColorPalette = VoxelColorPalette.new()
	for id: int in range(1, 256):
		var material: VoxelMaterial = catalog.get_material(id) if catalog else null
		if material:
			palette.set_color(id, material.color)
		elif catalog == null:
			palette.set_color(id, Color.from_hsv(fmod(id * 0.618, 1.0), 0.7, 0.9))
	mesher.palette = palette
	if surface_material == null:
		var surface: StandardMaterial3D = StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		# La paleta está en sRGB, como los colores del inspector.
		surface.vertex_color_is_srgb = true
		surface_material = surface
	mesher.set_material_by_index(VoxelMesherCubes.MATERIAL_OPAQUE, surface_material)
	_mesher = ChunkMesher.new(mesher)
