extends SceneTree
# Prueba de humo sin cabeza: arranca la partida, dispara a los enemigos y revisa que no haya errores.
#   godot --headless --path . --script res://tests/smoke_test.gd

var game
var frames := 0
var kills_seen := 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	game = packed.instantiate()
	root.add_child(game)

func _process(delta: float) -> bool:
	frames += 1
	if frames == 3:
		game.start_game()
	if frames > 3 and game.state == "play":
		# apuntar al primer enemigo vivo y disparar
		var target := Vector2(640, 300)
		for e in game.enemies:
			if not e.dying:
				var b: Dictionary = e.box()
				target = Vector2(b.x, b.y - b.h * 0.85)
				break
		game.mouse = target - game.cam.offset
		game.mouse_down = true
		if frames % 90 == 0:
			game.throw_grenade()
		if frames == 200:
			game.spawn("boss")
			game.spawn("heavy")
			game.spawn("runner")
			game.spawn("grenadier")
		if frames < 700:
			game.player.hp = 100.0
	if frames == 700:
		game.player.hp = 1.0
		game.player.inv = 0.0
		game.hurt_player(5.0)
		assert(game.state == "over")
	if frames == 720:
		game._set_pause(false)
		game.start_game()
		assert(game.state == "play")
	if frames == 800:
		game._set_pause(true)
		assert(game.state == "pause")
		game._set_pause(false)
	if frames == 900:
		print("RESULT state=%s wave=%d score=%d enemies=%d shells=%d" % [game.state, game.wave, game.score, game.enemies.size(), game.shells.size()])
		quit(0)
	return false
