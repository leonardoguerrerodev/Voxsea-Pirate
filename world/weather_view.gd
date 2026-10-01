extends Node
## Presentación del cielo y el clima. Le pasa a Sky3D la hora del juego
## (Game.hour, el reloj que manda) y el viento, y según Weather.current cambia
## nubes, niebla y luz, y hace llover con partículas que siguen a la cámara y
## chocan con lo que tengan encima (no llueve dentro de la bodega).

@export var sky: Sky3D

## Niebla de Sky3D sin clima; el clima la multiplica.
const BASE_FOG: float = 0.0007
const RAIN_AMOUNT: int = 4000
const RAIN_AREA: float = 40.0

var _rain: GPUParticles3D
var _rain_shelter: GPUParticlesCollisionHeightField3D
var _base_sun: float
var _base_dome: float


func _ready() -> void:
	_base_sun = sky.sun_energy
	_base_dome = sky.skydome_energy
	_rain = GPUParticles3D.new()
	_rain.amount = RAIN_AMOUNT
	_rain.lifetime = 1.2
	_rain.visibility_aabb = AABB(Vector3(-RAIN_AREA, -30, -RAIN_AREA), Vector3(RAIN_AREA * 2, 50, RAIN_AREA * 2))
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RAIN_AREA * 0.5, 0.5, RAIN_AREA * 0.5)
	process.direction = Vector3.DOWN
	process.spread = 2.0
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 22.0
	process.gravity = Vector3(0, -9.8, 0)
	process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	_rain.process_material = process
	var drop: QuadMesh = QuadMesh.new()
	drop.size = Vector2(0.015, 0.5)
	var look: StandardMaterial3D = StandardMaterial3D.new()
	look.albedo_color = Color(0.75, 0.8, 0.9, 0.35)
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	drop.material = look
	_rain.draw_pass_1 = drop
	_rain.emitting = false
	add_child(_rain)
	# "Techo" para la lluvia: mira desde arriba lo que hay bajo ella.
	_rain_shelter = GPUParticlesCollisionHeightField3D.new()
	_rain_shelter.size = Vector3(RAIN_AREA, 40, RAIN_AREA)
	_rain_shelter.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	_rain_shelter.follow_camera_enabled = true
	add_child(_rain_shelter)


func _process(_delta: float) -> void:
	sky.current_time = Game.hour
	var wind: Vector3 = Wind.velocity_at(Game.ocean_time)
	sky.wind_speed = wind.length()
	sky.wind_direction = atan2(wind.z, wind.x)
	var w: Dictionary = Weather.current
	var dome: SkyDome = sky.sky
	if dome:
		dome.cumulus_coverage = lerpf(0.3, 0.95, w["clouds"])
		dome.cirrus_coverage = lerpf(0.3, 0.9, w["clouds"])
		dome.fog_density = BASE_FOG * (1.0 + w["fog"] * 25.0)
	sky.sun_energy = _base_sun * (1.0 - w["dark"] * 0.8)
	sky.skydome_energy = _base_dome * (1.0 - w["dark"] * 0.6)
	var camera: Camera3D = get_viewport().get_camera_3d()
	_rain.emitting = w["rain"] > 0.02 and camera != null
	if camera:
		_rain.global_position = camera.global_position + Vector3.UP * 15.0
	_rain.amount_ratio = w["rain"]
