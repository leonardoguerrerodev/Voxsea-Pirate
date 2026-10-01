extends Node
## Clima (autoload "Weather", simulación). Pasa suave entre estados y mueve el
## viento y la altura de las olas; la presentación (WeatherView) lee `current`.
## El ciclo automático es determinista (semilla + reloj del mar): igual en todas
## las máquinas del coop.

enum State { CLEAR, CLOUDY, RAIN, STORM }

const NAMES: PackedStringArray = ["Despejado", "Nublado", "Lluvia", "Tormenta"]
## Por estado: nubes, lluvia, niebla, oscuridad, viento (×), olas (×).
const PROFILES: Array[Dictionary] = [
	{"clouds": 0.15, "rain": 0.0, "fog": 0.0, "dark": 0.0, "wind": 0.8, "waves": 0.8},
	{"clouds": 0.6, "rain": 0.0, "fog": 0.15, "dark": 0.25, "wind": 1.0, "waves": 1.0},
	{"clouds": 0.85, "rain": 0.6, "fog": 0.45, "dark": 0.5, "wind": 1.3, "waves": 1.3},
	{"clouds": 1.0, "rain": 1.0, "fog": 0.7, "dark": 0.75, "wind": 2.0, "waves": 2.0},
]
## Probabilidad de cada estado en el ciclo automático.
const WEIGHTS: PackedFloat32Array = [0.4, 0.3, 0.2, 0.1]

## Ondas que escala (el mismo recurso que usan el mar y los barcos).
@export var waves: WaveSettings = preload("res://ocean/default_waves.tres")
## Cambia de estado solo cada `period_minutes`.
@export var auto_cycle: bool = true
@export_range(0.5, 60.0, 0.5) var period_minutes: float = 6.0
## Segundos que tarda en pasar de un estado a otro.
@export_range(1.0, 300.0, 1.0) var transition_seconds: float = 45.0
@export var seed_value: int = 7
## Multiplicadores sobre lo que pide el clima (menú dev).
@export_range(0.0, 3.0, 0.05) var wave_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.05) var wind_multiplier: float = 1.0

## Estado hacia el que va (con auto_cycle lo elige el ciclo; si no, el menú dev).
var target: State = State.CLEAR
## Valores actuales, mezclados entre estados (claves de PROFILES).
var current: Dictionary = PROFILES[State.CLEAR].duplicate()


func _physics_process(delta: float) -> void:
	if auto_cycle:
		target = state_at(Game.ocean_time)
	var goal: Dictionary = PROFILES[target]
	var step: float = delta / transition_seconds
	for key: String in current:
		current[key] = move_toward(current[key], goal[key], step * maxf(absf(goal[key] - PROFILES[State.CLEAR][key]), 0.2))
	Wind.weather_scale = current["wind"] * wind_multiplier
	waves.amplitude_scale = current["waves"] * wave_multiplier


## Salta al estado pedido sin transición (menú dev).
func apply_now() -> void:
	current = PROFILES[target].duplicate()


## Estado del ciclo automático en el tiempo t del mar (determinista).
func state_at(t: float) -> State:
	var period: int = int(t / (period_minutes * 60.0))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([seed_value, period])
	return rng.rand_weighted(WEIGHTS) as State
