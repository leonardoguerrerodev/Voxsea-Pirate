extends Node
## Corre un test dentro de una escena, con los autoloads ya cargados (un script de
## -s compila antes que ellos y no conoce Game). Uso:
## ../Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tests/run.tscn -- test_hull
## Cada test es un Node que termina con get_tree().quit(código).


func _ready() -> void:
	# Acepta el nombre de un test o una ruta res:// (scripts de captura, etc.).
	var target: String = OS.get_cmdline_user_args()[0]
	var path: String = target if target.begins_with("res://") else "res://tests/%s.gd" % target
	add_child((load(path) as GDScript).new())
