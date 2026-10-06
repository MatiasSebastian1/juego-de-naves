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
var mat: ShaderMaterial

func _ready() -> void:
	z_index = 200
	shadow = Sprite2D.new()
	shadow.texture = K.shadow_tex()
	shadow.scale = Vector2(34.0 * U * 2.0 / 256.0, 9.0 * U * 2.0 / 256.0)
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

func visual(dt: float) -> void:
	var rolling := roll > 0.0
	var speed := minf(1.0, vel.length() / 220.0)
	if rolling:
		var k := 1.0 - roll / ROLL_TIME
		pivot.rotation = k * TAU * (1.0 if rd.x >= 0.0 else -1.0)
		pivot.scale = Vector2(1.0, 0.72)
	else:
		pivot.rotation = lerpf(pivot.rotation, vel.x / 380.0 * 0.06, minf(1.0, dt * 12.0))
		pivot.scale = Vector2(1.0, 1.0 + sin(t * 12.0) * 0.012 * speed)
	gun.visible = not rolling
	var sh := position + SHOULDER
	var ang := (aim_pos - sh).angle()
	gun.rotation = ang
	gun.scale = Vector2(0.5, -0.5 if absf(ang) > PI / 2.0 else 0.5)
	muzzle = sh + Vector2(cos(ang), sin(ang)) * 74.0 * U
	modulate.a = 0.45 if (inv > 0.0 and not rolling and int(t * 24.0) % 2 == 1) else 1.0
	mat.set_shader_parameter("flash", clampf(hit_t / 0.18, 0.0, 1.0) * 0.85)
