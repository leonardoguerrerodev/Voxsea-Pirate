class_name Lantern
extends Node3D
## Farol colocable (presentación): cuerpo, globo de vidrio translúcido, asa y una
## vela de cera adentro. `open` = encendido (se llama así para compartir el
## guardado y el toggle() de los props abribles); E lo prende y lo apaga.

@export var open: bool = true:
	set(value):
		open = value
		if is_node_ready():
			_apply()
## Brillo de la luz encendida; parpadea un poco alrededor de esto.
@export_range(0.0, 8.0, 0.1) var light_energy: float = 1.6
## Opacidad del vidrio (0 = invisible, 1 = opaco).
@export_range(0.0, 1.0, 0.01) var glass_alpha: float = 0.3

var _glass: StandardMaterial3D

@onready var _light: OmniLight3D = $Luz
@onready var _flame: GeometryInstance3D = $Llama


func _ready() -> void:
	# El globo trae su textura (ámbar con una llama pintada): se vuelve vidrio.
	for node: Node in $Globo.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		var source: BaseMaterial3D = instance.mesh.surface_get_material(0) as BaseMaterial3D
		_glass = source.duplicate() if source else StandardMaterial3D.new()
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.albedo_color.a = glass_alpha
		_glass.roughness = 0.05
		_glass.metallic = 0.0
		_glass.emission = Color(1.0, 0.6, 0.25)
		instance.material_override = _glass
		# El vidrio no tapa la luz de la vela (los barrotes sí dan sombra).
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_apply()


## Prende o apaga. Siempre se puede (como un prop abrible).
func toggle() -> bool:
	open = not open
	return true


func _apply() -> void:
	_light.visible = open
	_flame.visible = open
	if _glass:
		_glass.emission_enabled = open
		_glass.emission_energy_multiplier = 0.6


func _process(_delta: float) -> void:
	if open:
		var t: float = Time.get_ticks_msec() * 0.001
		_light.light_energy = light_energy * (0.88 + 0.08 * sin(t * 13.0) + 0.04 * sin(t * 37.0 + 0.7))
