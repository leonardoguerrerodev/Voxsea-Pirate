class_name BuildHistory
extends RefCounted
## Deshacer y rehacer ediciones del barco. Guarda los comandos inversos que
## devuelve ShipEditor.apply().

var _undo: Array[ShipEditCommand] = []
var _redo: Array[ShipEditCommand] = []


## Aplica un comando nuevo; borra lo que se podía rehacer.
func apply(data: ShipData, command: ShipEditCommand) -> void:
	var inverse: ShipEditCommand = ShipEditor.apply(data, command)
	if inverse.is_empty():
		return
	_undo.append(inverse)
	_redo.clear()


func undo(data: ShipData) -> bool:
	if _undo.is_empty():
		return false
	_redo.append(ShipEditor.apply(data, _undo.pop_back()))
	return true


func redo(data: ShipData) -> bool:
	if _redo.is_empty():
		return false
	_undo.append(ShipEditor.apply(data, _redo.pop_back()))
	return true
