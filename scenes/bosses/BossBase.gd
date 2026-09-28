class_name BossBase
extends EnemyBase
## Base comun para los jefes: entra en escena, avanza de fase segun el HP
## restante y delega el patron de ataque de cada fase a la subclase.

signal phase_changed(phase_index: int, phase_name: String)
signal boss_defeated()
signal boss_hp_changed(fraction: float)

var phase_names: Array[String] = []
var phase_thresholds: Array[float] = [] # fracciones de HP donde se pasa a la fase siguiente

var target_z: float = -3.5
var entry_speed: float = 2.2
var current_phase_index: int = -1
var _in_position: bool = false

func _ready() -> void:
	super._ready()
	collision_layer = Constants.LAYER_BOSS
	remove_from_group(Constants.GROUP_ENEMY)
	add_to_group(Constants.GROUP_BOSS)
	AudioManager.play_sfx("boss_alert")

func _pattern_process(delta: float) -> void:
	if not _in_position:
		_move_to_position(delta)
		return
	_update_phase()
	_phase_process(current_phase_index, delta)

func _move_to_position(delta: float) -> void:
	global_position.z = move_toward(global_position.z, target_z, entry_speed * delta)
	if is_equal_approx(global_position.z, target_z):
		_in_position = true
		current_phase_index = 0
		_phase_enter(0)
		phase_changed.emit(0, _phase_name(0))

func _update_phase() -> void:
	var frac := get_hp_fraction()
	boss_hp_changed.emit(frac)
	var new_phase := 0
	for i in phase_thresholds.size():
		if frac <= phase_thresholds[i]:
			new_phase = i + 1
	if new_phase != current_phase_index:
		current_phase_index = new_phase
		_phase_enter(current_phase_index)
		phase_changed.emit(current_phase_index, _phase_name(current_phase_index))

func _phase_name(index: int) -> String:
	return phase_names[index] if index >= 0 and index < phase_names.size() else ""

func get_hp_fraction() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)

func _phase_enter(_phase_index: int) -> void:
	pass # override

func _phase_process(_phase_index: int, _delta: float) -> void:
	pass # override

## --- Helpers de disparo compartidos por los jefes -----------------------

func fire_fan(half_angle_deg: float, count: int, bullet_speed: float, damage: float) -> void:
	var step := (half_angle_deg * 2.0) / float(max(count - 1, 1))
	for i in count:
		var angle_deg := -half_angle_deg + step * i
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(angle_deg))
		fire_bullet(dir, bullet_speed, damage)

func fire_circle(count: int, bullet_speed: float, damage: float) -> void:
	var step := TAU / float(count)
	for i in count:
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, step * i)
		fire_bullet(dir, bullet_speed, damage)

func fire_aimed_at_nearest_player(bullet_speed: float, damage: float) -> void:
	var target := _find_nearest_player()
	var dir := Vector3(0, 0, 1)
	if target:
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.05:
			dir = to_target.normalized()
	fire_bullet(dir, bullet_speed, damage)

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

func _die() -> void:
	AudioManager.play_sfx("explosion_big")
	for i in GameManager.active_player_count():
		GameManager.add_score(i, score_value)
	boss_defeated.emit()
	queue_free()
