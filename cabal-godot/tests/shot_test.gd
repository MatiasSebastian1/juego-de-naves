extends SceneTree
# Captura de pantallas durante una partida simulada (requiere render real, p. ej. xvfb + opengl3).
#   godot --rendering-driver opengl3 --fixed-fps 60 --path . --script res://tests/shot_test.gd -- /ruta/salida

var game
var frames := 0
var out := "/tmp"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.save_path = "user://shot_test.cfg"   # no pisar el ranking real
	game._load_save()

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
	if frames == 500: game.explosion(Vector2(760, 470), 1.2)
	if frames == 508: _snap("g_boom")
	# aviso de proyectil/granada dirigidos al jugador
	if frames == 400 and game.state == "play":
		var p = game.player
		game._bullet(Vector2(p.position.x + 40, 380), Vector2(p.position.x, p.position.y - 50), 1.6, 0.3, 8.0)
		game._nade(Vector2(p.position.x - 200, 400), Vector2(p.position.x, p.position.y))
	if frames == 425: _snap("g_warn")
	# pausa
	if frames == 545: game._set_pause(true)
	if frames == 550: _snap("g_pause")
	if frames == 551: game._set_pause(false)
	# game over con estadisticas y ranking
	if frames == 600:
		game.score = 18450; game.kills = 42; game.best_streak = 11; game.run_time = 187.0
		game.shots = 400; game.hits = 273
		game.player.hp = 1.0; game.player.inv = 0.0
		game.hurt_player(5.0)
	if frames == 700: _snap("g_over")
	if frames == 705:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://shot_test.cfg"))
		quit(0)
	return false
