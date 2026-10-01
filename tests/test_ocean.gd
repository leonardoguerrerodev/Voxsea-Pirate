extends Node
## Chequeo de la fase 1. Correr con (ver tests/run.gd):
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_ocean

const SETTLE_FRAMES: int = 600
const SAMPLE_FRAMES: int = 600

var _cube: RigidBody3D
var _waves: WaveSettings
var _frame: int = 0
var _errors: PackedFloat32Array = PackedFloat32Array()


func _ready() -> void:
	_waves = load("res://ocean/default_waves.tres")
	_check_inversion()
	var scene: Node = (load("res://sandbox/sandbox.tscn") as PackedScene).instantiate()
	add_child(scene)
	_cube = scene.get_node("FloatingCube")


## get_wave_height debe devolver la altura del punto desplazado que cae en (x, z).
func _check_inversion() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var worst: float = 0.0
	for _i: int in 1000:
		var rest: Vector2 = Vector2(rng.randf_range(-500.0, 500.0), rng.randf_range(-500.0, 500.0))
		var t: float = rng.randf_range(0.0, 3600.0)
		var d: Vector3 = _waves.get_displacement(rest.x, rest.y, t)
		var h: float = _waves.get_wave_height(rest.x + d.x, rest.y + d.z, t)
		worst = maxf(worst, absf(h - d.y))
	print("inversión: error máximo %.5f m" % worst)
	assert(worst < 0.005, "get_wave_height no coincide con la superficie desplazada")


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame > SETTLE_FRAMES:
		var p: Vector3 = _cube.global_position
		_errors.append(p.y - _waves.get_wave_height(p.x, p.z, Game.ocean_time))
	if _frame < SETTLE_FRAMES + SAMPLE_FRAMES:
		return
	var lo: float = 1e9
	var hi: float = -1e9
	var total: float = 0.0
	for e: float in _errors:
		lo = minf(lo, e)
		hi = maxf(hi, e)
		total += e
	var mean: float = total / _errors.size()
	print("cubo - ola: media %.3f m, rango [%.3f, %.3f] m, deriva xz %s" % [mean, lo, hi, Vector2(_cube.global_position.x, _cube.global_position.z)])
	# Densidad 500 kg/m³: el centro debe quedar cerca de la superficie, sin hundirse
	# ni quedar volando (el cubo mide 1 m, medio lado = 0,5 m).
	var ok: bool = absf(mean) < 0.15 and lo > -0.5 and hi < 0.5
	print("OK" if ok else "FALLA")
	get_tree().quit(0 if ok else 1)
	set_physics_process(false)
