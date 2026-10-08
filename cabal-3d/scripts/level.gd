extends Node3D
# Escenario del juego. Dos variantes:
#  * ARENA MESHY (la normal): una aldea del desierto generada con Meshy AI (assets/meshy/oasis_village.glb), escalada,
#    con colision trimesh del propio mesh, cobertura baja del Survival Kit colocada sobre el terreno real y una grilla A*
#    horneada al arrancar muestreando la fisica (ver _bake_village).
#  * FALLBACK KENNEY: el patio industrial de 60x60 m de antes (suelo procedural, cobertura, cerco), que se usa si el GLB
#    de Meshy no existe (o con Level.force_fallback = true, para las pruebas).
# En los dos casos: cielo/niebla/luces al atardecer, fuego y una grilla AStarGrid2D de 1 m para los enemigos.

const Assets = preload("res://scripts/assets.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const SAND_SHADER := preload("res://shaders/sand.gdshader")
const SV := "res://assets/third_party/kenney/survival/"

# Parametros de la arena Meshy. Para usar OTRA arena: cambia "path", ajusta "scale" (el GLB de Meshy mide ~1.9 u de lado),
# "play_half" (semilado jugable, en metros ya escalados) y "start_hint"; ver README.md de cabal-3d.
const ARENA := {
	"path": "res://assets/meshy/oasis_village.glb",
	"scale": 52.0,            # 1.9 u * 52 = ~99 m de lado; la puerta de una casa queda de ~2 m (el personaje mide 1.8 m)
	"yaw": 0.0,               # giro del mesh en grados
	"play_half": 41.0,        # el area jugable es el cuadrado [-41, 41] (el borde del diorama queda fuera)
	"start_hint": Vector2(8.0, 22.0),   # el jugador empieza en la celda abierta alcanzable mas cercana a este punto
	"look_at": Vector2(0.0, 0.0),       # y mira hacia este punto (el centro de la aldea)
	"sun_az": 55.0,           # azimut del sol respecto de la vista inicial (+ = a la izquierda), en grados
	"sun_el": 28.0,           # elevacion del sol (atardecer: bajo)
	"cover_count": 30,        # grupos de cobertura baja (cajas, barriles, paneles) sobre espacio abierto
	"water": true,            # las celdas con textura celeste (agua) se tratan como inaccesibles
}

const HALF := 30.0         # semilado del patio de respaldo (Kenney)
const GRID_N := 64         # celdas de 1 m del patio de respaldo, de -32 a 32
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_LIMIT := 8         # limites invisibles del area jugable: solo frenan a personajes (no a disparos ni camara)

# --- parametros del horneado de la aldea
const MIN_NY := 0.66            # una superficie con normal.y menor (pendiente > ~49 grados) no se camina
const STEP_MAX := 0.8           # desnivel maximo entre celdas vecinas de 1 m
const CAP_R := 0.6              # radio con el que se prueba si una celda esta libre (jefe = 0.66)
const CAP_LIFT := 0.32          # la capsula de prueba flota un poco (ignora irregularidades chicas)
const CAP_H := 1.9

static var force_fallback := false

var fx
var meshy := false           # true: arena Meshy; false: patio Kenney de respaldo
var half := HALF             # semilado del area jugable
var gn := GRID_N             # celdas por lado de la grilla
var gorg := 32.0             # celda = floor(p + gorg)
var hgrid := PackedFloat32Array()   # altura del suelo por celda (vacio = 0)
var start_pos := Vector3(0, 0.0, 18)
var start_yaw := 0.0
var center_pos := Vector3.ZERO
var water_cells := 0
var water_pts: PackedVector2Array = PackedVector2Array()   # centros de celdas de agua (depuracion)
var reach_cells := 0
var bake_ms := 0
var village: Node3D
var village_mesh: MeshInstance3D
var village_scale := 1.0
var ground_ref := 0.0        # el mesh se baja para que el suelo de la plaza quede cerca de y=0
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var covers: Array = []        # {pos, half(Vector3), low, rect, yaw}
var cover_points: Array = []  # {pos, dir, low, hl, taken}
var obstacles: Array = []     # Rect2 (xz) bloqueados para pathing
var grid: AStarGrid2D
var spawn_points: Array = []
var fires: Array = []
var rng := RandomNumberGenerator.new()

# Construye el escenario. En la arena Meshy deja pendiente el horneado de navegacion: la fisica solo responde a
# consultas despues de un frame, asi que quien llama debe hacer `await get_tree().physics_frame` y luego `bake()`.
func build(fx_node) -> void:
	fx = fx_node
	rng.seed = 20260
	meshy = not force_fallback and ResourceLoader.exists(ARENA.path)
	_environment()
	if meshy:
		half = ARENA.play_half
		_village_visual()
		return
	_build_fallback()

func _build_fallback() -> void:
	_ground()
	_walls()
	_layout()
	_perimeter()
	_fires()
	_make_grid()
	_make_cover_points()
	start_pos = Vector3(0, 0.0, 18)
	start_yaw = 0.0
	for x in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		spawn_points.append(Vector3(x, 0.0, -27.0))
	for z in [-14.0, 0.0, 14.0]:
		spawn_points.append(Vector3(-27.0, 0.0, z))
		spawn_points.append(Vector3(27.0, 0.0, z))
	for x in [-20.0, 20.0]:
		spawn_points.append(Vector3(x, 0.0, 27.0))

# ---------------------------------------------------------------- entorno

# Orienta el sol respecto de la vista inicial del jugador y ajusta la luz al material PBR de la aldea.
func _tune_village_light() -> void:
	var f := Vector3(-sin(start_yaw), 0.0, -cos(start_yaw))
	var toward := f.rotated(Vector3.UP, deg_to_rad(float(ARENA.sun_az)))
	var el := deg_to_rad(float(ARENA.sun_el))
	var travel := Vector3(-toward.x * cos(el), -sin(el), -toward.z * cos(el)).normalized()
	sun.global_transform = Transform3D(Basis.looking_at(travel, Vector3.UP), Vector3.ZERO)
	var back := f.rotated(Vector3.UP, deg_to_rad(float(ARENA.sun_az) + 200.0))
	var ft := Vector3(-back.x * 0.8, -0.6, -back.z * 0.8).normalized()
	fill_light.global_transform = Transform3D(Basis.looking_at(ft, Vector3.UP), Vector3.ZERO)

func _environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.13, 0.17, 0.38)
	sky_mat.sky_horizon_color = Color(0.98, 0.55, 0.32)
	sky_mat.sky_curve = 0.16
	sky_mat.ground_horizon_color = Color(0.86, 0.5, 0.34)
	sky_mat.ground_bottom_color = Color(0.2, 0.15, 0.17)
	sky_mat.ground_curve = 0.06
	sky_mat.sun_angle_max = 32.0
	sky_mat.sun_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.75
	env.ambient_light_color = Color(0.7, 0.6, 0.62)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.93, 0.56, 0.4) if not meshy else Color(0.9, 0.62, 0.52)
	env.fog_density = 0.0058 if not meshy else 0.0042
	env.fog_sky_affect = 0.45
	env.fog_sun_scatter = 0.25
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# sol calido, bajo, con sombras
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-23.0, 232.0, 0.0)
	sun.light_color = Color(1.0, 0.7, 0.45) if not meshy else Color(1.0, 0.75, 0.55)
	sun.light_energy = 1.75 if not meshy else 1.5
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 75.0 if not meshy else 90.0
	sun.directional_shadow_split_1 = 0.28 if not meshy else 0.24
	sun.shadow_bias = 0.05 if not meshy else 0.4       # el terreno de Meshy es irregular y rasante al sol: mucho sesgo contra el acne
	sun.shadow_normal_bias = 1.0 if not meshy else 3.2
	sun.shadow_blur = 1.4
	add_child(sun)
	# relleno frio sin sombras (separa a los personajes del fondo calido)
	var fill := DirectionalLight3D.new()
	fill_light = fill
	fill.rotation_degrees = Vector3(-35.0, 50.0, 0.0)
	fill.light_color = Color(0.5, 0.6, 1.0)
	fill.light_energy = 0.42
	fill.shadow_enabled = false
	add_child(fill)

func _ground() -> void:
	if not Assets.headless:
		var m := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(220, 220)
		m.mesh = pm
		var mat := ShaderMaterial.new()
		mat.shader = GROUND_SHADER
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	var b := StaticBody3D.new()
	b.collision_layer = L_WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(220, 2, 220)
	cs.shape = bs
	cs.position.y = -1.0
	b.add_child(cs)
	add_child(b)

func _wall_box(center: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	b.collision_layer = L_WORLD
	b.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	b.position = center
	add_child(b)

func _walls() -> void:
	# limites invisibles del patio (los edificios y el cerco quedan fuera)
	var h := 12.0
	var e := HALF + 1.5
	_wall_box(Vector3(0, h / 2, -e - 1), Vector3(2 * e + 4, h, 2))
	_wall_box(Vector3(0, h / 2, e + 1), Vector3(2 * e + 4, h, 2))
	_wall_box(Vector3(-e - 1, h / 2, 0), Vector3(2, h, 2 * e + 4))
	_wall_box(Vector3(e + 1, h / 2, 0), Vector3(2, h, 2 * e + 4))

# ---------------------------------------------------------------- props

# Crea un modelo con escala `s`, colision en caja (o cilindro) ajustada a su caja envolvente y lo registra
# como obstaculo de pathing / cobertura. Devuelve el StaticBody3D.
func prop(path: String, pos: Vector3, yaw_deg := 0.0, s := 1.0, collide := true, cyl := false, cast := true, as_cover := true, tint := Color.WHITE) -> StaticBody3D:
	if not ResourceLoader.exists(path):
		return null     # asset retirado del proyecto (p. ej. City Kit): el fallback lo omite
	var body := StaticBody3D.new()
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees.y = yaw_deg
	var model := Assets.inst(path)
	Assets.make_lit(model, tint)
	model.scale = Vector3.ONE * s
	body.add_child(model)
	if not cast:
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)
	var bb: AABB = model.transform * Assets.aabb_of(model)   # caja con la escala del modelo aplicada
	if collide:
		var cs := CollisionShape3D.new()
		if cyl:
			var c := CylinderShape3D.new()
			c.radius = minf(bb.size.x, bb.size.z) * 0.5
			c.height = bb.size.y
			cs.shape = c
		else:
			var b := BoxShape3D.new()
			b.size = bb.size
			cs.shape = b
		cs.position = bb.position + bb.size * 0.5
		body.add_child(cs)
		# rectangulo en planta (aprox. por la caja del giro)
		var basis := Basis(Vector3.UP, deg_to_rad(yaw_deg))
		var c0 := Vector2(INF, INF)
		var c1 := Vector2(-INF, -INF)
		for cx in [bb.position.x, bb.end.x]:
			for cz in [bb.position.z, bb.end.z]:
				var w: Vector3 = basis * Vector3(cx, 0, cz)
				c0 = Vector2(minf(c0.x, w.x), minf(c0.y, w.z))
				c1 = Vector2(maxf(c1.x, w.x), maxf(c1.y, w.z))
		var rect := Rect2(Vector2(pos.x, pos.z) + c0, c1 - c0)
		obstacles.append(rect)
		if as_cover and absf(pos.x) < half and absf(pos.z) < half:
			var yawr := deg_to_rad(yaw_deg)
			covers.append({"pos": pos, "rect": rect, "low": bb.size.y <= 1.45, "h": bb.size.y, "yaw": yawr, "half": bb.size * 0.5})
	return body

func _layout() -> void:
	var box := SV + "box.glb"
	var boxl := SV + "box-large.glb"
	var barrel := SV + "barrel.glb"
	var barrel_o := SV + "barrel-open.glb"
	var panel := SV + "metal-panel.glb"
	var panel_s := SV + "metal-panel-screws.glb"
	var fence := SV + "fence-fortified.glb"
	var rock_b := SV + "rock-b.glb"
	var rock_c := SV + "rock-c.glb"
	var rock_a := SV + "rock-a.glb"
	# --- coberturas bajas (se pueden usar agachado)
	prop(boxl, Vector3(-7, 0, 10), 15, 4.6)
	prop(box, Vector3(-4.2, 0, 11.4), 40, 4.4)
	prop(barrel, Vector3(8, 0, 10.5), 0, 3.8, true, true)
	prop(barrel, Vector3(9.2, 0, 11.6), 0, 3.8, true, true)
	prop(barrel, Vector3(9.6, 0, 9.6), 0, 3.8, true, true)
	prop(boxl, Vector3(1.0, 0, 4.5), 90, 4.6)
	prop(box, Vector3(-14, 0, -2), 20, 4.4)
	prop(boxl, Vector3(-15.8, 0, -3.6), 70, 4.6)
	prop(barrel, Vector3(15, 0, 0), 0, 3.8, true, true)
	prop(barrel, Vector3(16.3, 0, 1.0), 0, 3.8, true, true)
	prop(boxl, Vector3(5, 0, -5), 30, 4.6)
	prop(box, Vector3(-4, 0, -9), 10, 4.4)
	prop(box, Vector3(-2.7, 0, -8.7), 60, 4.4)
	prop(barrel, Vector3(11, 0, -12), 0, 3.8, true, true)
	prop(barrel, Vector3(12.4, 0, -11.6), 0, 3.8, true, true)
	prop(boxl, Vector3(-12, 0, -14), 120, 4.6)
	prop(boxl, Vector3(1, 0, -16), 85, 4.6)
	prop(barrel, Vector3(-20, 0, 8), 0, 3.8, true, true)
	prop(barrel, Vector3(-21.2, 0, 7.2), 0, 3.8, true, true)
	prop(boxl, Vector3(21, 0, 9), 100, 4.6)
	prop(box, Vector3(-22, 0, -9), 15, 4.4)
	prop(box, Vector3(22, 0, -10), 35, 4.4)
	prop(box, Vector3(23.4, 0, -9.2), 80, 4.4)
	prop(rock_c, Vector3(-6, 0, 0), 25, 3.2)
	prop(rock_a, Vector3(7, 0, 0.5), 140, 3.6)
	# --- coberturas altas
	prop(fence, Vector3(-16, 0, 13), 5, 4.4)
	prop(fence, Vector3(-14.0, 0, 13.2), 5, 4.4)
	prop(panel, Vector3(15, 0, 17), 25, 4.2)
	prop(panel_s, Vector3(17.2, 0, 16.4), 25, 4.2)
	prop(panel, Vector3(-24, 0, -18), 90, 4.2)
	prop(panel_s, Vector3(-24, 0, -15.8), 90, 4.2)
	prop(fence, Vector3(24, 0, -20), 70, 4.4)
	prop(fence, Vector3(25.0, 0, -17.9), 70, 4.4)
	prop(panel, Vector3(-3, 0, -2), 0, 4.2)
	prop(panel_s, Vector3(-0.8, 0, -2.2), 12, 4.2)
	prop(fence, Vector3(10, 0, -3), 90, 4.4)
	prop(fence, Vector3(10, 0, -5.2), 90, 4.4)
	prop(rock_b, Vector3(-9, 0, -19), 20, 4.4)
	prop(rock_b, Vector3(18, 0, -18), 200, 4.0)
	prop(boxl, Vector3(0, 0, -23), 0, 4.6)
	prop(box, Vector3(-13, 0, 20), 30, 4.4)
	prop(panel, Vector3(-9, 0, 5), 70, 4.2)
	prop(panel_s, Vector3(20, 0, 3), 15, 4.2)

func _perimeter() -> void:
	# cerco bajo con paneles y vallas a lo largo del borde (con huecos)
	var panel := SV + "metal-panel.glb"
	var fence := SV + "fence-fortified.glb"
	var i := 0
	for side in 4:
		var x := -26.0
		while x <= 26.0:
			var kind := rng.randi() % 5
			var edge := 30.2 + rng.randf_range(0.0, 0.5)
			var pos := Vector3(x, 0, -edge)
			var yaw := 0.0
			match side:
				1:
					pos = Vector3(x, 0, edge); yaw = 180.0
				2:
					pos = Vector3(-edge, 0, x); yaw = 90.0
				3:
					pos = Vector3(edge, 0, x); yaw = 270.0
			var step := 4.5
			if kind == 1:
				pass # hueco
				step = 3.5
			else:
				_perim_prop(panel if kind < 4 else fence, pos, yaw + rng.randf_range(-6, 6), 4.6)
				step = 2.45
			x += step
			i += 1

func _perim_prop(path: String, pos: Vector3, yaw: float, s: float) -> void:
	prop(path, pos, yaw, s, true, false, true, false)

func _near_obstacle(p: Vector3, m: float) -> bool:
	for r in obstacles:
		if (r as Rect2).grow(m).has_point(Vector2(p.x, p.z)):
			return true
	return false

func _fires() -> void:
	var spots := [Vector3(-10, 0, -4), Vector3(17, 0, -14), Vector3(-19, 0, 17), Vector3(11, 0, 6)]
	for sp in spots:
		prop(SV + "barrel-open.glb", sp, rng.randf_range(0, 360), 3.9, true, true)
		var f = fx.make_fire(self, sp + Vector3(0, 1.22, 0), 1.25, true)
		if f:
			fires.append(f)
	# fogata en el suelo cerca del inicio
	prop(SV + "campfire-pit.glb", Vector3(-3, 0, 17.5), 0, 5.0, false, false, true, false)
	var f1 = fx.make_fire(self, Vector3(-3, 0.25, 17.5), 1.0, false)
	if f1:
		fires.append(f1)
	prop(SV + "campfire-pit.glb", Vector3(24, 0, 26), 0, 5.0, false, false, true, false)
	var f2 = fx.make_fire(self, Vector3(24, 0.25, 26), 1.0, false)
	if f2:
		fires.append(f2)

# ---------------------------------------------------------------- pathing

func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(p.x + gorg)), 0, gn - 1), clampi(int(floor(p.z + gorg)), 0, gn - 1))

func _cell_h(c: Vector2i) -> float:
	if hgrid.is_empty():
		return 0.0
	return hgrid[c.y * gn + c.x]

func _cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x - gorg + 0.5, _cell_h(c), c.y - gorg + 0.5)

func _make_grid() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, gn, gn)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in gn:
		for y in gn:
			var c := Vector2(x - gorg + 0.5, y - gorg + 0.5)
			var solid := absf(c.x) > half - 0.6 or absf(c.y) > half - 0.6
			if not solid:
				for r in obstacles:
					if (r as Rect2).grow(0.55).has_point(c):
						solid = true
						break
			if solid:
				grid.set_point_solid(Vector2i(x, y), true)

func is_free(p: Vector3) -> bool:
	return not grid.is_point_solid(_cell(p))

func nearest_free(p: Vector3, min_clear := 0.0) -> Vector3:
	var c := _cell(p)
	if not grid.is_point_solid(c) and (min_clear <= 0.0 or clearance.is_empty() or clearance[c.y * gn + c.x] >= min_clear):
		return _cell_pos(c)
	for r in range(1, 12):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= gn or n.y >= gn:
					continue
				if not grid.is_point_solid(n) and (min_clear <= 0.0 or clearance.is_empty() or clearance[n.y * gn + n.x] >= min_clear):
					return _cell_pos(n)
	if min_clear > 0.0:
		return nearest_free(p)
	return p

func line_free(a: Vector3, b: Vector3) -> bool:
	var d := b - a
	d.y = 0.0
	var n := int(d.length() / 0.4) + 1
	for i in n + 1:
		var q := a + d * (float(i) / n)
		if grid.is_point_solid(_cell(q)):
			return false
	return true

func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := _cell(nearest_free(from))
	var b := _cell(nearest_free(to))
	var ids: Array[Vector2i] = grid.get_id_path(a, b)
	var raw := PackedVector3Array()
	for c in ids:
		raw.append(_cell_pos(c))
	var out := PackedVector3Array()
	if raw.size() <= 1:
		out.append(nearest_free(to))
		return out
	var i := 0
	var cur := from
	while i < raw.size() - 1:
		var j := raw.size() - 1
		while j > i + 1 and not line_free(cur, raw[j]):
			j -= 1
		out.append(raw[j])
		cur = raw[j]
		i = j
	return out

# Altura del suelo bajo el punto p (primer impacto hacia abajo desde un poco por encima de p). Sin colision de
# terreno (patio de respaldo) o fuera del arbol devuelve 0.
func ground_y(p: Vector3, up := 1.5) -> float:
	if not meshy or not is_inside_tree():
		return 0.0
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, up, 0), p + Vector3(0, -60.0, 0), L_WORLD)
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return _cell_h(_cell(p))
	return r.position.y

# ---------------------------------------------------------------- cobertura

func _make_cover_points() -> void:
	for c in covers:
		var r: Rect2 = c.rect
		var ctr := r.get_center()
		var sides := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for sd in sides:
			var off: float = (r.size.x if sd.x != 0.0 else r.size.y) * 0.5 + 0.95
			var p := Vector3(ctr.x + sd.x * off, c.pos.y, ctr.y + sd.y * off)
			if absf(p.x) > half - 2.0 or absf(p.z) > half - 2.0 or not is_free(p):
				continue
			var hl: float = (r.size.y if sd.x != 0.0 else r.size.x) * 0.5
			p.y = _cell_h(_cell(p))
			cover_points.append({"pos": p, "dir": Vector3(sd.x, 0, sd.y), "low": c.low, "hl": hl, "taken": null, "h": c.h})

# distancia en planta al borde de la cobertura baja o alta mas cercana
func nearest_cover_dist(p: Vector3) -> float:
	var best := 99.0
	for c in covers:
		var r: Rect2 = c.rect
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))
		best = minf(best, q.distance_to(Vector2(p.x, p.z)))
	return best

func spawn_pos(player_pos: Vector3, min_dist := 20.0, min_clear := 1.6) -> Vector3:
	var cands: Array = []
	for sp in spawn_points:
		if sp.distance_to(player_pos) >= min_dist:
			cands.append(sp)
	if cands.is_empty():
		cands = spawn_points
	var p: Vector3 = cands[rng.randi() % cands.size()]
	p += Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
	return nearest_free(p, min_clear)

# ================================================================ ARENA MESHY

# Visual (mesh escalado), colision trimesh, limites invisibles y horizonte. Todo antes del primer frame de fisica.
func _village_visual() -> void:
	var ps: PackedScene = load(ARENA.path)
	var inst: Node3D = ps.instantiate()
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	if mis.is_empty():
		push_error("la arena Meshy no tiene mallas: " + ARENA.path)
		meshy = false
		inst.free()
		_build_fallback()
		return
	village_mesh = mis[0]
	village_scale = ARENA.scale
	village = Node3D.new()
	village.name = "Village"
	village.scale = Vector3.ONE * village_scale
	village.rotation_degrees.y = ARENA.yaw
	# el mesh se baja para que el suelo tipico (mediana de los vertices de superficies horizontales) quede en y=0
	ground_ref = _estimate_ground() * village_scale
	village.position.y = -ground_ref
	add_child(village)
	# el mesh se cuelga directamente (sin los nodos intermedios del GLB)
	village_mesh.get_parent().remove_child(village_mesh)
	inst.free()
	village.add_child(village_mesh)
	village_mesh.transform = Transform3D.IDENTITY
	village_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_village_material()
	# colision: el propio mesh como trimesh (solo caras frontales: las normales del GLB son consistentes)
	var body := StaticBody3D.new()
	body.name = "VillageBody"
	body.collision_layer = L_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shp := village_mesh.mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shp.backface_collision = false
	cs.shape = shp
	body.add_child(cs)
	village.add_child(body)
	_limits()

func _estimate_ground() -> float:
	var arrays := village_mesh.mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var ys := PackedFloat32Array()
	for i in range(0, vs.size(), 3):
		if ns[i].y > 0.93:
			ys.append(vs[i].y)
	if ys.is_empty():
		return 0.0
	ys.sort()
	return ys[ys.size() / 2]

func _village_material() -> void:
	if Assets.headless:
		return
	var mesh := village_mesh.mesh
	for s in mesh.get_surface_count():
		var m = mesh.surface_get_material(s)
		if m is StandardMaterial3D:
			var d: StandardMaterial3D = m.duplicate()
			d.metallic = 0.0                 # el GLB no trae metal real (canal B ~ 0)
			d.metallic_specular = 0.35
			d.roughness = 1.0                # multiplica el canal G de la textura
			d.cull_mode = BaseMaterial3D.CULL_DISABLED
			village_mesh.set_surface_override_material(s, d)

# Paredes invisibles alrededor del area jugable: solo frenan a personajes (capa L_LIMIT).
func _limits() -> void:
	var h := 80.0
	var e := half + 0.6
	var t := 2.0
	for side in [[Vector3(0, 0, -e - t / 2), Vector3(2 * e + 2 * t, h, t)], [Vector3(0, 0, e + t / 2), Vector3(2 * e + 2 * t, h, t)],
			[Vector3(-e - t / 2, 0, 0), Vector3(t, h, 2 * e + 2 * t)], [Vector3(e + t / 2, 0, 0), Vector3(t, h, 2 * e + 2 * t)]]:
		var b := StaticBody3D.new()
		b.collision_layer = L_LIMIT
		b.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = side[1]
		cs.shape = bs
		b.add_child(cs)
		b.position = side[0] + Vector3(0, h / 2 - 30.0, 0)
		add_child(b)

# ---- horneado de navegacion (requiere un frame de fisica ya transcurrido)

var _space: PhysicsDirectSpaceState3D
var _ray := PhysicsRayQueryParameters3D.new()
var _cap_q := PhysicsShapeQueryParameters3D.new()
var _surf := {}          # indice de celda -> Array de {y, ny, face}
var _ok_cache := {}      # (celda, nivel) -> bool
var _ytop := 0.0
var _ybot := 0.0
var _uvs := PackedVector2Array()
var _idx := PackedInt32Array()
var _albedo: Image
var visited := PackedByteArray()
var clearance := PackedFloat32Array()

func bake() -> void:
	var t0 := Time.get_ticks_msec()
	_space = get_world_3d().direct_space_state
	_ray.collision_mask = L_WORLD
	var cap := CapsuleShape3D.new()
	cap.radius = CAP_R
	cap.height = CAP_H
	_cap_q.shape = cap
	_cap_q.collision_mask = L_WORLD
	gn = 2 * int(ceil(half + 2.0))
	gorg = gn / 2.0
	hgrid = PackedFloat32Array()
	hgrid.resize(gn * gn)
	visited = PackedByteArray()
	visited.resize(gn * gn)
	var ab: AABB = village_mesh.mesh.get_aabb()
	_ytop = ab.end.y * village_scale + 4.0 - ground_ref
	_ybot = ab.position.y * village_scale - 4.0 - ground_ref
	_load_water_data()
	# 1) inundacion desde el punto de inicio sobre superficies caminables
	var hint: Vector2 = ARENA.start_hint
	var s0 := _cell(Vector3(hint.x, 0, hint.y))
	var start_c := _find_start_cell(s0)
	_flood(start_c)
	# 2) grilla A*: solido = no alcanzable o fuera del area jugable
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, gn, gn)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	reach_cells = 0
	for x in gn:
		for y in gn:
			var c := Vector2(x - gorg + 0.5, y - gorg + 0.5)
			var inside := absf(c.x) <= half - 0.6 and absf(c.y) <= half - 0.6
			if visited[y * gn + x] == 1 and inside:
				reach_cells += 1
			else:
				visited[y * gn + x] = 0
				grid.set_point_solid(Vector2i(x, y), true)
	_compute_clearance()
	# 3) inicio del jugador y centro de la aldea
	var la: Vector2 = ARENA.look_at
	var sc := _pick_start(hint, la)
	start_pos = _cell_pos(sc)
	center_pos = _cell_pos(_best_open_cell(la, 2.0, 12.0))
	var d := Vector3(la.x, 0, la.y) - Vector3(start_pos.x, 0, start_pos.z)
	start_yaw = atan2(-d.x, -d.z)
	# 4) cobertura baja sobre espacio abierto (apoyada en el suelo real) + fuegos
	_place_cover_props()
	_place_fires()
	# marcar los props como obstaculos de la grilla
	for x in gn:
		for y in gn:
			if grid.is_point_solid(Vector2i(x, y)):
				continue
			var c := Vector2(x - gorg + 0.5, y - gorg + 0.5)
			for r in obstacles:
				if (r as Rect2).grow(0.55).has_point(c):
					grid.set_point_solid(Vector2i(x, y), true)
					visited[y * gn + x] = 0
					break
	_compute_clearance()
	_make_cover_points()
	_make_wall_cover_points()
	_make_spawns()
	_tune_village_light()
	_build_horizon()
	_uvs = PackedVector2Array()
	_idx = PackedInt32Array()
	_albedo = null
	_surf.clear()
	_ok_cache.clear()
	bake_ms = Time.get_ticks_msec() - t0
	print("Arena Meshy lista: %d celdas alcanzables, %d puntos de aparicion, %d coberturas, horneado %d ms" % [reach_cells, spawn_points.size(), covers.size(), bake_ms])

func _cidx(c: Vector2i) -> int:
	return c.y * gn + c.x

func _cxz(c: Vector2i) -> Vector2:
	return Vector2(c.x - gorg + 0.5, c.y - gorg + 0.5)

# primer impacto hacia abajo desde arriba (techo o suelo), en coordenadas del mundo actuales
func _first_ground(x: float, z: float) -> float:
	_ray.from = Vector3(x, _ytop, z)
	_ray.to = Vector3(x, _ybot, z)
	var best := 0.0
	var y0 := _ytop
	# el suelo es el ultimo impacto con normal hacia arriba
	for k in 6:
		_ray.from = Vector3(x, y0, z)
		var r := _space.intersect_ray(_ray)
		if r.is_empty():
			break
		if r.normal.y >= MIN_NY:
			best = r.position.y
		y0 = r.position.y - 0.08
	return best

func _load_water_data() -> void:
	_uvs = PackedVector2Array()
	_idx = PackedInt32Array()
	_albedo = null
	if not ARENA.water:
		return
	var arrays := village_mesh.mesh.surface_get_arrays(0)
	_uvs = arrays[Mesh.ARRAY_TEX_UV]
	_idx = arrays[Mesh.ARRAY_INDEX]
	var m = village_mesh.mesh.surface_get_material(0)
	if m is StandardMaterial3D and m.albedo_texture != null:
		_albedo = (m.albedo_texture as Texture2D).get_image()
		if _albedo != null and _albedo.is_compressed():
			_albedo.decompress()

# true si la cara `face` (indice de triangulo) es de color agua (celeste intenso)
func _is_water(face: int) -> bool:
	if _albedo == null or face < 0 or face * 3 + 2 >= _idx.size():
		return false
	var uv := (_uvs[_idx[face * 3]] + _uvs[_idx[face * 3 + 1]] + _uvs[_idx[face * 3 + 2]]) / 3.0
	var px := clampi(int(uv.x * _albedo.get_width()), 0, _albedo.get_width() - 1)
	var py := clampi(int(uv.y * _albedo.get_height()), 0, _albedo.get_height() - 1)
	var c := _albedo.get_pixel(px, py)
	return c.b > 0.55 and c.b > c.r + 0.25 and c.g > c.r + 0.18

# superficies caminables (normal hacia arriba) en la columna de la celda, de arriba hacia abajo
func _surfaces(c: Vector2i) -> Array:
	var ci := _cidx(c)
	if _surf.has(ci):
		return _surf[ci]
	var p := _cxz(c)
	var out := []
	var y0 := _ytop
	for k in 5:
		_ray.from = Vector3(p.x, y0, p.y)
		_ray.to = Vector3(p.x, _ybot, p.y)
		var r := _space.intersect_ray(_ray)
		if r.is_empty():
			break
		if r.normal.y >= MIN_NY:
			out.append({"y": r.position.y, "ny": r.normal.y, "face": r.get("face_index", -1)})
		y0 = r.position.y - 0.08
	_surf[ci] = out
	return out

# la superficie k de la celda c es transitable: sin choque con la capsula de prueba y que no sea agua
func _level_ok(c: Vector2i, k: int) -> bool:
	var key := _cidx(c) * 8 + k
	if _ok_cache.has(key):
		return _ok_cache[key]
	var sf: Dictionary = _surfaces(c)[k]
	var p := _cxz(c)
	var ok := true
	if ARENA.water and _is_water(sf.face):
		ok = false
		water_cells += 1
		water_pts.append(p)
	if ok:
		_cap_q.transform = Transform3D(Basis(), Vector3(p.x, sf.y + CAP_LIFT + CAP_H * 0.5, p.y))
		ok = _space.intersect_shape(_cap_q, 1).is_empty()
	_ok_cache[key] = ok
	return ok

func _find_start_cell(c0: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := Vector2i(c0.x + dx, c0.y + dy)
				var sf := _surfaces(c)
				if sf.is_empty():
					continue
				var k := sf.size() - 1
				if _level_ok(c, k):
					hgrid[_cidx(c)] = sf[k].y
					return c
	return c0

func _flood(start: Vector2i) -> void:
	var q: Array[Vector2i] = [start]
	visited[_cidx(start)] = 1
	var lim := int(half + 1.0)
	var qi := 0
	while qi < q.size():
		var c := q[qi]
		qi += 1
		var hy := hgrid[_cidx(c)]
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + dir
			if n.x < 0 or n.y < 0 or n.x >= gn or n.y >= gn or visited[_cidx(n)] == 1:
				continue
			var np := _cxz(n)
			if absf(np.x) > lim or absf(np.y) > lim:
				continue
			var sf := _surfaces(n)
			var bk := -1
			var bd := STEP_MAX
			for k in sf.size():
				var dy := absf(sf[k].y - hy)
				if dy <= bd:
					bd = dy
					bk = k
			if bk < 0 or not _level_ok(n, bk):
				continue
			# nada solido entre los dos centros (paredes finas) a la altura de la rodilla y del pecho
			var cp := _cxz(c)
			var by: float = sf[bk].y
			var blocked := false
			for hh in [0.55, 1.3]:
				_ray.from = Vector3(cp.x, hy + hh, cp.y)
				_ray.to = Vector3(np.x, by + hh, np.y)
				if not _space.intersect_ray(_ray).is_empty():
					blocked = true
					break
			if blocked or not _slope_ok(cp, hy, np, by):
				continue
			visited[_cidx(n)] = 1
			hgrid[_cidx(n)] = by
			q.append(n)

# el trayecto entre dos centros de celda no tiene escalones/pendientes abruptas: se sigue el suelo cada 0.25 m y
# cada tramo debe subir o bajar como mucho 0.3 m (~50 grados); un escalon asi no lo sube un CharacterBody3D
func _slope_ok(a: Vector2, ay: float, b: Vector2, by: float) -> bool:
	var py := ay
	for i in range(1, 4):
		var t := i / 4.0
		var q := a.lerp(b, t)
		_ray.from = Vector3(q.x, py + 0.9, q.y)
		_ray.to = Vector3(q.x, py - 1.2, q.y)
		var r := _space.intersect_ray(_ray)
		if r.is_empty():
			return false
		if absf(r.position.y - py) > 0.31 or r.normal.y < 0.5:
			return false
		py = r.position.y
	return absf(by - py) <= 0.31

# distancia (en celdas, aprox. euclidiana) de cada celda libre a la celda solida mas cercana
func _compute_clearance() -> void:
	clearance = PackedFloat32Array()
	clearance.resize(gn * gn)
	var q: Array[Vector2i] = []
	for x in gn:
		for y in gn:
			if grid.is_point_solid(Vector2i(x, y)):
				clearance[y * gn + x] = 0.0
				q.append(Vector2i(x, y))
			else:
				clearance[y * gn + x] = 999.0
	var qi := 0
	while qi < q.size():
		var c := q[qi]
		qi += 1
		var cd := clearance[_cidx(c)]
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= gn or n.y >= gn:
					continue
				var nd := cd + (1.0 if dx == 0 or dy == 0 else 1.414)
				if nd < clearance[_cidx(n)]:
					clearance[_cidx(n)] = nd
					q.append(n)

# inicio del jugador: celda abierta, plana, a 14-34 m del centro y con la mejor vista despejada hacia el centro
# (media de la longitud de 7 rayos en abanico a 1.6 m de altura); `hint` solo desempata.
func _pick_start(hint: Vector2, center: Vector2) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_s := -1e9
	for x in gn:
		for y in gn:
			var c := Vector2i(x, y)
			if grid.is_point_solid(c) or clearance[_cidx(c)] < 3.5:
				continue
			var p := _cxz(c)
			var dc := p.distance_to(center)
			if dc < 14.0 or dc > 34.0 or not _flat_at(c, 1, 0.3):
				continue
			var dirc := (center - p).normalized()
			var h := hgrid[_cidx(c)] + 1.6
			var sc := 0.0
			for k in 7:
				var d := dirc.rotated((k - 3) * 0.2)
				_ray.from = Vector3(p.x, h, p.y)
				_ray.to = Vector3(p.x + d.x * 40.0, h, p.y + d.y * 40.0)
				var r := _space.intersect_ray(_ray)
				sc += 40.0 if r.is_empty() else p.distance_to(Vector2(r.position.x, r.position.z))
			sc = sc / 7.0 - p.distance_to(hint) * 0.08
			if sc > best_s:
				best_s = sc
				best = c
	if best.x < 0:
		return _best_open_cell(hint, 3.0, 14.0)
	return best

# celda libre con holgura >= min_clear mas cercana a `hint` (si no hay, relaja la holgura)
func _best_open_cell(hint: Vector2, min_clear: float, radius: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_s := 1e9
	for mc in [min_clear, min_clear * 0.6, 1.0]:
		for x in gn:
			for y in gn:
				var c := Vector2i(x, y)
				if grid.is_point_solid(c) or clearance[_cidx(c)] < mc:
					continue
				var d := _cxz(c).distance_to(hint)
				if d < best_s:
					best_s = d
					best = c
		if best.x >= 0:
			break
	return best

# punto libre (alcanzable) con holgura >= clear metros lo mas cerca posible de `hint` (xz); lo usan las pruebas
func open_spot(hint: Vector2, clear := 4.0) -> Vector3:
	if not meshy:
		return nearest_free(Vector3(hint.x, 0, hint.y))
	return _cell_pos(_best_open_cell(hint, clear, 20.0))

func _flat_at(c: Vector2i, rad: int, tol: float) -> bool:
	var h0 := hgrid[_cidx(c)]
	for dx in range(-rad, rad + 1):
		for dy in range(-rad, rad + 1):
			var n := Vector2i(c.x + dx, c.y + dy)
			if n.x < 0 or n.y < 0 or n.x >= gn or n.y >= gn or grid.is_point_solid(n):
				return false
			if absf(hgrid[_cidx(n)] - h0) > tol:
				return false
	return true

func _pos_at(x: float, z: float) -> Vector3:
	var c := _cell(Vector3(x, 0, z))
	if grid.is_point_solid(c):
		return Vector3(x, _first_ground(x, z), z)
	return Vector3(x, hgrid[_cidx(c)], z)

# ---- cobertura baja y fuegos sobre espacio abierto

func _place_cover_props() -> void:
	var box := SV + "box.glb"
	var boxl := SV + "box-large.glb"
	var barrel := SV + "barrel.glb"
	var panel := SV + "metal-panel.glb"
	var panel_s := SV + "metal-panel-screws.glb"
	var fence := SV + "fence-fortified.glb"
	var spots := _pick_spots(int(ARENA.cover_count), 8.5, 2.6)
	var i := 0
	for sp in spots:
		var yaw := rng.randf_range(0.0, 360.0)
		var p: Vector3 = sp
		match i % 5:
			0:
				prop(boxl, p, yaw, 4.6)
				prop(box, _pos_at(p.x + cos(deg_to_rad(yaw)) * 1.9, p.z - sin(deg_to_rad(yaw)) * 1.9), yaw + 35.0, 4.4)
			1:
				for k in 3:
					var a := k * TAU / 3.0 + deg_to_rad(yaw)
					prop(barrel, _pos_at(p.x + cos(a) * 0.75, p.z + sin(a) * 0.75), 0.0, 3.8, true, true)
			2:
				prop(panel, p, yaw, 4.2)
				prop(panel_s, _pos_at(p.x + cos(deg_to_rad(yaw)) * 2.3, p.z - sin(deg_to_rad(yaw)) * 2.3), yaw + 14.0, 4.2)
			3:
				prop(box, p, yaw, 4.4)
				prop(box, _pos_at(p.x + 1.15, p.z + 0.3), yaw + 50.0, 4.4)
				prop(box, _pos_at(p.x + 0.5, p.z - 1.1), yaw + 20.0, 4.4)
			4:
				prop(fence, p, yaw, 4.4)
				prop(fence, _pos_at(p.x + cos(deg_to_rad(yaw)) * 2.3, p.z - sin(deg_to_rad(yaw)) * 2.3), yaw, 4.4)
		i += 1

func _pick_spots(count: int, spacing: float, min_clear: float) -> Array:
	var cells: Array = []
	for x in gn:
		for y in gn:
			var c := Vector2i(x, y)
			if grid.is_point_solid(c) or clearance[_cidx(c)] < min_clear:
				continue
			var p := _cxz(c)
			if absf(p.x) > half - 5.0 or absf(p.y) > half - 5.0:
				continue
			if p.distance_to(Vector2(start_pos.x, start_pos.z)) < 7.0:
				continue
			if not _flat_at(c, 2, 0.45):
				continue
			cells.append(c)
	# orden aleatorio determinista y muestreo con separacion minima
	for k in range(cells.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp = cells[k]
		cells[k] = cells[j]
		cells[j] = tmp
	var out: Array = []
	for c in cells:
		var p := _cxz(c)
		var ok := true
		for q in out:
			if Vector2(q.x, q.z).distance_to(p) < spacing:
				ok = false
				break
		if ok:
			out.append(Vector3(p.x, hgrid[_cidx(c)], p.y))
			if out.size() >= count:
				break
	return out

func _place_fires() -> void:
	# barriles encendidos en espacio abierto + dos fogatas (una cerca del inicio)
	var spots := _pick_spots(4, 18.0, 3.0)
	for sp in spots:
		var p: Vector3 = sp
		prop(SV + "barrel-open.glb", p, rng.randf_range(0, 360), 3.9, true, true)
		var f = fx.make_fire(self, p + Vector3(0, 1.22, 0), 1.25, true)
		if f:
			fires.append(f)
	var fc := _best_open_cell(Vector2(start_pos.x + 3.5, start_pos.z + 1.0), 2.0, 10.0)
	var fp := _cell_pos(fc)
	prop(SV + "campfire-pit.glb", fp, 0.0, 5.0, false, false, true, false)
	var f1 = fx.make_fire(self, fp + Vector3(0, 0.25, 0), 1.0, false)
	if f1:
		fires.append(f1)

# ---- puntos de cobertura en muros de edificios (a partir de la geometria real)

func _make_wall_cover_points() -> void:
	var cand: Array = []
	for x in gn:
		for y in gn:
			var c := Vector2i(x, y)
			if grid.is_point_solid(c):
				continue
			var cl := clearance[_cidx(c)]
			if cl < 1.0 or cl > 2.3:
				continue
			var p := _cxz(c)
			if absf(p.x) > half - 3.0 or absf(p.y) > half - 3.0:
				continue
			cand.append(c)
	for k in range(cand.size() - 1, 0, -1):
		var j := rng.randi() % (k + 1)
		var tmp = cand[k]
		cand[k] = cand[j]
		cand[j] = tmp
	var placed: Array = []
	for c in cand:
		if placed.size() >= 150:
			break
		var base := _cell_pos(c)
		# muro mas cercano en 8 direcciones (alto: choca a 1.0 m y a 2.4 m)
		var best_d := 99.0
		var best_dir := Vector3.ZERO
		for k in 8:
			var a := k * TAU / 8.0
			var dir := Vector3(cos(a), 0, sin(a))
			var d1 := _wall_dist(base, dir, 1.0)
			if d1 < best_d and d1 < 2.6 and _wall_dist(base, dir, 2.4) < 3.2:
				best_d = d1
				best_dir = dir
		if best_dir == Vector3.ZERO:
			continue
		var cdir := -best_dir
		# extension del muro a ambos lados -> el punto va en el centro del tramo
		var tan := Vector3(-best_dir.z, 0, best_dir.x)
		var ext := [0.0, 0.0]
		for si in 2:
			var sg := 1.0 if si == 0 else -1.0
			var s := 0.5
			while s <= 5.0:
				var o := base + tan * sg * s
				if _wall_dist(o, best_dir, 1.0) > 3.0:
					break
				ext[si] = s
				s += 0.5
		var mid: Vector3 = base + tan * (float(ext[0]) - float(ext[1])) * 0.5
		var pos := Vector3(mid.x, 0, mid.z)
		if not is_free(pos):
			continue
		pos.y = _cell_h(_cell(pos))
		var too_close := false
		for q in placed:
			if (q as Vector3).distance_to(pos) < 4.0:
				too_close = true
				break
		if too_close:
			continue
		placed.append(pos)
		cover_points.append({"pos": pos, "dir": cdir, "low": false, "hl": maxf(1.2, (ext[0] + ext[1]) * 0.5), "taken": null, "h": 3.0})

func _wall_dist(from: Vector3, dir: Vector3, up: float) -> float:
	_ray.from = from + Vector3(0, up, 0)
	_ray.to = from + Vector3(0, up, 0) + dir * 3.4
	var r := _space.intersect_ray(_ray)
	if r.is_empty() or absf(r.normal.y) > 0.5:
		return 99.0
	return from.distance_to(Vector3(r.position.x, from.y, r.position.z))

# ---- puntos de aparicion: celdas abiertas alcanzables cerca del borde jugable, repartidas por angulo

func _make_spawns() -> void:
	spawn_points.clear()
	var bins := 20
	var best: Array = []
	best.resize(bins)
	var best_s: Array = []
	best_s.resize(bins)
	for b in bins:
		best[b] = null
		best_s[b] = -1.0
	for x in gn:
		for y in gn:
			var c := Vector2i(x, y)
			if grid.is_point_solid(c) or clearance[_cidx(c)] < 2.0:
				continue
			var p := _cxz(c)
			var ring := maxf(absf(p.x), absf(p.y))
			if ring < half - 9.0 or ring > half - 3.0:
				continue
			var b := int(floor((atan2(p.y, p.x) + PI) / TAU * bins)) % bins
			var s := clearance[_cidx(c)] + rng.randf() * 1.5
			if s > best_s[b]:
				best_s[b] = s
				best[b] = c
	for b in bins:
		if best[b] != null:
			spawn_points.append(_cell_pos(best[b]))

# ---- horizonte: marco de arena alrededor del diorama, dunas y montanas lejanas

var _ring_mat: ShaderMaterial

func _sand_material(col: Color, col2: Color, far_dim := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SAND_SHADER
	m.set_shader_parameter("sand_a", col)
	m.set_shader_parameter("sand_b", col2)
	m.set_shader_parameter("far_dim", far_dim)
	return m

func _build_horizon() -> void:
	if Assets.headless:
		return
	var ext := (village_mesh.mesh.get_aabb().size.x * 0.5) * village_scale   # semilado del diorama
	# altura del borde del diorama (mediana del perimetro)
	var hs: Array = []
	var edge := ext - 0.7
	var n := 28
	for i in n:
		var t := lerpf(-edge, edge, float(i) / (n - 1))
		for pr in [Vector2(t, -edge), Vector2(t, edge), Vector2(-edge, t), Vector2(edge, t)]:
			var h := _first_ground(pr.x, pr.y)
			hs.append(h)
	hs.sort()
	var edge_h: float = hs[hs.size() / 2]
	var base_y := edge_h - 0.35
	# marco de arena con dunas (agujero donde esta el diorama)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cell := 6.0
	var R := 330.0
	var nq := int(R * 2.0 / cell)
	var inner := ext - 0.9
	var hf := func(x: float, z: float) -> float:
		var d := maxf(absf(x), absf(z)) - ext
		var k := clampf(d / 38.0, 0.0, 1.0)
		var n1 := sin(x * 0.045 + 1.3) * cos(z * 0.038 - 0.6) + 0.5 * sin(x * 0.11 + z * 0.09) + 0.35 * sin(z * 0.17 - x * 0.07)
		var bump := (n1 * 0.5 + 0.5) * (2.5 + 15.0 * k * k) * smoothstep(0.0, 14.0, d)
		return base_y + bump - (3.0 if d < 0.0 else 0.0)
	for ix in nq:
		for iz in nq:
			var x0 := -R + ix * cell
			var z0 := -R + iz * cell
			var x1 := x0 + cell
			var z1 := z0 + cell
			# omitir celdas totalmente dentro del diorama
			if x0 > -inner and x1 < inner and z0 > -inner and z1 < inner:
				continue
			var p00 := Vector3(x0, hf.call(x0, z0), z0)
			var p10 := Vector3(x1, hf.call(x1, z0), z0)
			var p01 := Vector3(x0, hf.call(x0, z1), z1)
			var p11 := Vector3(x1, hf.call(x1, z1), z1)
			for tri in [[p00, p01, p10], [p10, p01, p11]]:
				for v in tri:
					st.add_vertex(v)
	st.index()
	st.generate_normals()
	var frame := MeshInstance3D.new()
	frame.mesh = st.commit()
	frame.material_override = _sand_material(Color(0.85, 0.73, 0.58), Color(0.72, 0.58, 0.46))
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	frame.name = "SandFrame"
	add_child(frame)
	# anillo de montanas lejanas (silueta calida con niebla)
	var ms := SurfaceTool.new()
	ms.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 160
	var Rm := 360.0
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var h0 := _mount_h(a0)
		var h1 := _mount_h(a1)
		var b0 := Vector3(cos(a0) * Rm, base_y - 6.0, sin(a0) * Rm)
		var b1 := Vector3(cos(a1) * Rm, base_y - 6.0, sin(a1) * Rm)
		var t0 := Vector3(cos(a0) * Rm, base_y + h0, sin(a0) * Rm)
		var t1 := Vector3(cos(a1) * Rm, base_y + h1, sin(a1) * Rm)
		for tri in [[b0, t0, b1], [b1, t0, t1]]:
			for v in tri:
				ms.add_vertex(v)
	ms.index()
	ms.generate_normals()
	var mount := MeshInstance3D.new()
	mount.mesh = ms.commit()
	mount.material_override = _sand_material(Color(0.6, 0.45, 0.43), Color(0.48, 0.36, 0.38), 1.0)
	mount.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mount.name = "Mountains"
	add_child(mount)

func _mount_h(a: float) -> float:
	var v := 0.5 + 0.5 * sin(a * 5.0 + 0.7) * 0.6 + 0.3 * sin(a * 13.0 + 2.0) + 0.15 * sin(a * 31.0)
	return 16.0 + 42.0 * clampf(v, 0.0, 1.4)

# ---- depuracion: imagen de la grilla (una celda = 6 px)

func debug_nav_image() -> Image:
	var px := 6
	var img := Image.create(gn * px, gn * px, false, Image.FORMAT_RGB8)
	for x in gn:
		for y in gn:
			var c := Vector2i(x, y)
			var col := Color(0.55, 0.12, 0.1)
			if not grid.is_point_solid(c):
				var hh := clampf(_cell_h(c) * 0.12 + 0.5, 0.0, 1.0)
				col = Color(0.1, 0.35 + 0.5 * hh, 0.2)
			img.fill_rect(Rect2i(x * px, y * px, px, px), col)
	for wp in water_pts:
		var wc := _cell(Vector3(wp.x, 0, wp.y))
		img.fill_rect(Rect2i(wc.x * px, wc.y * px, px, px), Color(0.2, 0.5, 1.0))
	for cp in cover_points:
		var c := _cell(cp.pos)
		img.fill_rect(Rect2i(c.x * px + 1, c.y * px + 1, px - 2, px - 2), Color(0.95, 0.85, 0.2) if not cp.low else Color(0.2, 0.7, 1.0))
	for sp in spawn_points:
		var c := _cell(sp)
		img.fill_rect(Rect2i(c.x * px - 3, c.y * px - 3, px + 6, px + 6), Color(1, 0.2, 1))
	var sc := _cell(start_pos)
	img.fill_rect(Rect2i(sc.x * px - 4, sc.y * px - 4, px + 8, px + 8), Color(1, 1, 1))
	return img
