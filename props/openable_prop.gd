class_name OpenableProp
extends Node3D
## Prop de dos piezas que vinieron separadas de Tripo: una base fija y una pieza
## móvil (tapa, puerta) que se abre girando en una bisagra o levantándose. `toggle()`
## la abre o la cierra con una animación corta; `open` fija el estado sin animar.

## Base fija (cofre, caldero, estufa).
@export var base: PackedScene
## Pieza que se mueve (tapa, puerta) o se monta fija (llave del barril).
@export var part: PackedScene
## Dónde va el origen de la pieza cerrada (su base), relativo al origen del prop.
@export var part_offset: Vector3 = Vector3.ZERO
## Punto y eje de la bisagra, relativos al origen del prop.
@export var hinge: Vector3 = Vector3.ZERO
@export var hinge_axis: Vector3 = Vector3.RIGHT
## Giro al abrir (grados; el signo decide hacia dónde) y cuánto se levanta (m).
@export_range(-180.0, 180.0, 1.0) var open_angle: float = 0.0
@export_range(0.0, 1.0, 0.01) var open_lift: float = 0.0
## Sin bisagra (llave del barril): la pieza solo se monta.
@export var movable: bool = true
@export var open: bool = false:
	set(value):
		open = value
		if _pivot:
			_pivot.transform = _pose(1.0 if open else 0.0)

var _pivot: Node3D
var _tween: Tween


func _ready() -> void:
	add_child(base.instantiate())
	_pivot = Node3D.new()
	add_child(_pivot)
	var piece: Node3D = part.instantiate()
	piece.position = part_offset - hinge
	_pivot.add_child(piece)
	_pivot.transform = _pose(1.0 if open else 0.0)


## Abre o cierra con animación. Devuelve false si la pieza no se mueve.
func toggle() -> bool:
	if not movable:
		return false
	open = not open
	if _tween:
		_tween.kill()
	_pivot.transform = _pose(0.0 if open else 1.0)
	_tween = create_tween().set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(func(t: float) -> void: _pivot.transform = _pose(t), 0.0 if open else 1.0, 1.0 if open else 0.0, 0.45)
	return true


## Pose de la pieza: 0 = cerrada, 1 = abierta.
func _pose(t: float) -> Transform3D:
	var rotation_basis: Basis = Basis(hinge_axis.normalized(), deg_to_rad(open_angle * t)) if movable else Basis.IDENTITY
	return Transform3D(rotation_basis, hinge + Vector3.UP * open_lift * t)
