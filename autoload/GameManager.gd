extends Node
## GameManager: estado global de la run (puntaje, vidas, nivel actual, naves elegidas).
## No persiste en disco directamente: eso es responsabilidad de SaveManager.

signal score_changed(player_index: int, new_score: int)
signal lives_changed(player_index: int, new_lives: int)
signal player_game_over(player_index: int)
signal run_game_over()
signal level_completed(level_id: int, results: Dictionary)
signal checkpoint_reached(checkpoint_data: Dictionary)

enum GameMode { SOLO, COOP }
enum ControlScheme { KEYBOARD, MOUSE_KEYBOARD, GAMEPAD, TOUCH }

const MAX_LEVEL := 3
const STARTING_LIVES := 3
const STARTING_CONTINUES := 2
const STARTING_BOMBS := 2

const SHIP_IDS: Array[String] = ["interceptor", "bombardero", "prototipo"]

var game_mode: int = GameMode.SOLO
var selected_ship: Array[String] = ["interceptor", "bombardero"]
var control_scheme: Array[int] = [ControlScheme.KEYBOARD, ControlScheme.KEYBOARD]

var current_level_id: int = 1
var current_wave_index: int = 0

# Estado por jugador (indice 0 = P1, indice 1 = P2 en modo COOP).
var scores: Array[int] = [0, 0]
var lives: Array[int] = [STARTING_LIVES, STARTING_LIVES]
var continues_left: Array[int] = [STARTING_CONTINUES, STARTING_CONTINUES]
var bombs: Array[int] = [STARTING_BOMBS, STARTING_BOMBS]
var weapon_level: Array[int] = [1, 1]
var shield_charges: Array[int] = [0, 0]

var story_flags: Dictionary = {}

## Datos transitorios para la pantalla de resultados (no se guardan en disco).
## type: "level_complete" | "game_over" | "victory"
var last_result: Dictionary = {}

func reset_run(mode: int = GameMode.SOLO) -> void:
	game_mode = mode
	current_level_id = 1
	current_wave_index = 0
	scores = [0, 0]
	lives = [STARTING_LIVES, STARTING_LIVES]
	continues_left = [STARTING_CONTINUES, STARTING_CONTINUES]
	bombs = [STARTING_BOMBS, STARTING_BOMBS]
	weapon_level = [1, 1]
	shield_charges = [0, 0]
	story_flags.clear()

func active_player_count() -> int:
	return 2 if game_mode == GameMode.COOP else 1

func add_score(player_index: int, amount: int) -> void:
	if player_index < 0 or player_index >= scores.size():
		return
	scores[player_index] += amount
	score_changed.emit(player_index, scores[player_index])

func set_weapon_level(player_index: int, level: int) -> void:
	weapon_level[player_index] = clampi(level, 1, 3)

func lose_life(player_index: int) -> bool:
	if player_index < 0 or player_index >= lives.size():
		return true
	lives[player_index] -= 1
	lives_changed.emit(player_index, lives[player_index])
	if lives[player_index] > 0:
		return false
	if continues_left[player_index] > 0:
		continues_left[player_index] -= 1
		lives[player_index] = STARTING_LIVES
		lives_changed.emit(player_index, lives[player_index])
		return false
	player_game_over.emit(player_index)
	if _all_players_out():
		run_game_over.emit()
	return true

func _all_players_out() -> bool:
	for i in active_player_count():
		if lives[i] > 0 or continues_left[i] > 0:
			return false
	return true

func complete_level(level_id: int) -> void:
	var results := {
		"level_id": level_id,
		"scores": scores.duplicate(),
	}
	level_completed.emit(level_id, results)

func build_checkpoint_snapshot(extra: Dictionary = {}) -> Dictionary:
	# Punto unico de verdad para lo que entra en un checkpoint.
	# Regla: al agregar estado nuevo, sumarlo aca Y en apply_checkpoint_snapshot().
	var data := {
		"level_id": current_level_id,
		"wave_index": current_wave_index,
		"game_mode": game_mode,
		"selected_ship": selected_ship.duplicate(),
		"scores": scores.duplicate(),
		"lives": lives.duplicate(),
		"continues_left": continues_left.duplicate(),
		"bombs": bombs.duplicate(),
		"weapon_level": weapon_level.duplicate(),
		"shield_charges": shield_charges.duplicate(),
		"story_flags": story_flags.duplicate(),
	}
	for key in extra.keys():
		data[key] = extra[key]
	checkpoint_reached.emit(data)
	return data

func apply_checkpoint_snapshot(data: Dictionary) -> void:
	# Recalcula TODO desde el snapshot; nunca incrementa sobre el estado actual.
	current_level_id = int(data.get("level_id", 1))
	current_wave_index = int(data.get("wave_index", 0))
	game_mode = int(data.get("game_mode", GameMode.SOLO))
	var ships: Array = data.get("selected_ship", ["interceptor", "bombardero"])
	selected_ship = []
	for s in ships:
		selected_ship.append(String(s))
	scores = _to_int_array(data.get("scores", [0, 0]))
	lives = _to_int_array(data.get("lives", [STARTING_LIVES, STARTING_LIVES]))
	continues_left = _to_int_array(data.get("continues_left", [STARTING_CONTINUES, STARTING_CONTINUES]))
	bombs = _to_int_array(data.get("bombs", [STARTING_BOMBS, STARTING_BOMBS]))
	weapon_level = _to_int_array(data.get("weapon_level", [1, 1]))
	shield_charges = _to_int_array(data.get("shield_charges", [0, 0]))
	story_flags = (data.get("story_flags", {}) as Dictionary).duplicate()

func _to_int_array(source: Array) -> Array[int]:
	var out: Array[int] = []
	for v in source:
		out.append(int(v))
	return out
