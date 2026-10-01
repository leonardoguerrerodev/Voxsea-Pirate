class_name VoxelTexture
extends RefCounted
## ShipData como textura 3D sin reordenar: los ejes (ancho, alto, capas) son
## (y, x, z), el mismo orden ZXY de ShipData, así cada capa es un trozo contiguo
## del arreglo. En el shader se lee con texelFetch(tex, voxel.yxz, 0); un valor
## > 0 es "hay algo" (material o compartimento).


static func layers(data: ShipData) -> Array[Image]:
	var s: Vector3i = data.size
	var layer_size: int = s.y * s.x
	var result: Array[Image] = []
	for z: int in s.z:
		result.append(Image.create_from_data(s.y, s.x, false, Image.FORMAT_R8, data.voxels.slice(z * layer_size, (z + 1) * layer_size)))
	return result


## Crea la textura o, si ya existe, la actualiza (mismo tamaño).
static func upload(texture: ImageTexture3D, data: ShipData) -> ImageTexture3D:
	if texture == null:
		texture = ImageTexture3D.new()
		texture.create(Image.FORMAT_R8, data.size.y, data.size.x, data.size.z, false, layers(data))
	else:
		texture.update(layers(data))
	return texture
