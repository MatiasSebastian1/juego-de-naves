extends SceneTree
# Captura de pantallas durante una partida simulada (requiere render real, p. ej. xvfb + opengl3).
#   godot --rendering-driver opengl3 --fixed-fps 60 --path . --script res://tests/shot_test.gd -- /ruta/salida
# Genera: g_menu, g_play, g_combat, g_boss, g_cover, g_over, g_pause (.png)

var game
var frames := 0
var out := "/tmp"
var _cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.save_path = "user://shot_test3d.cfg"   # no pisar el ranking real
	game._load_save()

func _snap(n: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, n])

func _process(delta: float) -> bool:
	frames += 1
	var p = game.player
	if frames == 30:
		_snap("g_menu")
	if frames == 31:
		game.start_game()
		game.god = true
		game.inter_t = 99.0
	# vista tranquila: jugador en el patio mirando al centro
	if frames == 100:
		_snap("g_play")
	# alineacion de todos los tipos de enemigo (congelados) vista de frente
	if frames == 110:
		game.inter_t = 99.0
		game.wave = 3
		game.spawn_enemy("rifleman", Vector3(-4.5, 0, 6))
		game.spawn_enemy("runner", Vector3(-1.8, 0, 6))
		game.spawn_enemy("heavy", Vector3(1.8, 0, 6))
		game.spawn_enemy("grenadier", Vector3(4.5, 0, 6))
		game.spawn_enemy("boss", Vector3(0, 0, -1))
		for e in game.enemies:
			e.model.rotation.y = 0.0
			e.set_physics_process(false)
		_cam = Camera3D.new()
		game.world.add_child(_cam)
		_cam.fov = 55.0
		_cam.global_position = Vector3(1.0, 1.9, 13.5)
		_cam.look_at(Vector3(0, 1.8, 3.0))
		_cam.make_current()
	if frames == 122:
		_snap("g_enemies")
	if frames == 123:
		_cam.queue_free()
		game.player.camera.make_current()
		game.bot = true
		for e in game.enemies.duplicate():
			e.queue_free()
			game.enemies.erase(e)
		game.spawn_enemy("rifleman", Vector3(-5, 0, 5))
		game.spawn_enemy("runner", Vector3(6, 0, 0))
		game.spawn_enemy("heavy", Vector3(0, 0, -4))
		game.spawn_enemy("grenadier", Vector3(-9, 0, -4))
	if frames > 123 and frames < 260:
		game.player.hp = 100.0
	if frames == 245:
		_snap("g_combat")
	if frames == 255:
		game.bot = false
		game.manual = true
		p.in_fire = false
		p.in_aim = false
		p.in_move = Vector2.ZERO
		p.crouched = true
		var pos := Vector3(-7.5, 0.05, 12.0)
		p.global_position = pos
		p.yaw = 0.15
		p.pitch = -0.12
	if frames == 330:
		_snap("g_cover")
		p.crouched = false
		game.bot = false
		game.manual = true
		p.in_move = Vector2.ZERO
		p.in_fire = false
		for e in game.enemies.duplicate():
			if is_instance_valid(e) and not e.dying:
				e.take_hit(1e6, e.global_position + Vector3(0, 1, 0), false, Vector3.FORWARD)
		game.spawn_enemy("boss", Vector3(0, 0, -2))
		game.spawn_enemy("heavy", Vector3(-9, 0, 2))
		game.spawn_enemy("rifleman", Vector3(10, 0, 4))
		p.global_position = Vector3(0, 0.05, 14)
		p.yaw = 0.0
		p.pitch = -0.12
	if frames > 330 and frames < 598 and game.state == "play":
		p.hp = 100.0
	if frames == 450:
		_snap("g_boss")
		game.throw_grenade(p.global_position + Vector3(0, 1.5, 0), p.global_position + Vector3(2, 0, -10), true)
	if frames == 519:
		_snap("g_boom")
	if frames == 560:
		game.set_pause(true)
	if frames == 565:
		_snap("g_pause")
		game.set_pause(false)
	if frames == 600:
		game.god = false
		game.bot = false
		game.score = 18450
		game.kills = 42
		game.best_streak = 11
		game.run_time = 187.0
		game.shots = 400
		game.hits = 273
		game.wave = 7
		p.hp = 1.0
		p.inv_t = 0.0
		p.take_damage(5.0, Vector3(3, 0, 3))
	if frames == 720:
		_snap("g_over")
	if frames == 725:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_test3d.cfg"))
		quit(0)
	return false
