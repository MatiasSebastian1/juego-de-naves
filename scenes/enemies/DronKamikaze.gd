extends EnemyBase
## Persigue al jugador mas cercano y se autodestruye al tocarlo (o al morir).

func _configure() -> void:
	max_hp = 1.0
	speed = 5.5
	score_value = 200
	contact_damage = 2.0
	powerup_drop_chance = 0.08
	needs_player_contact_detection = true

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.4, 0.05)
	mat.emission_energy_multiplier = 0.9
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _pattern_process(delta: float) -> void:
	var target := _find_nearest_player()
	if target:
		var dir := (target.global_position - global_position)
		dir.y = 0.0
		if dir.length() > 0.05:
			global_position += dir.normalized() * speed * delta
	else:
		global_position.z += speed * delta

func _find_nearest_player() -> Node3D:
	var players := get_tree().get_nodes_in_group(Constants.GROUP_PLAYER)
	var nearest: Node3D = null
	var nearest_dist := INF
	for p in players:
		if not (p is Node3D) or not p.get("alive"):
			continue
		var d := global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = p
	return nearest

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group(Constants.GROUP_PLAYER):
		AudioManager.play_sfx("explosion_small")
		take_damage(max_hp)
