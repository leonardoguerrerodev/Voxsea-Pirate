class_name HullCollision
extends AnimatableBody3D
## Colisión del casco: una forma cóncava con los triángulos del modelo que se ve.
## Va como hijo del ShipBody y se mueve con él. Al ser cinemática, Jolt acepta
## formas cóncavas (en cuerpos dinámicos no). No aporta masa: esa sale del
## HullProfile. Quien camine encima va como hijo del barco (lo lleva la
## transformación, no una velocidad de plataforma: así no se hunde en la malla).
# Idea: gameidea.org, "Making Boat Physics in Godot" (cuerpo detallado hijo del rígido).

## Raíz del modelo: se juntan las mallas de todos sus MeshInstance3D.
@export var model: Node3D


func _ready() -> void:
	# Se mueve en el mismo instante que su padre, no en el paso físico siguiente.
	sync_to_physics = false
	var to_ship: Transform3D = (get_parent() as Node3D).global_transform.affine_inverse()
	var faces: PackedVector3Array = PackedVector3Array()
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		var xform: Transform3D = to_ship * instance.global_transform
		for vertex: Vector3 in instance.mesh.get_faces():
			faces.append(xform * vertex)
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = concave
	add_child(shape)
