extends Area3D
## Proyectil enemigo. Viaja hacia +Z (abajo de la pantalla, hacia el jugador).

var speed: float = 9.0
var damage: float = 1.0
var direction: Vector3 = Vector3(0, 0, 1)

func _ready() -> void:
	collision_layer = Constants.LAYER_ENEMY_BULLET
	collision_mask = Constants.LAYER_PLAYER | Constants.LAYER_PLAYER2
	monitoring = true
	monitorable = true
	add_to_group(Constants.GROUP_ENEMY_BULLET)
	area_entered.connect(_on_area_entered)
	_build_visual()

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.35, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.35, 0.35)
	mat.emission_energy_multiplier = 3.0
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.12
	shape.shape = sphere
	add_child(shape)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.z < Constants.SPAWN_Z - 2.0 or global_position.z > Constants.DESPAWN_Z + 2.0:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group(Constants.GROUP_PLAYER):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
