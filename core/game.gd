extends Node
## Estado global del juego. Autoload "Game".

## Reloj único del mar (regla 5): CPU y shader leen este valor, nunca Time.
var ocean_time: float = 0.0


func _physics_process(delta: float) -> void:
	ocean_time += delta
