class_name ChunkMesher
extends RefCounted
## Malla de un chunk de ShipData con el VoxelMesherCubes de Voxel Tools (greedy).
## La usan la imagen (ShipMesh) y la colisión (ShipDeck); es el único punto que
## conoce Voxel Tools.
# ponytail: en el hilo principal. Medido en el MacPro: 0,15 ms un chunk realista y
# 6,6 ms el peor caso (ajedrez). Pasar a WorkerThreadPool si una edición grande
# (relleno de caja, cañonazo) se nota.

var mesher: VoxelMesherCubes

var _data: ShipData
var _full: VoxelBuffer
var _chunk: VoxelBuffer = _make_buffer(Vector3i.ONE * (ShipData.CHUNK + 2))


## Sin mesher, usa uno con la paleta por defecto (todo id > 0 es sólido).
func _init(p_mesher: VoxelMesherCubes = null) -> void:
	if p_mesher == null:
		p_mesher = VoxelMesherCubes.new()
		p_mesher.color_mode = VoxelMesherCubes.COLOR_MESHER_PALETTE
		p_mesher.palette = VoxelColorPalette.new()
	p_mesher.greedy_meshing_enabled = true
	mesher = p_mesher


## Copia la grilla actual. Llamar antes de una tanda de build().
func sync(data: ShipData) -> void:
	if data != _data:
		_data = data
		_full = _make_buffer(data.size)
	_full.set_channel_from_byte_array(VoxelBuffer.CHANNEL_COLOR, data.voxels)


## Malla del chunk en voxels relativos a su esquina, o null si está vacío.
func build(chunk: Vector3i) -> Mesh:
	# El mesher necesita el chunk más 1 voxel de borde; fuera de la grilla es aire.
	var origin: Vector3i = chunk * ShipData.CHUNK
	var padded_min: Vector3i = origin - Vector3i.ONE
	var src_min: Vector3i = padded_min.max(Vector3i.ZERO)
	var src_max: Vector3i = (origin + Vector3i.ONE * (ShipData.CHUNK + 1)).min(_data.size)
	_chunk.fill(0, VoxelBuffer.CHANNEL_COLOR)
	_chunk.copy_channel_from_area(_full, src_min, src_max, src_min - padded_min, VoxelBuffer.CHANNEL_COLOR)
	return mesher.build_mesh(_chunk, [], {})


static func _make_buffer(buffer_size: Vector3i) -> VoxelBuffer:
	var buffer: VoxelBuffer = VoxelBuffer.new()
	buffer.create(buffer_size.x, buffer_size.y, buffer_size.z)
	buffer.set_channel_depth(VoxelBuffer.CHANNEL_COLOR, VoxelBuffer.DEPTH_8_BIT)
	return buffer
