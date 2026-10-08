extends SceneTree
# Capturas del personaje del jugador y de los zombis en la aldea (render real):
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 --path cabal-3d \
#       --script res://tests/char_shot.gd -- /ruta/salida
# Genera c_idle, c_fire (+c_fire2), c_run, c_crouch, c_aim, c_zombies y c_spit (proyectil toxico en vuelo).
var game
var frames := 0
var out := "/tmp"
var e1
var _cam: Camera3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.save_path = "user://char_shot3d.cfg"
	game._load_save()

func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _process(delta: float) -> bool:
	if not game.ready_done:
		return false
	frames += 1
	var p = game.player
	var lv = game.level
	var fwd := Vector3(-sin(lv.start_yaw), 0, -cos(lv.start_yaw))
	var right := Vector3(cos(lv.start_yaw), 0, -sin(lv.start_yaw))
	if frames == 31:
		game.start_game()
		game.god = true
		game.inter_t = 99.0
		game.manual = true
	if frames == 80:
		_snap("c_idle")
		e1 = game.spawn_enemy("rifleman", lv.nearest_free(lv.start_pos + fwd * 9.0 + right * 2.5))
		e1.set_physics_process(false)
		p.in_fire = true
	if frames in [110, 113]:
		_snap("c_fire" if frames == 110 else "c_fire2")
	if frames == 120:
		p.in_fire = false
		p.in_move = Vector2(0, 1)
		p.in_sprint = true
	if frames == 165:
		_snap("c_run")
	if frames == 170:
		p.in_move = Vector2.ZERO
		p.in_sprint = false
		p.crouched = true
		p.yaw += 0.7
	if frames == 235:
		_snap("c_crouch")
		p.crouched = false
		p.in_aim = true
	if frames == 290:
		_snap("c_aim")
		p.in_aim = false
		p.in_fire = false
		for e in game.enemies.duplicate():
			e.queue_free()
			game.enemies.erase(e)
		p.yaw = lv.start_yaw
		game.spawn_enemy("runner", lv.nearest_free(p.global_position + fwd * 6.0 + right * 1.0))
		var g = game.spawn_enemy("grenadier", lv.nearest_free(p.global_position + fwd * 10.0 - right * 3.0))
		var h = game.spawn_enemy("heavy", lv.nearest_free(p.global_position + fwd * 8.0 + right * 4.0))
		for e in game.enemies:
			e.speed *= 0.5
	if frames == 350:
		_snap("c_zombies")
		for e in game.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
				game.enemies.erase(e)
		e1 = game.spawn_enemy("rifleman", lv.nearest_free(p.global_position + fwd * 8.0 + right * 1.5))
		e1.set_physics_process(false)
		e1.model.rotation.y = atan2(-fwd.x, -fwd.z)
	if frames == 380:
		e1._telegraph(true)
	if frames == 400:
		e1._fire_shot(8.0, 0.0, e1.TOXIC)
	if frames == 403:
		_snap("c_spit")
	if frames == 405:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://char_shot3d.cfg"))
		quit(0)
	return false
