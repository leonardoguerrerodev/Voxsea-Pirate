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
	# ponytail: resube toda la grilla en cada cambio (un barco máximo son 128
	# capas de 64×32). Subir solo las capas tocadas si pesa al inundarse.
	var air: ShipData = ship.hydro.dry_air
	var s: Vector3i = air.size
	var layers: Array[Image] = []
	var layer: PackedByteArray = PackedByteArray()
	layer.resize(s.x * s.y)
	for z: int in s.z:
		for x: int in s.x:
			var base: int = x * s.y + z * s.y * s.x
			for y: int in s.y:
				layer[y * s.x + x] = 255 if air.voxels[base + y] != 0 else 0
		layers.append(Image.create_from_data(s.x, s.y, false, Image.FORMAT_R8, layer))
	if _texture == null:
		_texture = ImageTexture3D.new()
		_texture.create(Image.FORMAT_R8, s.x, s.y, s.z, false, layers)
		material.set_shader_parameter("ship_dry_air", _texture)
		material.set_shader_parameter("ship_size", s)
	else:
		_texture.update(layers)
