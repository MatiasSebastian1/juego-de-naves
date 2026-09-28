extends EnemyBase
## Lento, mucha vida, libera cazas basicos pequenios periodicamente.

const RELEASE_INTERVAL := 2.5
const MAX_RELEASES := 3

var _release_timer: float = 1.5
var _released_count: int = 0

func _configure() -> void:
	max_hp = 12.0
	speed = 0.7
	score_value = 400
	contact_damage = 1.5
	powerup_drop_chance = 0.3

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.6, 1.3)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.4, 0.55)
	mat.emission_energy_multiplier = 0.35
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 0.6, 1.3)
	shape.shape = box
	add_child(shape)

func _pattern_process(delta: float) -> void:
	global_position.z += speed * delta
	if _released_count >= MAX_RELEASES:
		return
	_release_timer -= delta
	if _release_timer <= 0.0:
		_release_timer = RELEASE_INTERVAL
		_released_count += 1
		_release_fighter()

func _release_fighter() -> void:
	var scene: PackedScene = load("res://scenes/enemies/CazaBasico.tscn")
	var fighter: Node3D = scene.instantiate()
	var offset := Vector3(randf_range(-0.8, 0.8), 0.0, 0.3)
	get_parent().add_child(fighter)
	fighter.global_position = global_position + offset
