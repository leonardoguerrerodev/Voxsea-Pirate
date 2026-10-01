extends CanvasLayer
## UI temporal: ayuda de controles (F1 la oculta), coordenadas de mapa, hora y
## rumbo de la mirada (arriba a la derecha) y menú de pausa (Esc) con menú dev.

const HELP: String = """WASD moverse · Espacio saltar · Shift correr · C agacharse
E tomar el timón (A/D timón · W/S velas · R ancla · E soltar)
Tab inventario (clic der. colocar) · E abrir · F recoger · rueda girar · Q brújula · F3 centro de gravedad · F1 ocultar esta ayuda · Esc pausa"""

## A quién se le muestran las coordenadas.
@export var player: Player
## Para el menú dev.
@export var ship: ShipBody
@export var sky: Sky3D
## Su material lo ajusta el menú dev.
@export var ocean: OceanSurface
## Recibe los objetos que se eligen para colocar desde el inventario.
@export var placer: DecorPlacer

var show_fps: bool = false

var _help: Label
var _coords: Label
var _menu: PanelContainer
var _dev: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_help = Label.new()
	_help.text = HELP
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -145
	_style(_help, 18)
	add_child(_help)

	_coords = Label.new()
	_coords.anchor_left = 1.0
	_coords.anchor_right = 1.0
	_coords.offset_left = -360
	_coords.offset_right = -16
	_coords.offset_top = 16
	_coords.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_style(_coords, 22)
	add_child(_coords)

	_menu = PanelContainer.new()
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu.grow_vertical = Control.GROW_DIRECTION_BOTH
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var title: Label = Label.new()
	title.text = "Pausa"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(title, 32)
	box.add_child(title)
	box.add_child(_button("Continuar", func() -> void: _set_paused(false)))
	box.add_child(_button("Dev", _toggle_dev))
	box.add_child(_button("Salir", func() -> void: get_tree().quit()))
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_child(box)
	_menu.add_child(margin)
	_menu.visible = false
	add_child(_menu)

	_dev = (load("res://ui/dev_menu.gd") as GDScript).new()
	_dev.set("ship", ship)
	_dev.set("player", player)
	_dev.set("sky", sky)
	_dev.set("ocean", ocean)
	_dev.set("ui", self)
	_dev.visible = false
	add_child(_dev)

	# Hijo de esta UI: recibe la entrada antes, así Esc lo cierra sin pausar.
	var inventory: InventoryUI = InventoryUI.new()
	inventory.player = player
	add_child(inventory)
	if placer:
		inventory.place_requested.connect(placer.begin)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if player == null or camera == null:
		return
	var heading: float = MapCoords.heading(-camera.global_basis.z)
	_coords.text = "%s · %s\nrumbo %03d° %s · %s" % [Game.clock(), MapCoords.format(player.global_position), roundi(heading) % 360, MapCoords.compass(heading), Weather.NAMES[Weather.target]]
	if show_fps:
		_coords.text += "\n%d fps" % Engine.get_frames_per_second()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F1:
		_help.visible = not _help.visible


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_menu.visible = paused
	if not paused:
		_dev.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


func _toggle_dev() -> void:
	_dev.visible = not _dev.visible
	if _dev.visible:
		_dev.call("refresh")


func _button(text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button


func _style(label: Label, size: int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
