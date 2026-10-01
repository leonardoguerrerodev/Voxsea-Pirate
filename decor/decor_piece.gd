class_name DecorPiece
extends ShipPart
## Objeto del inventario colocado en el barco: una pieza con masa (mueve el centro
## de gravedad), el modelo del objeto y una caja de colisión cinemática hija del
## barco (como HullCollision: se mueve con él y se puede pisar y apuntar).

var item: ItemData
var model: Node3D


static func create(p_item: ItemData) -> DecorPiece:
	var piece: DecorPiece = DecorPiece.new()
	piece.item = p_item
	piece.mass = p_item.mass
	piece.name = String(p_item.id)
	piece.model = p_item.prop.instantiate()
	piece.add_child(piece.model)
	return piece


# La colisión se arma al entrar al árbol: los props armados (OpenableProp) crean
# sus piezas recién en su _ready, que corre antes que este.
func _ready() -> void:
	var body: AnimatableBody3D = AnimatableBody3D.new()
	body.sync_to_physics = false
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	var bounds: AABB = model_bounds(model)
	box.size = bounds.size.max(Vector3.ONE * 0.05)
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	add_child(body)


## Caja del modelo en sus propias coordenadas.
static func model_bounds(root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array[Array] = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xform: Transform3D = entry[1]
		if node is Node3D and node != root:
			xform = xform * (node as Node3D).transform
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance and instance.mesh:
			var piece: AABB = xform * instance.mesh.get_aabb()
			box = piece if first else box.merge(piece)
			first = false
		for child: Node in node.get_children():
			stack.append([child, xform])
	return box
