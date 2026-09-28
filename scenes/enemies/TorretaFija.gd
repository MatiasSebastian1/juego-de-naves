extends EnemyBase
## Estatica respecto del scroll (no se mueve por su cuenta), dispara en circulo.

const FIRE_INTERVAL := 1.7
const BULLET_COUNT := 8

var _fire_timer: float = 1.0

func _configure() -> void:
	max_hp = 5.0
	speed = 0.0
	score_value = 250
	contact_damage = 1.5
	powerup_drop_chance = 0.2
	_fire_timer = 1.0

func _build_visual() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.55
	mesh.height = 0.5
	mesh_instance.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.6, 0.7)
	mat.emission_energy_multiplier = 0.3
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.5
	cyl.height = 0.5
	shape.shape = cyl
	add_child(shape)

func _pattern_process(delta: float) -> void:
	# No se mueve localmente: el scroll del nivel la arrastra tal cual.
	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		_fire_circle()

func _fire_circle() -> void:
	var step := TAU / float(BULLET_COUNT)
	for i in BULLET_COUNT:
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, step * i)
		fire_bullet(dir, 6.0, 1.0)
