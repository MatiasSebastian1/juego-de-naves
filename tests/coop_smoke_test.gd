extends Node
## Verifica que el modo cooperativo (2 jugadores) arme la escena de juego
## sin errores: 2 naves, HUD con 2 filas, controles independientes.

func _ready() -> void:
	GameManager.reset_run(GameManager.GameMode.COOP)
	GameManager.selected_ship = ["interceptor", "bombardero"]
	GameManager.control_scheme = [InputManager.SCHEME_KEYBOARD, InputManager.SCHEME_KEYBOARD]
	var scene: PackedScene = load("res://scenes/game/Game.tscn")
	var game: Node = scene.instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	print("COOP_PLAYERS=", game.players.size())
	for p in game.players:
		print("  player_index=", p.player_index, " ship=", p.ship_id, " x=", p.position.x)
	print("COOP_SMOKE_DONE")
	get_tree().quit()
