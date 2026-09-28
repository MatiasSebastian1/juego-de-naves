extends Node3D
## Smoke test de niveles: carga cada nivel, corre unos segundos de scroll y
## oleadas, y reporta cuantos enemigos quedaron vivos sin crashear.

func _ready() -> void:
	var level_paths := [
		"res://scenes/levels/Level1_CapaDeNubes.tscn",
		"res://scenes/levels/Level2_RuinasFlotantes.tscn",
		"res://scenes/levels/Level3_Nucleo.tscn",
	]
	for path in level_paths:
		await _test_level(path)
	print("LEVEL_SMOKE_DONE")
	get_tree().quit()

func _test_level(path: String) -> void:
	var scene: PackedScene = load(path)
	var level: Node3D = scene.instantiate()
	add_child(level)
	print("LOADED ", path, " level_id=", level.level_id, " scroll_speed=", level.scroll_speed, " waves=", level.wave_timeline.size())
	await get_tree().create_timer(6.0).timeout
	var enemy_count := get_tree().get_nodes_in_group(Constants.GROUP_ENEMY).size()
	print("AFTER_6S enemies_alive=", enemy_count, " scroll_z=", level.scroll_root.position.z)
	level.queue_free()
	await get_tree().process_frame
