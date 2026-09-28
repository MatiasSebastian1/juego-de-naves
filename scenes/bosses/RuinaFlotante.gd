extends BossBase
## Jefe del Nivel 2 - Ruinas Flotantes. 3 fases: torretas, misiles, nucleo expuesto.

const MOVE_AMPLITUDE := 2.0
const MOVE_FREQ := 0.35

var _fire_timer: float = 0.0
var _spawn_x: float = 0.0
var _turret_offsets: Array[Vector3] = [Vector3(-1.4, 0, 0), Vector3(1.4, 0, 0)]

func _configure() -> void:
	max_hp = 60.0
	speed = 0.0
	score_value = 6000
	contact_damage = 3.0
	powerup_drop_chance = 0.0
	phase_names = ["Torretas", "Misiles", "Nucleo expuesto"]
	phase_thresholds = [0.6, 0.3]
	target_z = -3.5

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.8, 1.1, 2.0)
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.4, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.5, 0.3)
	mat.emission_energy_multiplier = 0.4
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 1.1, 2.0)
	shape.shape = box
	add_child(shape)

func _phase_enter(phase_index: int) -> void:
	_fire_timer = 0.6
	_spawn_x = global_position.x

func _phase_process(phase_index: int, delta: float) -> void:
	match phase_index:
		0:
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.4
				_fire_from_turrets()
		1:
			global_position.x = _spawn_x + sin(_elapsed * MOVE_FREQ) * (MOVE_AMPLITUDE * 0.5)
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 1.8
				fire_aimed_at_nearest_player(6.0, 2.0)
				fire_aimed_at_nearest_player(6.0, 2.0)
		2:
			global_position.x = _spawn_x + sin(_elapsed * MOVE_FREQ * 2.2) * MOVE_AMPLITUDE
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_fire_timer = 0.5
				fire_fan(60.0, 6, 8.0, 1.0)

func _fire_from_turrets() -> void:
	for offset in _turret_offsets:
		var origin := global_position + offset
		var dir := Vector3(0, 0, 1)
		var target := _find_nearest_player()
		if target:
			var to_target: Vector3 = target.global_position - origin
			to_target.y = 0.0
			if to_target.length() > 0.05:
				dir = to_target.normalized()
		var bullet := EnemyBulletScene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = origin
		bullet.direction = dir
		bullet.speed = 7.0
		bullet.damage = 1.0
