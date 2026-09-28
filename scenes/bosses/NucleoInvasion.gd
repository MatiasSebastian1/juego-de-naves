extends BossBase
## Jefe final del prototipo. 4 fases: escudo, invocacion, laser, enrage.

const MOVE_AMPLITUDE := 2.6

var _fire_timer: float = 0.0
var _spawn_timer: float = 0.0
var _spawn_x: float = 0.0
var _laser_bursts_left: int = 0
var _laser_burst_timer: float = 0.0
var _laser_charge_timer: float = 0.0
var _laser_dir: Vector3 = Vector3(0, 0, 1)

func _configure() -> void:
	max_hp = 95.0
	speed = 0.0
	score_value = 10000
	contact_damage = 4.0
	powerup_drop_chance = 0.0
	phase_names = ["Escudo", "Invocacion", "Laser", "Enrage"]
	phase_thresholds = [0.75, 0.5, 0.25]
	target_z = -3.5

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := SphereMesh.new()
	mesh.radius = 1.3
	mesh.height = 2.0
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.15, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.1, 0.2)
	mat.emission_energy_multiplier = 0.8
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	shape.shape = sphere
	add_child(shape)

func take_damage(amount: float) -> void:
	var final_amount := amount
	if current_phase_index == 0:
		final_amount *= 0.5 # fase "Escudo": mitiga danio recibido
	super.take_damage(final_amount)

func _phase_enter(phase_index: int) -> void:
	_fire_timer = 0.5
	_spawn_timer = 1.5
	_spawn_x = global_position.x
	_laser_bursts_left = 0
	_laser_charge_timer = 1.0

func _phase_process(phase_index: int, delta: float) -> void:
	match phase_index:
		0:
			global_position.x = _spawn_x + sin(_elapsed * 0.4) * (MOVE_AMPLITUDE * 0.4)
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.5
				fire_fan(45.0, 5, 6.0, 1.0)
		1:
			global_position.x = _spawn_x + sin(_elapsed * 0.5) * (MOVE_AMPLITUDE * 0.6)
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.8
				fire_aimed_at_nearest_player(7.0, 1.0)
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_timer = 4.0
				_summon_reinforcement()
		2:
			global_position.x = _spawn_x + sin(_elapsed * 0.7) * MOVE_AMPLITUDE
			_process_laser(delta)
		3:
			global_position.x = _spawn_x + sin(_elapsed * 1.1) * MOVE_AMPLITUDE
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 0.9
				fire_fan(70.0, 8, 8.0, 1.2)
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				_spawn_timer = 3.0
				_summon_reinforcement()

func _process_laser(delta: float) -> void:
	if _laser_bursts_left <= 0:
		_laser_charge_timer -= delta
		if _laser_charge_timer <= 0.0:
			_laser_charge_timer = 2.2
			var target := _find_nearest_player()
			_laser_dir = Vector3(0, 0, 1)
			if target:
				var to_target: Vector3 = target.global_position - global_position
				to_target.y = 0.0
				if to_target.length() > 0.05:
					_laser_dir = to_target.normalized()
			_laser_bursts_left = 10
			_laser_burst_timer = 0.0
	else:
		_laser_burst_timer -= delta
		if _laser_burst_timer <= 0.0:
			_laser_burst_timer = 0.05
			fire_bullet(_laser_dir, 17.0, 1.2)
			_laser_bursts_left -= 1

func _summon_reinforcement() -> void:
	var scene: PackedScene = load("res://scenes/enemies/CazaRapido.tscn")
	var fighter: Node3D = scene.instantiate()
	var offset := Vector3(randf_range(-1.5, 1.5), 0.0, 0.6)
	get_parent().add_child(fighter)
	fighter.global_position = global_position + offset
