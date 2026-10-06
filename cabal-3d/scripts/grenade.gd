extends Node3D
# Granada con trayectoria parabolica calculada a mano (rebota contra el mundo) y explosion en area.

const Assets = preload("res://scripts/assets.gd")
const G := 20.0

var game
var fx
var level
var vel := Vector3.ZERO
var by_player := true
var fuse := 1.5
var age := 0.0
var radius := 5.2
var dmg := 110.0
var ring: MeshInstance3D = null
var model: Node3D
var blink: MeshInstance3D
var target := Vector3.ZERO
var rest := false
var done := false

func launch(start: Vector3, tgt: Vector3, player_owned: bool, ring_node = null) -> void:
	by_player = player_owned
	target = tgt
	ring = ring_node
	global_position = start
	var dist := Vector2(tgt.x - start.x, tgt.z - start.z).length()
	var t := clampf(dist / 15.0, 0.55, 1.35) if by_player else 1.2
	vel = (tgt - start) / t + Vector3(0, 0.5 * G * t, 0)
	fuse = t + (0.35 if by_player else 0.55)
	dmg = 120.0 if by_player else 42.0
	radius = 5.4 if by_player else 4.2
	model = Assets.inst("res://assets/third_party/kenney/blasters/grenade-a.glb")
	Assets.make_lit(model, Color(1, 1, 1))
	model.scale = Vector3.ONE * 2.4
	add_child(model)
	if Assets.headless:
		return
	blink = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	blink.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.15, 0.1)
	blink.material_override = mat
	blink.position = Vector3(0, 0.35, 0)
	blink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blink)

func _physics_process(delta: float) -> void:
	if done:
		return
	age += delta
	if not rest:
		vel.y -= G * delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * 0.1, 1)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			var n: Vector3 = r.normal
			vel = vel.bounce(n) * 0.38
			vel.x *= 0.8
			vel.z *= 0.8
			global_position = r.position + n * 0.1
			if n.y > 0.7 and vel.length() < 2.2:
				rest = true
				vel = Vector3.ZERO
		else:
			global_position = to
		if global_position.y < 0.1:
			global_position.y = 0.1
			vel.y = absf(vel.y) * 0.35
			vel.x *= 0.7
			vel.z *= 0.7
			if vel.length() < 2.0:
				rest = true
		if model:
			model.rotation += Vector3(7.0, 3.0, 5.0) * delta * (0.0 if rest else 1.0)
	# parpadeo cada vez mas rapido
	var rate := 6.0 + age * 6.0
	if blink:
		blink.visible = sin(age * rate * 3.0) > -0.2
	if ring:
		var k := clampf(age / fuse, 0.0, 1.0)
		(ring.material_override as ShaderMaterial).set_shader_parameter("pulse", k)
		(ring.material_override as ShaderMaterial).set_shader_parameter("strength", 0.7 + 0.3 * sin(age * 18.0))
	if age >= fuse:
		explode()

func explode() -> void:
	if done:
		return
	done = true
	if ring:
		ring.queue_free()
		ring = null
	game.explosion(global_position, radius, dmg, by_player)
	game.grenades.erase(self)
	queue_free()

func cleanup() -> void:
	done = true
	if ring:
		ring.queue_free()
		ring = null
	game.grenades.erase(self)
	queue_free()
