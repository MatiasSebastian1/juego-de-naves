extends Node2D
# Particulas, luces, destellos y textos flotantes (todo efimero).

const K = preload("res://scripts/k.gd")

func _emit(p: CPUParticles2D, life: float, pos: Vector2, zi := 160) -> void:
	p.position = pos
	p.z_index = zi
	p.one_shot = true
	p.explosiveness = 1.0
	add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.4).timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func sparks(pos: Vector2, n: int, col := Color(1.0, 0.82, 0.48)) -> void:
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = 0.45
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.12
	p.texture = K.glow_tex()
	p.material = K.additive()
	p.color = col
	p.color_ramp = K.fade_ramp(Color(1, 1, 1, 1), Color(1, 0.5, 0.2, 0))
	_emit(p, 0.45, pos)

func smoke(pos: Vector2, n: int, size := 40.0, col := Color(0.35, 0.3, 0.3, 0.55)) -> void:
	var p := CPUParticles2D.new()
	p.amount = n
	p.lifetime = 1.1
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 10.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, -30)
	var s := size * 2.0 / 256.0
	p.scale_amount_min = s * 0.6
	p.scale_amount_max = s * 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	p.texture = K.soft_tex()
	p.color = col
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	p.color_ramp = g
	_emit(p, 1.1, pos, 150)

func debris(pos: Vector2, n: int, col := Color(0.35, 0.28, 0.22)) -> void:
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
	p.color_ramp = K.fade_ramp(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	_emit(p, 0.9, pos)

func fire(pos: Vector2, big := 1.0) -> void:
	var p := CPUParticles2D.new()
	p.amount = int(18 * big)
	p.lifetime = 0.7
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 150.0 * big
	p.gravity = Vector2(0, -40)
	p.scale_amount_min = 0.3 * big
	p.scale_amount_max = 0.9 * big
	p.texture = K.glow_tex()
	p.material = K.additive()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.9, 0.55, 1.0), Color(1.0, 0.45, 0.12, 0.8), Color(0.6, 0.1, 0.05, 0.0)])
	p.color_ramp = g
	_emit(p, 0.7, pos, 158)

func ring(pos: Vector2, radius: float) -> void:
	var s := Sprite2D.new()
	s.texture = K.ring_tex()
	s.material = K.additive()
	s.position = pos
	s.z_index = 157
	s.scale = Vector2.ONE * 0.1
	add_child(s)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * (radius * 2.0 / 256.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(s.queue_free)

func light_flash(pos: Vector2, energy := 2.0, scale := 6.0, col := Color(1.0, 0.7, 0.4), dur := 0.3) -> void:
	var l := PointLight2D.new()
	l.texture = K.glow_tex()
	l.texture_scale = scale
	l.energy = energy
	l.color = col
	l.position = pos
	l.z_index = 159
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "energy", 0.0, dur)
	tw.tween_callback(l.queue_free)

func muzzle(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = K.glow_tex()
	s.material = K.additive()
	s.position = pos
	s.scale = Vector2.ONE * 0.5
	s.modulate = Color(1.0, 0.85, 0.5)
	s.z_index = 210
	add_child(s)
	get_tree().create_timer(0.05).timeout.connect(func(): if is_instance_valid(s): s.queue_free())
	light_flash(pos, 1.4, 3.0, Color(1.0, 0.78, 0.45), 0.09)

func tracer(a: Vector2, b: Vector2) -> void:
	var l := Line2D.new()
	l.points = PackedVector2Array([a, b])
	l.width = 3.0
	l.default_color = Color(1.0, 0.9, 0.62)
	l.material = K.additive()
	l.z_index = 205
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.07)
	tw.tween_callback(l.queue_free)

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
	e.color_ramp = K.fade_ramp(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	add_child(e)
	e.emitting = true
