class_name SaveGame
extends Node
## Guarda y carga la partida en user://partida.json: inventario, objetos colocados
## en el barco (posición, giro, abierto), posición del barco y del jugador, y hora.
## Carga al entrar si hay partida; guarda al salir (botón Salir o cerrar la ventana)
## y cuando se pide (pausa → Guardar). Los objetos se guardan por id: el archivo
## items/data/<id>.tres lo resuelve al cargar.

const PATH: String = "user://partida.json"
const VERSION: int = 1

@export var ship: ShipBody
@export var player: Player


func _ready() -> void:
	get_tree().auto_accept_quit = false
	# Después de que el barco y el jugador tengan su estado inicial.
	if FileAccess.file_exists(PATH):
		load_game.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_and_quit()


func save_and_quit() -> void:
	save_game()
	get_tree().quit()


func save_game() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(capture(ship, player), "\t"))


func load_game() -> bool:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not data is Dictionary or (data as Dictionary).get("version", 0) != VERSION:
		push_warning("Partida ilegible o de otra versión: se ignora")
		return false
	restore(data, ship, player)
	return true


static func delete() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## La partida como diccionario apto para JSON.
static func capture(p_ship: ShipBody, p_player: Player) -> Dictionary:
	var slots: Array = []
	for slot: Dictionary in p_player.inventory.slots:
		var item: ItemData = slot.item
		slots.append([String(item.id), slot.count] if item else null)
	var decor: Array = []
	for child: Node in p_ship.get_children():
		var piece: DecorPiece = child as DecorPiece
		if piece:
			var openable: OpenableProp = piece.model as OpenableProp
			decor.append({"id": String(piece.item.id), "transform": _pack(piece.transform), "open": openable != null and openable.open})
	return {
		"version": VERSION,
		"hour": Game.hour,
		"ship": _pack(p_ship.global_transform),
		"player": _pack(p_player.transform),
		"inventory": slots,
		"decor": decor,
	}


static func restore(data: Dictionary, p_ship: ShipBody, p_player: Player) -> void:
	Game.hour = data.hour
	p_ship.global_transform = _unpack(data.ship)
	p_ship.linear_velocity = Vector3.ZERO
	p_ship.angular_velocity = Vector3.ZERO
	p_player.transform = _unpack(data.player)
	p_player.velocity = Vector3.ZERO
	var inventory: Inventory = p_player.inventory
	for i: int in mini(inventory.slots.size(), (data.inventory as Array).size()):
		var entry: Variant = data.inventory[i]
		var item: ItemData = _item(entry[0]) if entry is Array else null
		inventory.slots[i] = {"item": item, "count": int(entry[1]) if item else 0}
	inventory.changed.emit()
	for child: Node in p_ship.get_children():
		if child is DecorPiece:
			p_ship.remove_child(child)
			child.queue_free()
	for entry: Dictionary in data.decor:
		var item: ItemData = _item(entry.id)
		if item == null:
			continue
		var piece: DecorPiece = DecorPiece.create(item)
		piece.transform = _unpack(entry.transform)
		var openable: OpenableProp = piece.model as OpenableProp
		if openable:
			openable.open = entry.open
		p_ship.add_child(piece)
	p_ship.refresh_mass()


static func _item(id: String) -> ItemData:
	var path: String = "res://items/data/%s.tres" % id
	return load(path) as ItemData if ResourceLoader.exists(path) else null


## Transform3D ↔ 12 números (base por columnas + origen).
static func _pack(t: Transform3D) -> Array:
	return [t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z, t.basis.z.x, t.basis.z.y, t.basis.z.z, t.origin.x, t.origin.y, t.origin.z]


static func _unpack(a: Array) -> Transform3D:
	return Transform3D(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]), Vector3(a[9], a[10], a[11]))
