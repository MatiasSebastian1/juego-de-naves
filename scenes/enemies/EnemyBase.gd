class_name EnemyBase
extends Area3D
## Base comun para los 6 tipos de enemigo. Los hijos configuran stats en
## _configure() y movimiento propio en _pattern_process(). El transporte
## "hacia el jugador" lo da el scroll del nivel (este nodo es hijo del
## ScrollRoot), no este script.

const EnemyBulletScene := preload("res://scenes/bullets/EnemyBullet.tscn")

var max_hp: float = 1.0
var hp: float = 1.0
var speed: float = 2.0
var score_value: int = 100
var contact_damage: float = 1.0
var powerup_drop_chance: float = 0.12
var needs_player_contact_detection: bool = false

var _elapsed: float = 0.0

func _ready() -> void:
	_configure()
	hp = max_hp
	collision_layer = Constants.LAYER_ENEMY
	monitorable = true
	monitoring = needs_player_contact_detection
	if needs_player_contact_detection:
		collision_mask = Constants.LAYER_PLAYER | Constants.LAYER_PLAYER2
		area_entered.connect(_on_area_entered)
	add_to_group(Constants.GROUP_ENEMY)
	_build_visual()
	_build_collision()

func _configure() -> void:
	pass # override en cada subclase

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.6, 0.4, 0.6)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.2, 0.2)
	mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.5, 0.6)
	shape.shape = box
	add_child(shape)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	_pattern_process(delta)
	if global_position.z > Constants.DESPAWN_Z or absf(global_position.x) > Constants.PLAYFIELD_HALF_WIDTH + 4.0:
		queue_free()

func _pattern_process(_delta: float) -> void:
	pass # override en cada subclase

func fire_bullet(direction: Vector3, bullet_speed: float = 8.0, damage: float = 1.0) -> void:
	var bullet := EnemyBulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.direction = direction.normalized()
	bullet.speed = bullet_speed
	bullet.damage = damage

func get_contact_damage() -> float:
	return contact_damage

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0.0:
		_die()
	else:
		AudioManager.play_sfx("hit_enemy")

func _die() -> void:
	AudioManager.play_sfx("explosion_small")
	for i in GameManager.active_player_count():
		GameManager.add_score(i, score_value)
	_maybe_drop_powerup()
	queue_free()

func _maybe_drop_powerup() -> void:
	if randf() < powerup_drop_chance and is_instance_valid(get_parent()):
		PowerUpSpawner.spawn_random(get_parent(), global_position)

func _on_area_entered(area: Area3D) -> void:
	pass # override para kamikaze, etc.
