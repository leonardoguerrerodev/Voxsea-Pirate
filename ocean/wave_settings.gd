class_name WaveSettings
extends Resource
## Fuente única de la forma del mar (regla 1). Gerstner según GPU Gems, cap. 1.
## ocean.gdshader implementa la misma fórmula: si cambias una, cambia la otra.

const MAX_WAVES: int = 8
const GRAVITY: float = 9.81
## Iteraciones para invertir el desplazamiento horizontal en get_wave_height.
const INVERT_STEPS: int = 4
## Floats por onda en _constants(): dir.x, dir.z, k, velocidad, amplitud, horizontal.
const STRIDE: int = 6

@export var waves: Array[Wave] = []


## Desplazamiento del punto de reposo (x, z) en el tiempo t.
func get_displacement(x: float, z: float, t: float) -> Vector3:
	return _displace(_constants(), x, z, t)


## Altura del mar en la posición de mundo (x, z).
func get_wave_height(x: float, z: float, t: float) -> float:
	return _height(_constants(), x, z, t)


## Altura del mar en muchos puntos (x, z) de mundo: calcula las constantes de las
## ondas una sola vez.
func sample_heights(points: PackedVector2Array, t: float) -> PackedFloat32Array:
	var c: PackedFloat32Array = _constants()
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(points.size())
	for i: int in points.size():
		result[i] = _height(c, points[i].x, points[i].y, t)
	return result


## Parámetros para el shader: (dirección en radianes, amplitud, longitud, empinamiento).
func to_shader_array() -> PackedVector4Array:
	var result: PackedVector4Array = PackedVector4Array()
	result.resize(MAX_WAVES)
	for i: int in mini(waves.size(), MAX_WAVES):
		var wave: Wave = waves[i]
		# Una onda vacía queda en amplitud 0: no aporta, igual que en la CPU.
		result[i] = Vector4(deg_to_rad(wave.direction), wave.amplitude, wave.wavelength, wave.steepness) if wave else Vector4(0.0, 0.0, 1.0, 0.0)
	return result


## Gerstner mueve los puntos en horizontal: primero se busca qué punto de reposo
## termina en (x, z) y se devuelve su altura.
func _height(c: PackedFloat32Array, x: float, z: float, t: float) -> float:
	var px: float = x
	var pz: float = z
	for _i: int in INVERT_STEPS:
		var d: Vector3 = _displace(c, px, pz, t)
		px = x - d.x
		pz = z - d.z
	return _displace(c, px, pz, t).y


func _displace(c: PackedFloat32Array, x: float, z: float, t: float) -> Vector3:
	var result: Vector3 = Vector3.ZERO
	for i: int in range(0, c.size(), STRIDE):
		var phase: float = c[i + 2] * (c[i] * x + c[i + 1] * z - c[i + 3] * t)
		var cosine: float = cos(phase)
		result.x += c[i] * c[i + 5] * cosine
		result.y += c[i + 4] * sin(phase)
		result.z += c[i + 1] * c[i + 5] * cosine
	return result


func _constants() -> PackedFloat32Array:
	var c: PackedFloat32Array = PackedFloat32Array()
	var count: int = mini(waves.size(), MAX_WAVES)
	for i: int in count:
		var wave: Wave = waves[i]
		if wave == null:
			continue
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(wave.direction))
		var k: float = TAU / wave.wavelength
		# El desplazamiento horizontal se divide por todas las ondas (count), igual
		# que en el shader, aunque alguna esté vacía.
		c.append_array([dir.x, dir.y, k, sqrt(GRAVITY / k), wave.amplitude, wave.steepness / (k * count)])
	return c
