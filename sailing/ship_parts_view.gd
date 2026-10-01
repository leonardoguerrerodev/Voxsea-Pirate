extends Node3D
## Presentación de las piezas (ShipPart): sobre su base dibuja mástil y vela (que
## sigue el ángulo y el despliegue del ShipRig), rueda de timón o ancla.
# ponytail: formas primitivas; modelos de verdad cuando haya arte.

@export var ship: ShipBody
@export var rig: ShipRig

var _sails: Dictionary = {}
## Cuánto se infla la vela con todo el paño (m).
const BILLOW: float = 0.8

var _canvas: ShaderMaterial = _sail_material()
var _wood: StandardMaterial3D = _material(Color(0.42, 0.28, 0.14), false)
var _iron: StandardMaterial3D = _material(Color(0.25, 0.25, 0.28), false)


func _ready() -> void:
	for part: ShipPart in ship.parts():
		var top: Vector3 = part.position
		match part.kind:
			ShipPart.Kind.SAIL:
				_add_sail(part, top)
			ShipPart.Kind.HELM:
				var wheel: MeshInstance3D = _mesh(TorusMesh.new(), _wood, top + Vector3.UP * 0.6)
				(wheel.mesh as TorusMesh).inner_radius = 0.35
				(wheel.mesh as TorusMesh).outer_radius = 0.45
				wheel.rotation.x = PI / 2.0
			ShipPart.Kind.ANCHOR:
				var anchor: MeshInstance3D = _mesh(CylinderMesh.new(), _iron, top + Vector3.UP * 0.3)
				(anchor.mesh as CylinderMesh).height = 0.6
				(anchor.mesh as CylinderMesh).top_radius = 0.2
				(anchor.mesh as CylinderMesh).bottom_radius = 0.35


func _process(_delta: float) -> void:
	for part: ShipPart in _sails:
		var pivot: Node3D = _sails[part]
		var trim: float = rig.sail_trims.get(part, 0.0)
		pivot.rotation.y = trim
		pivot.scale.y = maxf(rig.sail_amount, 0.05)
		# Se infla hacia el lado contrario al que se abrió (sotavento).
		(pivot.get_child(0) as GeometryInstance3D).set_instance_shader_parameter("billow", -signf(trim) * BILLOW * rig.sail_amount)


func _add_sail(part: ShipPart, top: Vector3) -> void:
	var mast: MeshInstance3D = _mesh(CylinderMesh.new(), _wood, top + Vector3.UP * part.mast_height * 0.5)
	(mast.mesh as CylinderMesh).height = part.mast_height
	(mast.mesh as CylinderMesh).top_radius = 0.1
	(mast.mesh as CylinderMesh).bottom_radius = 0.18
	# La vela cuelga de lo alto del mástil y crece hacia abajo al desplegarse.
	var pivot: Node3D = Node3D.new()
	pivot.position = top + Vector3.UP * part.mast_height * 0.95
	add_child(pivot)
	var height: float = part.mast_height * 0.8
	var width: float = part.sail_area / height
	var cloth: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_X
	plane.size = Vector2(width, height)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	cloth.mesh = plane
	cloth.material_override = _canvas
	# La cuerda (ancho) va a lo largo del barco; el borde de ataque, en el mástil.
	cloth.position = Vector3(0.0, -height * 0.5, width * 0.5)
	pivot.add_child(cloth)
	_sails[part] = pivot


func _mesh(mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	add_child(instance)
	return instance


static func _sail_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://sailing/sail.gdshader")
	material.set_shader_parameter("canvas", load("res://assets/textures/canvas.jpg"))
	return material


static func _material(color: Color, two_sided: bool) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	if two_sided:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
