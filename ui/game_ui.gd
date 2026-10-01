extends CanvasLayer
## UI temporal: ayuda de controles (F1 la oculta) y menú de pausa (Esc).

const HELP: String = """WASD moverse · Espacio saltar · Shift correr · C agacharse
B construir (dique seco) · clic izq. poner · clic der. quitar
T herramienta · 1-6 material · M espejo · Ctrl+Z / Ctrl+Y deshacer / rehacer
F3 depuración del barco · F1 ocultar esta ayuda · Esc pausa"""

var _help: Label
var _menu: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_help = Label.new()
	_help.text = HELP
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -120
	_style(_help, 18)
	add_child(_help)

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
	box.add_child(_button("Salir", func() -> void: get_tree().quit()))
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	margin.add_child(box)
	_menu.add_child(margin)
	_menu.visible = false
	add_child(_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_set_paused(not get_tree().paused)
	elif event is InputEventKey and event.is_pressed() and not event.is_echo() and (event as InputEventKey).keycode == KEY_F1:
		_help.visible = not _help.visible


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_menu.visible = paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED


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
