extends SceneTree
# Captura de pantallas durante una partida simulada (requiere render real, p. ej. xvfb + opengl3).
#   godot --path . --script res://tests/shot_test.gd -- /ruta/salida

var game
var frames := 0
var out := "/tmp"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)

func _snap(n: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [out, n])

func _process(delta: float) -> bool:
	frames += 1
	if frames == 30: _snap("g_menu")
	if frames == 31: game.start_game()
	if frames > 31 and game.state == "play":
		var target := Vector2(640, 300)
		for e in game.enemies:
			if not e.dying:
				var b: Dictionary = e.box()
				target = Vector2(b.x, b.y - b.h * 0.85)
				break
		game.mouse = target - game.cam.offset
		game.mouse_down = frames % 40 < 25
		if frames == 150: game.throw_grenade()
		if frames == 260:
			var bo = game.spawn("boss"); bo.hp = 99999.0; bo.max_hp = 99999.0
			game.spawn("heavy"); game.spawn("grenadier")
		game.player.hp = 100.0
	if frames == 160: _snap("g_play1")
	if frames == 380: _snap("g_boss")
	if frames == 520: _snap("g_play2")
	if frames == 540:
		quit(0)
	return false
