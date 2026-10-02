class_name ItemData
extends Resource
## Un tipo de objeto del inventario. Los objetos viven en items/data/*.tres.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
## Cuántos caben en una casilla.
@export_range(1, 999, 1) var max_stack: int = 1
## Modelo para ponerlo en el barco (decoración) o verlo en la mano. Puede faltar.
@export var prop: PackedScene
## Masa al colocarlo en el barco: suma al barco y mueve su centro de gravedad.
@export_range(0.0, 5000.0, 0.5, "suffix:kg") var mass: float = 1.0
## Qué pieza del barco es al colocarlo (timón: se toma con E). NONE = carga.
@export var part_kind: ShipPart.Kind = ShipPart.Kind.NONE
