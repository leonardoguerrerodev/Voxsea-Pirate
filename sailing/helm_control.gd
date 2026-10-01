extends Node
## Tomar el timón (E) cerca de una pieza timón: el jugador queda quieto (mira
## libre) y sus teclas manejan el barco. A/D timón, W/S velas, R ancla, E soltar.

## Distancia máxima al timón para tomarlo (m).
const REACH: float = 2.5
## Rapidez de los mandos (por segundo).
const RUDDER_RATE: float = 1.5
const SAIL_RATE: float = 0.4

@export var ship: ShipBody
@export var rig: ShipRig
@export var player: Player

var at_helm: bool = false
var _hud: Label


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud.offset_top = -190
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 24)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if at_helm:
			_set_helm(false)
		elif _near_helm():
			_set_helm(true)
	elif at_helm and event.is_action_pressed("anchor"):
		rig.anchored = not rig.anchored


func _physics_process(delta: float) -> void:
	if at_helm:
		var steer: float = Input.get_axis("move_left", "move_right")
		rig.rudder = move_toward(rig.rudder, steer, RUDDER_RATE * delta)
		var hoist: float = Input.get_axis("move_back", "move_forward")
		rig.sail_amount = clampf(rig.sail_amount + hoist * SAIL_RATE * delta, 0.0, 1.0)
	_update_hud()


func _set_helm(value: bool) -> void:
	at_helm = value
	player.immobile = value
	if not value:
		rig.rudder = 0.0


func _near_helm() -> bool:
	for helm: ShipPart in ship.parts(ShipPart.Kind.HELM):
		if helm.global_position.distance_to(player.global_position) < REACH:
			return true
	return false


func _update_hud() -> void:
	if at_helm:
		var wind: Vector3 = Wind.velocity_at(Game.ocean_time)
		var speed: float = Vector2(ship.linear_velocity.x, ship.linear_velocity.z).length()
		var helm: String = "◀" if rig.rudder < -0.05 else ("▶" if rig.rudder > 0.05 else "|")
		var course: float = MapCoords.heading(-ship.global_basis.z)
		# El viento se nombra por de dónde viene, como en náutica.
		var wind_from: String = MapCoords.compass(MapCoords.heading(-wind))
		_hud.text = "AL TIMÓN · rumbo %03d° %s · %.1f nudos · velas %d%% · timón %s · ancla %s · viento del %s, %.0f m/s\nA/D timón · W/S velas · R ancla · E soltar" % [roundi(course) % 360, MapCoords.compass(course), speed * 1.944, roundi(rig.sail_amount * 100.0), helm, "echada" if rig.anchored else "arriba", wind_from, wind.length()]
	elif _near_helm():
		_hud.text = "E: tomar el timón"
	else:
		_hud.text = ""
