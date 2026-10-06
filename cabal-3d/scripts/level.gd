extends Node3D
# Patio industrial en ruinas al atardecer (60x60 m): suelo procedural, cobertura con colisiones,
# edificios del City Kit alrededor, fuego, cielo, niebla, luces y una grilla A* para el movimiento de los enemigos.

const Assets = preload("res://scripts/assets.gd")
const GROUND_SHADER := preload("res://shaders/ground.gdshader")
const SV := "res://assets/third_party/kenney/survival/"
const CI := "res://assets/third_party/kenney/city/"

const HALF := 30.0         # el patio va de -30 a 30
const GRID_N := 64         # celdas de 1 m, de -32 a 32
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4

var fx
var sun: DirectionalLight3D
var env: Environment
var world_env: WorldEnvironment
var covers: Array = []        # {pos, half(Vector3), low, rect, yaw}
var cover_points: Array = []  # {pos, dir, low, hl, taken}
var obstacles: Array = []     # Rect2 (xz) bloqueados para pathing
var grid: AStarGrid2D
var spawn_points: Array = []
var fires: Array = []
var rng := RandomNumberGenerator.new()

func build(fx_node) -> void:
	fx = fx_node
	rng.seed = 20260
	_environment()
	_ground()
	_walls()
	_layout()
	_perimeter()
	_skyline()
	_decor()
	_fires()
	_make_grid()
	_make_cover_points()
	for x in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		spawn_points.append(Vector3(x, 0.0, -27.0))
	for z in [-14.0, 0.0, 14.0]:
		spawn_points.append(Vector3(-27.0, 0.0, z))
		spawn_points.append(Vector3(27.0, 0.0, z))
	for x in [-20.0, 20.0]:
		spawn_points.append(Vector3(x, 0.0, 27.0))

# ---------------------------------------------------------------- entorno

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
	env.fog_light_color = Color(0.93, 0.56, 0.4)
	env.fog_density = 0.0058
	env.fog_sky_affect = 0.45
	env.fog_sun_scatter = 0.25
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	# sol calido, bajo, con sombras
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-23.0, 232.0, 0.0)
	sun.light_color = Color(1.0, 0.7, 0.45)
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 75.0
	sun.directional_shadow_split_1 = 0.28
	sun.shadow_bias = 0.05
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.4
	add_child(sun)
	# relleno frio sin sombras (separa a los personajes del fondo calido)
	var fill := DirectionalLight3D.new()
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
		if as_cover and absf(pos.x) < HALF and absf(pos.z) < HALF:
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
	var cont := [CI + "shipping-container-a.glb", CI + "shipping-container-b.glb", CI + "shipping-container-c.glb"]
	var tank := CI + "detail-tank-large.glb"
	var tank_s := CI + "detail-tank.glb"
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
	prop(cont[0], Vector3(-16, 0, 13), 5, 1.55)
	prop(cont[1], Vector3(15, 0, 17), 25, 1.55)
	prop(cont[2], Vector3(-24, 0, -18), 90, 1.55)
	prop(cont[1], Vector3(24, 0, -20), 70, 1.55)
	prop(panel, Vector3(-3, 0, -2), 0, 4.2)
	prop(panel_s, Vector3(-0.8, 0, -2.2), 12, 4.2)
	prop(fence, Vector3(10, 0, -3), 90, 4.4)
	prop(fence, Vector3(10, 0, -5.2), 90, 4.4)
	prop(rock_b, Vector3(-9, 0, -19), 20, 4.4)
	prop(rock_b, Vector3(18, 0, -18), 200, 4.0)
	prop(tank, Vector3(0, 0, -23), 0, 2.6)
	prop(tank_s, Vector3(-13, 0, 20), 30, 2.6)
	prop(panel, Vector3(-9, 0, 5), 70, 4.2)
	prop(panel_s, Vector3(20, 0, 3), 15, 4.2)

func _perimeter() -> void:
	# cerco bajo con contenedores, paneles y vallas a lo largo del borde (con huecos)
	var cont := [CI + "shipping-container-a.glb", CI + "shipping-container-b.glb", CI + "shipping-container-c.glb"]
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
			if kind == 0 and absf(x) < 22.0:
				_perim_prop(cont[rng.randi() % 3], pos, yaw, 1.55)
				step = 7.4
			elif kind == 1:
				pass # hueco
				step = 3.5
			else:
				_perim_prop(panel if kind < 4 else fence, pos, yaw + rng.randf_range(-6, 6), 4.6)
				step = 2.45
			x += step
			i += 1

func _perim_prop(path: String, pos: Vector3, yaw: float, s: float) -> void:
	prop(path, pos, yaw, s, true, false, true, false)

func _skyline() -> void:
	var bld := []
	for c in "abcdefghijklmnopqrst":
		bld.append(CI + "building-%s.glb" % c)
	var tall := [CI + "building-a.glb", CI + "building-b.glb", CI + "building-c.glb", CI + "building-e.glb", CI + "building-m.glb", CI + "building-d.glb"]
	# primera fila: edificios medianos mirando al patio
	for side in 4:
		var t := -50.0
		while t <= 50.0:
			var d := 40.0 + rng.randf_range(-1.5, 2.5)
			var scale_f := rng.randf_range(7.0, 9.5)
			var path: String = bld[rng.randi() % bld.size()]
			var pos := Vector3(t, 0, -d)
			var yaw := 0.0
			match side:
				1:
					pos = Vector3(t, 0, d); yaw = 180.0
				2:
					pos = Vector3(-d, 0, t); yaw = 90.0
				3:
					pos = Vector3(d, 0, t); yaw = 270.0
			prop(path, pos, yaw, scale_f, false, false, false, false)
			t += rng.randf_range(11.0, 17.0)
	# segunda fila alta (silueta)
	for side in 4:
		var t := -55.0
		while t <= 55.0:
			var d := 62.0 + rng.randf_range(-2.0, 6.0)
			var path: String = tall[rng.randi() % tall.size()]
			var pos := Vector3(t, 0, -d)
			match side:
				1:
					pos = Vector3(t, 0, d)
				2:
					pos = Vector3(-d, 0, t)
				3:
					pos = Vector3(d, 0, t)
			prop(path, pos, rng.randf_range(0, 360), rng.randf_range(11.0, 15.0), false, false, false, false)
			t += rng.randf_range(18.0, 26.0)
	# hitos: chimeneas, torre de agua, molino
	prop(CI + "chimney-large.glb", Vector3(-44, 0, -30), 0, 11.0, false, false, false, false)
	prop(CI + "chimney-large.glb", Vector3(48, 0, -36), 0, 13.0, false, false, false, false)
	prop(CI + "chimney-basic.glb", Vector3(36, 0, 46), 0, 28.0, false, false, false, false)
	prop(CI + "water-tower.glb", Vector3(-30, 0, -52), 0, 12.0, false, false, false, false)
	prop(CI + "windmill.glb", Vector3(52, 0, 20), 30, 12.0, false, false, false, false)
	prop(CI + "chimney-medium.glb", Vector3(-52, 0, 34), 0, 14.0, false, false, false, false)

func _decor() -> void:
	# escombros chicos sin colision: tablones, madera, baldes, rocas bajas, carteles, cajas rotas
	var items := [SV + "resource-planks.glb", SV + "resource-wood.glb", SV + "bucket.glb", SV + "rock-a.glb", SV + "rock-c.glb", SV + "signpost.glb", SV + "box-open.glb", SV + "resource-stone.glb"]
	var scl := [4.2, 4.2, 3.4, 1.5, 1.4, 3.8, 3.6, 3.0]
	for i in 46:
		var k := rng.randi() % items.size()
		var p := Vector3(rng.randf_range(-28, 28), 0, rng.randf_range(-28, 28))
		if _near_obstacle(p, 1.2) or Vector2(p.x, p.z).distance_to(Vector2(0, 17)) < 4.0:
			continue
		prop(items[k], p, rng.randf_range(0, 360), scl[k], false, false, true, false)

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
	return Vector2i(clampi(int(floor(p.x + 32.0)), 0, GRID_N - 1), clampi(int(floor(p.z + 32.0)), 0, GRID_N - 1))

func _cell_pos(c: Vector2i) -> Vector3:
	return Vector3(c.x - 32.0 + 0.5, 0.0, c.y - 32.0 + 0.5)

func _make_grid() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, GRID_N, GRID_N)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for x in GRID_N:
		for y in GRID_N:
			var c := Vector2(x - 32.0 + 0.5, y - 32.0 + 0.5)
			var solid := absf(c.x) > HALF - 0.6 or absf(c.y) > HALF - 0.6
			if not solid:
				for r in obstacles:
					if (r as Rect2).grow(0.55).has_point(c):
						solid = true
						break
			if solid:
				grid.set_point_solid(Vector2i(x, y), true)

func is_free(p: Vector3) -> bool:
	return not grid.is_point_solid(_cell(p))

func nearest_free(p: Vector3) -> Vector3:
	var c := _cell(p)
	if not grid.is_point_solid(c):
		return _cell_pos(c)
	for r in range(1, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= GRID_N or n.y >= GRID_N:
					continue
				if not grid.is_point_solid(n):
					return _cell_pos(n)
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

# ---------------------------------------------------------------- cobertura

func _make_cover_points() -> void:
	for c in covers:
		var r: Rect2 = c.rect
		var ctr := r.get_center()
		var sides := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for sd in sides:
			var off: float = (r.size.x if sd.x != 0.0 else r.size.y) * 0.5 + 0.95
			var p := Vector3(ctr.x + sd.x * off, 0.0, ctr.y + sd.y * off)
			if absf(p.x) > HALF - 2.0 or absf(p.z) > HALF - 2.0 or not is_free(p):
				continue
			var hl: float = (r.size.y if sd.x != 0.0 else r.size.x) * 0.5
			cover_points.append({"pos": p, "dir": Vector3(sd.x, 0, sd.y), "low": c.low, "hl": hl, "taken": null, "h": c.h})

# distancia en planta al borde de la cobertura baja o alta mas cercana
func nearest_cover_dist(p: Vector3) -> float:
	var best := 99.0
	for c in covers:
		var r: Rect2 = c.rect
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.z, r.position.y, r.end.y))
		best = minf(best, q.distance_to(Vector2(p.x, p.z)))
	return best

func spawn_pos(player_pos: Vector3, min_dist := 20.0) -> Vector3:
	var cands: Array = []
	for sp in spawn_points:
		if sp.distance_to(player_pos) >= min_dist:
			cands.append(sp)
	if cands.is_empty():
		cands = spawn_points
	var p: Vector3 = cands[rng.randi() % cands.size()]
	p += Vector3(rng.randf_range(-2.5, 2.5), 0, rng.randf_range(-2.5, 2.5))
	return nearest_free(p)
