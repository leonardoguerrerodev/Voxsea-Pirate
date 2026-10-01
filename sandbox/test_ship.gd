extends ShipMesh
## Barco de prueba generado por código: casco abierto con fondo de hierro.

@export var hull_size: Vector3i = Vector3i(24, 10, 48)

const PLANK: int = 2
const IRON: int = 3


func _ready() -> void:
	var ship: ShipData = ShipData.new(hull_size)
	var command: ShipEditCommand = ShipEditCommand.new()
	var center: float = (hull_size.x - 1) / 2.0
	for z: int in hull_size.z:
		for y: int in hull_size.y:
			# Manga máxima al centro, se angosta hacia proa/popa y hacia la quilla.
			var half: float = center * sin(PI * (z + 0.5) / hull_size.z) * (0.4 + 0.6 * y / (hull_size.y - 1.0))
			for x: int in hull_size.x:
				var dx: float = absf(x - center)
				if dx > half + 0.5:
					continue
				var shell: bool = dx > half - 0.5 or y == 0 or z == 0 or z == hull_size.z - 1
				if shell:
					command.add(Vector3i(x, y, z), IRON if y == 0 else PLANK)
	ShipEditor.apply(ship, command)
	set_data(ship)
