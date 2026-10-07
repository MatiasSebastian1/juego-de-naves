extends RefCounted
# Utilidades de carga de modelos GLB (Kenney, CC0) y materiales.
# Los GLB de Kenney vienen con materiales "unlit": aca se convierten a materiales con luz (sombreado por pixel)
# para que respondan al sol, la niebla y las luces de fuego.

const KEN := "res://assets/third_party/kenney/"

# PUNTO DE EXTENSION: personaje principal generado con Meshy AI (aun no entregado, no se usa).
# Si existe `assets/meshy/character.glb`, `meshy_character_available()` devuelve true; el reemplazo del Blocky del jugador
# se haria en model.gd (Model.setup) cargando este GLB con la escala/rotacion de abajo. Ver "Personaje Meshy" en el README.
const MESHY_CHARACTER := "res://assets/meshy/character.glb"
const MESHY_CHARACTER_SCALE := 1.0          # ajustar para que mida ~1.8 m
const MESHY_CHARACTER_YAW_DEG := 180.0      # giro para que el frente mire a +Z local (como los Blocky; ajustar segun el modelo)

static func meshy_character_available() -> bool:
	return ResourceLoader.exists(MESHY_CHARACTER)

static var headless := DisplayServer.get_name() == "headless"   # sin renderer: las mallas no exponen superficies
static var _scenes := {}
static var _lit := {}

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

static func inst(path: String) -> Node3D:
	var ps := scene(path)
	if ps == null:
		push_error("modelo no encontrado: " + path)
		return Node3D.new()
	return ps.instantiate() as Node3D

# Convierte los materiales de todas las mallas a versiones con luz, compartidas (cache) entre instancias.
static func make_lit(root: Node, tint := Color.WHITE, rough := 0.9) -> void:
	if headless:
		return
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base = mi.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var key := str(base.get_instance_id()) + str(tint) + str(rough)
				if not _lit.has(key):
					var d: StandardMaterial3D = base.duplicate()
					d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
					d.albedo_color = d.albedo_color * tint
					d.roughness = rough
					d.metallic = 0.0
					d.metallic_specular = 0.25
					d.cull_mode = BaseMaterial3D.CULL_BACK
					_lit[key] = d
				mi.set_surface_override_material(s, _lit[key])

# Materiales propios (no compartidos) para un personaje: permiten tintar, borde de luz y destello de dano.
static func make_unique_lit(root: Node, tint: Color, rim: float, rim_tint: float) -> Array:
	var out := []
	if headless:
		return out
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base = mi.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var d: StandardMaterial3D = base.duplicate()
				d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				d.albedo_color = tint
				d.roughness = 0.85
				d.metallic_specular = 0.2
				d.rim_enabled = rim > 0.0
				d.rim = rim
				d.rim_tint = rim_tint
				d.emission_enabled = true
				d.emission = Color.BLACK
				d.emission_energy_multiplier = 1.0
				d.cull_mode = BaseMaterial3D.CULL_BACK
				mi.set_surface_override_material(s, d)
				out.append(d)
	return out

# Caja envolvente (en el espacio local de `root`) de todas las mallas.
static func aabb_of(root: Node3D) -> AABB:
	var res := AABB()
	var first := true
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != root and n != null:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var a: AABB = t * mi.mesh.get_aabb()
		if first:
			res = a
			first = false
		else:
			res = res.merge(a)
	return res
