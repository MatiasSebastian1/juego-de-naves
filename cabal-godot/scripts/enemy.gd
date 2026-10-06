extends Node2D
# Enemigo (soldado, granadero, corredor, pesado o jefe).  Posicion en pantalla segun profundidad z.

const K = preload("res://scripts/k.gd")
const FLASH = preload("res://shaders/flash.gdshader")

var game
var type := "rifle"
var x := 0.0
var z := 0.1
var tz := 0.5
var hp := 3.0
var max_hp := 3.0
var cd := 1.0
var aim := 0.0
var anim := 0.0
var ph := 0.0
var flash := 0.0
var dying := false
var dead_t := 0.0
var moving := true
var pat := 0
var size := 1.0
var cd_mul := 1.0     # escala del tiempo entre disparos (dificultad por oleada)
var tele_mul := 1.0   # escala del telegrafo
var enraged := false  # el jefe se enfurece por debajo del 50% de vida

var spr: Sprite2D
var shadow: Sprite2D       # contacto: elipse pequena bajo los pies
var cast: Sprite2D         # sombra proyectada segun el sol
var kick := 0.0            # retroceso/squash al disparar (1 -> 0)
var dying_frames := false  # hay cuadros de muerte para este tipo
var d_off := Vector2(-260, -400)
var n_off := Vector2(-210, -310)
var mat: ShaderMaterial
var cur_frame := ""
var last_flash := -1.0

func setup(t: String, wave: int) -> void:
	type = t
	var T: Dictionary = K.TYPES[t]
	size = T["size"]
	tz = randf_range(T["tz"][0], T["tz"][1])
	var D: Dictionary = K.diff(wave)
	cd_mul = D["cd"]
	tele_mul = D["tele"]
	# el jefe escala por oleada; el resto con el multiplicador de vida de la dificultad
	hp = (T["hp"] + wave * 8.0) if t == "boss" else T["hp"] * D["hp"]
	max_hp = hp
	x = randf_range(120.0, 1160.0)
	z = randf_range(0.03, 0.14)
	cd = randf_range(1.0, 2.5)
	anim = randf_range(0.0, 6.0)
	ph = randf_range(0.0, 6.0)
	if t == "runner":
		z = 0.1

func _ready() -> void:
	spr = Sprite2D.new()
	spr.centered = false
	n_off = Vector2(-450, -590) if type == "boss" else Vector2(-210, -310)
	d_off = Vector2(-450, -670) if type == "boss" else Vector2(-260, -400)
	dying_frames = K.has("%s_die3" % _pre())
	spr.offset = n_off
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat = ShaderMaterial.new()
	mat.shader = FLASH
	spr.material = mat
	shadow = Sprite2D.new()
	shadow.texture = K.shadow_tex()
	var rx := 220.0 if type == "boss" else 78.0 * (1.35 if type == "heavy" else (0.85 if type == "runner" else 1.0))
	var ry := 50.0 if type == "boss" else 21.0
	shadow.scale = Vector2(rx * 1.3 / 256.0, ry * 1.1 / 256.0)
	shadow.self_modulate = Color(1, 1, 1, 0.8)
	shadow.light_mask = 0
	cast = K.make_shadow(n_off, 1.0, 0.55)
	add_child(cast)
	add_child(shadow)
	add_child(spr)
	_apply(0.0)

func box() -> Dictionary:
	var s := K.zscale(z) * size
	var h := 130.0 * s
	return {"x": x, "y": K.zy(z), "h": h, "w": h * (0.6 if type == "boss" else 0.46), "s": s}

func _apply(dt: float) -> void:
	position = Vector2(x, K.zy(z))
	var s := K.zscale(z) * size
	var k := (130.0 * s / 460.0) if type == "boss" else (s / 2.0)
	scale = Vector2.ONE * k
	z_index = int(z * 100.0)
	var fname := _frame_name()
	if fname != cur_frame:
		cur_frame = fname
		var tx := K.tex(fname)
		spr.texture = tx
		cast.texture = tx
		var off := d_off if dying_frames and dying else n_off
		spr.offset = off
		cast.offset = off
	var fl := clampf(flash / 0.07, 0.0, 1.0)
	if fl != last_flash:
		last_flash = fl
		mat.set_shader_parameter("flash", fl)
	kick = maxf(0.0, kick - dt * 6.0)
	# animacion procedural: respiracion en reposo, rebote al caminar, squash y retroceso al disparar
	var sx := 1.0
	var sy := 1.0
	var by := 0.0
	if dying:
		_death_pose()
		return
	if moving:
		var ph2 := _walk_phase()
		by = -absf(sin(ph2 * TAU * 2.0)) * (9.0 if type == "boss" else 6.0)
		sx = 1.0 + sin(ph2 * TAU * 2.0) * 0.012
	else:
		sy = 1.0 + sin(anim * 2.2 + ph) * 0.012
		sx = 1.0 - sin(anim * 2.2 + ph) * 0.006
	if aim > 0.0:
		sy *= 0.985
		sx *= 1.012
	sx *= 1.0 + kick * 0.06
	sy *= 1.0 - kick * 0.08
	by += kick * 7.0
	spr.scale = Vector2(sx, sy)
	spr.position = Vector2(kick * -2.0 * (1.0 if x < 640.0 else -1.0), by)
	cast.position.x = spr.position.x

func _pre() -> String:
	return "boss" if type == "boss" else "enemy_%s" % type

func _walk_phase() -> float:
	var w := 14.0 if type == "runner" else (2.2 if type == "boss" else 8.0)
	return fposmod(anim * w / (TAU * 1.4), 1.0)

const WALK4 := ["walk1", "walk3", "walk2", "walk4"]

func _frame_name() -> String:
	var pre := _pre()
	if dying and dying_frames:
		var f := 1
		if type == "boss":
			f = 1 if dead_t < 0.45 else (2 if dead_t < 0.9 else 3)
		else:
			f = 1 if dead_t < 0.12 else (2 if dead_t < 0.28 else 3)
		return "%s_die%d" % [pre, f]
	var f := "idle"
	if aim > 0.0:
		f = "aim"
	elif moving:
		if K.has("%s_walk4" % pre):
			f = WALK4[int(_walk_phase() * 4.0) % 4]
		else:
			var w := 14.0 if type == "runner" else (2.2 if type == "boss" else 8.0)
			f = "walk1" if sin(anim * w) > 0.0 else "walk2"
	return "%s_%s" % [pre, f]

# Duracion total de la animacion de muerte (game.gd libera el nodo despues).
func death_len() -> float:
	if dying_frames:
		return 2.1 if type == "boss" else 1.1
	return 0.7

# Muerte con cuadros: caida, rebote al tocar el suelo y desvanecido.  Sin cuadros: giro y fade como antes.
func _death_pose() -> void:
	spr.scale = Vector2.ONE
	if not dying_frames:
		if type == "boss":
			modulate.a = 1.0 - clampf(dead_t / 0.7, 0.0, 1.0)
			spr.position.y = dead_t * 30.0 * 4.6
			spr.position.x = sin(dead_t * 40.0) * 5.0
		else:
			var kk := minf(1.0, dead_t / 0.35)
			rotation = -kk * 1.45 * (-1.0 if x > 640.0 else 1.0)
			modulate.a = 1.0 - clampf((dead_t - 0.4) / 0.3, 0.0, 1.0)
		return
	var land := 0.9 if type == "boss" else 0.28
	var amp := 26.0 if type == "boss" else 12.0
	var by := 0.0
	var bx := 0.0
	if dead_t > land:
		var u := dead_t - land
		# dos rebotes decrecientes
		if u < 0.22:
			by = -sin(u / 0.22 * PI) * amp
		elif u < 0.36:
			by = -sin((u - 0.22) / 0.14 * PI) * amp * 0.35
	if type == "boss" and dead_t < land:
		bx = sin(dead_t * 55.0) * 6.0 * (1.0 - dead_t / land * 0.5)
	spr.position = Vector2(bx, by)
	cast.position.x = bx
	var fade_at := 1.5 if type == "boss" else 0.72
	var fade_len := 0.55 if type == "boss" else 0.34
	modulate.a = 1.0 - clampf((dead_t - fade_at) / fade_len, 0.0, 1.0)

func tick(dt: float) -> void:
	anim += dt
	flash -= dt
	if dying:
		dead_t += dt
		_apply(dt)
		return
	var T: Dictionary = K.TYPES[type]
	moving = false
	if type == "boss" and not enraged and hp < max_hp * 0.5:
		enraged = true
		cd_mul *= 0.72
		game.boss_enrage(self)
	if type == "runner":
		z += dt * T["spd"]
		x += (game.player.position.x - x) * dt * 0.9
		moving = true
		if z >= 0.97:
			game.hurt_player(20.0)
			game.kill_enemy(self, true)
			game.explosion(Vector2(x, K.zy(z) - 30.0), 0.6)
		_apply(dt)
		return
	if z < tz:
		z += dt * T["spd"]
		moving = true
	x = clampf(x + sin(anim * T["sw"] + ph) * T["sa"] * dt, 90.0, 1190.0)
	cd -= dt
	if aim > 0.0:
		aim -= dt
		if aim <= 0.0:
			game.enemy_attack(self)
	elif cd <= 0.0 and z >= tz - 0.05:
		aim = maxf(0.3, T["tele"] * tele_mul)
		cd = randf_range(T["cd"][0], T["cd"][1]) * cd_mul
	_apply(dt)
