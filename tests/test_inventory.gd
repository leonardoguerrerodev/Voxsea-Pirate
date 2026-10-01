extends Node
## Chequeo del inventario: apilar, desbordar, sacar y mover entre casillas.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_inventory

var _failed: bool = false


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	var fish: ItemData = load("res://items/data/pescado_cocido.tres")  # se apila de a 10
	var bell: ItemData = load("res://items/data/campana.tres")  # no se apila
	var inventory: Inventory = Inventory.new(3)
	var signals: Array[int] = [0]
	inventory.changed.connect(func() -> void: signals[0] += 1)
	_expect(inventory.add(fish, 15) == 0, "15 pescados caben en 2 casillas")
	_expect(inventory.slots[0].count == 10 and inventory.slots[1].count == 5, "la primera pila se llena a 10")
	_expect(inventory.add(bell, 2) == 1, "2 campanas: cabe 1 (queda 1 casilla)")
	_expect(inventory.add(fish, 3) == 0 and inventory.slots[1].count == 8, "más pescado completa la pila que había")
	_expect(inventory.count_of(fish) == 18, "cuenta 18 pescados")
	_expect(inventory.remove(fish, 9) == 9 and inventory.count_of(fish) == 9, "saca 9, empezando por el final")
	inventory.move(2, 1)
	_expect(inventory.slots[1].item == bell and inventory.slots[2].item == null, "mover a una casilla vacía")
	inventory.move(1, 0)
	_expect(inventory.slots[0].item == bell and inventory.slots[1].item == fish, "mover sobre otro objeto intercambia")
	_expect(signals[0] > 0, "avisa los cambios")
	_expect(fish.icon != null and fish.prop != null, "el objeto trae ícono y modelo")
	print("FALLA" if _failed else "OK")
	get_tree().quit(1 if _failed else 0)
