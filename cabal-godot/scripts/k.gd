extends RefCounted
# Constantes, datos de enemigos y fabrica de texturas/materiales compartidos.

const W := 1280
const H := 720
const HOR := 292.0
const FLOOR := 650.0

const TYPES := {
	"rifle":     {"hp": 3.0,   "size": 1.0,  "spd": 0.18, "sw": 1.2, "sa": 30.0, "tele": 0.5,  "cd": [1.6, 3.2], "score": 100,  "tz": [0.45, 0.75]},
	"grenadier": {"hp": 4.0,   "size": 1.0,  "spd": 0.14, "sw": 0.8, "sa": 20.0, "tele": 0.75, "cd": [2.8, 4.4], "score": 150,  "tz": [0.35, 0.6]},
	"runner":    {"hp": 2.0,   "size": 0.95, "spd": 0.35, "sw": 0.0, "sa": 0.0,  "tele": 0.0,  "cd": [9.0, 9.0], "score": 120,  "tz": [1.0, 1.0]},
	"heavy":     {"hp": 16.0,  "size": 1.35, "spd": 0.1,  "sw": 0.6, "sa": 14.0, "tele": 0.6,  "cd": [1.5, 2.5], "score": 400,  "tz": [0.5, 0.7]},
	"boss":      {"hp": 140.0, "size": 2.7,  "spd": 0.08, "sw": 0.5, "sa": 60.0, "tele": 0.7,  "cd": [1.3, 2.1], "score": 3000, "tz": [0.32, 0.32]},
}

static var _tex := {}
static var _add: CanvasItemMaterial = null

static func zscale(z: float) -> float:
	return 0.28 + z * 0.85

static func zy(z: float) -> float:
	return HOR + z * (FLOOR - HOR)

static func tex(n: String) -> Texture2D:
	if not _tex.has(n):
		_tex[n] = load("res://assets/sprites/%s.png" % n)
	return _tex[n]

static func _radial(offsets: Array, colors: Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 256
	t.height = 256
	return t

static func glow_tex() -> Texture2D:
	if not _tex.has("_glow"):
		_tex["_glow"] = _radial([0.0, 0.25, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	return _tex["_glow"]

static func soft_tex() -> Texture2D:
	if not _tex.has("_soft"):
		_tex["_soft"] = _radial([0.0, 0.5, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	return _tex["_soft"]

static func shadow_tex() -> Texture2D:
	if not _tex.has("_shadow"):
		_tex["_shadow"] = _radial([0.0, 0.6, 1.0], [Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.38), Color(0, 0, 0, 0)])
	return _tex["_shadow"]

static func ring_tex() -> Texture2D:
	if not _tex.has("_ring"):
		_tex["_ring"] = _radial([0.0, 0.7, 0.88, 1.0], [Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 0.9, 0.7, 0.9), Color(1, 1, 1, 0)])
	return _tex["_ring"]

static func square_tex() -> Texture2D:
	if not _tex.has("_sq"):
		var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		im.fill(Color(1, 1, 1, 1))
		_tex["_sq"] = ImageTexture.create_from_image(im)
	return _tex["_sq"]

static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		_add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _add

static func fade_ramp(c0: Color, c1: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([c0, c1])
	return g
