extends Node
## Chequeo del clima: la tormenta sube viento y olas, la escala de olas llega igual
## a la CPU y al shader (regla 1), la transición es gradual y el ciclo automático
## es determinista.
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_weather

var _failed: bool = false
var _frame: int = 0


func _expect(ok: bool, what: String) -> void:
	print("  ", "ok    " if ok else "FALLA ", what)
	if not ok:
		_failed = true


func _ready() -> void:
	# Regla 1: la escala de olas la ven igual la CPU y el shader.
	var single: WaveSettings = WaveSettings.new()
	var wave: Wave = Wave.new()
	wave.amplitude = 1.0
	wave.wavelength = 40.0
	wave.steepness = 0.0
	single.waves.append(wave)
	single.amplitude_scale = 2.0
	var peak: float = single.get_displacement(10.0, 0.0, 0.0).y  # cresta: sin(k·10) = 1
	_expect(is_equal_approx(peak, 2.0), "CPU: amplitud 1 × escala 2 = %.3f" % peak)
	_expect(is_equal_approx(single.to_shader_array()[0].y, 2.0), "shader recibe la amplitud escalada")

	var seen: Array[int] = [0, 0, 0, 0]
	for period: int in 1000:
		seen[Weather.state_at(period * Weather.period_minutes * 60.0)] += 1
	_expect(Weather.state_at(12345.0) == Weather.state_at(12345.0), "ciclo automático determinista")
	_expect(seen[Weather.State.CLEAR] > seen[Weather.State.STORM] * 2 and seen[Weather.State.STORM] > 0, "despejado es común y la tormenta rara: %s" % [seen])

	Weather.auto_cycle = false
	Weather.target = Weather.State.CLEAR
	Weather.apply_now()
	Weather.transition_seconds = 10.0
	Weather.target = Weather.State.STORM


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame == 60 * 5:
		var wind: float = Weather.current["wind"]
		_expect(wind > 0.9 and wind < 1.9, "a mitad de la transición el viento va entre despejado y tormenta (%.2f)" % wind)
	if _frame == 60 * 12:
		_expect(is_equal_approx(Wind.weather_scale, 2.0), "en tormenta el viento sopla ×2 (%.2f)" % Wind.weather_scale)
		_expect(is_equal_approx(Weather.waves.amplitude_scale, 2.0), "en tormenta las olas son ×2 (%.2f)" % Weather.waves.amplitude_scale)
		print("FALLA" if _failed else "OK")
		get_tree().quit(1 if _failed else 0)
		set_physics_process(false)
