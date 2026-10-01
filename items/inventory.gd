class_name Inventory
extends RefCounted
## Casillas con objetos apilables (simulación, regla 3): la UI escucha `changed`.
## Una casilla vacía tiene item = null y count = 0.

signal changed

var slots: Array[Dictionary] = []


func _init(size: int) -> void:
	for i: int in size:
		slots.append({"item": null, "count": 0})


## Guarda `count` unidades: primero completa pilas del mismo objeto, después usa
## casillas vacías. Devuelve las que no cupieron.
func add(item: ItemData, count: int = 1) -> int:
	var left: int = count
	for slot: Dictionary in slots:
		if left > 0 and slot.item == item and slot.count < item.max_stack:
			var moved: int = mini(left, item.max_stack - slot.count)
			slot.count += moved
			left -= moved
	for slot: Dictionary in slots:
		if left > 0 and slot.item == null:
			var moved: int = mini(left, item.max_stack)
			slot.item = item
			slot.count = moved
			left -= moved
	if left != count:
		changed.emit()
	return left


## Saca hasta `count` unidades, empezando por las últimas casillas. Devuelve cuántas sacó.
func remove(item: ItemData, count: int = 1) -> int:
	var taken: int = 0
	for i: int in range(slots.size() - 1, -1, -1):
		var slot: Dictionary = slots[i]
		if taken < count and slot.item == item:
			var moved: int = mini(count - taken, slot.count)
			slot.count -= moved
			taken += moved
			if slot.count == 0:
				slot.item = null
	if taken > 0:
		changed.emit()
	return taken


func count_of(item: ItemData) -> int:
	var total: int = 0
	for slot: Dictionary in slots:
		if slot.item == item:
			total += slot.count
	return total


## Mueve la casilla `from` a `to`: si es el mismo objeto apila lo que quepa; si no, intercambia.
func move(from: int, to: int) -> void:
	if from == to:
		return
	var a: Dictionary = slots[from]
	var b: Dictionary = slots[to]
	if a.item != null and a.item == b.item:
		var moved: int = mini(a.count, a.item.max_stack - b.count)
		b.count += moved
		a.count -= moved
		if a.count == 0:
			a.item = null
	else:
		slots[from] = b
		slots[to] = a
	changed.emit()
