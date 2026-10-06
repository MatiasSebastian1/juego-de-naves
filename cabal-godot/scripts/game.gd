extends Node2D
# Controlador principal de Cabal HD: estados, oleadas, disparos, enemigos y efectos.

const K = preload("res://scripts/k.gd")
const Fx = preload("res://scripts/fx.gd")
const Sfx = preload("res://scripts/sfx.gd")
const Hud = preload("res://scripts/hud.gd")
const PlayerS = preload("res://scripts/player.gd")
const EnemyS = preload("res://scripts/enemy.gd")
const Shell = preload("res://scripts/shell.gd")
const Props = preload("res://scripts/props.gd")
const POST = preload("res://shaders/post.gdshader")
const SAVE_PATH := "user://cabalhd.cfg"

var state := "menu"
var world: Node2D
var fx
var sfx
var hud
var cam: Camera2D
var bg: Sprite2D
var post_mat: ShaderMaterial
var player

var enemies: Array = []
var shells: Array = []
var barricades: Array = []
var crates: Array = []
var pickups: Array = []
var queue: Array = []

var wave := 0
var score := 0
var hiscore := 0
var streak := 0
var combo_t := 0.0
var banner_t := 0.0
var banner_text := ""
var wave_delay := 0.5
var spawn_t := 0.0
var flash_t := 0.0
var shake_t := 0.0
var hurt_t := 0.0
var head_t := -1.0
var time := 0.0
var mouse := Vector2(640, 200)
var mouse_down := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_load_hi()
	world = Node2D.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	var mod := CanvasModulate.new()
	mod.color = Color(0.86, 0.82, 0.94)
	add_child(mod)
	var sun := DirectionalLight2D.new()
	sun.color = Color(1.0, 0.76, 0.52)
	sun.energy = 0.32
	add_child(sun)
	bg = Sprite2D.new()
	bg.texture = K.tex("background")
	bg.position = Vector2(640, 360)
	bg.scale = Vector2.ONE * 0.53
	bg.z_index = -100
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	world.add_child(bg)
	fx = Fx.new()
	world.add_child(fx)
	fx.ambient()
	player = PlayerS.new()
	player.game = self
	world.add_child(player)
	sfx = Sfx.new()
	add_child(sfx)
	cam = Camera2D.new()
	cam.position = Vector2(640, 360)
	add_child(cam)
	cam.make_current()
	# postproceso
	var pl := CanvasLayer.new()
	pl.layer = 4
	add_child(pl)
	var cr := ColorRect.new()
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST
	cr.material = post_mat
	pl.add_child(cr)
	var hl := CanvasLayer.new()
	hl.layer = 5
	add_child(hl)
	hud = Hud.new()
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.add_child(hud)
	reset_game()

func _load_hi() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) == OK:
		hiscore = int(c.get_value("game", "hi", 0))

func _save_hi() -> void:
	var c := ConfigFile.new()
	c.set_value("game", "hi", hiscore)
	c.save(SAVE_PATH)

func _free_all(arr: Array) -> void:
	for n in arr:
		if is_instance_valid(n):
			n.queue_free()
	arr.clear()

func reset_game() -> void:
	_free_all(enemies)
	_free_all(shells)
	_free_all(barricades)
	_free_all(crates)
	_free_all(pickups)
	queue.clear()
	player.reset()
	score = 0
	streak = 0
	combo_t = 0.0
	banner_t = 0.0
	spawn_t = 0.0
	flash_t = 0.0
	shake_t = 0.0
	hurt_t = 0.0
	wave_delay = 0.5
	wave = 0
	sfx.music_volume(-10.0)

func mult() -> int:
	return mini(5, 1 + streak / 4)

func aim_world() -> Vector2:
	return mouse + cam.offset

# ---------------------------------------------------------------- oleadas
func start_wave(n: int) -> void:
	wave = n
	sfx.play("wave")
	barricades = barricades.filter(func(b): return is_instance_valid(b) and b.hp > 0)
	for b in barricades:
		b.hp = minf(b.max_hp, b.hp + 6.0)
	var xs := [200.0, 440.0, 840.0, 1080.0]
	for xv in xs:
		if barricades.size() >= 3:
			break
		var near := false
		for b in barricades:
			if absf(b.x - xv) < 120.0:
				near = true
		if not near:
			var br = Props.Barricade.new()
			br.x = xv + randf_range(-40.0, 40.0)
			world.add_child(br)
			barricades.append(br)
	for i in 1 + (n % 2):
		var c = Props.Crate.new()
		c.x = randf_range(160.0, 1120.0)
		c.cz = randf_range(0.35, 0.6)
		world.add_child(c)
		crates.append(c)
	queue.clear()
	var count := 5 + n * 3
	for i in count:
		var r := randf()
		var t := "rifle"
		if n >= 2 and r < 0.2:
			t = "grenadier"
		elif n >= 2 and r < 0.38:
			t = "runner"
		elif n >= 4 and r < 0.5:
			t = "heavy"
		queue.append(t)
	if n % 5 == 0:
		queue.push_front("boss")
	banner_text = ("OLEADA %d — ¡JEFE!" % n) if n % 5 == 0 else ("OLEADA %d" % n)
	banner_t = 2.2
	spawn_t = 1.2

func spawn(t: String):
	var e = EnemyS.new()
	e.game = self
	e.setup(t, wave)
	world.add_child(e)
	enemies.append(e)
	return e

# ---------------------------------------------------------------- disparo
func shoot() -> void:
	var w: String = player.weapon
	var rate := 0.055 if w == "rapid" else (0.4 if w == "spread" else 0.1)
	player.fire_cd = rate
	player.flash = 0.06
	var pellets := 6 if w == "spread" else 1
	var sp := 46.0 if w == "spread" else 5.0
	var am := aim_world()
	for i in pellets:
		var a := randf() * TAU
		var r := sqrt(randf()) * sp
		var tp := am + Vector2(cos(a), sin(a)) * r
		var hit := hitscan(tp)
		fx.tracer(player.muzzle, tp)
		if not hit and tp.y > K.HOR:
			fx.dust(tp, 1)
	fx.muzzle(player.muzzle)
	sfx.play("spread" if w == "spread" else "shot", -4.0 if w != "spread" else 0.0, 0.05)
	shake_t = maxf(shake_t, 0.08 if w == "spread" else 0.02)

func hitscan(tp: Vector2) -> bool:
	for b in shells:
		if b.kind == "b" and not b.dead and b.t > 0.35 and b.position.distance_to(tp) < 12.0 + b.t * 14.0:
			b.dead = true
			fx.sparks(b.position, 8, Color(1.0, 0.6, 0.32))
			score += 10
			sfx.play("hit", -6.0)
			return true
	for k in pickups:
		if not k.dead and absf(k.base.x - tp.x) < 34.0 and absf(k.base.y - 20.0 - tp.y) < 34.0:
			collect(k)
			return true
	var list := enemies.filter(func(e): return not e.dying)
	list.sort_custom(func(a, b): return a.z > b.z)
	for e in list:
		var b: Dictionary = e.box()
		if tp.x > b.x - b.w / 2.0 and tp.x < b.x + b.w / 2.0 and tp.y > b.y - b.h and tp.y < b.y:
			var head: bool = tp.y < b.y - b.h * 0.78
			damage_enemy(e, 2.0 if head else 1.0, tp, head)
			return true
	for c in crates:
		var s: float = K.zscale(c.cz) * 80.0
		var y: float = K.zy(c.cz)
		if not c.dead and absf(c.x - tp.x) < s * 0.7 and tp.y > y - s and tp.y < y:
			c.hp -= 1.0
			c.hit = 0.1
			fx.sparks(tp, 6, Color(0.91, 0.75, 0.44))
			sfx.play("hit", -6.0)
			if c.hp <= 0.0:
				c.dead = true
				fx.debris(Vector2(c.x, y - s / 2.0), 16, Color(0.54, 0.42, 0.23))
				fx.smoke(Vector2(c.x, y - s / 2.0), 6, 30.0)
				drop_pickup(Vector2(c.x, y), true)
				sfx.play("boom", -8.0)
				shake_t = maxf(shake_t, 0.15)
			return true
	return false

func damage_enemy(e, dmg: float, tp: Vector2, head: bool) -> void:
	e.hp -= dmg
	e.flash = 0.07
	fx.sparks(tp, 10 if head else 5, Color(1.0, 0.95, 0.63) if head else Color(1.0, 0.82, 0.48))
	if head:
		if time - head_t > 0.3:
			head_t = time
			fx.floater(tp + Vector2(0, -14), "HEADSHOT", Color(1.0, 0.88, 0.4))
		sfx.play("head", -4.0)
	else:
		sfx.play("hit", -6.0)
	if e.hp <= 0.0:
		kill_enemy(e, false)

func kill_enemy(e, silent: bool) -> void:
	if e.dying:
		return
	e.dying = true
	e.dead_t = 0.0
	var T: Dictionary = K.TYPES[e.type]
	var b: Dictionary = e.box()
	if not silent:
		streak += 1
		combo_t = 3.0
		var pts: int = T["score"] * mult()
		score += pts
		fx.floater(Vector2(b.x, b.y - b.h - 8.0), "+%d%s" % [pts, ("  x%d" % mult()) if mult() > 1 else ""], Color(0.55, 0.93, 1.0))
		if randf() < (0.5 if e.type == "heavy" else 0.1) or e.type == "boss":
			drop_pickup(Vector2(b.x, b.y), false)
	var col := Color(0.42, 0.49, 0.32)
	match e.type:
		"grenadier": col = Color(0.54, 0.33, 0.25)
		"runner": col = Color(0.29, 0.42, 0.66)
		"heavy": col = Color(0.49, 0.24, 0.24)
		"boss": col = Color(0.5, 0.54, 0.62)
	fx.debris(Vector2(b.x, b.y - b.h / 2.0), 40 if e.type == "boss" else 9, col)
	fx.smoke(Vector2(b.x, b.y - b.h * 0.3), 3, 24.0 * b.s)
	if e.type == "boss":
		explosion(Vector2(b.x, b.y - b.h / 2.0), 2.4)
		queue = queue.filter(func(t): return t != "boss")
		_slowmo()
	else:
		shake_t = maxf(shake_t, 0.08)

func _slowmo() -> void:
	Engine.time_scale = 0.25
	get_tree().create_timer(0.9, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)

func drop_pickup(pos: Vector2, sure: bool) -> void:
	if not sure and randf() < 0.35:
		return
	var kinds := ["H", "G", "S", "R"]
	var k = Props.Pickup.new()
	k.kind = kinds[randi() % 4]
	k.base = pos
	world.add_child(k)
	pickups.append(k)

func collect(k) -> void:
	k.dead = true
	sfx.play("pickup")
	var names := {"H": "+VIDA", "G": "+3 GRANADAS", "S": "ESCOPETA", "R": "RÁFAGA"}
	match k.kind:
		"H": player.hp = minf(player.max_hp, player.hp + 35.0)
		"G": player.gren = mini(9, player.gren + 3)
		"S":
			player.weapon = "spread"
			player.wt = 15.0
		"R":
			player.weapon = "rapid"
			player.wt = 15.0
	fx.floater(k.position + Vector2(0, -40), names[k.kind], Color(0.6, 1.0, 0.6))
	fx.sparks(k.position, 16, Color(0.6, 1.0, 0.6))
	fx.light_flash(k.position, 1.2, 3.0, Color(0.6, 1.0, 0.6), 0.25)

func throw_grenade() -> void:
	if player.gren <= 0 or state != "play":
		return
	player.gren -= 1
	sfx.play("nade")
	var s = Shell.new()
	s.kind = "g"
	s.own = "p"
	s.p0 = player.muzzle
	s.tgt = aim_world()
	s.dur = 0.75
	s.rx = 150.0
	s.ry = 150.0
	s.cur = s.p0
	s.prev = s.p0
	world.add_child(s)
	shells.append(s)

func explosion(pos: Vector2, big := 1.0) -> void:
	fx.fire(pos, big)
	fx.smoke(pos, int(12 * big), 56.0 * big, Color(0.16, 0.13, 0.13, 0.6))
	fx.sparks(pos, int(26 * big))
	fx.debris(pos, int(10 * big))
	fx.ring(pos, 150.0 * big)
	fx.light_flash(pos, 2.6 * big, 9.0 * big, Color(1.0, 0.65, 0.35), 0.45)
	shake_t = maxf(shake_t, 0.35 * big)
	flash_t = maxf(flash_t, 0.12 * big)
	sfx.play("boom", 0.0, 0.1)

# ---------------------------------------------------------------- ataques enemigos
func _aim_at(spread: float) -> Vector2:
	var lead := minf(0.5, 0.1 + wave * 0.03)
	return Vector2(player.position.x + player.vel.x * lead + randf_range(-spread, spread), player.position.y - 50.0 + randf_range(-spread, spread) * 0.5)

func _bullet(src: Vector2, tg: Vector2, dur: float, z: float, dmg: float) -> void:
	var s = Shell.new()
	s.kind = "b"
	s.p0 = src
	s.tgt = tg
	s.dur = dur
	s.z = z
	s.dmg = dmg
	s.cur = src
	s.prev = src
	world.add_child(s)
	shells.append(s)

func _nade(src: Vector2, tg: Vector2) -> void:
	var s = Shell.new()
	s.kind = "g"
	s.own = "e"
	s.p0 = src
	s.tgt = Vector2(tg.x, clampf(player.position.y + randf_range(-30.0, 20.0), 560.0, 690.0))
	s.dur = 1.6
	s.rx = 130.0
	s.ry = 46.0
	s.cur = src
	s.prev = src
	world.add_child(s)
	shells.append(s)

func enemy_attack(e) -> void:
	var b: Dictionary = e.box()
	var src := Vector2(b.x, b.y - b.h * 0.62)
	match e.type:
		"rifle":
			_bullet(src, _aim_at(26.0), randf_range(0.95, 1.35), e.z, 8.0)
			sfx.play("enemy", -8.0)
		"heavy":
			for i in 3:
				_bullet(src, _aim_at(90.0 + i * 20.0), randf_range(0.95, 1.35), e.z, 12.0)
			sfx.play("enemy", -6.0)
		"grenadier":
			_nade(src, _aim_at(40.0))
			sfx.play("enemy", -6.0)
		"boss":
			e.pat += 1
			if e.pat % 3 == 0:
				_nade(src, _aim_at(120.0))
				_nade(src, _aim_at(160.0))
			else:
				for i in range(-2, 3):
					var a := _aim_at(10.0)
					_bullet(src, a + Vector2(i * 120.0, randf_range(-30.0, 30.0)), 1.15, e.z, 10.0)
			shake_t = maxf(shake_t, 0.12)
			sfx.play("enemy", -2.0)
	fx.light_flash(src, 1.0, 2.5, Color(1.0, 0.45, 0.25), 0.12)
	fx.sparks(src, 5, Color(1.0, 0.5, 0.3))

func hurt_player(d: float) -> void:
	if player.inv > 0.0 or state != "play":
		return
	player.hp -= d
	player.inv = 0.7
	hurt_t = 0.5
	streak = 0
	shake_t = maxf(shake_t, 0.3)
	sfx.play("hurt")
	fx.sparks(player.position + Vector2(0, -60), 12, Color(1.0, 0.4, 0.4))
	if player.hp <= 0.0:
		player.hp = 0.0
		state = "over"
		sfx.play("over")
		sfx.music_volume(-22.0)
		explosion(player.position + Vector2(0, -50), 1.2)
		if score > hiscore:
			hiscore = score
			_save_hi()

# ---------------------------------------------------------------- bucle
func _process(dt: float) -> void:
	time += dt
	if state == "play" or state == "over":
		update(dt)
	var s := 0.0 if state == "pause" else shake_t * 22.0
	cam.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * s + (mouse - Vector2(640, 360)) * 0.012
	bg.position = Vector2(640, 360) + cam.offset * 0.85
	post_mat.set_shader_parameter("hurt", clampf(hurt_t * 2.0, 0.0, 1.0))
	post_mat.set_shader_parameter("flash", flash_t * 1.4)
	post_mat.set_shader_parameter("time_s", fmod(time, 100.0))
	hud.queue_redraw()

func update(dt: float) -> void:
	combo_t -= dt
	if combo_t <= 0.0:
		streak = 0
	flash_t = maxf(0.0, flash_t - dt)
	shake_t = maxf(0.0, shake_t - dt)
	hurt_t = maxf(0.0, hurt_t - dt)
	banner_t = maxf(0.0, banner_t - dt)
	if player.wt > 0.0:
		player.wt -= dt
		if player.wt <= 0.0:
			player.weapon = "mg"
	player.aim_pos = aim_world()
	if state == "play":
		player.tick(dt)
		if mouse_down and player.fire_cd <= 0.0 and player.roll <= 0.0:
			shoot()
		_waves(dt)
	player.visual(dt)

	for e in enemies:
		e.tick(dt)
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if e.dying and e.dead_t > 0.7:
			e.queue_free()
			enemies.remove_at(i)

	_shells(dt)

	for b in barricades:
		b.tick(dt)
	for c in crates:
		c.tick(dt)
	for k in pickups:
		k.tick(dt)
	_cleanup()

func _waves(dt: float) -> void:
	var alive := 0
	for e in enemies:
		if not e.dying:
			alive += 1
	if queue.is_empty() and alive == 0 and banner_t <= 0.0:
		wave_delay -= dt
		if wave_delay <= 0.0:
			if wave > 0:
				score += wave * 250
				player.hp = minf(player.max_hp, player.hp + 15.0)
				player.gren = mini(9, player.gren + 1)
			start_wave(wave + 1)
			wave_delay = 2.2
	elif not queue.is_empty():
		spawn_t -= dt
		if spawn_t <= 0.0 and alive < 4 + wave / 2:
			spawn(queue.pop_front())
			spawn_t = maxf(0.5, 1.6 - wave * 0.08)

func _shells(dt: float) -> void:
	for b in shells:
		if b.dead:
			continue
		b.t += dt / b.dur
		if b.kind == "b":
			b.prev = b.cur
			b.cur = b.p0.lerp(b.tgt, b.t)
			if b.t > 0.12:
				for br in barricades:
					if br.hp > 0.0 and b.z < 0.88 and b.cur.x > br.x - br.w / 2.0 and b.cur.x < br.x + br.w / 2.0 and b.cur.y > br.base - br.h and b.cur.y < br.base:
						br.hp -= 1.0
						br.hit = 0.1
						b.dead = true
						fx.sparks(b.cur, 8, Color(1.0, 0.81, 0.54))
						fx.debris(b.cur, 3, Color(0.48, 0.44, 0.41))
						sfx.play("hit", -4.0)
						if br.hp <= 0.0:
							_break_barricade(br)
						break
			if not b.dead and b.t >= 1.0:
				b.dead = true
				if b.tgt.distance_to(Vector2(player.position.x, player.position.y - 50.0)) < 62.0:
					hurt_player(b.dmg)
				else:
					fx.dust(b.tgt, 2)
		else:
			b.cur = b.p0.lerp(b.tgt, b.t) - Vector2(0, sin(PI * minf(1.0, b.t)) * (110.0 if b.own == "p" else 160.0))
			if b.t >= 1.0:
				b.dead = true
				explosion(b.tgt, 1.1 if b.own == "p" else 0.9)
				if b.own == "p":
					for e in enemies:
						if e.dying:
							continue
						var bx: Dictionary = e.box()
						var d := Vector2(e.x, bx.y - bx.h / 2.0).distance_to(b.tgt)
						if d < b.rx + bx.w * 0.4:
							damage_enemy(e, 12.0 if e.type == "boss" else 8.0, Vector2(e.x, bx.y - bx.h / 2.0), false)
					for o in shells:
						if o.kind == "b" and not o.dead and o.cur.distance_to(b.tgt) < b.rx:
							o.dead = true
					for c in crates:
						if not c.dead and Vector2(c.x, K.zy(c.cz)).distance_to(b.tgt) < b.rx:
							c.hp = 0.0
							c.dead = true
							fx.debris(Vector2(c.x, K.zy(c.cz) - 30.0), 14, Color(0.54, 0.42, 0.23))
							drop_pickup(Vector2(c.x, K.zy(c.cz)), true)
				else:
					var dx: float = (player.position.x - b.tgt.x) / b.rx
					var dy: float = (player.position.y - b.tgt.y) / b.ry
					if dx * dx + dy * dy < 1.0:
						hurt_player(25.0)
					for br in barricades:
						if br.hp > 0.0 and absf(br.x - b.tgt.x) < b.rx + br.w / 2.0 and absf(br.base - b.tgt.y) < 90.0:
							br.hp -= 5.0
							br.hit = 0.15
							if br.hp <= 0.0:
								_break_barricade(br)
		b.refresh()

func _break_barricade(br) -> void:
	fx.debris(Vector2(br.x, br.base - 30.0), 24, Color(0.48, 0.44, 0.41))
	fx.smoke(Vector2(br.x, br.base - 30.0), 10, 40.0)
	sfx.play("boom", -6.0)
	shake_t = maxf(shake_t, 0.2)

func _cleanup() -> void:
	for arr in [shells, barricades, crates, pickups]:
		for i in range(arr.size() - 1, -1, -1):
			var n = arr[i]
			var gone := false
			if arr == shells:
				gone = n.dead
			elif arr == barricades:
				gone = n.hp <= 0.0
			elif arr == crates:
				gone = n.dead
			else:
				gone = n.dead or n.life <= 0.0
			if gone:
				n.queue_free()
				arr.remove_at(i)

# ---------------------------------------------------------------- entrada
func start_game() -> void:
	reset_game()
	state = "play"
	sfx.start_music()

func _set_pause(p: bool) -> void:
	state = "pause" if p else "play"
	get_tree().paused = p

func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		mouse = Vector2(clampf(ev.position.x, 0.0, 1280.0), clampf(ev.position.y, 0.0, 720.0))
	elif ev is InputEventMouseButton:
		mouse = Vector2(clampf(ev.position.x, 0.0, 1280.0), clampf(ev.position.y, 0.0, 720.0))
		if ev.pressed:
			if state == "menu" or state == "over":
				start_game()
				return
			if ev.button_index == MOUSE_BUTTON_LEFT:
				mouse_down = true
			elif ev.button_index == MOUSE_BUTTON_RIGHT:
				throw_grenade()
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			mouse_down = false
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.physical_keycode:
			KEY_G: throw_grenade()
			KEY_P, KEY_ESCAPE:
				if state == "play":
					_set_pause(true)
				elif state == "pause":
					_set_pause(false)
			KEY_ENTER, KEY_KP_ENTER:
				if state == "menu" or state == "over":
					start_game()
			KEY_F11:
				var m := DisplayServer.window_get_mode()
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if m == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		mouse_down = false
		if state == "play":
			_set_pause(true)
