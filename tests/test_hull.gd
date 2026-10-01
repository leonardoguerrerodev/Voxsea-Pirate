extends Node
## Chequeo del casco fijo en mar calmo: masa del perfil, una caja cerrada flota,
## una balsa flota baja, peso a un costado escora y la balandra flota derecha.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_hull

const SLOOP: String = "res://assets/ships/sloop/sloop.grid"
## Cubierta de la balandra sobre la quilla (tools/hull_to_grid.py la alinea ahí).
const SLOOP_DECK: float = 5.5

var _calm: WaveSettings = WaveSettings.new()
var _failed: bool = false
var _ships: Dictionary = {}
var _frame: int = 0


func _ready() -> void:
	_check_mass()
	_ships["casco"] = _spawn(HullProfile.box(Vector3i(10, 8, 16), 600.0), Vector3(0, 0, 0))
	_ships["balsa"] = _spawn(HullProfile.box(Vector3i(8, 1, 16), 600.0), Vector3(30, 0, 0))
	var weight: ShipPart = ShipPart.new()
	weight.mass = 5000.0
	weight.position = Vector3(0.5, 4.0, 4.0)
	_ships["peso_babor"] = _spawn(HullProfile.box(Vector3i(10, 8, 16), 600.0), Vector3(60, 0, 0), [weight])
	_ships["balandra"] = _spawn(HullProfile.from_file(SLOOP, 600.0), Vector3(90, 0, 0))


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _spawn(profile: HullProfile, at: Vector3, parts: Array[ShipPart] = []) -> ShipBody:
	var ship: ShipBody = ShipBody.new()
	ship.profile = profile
	ship.waves = _calm
	ship.can_sleep = false
	ship.position = at
	for part: ShipPart in parts:
		ship.add_child(part)
	add_child(ship)
	return ship


func _check_mass() -> void:
	print("masa:")
	var profile: HullProfile = HullProfile.box(Vector3i(4, 2, 4), 600.0)
	# Caja de 4·2·4 con todas las caras: todos sus voxels son casco.
	_expect(is_equal_approx(profile.mass, 32 * 600.0 * 0.125), "masa = voxels de casco · densidad · 0,125 m³ (%.0f kg)" % profile.mass)
	var sloop: HullProfile = HullProfile.from_file(SLOOP, 600.0)
	print("  balandra: %.0f kg, eslora %.1f m, manga %.1f m, %d celdas" % [sloop.mass, sloop.length, sloop.beam, sloop.cell_volumes.size()])
	_expect(sloop.interior.count(1) > 1000, "la balandra tiene bodega (%d voxels de aire)" % sloop.interior.count(1))


func _roll(ship: ShipBody) -> float:
	return ship.global_basis.get_euler().z


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 600:
		print("a los 10 s:")
		var hull: ShipBody = _ships["casco"]
		var raft: ShipBody = _ships["balsa"]
		_expect(hull.global_position.y < 0.0 and hull.global_position.y > -4.0, "casco cerrado flota (base en %.2f m, alto 4 m)" % hull.global_position.y)
		_expect(raft.global_position.y > -0.4 and raft.global_position.y < -0.2, "balsa flota baja (base en %.2f m, esperado -0,30)" % raft.global_position.y)
		_expect(absf(_roll(_ships["peso_babor"])) > 0.05, "peso a un costado escora (%.2f rad)" % _roll(_ships["peso_babor"]))
		var sloop: ShipBody = _ships["balandra"]
		var draft: float = -sloop.global_position.y
		_expect(draft > 0.0 and draft < SLOOP_DECK, "balandra flota con la cubierta afuera (calado %.2f m, %.0f kg)" % [draft, sloop.mass])
		_expect(absf(_roll(sloop)) < 0.05, "balandra derecha (escora %.3f rad)" % _roll(sloop))
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)
