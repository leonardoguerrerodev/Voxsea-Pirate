class_name ShipPart
extends Node3D
## Pieza del barco: vela, timón, ancla o carga (NONE: un prop con masa). Va como
## hijo del ShipBody; su posición es la base, apoyada en la cubierta. Su masa
## suma a la del barco y mueve el centro de gravedad. ShipPartsView la dibuja.

enum Kind { NONE, SAIL, HELM, ANCHOR }

@export var kind: Kind = Kind.NONE
@export_range(0.0, 50000.0, 1.0, "suffix:kg") var mass: float = 0.0
## Solo velas: superficie de lona y alto del mástil.
@export_range(0.0, 400.0, 1.0, "suffix:m²") var sail_area: float = 0.0
@export_range(0.0, 30.0, 0.5, "suffix:m") var mast_height: float = 0.0
