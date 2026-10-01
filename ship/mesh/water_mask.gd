class_name WaterMask
extends Node
## Presentación: el mar no se dibuja dentro del aire seco del barco. Sube el aire
## seco como textura 3D al shader del mar y le pasa la transformación del barco.

@export var ship: ShipBody
@export var ocean: OceanSurface

var _texture: ImageTexture3D
var _dirty: bool = true


func _ready() -> void:
	ship.hydro.dry_air.changed.connect(func(_chunk: Vector3i) -> void: _dirty = true)


func _process(_delta: float) -> void:
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	if _dirty:
		_dirty = false
		_upload(material)
	material.set_shader_parameter("ship_inverse", Projection(ship.global_transform.affine_inverse().scaled(Vector3.ONE / ShipData.VOXEL_SIZE)))


func _upload(material: ShaderMaterial) -> void:
	var fresh: bool = _texture == null
	_texture = VoxelTexture.upload(_texture, ship.hydro.dry_air)
	if fresh:
		material.set_shader_parameter("ship_dry_air", _texture)
		material.set_shader_parameter("ship_size", ship.hydro.dry_air.size)
