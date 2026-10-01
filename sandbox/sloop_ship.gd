extends ShipBody
## Balandra de prueba: casco modelado (assets/ships/sloop, sale de
## tools/hull_to_grid.py) con su grilla física. Encima de la cubierta pone vela
## grande, timón en la cubierta de popa y ancla a proa. Proa = z bajo.

@export_file("*.grid") var grid_path: String = "res://assets/ships/sloop/sloop.grid"

const SAIL: int = 8
const HELM: int = 9
const ANCHOR: int = 10
## Dónde va cada pieza a lo largo del barco (0 = proa, 1 = popa), en la crujía y
## sobre el voxel más alto de esa columna.
const PARTS: Dictionary = {SAIL: 0.37, HELM: 0.85, ANCHOR: 0.2}


func _enter_tree() -> void:
	if data == null:
		data = HullGrid.load_grid(grid_path)
		var command: ShipEditCommand = ShipEditCommand.new()
		for id: int in PARTS:
			var column: Vector2i = Vector2i(data.size.x / 2, int(data.size.z * PARTS[id]))
			var y: int = data.size.y - 1
			while y > 0 and data.get_voxel(Vector3i(column.x, y - 1, column.y)) == 0:
				y -= 1
			command.add(Vector3i(column.x, y, column.y), id)
		ShipEditor.apply(data, command)
	super()
