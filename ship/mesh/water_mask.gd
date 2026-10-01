class_name WaterMask
extends Node
## Presentación: el mar no se dibuja dentro de la bodega. Sube una vez el aire
## interior del casco (HullProfile) como textura 3D al shader del mar y le pasa la
## transformación del barco cada frame. Ejes de la textura (ancho, alto, capas) =
## (y, x, z), el orden ZXY del perfil: cada capa es un trozo contiguo del arreglo;
## el shader la lee con texelFetch(tex, voxel.yxz, 0).

@export var ship: ShipBody
@export var ocean: OceanSurface


func _ready() -> void:
	var size: Vector3i = ship.profile.size
	var layer_size: int = size.y * size.x
	var layers: Array[Image] = []
	for z: int in size.z:
		layers.append(Image.create_from_data(size.y, size.x, false, Image.FORMAT_R8, ship.profile.interior.slice(z * layer_size, (z + 1) * layer_size)))
	var texture: ImageTexture3D = ImageTexture3D.new()
	texture.create(Image.FORMAT_R8, size.y, size.x, size.z, false, layers)
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	material.set_shader_parameter("ship_dry_air", texture)
	material.set_shader_parameter("ship_size", size)


func _process(_delta: float) -> void:
	var material: ShaderMaterial = ocean.material_override as ShaderMaterial
	material.set_shader_parameter("ship_inverse", Projection(ship.global_transform.affine_inverse().scaled(Vector3.ONE / HullProfile.VOXEL_SIZE)))
