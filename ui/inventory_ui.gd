class_name InventoryUI
extends Control
## Inventario del jugador (presentación, regla 3): Tab lo abre y lo cierra, Esc lo
## cierra. Clic en una casilla la elige; clic en otra la mueve ahí (apila o
## intercambia). Clic derecho en un objeto con modelo: colocarlo en el barco. Abajo, nombre y descripción de lo que está bajo el mouse o elegido.
## Abierto: mouse visible y jugador quieto (mira libre no; así el clic no gira la cámara).

## Clic derecho en un objeto que se puede poner en el barco.
signal place_requested(item: ItemData)

const COLUMNS: int = 6
const SLOT_SIZE: Vector2 = Vector2(104, 104)

var player: Player

var _inventory: Inventory
var _buttons: Array[Button] = []
var _selected: int = -1
var _detail: Label
var _was_immobile: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.1, 0.08, 0.96)
	style.border_color = Color(0.55, 0.4, 0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title: Label = Label.new()
	title.text = "Inventario"
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	_inventory = player.inventory
	for i: int in _inventory.slots.size():
		var button: Button = Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.focus_mode = Control.FOCUS_NONE
		var count: Label = Label.new()
		count.name = "Count"
		count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		count.offset_left = -44
		count.offset_top = -30
		count.offset_right = -6
		count.offset_bottom = -4
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.add_theme_font_size_override("font_size", 20)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 6)
		button.add_child(count)
		button.pressed.connect(_on_slot_pressed.bind(i))
		button.gui_input.connect(_on_slot_input.bind(i))
		button.mouse_entered.connect(_show_detail.bind(i))
		grid.add_child(button)
		_buttons.append(button)
	_detail = Label.new()
	_detail.custom_minimum_size = Vector2(0, 64)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 18)
	box.add_child(_detail)
	_inventory.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or (visible and event.is_action_pressed("pause")):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	# No se abre con el juego en pausa (el menú de pausa ya tiene el mouse).
	if not visible and get_tree().paused:
		return
	visible = not visible
	_selected = -1
	if visible:
		_was_immobile = player.immobile
		player.immobile = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_refresh()
	else:
		player.immobile = _was_immobile
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_slot_pressed(index: int) -> void:
	if _selected < 0:
		if _inventory.slots[index].item != null:
			_selected = index
	else:
		_inventory.move(_selected, index)
		_selected = -1
	_refresh()
	_show_detail(index)


func _on_slot_input(event: InputEvent, index: int) -> void:
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button and button.pressed and button.button_index == MOUSE_BUTTON_RIGHT:
		var item: ItemData = _inventory.slots[index].item
		if item and item.prop:
			toggle()
			place_requested.emit(item)


func _refresh() -> void:
	for i: int in _buttons.size():
		var slot: Dictionary = _inventory.slots[i]
		var item: ItemData = slot.item
		_buttons[i].icon = item.icon if item else null
		(_buttons[i].get_node("Count") as Label).text = str(slot.count) if item and slot.count > 1 else ""
		_buttons[i].modulate = Color(1.0, 0.85, 0.4) if i == _selected else Color.WHITE


func _show_detail(index: int) -> void:
	var item: ItemData = _inventory.slots[index].item
	_detail.text = "%s\n%s%s" % [item.display_name, item.description, "\nClic derecho: colocar en el barco" if item.prop else ""] if item else ""
