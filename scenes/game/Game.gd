extends Node3D
## Controlador de la partida: instancia el nivel actual, las naves de los
## jugadores, la camara fija cenital, el HUD y el menu de pausa.

const LEVEL_SCENES := {
	1: preload("res://scenes/levels/Level1_CapaDeNubes.tscn"),
	2: preload("res://scenes/levels/Level2_RuinasFlotantes.tscn"),
	3: preload("res://scenes/levels/Level3_Nucleo.tscn"),
}
const PlayerScene := preload("res://scenes/player/Player.tscn")
const HUDScene := preload("res://scenes/game/HUD.tscn")
const PauseMenuScene := preload("res://scenes/game/PauseMenu.tscn")
const DialogueBoxScene := preload("res://scenes/dialogue/DialogueBox.tscn")

var level: Node3D
var players: Array = []
var hud
var pause_menu
var dialogue_box
var camera: Camera3D
var _paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_camera()

	hud = HUDScene.instantiate()
	add_child(hud)

	pause_menu = PauseMenuScene.instantiate()
	add_child(pause_menu)
	pause_menu.resume_requested.connect(_on_resume_requested)
	pause_menu.revert_requested.connect(_on_revert_requested)
	pause_menu.restart_requested.connect(_on_restart_requested)
	pause_menu.quit_requested.connect(_on_quit_requested)

	dialogue_box = DialogueBoxScene.instantiate()
	add_child(dialogue_box)

	_spawn_level()
	_spawn_players()

	hud.bind_game_manager_signals()
	hud.bind_level(level)
	for i in players.size():
		hud.bind_player(i, players[i])

	GameManager.run_game_over.connect(_on_run_game_over)
	level.level_finished.connect(_on_level_finished)

	_maybe_show_intro_dialogue()

func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = Constants.PLAYFIELD_HALF_WIDTH * 2.0
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.position = Vector3(0, 12, 0)
	camera.current = true
	add_child(camera)

func _spawn_level() -> void:
	var scene: PackedScene = LEVEL_SCENES.get(GameManager.current_level_id, LEVEL_SCENES[1])
	level = scene.instantiate()
	add_child(level)

func _spawn_players() -> void:
	var count := GameManager.active_player_count()
	for i in count:
		var p: Node3D = PlayerScene.instantiate()
		p.player_index = i
		p.ship_id = GameManager.selected_ship[i] if i < GameManager.selected_ship.size() else "interceptor"
		add_child(p)
		players.append(p)
	if players.size() == 2:
		players[0].position.x = -1.0
		players[1].position.x = 1.0

func _process(_delta: float) -> void:
	if dialogue_box.visible:
		return
	if InputManager.is_pause_just_pressed():
		_toggle_pause()

func _toggle_pause() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	pause_menu.visible = _paused

func _on_resume_requested() -> void:
	_paused = false
	get_tree().paused = false
	pause_menu.visible = false

func _on_revert_requested() -> void:
	get_tree().paused = false
	SaveManager.revert_to_last()
	get_tree().change_scene_to_file("res://scenes/game/Game.tscn")

func _on_restart_requested() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

## --- Historia / dialogos --------------------------------------------------

func _maybe_show_intro_dialogue() -> void:
	var key := -1
	match GameManager.current_level_id:
		1:
			if not GameManager.story_flags.get("shown_intro", false):
				key = StoryData.INTRO
				GameManager.story_flags["shown_intro"] = true
		2:
			if not GameManager.story_flags.get("shown_after1", false):
				key = StoryData.AFTER_LEVEL_1
				GameManager.story_flags["shown_after1"] = true
		3:
			if not GameManager.story_flags.get("shown_after2", false):
				key = StoryData.AFTER_LEVEL_2
				GameManager.story_flags["shown_after2"] = true
	if key == -1:
		return
	get_tree().paused = true
	dialogue_box.show_lines(StoryData.get_lines(key))
	await dialogue_box.finished
	get_tree().paused = false

## --- Fin de nivel / fin de run --------------------------------------------

func _on_level_finished(finished_level_id: int) -> void:
	var is_victory := finished_level_id >= GameManager.MAX_LEVEL
	if is_victory and not GameManager.story_flags.get("shown_ending", false):
		GameManager.story_flags["shown_ending"] = true
		get_tree().paused = true
		dialogue_box.show_lines(StoryData.get_lines(StoryData.ENDING))
		await dialogue_box.finished
		get_tree().paused = false
	GameManager.last_result = {
		"type": "victory" if is_victory else "level_complete",
		"level_id": finished_level_id,
		"scores": GameManager.scores.duplicate(),
	}
	get_tree().change_scene_to_file("res://scenes/game/ResultsScreen.tscn")

func _on_run_game_over() -> void:
	GameManager.last_result = {
		"type": "game_over",
		"level_id": GameManager.current_level_id,
		"scores": GameManager.scores.duplicate(),
	}
	get_tree().change_scene_to_file("res://scenes/game/ResultsScreen.tscn")
