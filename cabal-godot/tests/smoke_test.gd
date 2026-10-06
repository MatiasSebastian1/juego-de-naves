extends SceneTree
# Prueba de humo sin cabeza: simula partidas completas paso a paso y verifica reinicio, pausa, game over,
# ranking persistido, volumen/mute, oleadas 1..15 (jefe cada 5) y que Engine.time_scale siempre vuelva a 1.0.
#   godot --headless --path . --script res://tests/smoke_test.gd
# Imprime "RESULT ..." y sale con codigo 1 si algun chequeo falla.

const TEST_SAVE := "user://smoke_test.cfg"
const DT := 1.0 / 60.0

var game
var frames := 0
var fails := 0
var done := false

func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)

func check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		printerr("FALLO: ", msg)

# avanza la simulacion `sec` segundos de juego; con auto=true apunta y dispara al primer enemigo vivo
func sim(sec: float, auto := false, god := true) -> void:
	for i in int(sec / DT):
		if auto:
			var target := Vector2(640, 300)
			for e in game.enemies:
				if not e.dying:
					var b: Dictionary = e.box()
					target = Vector2(b.x, b.y - b.h * 0.85)
					break
			game.mouse = target - game.cam.offset
			game.mouse_down = true
		if god and game.state == "play":
			game.player.hp = 100.0
		game.update(DT)

func click(btn := MOUSE_BUTTON_LEFT, pos := Vector2(640, 360)) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = btn
	ev.position = pos
	ev.pressed = true
	game._input(ev)
	ev.pressed = false
	game._input(ev)

func key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	game._input(ev)

func kill_kind(game_over := false) -> void:
	game.player.hp = 1.0
	game.player.inv = 0.0
	game.hurt_player(5.0)

func _process(delta: float) -> bool:
	frames += 1
	if frames == 3 and not done:
		done = true
		_run()
	return false

func _run() -> void:
	# --- ranking en archivo temporal
	game.save_path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	game._load_save()
	check(game.top.is_empty(), "ranking inicial vacio")

	# --- partida automatica con jefe y todos los tipos
	check(game.state == "menu", "arranca en menu")
	click()   # click en el menu empieza
	check(game.state == "play", "click en el menu inicia la partida")
	sim(15.0, true)
	game.spawn("boss"); game.spawn("heavy"); game.spawn("runner"); game.spawn("grenadier")
	sim(20.0, true)
	check(game.shots > 0 and game.accuracy() <= 100, "estadisticas de disparos")
	game.throw_grenade()
	sim(2.0, true)
	check(game.player.gren >= 0, "granadas no negativas")

	# --- jefe muerto -> camara lenta, y reiniciar la deja en 1.0
	var bo = game.spawn("boss")
	game.damage_enemy(bo, 9999.0, Vector2(bo.x, bo.box().y - 100.0), false)
	game._time_fx()
	check(Engine.time_scale < 1.0, "slow-mo activo tras matar al jefe")
	game.start_game()
	game._time_fx()
	check(Engine.time_scale == 1.0, "time_scale vuelve a 1.0 al reiniciar durante slow-mo")
	check(game.enemies.is_empty() and game.shells.is_empty() and game.pickups.is_empty() and game.barricades.is_empty(), "reinicio limpia entidades")
	check(game.score == 0 and game.kills == 0 and game.shots == 0 and game.wave == 0, "reinicio limpia estadisticas")

	# --- slow-mo + pausa
	sim(1.0)
	game._slowmo()
	game._time_fx()
	check(Engine.time_scale == 0.25, "slow-mo aplicado")
	game._set_pause(true)
	game._time_fx()
	check(game.state == "pause" and paused and Engine.time_scale == 1.0, "pausa restablece time_scale")
	game._set_pause(true)
	check(game.state == "pause", "pausa doble es inocua")
	key(KEY_P)
	check(game.state == "play" and not paused, "P reanuda")
	# hit-stop: dura poco y se libera solo (tiempo real)
	game._stop_cool = 0
	game.hitstop(0.05)
	game._time_fx()
	check(Engine.time_scale < 0.1, "hit-stop aplicado")
	OS.delay_msec(80)
	game._time_fx()
	check(Engine.time_scale == 1.0, "hit-stop se libera solo")
	# pausar durante hit-stop
	game._stop_cool = 0
	game.hitstop(0.5)
	game._time_fx()
	game._set_pause(true)
	game._time_fx()
	check(Engine.time_scale == 1.0, "pausa durante hit-stop")
	game._set_pause(false)
	game.clear_time_fx()

	# --- pausa: reiniciar desde el menu de pausa registra puntaje
	sim(5.0, true)
	var sc: int = game.score
	check(sc > 0, "se sumo puntaje (%d)" % sc)
	game._set_pause(true)
	game._pause_click(game.Hud.BTN_RESTART.get_center())
	check(game.state == "play" and not paused and game.score == 0, "reiniciar desde pausa")
	check(game.top.size() == 1 and game.top[0]["score"] == sc, "reiniciar desde pausa guarda el puntaje")
	# clicks en pausa no disparan
	game._set_pause(true)
	game._pause_click(game.Hud.VOL_BAR.get_center())
	check(absf(game.sfx.level - 0.5) < 0.02, "click en la barra de volumen")
	click(MOUSE_BUTTON_LEFT, Vector2(5, 5))
	check(not game.mouse_down, "click en pausa no dispara")
	game._pause_click(game.Hud.BTN_RESUME.get_center())
	check(game.state == "play", "boton continuar")

	# --- volumen y mute
	key(KEY_M)
	check(game.sfx.muted and game.sfx.music.volume_db <= -79.0, "M silencia la musica")
	key(KEY_M)
	check(not game.sfx.muted and game.sfx.music.volume_db > -40.0, "M reactiva la musica")
	for i in 20:
		key(KEY_EQUAL)
	check(game.sfx.level == 1.0, "volumen tope 1.0")
	for i in 20:
		key(KEY_MINUS)
	check(game.sfx.level == 0.0 and game.sfx.music.volume_db <= -79.0, "volumen minimo silencia")
	game._set_volume(0.7)

	# --- game over, estadisticas, bloqueo de reinicio accidental y ranking
	sim(20.0, true)
	var wave_before: int = game.wave
	var score_before: int = game.score
	kill_kind()
	check(game.state == "over", "muerte -> game over")
	check(game.rank_idx >= 0 and game.top.size() >= 1, "puntaje entra al ranking")
	check(not game.player.visible, "jugador oculto al morir")
	click()
	check(game.state == "over", "click inmediato no reinicia (bloqueo)")
	game._time_fx()
	check(Engine.time_scale == 1.0 or Engine.time_scale == 0.05, "time_scale sano en game over")
	sim(1.0, false, false)
	click(MOUSE_BUTTON_WHEEL_UP)
	check(game.state == "over", "la rueda del mouse no reinicia")
	click()
	check(game.state == "play" and game.score == 0 and game.player.visible, "click reinicia tras el bloqueo")
	check(score_before >= 0 and wave_before >= 1, "oleada alcanzada registrada")

	# --- ranking: orden, tope de 5 y persistencia en disco
	for pts in [100, 5000, 300, 2500, 50, 9000, 700]:
		game.score = pts
		game.wave = 3
		game.run_registered = false
		game._register_run()
	check(game.top.size() == 5, "ranking limitado a 5")
	var ok := true
	for i in range(game.top.size() - 1):
		ok = ok and game.top[i]["score"] >= game.top[i + 1]["score"]
	check(ok and game.top[0]["score"] == 9000, "ranking ordenado desc")
	var c := ConfigFile.new()
	check(c.load(TEST_SAVE) == OK and (c.get_value("scores", "top", []) as Array).size() == 5, "ranking persistido en disco")
	game.top.clear()
	game._load_save()
	check(game.top.size() == 5 and game.hiscore == 9000, "ranking se recarga")

	# --- oleadas 1..15: dificultad monotona, jefe cada 5, sin errores ni fugas
	var prev: Dictionary = {}
	for n in range(1, 16):
		var d: Dictionary = game.K.diff(n)
		if not prev.is_empty():
			check(d["hp"] >= prev["hp"] and d["gap"] <= prev["gap"] and d["cd"] <= prev["cd"] and d["tele"] <= prev["tele"], "dificultad monotona en oleada %d" % n)
		prev = d
	game.start_game()
	var bosses := 0
	var seen_wave := 0
	var steps := 0
	while game.wave < 15 and steps < 60000:
		steps += 1
		game.player.hp = 100.0
		game.player.inv = 1.0
		if steps % 20 == 0:
			for e in game.enemies:
				if not e.dying:
					if e.type == "boss":
						bosses += 1
					game.damage_enemy(e, 9999.0, Vector2(e.x, e.box().y - 20), false)
					break
		game.update(DT)
		if game.wave != seen_wave:
			seen_wave = game.wave
			check(game.queue.size() <= 40, "cola razonable en oleada %d" % seen_wave)
	check(game.wave == 15, "se alcanzo la oleada 15 (wave=%d)" % game.wave)
	check(bosses >= 2, "aparecieron jefes (%d)" % bosses)
	sim(3.0, true)
	check(game.shells.size() < 80 and game.enemies.size() < 40, "sin acumulacion de proyectiles/enemigos")
	check(game.fx._emitters <= game.fx.MAX_EMITTERS + 10, "emisores de particulas acotados")

	# --- final: reinicio total y limpieza del archivo temporal
	game.start_game()
	game._time_fx()
	check(Engine.time_scale == 1.0, "time_scale final 1.0")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("RESULT state=%s wave=%d score=%d enemies=%d shells=%d fails=%d" % [game.state, game.wave, game.score, game.enemies.size(), game.shells.size(), fails])
	quit(1 if fails > 0 else 0)
