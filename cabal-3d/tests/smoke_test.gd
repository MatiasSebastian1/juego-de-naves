extends SceneTree
# Prueba de humo sin cabeza: simula partidas completas con el piloto automatico y verifica todos los tipos de
# enemigo y el jefe, oleadas 1..15, drops, granadas, pausa, reinicio, game over, ranking persistido y que
# Engine.time_scale siempre vuelva a su valor base.
#   godot --headless --path . --script res://tests/smoke_test.gd
# Imprime "RESULT ..." y sale con codigo 1 si algun chequeo falla.

const TEST_SAVE := "user://smoke_test3d.cfg"

var game
var started := false
var fails := 0
var checks := 0

func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	game.time_base = 6.0     # simula 6x mas rapido que el tiempo real
	game._update_time_scale()

func check(cond: bool, msg: String) -> void:
	checks += 1
	if OS.get_environment("SMOKE_VERBOSE") != "":
		print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		fails += 1
		printerr("FALLO: ", msg)

# avanza `sec` segundos de juego (frames de fisica)
func sim(sec: float) -> void:
	var t0: float = game.time
	while game.time - t0 < sec:
		await physics_frame

func key(code: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.pressed = true
	game._input(ev)

func click() -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	game._input(ev)
	ev.pressed = false
	game._input(ev)

func kill_all() -> void:
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and not e.dying:
			e.take_hit(1e6, e.global_position + Vector3(0, 1, 0), false, Vector3.FORWARD)

func _process(delta: float) -> bool:
	if not started:
		started = true
		_run()
	return false

func _run() -> void:
	game.save_path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	game._load_save()
	check(game.top.is_empty(), "ranking inicial vacio")
	await sim(0.5)
	check(game.state == "menu", "arranca en el menu")
	check(game.level.covers.size() >= 20, "el nivel tiene coberturas (%d)" % game.level.covers.size())
	check(game.level.cover_points.size() >= 40, "hay puntos de cobertura para la IA (%d)" % game.level.cover_points.size())
	# --- composicion de oleadas
	for n in range(1, 16):
		var q: Array = game.compose(n)
		check(q.size() > 0, "oleada %d tiene enemigos" % n)
		check((q[0] == "boss") == (n % 5 == 0), "jefe solo cada 5 oleadas (oleada %d)" % n)
	# --- pathing de la grilla
	var path: PackedVector3Array = game.level.find_path(Vector3(-25, 0, -25), Vector3(25, 0, 25))
	check(path.size() >= 1 and path[path.size() - 1].distance_to(Vector3(25, 0, 25)) < 3.0, "A* encuentra camino de esquina a esquina")

	# --- iniciar con click, partida automatica
	click()
	check(game.state == "play", "click en el menu inicia la partida")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "mouse capturado en juego")
	game.bot = true
	game.god = true
	await sim(8.0)
	check(game.wave == 1, "arranca la oleada 1 (wave=%d)" % game.wave)
	check(game.enemies.size() > 0, "hay enemigos en la oleada 1")
	var p = game.player
	check(p.camera.is_current(), "la camara del jugador esta activa")
	await sim(20.0)
	check(game.shots > 0 and game.accuracy() <= 100, "estadisticas de disparos (%d tiros)" % game.shots)
	check(game.kills > 0, "el bot mato enemigos (kills=%d)" % game.kills)
	check(p.ammo < 30 or p.reserve < 120, "se consumio municion")

	# --- todos los tipos de enemigo + jefe
	kill_all()
	await sim(2.0)
	var types := ["rifleman", "runner", "heavy", "grenadier", "boss"]
	var spawned := {}
	for i in types.size():
		var e = game.spawn_enemy(types[i], game.level.spawn_pos(p.global_position, 14.0))
		spawned[types[i]] = e
		check(e.hp > 0.0 and e.model != null, "enemigo %s creado" % types[i])
	check(spawned["boss"].scale_f > 2.0 and spawned["heavy"].scale_f > 1.3, "escalas de jefe y pesado")
	await sim(25.0)
	var alive_types := {}
	for e in game.enemies:
		if is_instance_valid(e) and not e.dying:
			alive_types[e.type] = true
	check(game.kills > 3, "siguen las bajas con todos los tipos")
	# disparos enemigos y granadas: forzar y verificar efectos
	game.god = false
	p.hp = 100.0
	var hp0: float = p.hp
	p.inv_t = 0.0
	p.take_damage(10.0, Vector3(5, 0, 5))
	check(p.hp < hp0, "el jugador recibe dano")
	p.inv_t = 0.5
	p.take_damage(10.0, Vector3(5, 0, 5))
	check(p.hp == hp0 - 10.0, "invulnerable mientras rueda/inv_t")
	game.god = true
	var ng: int = game.grenades.size()
	var gren0: int = p.gren
	p.p_gren = true
	await sim(0.2)
	check(p.gren == gren0 - 1 or gren0 == 0, "granada del jugador consumida")
	var gr = game.throw_grenade(p.global_position + Vector3(0, 1.5, 0), p.global_position + Vector3(8, 0, -8), false)
	check(game.grenades.has(gr), "granada enemiga en vuelo")
	await sim(3.5)
	check(not is_instance_valid(gr) and not game.grenades.has(gr), "la granada explota y se libera")
	# agacharse y rodar
	p.p_crouch = true
	await sim(0.4)
	check(p.crouched, "C agacha")
	p.p_crouch = true
	await sim(0.4)
	check(not p.crouched, "C vuelve a pararse")
	game.manual = true
	p.in_fire = false
	p.in_aim = false
	p.in_move = Vector2(0, 1)
	await sim(0.3)
	p.p_jump = true
	await sim(0.15)
	check(p.roll_t > 0.0 and p.inv_t > 0.0, "espacio en movimiento rueda con invulnerabilidad")
	await sim(1.2)
	p.in_move = Vector2.ZERO
	await sim(0.5)
	p.p_jump = true
	await sim(0.1)
	check(p.velocity.y > 1.0 or not p.is_on_floor(), "espacio quieto salta")
	await sim(1.0)

	# --- drops y armas temporales
	var drops := []
	for k in ["hp", "ammo", "gren", "spread", "burst"]:
		drops.append(game.spawn_pickup(k, p.global_position + Vector3(0.3, 0, 0.3)))
	await sim(0.5)
	game.manual = false
	var left := 0
	for d in drops:
		if is_instance_valid(d) and game.pickups.has(d):
			left += 1
	check(left == 0, "los drops se recogen caminando encima (%d sin recoger)" % left)
	check(p.weapon == "burst" or p.weapon == "spread", "arma temporal activa (%s)" % p.weapon)
	await sim(3.0)

	# --- jefe: muerte, camara lenta y retorno a time_scale base
	kill_all()
	await sim(1.5)
	var bo = game.spawn_enemy("boss", game.level.spawn_pos(p.global_position, 20.0))
	await sim(1.0)
	bo.take_hit(bo.hp * 0.6, bo.global_position + Vector3(0, 3, 0), false, Vector3.FORWARD)
	await sim(2.0)
	check(bo.enraged, "el jefe se enfurece por debajo del 50%")
	bo.take_hit(1e7, bo.global_position + Vector3(0, 4.2, 0), true, Vector3.FORWARD)
	check(bo.dying, "el jefe muere")
	check(Engine.time_scale < game.time_base, "camara lenta tras matar al jefe")
	while Time.get_ticks_msec() < game.slow_until + 300:
		await physics_frame
	await sim(0.3)
	check(is_equal_approx(Engine.time_scale, game.time_base), "time_scale vuelve al valor base")
	check(game.score > 0 and game.best_streak >= 1, "puntaje y combo")

	# --- pausa
	var pos_before := []
	for e in game.enemies:
		pos_before.append(e.global_position)
	key(KEY_P)
	check(game.state == "pause" and paused, "P pausa")
	if DisplayServer.get_name() != "headless":
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse liberado en pausa")
	await sim(1.0)
	var same := true
	for i in game.enemies.size():
		if i < pos_before.size() and is_instance_valid(game.enemies[i]) and game.enemies[i].global_position.distance_to(pos_before[i]) > 0.01:
			same = false
	check(same, "los enemigos no se mueven en pausa")
	game._pause_click(game.hud.BTN_MUTE.get_center())
	check(game.sfx.muted, "boton de musica")
	game._pause_click(game.hud.BTN_MUTE.get_center())
	check(not game.sfx.muted, "boton de musica (alterna)")
	game._pause_click(game.hud.BTN_RESUME.get_center())
	check(game.state == "play" and not paused, "boton continuar reanuda")
	key(KEY_ESCAPE)
	check(game.state == "pause", "Esc pausa")
	key(KEY_ESCAPE)
	check(game.state == "play", "Esc reanuda")

	# --- reinicio limpia todo
	game.start_game()
	check(game.enemies.is_empty() and game.grenades.is_empty() and game.pickups.is_empty(), "reinicio limpia entidades")
	check(game.score == 0 and game.kills == 0 and game.shots == 0 and game.wave == 0, "reinicio limpia estadisticas")
	check(p.hp == p.max_hp and p.gren == 3 and p.ammo == 30 and p.weapon == "rifle", "reinicio restablece al jugador")
	check(is_equal_approx(Engine.time_scale, game.time_base), "time_scale base tras reiniciar")

	# --- oleadas 1..15 acortadas: avanzar con el bot, matando a los enemigos
	game.bot = true
	game.god = true
	game.inter_t = 0.0
	var seen_boss := false
	var max_alive := 0
	var guard := 0
	while game.state == "play" and guard < 15 * 40:
		guard += 1
		await sim(0.5)
		if game.wave_state == "spawning" and game.queue.size() > 3:
			game.queue.resize(3 if game.wave % 5 != 0 else 4)
		for e in game.enemies:
			if is_instance_valid(e) and e.type == "boss":
				seen_boss = true
		max_alive = maxi(max_alive, game.alive_count())
		if game.wave_state == "spawning" and game.alive_count() > 0 and guard % 3 == 0:
			kill_all()
		if game.wave_state == "intermission":
			game.inter_t = minf(game.inter_t, 0.3)
	check(seen_boss, "aparecio al menos un jefe en 15 oleadas")
	check(game.state == "over" and game.victory, "completar la oleada 15 da la victoria (state=%s wave=%d)" % [game.state, game.wave])
	check(max_alive <= 13, "tope de enemigos simultaneos (%d)" % max_alive)
	check(game.top.size() == 1 and game.rank_idx == 0, "ranking guardado tras la victoria")

	# --- game over por muerte
	await sim(1.5)
	click()
	check(game.state == "play", "click en game over reinicia")
	game.bot = false
	game.god = false
	game.score = 4321
	game.kills = 7
	game.shots = 100
	game.hits = 40
	game.player.hp = 5.0
	game.player.inv_t = 0.0
	game.player.take_damage(50.0, Vector3(3, 0, 3))
	check(game.player.dead, "el jugador muere")
	await sim(2.4)
	check(game.state == "over" and not game.victory, "game over tras morir")
	check(game.accuracy() == 40, "precision 40%% (%d)" % game.accuracy())
	check(game.top.size() == 2, "ranking con 2 entradas (%d)" % game.top.size())
	check(game.top[0]["score"] >= game.top[1]["score"], "ranking ordenado")
	var cf := ConfigFile.new()
	check(cf.load(TEST_SAVE) == OK and cf.get_value("rank", "top", []).size() == 2, "ranking persistido en disco")
	await sim(1.5)
	key(KEY_ENTER)
	check(game.state == "play", "ENTER reinicia desde game over")
	# --- volver al menu desde la pausa
	key(KEY_P)
	key(KEY_Q)
	check(game.state == "menu", "Q en pausa vuelve al menu")
	check(not paused, "el arbol no queda en pausa en el menu")
	check(is_equal_approx(Engine.time_scale, game.time_base), "time_scale base al final")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	var summary := "RESULT checks=%d fails=%d" % [checks, fails]
	game.queue_free()
	await process_frame
	await process_frame
	preload("res://scripts/assets.gd")._scenes.clear()
	preload("res://scripts/assets.gd")._lit.clear()
	preload("res://scripts/model.gd")._anim_cache.clear()
	print(summary)
	quit(1 if fails > 0 else 0)
