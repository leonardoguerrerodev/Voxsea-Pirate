class_name HoldInterior
extends AnimatableBody3D
## Bodega jugable (presentación + colisión): piso plano generado desde el aire
## interior del casco (HullProfile), una escala de palos bajo la escotilla (solo se
## ve: se baja y se sube con E, HatchControl) y una tapa invisible sobre la rejilla
## para no caer entre los barrotes. Cinemática, hija del barco, como HullCollision
## (regla 8). Un farol la ilumina; de día entra luz por la rejilla.

const VOXEL: float = HullProfile.VOXEL_SIZE

## Alto del piso sobre la quilla (m): borde de una capa de voxels.
@export var floor_height: float = 1.5
## Escotilla en metros del barco: x y z mínimos y máximos, y alto de la cubierta.
@export var hatch_min: Vector2 = Vector2(4.0, 10.2)
@export var hatch_max: Vector2 = Vector2(6.5, 12.7)
@export var deck_height: float = 5.49
## Escala de palos: dos largueros y peldaños redondos, contra el borde de popa de
## la escotilla.
@export var ladder_width: float = 0.6
@export var rung_spacing: float = 0.35
@export var floor_material: Material
@export var stair_material: Material


func _ready() -> void:
	sync_to_physics = false
	var ship: ShipBody = get_parent() as ShipBody
	_build_floor(ship.profile)
	_build_ladder()
	_build_lid()
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


## Pie de la escala (en el piso, ejes del barco): ahí deja HatchControl al bajar.
func ladder_foot() -> Vector3:
	return Vector3((hatch_min.x + hatch_max.x) * 0.5, floor_height, hatch_max.y - 0.25)


## Dos largueros del piso a la cubierta y peldaños cada `rung_spacing`.
func _build_ladder() -> void:
	var foot: Vector3 = ladder_foot()
	var height: float = deck_height - floor_height
	for side: float in [-0.5, 0.5]:
		var rail: CylinderMesh = CylinderMesh.new()
		rail.top_radius = 0.045
		rail.bottom_radius = 0.05
		rail.height = height
		_add_mesh(rail, foot + Vector3(side * ladder_width, height * 0.5, 0.0), Vector3.ZERO)
	var y: float = 0.3
	while y < height - 0.1:
		var rung: CylinderMesh = CylinderMesh.new()
		rung.top_radius = 0.03
		rung.bottom_radius = 0.03
		rung.height = ladder_width + 0.16
		_add_mesh(rung, foot + Vector3(0.0, y, -0.04), Vector3(0.0, 0.0, PI / 2.0))
		y += rung_spacing


func _add_mesh(mesh: Mesh, at: Vector3, rotation_euler: Vector3) -> void:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = stair_material
	instance.position = at
	instance.rotation = rotation_euler
	add_child(instance)


## Tapa invisible bajo el tope de los barrotes: la rejilla se pisa sin caer por sus huecos.
func _build_lid() -> void:
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(hatch_max.x - hatch_min.x, 0.1, hatch_max.y - hatch_min.y)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = box
	collision.position = Vector3((hatch_min.x + hatch_max.x) * 0.5, deck_height - 0.2, (hatch_min.y + hatch_max.y) * 0.5)
	add_child(collision)
