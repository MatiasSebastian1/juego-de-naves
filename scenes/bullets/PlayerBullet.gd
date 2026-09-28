extends Area3D
## Proyectil del jugador. Viaja hacia -Z (arriba de la pantalla).

var speed: float = 22.0
var damage: float = 1.0
var direction: Vector3 = Vector3(0, 0, -1)
var owner_layer: int = Constants.LAYER_PLAYER_BULLET

func _ready() -> void:
	collision_layer = owner_layer
	collision_mask = Constants.LAYER_ENEMY | Constants.LAYER_BOSS
	monitoring = true
	monitorable = true
	add_to_group(Constants.GROUP_PLAYER_BULLET)
	area_entered.connect(_on_area_entered)
	_build_visual()

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.5
	mesh_instance.mesh = mesh
	mesh_instance.rotation_degrees = Vector3(90, 0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.95, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.95, 1.0)
	mat.emission_energy_multiplier = 3.0
	mesh_instance.material_override = mat
	add_child(mesh_instance)

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	shape.shape = sphere
	add_child(shape)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.z < Constants.SPAWN_Z - 2.0 or global_position.z > Constants.DESPAWN_Z + 2.0:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group(Constants.GROUP_ENEMY) or area.is_in_group(Constants.GROUP_BOSS):
		if area.has_method("take_damage"):
			area.take_damage(damage)
		queue_free()
