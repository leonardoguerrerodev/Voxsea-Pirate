class_name MapCoords
extends RefCounted
## Coordenadas de mapa, única fuente de la conversión mundo ↔ mapa (para el mapa,
## las zonas y los marcadores futuros). En metros:
##   X = este  (+x del mundo)
##   Y = norte (-z del mundo, el "adelante" de Godot; en un mapa queda arriba)
## Rumbos en grados desde el norte, en sentido horario (0 = N, 90 = E).

const POINTS: PackedStringArray = ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]


static func from_world(position: Vector3) -> Vector2:
	return Vector2(position.x, -position.z)


static func to_world(coords: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(coords.x, height, -coords.y)


## Rumbo de una dirección del mundo (se ignora la altura).
static func heading(direction: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(direction.x, -direction.z)), 360.0)


## Punto de la rosa de 8 vientos más cercano a un rumbo.
static func compass(degrees: float) -> String:
	return POINTS[roundi(fposmod(degrees, 360.0) / 45.0) % 8]


## "X 120 · Y -45" para mostrar.
static func format(position: Vector3) -> String:
	var coords: Vector2 = from_world(position)
	return "X %d · Y %d" % [roundi(coords.x), roundi(coords.y)]
