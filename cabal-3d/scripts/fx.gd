extends Node3D
# Efectos visuales con pools: trazadoras, chispas, polvo, fogonazos, explosiones, marcas de quemadura, fuego y humo.
# Todo se reutiliza (sin crear recursos pesados por frame).

const TEX := "res://assets/third_party/kenney/particles/"
const RING_SHADER := preload("res://shaders/ring.gdshader")
const Assets = preload("res://scripts/assets.gd")

var game
var _mats := {}
var tracers: Array = []     # [{n, t, life}]
var spark_pool: Array = []
var dust_pool: Array = []
var muzzles: Array = []     # [{n, t}]
var boom_pool: Array = []   # [{fire, smoke, sparks, ring, light, t, scorch}]
var scorches: Array = []
var flame_lights: Array = []  # [{light, base, ph}]
var rings: Array = []
var _si := 0
var _di := 0
var _ti := 0
var _mi := 0
var _bi := 0
var _ci := 0
var tex_muzzle: Array = []

func _ready() -> void:
	if Assets.headless:
		return     # sin renderer (pruebas sin cabeza): los efectos visuales no existen
	for i in 5:
		tex_muzzle.append(load(TEX + "muzzle_0%d.png" % (i + 1)))
	# trazadoras
	var bm := BoxMesh.new()
	bm.size = Vector3(1, 1, 1)
	for i in 36:
		var m := MeshInstance3D.new()
		m.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.disable_fog = true
		m.material_override = mat
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		tracers.append({"n": m, "t": 0.0, "life": 0.07, "col": Color.WHITE})
	for i in 14:
		spark_pool.append(_make_sparks(8, 0.45))
	for i in 10:
		dust_pool.append(_make_dust())
	# fogonazos
	for i in 8:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		q.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = tex_muzzle[i % 5]
		mat.disable_fog = true
		q.material_override = mat
		q.visible = false
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		muzzles.append({"n": q, "t": 0.0})
	for i in 3:
		boom_pool.append(_make_boom())
	# marcas de quemadura
	for i in 8:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1)
		q.mesh = qm
		q.rotation_degrees.x = -90.0
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = load(TEX + "scorch_0%d.png" % (1 + i % 3))
		mat.albedo_color = Color(0.03, 0.025, 0.02, 0.0)
		q.material_override = mat
		q.visible = false
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(q)
		scorches.append({"n": q, "t": 0.0})
	_make_motes()

func pmat(tex: String, additive: bool) -> StandardMaterial3D:
	var key := tex + str(additive)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(TEX + tex + ".png")
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	m.disable_fog = additive
	_mats[key] = m
	return m

func _quad(mat: Material, size := 1.0) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	return q

func _ramp(c0: Color, c1: Color, fade_in := 0.08) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, fade_in, 1.0])
	g.colors = PackedColorArray([Color(c0.r, c0.g, c0.b, 0.0), c0, c1])
	return g

func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c

func _make_sparks(n: int, life: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.local_coords = false
	p.mesh = _quad(pmat("spark_05", true), 0.22)
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.color_ramp = _ramp(Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.3, 0.05, 0.0), 0.02)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _make_dust() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 5
	p.lifetime = 0.9
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.9
	p.local_coords = false
	p.mesh = _quad(pmat("smoke_04", false), 1.0)
	p.direction = Vector3.UP
	p.spread = 50.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, 0.2, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 0.9
	p.scale_amount_curve = _curve(0.5, 1.6)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.color_ramp = _ramp(Color(0.62, 0.52, 0.42, 0.55), Color(0.5, 0.42, 0.35, 0.0), 0.1)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

func _make_boom() -> Dictionary:
	var fire := CPUParticles3D.new()
	fire.amount = 18
	fire.lifetime = 0.75
	fire.one_shot = true
	fire.emitting = false
	fire.explosiveness = 0.95
	fire.local_coords = false
	fire.mesh = _quad(pmat("flame_05", true), 1.0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.6
	fire.direction = Vector3.UP
	fire.spread = 180.0
	fire.initial_velocity_min = 1.5
	fire.initial_velocity_max = 5.5
	fire.gravity = Vector3(0, 1.5, 0)
	fire.damping_min = 2.0
	fire.damping_max = 4.0
	fire.scale_amount_min = 2.2
	fire.scale_amount_max = 3.6
	fire.scale_amount_curve = _curve(0.6, 1.0)
	fire.angle_min = 0.0
	fire.angle_max = 360.0
	fire.color_ramp = _ramp(Color(1.0, 0.75, 0.35, 1.0), Color(0.8, 0.15, 0.02, 0.0), 0.05)
	fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fire)
	var smoke := CPUParticles3D.new()
	smoke.amount = 12
	smoke.lifetime = 2.0
	smoke.one_shot = true
	smoke.emitting = false
	smoke.explosiveness = 0.8
	smoke.local_coords = false
	smoke.mesh = _quad(pmat("smoke_02", false), 1.0)
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8
	smoke.direction = Vector3.UP
	smoke.spread = 60.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 0.8, 0)
	smoke.damping_min = 0.8
	smoke.damping_max = 1.6
	smoke.scale_amount_min = 2.5
	smoke.scale_amount_max = 4.0
	smoke.scale_amount_curve = _curve(0.5, 1.4)
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.color_ramp = _ramp(Color(0.16, 0.13, 0.12, 0.75), Color(0.1, 0.09, 0.09, 0.0), 0.12)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	var sp := _make_sparks(26, 0.9)
	sp.spread = 90.0
	sp.initial_velocity_min = 6.0
	sp.initial_velocity_max = 14.0
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2, 2)
	ring.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = RING_SHADER
	ring.material_override = sm
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = 16.0
	light.light_energy = 0.0
	light.visible = false
	add_child(light)
	return {"fire": fire, "smoke": smoke, "sparks": sp, "ring": ring, "light": light, "t": 99.0, "r": 4.0}

var motes: CPUParticles3D

# ajusta la nube de polvo ambiente al tamano del area jugable
func fit_motes(half: float) -> void:
	if motes == null:
		return
	motes.emission_box_extents = Vector3(half, 4.5, half)
	motes.amount = int(clampf(130.0 * (half / 32.0) * (half / 32.0), 130.0, 320.0))
	motes.restart()

func _make_motes() -> void:
	var p := CPUParticles3D.new()
	motes = p
	p.amount = 130
	p.lifetime = 10.0
	p.preprocess = 10.0
	p.local_coords = false
	p.mesh = _quad(pmat("circle_05", true), 0.09)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(32, 4.5, 32)
	p.position = Vector3(0, 4.5, 0)
	p.direction = Vector3(1, 0.1, 0.3)
	p.spread = 25.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, 0.04, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.1
	p.color_ramp = _ramp(Color(1.0, 0.82, 0.55, 0.45), Color(1.0, 0.82, 0.55, 0.0), 0.2)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)

# ---------------------------------------------------------------- API

func tracer(a: Vector3, b: Vector3, col: Color, w := 0.035, life := 0.07) -> void:
	if Assets.headless:
		return
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var t = tracers[_ti]
	_ti = (_ti + 1) % tracers.size()
	var n: MeshInstance3D = t.n
	n.visible = true
	t.a = a
	t.dir = (b - a).normalized()
	t.total = len
	t.head = 0.0
	t.speed = 170.0
	t.streak = minf(6.0, len)
	t.w = maxf(w * 1.5, 0.05)
	t.t = 1.0
	t.life = 1.0
	t.col = col
	(n.material_override as StandardMaterial3D).albedo_color = col

func sparks(pos: Vector3, normal: Vector3, big := false) -> void:
	if Assets.headless:
		return
	var p: CPUParticles3D = spark_pool[_si]
	_si = (_si + 1) % spark_pool.size()
	p.global_position = pos + normal * 0.05
	p.direction = normal
	p.restart()
	p.emitting = true

func dust(pos: Vector3, normal: Vector3, size := 1.0) -> void:
	if Assets.headless:
		return
	var p: CPUParticles3D = dust_pool[_di]
	_di = (_di + 1) % dust_pool.size()
	p.global_position = pos + normal * 0.1
	p.direction = normal
	p.scale_amount_min = 0.5 * size
	p.scale_amount_max = 0.9 * size
	p.restart()
	p.emitting = true

func muzzle(pos: Vector3, size := 0.7) -> void:
	if Assets.headless:
		return
	var m = muzzles[_mi]
	_mi = (_mi + 1) % muzzles.size()
	var n: MeshInstance3D = m.n
	n.global_position = pos
	(n.mesh as QuadMesh).size = Vector2(size, size)
	n.rotation.z = randf() * TAU
	n.visible = true
	m.t = 0.05

# altura del suelo bajo `pos` (el terreno de la arena no es plano)
func _gy(pos: Vector3) -> float:
	if game != null and game.level != null:
		return game.level.ground_y(pos)
	return 0.0

func scorch(pos: Vector3, radius: float) -> void:
	if Assets.headless:
		return
	var s = scorches[_ci]
	_ci = (_ci + 1) % scorches.size()
	var n: MeshInstance3D = s.n
	n.global_position = Vector3(pos.x, _gy(pos) + 0.06 + 0.002 * _ci, pos.z)
	n.scale = Vector3(radius * 2.4, radius * 2.4, 1.0)
	n.rotation.y = randf() * TAU
	n.visible = true
	s.t = 9.0

func explosion(pos: Vector3, radius: float) -> void:
	if Assets.headless:
		return
	var b = boom_pool[_bi]
	_bi = (_bi + 1) % boom_pool.size()
	var gp := Vector3(pos.x, maxf(pos.y, _gy(pos)) + 0.4, pos.z)
	for k in ["fire", "smoke", "sparks"]:
		var p: CPUParticles3D = b[k]
		p.global_position = gp
		p.restart()
		p.emitting = true
	var f: CPUParticles3D = b.fire
	f.scale_amount_min = radius * 0.5
	f.scale_amount_max = radius * 0.85
	var ring: MeshInstance3D = b.ring
	ring.global_position = Vector3(pos.x, _gy(pos) + 0.14, pos.z)
	ring.scale = Vector3(radius, 1, radius)
	ring.visible = true
	(ring.material_override as ShaderMaterial).set_shader_parameter("color", Color(1.0, 0.7, 0.4, 1.0))
	(ring.material_override as ShaderMaterial).set_shader_parameter("fill", 0.0)
	var l: OmniLight3D = b.light
	l.global_position = gp + Vector3(0, 1.0, 0)
	l.visible = true
	l.light_energy = 7.0
	b.t = 0.0
	b.r = radius
	scorch(pos, radius * 0.55)

func poof(pos: Vector3, big := false) -> void:
	if Assets.headless:
		return
	dust(pos + Vector3(0, 0.5, 0), Vector3.UP, 1.6 if big else 1.0)
	sparks(pos + Vector3(0, 1.0, 0), Vector3.UP)

# anillo de aviso en el suelo (devuelve el nodo; quien lo crea lo libera)
func make_ring(pos: Vector3, radius: float, col := Color(1.0, 0.25, 0.1)) -> MeshInstance3D:
	if Assets.headless:
		return null
	var ring := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	ring.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = RING_SHADER
	sm.set_shader_parameter("color", col)
	ring.material_override = sm
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(pos.x, _gy(pos) + 0.13, pos.z)
	return ring

# fuego con llamas, humo, chispas que suben y luz que parpadea
func make_fire(parent: Node, pos: Vector3, s := 1.0, light := true) -> Node3D:
	if Assets.headless:
		return null
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var fl := CPUParticles3D.new()
	fl.amount = 14
	fl.lifetime = 0.8
	fl.local_coords = false
	fl.mesh = _quad(pmat("flame_03", true), 1.0)
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 0.18 * s
	fl.direction = Vector3.UP
	fl.spread = 14.0
	fl.initial_velocity_min = 0.9 * s
	fl.initial_velocity_max = 1.7 * s
	fl.gravity = Vector3(0, 0.6, 0)
	fl.scale_amount_min = 0.9 * s
	fl.scale_amount_max = 1.4 * s
	fl.scale_amount_curve = _curve(1.0, 0.25)
	fl.angle_min = -15.0
	fl.angle_max = 15.0
	fl.color_ramp = _ramp(Color(1.0, 0.7, 0.3, 0.95), Color(0.9, 0.2, 0.02, 0.0), 0.08)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(fl)
	var sm := CPUParticles3D.new()
	sm.amount = 8
	sm.lifetime = 3.4
	sm.local_coords = false
	sm.mesh = _quad(pmat("smoke_07", false), 1.0)
	sm.position = Vector3(0, 0.9 * s, 0)
	sm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.2 * s
	sm.direction = Vector3.UP
	sm.spread = 10.0
	sm.initial_velocity_min = 1.0
	sm.initial_velocity_max = 1.6
	sm.gravity = Vector3(0.3, 0.3, 0.1)
	sm.scale_amount_min = 0.9 * s
	sm.scale_amount_max = 1.4 * s
	sm.scale_amount_curve = _curve(0.5, 2.6)
	sm.angle_min = 0.0
	sm.angle_max = 360.0
	sm.color_ramp = _ramp(Color(0.2, 0.17, 0.16, 0.5), Color(0.15, 0.13, 0.13, 0.0), 0.15)
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(sm)
	var em := CPUParticles3D.new()
	em.amount = 6
	em.lifetime = 2.0
	em.local_coords = false
	em.mesh = _quad(pmat("circle_05", true), 0.07)
	em.position = Vector3(0, 0.4 * s, 0)
	em.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	em.emission_sphere_radius = 0.2 * s
	em.direction = Vector3.UP
	em.spread = 25.0
	em.initial_velocity_min = 1.5
	em.initial_velocity_max = 3.0
	em.gravity = Vector3(0.4, 0.2, 0)
	em.color_ramp = _ramp(Color(1.0, 0.65, 0.2, 1.0), Color(1.0, 0.3, 0.05, 0.0), 0.05)
	em.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(em)
	if light:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.22)
		l.omni_range = 9.0 * s
		l.light_energy = 1.7
		l.omni_attenuation = 1.4
		l.position = Vector3(0, 1.0 * s, 0)
		root.add_child(l)
		flame_lights.append({"l": l, "base": 1.7, "ph": randf() * 10.0})
	return root

func _process(delta: float) -> void:
	if Assets.headless:
		return
	for t in tracers:
		if t.t > 0.0:
			var n: MeshInstance3D = t.n
			t.head += t.speed * delta
			var tail: float = t.head - t.streak
			if tail >= t.total:
				t.t = 0.0
				n.visible = false
			else:
				var s0: float = maxf(0.0, tail)
				var s1: float = minf(t.total, t.head)
				var seg: float = maxf(0.05, s1 - s0)
				var mid: Vector3 = t.a + t.dir * ((s0 + s1) * 0.5)
				n.global_transform = Transform3D(Basis.looking_at(t.dir, Vector3.UP).scaled(Vector3(t.w, t.w, seg)), mid)
	for m in muzzles:
		if m.t > 0.0:
			m.t -= delta
			if m.t <= 0.0:
				m.n.visible = false
	for b in boom_pool:
		if b.t < 3.0:
			b.t += delta
			var k: float = b.t / 0.45
			var ring: MeshInstance3D = b.ring
			if k < 1.0:
				(ring.material_override as ShaderMaterial).set_shader_parameter("pulse", k)
				(ring.material_override as ShaderMaterial).set_shader_parameter("strength", 1.0 - k)
			else:
				ring.visible = false
			var l: OmniLight3D = b.light
			l.light_energy = maxf(0.0, 7.0 * (1.0 - b.t / 0.4))
			if b.t > 0.4:
				l.visible = false
	for s in scorches:
		if s.t > 0.0:
			s.t -= delta
			var a := clampf(s.t / 3.0, 0.0, 1.0) * 0.7
			((s.n as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(0.03, 0.025, 0.02, a)
			if s.t <= 0.0:
				s.n.visible = false
	var tm := Time.get_ticks_msec() * 0.001
	for f in flame_lights:
		if is_instance_valid(f.l):
			f.l.light_energy = f.base * (0.8 + 0.25 * sin(tm * 11.0 + f.ph) + 0.15 * sin(tm * 23.0 + f.ph * 2.0))

func clear() -> void:
	if Assets.headless:
		return
	for t in tracers:
		t.t = 0.0
		t.n.visible = false
	for m in muzzles:
		m.t = 0.0
		m.n.visible = false
	for s in scorches:
		s.t = 0.0
		s.n.visible = false
	for b in boom_pool:
		b.t = 99.0
		b.ring.visible = false
		b.light.visible = false
