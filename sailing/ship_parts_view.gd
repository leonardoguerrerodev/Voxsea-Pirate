extends Node3D
## Presentación de las piezas funcionales: sobre la base (el voxel) dibuja mástil
## y vela (que sigue el ángulo y el despliegue del ShipRig), rueda de timón o
## ancla. Escanea la grilla cuando cambia.
# ponytail: formas primitivas; modelos de verdad cuando haya arte.

@export var ship: ShipBody
@export var rig: ShipRig

var _sails: Dictionary = {}
var _dirty: bool = true
var _canvas: StandardMaterial3D = _material(Color(0.92, 0.88, 0.78), true)
var _wood: StandardMaterial3D = _material(Color(0.42, 0.28, 0.14), false)
var _iron: StandardMaterial3D = _material(Color(0.25, 0.25, 0.28), false)


func _ready() -> void:
	ship.data.changed.connect(func(_chunk: Vector3i) -> void: _dirty = true)


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()
	for cell: Vector3i in _sails:
		var pivot: Node3D = _sails[cell]
		pivot.rotation.y = rig.sail_trims.get(cell, 0.0)
		pivot.scale.y = maxf(rig.sail_amount, 0.05)


func _rebuild() -> void:
	for child: Node in get_children():
		child.queue_free()
	_sails.clear()
	var data: ShipData = ship.data
	for i: int in data.voxels.size():
		var id: int = data.voxels[i]
		if id == 0:
			continue
		var material: VoxelMaterial = ship.catalog.get_material(id)
		if material == null or material.part == VoxelMaterial.Part.NONE:
			continue
		var cell: Vector3i = Vector3i((i / data.size.y) % data.size.x, i % data.size.y, i / (data.size.y * data.size.x))
		var top: Vector3 = (Vector3(cell) + Vector3(0.5, 1.0, 0.5)) * ShipData.VOXEL_SIZE
		match material.part:
			VoxelMaterial.Part.SAIL:
				_add_sail(cell, top, material)
			VoxelMaterial.Part.HELM:
				var wheel: MeshInstance3D = _mesh(TorusMesh.new(), _wood, top + Vector3.UP * 0.6)
				(wheel.mesh as TorusMesh).inner_radius = 0.35
				(wheel.mesh as TorusMesh).outer_radius = 0.45
				wheel.rotation.x = PI / 2.0
			VoxelMaterial.Part.ANCHOR:
				var anchor: MeshInstance3D = _mesh(CylinderMesh.new(), _iron, top + Vector3.UP * 0.3)
				(anchor.mesh as CylinderMesh).height = 0.6
				(anchor.mesh as CylinderMesh).top_radius = 0.2
				(anchor.mesh as CylinderMesh).bottom_radius = 0.35


func _add_sail(cell: Vector3i, top: Vector3, material: VoxelMaterial) -> void:
	var mast: MeshInstance3D = _mesh(CylinderMesh.new(), _wood, top + Vector3.UP * material.mast_height * 0.5)
	(mast.mesh as CylinderMesh).height = material.mast_height
	(mast.mesh as CylinderMesh).top_radius = 0.1
	(mast.mesh as CylinderMesh).bottom_radius = 0.18
	# La vela cuelga de lo alto del mástil y crece hacia abajo al desplegarse.
	var pivot: Node3D = Node3D.new()
	pivot.position = top + Vector3.UP * material.mast_height * 0.95
	add_child(pivot)
	var height: float = material.mast_height * 0.8
	var width: float = material.sail_area / height
	var cloth: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, height, width)
	cloth.mesh = box
	cloth.material_override = _canvas
	# La cuerda (ancho) va a lo largo del barco; el borde de ataque, en el mástil.
	cloth.position = Vector3(0.0, -height * 0.5, width * 0.5)
	pivot.add_child(cloth)
	_sails[cell] = pivot


func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


static func _material(color: Color, two_sided: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
