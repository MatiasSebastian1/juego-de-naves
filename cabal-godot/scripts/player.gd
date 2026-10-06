extends Node2D
# Soldado del jugador (de espaldas), con arma que apunta al cursor.

const K = preload("res://scripts/k.gd")
const FLASH = preload("res://shaders/flash.gdshader")
const U := 1.55
const SHOULDER := Vector2(16.0 * U, -66.0 * U)

var game
var vel := Vector2.ZERO
var hp := 100.0
var max_hp := 100.0
var gren := 3
var roll := 0.0
var roll_cd := 0.0
var rd := Vector2(1, 0)
var inv := 0.0
var fire_cd := 0.0
var weapon := "mg"
var wt := 0.0
var flash := 0.0
var dir := 1
var muzzle := Vector2.ZERO
var aim_pos := Vector2(640, 200)
var t := 0.0
var hit_t := 0.0          # destello blanco al recibir dano
var roll_ready_t := 0.0   # pulso breve cuando la esquiva vuelve a estar lista (lo dibuja el HUD)

const ROLL_TIME := 0.36
const ROLL_CD := 0.95

var pivot: Node2D
var body: Sprite2D
var gun: Sprite2D
var shadow: Sprite2D
var cast: Sprite2D
var recoil := 0.0        # retroceso del arma al disparar (1 -> 0)
var step_t := 0.0        # fase del ciclo de caminata
var hurt_hold := 0.0     # tiempo restante mostrando el cuadro de herido
var gun_angle := 0.0
var cur_body := ""
var mat: ShaderMaterial

func _ready() -> void:
	z_index = 200
	shadow = Sprite2D.new()
	shadow.texture = K.shadow_tex()
	shadow.scale = Vector2(26.0 * U * 2.0 / 256.0, 7.0 * U * 2.0 / 256.0)
	shadow.self_modulate = Color(1, 1, 1, 0.8)
	shadow.light_mask = 0
	cast = K.make_shadow(Vector2(-340, -600), 0.5, 0.55)
	cast.texture = K.tex("player_body")
	add_child(cast)
	add_child(shadow)
	pivot = Node2D.new()
	pivot.position = Vector2(0, -62)
	add_child(pivot)
	mat = ShaderMaterial.new()
	mat.shader = FLASH
	body = Sprite2D.new()
	body.texture = K.tex("player_body")
	body.centered = false
	body.offset = Vector2(-340, -600)
	body.position = Vector2(0, 62)
	body.scale = Vector2(0.5, 0.5)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body.material = mat
	pivot.add_child(body)
	gun = Sprite2D.new()
	gun.texture = K.tex("player_gun")
	gun.centered = false
	gun.offset = Vector2(-40, -80)
	gun.scale = Vector2(0.5, 0.5)
	gun.position = SHOULDER
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(gun)
	reset()

func reset() -> void:
	position = Vector2(640, 610)
	vel = Vector2.ZERO
	hp = max_hp
	gren = 3
	roll = 0.0
	roll_cd = 0.0
	inv = 0.0
	fire_cd = 0.0
	weapon = "mg"
	wt = 0.0
	flash = 0.0
	hit_t = 0.0
	recoil = 0.0
	hurt_hold = 0.0
	roll_ready_t = 0.0
	dir = 1
	visible = true
	if pivot:
		pivot.rotation = 0.0
		pivot.scale = Vector2.ONE
		modulate.a = 1.0

func _key(a: int, b: int) -> bool:
	return Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)

func tick(dt: float) -> void:
	t += dt
	var ax := (1 if _key(KEY_D, KEY_RIGHT) else 0) - (1 if _key(KEY_A, KEY_LEFT) else 0)
	var ay := (1 if _key(KEY_S, KEY_DOWN) else 0) - (1 if _key(KEY_W, KEY_UP) else 0)
	if ax != 0:
		dir = ax
	inv = maxf(0.0, inv - dt)
	hit_t = maxf(0.0, hit_t - dt)
	roll_ready_t = maxf(0.0, roll_ready_t - dt)
	if roll_cd > 0.0 and roll_cd - dt <= 0.0:
		roll_ready_t = 0.35
	roll_cd -= dt
	fire_cd -= dt
	flash -= dt
	if roll > 0.0:
		roll -= dt
		vel = Vector2(rd.x * 880.0, rd.y * 520.0)
	else:
		var l := Vector2(ax, ay).length()
		if l == 0.0:
			l = 1.0
		vel.x = lerpf(vel.x, ax / l * 380.0, minf(1.0, dt * 14.0))
		vel.y = lerpf(vel.y, ay / l * 260.0, minf(1.0, dt * 14.0))
		if Input.is_physical_key_pressed(KEY_SPACE) and roll_cd <= 0.0:
			roll = ROLL_TIME
			roll_cd = ROLL_CD
			inv = maxf(inv, ROLL_TIME)
			game.sfx.play("roll")
			rd = Vector2(ax / l, ay / l) if (ax != 0 or ay != 0) else Vector2(dir, 0)
			game.fx.dust(position + Vector2(0, -6), 4)
	position.x = clampf(position.x + vel.x * dt, 70.0, 1210.0)
	position.y = clampf(position.y + vel.y * dt, 540.0, 682.0)

func _body_frame() -> String:
	if hurt_hold > 0.0 and K.has("player_body_hurt"):
		return "player_body_hurt"
	if vel.length() > 40.0 and roll <= 0.0 and K.has("player_body_walk2"):
		return "player_body_walk1" if sin(step_t) > 0.0 else "player_body_walk2"
	return "player_body"

func visual(dt: float) -> void:
	var rolling := roll > 0.0
	var speed := minf(1.0, vel.length() / 220.0)
	step_t += dt * (6.0 + vel.length() / 28.0) if vel.length() > 40.0 else 0.0
	if hit_t > 0.1:
		hurt_hold = 0.3
	hurt_hold = maxf(0.0, hurt_hold - dt)
	recoil = maxf(0.0, recoil - dt * 9.0)
	var fn := _body_frame()
	if fn != cur_body:
		cur_body = fn
		var tx := K.tex(fn)
		body.texture = tx
		cast.texture = tx
	cast.visible = not rolling
	if rolling:
		var k := 1.0 - roll / ROLL_TIME
		pivot.rotation = k * TAU * (1.0 if rd.x >= 0.0 else -1.0)
		pivot.scale = Vector2(1.0, 0.72)
		pivot.position = Vector2(0, -62)
	else:
		pivot.rotation = lerpf(pivot.rotation, vel.x / 380.0 * 0.06, minf(1.0, dt * 12.0))
		# respiracion en reposo, rebote al caminar y squash al disparar
		var breath := sin(t * 2.4) * 0.008 * (1.0 - speed)
		var bob := sin(step_t * 2.0)
		pivot.scale = Vector2(1.0 + recoil * 0.025 - bob * 0.01 * speed, 1.0 + breath - recoil * 0.03 + absf(bob) * 0.012 * speed)
		pivot.position = Vector2(0, -62 - absf(bob) * 3.0 * speed + recoil * 1.5)
	gun.visible = not rolling
	var sh := position + SHOULDER
	var ang := (aim_pos - sh).angle()
	gun_angle = ang
	gun.rotation = ang
	gun.scale = Vector2(0.5, -0.5 if absf(ang) > PI / 2.0 else 0.5)
	gun.position = SHOULDER - Vector2(cos(ang), sin(ang)) * recoil * 9.0 + Vector2(0, pivot.position.y + 62.0)
	muzzle = sh + Vector2(cos(ang), sin(ang)) * 74.0 * U
	modulate.a = 0.45 if (inv > 0.0 and not rolling and int(t * 24.0) % 2 == 1) else 1.0
	mat.set_shader_parameter("flash", clampf(hit_t / 0.18, 0.0, 1.0) * 0.85)
