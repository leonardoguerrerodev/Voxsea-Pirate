class_name CannonControl
extends Node
## Manejar un cañón (E de cerca y mirándolo): el jugador queda quieto y oculto, la
## vista pasa a una cámara detrás de la recámara, el mouse apunta (horizontal gira
## el cañón, vertical sube o baja el tubo en sus muñones), clic dispara una bala
## del inventario y E lo suelta. El cañón es un objeto colocado (DecorPiece de
## tipo CANNON, props/canon_armado.tscn: la cureña es la base y el tubo la pieza
## que gira).

## Distancia horizontal máxima al cañón para tomarlo (m) y cuánto mirarlo (coseno).
const REACH: float = 1.8
const FACING: float = 0.5
## Boca del tubo y cámara, en ejes del tubo (su bisagra: los muñones). El tubo
## apunta a -x (props/canon_armado.tscn).
const MUZZLE: Vector3 = Vector3(-1.0, 0.03, 0.0)
const CAMERA_OFFSET: Vector3 = Vector3(2.2, 0.8, 0.0)

@export var ship: ShipBody
@export var player: Player
@export var helm: Node
## Munición: se gasta una por disparo.
@export var ammo: ItemData = preload("res://items/data/bala.tres")
@export_range(10.0, 200.0, 1.0, "suffix:m/s") var muzzle_speed: float = 70.0
@export_range(0.0, 10.0, 0.1, "suffix:s") var reload_time: float = 3.0
## Impulso de retroceso sobre el barco (N·s).
@export_range(0.0, 20000.0, 100.0) var recoil: float = 3000.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var yaw_limit: float = 45.0
@export_range(-45.0, 0.0, 1.0, "suffix:°") var pitch_min: float = -10.0
@export_range(0.0, 60.0, 1.0, "suffix:°") var pitch_max: float = 30.0
## Grados por píxel de mouse.
@export_range(0.01, 1.0, 0.01) var sensitivity: float = 0.1

## Cañón en uso (null si ninguno).
var cannon: DecorPiece
var yaw: float = 0.0
var pitch: float = 0.0
var cooldown: float = 0.0

var _camera: Camera3D
var _stand: Vector3
var _hud: Label


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud.offset_top = -130
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 24)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if cannon:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		var button: InputEventMouseButton = event as InputEventMouseButton
		if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			aim(-motion.screen_relative.x * sensitivity, -motion.screen_relative.y * sensitivity)
		elif button and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			fire()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			exit()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and not player.immobile and not (helm and helm.get("at_helm")):
		var near: DecorPiece = _near_cannon()
		if near:
			enter(near)
			get_viewport().set_input_as_handled()


func enter(piece: DecorPiece) -> void:
	cannon = piece
	yaw = rad_to_deg(piece.model.rotation.y)
	pitch = 0.0
	_stand = player.position
	player.immobile = true
	player.hidden = true
	_camera = Camera3D.new()
	_barrel().add_child(_camera)
	_camera.position = CAMERA_OFFSET
	_camera.rotation.y = PI / 2.0  # mira a -x, por el tubo
	_camera.make_current()
	aim(0.0, 0.0)


func exit() -> void:
	if _camera:
		_camera.queue_free()
		_camera = null
	player.CAMERA.make_current()
	player.immobile = false
	player.hidden = false
	cannon = null


## Mueve la puntería (grados): horizontal gira todo el cañón, vertical el tubo.
func aim(delta_yaw: float, delta_pitch: float) -> void:
	yaw = clampf(yaw + delta_yaw, -yaw_limit, yaw_limit)
	pitch = clampf(pitch + delta_pitch, pitch_min, pitch_max)
	cannon.model.rotation.y = deg_to_rad(yaw)
	# Subir la boca (en -x) es girar en negativo alrededor de los muñones (+z).
	(cannon.model as OpenableProp).set_turn(deg_to_rad(-pitch))


## Dispara si está cargado y hay balas. Devuelve la bala o null.
func fire() -> Cannonball:
	if cannon == null or cooldown > 0.0 or player.inventory.remove(ammo, 1) == 0:
		return null
	var barrel: Node3D = _barrel()
	var muzzle: Vector3 = barrel.global_transform * MUZZLE
	var direction: Vector3 = -barrel.global_basis.x.normalized()
	var ball: Cannonball = Cannonball.new()
	ball.waves = ship.waves
	ball.velocity = direction * muzzle_speed + ship.linear_velocity
	ship.get_parent().add_child(ball)
	ball.global_position = muzzle
	var smoke: CPUParticles3D = Effects.burst(Color(0.75, 0.75, 0.72), 3.0, 30)
	smoke.direction = direction
	ship.get_parent().add_child(smoke)
	smoke.global_position = muzzle
	_flash(muzzle)
	if not ship.freeze:
		ship.apply_impulse(-direction * recoil, muzzle - ship.global_position)
	cooldown = reload_time
	return ball


func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if cannon:
		# immobile solo corta las teclas: sin esto resbala con la escora.
		player.position = _stand
		player.velocity = Vector3.ZERO


func _process(_delta: float) -> void:
	if cannon:
		var balls: int = player.inventory.count_of(ammo)
		var state: String = "cargando…" if cooldown > 0.0 else ("listo" if balls > 0 else "sin balas")
		_hud.text = "AL CAÑÓN · %s · balas %d · elevación %+.0f°\nmouse apuntar · clic disparar · E soltar" % [state, balls, pitch]
	elif _near_cannon():
		_hud.text = "E: tomar el cañón"
	else:
		_hud.text = ""


func _barrel() -> Node3D:
	return (cannon.model as OpenableProp).pivot()


func _near_cannon() -> DecorPiece:
	for part: ShipPart in ship.parts(ShipPart.Kind.CANNON):
		var piece: DecorPiece = part as DecorPiece
		if piece == null:
			continue
		var offset: Vector3 = piece.global_position - player.global_position
		var look: Vector3 = -player.CAMERA.global_basis.z
		if Vector2(offset.x, offset.z).length() < REACH and look.dot((piece.global_position + Vector3.UP * 0.6 - player.CAMERA.global_position).normalized()) > FACING:
			return piece
	return null


func _flash(at: Vector3) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 6.0
	light.omni_range = 8.0
	ship.get_parent().add_child(light)
	light.global_position = at
	var tween: Tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.15)
	tween.finished.connect(light.queue_free)
