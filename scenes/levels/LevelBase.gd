class_name LevelBase
extends Node3D
## Base comun de nivel: scroll continuo, timeline de oleadas de enemigos y
## spawn del jefe al final. Las subclases solo llenan _build_timeline().

signal boss_spawned(boss: Node)
signal boss_phase_changed(phase_index: int, phase_name: String)
signal level_finished(level_id: int)

var level_id: int = 1
var scroll_speed: float = 3.0
var scroll_root: Node3D
var elapsed: float = 0.0
var active: bool = true

## Cada entrada: {"time": float, "scene": PackedScene, "x": float}
var wave_timeline: Array[Dictionary] = []
var boss_scene: PackedScene = null
var boss_spawn_time: float = 9999.0

var _wave_cursor: int = 0
var _boss_spawned: bool = false

func _ready() -> void:
	scroll_root = Node3D.new()
	scroll_root.name = "ScrollRoot"
	add_child(scroll_root)
	_setup_environment()
	_setup_background()
	_build_timeline()
	wave_timeline.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))

func _physics_process(delta: float) -> void:
	if not active:
		return
	elapsed += delta
	scroll_root.position.z += scroll_speed * delta
	_process_waves()
	if not _boss_spawned and elapsed >= boss_spawn_time:
		_spawn_boss()

func _process_waves() -> void:
	while _wave_cursor < wave_timeline.size() and float(wave_timeline[_wave_cursor]["time"]) <= elapsed:
		_spawn_wave_entry(wave_timeline[_wave_cursor])
		_wave_cursor += 1

func _spawn_wave_entry(entry: Dictionary) -> void:
	var scene: PackedScene = entry["scene"]
	var inst: Node3D = scene.instantiate()
	inst.position = Vector3(float(entry.get("x", 0.0)), 0.0, Constants.SPAWN_Z)
	scroll_root.add_child(inst)

func _spawn_boss() -> void:
	if boss_scene == null:
		return
	_boss_spawned = true
	var boss: Node3D = boss_scene.instantiate()
	boss.position = Vector3(0.0, 0.0, Constants.SPAWN_Z)
	scroll_root.add_child(boss)
	boss.boss_defeated.connect(_on_boss_defeated)
	boss.phase_changed.connect(func(idx, name): boss_phase_changed.emit(idx, name))
	boss_spawned.emit(boss)
	AudioManager.play_sfx("boss_alert")

func _on_boss_defeated() -> void:
	active = false
	GameManager.complete_level(level_id)
	level_finished.emit(level_id)

func add_wave(time: float, scene: PackedScene, x: float = 0.0) -> void:
	wave_timeline.append({"time": time, "scene": scene, "x": x})

## --- Virtuales para subclases --------------------------------------------

func _build_timeline() -> void:
	pass # override: llenar wave_timeline via add_wave(), setear boss_scene/boss_spawn_time

func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = get_ambient_tint()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	environment.ambient_light_energy = 0.6
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_white = 4.0 # evita que las luces se vayan a blanco puro
	env.environment = environment
	add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-85, 20, 0)
	light.light_energy = 0.9
	light.shadow_enabled = false
	add_child(light)

func get_ambient_tint() -> Color:
	return Color(0.05, 0.06, 0.09)

func _setup_background() -> void:
	var bg := BackgroundLayer.new()
	scroll_root.add_child(bg)
	bg.build(get_ambient_tint() * 3.0, 14)
