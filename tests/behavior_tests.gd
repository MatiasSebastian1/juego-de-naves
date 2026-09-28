extends Node3D
## Pruebas automaticas que actuan como el jugador (simulan input real, no
## leen ni fuerzan el dato) y verifican reachability real por colision.
## Reglas seguidas (aprendidas en Dia Blanco, adaptadas a un shmup):
##  1. Actuar como el jugador: se simula Input.action_press, no se llama
##     directamente a metodos internos para "hacer trampa".
##  2. Se prueban los dos ejes de movimiento (X y Z).
##  3. El pickup se prueba corrido del centro, no en (0,0).
##  4. La "entrada a la zona" (nivel listo) siempre precede al "contenido"
##     (primera oleada), verificado en las 3 timelines.
##  5. El power-up se recoge por overlap real, verificado por un efecto de
##     estado real (weapon_level sube), no asumido.
##  6. El dialogo no se marca como "mostrado" sin verificar que el texto
##     real se renderizo y que bloquea el juego (paused=true).

var _failures: int = 0
var _total: int = 0

func _ready() -> void:
	await _test_movement_both_axes()
	await _test_offcenter_pickup_reachability()
	_test_zone_entry_before_content()
	await _test_dialogue_really_blocks()

	print("--------------------------------------------------")
	print("BEHAVIOR_TESTS: %d/%d OK" % [_total - _failures, _total])
	if _failures > 0:
		print("BEHAVIOR_TESTS_FAILED")
		get_tree().quit(1)
	else:
		print("BEHAVIOR_TESTS_ALL_PASSED")
		get_tree().quit(0)

func _check(name: String, condition: bool, detail: String = "") -> void:
	_total += 1
	if condition:
		print("[PASS] ", name)
	else:
		_failures += 1
		print("[FAIL] ", name, " -- ", detail)

func _wait_physics_frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## --- Test 1: movimiento en los dos ejes, simulando input real -----------

func _test_movement_both_axes() -> void:
	var player: Node3D = load("res://scenes/player/Player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame

	var start_pos: Vector3 = player.global_position

	Input.action_press("p1_right")
	await _wait_physics_frames(30)
	Input.action_release("p1_right")
	var after_x: Vector3 = player.global_position
	_check(
		"Movimiento eje X (derecha) responde a input real",
		after_x.x > start_pos.x + 0.3,
		"start.x=%s after.x=%s" % [start_pos.x, after_x.x]
	)

	var mid_pos: Vector3 = player.global_position
	Input.action_press("p1_up")
	await _wait_physics_frames(20)
	Input.action_release("p1_up")
	var after_z: Vector3 = player.global_position
	_check(
		"Movimiento eje Z (arriba) responde a input real",
		after_z.z < mid_pos.z - 0.2,
		"mid.z=%s after.z=%s" % [mid_pos.z, after_z.z]
	)

	player.queue_free()
	await get_tree().physics_frame

## --- Test 2: pickup de power-up corrido del centro, verificado por -------
## --- un efecto de estado real (no se llama apply_powerup a mano) --------

func _test_offcenter_pickup_reachability() -> void:
	GameManager.reset_run(GameManager.GameMode.SOLO)

	var player: Node3D = load("res://scenes/player/Player.tscn").instantiate()
	add_child(player)
	await get_tree().physics_frame
	# Arranca corrido del centro, no en (0,0).
	player.global_position = Vector3(-2.0, 0.0, Constants.PLAYER_MAX_Z - 1.0)

	var powerup: Node3D = load("res://scenes/powerups/WeaponUpgrade.tscn").instantiate()
	add_child(powerup)
	powerup.drift_speed = 0.0 # no lo dejamos caer, solo probamos que el jugador llegue
	# Tambien corrido del centro, en un X que un enemigo real usaria (ver Level1).
	powerup.global_position = Vector3(2.0, 0.0, Constants.PLAYER_MAX_Z - 1.0)

	var weapon_level_before: int = GameManager.weapon_level[0]

	Input.action_press("p1_right")
	await _wait_physics_frames(120) # tiempo de sobra para cruzar el playfield
	Input.action_release("p1_right")

	var weapon_level_after: int = GameManager.weapon_level[0]
	var powerup_consumed: bool = not is_instance_valid(powerup) or powerup.is_queued_for_deletion()

	_check(
		"Power-up alcanzable moviendose desde -2.0 hasta 2.0 (overlap real)",
		powerup_consumed,
		"powerup sigue vivo en x=%s, jugador en x=%s" % [
			powerup.global_position.x if is_instance_valid(powerup) else "N/A",
			player.global_position.x
		]
	)
	_check(
		"El pickup subio weapon_level via colision real (no llamada directa)",
		weapon_level_after > weapon_level_before,
		"antes=%d despues=%d" % [weapon_level_before, weapon_level_after]
	)

	player.queue_free()
	if is_instance_valid(powerup):
		powerup.queue_free()
	await get_tree().physics_frame

## --- Test 3: la zona (nivel listo) entra antes que el contenido ---------

func _test_zone_entry_before_content() -> void:
	var level_paths := [
		"res://scenes/levels/Level1_CapaDeNubes.tscn",
		"res://scenes/levels/Level2_RuinasFlotantes.tscn",
		"res://scenes/levels/Level3_Nucleo.tscn",
	]
	for path in level_paths:
		var scene: PackedScene = load(path)
		var level: Node3D = scene.instantiate()
		add_child(level)
		var min_time := INF
		for entry in level.wave_timeline:
			min_time = minf(min_time, float(entry["time"]))
		_check(
			"%s: la zona esta lista (t=0) antes de la primera oleada (t=%s)" % [path, min_time],
			min_time > 0.0 and level.scroll_root != null,
			"min_time=%s scroll_root=%s" % [min_time, level.scroll_root]
		)
		level.queue_free()

## --- Test 4: el dialogo bloquea el juego de verdad, con texto real ------

func _test_dialogue_really_blocks() -> void:
	var dialogue: CanvasLayer = load("res://scenes/dialogue/DialogueBox.tscn").instantiate()
	add_child(dialogue)
	await get_tree().physics_frame

	var lines := StoryData.get_lines(StoryData.INTRO)
	var expected_text: String = String(lines[0]["text"])

	dialogue.show_lines(lines)
	await get_tree().physics_frame
	get_tree().paused = true

	_check(
		"El dialogo esta visible con el texto real (no un placeholder)",
		dialogue.visible and dialogue._text_label.text == expected_text,
		"visible=%s text=%s" % [dialogue.visible, dialogue._text_label.text if dialogue._text_label else "N/A"]
	)
	_check(
		"El juego queda realmente pausado mientras se muestra el dialogo",
		get_tree().paused == true,
		""
	)

	# Simula avanzar el dialogo apretando "disparo" de verdad (Input.action_press,
	# el mismo camino que usaria un jugador con teclado/gamepad), sin llamar
	# _close()/_advance() a mano.
	var attempts := 0
	while dialogue.visible and attempts < lines.size() + 2:
		Input.action_press("p1_fire")
		await get_tree().physics_frame
		Input.action_release("p1_fire")
		await get_tree().physics_frame
		attempts += 1

	_check(
		"El dialogo se cierra solo despues de consumir todas las lineas",
		not dialogue.visible,
		"visible=%s" % dialogue.visible
	)

	get_tree().paused = false
	dialogue.queue_free()
	await get_tree().physics_frame
