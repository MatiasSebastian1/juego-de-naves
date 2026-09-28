extends EnemyBase
## Zigzag en X mientras avanza, dispara rapido hacia el jugador.

const ZIGZAG_FREQ := 2.6
const ZIGZAG_AMP := 1.4
const FIRE_INTERVAL := 1.1

var _spawn_x: float = 0.0
var _fire_timer: float = 0.0
var _pattern_ready: bool = false

func _configure() -> void:
	max_hp = 1.0
	speed = 4.2
	score_value = 150
	contact_damage = 1.0
	powerup_drop_chance = 0.12
	_fire_timer = randf_range(0.3, FIRE_INTERVAL)

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.45, 0.3, 0.6)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(0.95, 0.85, 0.2)
	mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _pattern_process(delta: float) -> void:
	if not _pattern_ready:
		_spawn_x = position.x
		_pattern_ready = true
	global_position.z += speed * delta
	position.x = _spawn_x + sin(_elapsed * ZIGZAG_FREQ) * ZIGZAG_AMP

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		fire_bullet(Vector3(0, 0, 1), 10.0, 1.0)
