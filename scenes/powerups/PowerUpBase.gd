class_name PowerUpBase
extends Area3D
## Base para los 4 power-ups. Cada subclase define power_type + visual.
## El pickup lo maneja este script (no Player), asi hay un solo lugar que
## decide "que significa agarrar este objeto".

var power_type: String = "weapon"
var drift_speed: float = 0.6

func _ready() -> void:
	_configure()
	collision_layer = Constants.LAYER_POWERUP
	collision_mask = Constants.LAYER_PLAYER | Constants.LAYER_PLAYER2
	monitoring = true
	monitorable = true
	add_to_group(Constants.GROUP_POWERUP)
	area_entered.connect(_on_area_entered)
	_build_visual()
	_build_collision()

func _configure() -> void:
	pass # override en cada subclase: setear power_type

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := SphereMesh.new()
	mesh.radius = 0.3
	mesh.height = 0.6
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _get_color()
	mat.emission_enabled = true
	mat.emission = _get_color()
	mat.emission_energy_multiplier = 1.5
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _get_color() -> Color:
	match power_type:
		"weapon": return Color(1.0, 0.9, 0.2)
		"shield": return Color(0.3, 0.6, 1.0)
		"speed": return Color(0.3, 1.0, 0.5)
		"bomb": return Color(1.0, 0.3, 0.3)
		_: return Color.WHITE

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.35
	shape.shape = sphere
	add_child(shape)

func _physics_process(delta: float) -> void:
	global_position.z += drift_speed * delta
	global_position.y = 0.1 + sin(Time.get_ticks_msec() / 300.0) * 0.05
	if global_position.z > Constants.DESPAWN_Z:
		queue_free()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group(Constants.GROUP_PLAYER) and area.has_method("apply_powerup"):
		area.apply_powerup(power_type)
		queue_free()
