class_name WaveSettings
extends Resource
## Fuente única de la forma del mar (regla 1). Gerstner según GPU Gems, cap. 1.
## ocean.gdshader implementa la misma fórmula: si cambias una, cambia la otra.

const MAX_WAVES: int = 8
const GRAVITY: float = 9.81
## Iteraciones para invertir el desplazamiento horizontal en get_wave_height.
const INVERT_STEPS: int = 4

@export var waves: Array[Wave] = []


## Desplazamiento del punto de reposo (x, z) en el tiempo t.
func get_displacement(x: float, z: float, t: float) -> Vector3:
	var result: Vector3 = Vector3.ZERO
	var count: int = mini(waves.size(), MAX_WAVES)
	for i: int in count:
		var wave: Wave = waves[i]
		if wave == null:
			continue
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(wave.direction))
		var k: float = TAU / wave.wavelength
		var speed: float = sqrt(GRAVITY / k)
		var phase: float = k * (dir.x * x + dir.y * z - speed * t)
		var horizontal: float = wave.steepness / (k * count)
		result.x += dir.x * horizontal * cos(phase)
		result.y += wave.amplitude * sin(phase)
		result.z += dir.y * horizontal * cos(phase)
	return result


## Altura del mar en la posición de mundo (x, z). Gerstner mueve los puntos en
## horizontal, así que primero se busca qué punto de reposo termina en (x, z).
func get_wave_height(x: float, z: float, t: float) -> float:
	var px: float = x
	var pz: float = z
	for _i: int in INVERT_STEPS:
		var d: Vector3 = get_displacement(px, pz, t)
		px = x - d.x
		pz = z - d.z
	return get_displacement(px, pz, t).y


## Parámetros para el shader: (dirección en radianes, amplitud, longitud, empinamiento).
func to_shader_array() -> PackedVector4Array:
	var result: PackedVector4Array = PackedVector4Array()
	result.resize(MAX_WAVES)
	for i: int in mini(waves.size(), MAX_WAVES):
		var wave: Wave = waves[i]
		# Una onda vacía queda en amplitud 0: no aporta, igual que en la CPU.
		result[i] = Vector4(deg_to_rad(wave.direction), wave.amplitude, wave.wavelength, wave.steepness) if wave else Vector4(0.0, 0.0, 1.0, 0.0)
	return result
