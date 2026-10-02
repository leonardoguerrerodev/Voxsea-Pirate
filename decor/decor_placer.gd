class_name DecorPlacer
extends Node
## Decorar el barco (presentación + comandos sobre el barco). Desde el inventario
## (clic derecho) se elige un objeto: aparece su fantasma donde apunta la mira,
## sobre un piso del barco. Rueda = girar, clic izquierdo = colocar, clic derecho o
## Esc = cancelar. Mirando un objeto colocado: E lo abre/cierra, F lo recoge.

const REACH: float = 6.0
## Pisos: la normal debe apuntar hacia arriba al menos esto (coseno).
const FLOOR: float = 0.7
const TURN_STEP: float = deg_to_rad(15.0)

@export var ship: ShipBody
@export var player: Player
@export var camera: Camera3D

var placing: ItemData
var _ghost: Node3D
var _yaw: float = 0.0
var _valid: bool = false


func begin(item: ItemData) -> void:
	cancel()
	if item.prop == null:
		return
	placing = item
	_ghost = item.prop.instantiate()
	_ghost.process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in _ghost.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).transparency = 0.45
	ship.add_child(_ghost)
	_ghost.visible = false


func cancel() -> void:
	placing = null
	if _ghost:
		_ghost.queue_free()
		_ghost = null


func _physics_process(_delta: float) -> void:
	if placing == null:
		return
	var hit: Dictionary = _aim()
	_valid = not hit.is_empty() and _on_ship(hit.collider) and (hit.normal as Vector3).y > FLOOR
	_ghost.visible = _valid
	if _valid:
		var local: Vector3 = ship.to_local(hit.position)
		_ghost.transform = Transform3D(Basis(Vector3.UP, _yaw), local)


func _unhandled_input(event: InputEvent) -> void:
	if placing:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button and button.pressed:
			match button.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					_yaw += TURN_STEP
				MOUSE_BUTTON_WHEEL_DOWN:
					_yaw -= TURN_STEP
				MOUSE_BUTTON_LEFT:
					if _valid:
						_place()
				MOUSE_BUTTON_RIGHT:
					cancel()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("pause"):
			cancel()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("pick_up"):
		var piece: DecorPiece = _aimed_piece()
		if piece == null:
			return
		if event.is_action_pressed("pick_up"):
			_pick_up(piece)
		elif not (piece.model.has_method("toggle") and piece.model.call("toggle")):
			return  # no se abre ni se prende (el timón): E queda para HelmControl
		get_viewport().set_input_as_handled()


func _place() -> void:
	if player.inventory.remove(placing, 1) == 0:
		cancel()
		return
	var piece: DecorPiece = DecorPiece.create(placing)
	piece.transform = _ghost.transform
	ship.add_child(piece)
	ship.refresh_mass()
	if player.inventory.count_of(placing) == 0:
		cancel()


func _pick_up(piece: DecorPiece) -> void:
	if player.inventory.add(piece.item, 1) > 0:
		return  # no cabe
	piece.queue_free()
	ship.remove_child(piece)
	ship.refresh_mass()


func _aimed_piece() -> DecorPiece:
	var hit: Dictionary = _aim()
	if hit.is_empty():
		return null
	return (hit.collider as Node).get_parent() as DecorPiece


func _aim() -> Dictionary:
	var from: Vector3 = camera.global_position
	# En tercera persona la cámara va detrás: el alcance se cuenta desde la cabeza.
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * (REACH + player.camera_reach))
	query.exclude = [player.get_rid()]
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


func _on_ship(collider: Object) -> bool:
	var node: Node = collider as Node
	return node != null and ship.is_ancestor_of(node)
