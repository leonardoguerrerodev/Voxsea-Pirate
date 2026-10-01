class_name Compass
extends Node3D
## Brújula básica en la mano (Q la equipa o la guarda). Va como hija de la cámara,
## abajo a la derecha, así se camina y se mira adelante a la vez. N, E, S y O van
## fijos en la caja (N hacia adelante); solo la aguja gira para apuntar al norte
## del mapa (Y+ de MapCoords) y asienta con inercia.
## Se dibuja encima del mundo para no atravesar paredes.
# ponytail: mano y brújula con primitivas; modelos cuando haya arte. Cuando haya
# inventario (fase 9), equiparla dependerá de tenerla.

## Dónde queda en la vista (local a la cámara) y cuánto baja al guardarla.
const HELD: Vector3 = Vector3(0.22, -0.2, -0.45)
const HIDDEN_DROP: float = 0.35
## Qué tan rápido asienta la aguja (1/s) y cuánto tarda en subir o bajar (s).
const SETTLE: float = 6.0
const RAISE_TIME: float = 0.25

var equipped: bool = false

var _needle: Node3D
var _tween: Tween


func _ready() -> void:
	position = HELD + Vector3.DOWN * HIDDEN_DROP
	visible = false
	# Inclinada hacia la cámara para verle la cara.
	rotation.x = deg_to_rad(55.0)
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("compass"):
		set_equipped(not equipped)


func set_equipped(value: bool) -> void:
	equipped = value
	if _tween:
		_tween.kill()
	visible = true
	_tween = create_tween()
	_tween.tween_property(self, "position", HELD + (Vector3.ZERO if value else Vector3.DOWN * HIDDEN_DROP), RAISE_TIME)
	if not value:
		_tween.tween_callback(func() -> void: visible = false)


func _process(delta: float) -> void:
	if visible:
		_needle.rotation.y = lerp_angle(_needle.rotation.y, north_angle(), 1.0 - exp(-SETTLE * delta))


## Giro de la aguja (en el eje de la brújula) que hace que su -z mire al norte del mapa.
func north_angle() -> float:
	# Norte del mapa = Y+. Ojo: Vector2.UP de Godot es (0, -1), el "arriba" de pantalla.
	var north: Vector3 = global_basis.inverse() * MapCoords.to_world(Vector2(0.0, 1.0)).normalized()
	return atan2(-north.x, -north.z)


func _build() -> void:
	var hand: MeshInstance3D = _part(BoxMesh.new(), Color(0.85, 0.65, 0.5), 0)
	(hand.mesh as BoxMesh).size = Vector3(0.16, 0.04, 0.2)
	hand.position = Vector3(0.0, -0.035, 0.03)
	var case: MeshInstance3D = _part(CylinderMesh.new(), Color(0.55, 0.42, 0.18), 1)
	(case.mesh as CylinderMesh).top_radius = 0.075
	(case.mesh as CylinderMesh).bottom_radius = 0.075
	(case.mesh as CylinderMesh).height = 0.025
	var face: MeshInstance3D = _part(CylinderMesh.new(), Color(0.93, 0.9, 0.82), 2)
	(face.mesh as CylinderMesh).top_radius = 0.065
	(face.mesh as CylinderMesh).bottom_radius = 0.065
	(face.mesh as CylinderMesh).height = 0.002
	face.position.y = 0.013
	# Letras fijas en la caja: N hacia adelante (-z), E a la derecha, S, O.
	for i: int in 4:
		var letter: Label3D = Label3D.new()
		letter.text = MapCoords.POINTS[i * 2]
		letter.font_size = 32
		letter.pixel_size = 0.0006
		letter.modulate = Color(0.8, 0.1, 0.1) if i == 0 else Color(0.1, 0.1, 0.12)
		letter.outline_size = 0
		letter.no_depth_test = true
		letter.render_priority = 3
		var angle: float = -i * PI / 2.0
		letter.position = Vector3(-sin(angle), 0.0, -cos(angle)) * 0.048 + Vector3.UP * 0.016
		letter.rotation = Vector3(-PI / 2.0, angle, 0.0)
		add_child(letter)
	# La aguja va al final: mitad roja hacia el norte (-z), mitad oscura al sur.
	_needle = Node3D.new()
	_needle.position.y = 0.017
	add_child(_needle)
	for half: int in 2:
		var needle: MeshInstance3D = _part(BoxMesh.new(), Color(0.8, 0.1, 0.1) if half == 0 else Color(0.15, 0.15, 0.18), 4, _needle)
		(needle.mesh as BoxMesh).size = Vector3(0.008, 0.002, 0.05)
		needle.position.z = -0.025 if half == 0 else 0.025


func _part(mesh: Mesh, color: Color, priority: int, parent: Node3D = self) -> MeshInstance3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.no_depth_test = true
	material.render_priority = priority
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
