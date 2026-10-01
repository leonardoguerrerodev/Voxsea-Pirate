class_name ShipDeck
extends AnimatableBody3D
## Colisión detallada del barco: una forma cóncava por chunk, armada con la misma
## malla que se ve. Va como hijo del ShipBody y se mueve con él. Al ser cinemática,
## Jolt acepta formas cóncavas (en cuerpos dinámicos no). No aporta masa: esa sale
## de los voxels. Quien camine encima va como hijo del barco (lo lleva la
## transformación, no una velocidad de plataforma: así no se hunde en la malla).
# Idea: gameidea.org, "Making Boat Physics in Godot" (cuerpo detallado hijo del rígido).

var _ship: ShipBody
var _mesher: ChunkMesher = ChunkMesher.new()
var _shapes: Dictionary = {}
var _dirty: Dictionary = {}


func _ready() -> void:
	# Se mueve en el mismo instante que su padre, no en el paso físico siguiente.
	sync_to_physics = false
	_ship = get_parent() as ShipBody
	_ship.data.changed.connect(func(chunk: Vector3i) -> void: _dirty[chunk] = true)
	var grid: Vector3i = _ship.data.chunk_grid()
	for z: int in grid.z:
		for y: int in grid.y:
			for x: int in grid.x:
				_dirty[Vector3i(x, y, z)] = true
	flush()


func _physics_process(_delta: float) -> void:
	if not _dirty.is_empty():
		flush()


## Rehace la colisión de los chunks pendientes y devuelve cuántos fueron.
func flush() -> int:
	_mesher.sync(_ship.data)
	var count: int = _dirty.size()
	for chunk: Vector3i in _dirty:
		var shape: CollisionShape3D = _shapes.get(chunk)
		if shape == null:
			shape = CollisionShape3D.new()
			add_child(shape)
			_shapes[chunk] = shape
		var mesh: Mesh = _mesher.build(chunk)
		if mesh == null:
			shape.shape = null
			continue
		# De voxels del chunk a metros del barco.
		var offset: Vector3 = Vector3(chunk * ShipData.CHUNK)
		var faces: PackedVector3Array = mesh.get_faces()
		for i: int in faces.size():
			faces[i] = (faces[i] + offset) * ShipData.VOXEL_SIZE
		var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
		concave.set_faces(faces)
		shape.shape = concave
	_dirty.clear()
	return count
