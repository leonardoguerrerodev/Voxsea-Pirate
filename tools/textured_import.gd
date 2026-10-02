@tool
extends EditorScenePostImport
## Post-importación de los .glb con textura propia (casco y props de Meshy): filtrado
## anisotrópico en todos sus materiales. Sin esto, la cubierta vista desde los ojos
## del jugador (ángulo rasante) se ve lavada y borrosa. Se asigna en el .import de
## cada .glb (import_script/path).


func _post_import(scene: Node) -> Object:
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for i: int in mesh.get_surface_count():
			var material: BaseMaterial3D = mesh.surface_get_material(i) as BaseMaterial3D
			if material:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return scene
