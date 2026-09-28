extends BossBase
## Jefe del Nivel 1 - Capa de Nubes. 3 fases: disparo frontal, abanico, laser.

const MOVE_AMPLITUDE := 2.4
const MOVE_FREQ := 0.5

var _fire_timer: float = 0.0
var _spawn_x: float = 0.0
var _laser_charge_timer: float = 0.0
var _laser_bursts_left: int = 0
var _laser_burst_timer: float = 0.0
var _laser_dir: Vector3 = Vector3(0, 0, 1)

func _configure() -> void:
	max_hp = 45.0
	speed = 0.0
	score_value = 5000
	contact_damage = 3.0
	powerup_drop_chance = 0.0
	phase_names = ["Disparo frontal", "Abanico", "Laser"]
	phase_thresholds = [0.66, 0.33]
	target_z = -3.5

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.4, 0.9, 1.8)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.55, 0.75)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.7, 1.0)
	mat.emission_energy_multiplier = 0.6
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 0.9, 1.8)
	shape.shape = box
	add_child(shape)

func _phase_enter(phase_index: int) -> void:
	_fire_timer = 0.5
	_laser_bursts_left = 0
	_spawn_x = global_position.x

func _phase_process(phase_index: int, delta: float) -> void:
	global_position.x = _spawn_x + sin(_elapsed * MOVE_FREQ) * MOVE_AMPLITUDE
	match phase_index:
		0:
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.0
				fire_bullet(Vector3(0, 0, 1), 8.0, 1.0)
				fire_bullet(Vector3(0.08, 0, 1), 8.0, 1.0)
				fire_bullet(Vector3(-0.08, 0, 1), 8.0, 1.0)
		1:
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.3
				fire_fan(50.0, 7, 7.0, 1.0)
		2:
			_process_laser(delta)

func _process_laser(delta: float) -> void:
	if _laser_bursts_left <= 0:
		_laser_charge_timer -= delta
		if _laser_charge_timer <= 0.0:
			_laser_charge_timer = 2.6
			var target := _find_nearest_player()
			_laser_dir = Vector3(0, 0, 1)
			if target:
				var to_target: Vector3 = target.global_position - global_position
				to_target.y = 0.0
				if to_target.length() > 0.05:
					_laser_dir = to_target.normalized()
			_laser_bursts_left = 8
			_laser_burst_timer = 0.0
		# fan de apoyo mientras carga
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_fire_timer = 1.6
			fire_fan(35.0, 5, 6.0, 1.0)
	else:
		_laser_burst_timer -= delta
		if _laser_burst_timer <= 0.0:
			_laser_burst_timer = 0.06
			fire_bullet(_laser_dir, 16.0, 1.0)
			_laser_bursts_left -= 1
