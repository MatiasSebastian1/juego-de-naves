extends Area3D
## Nave del jugador. Movimiento, disparo, danio, power-ups y respawn.
## Los valores de combate (danio, cadencia, cantidad de balas) se recalculan
## SIEMPRE desde ShipDatabase + weapon_level actual; nunca se incrementan
## sobre el valor anterior (evita arrastrar estados inconsistentes al cargar).

signal died(player_index: int)
signal hp_changed(current: int, max_hp: int)
signal shield_changed(charges: int)

const PlayerBulletScene := preload("res://scenes/bullets/PlayerBullet.tscn")
const RESPAWN_INVULN_TIME := 2.0
const HIT_INVULN_TIME := 1.0
const SPEED_BOOST_MULT := 1.3
const SHIELD_MAX := 3
const BOMB_DAMAGE := 999.0

@export var player_index: int = 0
@export var ship_id: String = "interceptor"

var max_hp: int = 3
var current_hp: int = 3
var invuln_timer: float = 0.0
var fire_timer: float = 0.0
var speed_boost_timer: float = 0.0
var passive_shield_regen_timer: float = 0.0
var alive: bool = true

func _ready() -> void:
	var stats := ShipDatabase.get_stats(ship_id)
	max_hp = int(stats.get("max_hp", 3))
	current_hp = max_hp

	collision_layer = Constants.LAYER_PLAYER if player_index == 0 else Constants.LAYER_PLAYER2
	collision_mask = Constants.LAYER_ENEMY | Constants.LAYER_ENEMY_BULLET | Constants.LAYER_BOSS | Constants.LAYER_POWERUP
	monitoring = true
	monitorable = true
	add_to_group(Constants.GROUP_PLAYER)
	area_entered.connect(_on_area_entered)

	_build_visual(stats)
	_build_collision()

	global_position = Vector3(0.0, 0.0, Constants.PLAYER_MAX_Z - 1.0)
	invuln_timer = RESPAWN_INVULN_TIME

func _build_visual(stats: Dictionary) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.6, 0.35, 0.9)
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(0, 180, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = stats.get("color", Color.WHITE)
	mat.emission_enabled = true
	mat.emission = stats.get("color", Color.WHITE)
	mat.emission_energy_multiplier = 0.6
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 0.7
	shape.shape = capsule
	shape.rotation_degrees = Vector3(90, 0, 0)
	add_child(shape)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	_handle_movement(delta)
	_handle_shooting(delta)
	if invuln_timer > 0.0:
		invuln_timer -= delta
	if speed_boost_timer > 0.0:
		speed_boost_timer -= delta
	_handle_passive_shield(delta)
	if InputManager.is_bomb_just_pressed(player_index):
		_try_use_bomb()

func _handle_movement(delta: float) -> void:
	var stats := ShipDatabase.get_stats(ship_id)
	var speed: float = float(stats.get("speed", 6.0))
	if speed_boost_timer > 0.0:
		speed *= SPEED_BOOST_MULT

	if InputManager.has_direct_position_control(player_index):
		var target_screen := InputManager.get_touch_target_position(player_index)
		if target_screen != Vector2.ZERO:
			var target_world := _screen_to_world(target_screen)
			global_position = global_position.move_toward(target_world, speed * delta)
	else:
		var move := InputManager.get_move_vector(player_index)
		global_position += Vector3(move.x, 0.0, move.y) * speed * delta

	global_position.x = clampf(global_position.x, -Constants.PLAYFIELD_HALF_WIDTH, Constants.PLAYFIELD_HALF_WIDTH)
	global_position.z = clampf(global_position.z, Constants.PLAYER_MIN_Z, Constants.PLAYER_MAX_Z)

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	if not InputManager.is_fire_held(player_index):
		return
	if fire_timer > 0.0:
		return
	var weapon_level: int = GameManager.weapon_level[player_index] if player_index < GameManager.weapon_level.size() else 1
	fire_timer = ShipDatabase.compute_cooldown(ship_id, weapon_level)
	_fire(weapon_level)

func _fire(weapon_level: int) -> void:
	var damage := ShipDatabase.compute_damage(ship_id, weapon_level)
	var aim_dir := _get_aim_direction()
	var offsets := _get_bullet_offsets(weapon_level)
	for offset in offsets:
		var bullet := PlayerBulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position + Vector3(offset.x, 0.15, offset.y)
		bullet.direction = aim_dir
		bullet.damage = damage
	AudioManager.play_sfx("shoot" if weapon_level < 3 else "shoot_heavy")

func _get_bullet_offsets(weapon_level: int) -> Array[Vector2]:
	match weapon_level:
		1:
			return [Vector2(0, -0.3)]
		2:
			return [Vector2(-0.22, -0.2), Vector2(0.22, -0.2)]
		_:
			return [Vector2(-0.28, -0.2), Vector2(0, -0.35), Vector2(0.28, -0.2)]

func _get_aim_direction() -> Vector3:
	if InputManager.wants_mouse_aim(player_index):
		var target := _screen_to_world(InputManager.get_mouse_screen_position())
		var dir := (target - global_position)
		dir.y = 0.0
		if dir.length() > 0.01:
			return dir.normalized()
	return Vector3(0, 0, -1)

func _screen_to_world(screen_pos: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return global_position
	var plane := Plane(Vector3.UP, global_position.y)
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	var hit = plane.intersects_ray(origin, dir)
	if hit == null:
		return global_position
	return hit

func _handle_passive_shield(delta: float) -> void:
	var stats := ShipDatabase.get_stats(ship_id)
	if not bool(stats.get("passive_shield_regen", false)):
		return
	if GameManager.shield_charges[player_index] >= SHIELD_MAX:
		return
	passive_shield_regen_timer += delta
	if passive_shield_regen_timer >= 12.0:
		passive_shield_regen_timer = 0.0
		add_shield_charge(1)

func _try_use_bomb() -> void:
	if GameManager.bombs[player_index] <= 0:
		return
	GameManager.bombs[player_index] -= 1
	_trigger_bomb()

func _trigger_bomb() -> void:
	AudioManager.play_sfx("bomb")
	invuln_timer = max(invuln_timer, 1.5)
	for enemy_bullet in get_tree().get_nodes_in_group(Constants.GROUP_ENEMY_BULLET):
		enemy_bullet.queue_free()
	for enemy in get_tree().get_nodes_in_group(Constants.GROUP_ENEMY):
		if enemy.has_method("take_damage"):
			enemy.take_damage(BOMB_DAMAGE)
	for boss in get_tree().get_nodes_in_group(Constants.GROUP_BOSS):
		if boss.has_method("take_damage"):
			boss.take_damage(30.0)

## --- Danio / power-ups ---------------------------------------------------

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group(Constants.GROUP_POWERUP):
		return # PowerUpBase.gd maneja su propio pickup via body/area_entered del lado del powerup.
	if area.is_in_group(Constants.GROUP_ENEMY) or area.is_in_group(Constants.GROUP_BOSS):
		if area.has_method("get_contact_damage"):
			take_damage(area.get_contact_damage())

func take_damage(amount: float) -> void:
	if not alive or invuln_timer > 0.0:
		return
	if GameManager.shield_charges[player_index] > 0:
		GameManager.shield_charges[player_index] -= 1
		shield_changed.emit(GameManager.shield_charges[player_index])
		AudioManager.play_sfx("shield_break")
		invuln_timer = HIT_INVULN_TIME
		return
	current_hp -= int(ceil(amount))
	hp_changed.emit(current_hp, max_hp)
	AudioManager.play_sfx("hit_player")
	if current_hp <= 0:
		_die()
	else:
		invuln_timer = HIT_INVULN_TIME

func add_shield_charge(amount: int) -> void:
	GameManager.shield_charges[player_index] = clampi(GameManager.shield_charges[player_index] + amount, 0, SHIELD_MAX)
	shield_changed.emit(GameManager.shield_charges[player_index])

func apply_powerup(power_type: String) -> void:
	match power_type:
		"weapon":
			GameManager.set_weapon_level(player_index, GameManager.weapon_level[player_index] + 1)
		"shield":
			add_shield_charge(1)
		"speed":
			speed_boost_timer = 15.0
		"bomb":
			GameManager.bombs[player_index] += 1
	AudioManager.play_sfx("powerup")

func _die() -> void:
	alive = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	died.emit(player_index)
	var game_over := GameManager.lose_life(player_index)
	if not game_over:
		await get_tree().create_timer(1.2).timeout
		_respawn()

func _respawn() -> void:
	current_hp = max_hp
	hp_changed.emit(current_hp, max_hp)
	global_position = Vector3(0.0, 0.0, Constants.PLAYER_MAX_Z - 1.0)
	alive = true
	visible = true
	set_deferred("monitoring", true)
	set_deferred("monitorable", true)
	invuln_timer = RESPAWN_INVULN_TIME
