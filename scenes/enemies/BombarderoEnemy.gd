extends EnemyBase
## Lento, mucha vida, dispara un abanico de proyectiles.

const FIRE_INTERVAL := 2.0
const FAN_HALF_ANGLE_DEG := 40.0
const FAN_BULLET_COUNT := 5

var _fire_timer: float = 1.0

func _configure() -> void:
	max_hp = 9.0
	speed = 1.1
	score_value = 300
	contact_damage = 2.0
	powerup_drop_chance = 0.25
	_fire_timer = 1.5

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 0.5, 1.0)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.35, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.55, 0.35, 0.2)
	mat.emission_energy_multiplier = 0.35
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.5, 1.0)
	shape.shape = box
	add_child(shape)

func _pattern_process(delta: float) -> void:
	global_position.z += speed * delta
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_fire_fan()

func _fire_fan() -> void:
	var step := (FAN_HALF_ANGLE_DEG * 2.0) / float(FAN_BULLET_COUNT - 1)
	for i in FAN_BULLET_COUNT:
		var angle_deg := -FAN_HALF_ANGLE_DEG + step * i
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(angle_deg))
		fire_bullet(dir, 7.0, 1.0)
