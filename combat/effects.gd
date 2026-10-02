class_name Effects
extends RefCounted
## Efectos de un solo uso (presentación): estallido de partículas que se borra solo.
# ponytail: esferitas sin textura; humo y espuma con sprites cuando haya arte.


## Estallido hacia arriba (salpicadura, astillas, humo), `speed` en m/s.
static func burst(color: Color, speed: float, amount: int = 40) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	sphere.material = material
	particles.mesh = sphere
	particles.amount = amount
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.lifetime = 1.6
	particles.direction = Vector3.UP
	particles.spread = 30.0
	particles.initial_velocity_min = speed * 0.5
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.4
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles
