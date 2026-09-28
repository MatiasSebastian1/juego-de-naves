class_name BackgroundLayer
extends Node3D
## Fondo procedural placeholder (nubes/ruinas/nucleo segun tinte) mientras no
## hay assets de Meshy. Cuando lleguen los .glb, esto se reemplaza sin tocar
## LevelBase: solo hay que dejar de llamar a build().

func build(tint: Color, count: int, y_level: float = -1.2) -> void:
	for i in count:
		var quad := MeshInstance3D.new()
		var mesh := PlaneMesh.new()
		var size := randf_range(1.2, 3.2)
		mesh.size = Vector2(size, size)
		quad.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(tint.r, tint.g, tint.b, randf_range(0.12, 0.3))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material_override = mat
		add_child(quad)
		quad.position = Vector3(
			randf_range(-Constants.PLAYFIELD_HALF_WIDTH - 1.5, Constants.PLAYFIELD_HALF_WIDTH + 1.5),
			y_level,
			randf_range(Constants.SPAWN_Z, Constants.DESPAWN_Z)
		)
		quad.rotation_degrees.y = randf_range(0, 360)

func _process(_delta: float) -> void:
	var cycle_length := Constants.DESPAWN_Z - Constants.SPAWN_Z
	for child in get_children():
		if child.global_position.z > Constants.DESPAWN_Z:
			child.position.z -= cycle_length
			child.position.x = randf_range(-Constants.PLAYFIELD_HALF_WIDTH - 1.5, Constants.PLAYFIELD_HALF_WIDTH + 1.5)
