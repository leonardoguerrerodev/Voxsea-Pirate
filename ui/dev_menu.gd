extends PanelContainer
## Menú dev (temporal): ajusta en vivo todo lo configurable del juego. Se abre
## desde la pausa. Cada fila lee y escribe una propiedad de un objeto; agregar un
## ajuste nuevo es una línea en _build().

var ship: ShipBody
var player: Player
var sky: Sky3D
var ocean: OceanSurface
var ui: Node

var _rows: Array[Dictionary] = []
var _list: VBoxContainer


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -620
	offset_top = 110
	offset_right = -16
	offset_bottom = -16
	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var outer: VBoxContainer = VBoxContainer.new()
	margin.add_child(outer)
	var title: Label = Label.new()
	title.text = "Menú dev"
	title.add_theme_font_size_override("font_size", 28)
	outer.add_child(title)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_build()


## Vuelve a leer los valores (la hora o el clima cambian solos).
func refresh() -> void:
	for row: Dictionary in _rows:
		var value: Variant = (row.object as Object).get(row.property)
		var control: Control = row.control
		if control is HSlider:
			(control as HSlider).set_value_no_signal(value)
			(row.label as Label).text = _number(value)
		elif control is CheckBox:
			(control as CheckBox).set_pressed_no_signal(value)
		elif control is OptionButton:
			(control as OptionButton).select(value)


func _build() -> void:
	var rig: ShipRig = ship.get_node("Rig") as ShipRig
	var apply_speed: Callable = func() -> void: player._enter_normal_state()
	_section("Tiempo")
	_slider(Game, "hour", "Hora del día", 0.0, 23.99, 0.1)
	_slider(Game, "day_minutes", "Duración del día (min)", 1.0, 120.0, 1.0)
	_check(Game, "day_paused", "Detener el ciclo")
	_section("Clima")
	_check(Weather, "auto_cycle", "Ciclo automático")
	_option(Weather, "target", "Estado", Weather.NAMES)
	_button("Aplicar el estado ya", func() -> void: Weather.apply_now())
	_slider(Weather, "transition_seconds", "Transición (s)", 1.0, 300.0, 1.0)
	_slider(Weather, "period_minutes", "Cambia cada (min)", 0.5, 60.0, 0.5)
	_section("Viento")
	_slider(Wind, "direction", "Hacia dónde sopla (°, 0 = este)", -180.0, 180.0, 1.0)
	_slider(Wind, "speed", "Velocidad base (m/s)", 0.0, 30.0, 0.5)
	_slider(Wind, "variability", "Variabilidad", 0.0, 1.0, 0.05)
	_slider(Weather, "wind_multiplier", "Multiplicador (× clima)", 0.0, 3.0, 0.05)
	_section("Mar")
	_slider(Weather, "wave_multiplier", "Altura de olas (× clima)", 0.0, 3.0, 0.05)
	var sea: ShaderMaterial = ocean.material_override as ShaderMaterial
	_slider(sea, "shader_parameter/detail_strength", "Ondas finas", 0.0, 2.0, 0.05)
	_slider(sea, "shader_parameter/detail_speed", "Velocidad de ondas finas", 0.0, 2.0, 0.05)
	_slider(sea, "shader_parameter/detail_fade", "Alcance de ondas finas (m)", 10.0, 200.0, 5.0)
	_slider(sea, "shader_parameter/sun_roughness", "Rugosidad del brillo del sol", 0.02, 1.0, 0.01)
	_slider(sea, "shader_parameter/scattering", "Luz en las crestas", 0.0, 3.0, 0.05)
	_slider(sea, "shader_parameter/refraction", "Refracción", 0.0, 0.2, 0.005)
	_slider(sea, "shader_parameter/clarity", "Claridad del agua", 0.25, 6.0, 0.05)
	_slider(sea, "shader_parameter/diffuse_amount", "Difusa del agua", 0.0, 1.0, 0.01)
	_slider(sea, "shader_parameter/jacobian_foam", "Espuma de crestas", 0.0, 1.0, 0.01)
	_section("Cielo (Sky3D)")
	_check(sky, "clouds_enabled", "Nubes (pesan en el Mac)")
	_check(sky, "fog_enabled", "Niebla atmosférica")
	_slider(sky, "moon_energy", "Luz de luna", 0.0, 3.0, 0.05)
	_slider(sky, "night_sky_contribution", "Brillo del cielo de noche", 0.0, 1.0, 0.05)
	_section("Barco")
	_slider(rig, "sail_scale", "Fuerza de vela (×)", 0.0, 30.0, 0.5)
	_slider(rig, "drag_forward", "Arrastre de frente", 0.05, 3.0, 0.05)
	_slider(rig, "keel_lift", "Sustentación de quilla", 0.0, 10.0, 0.1)
	_slider(rig, "anchor_drag", "Freno del ancla", 0.0, 20.0, 0.5)
	_slider(rig, "side_push", "Tirón de costado de la vela", 0.0, 1.0, 0.01)
	_slider(ship, "roll_damping", "Amortiguación de escora", 0.0, 10.0, 0.1)
	_slider(ship, "water_drag", "Arrastre vertical", 0.0, 10.0, 0.1)
	_slider(ship, "max_heel", "Escora libre (°)", 0.0, 90.0, 1.0)
	_slider(ship, "righting", "Adrizado (rigidez)", 0.0, 30.0, 0.5)
	_section("Jugador")
	_slider(player, "base_speed", "Velocidad al caminar", 0.5, 15.0, 0.5, apply_speed)
	_slider(player, "sprint_speed", "Velocidad al correr", 0.5, 25.0, 0.5, apply_speed)
	_slider(player, "jump_velocity", "Salto", 1.0, 15.0, 0.5)
	_slider(player, "mouse_sensitivity", "Sensibilidad del mouse", 0.01, 0.5, 0.01)
	_button("Dar objetos de prueba", _give_test_items)
	_button("Borrar partida guardada", func() -> void: SaveGame.delete())
	_section("Gráficos")
	_slider(get_viewport(), "scaling_3d_scale", "Escala de render 3D", 0.25, 1.0, 0.05)
	var env: Environment = sky.environment
	_option(env, "tonemap_mode", "Tonemapping", PackedStringArray(["Lineal", "Reinhard", "Filmic", "ACES", "AgX"]))
	_slider(env, "tonemap_exposure", "Exposición", 0.25, 4.0, 0.05)
	_check(env, "adjustment_enabled", "Ajustes de color")
	_slider(env, "adjustment_saturation", "Saturación", 0.0, 2.0, 0.05)
	_slider(env, "adjustment_contrast", "Contraste", 0.0, 2.0, 0.05)
	_check(env, "ssr_enabled", "Reflejos SSR")
	_check(env, "ssao_enabled", "Oclusión SSAO")
	_check(env, "ssil_enabled", "Luz indirecta SSIL")
	_check(env, "sdfgi_enabled", "Iluminación global SDFGI")
	_check(env, "glow_enabled", "Brillo (glow)")
	_check(env, "volumetric_fog_enabled", "Niebla volumétrica")
	_check(ui, "show_fps", "Mostrar FPS")


## Uno de cada objeto de items/data (cinco de lo que se apila).
func _give_test_items() -> void:
	for file: String in DirAccess.get_files_at("res://items/data"):
		if file.ends_with(".tres"):
			var item: ItemData = load("res://items/data".path_join(file))
			player.inventory.add(item, 5 if item.max_stack > 1 else 1)


func _section(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	_list.add_child(label)


func _slider(object: Object, property: String, text: String, low: float, high: float, step: float, after: Callable = Callable()) -> void:
	var row: HBoxContainer = _row(text)
	var slider: HSlider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.x = 200
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = 64
	slider.value_changed.connect(func(value: float) -> void:
		object.set(property, value)
		value_label.text = _number(value)
		if after.is_valid():
			after.call())
	row.add_child(slider)
	row.add_child(value_label)
	_rows.append({"object": object, "property": property, "control": slider, "label": value_label})


func _check(object: Object, property: String, text: String) -> void:
	var row: HBoxContainer = _row(text)
	var box: CheckBox = CheckBox.new()
	box.toggled.connect(func(on: bool) -> void: object.set(property, on))
	row.add_child(box)
	_rows.append({"object": object, "property": property, "control": box})


func _option(object: Object, property: String, text: String, names: PackedStringArray) -> void:
	var row: HBoxContainer = _row(text)
	var option: OptionButton = OptionButton.new()
	for item: String in names:
		option.add_item(item)
	option.item_selected.connect(func(index: int) -> void: object.set(property, index))
	row.add_child(option)
	_rows.append({"object": object, "property": property, "control": option})


func _button(text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	_list.add_child(button)


func _row(text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var label: Label = Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	_list.add_child(row)
	return row


func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
