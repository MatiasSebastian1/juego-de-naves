extends Node
# Cabal 3D: orquesta el estado del juego (menu / juego / pausa / game over), las oleadas, el puntaje, los drops,
# el postproceso, la interfaz y el guardado del ranking. La logica de gameplay corre en _physics_process.

const Level = preload("res://scripts/level.gd")
const Fx = preload("res://scripts/fx.gd")
const Player = preload("res://scripts/player.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Grenade = preload("res://scripts/grenade.gd")
const Pickup = preload("res://scripts/pickup.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Hud = preload("res://scripts/hud.gd")
const POST_SHADER := preload("res://shaders/post.gdshader")

const MAX_WAVE := 15

var state := "menu"          # menu | play | pause | over
var time := 0.0
var god := false             # invulnerable (pruebas)
var bot := false             # piloto automatico (pruebas)
var manual := false          # las pruebas fijan las intenciones del jugador a mano
var time_base := 1.0         # multiplicador de tiempo (las pruebas lo suben)
var slow_until := 0

var world: Node3D
var level
var fx
var player
var enemies_root: Node3D
var proj_root: Node3D
var pick_root: Node3D
var sfx
var hud
var post_mat: ShaderMaterial
var menu_cam: Camera3D

var enemies: Array = []
var pickups: Array = []
var grenades: Array = []

var wave := 0
var wave_state := "idle"     # idle | intermission | spawning
var queue: Array = []
var spawn_t := 0.0
var inter_t := 0.0
var victory := false
var ending_t := -1.0

var score := 0
var kills := 0
var shots := 0
var hits := 0
var streak := 0
var streak_t := 0.0
var best_streak := 0
var run_time := 0.0
var hiscore := 0
var top: Array = []
var rank_idx := -1
var save_path := "user://cabal3d.cfg"
var over_t := 0.0
const OVER_LOCK := 1.2

var banner_text := ""
var banner_t := 0.0
var toast_text := ""
var toast_t := 0.0
var hit_t := 0.0
var hit_head := false
var hit_kill := false
var head_t := 0.0
var dmg_ind: Array = []      # {pos, t}
var hurt_amt := 0.0
var bot_t := 0.0
var bot_strafe := 1.0
var bot_gren_t := 6.0
var ready_done := false      # false mientras se hornea la navegacion de la arena (un frame de fisica)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = Node3D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	fx = Fx.new()
	fx.game = self
	world.add_child(fx)
	level = Level.new()
	world.add_child(level)
	level.build(fx)
	if level.meshy:
		# la fisica solo responde a consultas tras un frame: horneado de navegacion de la arena Meshy
		await get_tree().physics_frame
		level.bake()
		fx.fit_motes(level.half)
	enemies_root = Node3D.new()
	world.add_child(enemies_root)
	proj_root = Node3D.new()
	world.add_child(proj_root)
	pick_root = Node3D.new()
	world.add_child(pick_root)
	sfx = Sfx.new()
	add_child(sfx)
	player = Player.new()
	player.game = self
	player.level = level
	player.fx = fx
	world.add_child(player)
	player.reset()
	menu_cam = Camera3D.new()
	menu_cam.fov = 62.0
	menu_cam.far = 400.0
	world.add_child(menu_cam)
	# postproceso (debajo de la interfaz)
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST_SHADER
	cr.material = post_mat
	pl.add_child(cr)
	var hl := CanvasLayer.new()
	hl.layer = 2
	add_child(hl)
	hud = Hud.new()
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.add_child(hud)
	_load_save()
	ready_done = true
	_enter_menu()

func _enter_menu() -> void:
	state = "menu"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_cam.make_current()
	sfx.start_music()
	sfx.music_volume(-13.0)
	_update_time_scale()

# ---------------------------------------------------------------- partida

func start_game() -> void:
	_clear_entities()
	player.reset()
	score = 0
	kills = 0
	shots = 0
	hits = 0
	streak = 0
	streak_t = 0.0
	best_streak = 0
	run_time = 0.0
	wave = 0
	victory = false
	ending_t = -1.0
	rank_idx = -1
	over_t = 0.0
	dmg_ind.clear()
	hurt_amt = 0.0
	banner_t = 0.0
	toast_t = 0.0
	hit_t = 0.0
	slow_until = 0
	state = "play"
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.camera.make_current()
	sfx.start_music()
	sfx.music_volume(-11.0)
	wave_state = "intermission"
	inter_t = 1.6
	banner("PREPARATE", 1.5)
	_update_time_scale()

func _clear_entities() -> void:
	for e in enemies:
		if is_instance_valid(e):
			if e.aim_ring:
				e.aim_ring.queue_free()
			e.queue_free()
	enemies.clear()
	for g in grenades.duplicate():
		if is_instance_valid(g):
			g.cleanup()
	grenades.clear()
	for p in pickups:
		if is_instance_valid(p):
			p.queue_free()
	pickups.clear()
	for c in level.cover_points:
		c.taken = null
	fx.clear()
	queue.clear()

func set_pause(on: bool) -> void:
	if on and state == "play":
		state = "pause"
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		player.in_fire = false
		player.in_aim = false
		sfx.music_volume(-20.0)
		_update_time_scale()
	elif not on and state == "pause":
		state = "play"
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		sfx.music_volume(-11.0)
		_update_time_scale()

func to_menu() -> void:
	get_tree().paused = false
	_clear_entities()
	player.reset()
	wave_state = "idle"
	_enter_menu()

func end_game(win := false) -> void:
	if state == "over":
		return
	victory = win
	state = "over"
	over_t = 0.0
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.in_fire = false
	player.in_aim = false
	slow_until = 0
	_update_time_scale()
	hiscore = maxi(hiscore, score)
	var entry := {"score": score, "wave": wave, "kills": kills}
	top.append(entry)
	top.sort_custom(func(a, b): return a["score"] > b["score"])
	rank_idx = top.find(entry)
	if top.size() > 5:
		top.resize(5)
	if rank_idx >= 5:
		rank_idx = -1
	_save()
	sfx.play("wave" if win else "over", 0.0)
	sfx.music_volume(-18.0)

func player_died() -> void:
	ending_t = 1.9
	banner("", 0.0)

func accuracy() -> int:
	if shots <= 0:
		return 0
	return mini(100, int(round(100.0 * hits / float(shots))))

func mult() -> int:
	return mini(5, 1 + streak / 4)

func banner(t: String, d := 2.0) -> void:
	banner_text = t
	banner_t = d

func toast(t: String) -> void:
	toast_text = t
	toast_t = 2.2

func _update_time_scale() -> void:
	var slow := 1.0
	if state == "play" and Time.get_ticks_msec() < slow_until:
		slow = 0.4
	Engine.time_scale = time_base * slow

# ---------------------------------------------------------------- guardado

func _load_save() -> void:
	var cf := ConfigFile.new()
	hiscore = 0
	top = []
	if cf.load(save_path) == OK:
		hiscore = int(cf.get_value("rank", "hiscore", 0))
		var t = cf.get_value("rank", "top", [])
		if t is Array:
			for e in t:
				if e is Dictionary and e.has("score"):
					top.append({"score": int(e["score"]), "wave": int(e.get("wave", 0)), "kills": int(e.get("kills", 0))})
	top.sort_custom(func(a, b): return a["score"] > b["score"])
	if top.size() > 5:
		top.resize(5)
	if not top.is_empty():
		hiscore = maxi(hiscore, int(top[0]["score"]))

func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("rank", "hiscore", hiscore)
	cf.set_value("rank", "top", top)
	cf.save(save_path)

# ---------------------------------------------------------------- entrada

func _input(event: InputEvent) -> void:
	if not ready_done:
		return
	if event is InputEventMouseMotion:
		if state == "play" and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not bot:
			player.look(event.relative)
	elif event is InputEventMouseButton:
		var pos: Vector2 = event.position
		match state:
			"menu":
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					start_game()
			"play":
				if bot:
					return
				if event.button_index == MOUSE_BUTTON_LEFT:
					player.in_fire = event.pressed
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					player.in_aim = event.pressed
			"pause":
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_pause_click(pos)
			"over":
				if event.pressed and event.button_index == MOUSE_BUTTON_LEFT and over_t > OVER_LOCK:
					start_game()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k == KEY_F11:
			var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)
			return
		if k == KEY_M:
			sfx.set_muted(not sfx.muted)
			return
		if k == KEY_BRACKETLEFT or k == KEY_BRACKETRIGHT:
			player.sens = clampf(player.sens * (0.85 if k == KEY_BRACKETLEFT else 1.18), 0.0008, 0.008)
			toast("Sensibilidad %d%%" % int(round(player.sens / 0.0026 * 100.0)))
			return
		if k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			sfx.set_level(sfx.level - 0.1)
			return
		if k == KEY_EQUAL or k == KEY_KP_ADD:
			sfx.set_level(sfx.level + 0.1)
			return
		match state:
			"menu":
				if k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER:
					start_game()
			"play":
				if k == KEY_ESCAPE or k == KEY_P:
					set_pause(true)
				elif not bot:
					match k:
						KEY_R:
							player.p_reload = true
						KEY_G:
							player.p_gren = true
						KEY_C:
							player.p_crouch = true
						KEY_SPACE:
							player.p_jump = true
			"pause":
				if k == KEY_ESCAPE or k == KEY_P:
					set_pause(false)
				elif k == KEY_R:
					start_game()
				elif k == KEY_Q:
					to_menu()
			"over":
				if (k == KEY_ENTER or k == KEY_SPACE or k == KEY_KP_ENTER) and over_t > OVER_LOCK:
					start_game()

func _pause_click(p: Vector2) -> void:
	if Hud.BTN_RESUME.has_point(p):
		set_pause(false)
	elif Hud.BTN_RESTART.has_point(p):
		start_game()
	elif Hud.BTN_MUTE.has_point(p):
		sfx.set_muted(not sfx.muted)
	elif Hud.BTN_MENU.has_point(p):
		to_menu()
	elif Hud.VOL_BAR.grow(8).has_point(p):
		sfx.set_level((p.x - Hud.VOL_BAR.position.x) / Hud.VOL_BAR.size.x)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and ready_done and state == "play" and not bot:
		set_pause(true)

func _read_intents() -> void:
	var mv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		mv.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		mv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		mv.x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		mv.x -= 1.0
	player.in_move = mv
	player.in_sprint = Input.is_physical_key_pressed(KEY_SHIFT)
	player.in_crouch_hold = Input.is_physical_key_pressed(KEY_CTRL)

# piloto automatico para las pruebas: apunta al enemigo mas cercano, dispara, se mueve y tira granadas
func _bot_intents(delta: float) -> void:
	var best = null
	var bd := 1e9
	for e in enemies:
		if e.dying:
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if e.los:
			d -= 8.0
		if d < bd:
			bd = d
			best = e
	bot_t -= delta
	bot_gren_t -= delta
	if bot_t <= 0.0:
		bot_t = randf_range(0.8, 2.0)
		bot_strafe = -bot_strafe
	if best == null:
		player.in_fire = false
		player.in_move = Vector2(0, 0.3)
		return
	var cam: Camera3D = player.camera
	var tp: Vector3 = best.global_position + Vector3(0, 1.45 * best.scale_f * best.crouch_k, 0)
	var dir: Vector3 = tp - cam.global_position
	var flat := Vector2(dir.x, dir.z).length()
	player.yaw = atan2(-dir.x, -dir.z)
	player.pitch = clampf(atan2(dir.y, flat) , -0.8, 0.6)
	var dist: float = best.global_position.distance_to(player.global_position)
	player.in_aim = true
	player.in_fire = player.aim_over_enemy or dist < 4.0
	var mv := Vector2(bot_strafe * 0.8, 0.0)
	if dist > 18.0:
		mv.y = 1.0
	elif dist < 8.0:
		mv.y = -1.0
	player.in_move = mv
	player.in_sprint = false
	player.in_crouch_hold = false
	if bot_gren_t <= 0.0:
		bot_gren_t = randf_range(6.0, 10.0)
		player.p_gren = true
	if randf() < 0.004:
		player.p_jump = true

# ---------------------------------------------------------------- bucle

func _physics_process(delta: float) -> void:
	if not ready_done:
		return
	time += delta
	if state != "play":
		if state == "over":
			over_t += delta
		return
	run_time += delta
	if manual:
		pass
	elif bot:
		_bot_intents(delta)
	else:
		_read_intents()
	_waves(delta)
	_pickups_tick(delta)
	if streak_t > 0.0:
		streak_t -= delta
		if streak_t <= 0.0:
			streak = 0
	banner_t = maxf(0.0, banner_t - delta)
	toast_t = maxf(0.0, toast_t - delta)
	hit_t = maxf(0.0, hit_t - delta)
	head_t = maxf(0.0, head_t - delta)
	for d in dmg_ind:
		d.t -= delta
	dmg_ind = dmg_ind.filter(func(d): return d.t > 0.0)
	if ending_t > 0.0:
		ending_t -= delta
		if ending_t <= 0.0:
			ending_t = -1.0
			end_game(false)
	if Time.get_ticks_msec() >= slow_until and Engine.time_scale != time_base:
		_update_time_scale()

func _process(delta: float) -> void:
	if not ready_done:
		return
	hurt_amt = maxf(0.0, hurt_amt - delta * 2.4)
	var low := 0.0
	if state == "play" and player.hp < 30.0 and not player.dead:
		low = 0.5 + 0.5 * sin(time * 6.0)
	post_mat.set_shader_parameter("hurt", hurt_amt)
	post_mat.set_shader_parameter("time_s", time)
	post_mat.set_shader_parameter("low_hp", low)
	if state == "menu":
		# camara del menu: orbita lenta cerca del punto de inicio, mirando hacia donde mira el jugador
		var a := time * 0.12
		var sp: Vector3 = level.start_pos
		var f := Vector3(-sin(level.start_yaw), 0.0, -cos(level.start_yaw))
		var r := Vector3(cos(level.start_yaw), 0.0, -sin(level.start_yaw))
		menu_cam.global_position = sp + Vector3(0, 2.3 + sin(a * 0.7) * 0.4, 0) - f * (3.0 + cos(a) * 1.2) + r * (3.6 + sin(a) * 3.5)
		menu_cam.look_at(sp + f * 6.0 + Vector3(0, 1.5, 0), Vector3.UP)
	if state == "over" and not player.dead:
		pass

# ---------------------------------------------------------------- oleadas

func _wave_cap(n: int) -> int:
	return mini(5 + n / 2, 11) + (2 if n % 5 == 0 else 0)

func compose(n: int) -> Array:
	var q: Array = []
	var total := mini(5 + 2 * n, 30)
	var boss := n % 5 == 0
	if boss:
		total = 4 + n / 5 * 3
	for i in total:
		var w := {"rifleman": 1.0}
		if n >= 2:
			w["runner"] = 0.4 + 0.02 * n
		if n >= 3:
			w["grenadier"] = 0.3 + 0.015 * n
		if n >= 4:
			w["heavy"] = 0.18 + 0.02 * n
		var sum := 0.0
		for k in w:
			sum += w[k]
		var r := randf() * sum
		for k in w:
			r -= w[k]
			if r <= 0.0:
				q.append(k)
				break
	if n == 2:
		q[0] = "runner"
	if n == 3:
		q[1] = "grenadier"
	if n == 4:
		q[2] = "heavy"
	if boss:
		q.push_front("boss")
	return q

func start_wave(n: int) -> void:
	wave = n
	queue = compose(n)
	wave_state = "spawning"
	spawn_t = 0.6
	banner("OLEADA %d%s" % [n, "  -  JEFE" if n % 5 == 0 else ""], 2.4)
	sfx.play("wave", -2.0)

func alive_count() -> int:
	var c := 0
	for e in enemies:
		if is_instance_valid(e) and not e.dying:
			c += 1
	return c

func _waves(delta: float) -> void:
	if ending_t > 0.0:
		return
	match wave_state:
		"intermission":
			inter_t -= delta
			if inter_t <= 0.0:
				start_wave(wave + 1)
		"spawning":
			spawn_t -= delta
			var alive := alive_count()
			if not queue.is_empty() and alive < _wave_cap(wave) and spawn_t <= 0.0:
				var t: String = queue.pop_front()
				spawn_enemy(t, level.spawn_pos(player.global_position, 18.0 if t != "boss" else 22.0, 1.6 if t != "boss" else 2.4))
				spawn_t = maxf(0.55, 1.7 - 0.07 * wave) * (3.0 if t == "boss" else 1.0)
			if queue.is_empty() and alive == 0:
				_wave_clear()

func _wave_clear() -> void:
	if wave >= MAX_WAVE:
		banner("VICTORIA", 3.0)
		end_game(true)
		return
	wave_state = "intermission"
	inter_t = 5.0
	banner("OLEADA %d COMPLETA" % wave, 2.4)
	player.heal(20.0)
	player.add_ammo(30)
	player.gren = mini(player.max_gren, player.gren + 1)
	sfx.play("pickup", -2.0)

func spawn_enemy(t: String, pos: Vector3):
	var e = Enemy.new()
	e.game = self
	e.level = level
	e.fx = fx
	e.player = player
	enemies_root.add_child(e)
	e.init_type(t, maxi(wave, 1), pos)
	enemies.append(e)
	if t == "boss":
		sfx.play("wave", 0.0)
	return e

# ---------------------------------------------------------------- eventos de combate

func on_enemy_hit(e, head: bool, killed: bool, pos: Vector3) -> void:
	hit_t = 0.2
	hit_head = head
	hit_kill = killed
	if head:
		head_t = 0.9
		player.last_shot_hit = true

func on_enemy_died(e, head: bool) -> void:
	kills += 1
	streak += 1
	streak_t = 3.8
	best_streak = maxi(best_streak, streak)
	var pts: int = e.cfg.score
	if head:
		pts = int(pts * 1.5)
	score += pts * mult()
	if e.type == "boss":
		banner("JEFE ABATIDO", 2.6)
		slow_until = Time.get_ticks_msec() + 1300
		_update_time_scale()
		for i in 3:
			maybe_drop(e.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), "boss", true)
	else:
		maybe_drop(e.global_position, e.type)

func on_player_hit(from: Vector3) -> void:
	hurt_amt = 1.0
	dmg_ind.append({"pos": from, "t": 1.4})

func shake(a: float) -> void:
	player.shake = maxf(player.shake, a)

func throw_grenade(start: Vector3, target: Vector3, by_player: bool, ring = null):
	var g = Grenade.new()
	g.game = self
	g.fx = fx
	g.level = level
	proj_root.add_child(g)
	grenades.append(g)
	g.launch(start, target, by_player, ring)
	return g

func explosion(pos: Vector3, radius: float, dmg: float, by_player: bool) -> void:
	fx.explosion(pos, radius)
	sfx.play3d("boom", pos, 3.0, 0.05, 28.0)
	var dp: float = player.global_position.distance_to(pos)
	shake(clampf(1.2 - dp / 28.0, 0.0, 1.0))
	var space := world.get_world_3d().direct_space_state
	for e in enemies.duplicate():
		if not is_instance_valid(e) or e.dying:
			continue
		var d: float = (e.global_position + Vector3(0, 0.9, 0)).distance_to(pos)
		if d < radius + e.scale_f * 0.4:
			var f := 1.0 - clampf(d / (radius + 0.5), 0.0, 1.0) * 0.75
			var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), e.global_position + Vector3(0, 1.0, 0), 1)
			var cover_f := 0.4 if not space.intersect_ray(q).is_empty() else 1.0
			if by_player:
				e.take_hit(dmg * f * cover_f, e.global_position + Vector3(0, 1.0, 0), false, (e.global_position - pos).normalized())
	if dp < radius:
		var f := 1.0 - clampf(dp / radius, 0.0, 1.0) * 0.75
		var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 0.5, 0), player.chest_pos(), 1)
		var cover_f := 0.35 if not space.intersect_ray(q).is_empty() else 1.0
		var pd := dmg * f * cover_f * (0.3 if by_player else 1.0)
		if pd > 1.0:
			player.take_damage(pd, pos)

# ---------------------------------------------------------------- drops

func maybe_drop(pos: Vector3, type: String, force := false) -> void:
	var chance: float = {"rifleman": 0.2, "runner": 0.16, "grenadier": 0.35, "heavy": 0.75, "boss": 1.0}.get(type, 0.2)
	if not force and randf() > chance:
		return
	if pickups.size() >= 10:
		return
	var w := {"hp": 26.0, "ammo": 30.0, "gren": 16.0, "spread": 11.0, "burst": 11.0}
	if player.hp < 50.0:
		w["hp"] = 60.0
	if player.reserve < 50:
		w["ammo"] = 60.0
	if player.gren >= 4:
		w["gren"] = 4.0
	var sum := 0.0
	for k in w:
		sum += w[k]
	var r := randf() * sum
	var kind := "ammo"
	for k in w:
		r -= w[k]
		if r <= 0.0:
			kind = k
			break
	spawn_pickup(kind, level.nearest_free(pos))

func spawn_pickup(kind: String, pos: Vector3):
	var p = Pickup.new()
	pick_root.add_child(p)
	p.setup(kind, pos)
	pickups.append(p)
	return p

func _pickups_tick(delta: float) -> void:
	for p in pickups.duplicate():
		if not is_instance_valid(p):
			pickups.erase(p)
			continue
		p.life -= delta
		var d := Vector2(p.global_position.x - player.global_position.x, p.global_position.z - player.global_position.z).length()
		if p.life <= 0.0:
			pickups.erase(p)
			p.queue_free()
		elif d < 1.7 and not player.dead:
			_collect(p)
			pickups.erase(p)
			p.queue_free()

func _collect(p) -> void:
	var d: Dictionary = Pickup.KINDS[p.kind]
	match p.kind:
		"hp":
			player.heal(35.0)
		"ammo":
			player.add_ammo(60)
		"gren":
			player.gren = mini(player.max_gren, player.gren + 2)
		"spread", "burst":
			player.set_weapon(p.kind)
			player.wtime = 22.0
	toast(d.label)
	sfx.play("pickup", -1.0)
