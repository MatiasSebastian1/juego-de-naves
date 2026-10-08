extends CharacterBody3D
# Enemigos: fusilero (cobertura + asoma y dispara con telegrafo), corredor (sprint + melee), pesado (rafagas),
# granadero (granadas con indicador en el suelo) y jefe (abanico de disparos, granadas, se enfurece al 50%).
# Movimiento por grilla A* (level.gd) + evitacion entre enemigos; disparos hitscan que bloquea la cobertura.

const Model = preload("res://scripts/model.gd")
const FONT_PATH := "res://assets/third_party/kenney/fonts/Kenney Future.ttf"
const Assets = preload("res://scripts/assets.gd")

# Todos los enemigos son el mismo zombi de Meshy (assets/meshy/zombie.glb); se distinguen por tinte, escala y anillo de pies.
# Los que atacan a distancia (fusilero, pesado, granadero, jefe) lanzan proyectiles toxicos (escupitajo / bolsas de acido)
# con el gesto de la animacion "attack"; el corredor ataca cuerpo a cuerpo con esa misma animacion.
const TOXIC := Color(0.5, 1.0, 0.18)
const ATTACK_FROM := 0.35        # instante de la animacion "attack" donde empieza a levantar los brazos
const ATTACK_HIT := 1.40         # instante del golpe / lanzamiento
const ATTACK_END := 1.70         # hasta aqui el gesto bloquea la locomocion
const TYPES := {
	"rifleman": {"tint": Color(1.55, 0.8, 0.72), "hp": 70.0, "speed": 3.7, "scale": 1.0, "dmg": 8.0, "tele": 0.62, "spread": 3.6, "burst": [2, 4], "score": 100,
		"col": Color(1.0, 0.25, 0.2), "name": "FUSILERO"},
	"runner": {"tint": Color(1.6, 1.45, 0.62), "hp": 48.0, "speed": 7.4, "scale": 0.95, "dmg": 16.0, "tele": 0.38, "spread": 0.0, "burst": [1, 1], "score": 120,
		"col": Color(1.0, 0.85, 0.1), "name": "CORREDOR"},
	"heavy": {"tint": Color(1.6, 1.0, 0.55), "hp": 330.0, "speed": 2.5, "scale": 1.25, "dmg": 9.0, "tele": 0.9, "spread": 4.4, "burst": [6, 9], "score": 400,
		"col": Color(1.0, 0.5, 0.1), "name": "PESADO"},
	"grenadier": {"tint": Color(0.78, 1.5, 0.8), "hp": 85.0, "speed": 3.3, "scale": 1.05, "dmg": 0.0, "tele": 0.7, "spread": 0.0, "burst": [1, 1], "score": 200,
		"col": Color(0.3, 1.0, 0.4), "name": "GRANADERO"},
	"boss": {"tint": Color(1.5, 0.75, 1.5), "hp": 2700.0, "speed": 2.9, "scale": 2.1, "dmg": 10.0, "tele": 1.0, "spread": 1.2, "burst": [10, 14], "score": 3000,
		"col": Color(1.0, 0.25, 0.9), "name": "JEFE"},
}

var game
var level
var fx
var player

var type := "rifleman"
var cfg: Dictionary
var hp := 100.0
var max_hp := 100.0
var scale_f := 1.0
var speed := 3.0
var dying := false
var die_t := 0.0
var model
var capsule: CapsuleShape3D
var col: CollisionShape3D
var foot_ring: MeshInstance3D
var warn: Label3D = null
var bar_bg: MeshInstance3D
var bar_fg: MeshInstance3D
var wave_n := 1
var diff := 0.0

var state := "move"
var st_t := 0.0
var path := PackedVector3Array()
var path_i := 0
var repath_t := 0.0
var goal := Vector3.ZERO
var cover = null
var peek_pos := Vector3.ZERO
var peeking := false
var burst_left := 0
var shot_cd := 0.0
var strafe_dir := 1.0
var cycles := 0
var want_vel := Vector3.ZERO
var face_dir := Vector3.ZERO     # direccion a la que debe mirar (cero = hacia donde camina)
var los := false
var ever_los := false       # estadisticas para las pruebas: alguna vez tuvo linea de vision al jugador
var stuck_events := 0       # cuantas veces se detecto atoranque
var stuck_streak := 0       # atoranques seguidos sin avanzar (si pasan de 4, se reubica)
var rescues := 0
var los_t := 0.0
var no_los_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var crouch_k := 1.0
var nade_cd := 3.0
var tele_t := 0.0
var pattern := ""
var pattern_n := 0
var enraged := false
var hit_react := 0.0
var strike_done := false
var spawn_t := 0.5
var fade := 1.0
var aim_ring: MeshInstance3D = null
var last_target := Vector3.ZERO

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1 | 8        # mundo + limites invisibles
	floor_snap_length = 0.55
	floor_max_angle = deg_to_rad(50.0)

func init_type(t: String, wave: int, pos: Vector3) -> void:
	type = t
	cfg = TYPES[t]
	wave_n = wave
	diff = clampf((wave - 1) / 14.0, 0.0, 1.0)
	scale_f = cfg.scale
	max_hp = cfg.hp * (1.0 + 0.07 * (wave - 1)) * (1.0 + (0.25 * (wave / 5.0) if t == "boss" else 0.0))
	hp = max_hp
	speed = cfg.speed * (1.0 + 0.2 * diff)
	global_position = pos + Vector3(0, 0.08, 0)
	last_pos = global_position
	var h := 1.84 * scale_f
	capsule = CapsuleShape3D.new()
	capsule.radius = (0.42 * scale_f) if t != "boss" else 0.66
	capsule.height = h
	col = CollisionShape3D.new()
	col.shape = capsule
	col.position.y = h * 0.5
	add_child(col)
	model = Model.new()
	add_child(model)
	model.setup("zombie", cfg.tint, 0.5, 0.4)
	model.scale = Vector3.ONE * scale_f
	model.base_emit = cfg.col * 0.08
	model.glow_col = cfg.col
	model.speed_var = randf_range(0.88, 1.14)       # cada zombi camina a su propio ritmo y desfasado
	model.play("idle", 0.0)
	model.randomize_phase()
	if not Assets.headless:
		# anillo de color bajo los pies (identifica al tipo de un vistazo)
		foot_ring = MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1, 1) * 2.1 * scale_f
		foot_ring.mesh = qm
		foot_ring.rotation_degrees.x = -90.0
		foot_ring.position.y = 0.05
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_texture = load("res://assets/third_party/kenney/particles/circle_05.png")
		mat.albedo_color = Color(cfg.col.r, cfg.col.g, cfg.col.b, 0.55)
		mat.disable_fog = true
		foot_ring.material_override = mat
		foot_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(foot_ring)
		# aviso "!" sobre la cabeza durante el telegrafo
		warn = Label3D.new()
		warn.text = "!"
		warn.font_size = 120
		warn.pixel_size = 0.006
		warn.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		warn.no_depth_test = true
		warn.modulate = Color(1.0, 0.25, 0.15)
		warn.outline_modulate = Color(0, 0, 0, 1)
		warn.outline_size = 14
		warn.position = Vector3(0, h + 0.85, 0)
		warn.visible = false
		if ResourceLoader.exists(FONT_PATH):
			warn.font = load(FONT_PATH)
		add_child(warn)
		if t != "boss":
			_make_bar(h)
	if t != "runner" and t != "grenadier":
		_pick_cover()
	if t == "grenadier":
		nade_cd = randf_range(1.5, 3.0)
	state = "move"

func _make_bar(h: float) -> void:
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 0.1)
	bar_bg = MeshInstance3D.new()
	bar_bg.mesh = qm
	var m1 := StandardMaterial3D.new()
	m1.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m1.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m1.billboard_keep_scale = true
	m1.albedo_color = Color(0, 0, 0, 0.6)
	m1.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m1.no_depth_test = true
	m1.render_priority = 1
	bar_bg.material_override = m1
	bar_bg.position = Vector3(0, h + 0.45, 0)
	bar_bg.scale = Vector3(scale_f, 1, 1)
	bar_bg.visible = false
	bar_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar_bg)
	bar_fg = MeshInstance3D.new()
	bar_fg.mesh = qm
	var m2 := m1.duplicate()
	m2.albedo_color = Color(cfg.col.r, cfg.col.g, cfg.col.b, 1.0).lightened(0.2)
	m2.render_priority = 2
	bar_fg.material_override = m2
	bar_fg.position = Vector3(0, h + 0.45, 0)
	bar_fg.visible = false
	bar_fg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar_fg)

# ---------------------------------------------------------------- utilidades

func flat_to(p: Vector3) -> Vector3:
	var d := p - global_position
	d.y = 0.0
	return d

func eye_pos() -> Vector3:
	return global_position + Vector3(0, 1.45 * scale_f * crouch_k, 0)

func is_head(p: Vector3) -> bool:
	return p.y > global_position.y + 1.84 * scale_f * crouch_k * 0.72

func _pick_cover() -> void:
	if cover != null:
		cover.taken = null
		cover = null
	var best = null
	var best_s := 1e9
	var ppos: Vector3 = player.global_position
	for c in level.cover_points:
		if c.taken != null and c.taken != self:
			continue
		var dp: float = c.pos.distance_to(ppos)
		if dp < 8.0 or dp > 26.0:
			continue
		# el punto debe quedar tapado respecto del jugador (el lado opuesto de la cobertura)
		var to_p: Vector3 = (ppos - c.pos).normalized()
		if to_p.dot(c.dir) > 0.15:
			continue
		var s: float = global_position.distance_to(c.pos) + randf() * 8.0 + absf(dp - 15.0) * 0.6
		if s < best_s:
			best_s = s
			best = c
	if best != null:
		best.taken = self
	cover = best

func _goto(target: Vector3, interval := 0.6) -> void:
	if repath_t <= 0.0 or goal.distance_to(target) > 3.0 or path.is_empty():
		goal = target
		path = level.find_path(global_position, target)
		path_i = 0
		repath_t = interval

func _follow(spd: float) -> bool:
	while path_i < path.size():
		var d := flat_to(path[path_i])
		if d.length() < 0.55:
			path_i += 1
		else:
			want_vel = d.normalized() * spd
			return false
	want_vel = Vector3.ZERO
	return true

func _can_see() -> bool:
	var from := eye_pos()
	var to: Vector3 = player.chest_pos()
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return not r.is_empty() and r.collider == player

func _set_state(s: String, t := 0.0) -> void:
	state = s
	st_t = t
	peeking = false

func _telegraph(on: bool) -> void:
	model.glow = 1.0 if on else 0.0
	if on:
		# el gesto de "attack" (brazos arriba y golpe hacia adelante) llega a su punto de impacto cuando termina el telegrafo
		var lead: float = cfg.tele + (0.14 if type == "runner" else 0.0)
		model.gesture("attack", ATTACK_FROM, (ATTACK_HIT - ATTACK_FROM) / lead, ATTACK_END)
	if warn == null:
		return
	warn.visible = on
	if on:
		warn.modulate = Color(1.0, 0.25, 0.15) if type != "grenadier" else Color(0.4, 1.0, 0.4)

# ---------------------------------------------------------------- bucle

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if dying:
		_die_tick(delta)
		return
	if game.state != "play":
		velocity = Vector3(0, velocity.y - 24.0 * delta, 0)
		move_and_slide()
		model.play("idle")
		return
	spawn_t = maxf(0.0, spawn_t - delta)
	var dp2 := global_position.distance_squared_to(player.global_position)
	model.lod = 1 if dp2 < 26.0 * 26.0 else (2 if dp2 < 48.0 * 48.0 else 3)    # animacion mas espaciada a lo lejos
	repath_t -= delta
	st_t -= delta
	shot_cd -= delta
	los_t -= delta
	hit_react = maxf(0.0, hit_react - delta)
	if los_t <= 0.0:
		los_t = 0.12 + randf() * 0.05
		los = _can_see()
		if los:
			ever_los = true
		no_los_t = 0.0 if los else no_los_t + 0.14
	want_vel = Vector3.ZERO
	face_dir = Vector3.ZERO
	match type:
		"runner":
			_ai_runner(delta)
		"grenadier":
			_ai_grenadier(delta)
		"boss":
			_ai_boss(delta)
		_:
			_ai_shooter(delta)
	_apply_motion(delta)
	# barra de vida (solo si esta danado)
	if bar_bg:
		var show := hp < max_hp and not dying
		bar_bg.visible = show
		bar_fg.visible = show
		if show:
			var k := clampf(hp / max_hp, 0.0, 1.0)
			bar_fg.scale = Vector3(maxf(k * scale_f, 0.001), 0.7, 1.0)
			bar_fg.position.x = 0.0
			bar_fg.position.y = bar_bg.position.y
			# la barra se recorta hacia la izquierda: se compensa con una escala centrada (billboard) simple
	# atoranque
	stuck_t += delta
	if stuck_t > 0.8:
		stuck_t = 0.0
		if want_vel.length() > 0.5 and last_pos.distance_to(global_position) < 0.15:
			stuck_events += 1
			stuck_streak += 1
			if stuck_streak >= 4:
				_rescue()
			repath_t = 0.0
			path = PackedVector3Array()
			var side := Vector3(-want_vel.z, 0, want_vel.x).normalized() * randf_range(-3.0, 3.0)
			goal = global_position + side
			path = level.find_path(global_position, level.nearest_free(goal))
			path_i = 0
		if last_pos.distance_to(global_position) > 1.0:
			stuck_streak = 0
		last_pos = global_position

# Red de seguridad: un enemigo que sigue atascado tras varios intentos reaparece en un punto libre (nunca bloquea la oleada)
func _rescue() -> void:
	stuck_streak = 0
	rescues += 1
	var p: Vector3 = level.spawn_pos(player.global_position, 16.0, 2.0 if type != "boss" else 2.4)
	global_position = p + Vector3(0, 0.08, 0)
	velocity = Vector3.ZERO
	path = PackedVector3Array()
	path_i = 0
	last_pos = global_position
	_set_state("move")

func _apply_motion(delta: float) -> void:
	# separacion entre enemigos
	var sep := Vector3.ZERO
	for e in game.enemies:
		if e == self or e.dying:
			continue
		var d: Vector3 = global_position - e.global_position
		d.y = 0.0
		var r: float = (0.8 + 0.35 * (scale_f + e.scale_f))
		var l := d.length()
		if l < r and l > 0.001:
			sep += d / l * (r - l) * 3.0
	var wv := want_vel + sep
	if wv.length() > speed * 1.4:
		wv = wv.normalized() * speed * 1.4
	var acc := 10.0
	velocity.x = lerpf(velocity.x, wv.x, 1.0 - exp(-delta * acc))
	velocity.z = lerpf(velocity.z, wv.z, 1.0 - exp(-delta * acc))
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = -1.0
	move_and_slide()
	# orientacion
	var look := face_dir
	var hs := Vector2(velocity.x, velocity.z).length()
	if look.length() < 0.01 and hs > 0.3:
		look = Vector3(velocity.x, 0, velocity.z)
	if look.length() > 0.01:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(look.x, look.z), 1.0 - exp(-delta * (12.0 if face_dir.length() > 0.01 else 9.0)))
	# agachado (en cobertura baja)
	crouch_k = lerpf(crouch_k, 0.64 if (state == "hide" and cover != null and cover.low) else 1.0, 1.0 - exp(-delta * 14.0))
	model.scale = Vector3.ONE * scale_f
	model.crouch = clampf((1.0 - crouch_k) / 0.36, 0.0, 1.0)
	capsule.height = 1.84 * scale_f * crouch_k
	col.position.y = capsule.height * 0.5
	# animacion (caminar para los lentos, correr para el corredor; velocidad proporcional a la velocidad real)
	model.locomote(hs, 2.6 if type == "runner" else 99.0)

# ---------------------------------------------------------------- fusilero / pesado

func _ai_shooter(delta: float) -> void:
	var to_p := flat_to(player.global_position)
	var dist := to_p.length()
	var heavy := type == "heavy"
	match state:
		"move":
			var arrived := false
			if cover != null and not heavy:
				_goto(cover.pos)
				arrived = _follow(speed)
				if arrived or global_position.distance_to(cover.pos) < 1.0:
					cycles = 0
					_set_state("hide", randf_range(0.8, 1.8) * (1.0 - 0.3 * diff))
			else:
				# sin cobertura (o pesado): acercarse hasta la distancia de combate
				var rng_d := 12.0 + (4.0 if heavy else 8.0) * (1.0 - diff)
				if dist > rng_d + 2.0 or not los:
					var tgt: Vector3 = player.global_position - to_p.normalized() * rng_d
					_goto(level.nearest_free(tgt), 0.8)
					_follow(speed)
					if heavy and los and dist < rng_d + 6.0 and st_t < 0.0:
						_set_state("aim", cfg.tele)
						_telegraph(true)
				else:
					_set_state("aim", cfg.tele)
					_telegraph(true)
		"hide":
			want_vel = Vector3.ZERO
			if cover != null:
				face_dir = player.global_position - global_position
			if st_t <= 0.0:
				if cover != null and not cover.low:
					# cobertura alta: asoma por un costado con linea de vision
					var side: Vector3 = Vector3(-cover.dir.z, 0, cover.dir.x)
					var best := Vector3.ZERO
					var found := false
					for sgn in [1.0, -1.0]:
						var pp: Vector3 = cover.pos + side * sgn * (cover.hl + 0.9)
						if level.is_free(pp):
							var qp := PhysicsRayQueryParameters3D.create(pp + Vector3(0, 1.4, 0), player.chest_pos(), 1 | 2)
							var rr := get_world_3d().direct_space_state.intersect_ray(qp)
							if not rr.is_empty() and rr.collider == player:
								best = pp
								found = true
								if randf() < 0.5:
									break
					if found:
						peek_pos = best
						peeking = true
						_set_state("peek", 2.0)
						peeking = true
					else:
						_relocate()
				else:
					_set_state("aim", cfg.tele)
					_telegraph(true)
					if not los:
						# agachado no hay linea; se para para apuntar
						pass
		"peek":
			_goto(peek_pos, 0.3)
			var arr := _follow(speed * 1.2)
			if arr or global_position.distance_to(peek_pos) < 0.5 or st_t <= 0.0:
				_set_state("aim", cfg.tele)
				_telegraph(true)
		"aim":
			want_vel = Vector3.ZERO
			face_dir = to_p
			if heavy and speed > 0.0:
				# el pesado avanza lento mientras apunta
				var tgt2: Vector3 = player.global_position
				if dist > 9.0:
					_goto(level.nearest_free(tgt2), 0.8)
					_follow(speed * 0.45)
			if st_t <= 0.0:
				_telegraph(false)
				if los or no_los_t < 0.5:
					var b: Array = cfg.burst
					burst_left = randi_range(b[0], b[1]) + int(diff * 2.0)
					_set_state("fire", 0.0)
				else:
					_relocate()
			elif no_los_t > 1.2 and not heavy:
				_telegraph(false)
				_relocate()
		"fire":
			face_dir = to_p
			if heavy:
				if dist > 10.0:
					_goto(level.nearest_free(player.global_position), 0.8)
					_follow(speed * 0.4)
			if shot_cd <= 0.0 and burst_left > 0:
				_fire_shot(cfg.dmg, cfg.spread * (1.0 - 0.45 * diff), TOXIC)
				burst_left -= 1
				shot_cd = (0.09 if heavy else 0.14) * (1.0 - 0.25 * diff) + randf() * 0.03
			if burst_left <= 0 and shot_cd <= -0.15:
				cycles += 1
				if cover != null and not heavy:
					if cycles >= 3 or randf() < 0.25:
						_relocate()
					else:
						_set_state("return")
				else:
					_set_state("strafe", randf_range(0.8, 1.7))
					strafe_dir = 1.0 if randf() < 0.5 else -1.0
		"return":
			_goto(cover.pos if cover != null else global_position, 0.4)
			if _follow(speed * 1.2) or global_position.distance_to(cover.pos) < 0.9:
				_set_state("hide", randf_range(0.9, 2.0) * (1.0 - 0.35 * diff))
		"strafe":
			face_dir = to_p
			var perp := Vector3(-to_p.z, 0, to_p.x).normalized() * strafe_dir
			var tgt3 := global_position + perp * 3.0
			if level.is_free(tgt3) and level.is_free(global_position + perp * 1.2):
				want_vel = perp * speed * 0.7
			else:
				strafe_dir = -strafe_dir
			if st_t <= 0.0:
				if cover != null and not heavy:
					_set_state("move")
				else:
					_set_state("aim", cfg.tele)
					_telegraph(true)

func _relocate() -> void:
	_telegraph(false)
	model.cancel_gesture()
	_pick_cover()
	_set_state("move")
	path = PackedVector3Array()

# ---------------------------------------------------------------- disparo

func _fire_shot(dmg: float, spread_deg: float, col_t: Color) -> void:
	var origin: Vector3 = model.muzzle.global_position if model.muzzle else eye_pos()
	var tgt: Vector3 = player.chest_pos() + Vector3(randf_range(-0.15, 0.15), randf_range(-0.1, 0.45), randf_range(-0.15, 0.15))
	var dir := (tgt - origin).normalized()
	_shoot_dir(origin, dir, dmg, spread_deg, col_t)
	model.kick()
	fx.muzzle(origin + dir * 0.2, 0.55 * minf(scale_f, 1.5), TOXIC)
	model.gesture("attack", ATTACK_HIT - 0.12, 3.0, ATTACK_END)
	game.sfx.play3d("enemy", origin, -5.0, 0.08, 14.0)

func _shoot_dir(origin: Vector3, dir: Vector3, dmg: float, spread_deg: float, col_t: Color) -> void:
	# la precision empeora si el jugador se mueve rapido
	var ps: float = player.vel_h.length()
	var sp := spread_deg * (1.0 + clampf(ps / 8.0, 0.0, 1.0) * 0.5)
	var d: Vector3 = player._spread(dir, sp)
	var q := PhysicsRayQueryParameters3D.create(origin, origin + d * 90.0, 1 | 2)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	var end := origin + d * 60.0
	if not r.is_empty():
		end = r.position
		if r.collider == player:
			player.take_damage(dmg, global_position)
		else:
			fx.splat(r.position, r.normal, 0.8)
	fx.spit(origin, end, TOXIC, minf(scale_f, 1.6))

# ---------------------------------------------------------------- corredor

func _ai_runner(delta: float) -> void:
	var to_p := flat_to(player.global_position)
	var dist := to_p.length()
	match state:
		"move":
			if dist < 2.1:
				_set_state("windup", cfg.tele)
				_telegraph(true)
				strike_done = false
			else:
				_goto(player.global_position, 0.35)
				_follow(speed)
				if dist < 6.0 and level.line_free(global_position, player.global_position):
					want_vel = to_p.normalized() * speed
		"windup":
			want_vel = Vector3.ZERO
			face_dir = to_p
			if st_t <= 0.0:
				_telegraph(false)
				_set_state("strike", 0.42)
				strike_done = false
		"strike":
			face_dir = to_p
			want_vel = to_p.normalized() * speed * 0.35
			if not strike_done and st_t < 0.28:
				strike_done = true
				if dist < 2.9:
					player.take_damage(cfg.dmg, global_position)
					game.sfx.play3d("hit", global_position, -3.0)
			if st_t <= 0.0:
				_set_state("recover", 0.5)
		"recover":
			want_vel = -to_p.normalized() * speed * 0.3
			if st_t <= 0.0:
				_set_state("move")

# ---------------------------------------------------------------- granadero

func _ai_grenadier(delta: float) -> void:
	var to_p := flat_to(player.global_position)
	var dist := to_p.length()
	nade_cd -= delta
	match state:
		"move":
			if dist > 20.0:
				_goto(level.nearest_free(player.global_position - to_p.normalized() * 16.0), 0.8)
				_follow(speed)
			elif dist < 10.0:
				var away: Vector3 = global_position - to_p.normalized() * 6.0
				_goto(level.nearest_free(away), 0.8)
				_follow(speed * 1.1)
			else:
				var perp := Vector3(-to_p.z, 0, to_p.x).normalized() * strafe_dir
				if level.is_free(global_position + perp * 1.5):
					want_vel = perp * speed * 0.5
				else:
					strafe_dir = -strafe_dir
				face_dir = to_p
			if nade_cd <= 0.0 and dist < 28.0:
				_set_state("aim", cfg.tele)
				_telegraph(true)
				var lead: Vector3 = player.velocity * 0.9
				last_target = level.nearest_free(player.global_position + Vector3(lead.x, 0, lead.z) + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
				if aim_ring:
					aim_ring.queue_free()
				aim_ring = fx.make_ring(last_target, 4.2, Color(0.4, 1.0, 0.4))
		"aim":
			want_vel = Vector3.ZERO
			face_dir = last_target - global_position
			if aim_ring:
				var k := 1.0 - clampf(st_t / cfg.tele, 0.0, 1.0)
				(aim_ring.material_override as ShaderMaterial).set_shader_parameter("pulse", k)
			if st_t <= 0.0:
				_telegraph(false)
				game.throw_grenade(global_position + Vector3(0, 1.8 * scale_f, 0) + face_dir.normalized() * 0.6, last_target, false, aim_ring)
				aim_ring = null
				game.sfx.play3d("nade", global_position, -2.0)
				model.kick()
				nade_cd = randf_range(3.6, 5.4) * (1.0 - 0.3 * diff)
				_set_state("recover", 0.7)
		"recover":
			want_vel = Vector3.ZERO
			face_dir = to_p
			if st_t <= 0.0:
				_set_state("move")

# ---------------------------------------------------------------- jefe

func _ai_boss(delta: float) -> void:
	var to_p := flat_to(player.global_position)
	var dist := to_p.length()
	if not enraged and hp < max_hp * 0.5:
		enraged = true
		speed *= 1.35
		model.base_emit = cfg.col * 0.35
		game.banner("JEFE ENFURECIDO", 2.2)
		game.sfx.play("wave", -2.0)
	var pause := 1.3 * (0.5 if enraged else 1.0)
	match state:
		"move":
			if dist > 17.0 or not los:
				_goto(level.nearest_free(player.global_position - to_p.normalized() * 13.0), 0.7)
				_follow(speed)
			elif dist < 9.0:
				_goto(level.nearest_free(global_position - to_p.normalized() * 6.0), 0.7)
				_follow(speed)
			else:
				face_dir = to_p
			if st_t <= -pause and (los or dist < 26.0):
				var opts := ["fan", "fan", "nades", "burst"]
				pattern = opts[randi() % opts.size()]
				pattern_n = 0
				_set_state("tele", cfg.tele * (0.7 if enraged else 1.0))
				_telegraph(true)
				last_target = player.global_position
				if pattern == "fan":
					pass
		"tele":
			want_vel = Vector3.ZERO
			face_dir = to_p
			if st_t <= 0.0:
				_telegraph(false)
				match pattern:
					"fan":
						burst_left = 3 if not enraged else 4
					"nades":
						burst_left = 3 if not enraged else 5
					"burst":
						burst_left = randi_range(cfg.burst[0], cfg.burst[1]) + (6 if enraged else 0)
				_set_state("act", 0.0)
				shot_cd = 0.0
		"act":
			want_vel = Vector3.ZERO
			face_dir = to_p
			if shot_cd <= 0.0 and burst_left > 0:
				var origin: Vector3 = model.muzzle.global_position if model.muzzle else eye_pos()
				match pattern:
					"fan":
						var n_rays := 9 if not enraged else 13
						var base: Vector3 = (player.chest_pos() - origin)
						base.y *= 0.4
						base = base.normalized()
						for i in n_rays:
							var a := deg_to_rad(lerpf(-32.0, 32.0, float(i) / (n_rays - 1)))
							var dd := base.rotated(Vector3.UP, a)
							_shoot_dir(origin, dd, cfg.dmg, 1.2, TOXIC)
						fx.muzzle(origin + base * 0.3, 1.6)
						game.sfx.play3d("spread", origin, 0.0, 0.05, 20.0)
						shot_cd = 0.38 * (0.75 if enraged else 1.0)
					"nades":
						var off := Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)) if pattern_n > 0 else Vector3.ZERO
						var tg: Vector3 = level.nearest_free(player.global_position + off)
						var ring: MeshInstance3D = fx.make_ring(tg, 4.2, TOXIC)
						game.throw_grenade(origin + Vector3(0, 0.6, 0), tg, false, ring)
						game.sfx.play3d("nade", origin, 0.0, 0.05, 18.0)
						shot_cd = 0.5
					"burst":
						_fire_shot(cfg.dmg * 0.7, 2.6, TOXIC)
						shot_cd = 0.075
				pattern_n += 1
				burst_left -= 1
				model.gesture("attack", ATTACK_HIT - 0.12, 2.2, ATTACK_END)
			if burst_left <= 0 and shot_cd <= -0.1:
				_set_state("move")
				st_t = 0.0

# ---------------------------------------------------------------- dano y muerte

func take_hit(dmg: float, pos: Vector3, head: bool, dir: Vector3) -> void:
	if dying:
		return
	hp -= dmg
	model.hit_flash()
	hit_react = 0.15
	fx.splat(pos, -dir, 0.6)
	var killed := hp <= 0.0
	game.on_enemy_hit(self, head, killed, pos)
	game.sfx.play3d("head" if head else "hit", pos, -2.0, 0.06)
	if killed:
		die(head)
	else:
		# los shooters en cobertura alta se quedan ocultos un instante mas si los hieren
		if state == "hide":
			st_t += 0.3

func die(head := false) -> void:
	if dying:
		return
	dying = true
	die_t = 0.0
	_telegraph(false)
	if aim_ring:
		aim_ring.queue_free()
		aim_ring = null
	if cover != null:
		cover.taken = null
	collision_layer = 0
	collision_mask = 1 | 8
	model.cancel_gesture()
	model.die(randf_range(-1.0, 1.0))
	model.base_emit = Color.BLACK
	model.scale = Vector3.ONE * scale_f
	if foot_ring:
		foot_ring.visible = false
	if bar_bg:
		bar_bg.visible = false
		bar_fg.visible = false
	fx.poof(global_position, type == "boss" or type == "heavy", true)
	game.on_enemy_died(self, head)

func _die_tick(delta: float) -> void:
	die_t += delta
	velocity.x = lerpf(velocity.x, 0.0, 1.0 - exp(-delta * 8.0))
	velocity.z = lerpf(velocity.z, 0.0, 1.0 - exp(-delta * 8.0))
	velocity.y -= 24.0 * delta
	move_and_slide()
	var hold := 1.1 if type != "boss" else 1.8
	if die_t > hold:
		var a := clampf(1.0 - (die_t - hold) / 0.8, 0.0, 1.0)
		model.set_alpha(a)
		if a <= 0.0:
			game.enemies.erase(self)
			queue_free()
