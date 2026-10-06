extends Node2D
# Particulas, luces, destellos y textos flotantes (todo efimero).

const K = preload("res://scripts/k.gd")

const MAX_EMITTERS := 56   # tope de emisores de particulas vivos (cuida los 60 FPS en combates intensos)
const MAX_LIGHTS := 8      # tope de luces dinamicas simultaneas

const MAX_CASINGS := 20

var _casings: Array = []
var _scorches: Array = []
var _trace_curve: Curve
var _trace_grad: Gradient
var _emitters := 0
var _lights := 0
# Recursos constantes compartidos por todas las particulas (no se crean por disparo)
var _smoke_curve: Curve
var _smoke_ramp: Gradient
var _fire_ramp: Gradient

func _ready() -> void:
	_trace_curve = Curve.new()
	_trace_curve.add_point(Vector2(0, 0.1))
	_trace_curve.add_point(Vector2(1, 1.0))
	_trace_grad = Gradient.new()
	_trace_grad.offsets = PackedFloat32Array([0.0, 1.0])
	_trace_grad.colors = PackedColorArray([Color(1.0, 0.6, 0.3, 0.0), Color(1.0, 0.95, 0.75, 1.0)])
	_smoke_curve = Curve.new()
	_smoke_curve.add_point(Vector2(0, 0.5))
	_smoke_curve.add_point(Vector2(1, 1.6))
	_smoke_ramp = Gradient.new()
	_smoke_ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	_smoke_ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	_fire_ramp = Gradient.new()
	_fire_ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	_fire_ramp.colors = PackedColorArray([Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.45, 0.12, 0.8), Color(0.6, 0.1, 0.05, 0.0)])

func _emit(p: CPUParticles2D, life: float, pos: Vector2, zi := 160) -> void:
	_emitters += 1
	p.position = pos
	p.z_index = zi
	p.one_shot = true
	p.explosiveness = 1.0
	add_child(p)
	p.emitting = true
	# el timer se detiene con la pausa (process_always = false) para que las particulas no desaparezcan
	get_tree().create_timer(life + 0.4, false).timeout.connect(func():
		_emitters -= 1
		if is_instance_valid(p):
			p.queue_free())

func sparks(pos: Vector2, n: int, col := Color(1.0, 0.82, 0.48)) -> void:
	if _emitters >= MAX_EMITTERS:
		return
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = 0.5
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 760)
	p.damping_min = 20.0
	p.damping_max = 70.0
	# chispas alargadas con estela: la textura se alinea con la velocidad
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.8
	p.texture = K.streak_tex()
	p.material = K.additive()
	p.color = col
	p.color_ramp = K.ramp("spark", Color(1, 1, 1, 1), Color(1, 0.45, 0.15, 0))
	_emit(p, 0.5, pos)
	if n >= 8:
		flash_sprite(pos, 0.16, 1.1 if n < 14 else 1.8, col)

# Destello breve de estrella (fx_spark) en un punto: impactos fuertes.
func flash_sprite(pos: Vector2, dur: float, size: float, col := Color(1.0, 0.85, 0.55)) -> void:
	var s := Sprite2D.new()
	s.texture = K.tex("fx_spark") if K.has("fx_spark") else K.glow_tex()
	s.material = K.additive()
	s.position = pos
	s.rotation = randf() * TAU
	s.modulate = Color(col.r, col.g, col.b, 1.0)
	s.z_index = 208
	var base := size * 64.0 / maxf(1.0, float(s.texture.get_width()))
	s.scale = Vector2.ONE * base * 0.5
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * base, dur * 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, dur).set_delay(dur * 0.2)
	tw.chain().tween_callback(s.queue_free)

func _smoke_tex() -> Texture2D:
	var t := K.kp_rand("smoke", 8)
	if t == null:
		t = K.tex("fx_smoke_puff") if K.has("fx_smoke_puff") else K.soft_tex()
	return t

# Humo volumetrico: puffs rotados con texturas variadas; los grandes suman una capa clara y calida (iluminada por el fuego).
func smoke(pos: Vector2, n: int, size := 40.0, col := Color(0.35, 0.3, 0.3, 0.55)) -> void:
	if _emitters >= MAX_EMITTERS:
		return
	var layers := 2 if (n >= 6 and _emitters < MAX_EMITTERS - 12) else 1
	for li in layers:
		var p := CPUParticles2D.new()
		var tx := _smoke_tex()
		p.amount = n if li == 0 else maxi(3, n / 2)
		p.lifetime = 1.3 if li == 0 else 0.9
		p.direction = Vector2(0, -1)
		p.spread = 180.0
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 70.0 if li == 0 else 110.0
		p.damping_min = 10.0
		p.damping_max = 40.0
		p.gravity = Vector2(14, -34)
		p.angle_min = -180.0
		p.angle_max = 180.0
		p.angular_velocity_min = -40.0
		p.angular_velocity_max = 40.0
		var s := size * 2.0 / float(tx.get_width())
		p.scale_amount_min = s * (0.6 if li == 0 else 0.45)
		p.scale_amount_max = s * (1.1 if li == 0 else 0.8)
		p.scale_amount_curve = _smoke_curve
		p.texture = tx
		if li == 0:
			p.color = col
			p.color_ramp = _smoke_ramp
		else:
			# capa interior: tono de brasa que se apaga rapido
			p.color = Color(1.0, 0.6, 0.35, col.a * 0.7)
			p.color_ramp = K.ramp("ember_smoke", Color(1, 1, 1, 0.9), Color(0.3, 0.2, 0.2, 0))
			p.material = K.additive()
		_emit(p, p.lifetime, pos, 150 if li == 0 else 152)

func debris(pos: Vector2, n: int, col := Color(0.35, 0.28, 0.22)) -> void:
	if _emitters >= MAX_EMITTERS:
		return
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 80.0
	p.initial_velocity_min = 100.0
	p.initial_velocity_max = 440.0
	p.gravity = Vector2(0, 1100)
	p.angular_velocity_min = -600.0
	p.angular_velocity_max = 600.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.texture = K.square_tex()
	p.color = col
	p.color_ramp = K.ramp("fade", Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	_emit(p, 0.9, pos)

# Explosion: nucleo de fuego (texturas de Kenney variadas) + lenguas de llama que suben + destello de estrella.
func fire(pos: Vector2, big := 1.0) -> void:
	if _emitters >= MAX_EMITTERS + 8:
		return
	var core: Texture2D = K.kp_rand("fire", 2)
	var p := CPUParticles2D.new()
	p.amount = int(16 * big)
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 150.0 * big
	p.gravity = Vector2(0, -40)
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.material = K.additive()
	p.color_ramp = _fire_ramp
	if core != null:
		var s := 150.0 * big / float(core.get_width())
		p.scale_amount_min = s * 0.5
		p.scale_amount_max = s * 1.0
		p.texture = core
	else:
		p.scale_amount_min = 0.3 * big
		p.scale_amount_max = 0.9 * big
		p.texture = K.glow_tex()
	_emit(p, 0.7, pos, 158)
	var fl: Texture2D = K.kp_rand("flame", 6) if randf() < 0.5 else K.kp("flame_05")
	if fl != null and _emitters < MAX_EMITTERS + 8:
		var q := CPUParticles2D.new()
		q.amount = int(7 * big)
		q.lifetime = 0.65
		q.direction = Vector2(0, -1)
		q.spread = 40.0
		q.initial_velocity_min = 40.0
		q.initial_velocity_max = 130.0 * big
		q.gravity = Vector2(0, -80)
		q.angle_min = -25.0
		q.angle_max = 25.0
		var s2 := 130.0 * big / float(fl.get_width())
		q.scale_amount_min = s2 * 0.6
		q.scale_amount_max = s2 * 1.2
		q.texture = fl
		q.material = K.additive()
		q.color_ramp = _fire_ramp
		_emit(q, 0.65, pos + Vector2(0, 6), 159)
	flash_sprite(pos, 0.25, 1.8 * big, Color(1.0, 0.8, 0.5))

# Onda de choque en el suelo (anillo aplastado).
func ring(pos: Vector2, radius: float) -> void:
	var s := Sprite2D.new()
	s.texture = K.tex("fx_shockwave") if K.has("fx_shockwave") else K.ring_tex()
	s.material = K.additive()
	s.position = pos
	s.z_index = 157
	var base := radius * 2.0 / float(s.texture.get_width())
	s.scale = Vector2(0.1, 0.06)
	s.modulate = Color(1.0, 0.85, 0.65, 0.9)
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2(base, base * 0.55), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(s.queue_free)

# Marca de quemadura en el suelo que se desvanece lentamente.
func scorch(pos: Vector2, size := 120.0) -> void:
	var tx := K.kp_rand("scorch", 3)
	if tx == null or pos.y < K.HOR + 20.0:
		return
	while _scorches.size() >= 10:
		var old = _scorches.pop_front()
		if is_instance_valid(old):
			old.queue_free()   # su tween se corta solo al liberarse el nodo
	var s := Sprite2D.new()
	s.texture = tx
	s.position = pos + Vector2(0, 8)
	s.rotation = randf() * TAU
	var k := size / float(tx.get_width())
	s.scale = Vector2(k, k * 0.45)
	s.rotation = 0.0
	s.modulate = Color(0.04, 0.02, 0.02, 0.0)
	s.z_index = -50
	s.light_mask = 0
	add_child(s)
	_scorches.append(s)
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 0.55, 0.15)
	tw.tween_property(s, "modulate:a", 0.0, 9.0).set_delay(3.0)
	tw.tween_callback(func():
		_scorches.erase(s)
		if is_instance_valid(s):
			s.queue_free())

func light_flash(pos: Vector2, energy := 2.0, scale := 6.0, col := Color(1.0, 0.7, 0.4), dur := 0.3) -> void:
	if _lights >= MAX_LIGHTS:
		return
	_lights += 1
	var l := PointLight2D.new()
	l.texture = K.glow_tex()
	l.texture_scale = scale
	l.energy = energy
	l.color = col
	l.height = 55.0 + scale * 6.0   # altura sobre el plano: da relieve con los mapas de normales
	l.position = pos
	l.z_index = 159
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "energy", 0.0, dur)
	tw.tween_callback(func():
		_lights -= 1
		l.queue_free())

# Fogonazo de boca: llama de Kenney orientada al apuntado (+ estrella de fx_muzzle y resplandor).
func muzzle(pos: Vector2, ang := 1000.0) -> void:
	var aimed := ang < 999.0
	var m: Texture2D = K.kp_rand("muzzle", 5) if aimed else null
	if m != null:
		var f := Sprite2D.new()
		f.texture = m
		f.material = K.additive()
		f.centered = false
		# la llama de Kenney apunta hacia arriba con la base abajo: se ancla la base en la boca
		f.offset = Vector2(-m.get_width() * 0.5, -m.get_height() * 0.9)
		f.position = pos
		f.rotation = ang + PI / 2.0
		var k := randf_range(0.2, 0.3)
		f.scale = Vector2(k * 0.9, k * randf_range(0.9, 1.25))
		f.modulate = Color(1.0, 0.85, 0.55)
		f.z_index = 210
		add_child(f)
		get_tree().create_timer(0.055, false).timeout.connect(func(): if is_instance_valid(f): f.queue_free())
	var s := Sprite2D.new()
	s.texture = K.tex("fx_muzzle") if K.has("fx_muzzle") else K.glow_tex()
	s.material = K.additive()
	s.position = pos
	s.rotation = randf() * TAU
	var w := float(s.texture.get_width())
	s.scale = Vector2.ONE * (0.5 * 256.0 / w if K.has("fx_muzzle") else 0.5) * (0.5 if m != null else 0.7)
	s.modulate = Color(1.0, 0.85, 0.5)
	s.z_index = 211
	add_child(s)
	get_tree().create_timer(0.05, false).timeout.connect(func(): if is_instance_valid(s): s.queue_free())
	light_flash(pos, 1.4, 3.0, Color(1.0, 0.78, 0.45), 0.09)

# Trazo luminoso de un disparo del jugador: se afina y se apaga hacia la boca del arma.
func tracer(a: Vector2, b: Vector2) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = 4.0
	l.width_curve = _trace_curve
	l.gradient = _trace_grad
	l.default_color = Color(1.0, 0.9, 0.62)
	l.material = K.additive()
	l.z_index = 205
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.08)
	tw.tween_callback(l.queue_free)

# Casquillo expulsado: sale hacia arriba y a un lado, rebota en el suelo y se desvanece.
func shell_eject(pos: Vector2, ang: float, ground_y: float) -> void:
	if _casings.size() >= MAX_CASINGS:
		return
	var s := Sprite2D.new()
	if K.has("fx_shell"):
		s.texture = K.tex("fx_shell")
		s.scale = Vector2.ONE * 1.1
	else:
		s.texture = K.square_tex()
		s.scale = Vector2(1.4, 0.7)
		s.modulate = Color(0.95, 0.75, 0.3)
	s.position = pos
	s.z_index = 204
	add_child(s)
	var perp := Vector2(sin(ang), -cos(ang))
	_casings.append({"n": s, "v": perp * randf_range(90.0, 170.0) + Vector2(randf_range(-30.0, 30.0), randf_range(-170.0, -90.0)),
		"w": randf_range(-18.0, 18.0), "gy": ground_y + randf_range(-6.0, 10.0), "t": 0.0, "b": 0})

func _process(dt: float) -> void:
	for i in range(_casings.size() - 1, -1, -1):
		var c = _casings[i]
		var n: Sprite2D = c["n"]
		c["t"] += dt
		var done: bool = c["t"] > 1.6 or not is_instance_valid(n)
		if not done:
			var v: Vector2 = c["v"]
			if c["b"] < 3 or n.position.y < c["gy"] - 0.5:
				v.y += 1000.0 * dt
				n.position += v * dt
				n.rotation += c["w"] * dt
				if n.position.y > c["gy"] and v.y > 0.0:
					n.position.y = c["gy"]
					v.y *= -0.38
					v.x *= 0.6
					c["w"] *= 0.5
					c["b"] += 1
					if c["b"] >= 3 or absf(v.y) < 40.0:
						v = Vector2.ZERO
						c["b"] = 3
				c["v"] = v
			n.modulate.a = 1.0 - clampf((c["t"] - 1.0) / 0.6, 0.0, 1.0)
		if done:
			if is_instance_valid(n):
				n.queue_free()
			_casings.remove_at(i)

func floater(pos: Vector2, text: String, col := Color.WHITE) -> void:
	var lb := Label.new()
	lb.text = text
	lb.size = Vector2(300, 32)
	lb.position = pos - Vector2(150, 16)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 24)
	lb.add_theme_color_override("font_color", col)
	lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lb.add_theme_constant_override("outline_size", 7)
	lb.z_index = 300
	add_child(lb)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lb, "position:y", lb.position.y - 42.0, 0.9)
	tw.tween_property(lb, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(lb.queue_free)

func dust(pos: Vector2, n := 2) -> void:
	smoke(pos, n, 14.0, Color(0.55, 0.47, 0.4, 0.5))

# Ambiente: humo de columnas lejanas y brasas flotando.
func ambient() -> void:
	for sx in [140.0, 430.0, 720.0, 1040.0, 1210.0]:
		var p := CPUParticles2D.new()
		p.position = Vector2(sx, K.HOR - 8.0)
		p.z_index = -60
		p.amount = 14
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.direction = Vector2(0.25, -1)
		p.spread = 8.0
		p.initial_velocity_min = 18.0
		p.initial_velocity_max = 30.0
		p.gravity = Vector2.ZERO
		p.scale_amount_min = 0.35
		p.scale_amount_max = 0.55
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(1, 1.9))
		p.scale_amount_curve = curve
		p.texture = K.soft_tex()
		p.color = Color(0.11, 0.08, 0.1, 0.9)
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		p.color_ramp = g
		add_child(p)
		p.emitting = true
	var e := CPUParticles2D.new()
	e.position = Vector2(640, K.H + 10.0)
	e.z_index = 400
	e.amount = 45
	e.lifetime = 9.0
	e.preprocess = 9.0
	e.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	e.emission_rect_extents = Vector2(700, 4)
	e.direction = Vector2(-0.2, -1)
	e.spread = 25.0
	e.initial_velocity_min = 40.0
	e.initial_velocity_max = 110.0
	e.gravity = Vector2.ZERO
	e.scale_amount_min = 0.012
	e.scale_amount_max = 0.03
	e.texture = K.glow_tex()
	e.material = K.additive()
	e.color = Color(1.0, 0.62, 0.25, 0.8)
	e.color_ramp = K.ramp("fade", Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	add_child(e)
	e.emitting = true
