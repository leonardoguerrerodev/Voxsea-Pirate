class_name Wave
extends Resource
## Una onda de Gerstner. La CPU y el shader leen estos mismos valores.

## Dirección de avance (0° = +X, 90° = +Z).
@export_range(-180.0, 180.0, 1.0, "suffix:°") var direction: float = 0.0
## Altura de la cresta sobre el nivel medio.
@export_range(0.0, 5.0, 0.01, "suffix:m") var amplitude: float = 0.2
## Distancia entre crestas. Menos de ~4 m se ve mal con la malla de 1 m.
@export_range(1.0, 500.0, 0.1, "suffix:m") var wavelength: float = 20.0
## 0 = ola redonda; 1 = cresta en punta (máximo sin que la malla haga bucles).
@export_range(0.0, 1.0, 0.01) var steepness: float = 0.5
