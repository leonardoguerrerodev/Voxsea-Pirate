extends Node
## Estado global del juego. Autoload "Game".

## Reloj único del mar (regla 5): CPU y shader leen este valor, nunca Time.
var ocean_time: float = 0.0
## Hora del día (0–24). Avanza con la física, como el reloj del mar; en coop la
## manda el host.
var hour: float = 9.0
## Minutos reales que dura un día completo.
var day_minutes: float = 20.0
## Detiene el ciclo (para el menú dev).
var day_paused: bool = false


func _physics_process(delta: float) -> void:
	ocean_time += delta
	if not day_paused:
		hour = fposmod(hour + delta * 24.0 / (day_minutes * 60.0), 24.0)


## "09:30" para mostrar.
func clock() -> String:
	return "%02d:%02d" % [int(hour), int(fmod(hour, 1.0) * 60.0)]
