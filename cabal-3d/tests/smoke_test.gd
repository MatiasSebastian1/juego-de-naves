extends SceneTree
# Prueba de humo sin cabeza: simula partidas completas con el piloto automatico y verifica todos los tipos de
# enemigo y el jefe, oleadas 1..15, drops, granadas, pausa, reinicio, game over, ranking persistido y que
# Engine.time_scale siempre vuelva a su valor base.
#   godot --headless --path . --script res://tests/smoke_test.gd
#   SMOKE_ARENA=kenney godot --headless --path . --script res://tests/smoke_test.gd    (patio Kenney de respaldo)
# Imprime "RESULT ..." y sale con codigo 1 si algun chequeo falla. Con la arena Meshy ademas comprueba la navegacion
# horneada: puntos de aparicion, suelo, rutas, linea de vision de los enemigos y limites.

const TEST_SAVE := "user://smoke_test3d.cfg"

var game
var started := false
var fails := 0
var checks := 0

func _initialize() -> void:
	if OS.get_environment("SMOKE_ARENA") == "kenney":
		preload("res://scripts/level.gd").force_fallback = true
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

# capsula de un enemigo estandar en `pos` (algo elevada): true si no toca la geometria del mundo
func _clear_of_world(pos: Vector3, r := 0.42, h := 1.84) -> bool:
	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = h
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1
	q.transform = Transform3D(Basis(), pos + Vector3(0, h * 0.5 + 0.12, 0))
	return game.world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

# --- comprobaciones de la arena Meshy (navegacion horneada, suelo, rutas, limites)
func _arena_checks() -> void:
	var lv = game.level
	var p = game.player
	check(lv.village != null and lv.village.get_node_or_null("VillageBody") != null, "la aldea tiene cuerpo de colision (trimesh)")
	check(lv.reach_cells >= 2500, "zona alcanzable amplia (%d celdas)" % lv.reach_cells)
	check(lv.water_cells >= 1, "se detecto agua en el estanque (%d)" % lv.water_cells)
	check(lv.spawn_points.size() >= 12, "puntos de aparicion repartidos (%d)" % lv.spawn_points.size())
	check(lv.bake_ms < 8000, "horneado de navegacion rapido (%d ms)" % lv.bake_ms)
	check(lv.is_free(lv.start_pos) and _clear_of_world(lv.start_pos, 0.38, 1.8), "el jugador empieza en espacio libre")
	check(absf(lv.start_pos.y - lv.ground_y(lv.start_pos)) < 0.5, "el inicio esta sobre el suelo")
	check(absf(p.global_position.y - lv.start_pos.y) < 0.6 and p.global_position.distance_to(lv.start_pos) < 1.0, "el jugador aparece en el inicio")
	# cada punto de aparicion: celda libre, sobre el suelo, sin tocar edificios y con ruta hasta el jugador
	var bad_free := 0
	var bad_ground := 0
	var bad_clear := 0
	var bad_path := 0
	for sp in lv.spawn_points:
		if not lv.is_free(sp):
			bad_free += 1
		if absf(sp.y - lv.ground_y(sp)) > 0.5:
			bad_ground += 1
		if not _clear_of_world(sp):
			bad_clear += 1
		var pth: PackedVector3Array = lv.find_path(sp, lv.start_pos)
		var ok := pth.size() >= 1 and pth[pth.size() - 1].distance_to(lv.nearest_free(lv.start_pos)) < 0.6
		for q in pth:
			if not lv.is_free(q):
				ok = false
		if not ok:
			bad_path += 1
	check(bad_free == 0, "todos los puntos de aparicion en celda libre (%d fallan)" % bad_free)
	check(bad_ground == 0, "todos los puntos de aparicion sobre el suelo (%d fallan)" % bad_ground)
	check(bad_clear == 0, "ningun punto de aparicion dentro de un edificio (%d fallan)" % bad_clear)
	check(bad_path == 0, "todos los puntos de aparicion tienen ruta al jugador (%d fallan)" % bad_path)
	# spawn_pos con el jugador en muchos lugares: libre, a distancia razonable y fuera de edificios
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 7
	var free_cells: Array = []
	for x in lv.gn:
		for y in lv.gn:
			if not lv.grid.is_point_solid(Vector2i(x, y)):
				free_cells.append(lv._cell_pos(Vector2i(x, y)))
	var sp_bad := 0
	var sp_near := 0
	for i in 300:
		var pp: Vector3 = free_cells[rnd.randi() % free_cells.size()]
		var s2: Vector3 = lv.spawn_pos(pp, 18.0)
		if not lv.is_free(s2) or not _clear_of_world(s2) or absf(s2.y - lv.ground_y(s2)) > 0.5:
			sp_bad += 1
		if s2.distance_to(pp) < 14.0:
			sp_near += 1
	check(sp_bad == 0, "300 apariciones: libres, sobre el suelo y fuera de edificios (%d fallan)" % sp_bad)
	check(sp_near < 30, "las apariciones no son encima del jugador (%d de 300 a menos de 14 m)" % sp_near)
	# rutas entre celdas libres al azar
	var path_bad := 0
	for i in 60:
		var a: Vector3 = free_cells[rnd.randi() % free_cells.size()]
		var b: Vector3 = free_cells[rnd.randi() % free_cells.size()]
		var pth: PackedVector3Array = lv.find_path(a, b)
		if pth.is_empty() or pth[pth.size() - 1].distance_to(b) > 0.6:
			path_bad += 1
	check(path_bad == 0, "60 rutas aleatorias entre celdas libres (%d sin ruta)" % path_bad)
	# las celdas libres son transitables: el suelo bajo ellas es una superficie caminable
	var flat_bad := 0
	for i in 200:
		var c: Vector3 = free_cells[rnd.randi() % free_cells.size()]
		if absf(c.y - lv.ground_y(c, 0.5)) > 0.9:
			flat_bad += 1
	check(flat_bad < 6, "altura de la grilla coincide con el suelo (%d de 200 discrepan)" % flat_bad)
	# muros: un rayo contra un punto de cobertura de edificio choca; los props bajos tambien estan en el mundo
	var walls := 0
	var wall_hit := 0
	for cp in lv.cover_points:
		if not cp.low:
			walls += 1
			var from: Vector3 = cp.pos + Vector3(0, 1.2, 0)
			var q := PhysicsRayQueryParameters3D.create(from, from - cp.dir * 4.0, 1)
			if not game.world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				wall_hit += 1
	check(walls >= 30 and wall_hit >= int(walls * 0.9), "puntos de cobertura en muros reales (%d de %d con pared detras)" % [wall_hit, walls])
	# disparos bloqueados por edificios: rayo del inicio a traves de la casa mas cercana no llega al otro lado
	var blocked := 0
	for k in 12:
		var a: Vector3 = free_cells[rnd.randi() % free_cells.size()] + Vector3(0, 1.4, 0)
		var b: Vector3 = free_cells[rnd.randi() % free_cells.size()] + Vector3(0, 1.4, 0)
		var q := PhysicsRayQueryParameters3D.create(a, b, 1)
		if not game.world.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			blocked += 1
	check(blocked >= 3, "los disparos se bloquean con edificios y muros (%d de 12 rayos)" % blocked)
	# enemigos de todas las oleadas: sobre el suelo y en celda libre tras asentarse
	var n_checked := 0
	var e_floor := 0
	var e_free := 0
	var e_clear := 0
	for wv in [1, 2, 3, 4, 5, 8, 10, 15]:
		var q2: Array = game.compose(wv)
		for i in mini(q2.size(), 12):
			game.wave = wv
			var e = game.spawn_enemy(q2[i], lv.spawn_pos(p.global_position, 22.0 if q2[i] == "boss" else 18.0, 2.4 if q2[i] == "boss" else 1.6))
			e.set_physics_process(false)     # solo se comprueba el punto de aparicion
		for e in game.enemies:
			if not lv.is_free(e.global_position) or not _clear_of_world(e.global_position - Vector3(0, 0.08, 0), e.capsule.radius, e.capsule.height):
				e_clear += 1
		for e in game.enemies:
			e.set_physics_process(true)
		await sim(0.6)
		for e in game.enemies:
			n_checked += 1
			if e.is_on_floor() and absf(e.global_position.y - lv.ground_y(e.global_position)) < 0.4:
				e_floor += 1
			if lv.is_free(e.global_position):
				e_free += 1
		kill_all()
		await sim(0.2)
		for e in game.enemies.duplicate():
			if is_instance_valid(e):
				e.queue_free()
		game.enemies.clear()
	check(n_checked > 60 and e_clear == 0, "%d enemigos de 8 oleadas aparecen en celda libre sin tocar edificios (%d fallan)" % [n_checked, e_clear])
	check(e_floor >= n_checked - 1, "los enemigos quedan apoyados en el suelo (%d de %d)" % [e_floor, n_checked])
	check(e_free >= n_checked - 2, "los enemigos siguen en celda libre tras asentarse (%d de %d)" % [e_free, n_checked])
	# limites invisibles: el jugador no sale del area jugable
	var edge: Vector3 = lv.open_spot(Vector2(lv.half - 6.0, 0.0), 2.0)
	p.global_position = edge + Vector3(0, 0.1, 0)
	p.velocity = Vector3.ZERO
	game.manual = true
	game.state = "play"
	p.yaw = 0.0
	p.in_move = Vector2(1, 0)
	p.in_sprint = true
	await sim(3.0)
	p.in_move = Vector2.ZERO
	p.in_sprint = false
	check(absf(p.global_position.x) <= lv.half - 0.3, "el limite invisible frena al jugador (x=%.1f, limite %.1f)" % [p.global_position.x, lv.half])
	game.state = "menu"
	game.manual = false
	p.global_position = lv.start_pos + Vector3(0, 0.1, 0)
	await _player_walk_check()

# el jugador (CharacterBody3D real) recorre rutas de la grilla sin atorarse ni atravesar paredes
func _player_walk_check() -> void:
	var lv = game.level
	var p = game.player
	game.state = "play"
	game.manual = true
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 11
	var free_cells: Array = []
	for x in lv.gn:
		for y in lv.gn:
			if lv.clearance[y * lv.gn + x] >= 2.0:
				free_cells.append(lv._cell_pos(Vector2i(x, y)))
	var ok := 0
	var through := 0
	var n := 6
	var cur: Vector3 = lv.start_pos
	for i in n:
		var target: Vector3 = free_cells[rnd.randi() % free_cells.size()]
		for k in 30:
			if cur.distance_to(target) > 25.0:
				break
			target = free_cells[rnd.randi() % free_cells.size()]
		p.global_position = cur + Vector3(0, 0.1, 0)
		p.velocity = Vector3.ZERO
		await sim(0.2)
		var path: PackedVector3Array = lv.find_path(cur, target)
		var arrived := true
		for wp in path:
			var t0: float = game.time
			var last: Vector3 = p.global_position
			var last_t: float = game.time
			while Vector2(wp.x - p.global_position.x, wp.z - p.global_position.z).length() > 0.7:
				var d: Vector3 = wp - p.global_position
				d.y = 0.0
				d = d.normalized()
				p.yaw = atan2(-d.x, -d.z)
				p.in_move = Vector2(0, 1)
				await physics_frame
				if absf(p.global_position.y - lv.ground_y(p.global_position)) > 6.0:
					through += 1
					arrived = false
					break
				if game.time - last_t > 1.5:
					if p.global_position.distance_to(last) < 0.5:
						arrived = false
						break
					last = p.global_position
					last_t = game.time
				if game.time - t0 > 25.0:
					arrived = false
					break
			if not arrived:
				break
		if arrived:
			ok += 1
		else:
			print("jugador atorado en ruta %d: de %s a %s, pos %s" % [i, cur, target, p.global_position])
		cur = target
	p.in_move = Vector2.ZERO
	check(through == 0, "el jugador nunca atraviesa el suelo")
	check(ok >= n - 1, "el jugador recorre rutas de la grilla sin atorarse (%d de %d)" % [ok, n])
	game.state = "menu"
	game.manual = false
	p.global_position = lv.start_pos + Vector3(0, 0.1, 0)

# IA en la arena: con el jugador quieto, los enemigos llegan a verlo (ruta + linea de vision) y no se atoran
func _arena_ai_check() -> void:
	var lv = game.level
	var p = game.player
	game.bot = false
	game.manual = true
	game.god = true
	p.in_move = Vector2.ZERO
	p.in_fire = false
	p.in_aim = false
	kill_all()
	await sim(1.5)
	for e in game.enemies.duplicate():
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()
	game.wave_state = "idle"
	game.queue.clear()
	game.wave = 6
	var squad: Array = []
	for t in ["rifleman", "runner", "heavy", "grenadier"]:
		for i in 4:
			squad.append(game.spawn_enemy(t, lv.spawn_pos(p.global_position, 20.0)))
	var stuck_start := 0
	await sim(40.0)
	var seen := 0
	var stuck := 0
	var inside := 0
	var on_floor := 0
	var closest := 0
	for e in squad:
		if not is_instance_valid(e):
			continue
		if e.ever_los:
			seen += 1
		stuck += e.stuck_events
		if absf(e.global_position.x) <= lv.half and absf(e.global_position.z) <= lv.half:
			inside += 1
		if e.is_on_floor():
			on_floor += 1
		if e.global_position.distance_to(p.global_position) < 40.0:
			closest += 1
	var frac := float(seen) / float(squad.size())
	print("IA arena: LOS %d/%d, atoranques %d (%.1f por enemigo), en el suelo %d, dentro %d" % [seen, squad.size(), stuck, float(stuck) / squad.size(), on_floor, inside])
	check(frac >= 0.75, "los enemigos llegan a tener linea de vision al jugador (%d de %d)" % [seen, squad.size()])
	check(float(stuck) / squad.size() <= 4.0, "pocos atoranques (%.1f por enemigo en 40 s)" % [float(stuck) / squad.size()])
	check(inside == squad.size(), "todos los enemigos siguen dentro del area jugable (%d de %d)" % [inside, squad.size()])
	check(on_floor >= squad.size() - 1, "los enemigos caminan sobre el terreno (%d de %d en el suelo)" % [on_floor, squad.size()])
	for e in squad:
		if is_instance_valid(e) and not e.dying:
			e.take_hit(1e6, e.global_position + Vector3(0, 1, 0), false, Vector3.FORWARD)
	await sim(2.0)
	game.manual = false
	game.god = false

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
	var lv = game.level
	var pa: Vector3 = lv.spawn_points[0]
	var pb: Vector3 = lv.spawn_points[lv.spawn_points.size() / 2]
	var path: PackedVector3Array = lv.find_path(pa, pb)
	check(path.size() >= 1 and path[path.size() - 1].distance_to(pb) < 3.0, "A* encuentra camino entre puntos de aparicion lejanos")
	if lv.meshy:
		await _arena_checks()
	else:
		check(not lv.meshy and lv.half == 30.0, "fallback: patio Kenney activo")

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

	if game.level.meshy:
		await _arena_ai_check()
		game.start_game()

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
