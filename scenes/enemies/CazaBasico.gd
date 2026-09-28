extends EnemyBase
## Vuela derecho hacia abajo. El enemigo mas simple, usado para ensenar controles.

func _configure() -> void:
	max_hp = 2.0
	speed = 2.6
	score_value = 100
	contact_damage = 1.0
	powerup_drop_chance = 0.1

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.65
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.25, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.85, 0.25, 0.25)
	mat.emission_energy_multiplier = 0.4
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _pattern_process(delta: float) -> void:
	global_position.z += speed * delta
