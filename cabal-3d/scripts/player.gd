extends CharacterBody3D
# Jugador: movimiento relativo a la camara, camara de tercera persona sobre el hombro (SpringArm3D con colision),
# disparo hitscan desde la boca hacia el punto de mira, recarga, granadas, agacharse y rodar con invulnerabilidad.

const Model = preload("res://scripts/model.gd")

const WEAPONS := {
	"rifle": {"name": "RIFLE", "rate": 0.105, "dmg": 22.0, "pellets": 1, "spread": 0.7, "kick": 0.55, "sound": "shot", "gun": "blaster-a", "len": 2.0, "tracer": Color(1.0, 0.86, 0.5)},
	"spread": {"name": "ESCOPETA", "rate": 0.78, "dmg": 12.0, "pellets": 9, "spread": 4.6, "kick": 2.4, "sound": "spread", "gun": "blaster-d", "len": 2.1, "tracer": Color(1.0, 0.7, 0.35)},
	"burst": {"name": "RAFAGA", "rate": 0.058, "dmg": 15.0, "pellets": 1, "spread": 1.3, "kick": 0.4, "sound": "shot", "gun": "blaster-e", "len": 2.2, "tracer": Color(0.5, 0.9, 1.0)},
}

var game
var level
var fx

var model
var rot_pivot: Node3D
var cam_pivot: Node3D
var pitch_node: Node3D
var spring: SpringArm3D
var camera: Camera3D
var capsule: CapsuleShape3D
var col: CollisionShape3D
var mlight: OmniLight3D

# estado
var max_hp := 100.0
var hp := 100.0
var gren := 3
var max_gren := 6
const MAG := 30
var ammo := 30
var reserve := 120
const MAX_RESERVE := 240
var weapon := "rifle"
var wtime := 0.0
var reloading := false
var reload_t := 0.0
const RELOAD_TIME := 1.6
var fire_cd := 0.0
var bloom := 0.0
var dead := false
var yaw := 0.0
var pitch := -0.13
var recoil := 0.0
var shake := 0.0
var crouched := false
var in_cover := false
var aiming := false
var aim_k := 0.0
var roll_t := 0.0
var roll_cd := 0.0
const ROLL_TIME := 0.5
const ROLL_CD := 0.95
var inv_t := 0.0
var roll_dir := Vector3.ZERO
var face_yaw := 0.0
var combat_t := 0.0       # tiempo desde la ultima accion de combate (mantiene apuntando al frente)
var hurt_t := 0.0
var step_t := 0.0
var sens := 0.0026
var flash_light_t := 0.0
var cam_h := 1.75
var vel_h := Vector3.ZERO
var aim_hit := {}
var aim_over_enemy := false
var last_shot_hit := false

# intenciones (las llena game.gd desde el teclado/mouse o el bot de pruebas)
var in_move := Vector2.ZERO
var in_sprint := false
var in_fire := false
var in_aim := false
var in_crouch_hold := false
var p_jump := false
var p_reload := false
var p_gren := false
var p_crouch := false

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8        # mundo + limites invisibles del area jugable
	floor_snap_length = 0.55      # el terreno de la arena es irregular
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	capsule = CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	col = CollisionShape3D.new()
	col.shape = capsule
	col.position.y = 0.9
	add_child(col)
	rot_pivot = Node3D.new()
	rot_pivot.position.y = 0.9
	add_child(rot_pivot)
	model = Model.new()
	model.position.y = -0.9
	rot_pivot.add_child(model)
	model.setup("m", Color(1, 1, 1), 0.12, 0.5)
	model.give_weapon("blaster-a", 1.55)
	# camara
	cam_pivot = Node3D.new()
	cam_pivot.position.y = cam_h
	add_child(cam_pivot)
	pitch_node = Node3D.new()
	cam_pivot.add_child(pitch_node)
	spring = SpringArm3D.new()
	spring.spring_length = 3.4
	spring.collision_mask = 1
	spring.margin = 0.2
	var ss := SphereShape3D.new()
	ss.radius = 0.25
	spring.shape = ss
	pitch_node.add_child(spring)
	spring.add_excluded_object(get_rid())
	camera = Camera3D.new()
	camera.fov = 70.0
	camera.near = 0.08
	camera.far = 400.0
	camera.h_offset = 1.0
	camera.v_offset = 0.2
	spring.add_child(camera)
	mlight = OmniLight3D.new()
	mlight.light_color = Color(1.0, 0.8, 0.5)
	mlight.omni_range = 7.0
	mlight.light_energy = 0.0
	mlight.shadow_enabled = false
	add_child(mlight)

func reset() -> void:
	hp = max_hp
	gren = 3
	ammo = MAG
	reserve = 120
	set_weapon("rifle")
	wtime = 0.0
	reloading = false
	dead = false
	crouched = false
	roll_t = 0.0
	roll_cd = 0.0
	inv_t = 0.0
	fire_cd = 0.0
	bloom = 0.0
	recoil = 0.0
	shake = 0.0
	velocity = Vector3.ZERO
	position = level.start_pos + Vector3(0, 0.08, 0)
	yaw = level.start_yaw
	pitch = -0.13
	face_yaw = yaw + PI
	model.rotation.y = face_yaw
	rot_pivot.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	model.play("idle_h", 0.0)
	capsule.height = 1.8
	col.position.y = 0.9
	cam_h = 1.75

func set_weapon(w: String) -> void:
	weapon = w
	var d: Dictionary = WEAPONS[w]
	model.give_weapon(d.gun, d.len)
	reloading = false

func look(rel: Vector2) -> void:
	var k := 0.62 if aiming else 1.0
	yaw -= rel.x * sens * k
	pitch = clampf(pitch - rel.y * sens * k, -0.85, 0.62)

func muzzle_pos() -> Vector3:
	if model.muzzle:
		return model.muzzle.global_position
	return global_position + Vector3(0, 1.4, 0)

func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func chest_pos() -> Vector3:
	return global_position + Vector3(0, 0.62 if (crouched or roll_t > 0.0) else 1.25, 0)

func current_spread() -> float:
	var d: Dictionary = WEAPONS[weapon]
	var s: float = d.spread + bloom
	if aiming:
		s *= 0.55
	if crouched:
		s *= 0.75
	var spd := Vector2(velocity.x, velocity.z).length()
	s *= 1.0 + clampf(spd / 7.0, 0.0, 1.0) * 0.9
	if not is_on_floor():
		s *= 2.0
	return s

# punto al que apunta la mira (centro de la pantalla)
func aim_ray() -> Dictionary:
	var fwd := -camera.global_transform.basis.z
	var d := camera.global_position.distance_to(cam_pivot.global_position)
	var from := camera.global_position + fwd * maxf(d, 0.4)
	var to := from + fwd * 140.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return {"pos": to, "hit": false, "collider": null}
	return {"pos": r.position, "hit": true, "collider": r.collider, "normal": r.normal}

func start_reload() -> void:
	if reloading or weapon != "rifle" or ammo >= MAG or reserve <= 0 or dead:
		return
	reloading = true
	reload_t = RELOAD_TIME
	game.sfx.play("roll", -6.0)

func take_damage(dmg: float, from: Vector3) -> void:
	if dead or inv_t > 0.0 or game.god:
		return
	if in_cover:
		dmg *= 0.7
	hp -= dmg
	hurt_t = 0.3
	shake = maxf(shake, 0.5)
	model.hit_flash()
	game.sfx.play("hurt", -2.0)
	game.on_player_hit(from)
	if hp <= 0.0:
		hp = 0.0
		die()

func die() -> void:
	dead = true
	reloading = false
	in_fire = false
	model.play_once("die", 0.05)
	game.player_died()

func heal(a: float) -> void:
	hp = minf(max_hp, hp + a)

func add_ammo(a: int) -> void:
	reserve = mini(MAX_RESERVE, reserve + a)

func _physics_process(delta: float) -> void:
	if game == null:
		return
	if game.state == "menu":
		model.play("idle_h")
		return
	var st: String = game.state
	if st == "pause":
		return
	# --- temporizadores
	fire_cd = maxf(0.0, fire_cd - delta)
	roll_cd = maxf(0.0, roll_cd - delta)
	inv_t = maxf(0.0, inv_t - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	combat_t = maxf(0.0, combat_t - delta)
	bloom = maxf(0.0, bloom - delta * 3.5)
	recoil = lerpf(recoil, 0.0, 1.0 - exp(-delta * 9.0))
	shake = maxf(0.0, shake - delta * 2.2)
	if wtime > 0.0:
		wtime -= delta
		if wtime <= 0.0:
			wtime = 0.0
			set_weapon("rifle")
			game.toast("Arma temporal agotada")
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			reloading = false
			var take := mini(MAG - ammo, reserve)
			ammo += take
			reserve -= take
	# --- ayuda de tiempo para el apuntado
	aiming = in_aim and not dead and roll_t <= 0.0
	aim_k = lerpf(aim_k, 1.0 if aiming else 0.0, 1.0 - exp(-delta * 12.0))
	var fwd := forward_flat()
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		velocity.y -= 24.0 * delta
		move_and_slide()
		_update_camera(delta)
		return
	# --- agacharse
	if p_crouch:
		crouched = not crouched
	p_crouch = false
	var want_crouch := crouched or in_crouch_hold
	if roll_t > 0.0:
		want_crouch = true
	capsule.height = lerpf(capsule.height, 1.1 if want_crouch else 1.8, 1.0 - exp(-delta * 16.0))
	col.position.y = capsule.height * 0.5
	cam_h = lerpf(cam_h, 1.2 if want_crouch else 1.75, 1.0 - exp(-delta * 10.0))
	in_cover = want_crouch and roll_t <= 0.0 and level.nearest_cover_dist(global_position) < 1.5
	# --- movimiento
	var mv := fwd * in_move.y + right * in_move.x
	if mv.length() > 1.0:
		mv = mv.normalized()
	var firing := in_fire and not reloading
	var spd := 4.4
	if want_crouch:
		spd = 2.3
	elif aiming:
		spd = 2.7
	elif in_sprint and in_move.y > 0.1 and not firing:
		spd = 7.6
	if p_jump:
		p_jump = false
		if is_on_floor():
			if roll_cd <= 0.0 and mv.length() > 0.2:
				roll_t = ROLL_TIME
				roll_cd = ROLL_CD
				inv_t = ROLL_TIME * 0.9
				roll_dir = mv.normalized()
				game.sfx.play("roll", -2.0)
				reloading = false
			else:
				velocity.y = 8.0
	if roll_t > 0.0:
		roll_t -= delta
		var k := 1.0 - roll_t / ROLL_TIME
		vel_h = roll_dir * lerpf(11.5, 6.0, k)
	else:
		vel_h = vel_h.lerp(mv * spd, 1.0 - exp(-delta * (14.0 if mv.length() > 0.05 else 18.0)))
	velocity.x = vel_h.x
	velocity.z = vel_h.z
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0
	move_and_slide()
	var lim: float = level.half - 0.5
	if absf(position.x) > lim:
		position.x = signf(position.x) * lim
	if absf(position.z) > lim:
		position.z = signf(position.z) * lim
	var hspd := Vector2(velocity.x, velocity.z).length()
	# --- acciones
	if p_reload:
		start_reload()
	p_reload = false
	if p_gren:
		_throw()
	p_gren = false
	if in_fire and roll_t <= 0.0:
		_try_fire()
	if weapon == "rifle" and ammo <= 0 and not reloading and reserve > 0:
		start_reload()
	# --- apuntado (rayo desde el centro de la camara)
	aim_hit = aim_ray()
	if not aim_hit.is_empty() and not dead:
		model.aim_weapon(aim_hit.pos)
	var c = aim_hit.collider
	aim_over_enemy = c != null and c.is_in_group("enemy")
	# --- orientacion del modelo
	if aiming or firing or in_fire:
		combat_t = 1.2
	var target_yaw := face_yaw
	if combat_t > 0.0:
		target_yaw = atan2(fwd.x, fwd.z)
	elif hspd > 0.5:
		target_yaw = atan2(velocity.x, velocity.z)
	else:
		var cy := atan2(fwd.x, fwd.z)
		if absf(angle_difference(face_yaw, cy)) > 1.6:
			target_yaw = cy
	if roll_t > 0.0:
		target_yaw = atan2(roll_dir.x, roll_dir.z)
	var turn := 22.0 if (combat_t > 0.0) else 10.0
	face_yaw = lerp_angle(face_yaw, target_yaw, 1.0 - exp(-delta * turn))
	model.rotation.y = face_yaw
	# voltereta al rodar
	if roll_t > 0.0:
		var k := 1.0 - roll_t / ROLL_TIME
		rot_pivot.rotation.x = k * TAU
		model.scale = Vector3.ONE * 0.9
	else:
		rot_pivot.rotation.x = 0.0
		var sy := lerpf(model.scale.y, 0.74 if want_crouch else 1.0, 1.0 - exp(-delta * 14.0))
		model.scale = Vector3(1.0, sy, 1.0)
	model.position.y = -0.9
	# --- animacion
	if roll_t > 0.0:
		model.play("sprint_h", 0.05, 1.6)
	elif hspd > 5.0:
		model.play("sprint_h", 0.12, hspd / 6.5)
	elif hspd > 0.4:
		model.play("walk_h", 0.12, clampf(hspd / 3.2, 0.6, 1.4))
	else:
		model.play("idle_h", 0.15, 1.0)
	_update_camera(delta)
	# luz del fogonazo
	flash_light_t = maxf(0.0, flash_light_t - delta)
	mlight.light_energy = 3.0 * (flash_light_t / 0.05) if flash_light_t > 0.0 else 0.0

func _update_camera(delta: float) -> void:
	cam_pivot.position.y = cam_h
	cam_pivot.rotation.y = yaw
	var jx := 0.0
	var jy := 0.0
	var jz := 0.0
	if shake > 0.0:
		var a := shake * shake * 0.03
		jx = randf_range(-a, a)
		jy = randf_range(-a, a)
		jz = randf_range(-a, a) * 0.6
	pitch_node.rotation = Vector3(pitch + recoil + jx, jy, jz)
	spring.spring_length = lerpf(4.1, 3.0, aim_k)
	camera.h_offset = lerpf(1.25, 1.4, aim_k)
	camera.v_offset = lerpf(0.2, 0.15, aim_k)
	camera.fov = lerpf(70.0, 56.0, aim_k)

func _try_fire() -> void:
	if reloading or fire_cd > 0.0 or dead:
		return
	var d: Dictionary = WEAPONS[weapon]
	if weapon == "rifle":
		if ammo <= 0:
			return
		ammo -= 1
	fire_cd = d.rate
	_shoot(d)

func _shoot(d: Dictionary) -> void:
	combat_t = 1.4
	var origin := muzzle_pos()
	var target: Vector3 = aim_hit.pos if not aim_hit.is_empty() else origin + forward_flat() * 50.0
	var base_dir := (target - origin)
	if base_dir.length() < 1.5:
		base_dir = -camera.global_transform.basis.z
	base_dir = base_dir.normalized()
	var any_hit := false
	var spread: float = current_spread()
	var space := get_world_3d().direct_space_state
	for i in int(d.pellets):
		var dir := _spread(base_dir, spread)
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 130.0, 1 | 4)
		q.exclude = [get_rid()]
		var r := space.intersect_ray(q)
		var end := origin + dir * 90.0
		if not r.is_empty():
			end = r.position
			var cld = r.collider
			if cld != null and cld.is_in_group("enemy"):
				var head: bool = cld.is_head(r.position)
				var dmg: float = d.dmg * (2.0 if head else 1.0)
				cld.take_hit(dmg, r.position, head, dir)
				any_hit = true
			else:
				fx.sparks(r.position, r.normal)
				if r.normal.y > 0.6:
					fx.dust(r.position, r.normal, 0.8)
				elif i % 3 == 0:
					fx.dust(r.position, r.normal, 0.6)
		if i < 3 or weapon != "spread":
			fx.tracer(origin, end, d.tracer, 0.03, 0.06)
	game.shots += 1
	if any_hit:
		game.hits += 1
	# retroceso, fogonazo y sonido
	bloom = minf(bloom + (0.28 if weapon == "rifle" else 0.1), 3.0)
	recoil += deg_to_rad(d.kick) * (0.6 if aiming else 1.0)
	recoil = minf(recoil, 0.16)
	pitch = minf(pitch + deg_to_rad(d.kick) * 0.12, 0.62)
	yaw += randf_range(-0.0016, 0.0016) * d.kick
	shake = maxf(shake, 0.12 + d.kick * 0.06)
	model.kick()
	fx.muzzle(origin + (target - origin).normalized() * 0.2, 1.5 if weapon == "spread" else 1.05)
	flash_light_t = 0.05
	mlight.global_position = origin
	game.sfx.play(d.sound, -4.0 if weapon == "rifle" else -2.0, 0.05)

func _spread(dir: Vector3, deg: float) -> Vector3:
	if deg <= 0.01:
		return dir
	var a := deg_to_rad(deg) * sqrt(randf())
	var ph := randf() * TAU
	var u := dir.cross(Vector3.UP)
	if u.length() < 0.01:
		u = Vector3.RIGHT
	u = u.normalized()
	var v := dir.cross(u).normalized()
	return (dir + (u * cos(ph) + v * sin(ph)) * tan(a)).normalized()

func _throw() -> void:
	if gren <= 0 or roll_t > 0.0 or dead:
		return
	gren -= 1
	combat_t = 1.0
	var start := global_position + Vector3(0, 1.55, 0) + forward_flat() * 0.7 + Vector3(cos(yaw), 0, -sin(yaw)) * 0.35
	var target: Vector3 = aim_hit.pos if not aim_hit.is_empty() else start + forward_flat() * 14.0
	var flat := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	if flat.length() > 24.0:
		target = global_position + flat.normalized() * 24.0
		target.y = 0.0
	if flat.length() < 3.0:
		target = global_position + forward_flat() * 3.5
		target.y = 0.0
	game.throw_grenade(start, target, true)
	game.sfx.play("nade", -4.0)
