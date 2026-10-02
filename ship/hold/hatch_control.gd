class_name HatchControl
extends Node
## Bajar a la bodega y subir (E): mirando la rejilla de cerca desde la cubierta, o
## junto a la escala desde abajo. Fundido a negro corto y el jugador aparece al pie
## de la escala o en la cubierta junto a la escotilla (es hijo del barco: se mueve
## en ejes del barco).

## Distancia horizontal máxima al centro de la rejilla o a la escala (m).
const REACH: float = 1.6
## Cuánto debe mirar la cámara hacia la rejilla (coseno).
const FACING: float = 0.5
const FADE: float = 0.25

@export var player: Player
@export var hold: HoldInterior
@export var helm: Node

var _hud: Label
var _black: ColorRect
var _busy: bool = false


func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 10
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.modulate.a = 0.0
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_black)
	_hud = Label.new()
	_hud.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hud.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hud.offset_top = -160
	_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud.add_theme_font_size_override("font_size", 24)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if _busy or not event.is_action_pressed("interact") or (helm and helm.get("at_helm")):
		return
	var place: int = _place()
	if place != 0:
		get_viewport().set_input_as_handled()
		_fade_to(place < 0)


func _process(_delta: float) -> void:
	var place: int = _place()
	_hud.text = "" if _busy or place == 0 else ("E: bajar a la bodega" if place < 0 else "E: subir a cubierta")


## -1 = en cubierta mirando la rejilla, 1 = en la bodega junto a la escala, 0 = nada.
func _place() -> int:
	var p: Vector3 = player.position
	var center: Vector3 = Vector3((hold.hatch_min.x + hold.hatch_max.x) * 0.5, hold.deck_height, (hold.hatch_min.y + hold.hatch_max.y) * 0.5)
	if p.y > hold.deck_height - 0.5:
		var look: Vector3 = -player.CAMERA.global_basis.z
		var to_hatch: Vector3 = ((player.get_parent() as Node3D).to_global(center) - player.CAMERA.global_position).normalized()
		if Vector2(p.x - center.x, p.z - center.z).length() < REACH and look.dot(to_hatch) > FACING:
			return -1
		return 0
	var foot: Vector3 = hold.ladder_foot()
	return 1 if Vector2(p.x - foot.x, p.z - foot.z).length() < REACH else 0


func _fade_to(down: bool) -> void:
	_busy = true
	var tween: Tween = create_tween()
	tween.tween_property(_black, "modulate:a", 1.0, FADE)
	tween.tween_callback(teleport.bind(down))
	tween.tween_property(_black, "modulate:a", 0.0, FADE)
	tween.tween_callback(func() -> void: _busy = false)


## Abajo: al pie de la escala, mirando a proa. Arriba: en la cubierta, a popa de la escotilla.
func teleport(down: bool) -> void:
	var foot: Vector3 = hold.ladder_foot()
	if down:
		player.position = foot + Vector3(0.0, 0.05, -0.6)
	else:
		player.position = Vector3(foot.x, hold.deck_height + 0.4, hold.hatch_max.y + 0.7)
	player.velocity = Vector3.ZERO
