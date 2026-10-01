extends Node
## Chequeo de la fase 5 en mar calmo y viento fijo hacia +x (viene de -x). Un
## piloto automático mantiene el rumbo, como haría el jugador.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_sailing

const PLANK: int = 2
const SAIL: int = 8
const HELM: int = 9
const ANCHOR: int = 10
const RUN_FRAMES: int = 60 * 40

var _failed: bool = false
var _ships: Dictionary = {}
var _headings: Dictionary = {}
var _frame: int = 0


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


## Caja con cubierta, de tablón; vela grande a proa y timón a popa.
func _hull(size: Vector3i, sail: bool) -> ShipData:
	var data: ShipData = ShipData.new(size + Vector3i(0, 1, 0))
	var command: ShipEditCommand = ShipEditCommand.new()
	for z: int in size.z:
		for y: int in size.y:
			for x: int in size.x:
				if x == 0 or x == size.x - 1 or z == 0 or z == size.z - 1 or y == 0 or y == size.y - 1:
					command.add(Vector3i(x, y, z), PLANK)
	if sail:
		command.add(Vector3i(size.x / 2, size.y, size.z / 3), SAIL)
	command.add(Vector3i(size.x / 2, size.y, size.z - 3), HELM)
	command.add(Vector3i(size.x / 2, size.y, 2), ANCHOR)
	ShipEditor.apply(data, command)
	return data


## yaw: rumbo (rad). La proa es -z local: yaw 0 = proa hacia -z (viento de costado),
## yaw 90° = proa hacia -x (contra el viento).
func _spawn(key: String, data: ShipData, at: Vector3, yaw: float, speed: float = 0.0) -> void:
	var ship: ShipBody = ShipBody.new()
	ship.data = data
	ship.catalog = load("res://ship/data/materials.tres")
	ship.waves = WaveSettings.new()
	ship.transform = Transform3D(Basis(Vector3.UP, yaw), at)
	var rig: ShipRig = ShipRig.new()
	rig.name = "Rig"
	ship.add_child(rig)
	add_child(ship)
	ship.linear_velocity = -ship.global_basis.z * speed
	_ships[key] = ship
	_headings[key] = yaw


## Zona prohibida: el menor ángulo entre la proa y el viento con el que la vela,
## en su mejor orientación, empuja hacia adelante. Proa al viento no se avanza.
func _check_no_go_zone() -> void:
	var forward: Vector3 = Vector3.FORWARD
	for degrees: int in range(0, 91):
		# Viento aparente que viene desde `degrees` respecto de la proa.
		var apparent: Vector3 = -forward.rotated(Vector3.UP, deg_to_rad(degrees)) * 10.0
		var best: float = -INF
		for trim: float in ShipRig.trims():
			best = maxf(best, ShipRig.sail_force(apparent, forward.rotated(Vector3.UP, trim), 100.0).dot(forward))
		if best > 0.0:
			print("la vela empuja hacia adelante desde %d° del viento" % degrees)
			_expect(degrees >= 20 and degrees <= 50, "proa al viento no avanza: zona prohibida de ±%d°" % degrees)
			return
	_expect(false, "la vela nunca empuja hacia adelante")


func _ready() -> void:
	_check_no_go_zone()
	# Clima neutro: el test mide la vela, no el clima.
	Weather.set_physics_process(false)
	Wind.weather_scale = 1.0
	Wind.direction = 0.0
	Wind.variability = 0.0
	Wind.speed = 10.0
	var size: Vector3i = Vector3i(12, 8, 40)
	_spawn("de costado", _hull(size, true), Vector3(0, 0, 0), 0.0)
	_spawn("ceñida 50°", _hull(size, true), Vector3(0, 0, 200), deg_to_rad(40.0))
	_spawn("anclado", _hull(size, true), Vector3(0, 0, 400), 0.0)
	# Giro: sin velas, mismo ancho y alto, distinto largo, con 3 m/s de arranque.
	_spawn("corto", _hull(Vector3i(12, 8, 20), false), Vector3(0, 0, 600), 0.0, 3.0)
	_spawn("largo", _hull(Vector3i(12, 8, 60), false), Vector3(0, 0, 800), 0.0, 3.0)
	(_ships["anclado"].get_node("Rig") as ShipRig).anchored = true
	for key: String in ["de costado", "ceñida 50°", "anclado"]:
		(_ships[key].get_node("Rig") as ShipRig).sail_amount = 1.0


func _physics_process(_delta: float) -> void:
	_frame += 1
	for key: String in ["de costado", "ceñida 50°"]:
		var ship: ShipBody = _ships[key]
		var error: float = wrapf(_headings[key] - ship.global_rotation.y, -PI, PI)
		(ship.get_node("Rig") as ShipRig).rudder = clampf(-3.0 * error, -1.0, 1.0)
	if _frame == 60:
		for key: String in ["corto", "largo"]:
			_headings[key] = (_ships[key] as ShipBody).global_rotation.y
			(_ships[key].get_node("Rig") as ShipRig).rudder = 1.0
	if _frame == 60 + 60 * 8:
		var turned: Dictionary = {}
		for key: String in ["corto", "largo"]:
			turned[key] = absf(wrapf((_ships[key] as ShipBody).global_rotation.y - _headings[key], -PI, PI))
		print("giro en 8 s con el timón a fondo: corto %.0f°, largo %.0f°" % [rad_to_deg(turned["corto"]), rad_to_deg(turned["largo"])])
		_expect(turned["corto"] > turned["largo"] * 1.3, "el barco largo gira más lento")
	if _frame == RUN_FRAMES:
		for key: String in ["de costado", "ceñida 50°"]:
			var ship: ShipBody = _ships[key]
			var v: Vector3 = ship.linear_velocity
			print("%-15s velocidad %.2f m/s · contra el viento %+.2f m/s · deriva %.2f m/s · escora %.2f rad" % [key, Vector2(v.x, v.z).length(), -v.x, v.dot(ship.global_basis.x), ship.global_basis.get_euler().z])
		_expect(Vector2(_ships["de costado"].linear_velocity.x, _ships["de costado"].linear_velocity.z).length() > 2.5, "con viento de costado navega (> 2,5 m/s)")
		var anchored: Vector3 = _ships["anclado"].linear_velocity
		_expect(Vector2(anchored.x, anchored.z).length() < 0.3, "anclado con velas arriba no avanza (%.2f m/s)" % Vector2(anchored.x, anchored.z).length())
		_expect(-_ships["ceñida 50°"].linear_velocity.x > 0.3, "ciñendo a 50° gana terreno contra el viento: se puede ir en zigzag")
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)
