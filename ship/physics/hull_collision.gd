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
## Malla reducida solo para chocar (tools/hull_to_grid.py la deja en
## <casco>_colision.glb, en los mismos ejes). Si falta, se usa `model`.
@export var source: PackedScene


func _ready() -> void:
	# Se mueve en el mismo instante que su padre, no en el paso físico siguiente.
	sync_to_physics = false
	var faces: PackedVector3Array = PackedVector3Array()
	# Transformaciones relativas a la raíz (la de colisión no entra al árbol).
	var root: Node3D = source.instantiate() if source else model
	var stack: Array[Array] = [[root, model.transform]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var xform: Transform3D = entry[1]
		for child: Node in node.get_children():
			stack.append([child, xform * (child as Node3D).transform if child is Node3D else xform])
		var instance: MeshInstance3D = node as MeshInstance3D
		if instance == null or instance.mesh == null:
			continue
		for vertex: Vector3 in instance.mesh.get_faces():
			faces.append(xform * vertex)
	if source:
		root.free()
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	concave.set_faces(faces)
	# Las normales del modelo miran hacia afuera: sin esto, desde la bodega se
	# atraviesan el casco y la cubierta.
	concave.backface_collision = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = concave
	add_child(shape)
