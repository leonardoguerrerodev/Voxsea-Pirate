extends Node
## Íconos del inventario desde los props 3D: uno por .glb de assets/props y por
## escena armada de props/ (cofre con tapa, estufa con puerta), en 3/4
## y fondo transparente, a assets/icons/<prop>.png. Necesita render real (sin --headless):
## ../Godot_v4.7.2-stable_linux.x86_64 --path . res://tests/run.tscn -- res://tools/render_icons.gd

const SIZE: int = 256
const SOURCES: PackedStringArray = ["res://assets/props", "res://props"]
const ICONS: String = "res://assets/icons"


func _ready() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var environment: WorldEnvironment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.72, 0.68)
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	viewport.add_child(environment)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_energy = 1.3
	viewport.add_child(sun)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICONS))
	var files: PackedStringArray = []
	for folder: String in SOURCES:
		for file: String in DirAccess.get_files_at(folder):
			if file.ends_with(".glb") or file.ends_with(".tscn"):
				files.append(folder.path_join(file))
	for path: String in files:
		var file: String = path.get_file()
		var prop: Node3D = (load(path) as PackedScene).instantiate()
		viewport.add_child(prop)
		var box: AABB = _bounds(prop)
		var center: Vector3 = box.get_center()
		var radius: float = box.size.length() * 0.5
		camera.size = radius * 2.1
		camera.look_at_from_position(center + Vector3(1.0, 0.8, 1.2).normalized() * radius * 4.0, center)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(ICONS.path_join(file.get_basename() + ".png")))
		print("ícono ", file.get_basename())
		prop.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _bounds(root: Node) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var instance: MeshInstance3D = node as MeshInstance3D
		var piece: AABB = instance.global_transform * instance.get_aabb()
		box = piece if first else box.merge(piece)
		first = false
	return box
