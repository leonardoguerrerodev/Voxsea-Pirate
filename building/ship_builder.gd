class_name ShipBuilder
extends Node
## Modo construcción en primera persona. B pone el barco en dique seco (congelado
## y derecho) y lo suelta al salir. Se apunta con la mira: clic izquierdo pone,
## derecho quita. Herramientas voxel / línea / caja (arrastrando), espejo
## babor-estribor, materiales 1-6, deshacer y rehacer. Todo pasa por comandos
## (regla 2).
# ponytail: la grilla del barco tiene tamaño fijo; construir fuera de ella no hace
# nada. Agrandar ShipData cuando haga falta.

enum Tool { VOXEL, LINE, BOX }

const REACH: float = 10.0
const TOOL_NAMES: PackedStringArray = ["Voxel", "Línea", "Caja"]

@export var ship: ShipBody
@export var camera: Camera3D
## Se excluye del rayo de la mira.
@export var player: CollisionObject3D

var building: bool = false
var tool: Tool = Tool.VOXEL
var mirror: bool = true
var material_id: int = 2
var history: BuildHistory = BuildHistory.new()

var _anchor: Vector3i
var _dragging: bool = false
var _removing: bool = false
var _place_cell: Vector3i
var _remove_cell: Vector3i
var _has_target: bool = false
var _ghost: MeshInstance3D
var _mirror_ghost: MeshInstance3D
var _hud: Label


func _ready() -> void:
	_ghost = _make_ghost()
	_mirror_ghost = _make_ghost()
	var layer: CanvasLayer = CanvasLayer.new()
	_hud = Label.new()
	_hud.position = Vector2(16, 16)
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	add_child(layer)
	_update_hud()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		_set_building(not building)
	if not building:
		return
	if event.is_action_pressed("build_tool"):
		tool = ((tool + 1) % Tool.size()) as Tool
	elif event.is_action_pressed("build_mirror"):
		mirror = not mirror
	elif event.is_action_pressed("build_undo"):
		history.undo(ship.data)
	elif event.is_action_pressed("build_redo"):
		history.redo(ship.data)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo():
		var digit: int = (event as InputEventKey).physical_keycode - KEY_0
		if digit >= 1 and digit < ship.catalog.materials.size():
			material_id = digit
	elif _has_target and (event.is_action_pressed("build_place") or event.is_action_pressed("build_remove")):
		_removing = event.is_action_pressed("build_remove")
		_anchor = _remove_cell if _removing else _place_cell
		_dragging = tool != Tool.VOXEL
		if not _dragging:
			_commit(_anchor)
	elif _dragging and (event.is_action_released("build_place") or event.is_action_released("build_remove")):
		_dragging = false
		_commit(_remove_cell if _removing else _place_cell)
	_update_hud()


func _process(_delta: float) -> void:
	_has_target = building and _aim()
	_ghost.visible = _has_target
	_mirror_ghost.visible = _has_target and mirror
	if not _has_target:
		return
	var target: Vector3i = _remove_cell if (_dragging and _removing) or (not _dragging and Input.is_action_pressed("build_remove")) else _place_cell
	var from: Vector3i = _anchor if _dragging else target
	var to: Vector3i = constrain(from, target, tool)
	_show_ghost(_ghost, from, to, _dragging and _removing)
	_show_ghost(_mirror_ghost, mirror_cell(from, ship.data.size), mirror_cell(to, ship.data.size), _dragging and _removing)


## Comando que llena (o vacía, con value 0) la región de a hasta b.
static func region_command(a: Vector3i, b: Vector3i, value: int, with_mirror: bool, size: Vector3i) -> ShipEditCommand:
	var command: ShipEditCommand = ShipEditCommand.new()
	var low: Vector3i = a.min(b)
	var high: Vector3i = a.max(b)
	for z: int in range(low.z, high.z + 1):
		for y: int in range(low.y, high.y + 1):
			for x: int in range(low.x, high.x + 1):
				var cell: Vector3i = Vector3i(x, y, z)
				command.add(cell, value)
				if with_mirror:
					command.add(mirror_cell(cell, size), value)
	return command


## Con la línea, el destino se queda solo con el eje de mayor avance.
static func constrain(from: Vector3i, to: Vector3i, p_tool: Tool) -> Vector3i:
	if p_tool != Tool.LINE:
		return to
	var delta: Vector3i = to - from
	var axis: int = delta.abs().max_axis_index()
	var result: Vector3i = from
	result[axis] = to[axis]
	return result


## Voxel espejado respecto del eje largo del barco (babor ↔ estribor).
static func mirror_cell(cell: Vector3i, size: Vector3i) -> Vector3i:
	return Vector3i(size.x - 1 - cell.x, cell.y, cell.z)


func _commit(target: Vector3i) -> void:
	var to: Vector3i = constrain(_anchor, target, tool)
	history.apply(ship.data, region_command(_anchor, to, 0 if _removing else material_id, mirror, ship.data.size))


func _set_building(value: bool) -> void:
	building = value
	_dragging = false
	if building:
		# Dique seco: derecho y quieto. La hidrostática se recalcula al soltarlo.
		ship.freeze = true
		ship.global_basis = Basis(Vector3.UP, ship.global_rotation.y)
		ship.linear_velocity = Vector3.ZERO
		ship.angular_velocity = Vector3.ZERO
	else:
		ship.freeze = false
	_update_hud()


## Rayo desde el centro de la cámara contra la cubierta. Calcula el voxel apuntado
## (para quitar) y el vecino por la cara apuntada (para poner).
func _aim() -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position, camera.global_position - camera.global_basis.z * REACH)
	if player:
		query.exclude = [player.get_rid()]
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or (hit.collider as Node).get_parent() != ship:
		return false
	var local: Vector3 = ship.global_transform.affine_inverse() * (hit.position as Vector3)
	var normal: Vector3 = (ship.global_basis.inverse() * (hit.normal as Vector3)).normalized()
	var quarter: float = ShipData.VOXEL_SIZE * 0.5
	_remove_cell = Vector3i(((local - normal * quarter) / ShipData.VOXEL_SIZE).floor())
	_place_cell = Vector3i(((local + normal * quarter) / ShipData.VOXEL_SIZE).floor())
	return true


func _show_ghost(ghost: MeshInstance3D, a: Vector3i, b: Vector3i, removing: bool) -> void:
	var low: Vector3i = a.min(b)
	var cells: Vector3 = Vector3(a.max(b) - low + Vector3i.ONE)
	ghost.position = (Vector3(low) + cells * 0.5) * ShipData.VOXEL_SIZE
	# Un pelo más grande para que no parpadee contra las caras del casco.
	ghost.scale = cells * ShipData.VOXEL_SIZE + Vector3.ONE * 0.02
	(ghost.material_override as StandardMaterial3D).albedo_color = Color(1, 0.25, 0.2, 0.35) if removing else Color(0.3, 1, 0.4, 0.35)


func _make_ghost() -> MeshInstance3D:
	var ghost: MeshInstance3D = MeshInstance3D.new()
	ghost.mesh = BoxMesh.new()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material_override = material
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.visible = false
	ship.add_child.call_deferred(ghost)
	return ghost


func _update_hud() -> void:
	if not building:
		_hud.text = ""
		return
	var material: VoxelMaterial = ship.catalog.get_material(material_id)
	_hud.text = "CONSTRUCCIÓN (dique seco)\nHerramienta: %s   Material: %s   Espejo: %s" % [TOOL_NAMES[tool], material.display_name, "sí" if mirror else "no"]
