extends Node
## Viento global (autoload "Wind"). Determinista: sale del reloj del mar, así es el
## mismo en todas las máquinas del coop sin sincronizar nada.

## Hacia dónde sopla (0° = +X, 90° = +Z, igual que las olas).
@export_range(-180.0, 180.0, 1.0, "suffix:°") var direction: float = 0.0
@export_range(0.0, 30.0, 0.1, "suffix:m/s") var speed: float = 9.0
## 0 = constante; 1 = gira despacio unos ±30° y la fuerza varía ±25 %.
@export_range(0.0, 1.0, 0.05) var variability: float = 1.0
## Multiplica la fuerza (la fija el clima: tormenta = más viento).
var weather_scale: float = 1.0


## Velocidad del viento (horizontal) en el tiempo t del mar.
func velocity_at(t: float) -> Vector3:
	var angle: float = deg_to_rad(direction) + variability * (0.4 * sin(t / 97.0) + 0.15 * sin(t / 41.0 + 1.3))
	var strength: float = speed * weather_scale * (1.0 + variability * 0.25 * sin(t / 53.0 + 0.7))
	return Vector3(cos(angle), 0.0, sin(angle)) * strength
