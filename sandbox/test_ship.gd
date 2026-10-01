extends ShipBody
## Barco de prueba generado por código: casco de tablón con cubierta y borda, dos
## mamparos que lo dividen en tres compartimentos, quilla de hierro como lastre y
## una escotilla con escalera para bajar a la bodega del compartimento central.
## En cubierta: vela grande a proa, timón a popa y ancla en la proa. Proa = z bajo.

@export var hull_size: Vector3i = Vector3i(24, 12, 48)
## Grilla del barco: más grande que el casco para tener dónde construir.
@export var grid_size: Vector3i = Vector3i(32, 24, 64)

const PLANK: int = 2
const IRON: int = 3
## Ancho de la quilla de hierro, en voxels, al centro del fondo.
const KEEL_WIDTH: int = 4
## Fila de la cubierta (su tope queda a 5 m). Encima va la borda, de dos voxels
## para que la subida automática de escalones no la trepe.
const DECK_Y: int = 9
## Escalera: 8 escalones de un voxel, 4 voxels de ancho al centro, desde la bodega
## (z = STAIRS_Z) hacia popa; la escotilla se abre sobre los 7 de arriba (la
## cabeza del jugador necesita ese espacio al bajar).
const STAIRS_Z: int = 18
const STAIRS_WIDTH: int = 4
const SAIL: int = 8
const HELM: int = 9
const ANCHOR: int = 10
## Piezas sobre la cubierta, en z del casco (al centro en x).
const SAIL_Z: int = 12
const HELM_Z: int = 42
const ANCHOR_Z: int = 4


func _enter_tree() -> void:
	if data == null:
		data = _build_hull()
	super()


func _build_hull() -> ShipData:
	var ship: ShipData = ShipData.new(grid_size)
	# Casco centrado en x (el eje del espejo) y en z, apoyado en y = 0.
	var offset: Vector3i = Vector3i((grid_size.x - hull_size.x) / 2, 0, (grid_size.z - hull_size.z) / 2)
	var command: ShipEditCommand = ShipEditCommand.new()
	var center: float = (hull_size.x - 1) / 2.0
	var bulkheads: Array[int] = [hull_size.z / 3, hull_size.z * 2 / 3]
	for z: int in hull_size.z:
		for y: int in hull_size.y:
			# Manga máxima al centro, se angosta hacia proa/popa y hacia la quilla.
			var half: float = center * sin(PI * (z + 0.5) / hull_size.z) * (0.4 + 0.6 * y / (hull_size.y - 1.0))
			for x: int in hull_size.x:
				var dx: float = absf(x - center)
				if dx > half + 0.5:
					continue
				var shell: bool = dx > half - 0.5 or z == 0 or z == hull_size.z - 1
				var on_stairs: bool = dx < STAIRS_WIDTH / 2.0
				var step: int = z - STAIRS_Z
				var hatch: bool = on_stairs and step >= 2 and step <= 8
				if y == 0 and dx < KEEL_WIDTH / 2.0:
					command.add(offset + Vector3i(x, y, z), IRON)
				elif shell or y == 0 or (z in bulkheads and y < DECK_Y) or (y == DECK_Y and not hatch):
					command.add(offset + Vector3i(x, y, z), PLANK)
				elif on_stairs and step >= 1 and step <= 8 and y == step:
					command.add(offset + Vector3i(x, y, z), PLANK)
	var deck: int = DECK_Y + 1
	var middle: int = int(center)
	command.add(offset + Vector3i(middle, deck, SAIL_Z), SAIL)
	command.add(offset + Vector3i(middle, deck, HELM_Z), HELM)
	command.add(offset + Vector3i(middle, deck, ANCHOR_Z), ANCHOR)
	ShipEditor.apply(ship, command)
	return ship
