class_name OceanSurface
extends MeshInstance3D
## Presentación del mar: malla que sigue a la cámara con el shader de Gerstner.
## Solo lee WaveSettings y Game.ocean_time; la simulación no la conoce (regla 3).

@export var settings: WaveSettings

var _material: ShaderMaterial
var _spacing: float = 1.0


func _ready() -> void:
	_material = material_override as ShaderMaterial
	var plane: PlaneMesh = mesh as PlaneMesh
	_spacing = plane.size.x / (plane.subdivide_width + 1)


func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		# Avanza de a un vértice para que la malla no "nade" sobre las olas.
		global_position = Vector3(snappedf(camera.global_position.x, _spacing), 0.0, snappedf(camera.global_position.z, _spacing))
	# ponytail: se envía cada frame (8 ondas, costo nulo); así los cambios en vivo
	# del inspector llegan sin señales.
	_material.set_shader_parameter("waves", settings.to_shader_array())
	_material.set_shader_parameter("wave_count", mini(settings.waves.size(), WaveSettings.MAX_WAVES))
	# ponytail: el reloj avanza a 60 Hz (física); en pantallas de más Hz las olas
	# saltan levemente. Si se nota, interpolar con Engine.get_physics_interpolation_fraction().
	_material.set_shader_parameter("ocean_time", Game.ocean_time)
