extends Node
## Chequeo de la fase 4 en mar calmo. Correr con (ver tests/run.gd):
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_hydro

const PLANK: int = 2
const IRON: int = 3

var _catalog: MaterialCatalog
var _calm: WaveSettings = WaveSettings.new()
var _failed: bool = false
var _ships: Dictionary = {}
var _frame: int = 0
var _breached: bool = false


func _ready() -> void:
	_catalog = load("res://ship/data/materials.tres")
	_check_mass()
	_check_compartments()
	# Escenarios físicos, separados en x para que no se toquen.
	_ships["casco"] = _spawn(_box(Vector3i(10, 8, 16), true), Vector3(0, 0, 0))
	_ships["balsa"] = _spawn(_box(Vector3i(8, 1, 16), true), Vector3(30, 0, 0))
	var low: ShipData = _box(Vector3i(10, 8, 16), true)
	_fill(low, Vector3i(1, 1, 1), Vector3i(9, 2, 15), IRON)
	_ships["peso_abajo"] = _spawn(low, Vector3(60, 0, 0), 0.15)
	var high: ShipData = _box(Vector3i(10, 8, 16), true)
	_fill(high, Vector3i(1, 6, 1), Vector3i(9, 7, 15), IRON)
	_ships["peso_arriba"] = _spawn(high, Vector3(90, 0, 0), 0.15)
	var breach: ShipData = _box(Vector3i(10, 8, 32), true)
	_fill(breach, Vector3i(1, 1, 16), Vector3i(9, 7, 17), PLANK)  # mamparo
	_ships["brecha"] = _spawn(breach, Vector3(120, 0, 0))


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


## Caja de tablón de pared simple; con tapa = cubierta cerrada.
func _box(size: Vector3i, lid: bool) -> ShipData:
	var data: ShipData = ShipData.new(size)
	var command: ShipEditCommand = ShipEditCommand.new()
	for z: int in size.z:
		for y: int in size.y:
			for x: int in size.x:
				var shell: bool = x == 0 or x == size.x - 1 or z == 0 or z == size.z - 1 or y == 0 or (lid and y == size.y - 1)
				if shell:
					command.add(Vector3i(x, y, z), PLANK)
	ShipEditor.apply(data, command)
	return data


func _fill(data: ShipData, from: Vector3i, to: Vector3i, value: int) -> void:
	var command: ShipEditCommand = ShipEditCommand.new()
	for z: int in range(from.z, to.z):
		for y: int in range(from.y, to.y):
			for x: int in range(from.x, to.x):
				command.add(Vector3i(x, y, z), value)
	ShipEditor.apply(data, command)


func _spawn(data: ShipData, at: Vector3, roll: float = 0.0) -> ShipBody:
	var ship: ShipBody = ShipBody.new()
	ship.data = data
	ship.catalog = _catalog
	ship.waves = _calm
	ship.can_sleep = false
	ship.water_drag = 1.0
	ship.transform = Transform3D(Basis(Vector3.BACK, roll), at)
	add_child(ship)
	return ship


func _check_mass() -> void:
	print("masa:")
	var data: ShipData = _box(Vector3i(4, 2, 4), false)
	var hydro: ShipHydrostatics = ShipHydrostatics.new(data, _catalog)
	hydro.rebuild()
	var voxels: int = data.voxels.count(PLANK)
	_expect(is_equal_approx(hydro.mass, voxels * 600.0 * 0.125), "masa = voxels · densidad · 0,125 m³ (%.0f kg)" % hydro.mass)
	_expect(hydro.center_of_mass.is_equal_approx(Vector3(1.0, hydro.center_of_mass.y, 1.0)), "centro de gravedad al medio en x/z")


func _check_compartments() -> void:
	print("compartimentos:")
	var open: ShipData = _box(Vector3i(6, 4, 6), false)
	var hydro: ShipHydrostatics = ShipHydrostatics.new(open, _catalog)
	hydro.rebuild()
	_expect(hydro.compartments.size() == 1, "bote sin cubierta: 1 compartimento")
	_expect(hydro.compartments[0].cells.size() == 4 * 3 * 4, "su interior son 4·3·4 voxels")
	_expect(not hydro.compartments[0].openings.is_empty(), "abierto arriba: tiene aberturas")
	var closed: ShipData = _box(Vector3i(6, 4, 6), true)
	hydro = ShipHydrostatics.new(closed, _catalog)
	hydro.rebuild()
	_expect(hydro.compartments.size() == 1 and hydro.compartments[0].openings.is_empty(), "caja cerrada: sellada")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 600:
		print("a los 10 s:")
		var hull: ShipBody = _ships["casco"]
		var raft: ShipBody = _ships["balsa"]
		_expect(hull.global_position.y < 0.0 and hull.global_position.y > -4.0, "casco cerrado flota (base en %.2f m, alto 4 m)" % hull.global_position.y)
		_expect(raft.global_position.y > -0.4 and raft.global_position.y < -0.2, "balsa flota baja (base en %.2f m, esperado -0,30)" % raft.global_position.y)
		var low_roll: float = absf((_ships["peso_abajo"] as ShipBody).global_basis.get_euler().z)
		var high_roll: float = absf((_ships["peso_arriba"] as ShipBody).global_basis.get_euler().z)
		_expect(low_roll < 0.1, "peso abajo se endereza (escora %.2f rad)" % low_roll)
		_expect(high_roll > 0.4, "peso arriba escora (%.2f rad)" % high_roll)
		var breach: ShipBody = _ships["brecha"]
		_expect(breach.hydro.flooded_count() == 0, "sin brecha no entra agua")
		# Agujero en el costado, bajo la línea de flotación, en la mitad de proa (z < 16).
		var hole: ShipEditCommand = ShipEditCommand.new()
		for z: int in [4, 5]:
			for y: int in [1, 2]:
				hole.add(Vector3i(0, y, z), 0)
		ShipEditor.apply(breach.data, hole)
	if _frame == 600 + 1800:
		print("30 s después de la brecha:")
		var breach: ShipBody = _ships["brecha"]
		var bow: float = (breach.global_transform * Vector3(2.5, 0, 0)).y
		var stern: float = (breach.global_transform * Vector3(2.5, 0, 16)).y
		_expect(breach.hydro.flooded_count() > 100, "entró agua (%d voxels)" % breach.hydro.flooded_count())
		_expect(bow < stern - 0.5, "se hunde la proa (proa %.2f m, popa %.2f m)" % [bow, stern])
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)
