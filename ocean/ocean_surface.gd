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
	# Los parámetros que nadie asignó leen null: se copian los valores por defecto
	# del shader para que el menú dev pueda mostrarlos y moverlos.
	var shader: Shader = _material.shader
	for uniform: Dictionary in shader.get_shader_uniform_list():
		if _material.get_shader_parameter(uniform.name) == null:
			var value: Variant = RenderingServer.shader_get_parameter_default(shader.get_rid(), uniform.name)
			if value != null:
				_material.set_shader_parameter(uniform.name, value)
	# Detalle fino del agua: mapas de normales de ruido, repetibles, sin archivos.
	var horizon: MeshInstance3D = get_node_or_null("Horizon") as MeshInstance3D
	for slot: String in ["detail_normal_a", "detail_normal_b"]:
		var texture: NoiseTexture2D = _detail_normals(1 if slot.ends_with("a") else 7)
		_material.set_shader_parameter(slot, texture)
		if horizon:
			(horizon.material_override as ShaderMaterial).set_shader_parameter(slot, texture)


static func _detail_normals(seed: int) -> NoiseTexture2D:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	var texture: NoiseTexture2D = NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 6.0
	texture.noise = noise
	return texture


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
