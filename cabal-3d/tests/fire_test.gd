extends SceneTree
# Captura del jugador disparando (para revisar de donde salen los disparos).
#   godot --rendering-driver opengl3 --fixed-fps 60 --path . --script res://tests/fire_test.gd -- /ruta/salida

var game
var frames := 0
var out := "/tmp"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.save_path = "user://fire_test3d.cfg"
	game._load_save()

func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _process(delta: float) -> bool:
	if not game.ready_done:
		return false
	frames += 1
	var p = game.player
	if frames == 31:
		game.start_game()
		game.god = true
		game.inter_t = 99.0
		game.manual = true
	if frames == 60:
		# enemigo congelado a 9 m, un poco a la derecha de la mira del jugador
		var lv = game.level
		var fwd := Vector3(-sin(lv.start_yaw), 0, -cos(lv.start_yaw))
		var right := Vector3(cos(lv.start_yaw), 0, -sin(lv.start_yaw))
		var e = game.spawn_enemy("rifleman", lv.nearest_free(lv.start_pos + fwd * 9.0 + right * 2.5))
		e.set_physics_process(false)
		p.in_fire = true
	if frames in [90, 93, 96, 99, 140]:
		_snap("f_%d" % frames)
	if frames == 150:
		quit(0)
	return false
