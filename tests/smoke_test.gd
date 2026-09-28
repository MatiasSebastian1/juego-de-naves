extends Node3D
## Smoke test: instancia jugador + camara y corre unos frames para detectar
## errores de compilacion/ejecucion temprano (sin editor grafico disponible).

func _ready() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Constants.PLAYFIELD_HALF_WIDTH * 2.0
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.position = Vector3(0, 10, 0)
	add_child(camera)

	var player_scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player: Node = player_scene.instantiate()
	add_child(player)
	print("SMOKE_OK player_index=", player.player_index, " ship=", player.ship_id, " hp=", player.current_hp)

	var enemy_paths := [
		"res://scenes/enemies/CazaBasico.tscn",
		"res://scenes/enemies/CazaRapido.tscn",
		"res://scenes/enemies/BombarderoEnemy.tscn",
		"res://scenes/enemies/TorretaFija.tscn",
		"res://scenes/enemies/DronKamikaze.tscn",
		"res://scenes/enemies/PortaNaves.tscn",
	]
	var scroll_root := Node3D.new()
	add_child(scroll_root)
	var i := 0
	for path in enemy_paths:
		var scene: PackedScene = load(path)
		var enemy: Node3D = scene.instantiate()
		enemy.position = Vector3(i - 3.0, 0, -5.0)
		scroll_root.add_child(enemy)
		i += 1
	print("SMOKE_ENEMIES_OK count=", scroll_root.get_child_count())

	var powerup_paths := [
		"res://scenes/powerups/WeaponUpgrade.tscn",
		"res://scenes/powerups/Shield.tscn",
		"res://scenes/powerups/SpeedBoost.tscn",
		"res://scenes/powerups/Bomb.tscn",
	]
	for path in powerup_paths:
		var scene: PackedScene = load(path)
		var pu: Node3D = scene.instantiate()
		add_child(pu)
		pu.position = Vector3(0, 0, -2)
	print("SMOKE_POWERUPS_OK")

	var boss_paths := [
		"res://scenes/bosses/GuardianNube.tscn",
		"res://scenes/bosses/RuinaFlotante.tscn",
		"res://scenes/bosses/NucleoInvasion.tscn",
	]
	var boss_root := Node3D.new()
	add_child(boss_root)
	var bx := -6.0
	for path in boss_paths:
		var scene: PackedScene = load(path)
		var boss: Node3D = scene.instantiate()
		boss.position = Vector3(bx, 0, -9.0)
		boss_root.add_child(boss)
		bx += 6.0
	print("SMOKE_BOSSES_OK count=", boss_root.get_child_count())

	await get_tree().create_timer(4.0).timeout
	print("SMOKE_AFTER_PHYSICS survivors=", scroll_root.get_child_count())
	for boss in boss_root.get_children():
		print("BOSS ", boss.name, " phase=", boss.current_phase_index, " hp=", boss.hp, " z=", boss.global_position.z)
	print("SMOKE_DONE")
	get_tree().quit()
