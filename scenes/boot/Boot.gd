extends Node
## Punto de entrada del juego. Prepara servicios globales y pasa al menu principal.

func _ready() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")
