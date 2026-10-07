extends SceneTree
# Captura de pantallas durante una partida simulada (requiere render real, p. ej. xvfb + opengl3).
#   godot --rendering-driver opengl3 --fixed-fps 60 --path . --script res://tests/shot_test.gd -- /ruta/salida
# Genera: g_menu, g_play, g_aerial, g_enemies, g_combat, g_cover, g_boss, g_boom, g_pause, g_over (.png).
# Las posiciones se calculan a partir del nivel (punto de inicio, espacios abiertos), asi sirve con cualquier arena.

var game
var frames := 0
var out := "/tmp"
var _cam: Camera3D
var _a := Vector3.ZERO       # espacio abierto para alinear a los enemigos
var _fwd := Vector3.ZERO

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

# punto libre cerca de start + (dx, dz) en ejes del mundo
func _rel(dx: float, dz: float) -> Vector3:
	var s: Vector3 = game.level.start_pos
	return game.level.nearest_free(s + Vector3(dx, 0, dz))

func _process(delta: float) -> bool:
	if not game.ready_done:
		return false
	frames += 1
	var p = game.player
	var lv = game.level
	if frames == 30:
		_snap("g_menu")
	if frames == 31:
		game.start_game()
		game.god = true
		game.inter_t = 99.0
		_fwd = Vector3(-sin(lv.start_yaw), 0, -cos(lv.start_yaw))
		_a = lv.open_spot(Vector2(lv.start_pos.x, lv.start_pos.z) + Vector2(_fwd.x, _fwd.z) * 12.0, 7.0)
	# vista tranquila: jugador en el punto de inicio mirando al centro
	if frames == 100:
		_snap("g_play")
	# vista aerea del nivel completo
	if frames == 104:
		_cam = Camera3D.new()
		game.world.add_child(_cam)
		_cam.far = 700.0
		_cam.fov = 60.0
		_cam.global_position = Vector3(lv.start_pos.x * 0.3, 78.0, lv.start_pos.z + 70.0)
		_cam.look_at(Vector3(0, 0, 4), Vector3.UP)
		_cam.make_current()
	if frames == 110:
		_snap("g_aerial")
		_cam.queue_free()
		p.camera.make_current()
	# alineacion de todos los tipos de enemigo (congelados) vista de frente
	if frames == 112:
		game.inter_t = 99.0
		game.wave = 3
		var r := Vector3(1, 0, 0)
		game.spawn_enemy("rifleman", lv.nearest_free(_a + r * -4.5))
		game.spawn_enemy("runner", lv.nearest_free(_a + r * -1.8))
		game.spawn_enemy("heavy", lv.nearest_free(_a + r * 1.8))
		game.spawn_enemy("grenadier", lv.nearest_free(_a + r * 4.5))
		game.spawn_enemy("boss", lv.nearest_free(_a + Vector3(0, 0, -7.0)))
		for e in game.enemies:
			e.model.rotation.y = 0.0
			e.set_physics_process(false)
		_cam = Camera3D.new()
		game.world.add_child(_cam)
		_cam.fov = 55.0
		_cam.global_position = _a + Vector3(1.0, 1.9, 7.5)
		_cam.look_at(_a + Vector3(0, 1.8, -3.0))
		_cam.make_current()
	if frames == 124:
		_snap("g_enemies")
	if frames == 125:
		_cam.queue_free()
		game.player.camera.make_current()
		game.bot = true
		for e in game.enemies.duplicate():
			e.queue_free()
			game.enemies.erase(e)
		game.spawn_enemy("rifleman", _rel(-5, -5))
		game.spawn_enemy("runner", _rel(6, -9))
		game.spawn_enemy("heavy", _rel(0, -14))
		game.spawn_enemy("grenadier", _rel(-9, -12))
	if frames > 125 and frames < 262:
		game.player.hp = 100.0
	if frames == 247:
		_snap("g_combat")
	if frames == 257:
		game.bot = false
		game.manual = true
		p.in_fire = false
		p.in_aim = false
		p.in_move = Vector2.ZERO
		p.crouched = true
		# detras de la cobertura baja mas cercana al inicio, mirando hacia ella
		var best = null
		var bd := 1e9
		for cp in lv.cover_points:
			if cp.low and cp.pos.distance_to(lv.start_pos) < bd:
				bd = cp.pos.distance_to(lv.start_pos)
				best = cp
		if best != null:
			p.global_position = best.pos + Vector3(0, 0.08, 0)
			p.yaw = atan2(best.dir.x, best.dir.z)
			p.pitch = -0.12
	if frames == 332:
		_snap("g_cover")
		p.crouched = false
		game.bot = false
		game.manual = true
		p.in_move = Vector2.ZERO
		p.in_fire = false
		for e in game.enemies.duplicate():
			if is_instance_valid(e) and not e.dying:
				e.take_hit(1e6, e.global_position + Vector3(0, 1, 0), false, Vector3.FORWARD)
		p.global_position = lv.start_pos + Vector3(0, 0.08, 0)
		p.yaw = lv.start_yaw
		p.pitch = -0.12
		game.spawn_enemy("boss", lv.nearest_free(lv.start_pos + _fwd * 12.0))
		game.spawn_enemy("heavy", _rel(-9, -8))
		game.spawn_enemy("rifleman", _rel(10, -6))
	if frames > 332 and frames < 600 and game.state == "play":
		p.hp = 100.0
	if frames == 452:
		_snap("g_boss")
		game.throw_grenade(p.global_position + Vector3(0, 1.5, 0), p.global_position + _fwd * 10.0, true)
	if frames == 521:
		_snap("g_boom")
	if frames == 562:
		game.set_pause(true)
	if frames == 567:
		_snap("g_pause")
		game.set_pause(false)
	if frames == 602:
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
	if frames == 722:
		_snap("g_over")
	if frames == 727:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_test3d.cfg"))
		quit(0)
	return false
