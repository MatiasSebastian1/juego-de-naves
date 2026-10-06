extends SceneTree
# Captura rapida (render real) para ajustar el aspecto: menu, juego, jefe y explosion.
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --path . --script res://tests/look_test.gd -- /carpeta/salida

var game
var frames := 0
var out := "/tmp"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.save_path = "user://look_test.cfg"
	game._load_save()

func _snap(n: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, n])

func _process(_d: float) -> bool:
	frames += 1
	if frames == 20: _snap("l_menu")
	if frames == 21: game.start_game()
	if frames > 21 and game.state == "play":
		game.player.hp = 100.0
		var target := Vector2(640, 300)
		for e in game.enemies:
			if not e.dying:
				var b: Dictionary = e.box()
				target = Vector2(b.x, b.y - b.h * 0.85)
				break
		game.mouse = target - game.cam.offset
		game.mouse_down = frames % 30 < 18
	if frames == 60:
		var bo = game.spawn("boss"); bo.hp = 99999.0; bo.max_hp = 99999.0; bo.x = 330.0; bo.tz = 0.55
		var h = game.spawn("heavy"); h.x = 640.0; h.tz = 0.7
		game.spawn("grenadier").x = 950.0
		game.spawn("rifle").x = 800.0
	if frames == 140: _snap("l_play")
	if frames == 150: game.explosion(Vector2(760, 470), 1.3)
	if frames == 158: _snap("l_boom")
	if frames == 175:
		for e in game.enemies:
			if e.type == "rifle" or e.type == "grenadier":
				game.kill_enemy(e, false)
	if frames == 182: _snap("l_die1")
	if frames == 195: _snap("l_die2")
	if frames == 215:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://look_test.cfg"))
		quit(0)
	return false
