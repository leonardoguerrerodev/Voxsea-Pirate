class_name HoldInterior
extends AnimatableBody3D
## Bodega jugable (presentación + colisión): piso plano generado desde el aire
## interior del casco (HullProfile) y escalera de la escotilla al piso. Cinemática,
## hija del barco, como HullCollision (regla 8). Un farol la ilumina.

const VOXEL: float = HullProfile.VOXEL_SIZE

## Alto del piso sobre la quilla (m): borde de una capa de voxels.
@export var floor_height: float = 1.5
## Escotilla en metros del barco: x y z mínimos y máximos, y alto de la cubierta.
@export var hatch_min: Vector2 = Vector2(4.0, 10.2)
@export var hatch_max: Vector2 = Vector2(6.5, 12.7)
@export var deck_height: float = 5.49
## Escalera: baja hacia proa (-z) desde el borde de popa de la escotilla. Empinada,
## como las de barco: tendida, la cabeza choca con la cubierta antes de pasar.
@export var stair_width: float = 1.2
@export var stair_rise: float = 0.35
@export var stair_run: float = 0.22
@export var floor_material: Material
@export var stair_material: Material


func _ready() -> void:
	sync_to_physics = false
	var ship: ShipBody = get_parent() as ShipBody
	_build_floor(ship.profile)
	_build_stairs()
	var lantern: OmniLight3D = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.72, 0.4)
	lantern.light_energy = 2.0
	lantern.omni_range = 9.0
	lantern.shadow_enabled = true
	lantern.position = Vector3((hatch_min.x + hatch_max.x) * 0.5, deck_height - 0.6, hatch_min.y - 3.0)
	add_child(lantern)


## Una cara por cada voxel de la capa del piso que es aire interior, más los de
## casco vecinos (el piso entra bajo las tablas y no deja rendijas).
func _build_floor(profile: HullProfile) -> void:
	var size: Vector3i = profile.size
	var layer: int = int(round(floor_height / VOXEL))
	var faces: PackedVector3Array = PackedVector3Array()
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in size.z:
		for x: int in size.x:
			if not _floor_cell(profile, x, layer, z):
				continue
			var a: Vector3 = Vector3(x, layer, z) * VOXEL
			var quad: PackedVector3Array = [a, a + Vector3(VOXEL, 0, 0), a + Vector3(VOXEL, 0, VOXEL), a, a + Vector3(VOXEL, 0, VOXEL), a + Vector3(0, 0, VOXEL)]
			for v: Vector3 in quad:
				st.set_uv(Vector2(v.x, v.z) / 1.5)
				st.set_normal(Vector3.UP)
				st.add_vertex(v)
			faces.append_array([quad[0], quad[2], quad[1], quad[3], quad[5], quad[4]])
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = floor_material
	add_child(mesh)
	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	# Un piso se pisa desde arriba; así no importa el sentido de los triángulos.
	shape.backface_collision = true
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)


func _floor_cell(profile: HullProfile, x: int, y: int, z: int) -> bool:
	if _interior(profile, x, y, z):
		return true
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _interior(profile, x + d.x, y, z + d.y):
			return true
	return false


func _interior(profile: HullProfile, x: int, y: int, z: int) -> bool:
	var s: Vector3i = profile.size
	if x < 0 or y < 0 or z < 0 or x >= s.x or y >= s.y or z >= s.z:
		return false
	return profile.interior[y + x * s.y + z * s.y * s.x] == 1


## Peldaños macizos desde el piso hasta su tope, del borde de popa de la escotilla hacia proa.
func _build_stairs() -> void:
	var steps: int = int(round((deck_height - floor_height) / stair_rise))
	var center_x: float = (hatch_min.x + hatch_max.x) * 0.5
	var start_z: float = hatch_max.y - 0.1
	for i: int in range(1, steps):
		var top: float = deck_height - i * stair_rise
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(stair_width, top - floor_height, stair_run)
		var position_i: Vector3 = Vector3(center_x, (top + floor_height) * 0.5, start_z - (i - 0.5) * stair_run)
		var step: MeshInstance3D = MeshInstance3D.new()
		step.mesh = box
		step.material_override = stair_material
		step.position = position_i
		add_child(step)
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = box.size
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		collision.position = position_i
		add_child(collision)
