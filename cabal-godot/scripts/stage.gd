extends Node2D
# Escenario: iluminacion (ambiente + sol con altura), fondo en capas con paralaje, nubes que derivan,
# primer plano, destello de lente del sol, polvo en los haces de luz y datos de postproceso
# (fuentes de calor y ondas de choque).  Todo se degrada al fondo unico si faltan las capas nuevas.

const K = preload("res://scripts/k.gd")
const LAYER = preload("res://shaders/layer.gdshader")
const WISPS = preload("res://shaders/wisps.gdshader")

# Con mapas de normales el sol modula por relieve: ambiente mas oscuro y sol mas fuerte.  Sin ellos, valores planos clasicos.
const AMBIENT_LIT := Color(0.78, 0.74, 0.88)
const SUN_ENERGY_LIT := 0.62
const AMBIENT := Color(0.84, 0.80, 0.92)
const SUN_COLOR := Color(1.0, 0.74, 0.5)
const SUN_ENERGY := 0.30
const SUN_HEIGHT := 0.38
const SUN_ROT := 0.62            # la luz viaja hacia abajo-izquierda (viene del sol, arriba a la derecha)
const LAYER_SCALE := 0.56
# paralaje: [textura, amplitud px, desenfoque mip, bruma, seguimiento de camara]
const LAYERS := [["bg_sky", 6.0, 0.5, 0.0], ["bg_far", 14.0, 0.35, 0.10], ["bg_mid", 26.0, 0.0, 0.04], ["bg_ground", 38.0, 0.0, 0.0]]

var game
var layered := false
var layer_nodes: Array = []      # [{spr, amp}]
var single_bg: Sprite2D
var fg: Sprite2D
var fg_amp := 46.0
var sun: DirectionalLight2D
var modulate_node: CanvasModulate
var flare_layer: CanvasLayer
var flares: Array = []           # [{spr, k, a}]
var pm := Vector2.ZERO           # paralaje suavizado (-1..1)
var t := 0.0
var shocks: Array = []           # [{pos: Vector2, age: float, amp: float}]
var heats: Array = []            # [{pos: Vector2, age: float, life: float, str: float}]

func setup() -> void:
	modulate_node = CanvasModulate.new()
	var normals: bool = K.lit and K.has("player_body_n") and K.has("enemy_rifle_idle_n")
	modulate_node.color = AMBIENT_LIT if normals else AMBIENT
	add_child(modulate_node)
	sun = DirectionalLight2D.new()
	sun.color = SUN_COLOR
	sun.energy = SUN_ENERGY_LIT if normals else SUN_ENERGY
	sun.height = SUN_HEIGHT
	sun.rotation = SUN_ROT
	sun.range_item_cull_mask = 1   # solo sprites (con relieve)
	add_child(sun)
	# El fondo (capa de luz 2) recibe un sol plano aparte, para conservar sus colores originales.
	var bgsun := DirectionalLight2D.new()
	bgsun.color = Color(1.0, 0.82, 0.62)
	bgsun.energy = 0.42
	bgsun.range_item_cull_mask = 2
	add_child(bgsun)

	layered = K.has("bg_sky") and K.has("bg_far") and K.has("bg_mid") and K.has("bg_ground")
	if layered:
		var z := -100
		for L in LAYERS:
			var spr := Sprite2D.new()
			spr.texture = K.tex(L[0])
			spr.position = Vector2(640, 360)
			spr.scale = Vector2.ONE * LAYER_SCALE
			spr.z_index = z
			spr.light_mask = 2
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if L[2] > 0.0 or L[3] > 0.0:
				var m := ShaderMaterial.new()
				m.shader = LAYER
				m.set_shader_parameter("blur", L[2])
				m.set_shader_parameter("haze", L[3])
				spr.material = m
			add_child(spr)
			layer_nodes.append({"spr": spr, "amp": L[1]})
			z += 2
			if L[0] == "bg_sky":
				_add_wisps(-99)
	else:
		single_bg = Sprite2D.new()
		single_bg.texture = K.tex("background")
		single_bg.position = Vector2(640, 360)
		single_bg.light_mask = 2
		single_bg.scale = Vector2.ONE * 0.56
		single_bg.z_index = -100
		single_bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(single_bg)
		layer_nodes.append({"spr": single_bg, "amp": 20.0})

	if K.has("fg_rubble"):
		fg = Sprite2D.new()
		fg.texture = K.tex("fg_rubble")
		fg.scale = Vector2.ONE * 0.54
		fg.position = Vector2(640, 720.0 + 8.0 - 500.0 * 0.54 * 0.5)
		fg.z_index = 260
		fg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var m := ShaderMaterial.new()
		m.shader = LAYER
		m.set_shader_parameter("blur", 0.9)
		m.set_shader_parameter("tint", Color(0.82, 0.78, 0.9, 1.0))
		fg.material = m
		add_child(fg)

	_add_flare()
	_add_dust()

func _add_wisps(z: int) -> void:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.012
	n.fractal_octaves = 4
	var nt := NoiseTexture2D.new()
	nt.noise = n
	nt.seamless = true
	nt.width = 512
	nt.height = 256
	var s := Sprite2D.new()
	s.texture = K.square_tex()
	s.scale = Vector2(1400.0 / 8.0, 330.0 / 8.0)
	s.position = Vector2(640, 150)
	s.z_index = z
	var m := ShaderMaterial.new()
	m.shader = WISPS
	m.set_shader_parameter("noise", nt)
	s.material = m
	add_child(s)

# Destello de lente del sol: nucleo con fx_flare y fantasmas sobre el eje sol-centro, en una capa bajo el postproceso.
func _add_flare() -> void:
	flare_layer = CanvasLayer.new()
	flare_layer.layer = 3
	add_child(flare_layer)
	var core: Texture2D = K.tex("fx_flare") if K.has("fx_flare") else K.glow_tex()
	var ghost: Texture2D = K.glow_tex()
	var ring: Texture2D = K.ring_tex()
	# [textura, posicion sobre el eje (0 = sol, 1 = centro, >1 mas alla), tamano px, alfa, color]
	var defs := [
		[core, 0.0, 520.0, 0.26, Color(1.0, 0.82, 0.6)],
		[ghost, 0.55, 90.0, 0.10, Color(1.0, 0.6, 0.35)],
		[ring, 0.95, 220.0, 0.06, Color(0.8, 0.9, 1.0)],
		[ghost, 1.35, 150.0, 0.07, Color(0.6, 0.8, 1.0)],
		[ring, 1.8, 120.0, 0.05, Color(1.0, 0.7, 0.5)],
	]
	for d in defs:
		var s := Sprite2D.new()
		s.texture = d[0]
		s.material = K.additive()
		s.scale = Vector2.ONE * (d[2] / float(d[0].get_width()))
		s.modulate = Color(d[4].r, d[4].g, d[4].b, d[3])
		flare_layer.add_child(s)
		flares.append({"spr": s, "k": d[1], "a": d[3]})

# Motas de polvo flotando en el haz de luz del sol (un solo emisor, bajo alfa).
func _add_dust() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(780, 360)
	p.z_index = 190
	p.amount = 38
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(520, 250)
	p.direction = Vector2(-1, 0.25)
	p.spread = 60.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 20.0
	p.gravity = Vector2(0, 2)
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.03
	p.texture = K.glow_tex()
	p.material = K.additive()
	p.color = Color(1.0, 0.85, 0.62, 0.7)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	p.color_ramp = g
	add_child(p)
	p.emitting = true

# ---------------------------------------------------------------- datos para el postproceso
func shock(pos: Vector2, amp := 1.0) -> void:
	if shocks.size() >= 3:
		shocks.pop_front()
	shocks.append({"pos": pos, "age": 0.0, "amp": amp})

func heat(pos: Vector2, life := 0.9, strength := 1.0) -> void:
	if heats.size() >= 2:
		heats.pop_front()
	heats.append({"pos": pos, "age": 0.0, "life": life, "str": strength})

func _uv(p: Vector2) -> Vector2:
	return Vector2(p.x / 1280.0, p.y / 720.0)

# Se llama cada cuadro desde game._process con el estado actual.
func update(dt: float, mouse: Vector2, cam_off: Vector2, player_x: float, state: String, post: ShaderMaterial) -> void:
	t += dt
	var target := (mouse - Vector2(640, 360)) / Vector2(640, 360)
	target.x += (player_x - 640.0) / 640.0 * 0.7
	if state == "menu":
		# balanceo lento de camara en el menu, asi el fondo se mueve aunque no se toque nada
		target = Vector2(sin(t * 0.37) * 0.8, sin(t * 0.23) * 0.5)
	pm = pm.lerp(target.clamp(Vector2(-1.5, -1), Vector2(1.5, 1)), minf(1.0, dt * 3.0))
	for L in layer_nodes:
		var spr: Sprite2D = L["spr"]
		var a: float = L["amp"]
		spr.position = Vector2(640, 360) + cam_off * 0.5 + Vector2(-pm.x * a, -pm.y * a * 0.4)
	if layered:
		# las nubes del cielo derivan despacio
		(layer_nodes[0]["spr"] as Sprite2D).position.x += sin(t * 0.045) * 10.0
	if fg:
		fg.position.x = 640.0 + pm.x * fg_amp + cam_off.x
		fg.position.y = 720.0 + 8.0 - 500.0 * 0.54 * 0.5 + pm.y * 10.0

	# destello de lente: se mueve con el paralaje del cielo; eje sol -> centro de pantalla
	var sunp := K.SUN_POS + Vector2(-pm.x * 6.0, -pm.y * 2.5)
	var axis := Vector2(640, 360) - sunp
	for f in flares:
		(f["spr"] as Sprite2D).position = sunp + axis * f["k"]
		var pulse := 0.85 + 0.15 * sin(t * 1.7 + f["k"] * 3.0)
		var m: Color = (f["spr"] as Sprite2D).modulate
		(f["spr"] as Sprite2D).modulate = Color(m.r, m.g, m.b, f["a"] * pulse)

	# postproceso
	for i in range(shocks.size() - 1, -1, -1):
		shocks[i]["age"] += dt
		if shocks[i]["age"] > 0.7:
			shocks.remove_at(i)
	for i in range(heats.size() - 1, -1, -1):
		heats[i]["age"] += dt
		if heats[i]["age"] > heats[i]["life"]:
			heats.remove_at(i)
	for i in 3:
		var v := Vector4(0, 0, -1, 0)
		if i < shocks.size():
			var u := _uv(shocks[i]["pos"])
			v = Vector4(u.x, u.y, shocks[i]["age"], shocks[i]["amp"])
		post.set_shader_parameter("shock%d" % i, v)
	for i in 2:
		var v := Vector4(0, 0, 0.1, 0)
		if i < heats.size():
			var h = heats[i]
			var u := _uv(h["pos"])
			v = Vector4(u.x, u.y, 0.11, h["str"] * (1.0 - h["age"] / h["life"]))
		post.set_shader_parameter("heat%d" % i, v)
	# fuegos fijos del horizonte (derivados del fondo)
	post.set_shader_parameter("heat2", Vector4(0.32 + pm.x * 0.01, 0.375, 0.08, 0.55))
	post.set_shader_parameter("heat3", Vector4(0.83 + pm.x * 0.01, 0.375, 0.08, 0.55))
