extends Node3D
# Items que se recogen caminando encima: vida, municion, granadas, escopeta y rafaga (armas temporales).

const Assets = preload("res://scripts/assets.gd")
const BL := "res://assets/third_party/kenney/blasters/"

const KINDS := {
	"hp": {"model": "crate-small", "scale": 2.6, "col": Color(0.3, 1.0, 0.45), "label": "VIDA +35"},
	"ammo": {"model": "clip-large", "scale": 3.6, "col": Color(1.0, 0.85, 0.3), "label": "MUNICION +60"},
	"gren": {"model": "grenade-a", "scale": 3.4, "col": Color(1.0, 0.5, 0.2), "label": "GRANADAS +2"},
	"spread": {"model": "blaster-d", "scale": 1.15, "col": Color(1.0, 0.55, 0.25), "label": "ESCOPETA"},
	"burst": {"model": "blaster-e", "scale": 0.95, "col": Color(0.4, 0.85, 1.0), "label": "RAFAGA"},
}

var kind := "hp"
var life := 24.0
var t := 0.0
var model: Node3D
var glow: MeshInstance3D
var base_y := 0.9

func setup(k: String, pos: Vector3) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	global_position = Vector3(pos.x, 0.0, pos.z)
	model = Assets.inst(BL + d.model + ".glb")
	Assets.make_lit(model, Color(1, 1, 1))
	var bb := Assets.aabb_of(model)
	model.scale = Vector3.ONE * float(d.scale)
	# centrar el modelo en su propio origen
	var sc: float = d.scale
	var c := (bb.position + bb.size * 0.5) * sc
	model.position = -c
	var holder := Node3D.new()
	holder.name = "holder"
	add_child(holder)
	holder.add_child(model)
	holder.position.y = base_y
	if Assets.headless:
		return
	# resplandor y anillo de color en el suelo
	glow = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(2.6, 2.6)
	glow.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = load("res://assets/third_party/kenney/particles/light_01.png")
	mat.albedo_color = Color(d.col.r, d.col.g, d.col.b, 0.75)
	mat.disable_fog = true
	glow.material_override = mat
	glow.position.y = base_y
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	var ring := MeshInstance3D.new()
	var pm := QuadMesh.new()
	pm.size = Vector2(1.9, 1.9)
	ring.mesh = pm
	ring.rotation_degrees.x = -90.0
	ring.position.y = 0.06
	var m2 := StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m2.albedo_texture = load("res://assets/third_party/kenney/particles/circle_05.png")
	m2.albedo_color = Color(d.col.r, d.col.g, d.col.b, 0.8)
	m2.disable_fog = true
	ring.material_override = m2
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

func _process(delta: float) -> void:
	t += delta
	var h: Node3D = get_node_or_null("holder")
	if h:
		h.rotation.y += delta * 2.2
		h.position.y = base_y + sin(t * 3.0) * 0.12
		if glow:
			glow.position.y = h.position.y
	if glow:
		var m := glow.material_override as StandardMaterial3D
		var a := 0.55 + 0.25 * sin(t * 4.0)
		if life < 5.0:
			a *= 0.5 + 0.5 * sin(t * 18.0)
		m.albedo_color.a = a
