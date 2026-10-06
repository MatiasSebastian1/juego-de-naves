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
var shadow: Sprite2D
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
	spr.offset = Vector2(-450, -590) if type == "boss" else Vector2(-210, -310)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat = ShaderMaterial.new()
	mat.shader = FLASH
	spr.material = mat
	shadow = Sprite2D.new()
	shadow.texture = K.shadow_tex()
	var rx := 220.0 if type == "boss" else 78.0 * (1.35 if type == "heavy" else (0.85 if type == "runner" else 1.0))
	var ry := 50.0 if type == "boss" else 21.0
	shadow.scale = Vector2(rx * 2.0 / 256.0, ry * 2.0 / 256.0)
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
	var f := "idle"
	if aim > 0.0:
		f = "aim"
	elif moving:
		var w := 14.0 if type == "runner" else (2.2 if type == "boss" else 8.0)
		f = "walk1" if sin(anim * w) > 0.0 else "walk2"
	var fname := ("boss_%s" % f) if type == "boss" else ("enemy_%s_%s" % [type, f])
	if fname != cur_frame:
		cur_frame = fname
		spr.texture = K.tex(fname)
	var fl := clampf(flash / 0.07, 0.0, 1.0)
	if fl != last_flash:
		last_flash = fl
		mat.set_shader_parameter("flash", fl)
	if dying:
		if type == "boss":
			modulate.a = 1.0 - clampf(dead_t / 0.7, 0.0, 1.0)
			spr.position.y = dead_t * 30.0 * 4.6
			spr.position.x = sin(dead_t * 40.0) * 5.0
		else:
			var kk := minf(1.0, dead_t / 0.35)
			rotation = -kk * 1.45 * (-1.0 if x > 640.0 else 1.0)
			modulate.a = 1.0 - clampf((dead_t - 0.4) / 0.3, 0.0, 1.0)

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
