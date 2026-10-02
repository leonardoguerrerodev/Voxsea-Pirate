extends Node3D
## Presentación de las piezas (ShipPart): sobre su base dibuja mástil y vela (que
## sigue el ángulo y el despliegue del ShipRig) o ancla (el timón es un objeto con su modelo).
## La vela es cuadra, colgada de la verga del modelo: el mástil queda fijo y la
## verga y la tela giran con el ángulo del ShipRig (la física la trata como placa
## plana). La tela va delante del mástil (hacia proa) y se infla con el empuje.

## Mástil con cofa y su verga, separados de un mismo modelo de 12 m en los mismos
## ejes (tools/props_import.py, assets/props/palos.json: "box"); verga a lo ancho (x).
const MAST: PackedScene = preload("res://assets/props/palo_cofa.glb")
const ANCHOR: PackedScene = preload("res://assets/props/ancla.glb")
const YARD: PackedScene = preload("res://assets/props/palo_verga.glb")
const MAST_MODEL_HEIGHT: float = 12.0
## Alto y largo de la verga en fracción del alto del mástil (medido en el modelo).
const YARD_HEIGHT: float = 9.83 / 12.0
const YARD_SPAN: float = 6.96 / 12.0
## Separación de la tela al eje del mástil, en el modelo de 12 m (radio ~0,36 + holgura).
const CLOTH_OFFSET: float = 0.5
## Hueco entre el pie de la vela y la cubierta (m).
const SAIL_CLEARANCE: float = 1.2

@export var ship: ShipBody
@export var rig: ShipRig

var _sails: Dictionary = {}
## Cuánto se infla la vela con todo el paño (m).
const BILLOW: float = 0.8

var _canvas: ShaderMaterial = _sail_material()


func _ready() -> void:
	for part: ShipPart in ship.parts():
		var top: Vector3 = part.position
		match part.kind:
			ShipPart.Kind.SAIL:
				_add_sail(part, top)
			ShipPart.Kind.ANCHOR:
				var anchor: Node3D = ANCHOR.instantiate()
				anchor.position = top
				add_child(anchor)


func _process(_delta: float) -> void:
	for part: ShipPart in _sails:
		var pivot: Node3D = _sails[part]
		var trim: float = rig.sail_trims.get(part, 0.0)
		(pivot.get_parent() as Node3D).rotation.y = trim
		pivot.scale.y = maxf(rig.sail_amount, 0.05)
		# Hacia proa en ejes de la verga: +x apunta a proa si sin(ángulo) > 0.
		var bow: float = 1.0 if sin(trim) >= 0.0 else -1.0
		var cloth: GeometryInstance3D = pivot.get_child(0) as GeometryInstance3D
		cloth.position.x = bow * CLOTH_OFFSET * part.mast_height / MAST_MODEL_HEIGHT
		# El viento la empuja hacia proa, tanto como empuja al barco.
		var drive: float = rig.sail_drives.get(part, 0.0)
		cloth.set_instance_shader_parameter("billow", bow * BILLOW * drive * rig.sail_amount)
		cloth.set_instance_shader_parameter("wind", clampf(Wind.velocity_at(Game.ocean_time).length() / 12.0, 0.0, 1.5) * rig.sail_amount)


func _add_sail(part: ShipPart, top: Vector3) -> void:
	var model_scale: Vector3 = Vector3.ONE * part.mast_height / MAST_MODEL_HEIGHT
	var mast: Node3D = MAST.instantiate()
	mast.position = top
	mast.rotation.y = PI / 2.0
	mast.scale = model_scale
	add_child(mast)
	# Verga y tela giran con el ángulo de la vela; con ángulo 0 van a lo largo (-z).
	var turn: Node3D = Node3D.new()
	turn.position = top
	add_child(turn)
	var yard: Node3D = YARD.instantiate()
	yard.rotation.y = PI / 2.0
	yard.scale = model_scale
	turn.add_child(yard)
	# La vela cuelga de la verga y crece hacia abajo al desplegarse.
	var pivot: Node3D = Node3D.new()
	pivot.position = Vector3.UP * part.mast_height * YARD_HEIGHT
	turn.add_child(pivot)
	var height: float = part.mast_height * YARD_HEIGHT - SAIL_CLEARANCE
	var width: float = part.mast_height * YARD_SPAN * 0.95
	var cloth: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_X
	plane.size = Vector2(width, height)
	plane.subdivide_width = 12
	plane.subdivide_depth = 12
	cloth.mesh = plane
	cloth.material_override = _canvas
	# A lo largo de la verga; _process la corre hacia proa del mástil.
	cloth.position = Vector3(0.0, -height * 0.5, 0.0)
	pivot.add_child(cloth)
	_sails[part] = pivot



static func _sail_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load("res://sailing/sail.gdshader")
	material.set_shader_parameter("canvas", load("res://assets/textures/canvas.jpg"))
	return material

