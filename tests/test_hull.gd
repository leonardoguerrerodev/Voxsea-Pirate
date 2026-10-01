extends Node
## Spike del casco modelado: la grilla que sale de tools/hull_to_grid.py flota,
## se endereza, escora con peso a un lado y se inunda por un agujero. Correr con:
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_hull

const GRID: String = "res://assets/ships/sloop/sloop.grid"
const IRON: int = 3

var _catalog: MaterialCatalog
var _calm: WaveSettings = WaveSettings.new()
var _failed: bool = false
var _ships: Dictionary = {}
var _frame: int = 0


func _ready() -> void:
	_catalog = load("res://ship/data/materials.tres")
	var data: ShipData = HullGrid.load_grid(GRID)
	var hydro: ShipHydrostatics = ShipHydrostatics.new(data, _catalog)
	var start: int = Time.get_ticks_usec()
	hydro.rebuild()
	print("grilla %s: %d voxels, %.0f kg, %d compartimentos, rebuild %.1f ms" % [data.size, data.voxels.count(2), hydro.mass, hydro.compartments.size(), (Time.get_ticks_usec() - start) / 1000.0])
	_expect(hydro.compartments.size() >= 1, "tiene aire interior")
	_ships["casco"] = _spawn(HullGrid.load_grid(GRID), Vector3(0, 0, 0))
	# Hierro contra el costado de babor, en la bodega: los 3 primeros voxels de
	# aire seco desde el casco, en el tercio central del largo.
	var heavy: ShipData = HullGrid.load_grid(GRID)
	var weight: ShipEditCommand = ShipEditCommand.new()
	for z: int in range(data.size.z / 3, data.size.z * 2 / 3):
		for y: int in range(2, 4):
			var placed: int = 0
			for x: int in data.size.x / 2:
				if placed < 3 and hydro.dry_air.get_voxel(Vector3i(x, y, z)) != 0:
					weight.add(Vector3i(x, y, z), IRON)
					placed += 1
	ShipEditor.apply(heavy, weight)
	_ships["peso_babor"] = _spawn(heavy, Vector3(30, 0, 0))
	_ships["brecha"] = _spawn(HullGrid.load_grid(GRID), Vector3(60, 0, 0))


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _spawn(data: ShipData, at: Vector3) -> ShipBody:
	var ship: ShipBody = ShipBody.new()
	ship.data = data
	ship.catalog = _catalog
	ship.waves = _calm
	ship.can_sleep = false
	ship.position = at
	add_child(ship)
	return ship


## Altura de la proa menos la de la popa, en la quilla (proa = z bajo).
func _trim(ship: ShipBody) -> float:
	return (ship.global_transform * Vector3(3.0, 0, 2.0)).y - (ship.global_transform * Vector3(3.0, 0, 11.0)).y


func _roll(ship: ShipBody) -> float:
	return ship.global_basis.get_euler().z


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 600:
		print("a los 10 s:")
		var hull: ShipBody = _ships["casco"]
		var draft: float = -hull.global_position.y
		var deck: float = 5.5
		print("  calado %.2f m (cubierta a %.1f m sobre la quilla), %.0f kg" % [draft, deck, hull.mass])
		_expect(draft > 0.0 and draft < deck, "flota con la cubierta fuera del agua")
		_expect(absf(_roll(hull)) < 0.05, "derecho (escora %.3f rad)" % _roll(hull))
		var heavy: ShipBody = _ships["peso_babor"]
		_expect(absf(_roll(heavy)) > 0.05, "peso a babor escora (%.2f rad, %.0f kg)" % [_roll(heavy), heavy.mass - hull.mass])
		# Agujero en el costado, bajo la línea de flotación, en la mitad de proa.
		var breach: ShipBody = _ships["brecha"]
		var hole: ShipEditCommand = ShipEditCommand.new()
		var y: int = maxi(1, int(draft / ShipData.VOXEL_SIZE) - 1)
		# Del costado hacia adentro hasta llegar a la bodega (el casco tiene 1 a 3 voxels).
		for z: int in [7, 8]:
			for x: int in breach.data.size.x:
				if breach.hydro.dry_air.get_voxel(Vector3i(x, y, z)) != 0:
					break
				if breach.data.get_voxel(Vector3i(x, y, z)) != 0:
					hole.add(Vector3i(x, y, z), 0)
		print("  agujero en y = %d (%.1f m), %d voxels" % [y, y * ShipData.VOXEL_SIZE, hole.positions.size()])
		var start: int = Time.get_ticks_usec()
		ShipEditor.apply(breach.data, hole)
		breach.hydro.rebuild()
		print("  rebuild tras el agujero: %.1f ms" % ((Time.get_ticks_usec() - start) / 1000.0))
	if _frame == 600 + 1800:
		print("30 s después de la brecha:")
		var breach: ShipBody = _ships["brecha"]
		var sunk: float = (_ships["casco"] as ShipBody).global_position.y - breach.global_position.y
		_expect(breach.hydro.flooded_count() > 20, "entró agua (%d voxels)" % breach.hydro.flooded_count())
		# La bodega es un solo compartimento (sin mamparos): se inunda entera y el
		# barco baja parejo, no solo la proa.
		_expect(sunk > 0.5, "baja %.2f m respecto del casco intacto (trimado %.2f m)" % [sunk, _trim(breach) - _trim(_ships["casco"])])
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)
