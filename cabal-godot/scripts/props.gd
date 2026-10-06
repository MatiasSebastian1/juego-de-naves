extends RefCounted
# Barricadas, cajas de suministro e items.  Cada clase es un Node2D autonomo.

class Barricade extends Node2D:
	const K = preload("res://scripts/k.gd")
	const FLASH = preload("res://shaders/flash.gdshader")
	var hp := 16.0
	var max_hp := 16.0
	var w := 190.0
	var h := 78.0
	var base := 566.0
	var hit := 0.0
	var x := 0.0
	var spr: Sprite2D
	var mat: ShaderMaterial
	var frame := -1
	var cast: Sprite2D

	func _ready() -> void:
		z_index = 88
		position = Vector2(x, base)
		cast = K.make_shadow(Vector2(-260, -270), 0.4, 0.55)
		add_child(cast)
		spr = Sprite2D.new()
		spr.centered = false
		spr.offset = Vector2(-260, -270)
		spr.scale = Vector2(0.4, 0.4)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat = ShaderMaterial.new()
		mat.shader = FLASH
		spr.material = mat
		add_child(spr)
		refresh()

	func refresh() -> void:
		var k := hp / max_hp
		var f := 0 if k >= 0.7 else (1 if k >= 0.4 else 2)
		if f != frame:
			frame = f
			spr.texture = K.tex("barricade_%d" % f)
			cast.texture = spr.texture
		mat.set_shader_parameter("flash", clampf(hit / 0.1, 0.0, 1.0) * 0.7)

	func tick(dt: float) -> void:
		hit = maxf(0.0, hit - dt)
		refresh()

class Crate extends Node2D:
	const K = preload("res://scripts/k.gd")
	const FLASH = preload("res://shaders/flash.gdshader")
	var hp := 4.0
	var x := 0.0
	var cz := 0.5
	var hit := 0.0
	var dead := false
	var spr: Sprite2D
	var mat: ShaderMaterial

	func _ready() -> void:
		z_index = int(cz * 100.0)
		position = Vector2(x, K.zy(cz))
		var sh := Sprite2D.new()
		sh.texture = K.shadow_tex()
		var s := K.zscale(cz) * 80.0
		sh.scale = Vector2(s * 1.2 / 256.0, s * 0.2 / 256.0)
		sh.light_mask = 0
		add_child(sh)
		var cs := K.make_shadow(Vector2(-160, -260), s / 200.0, 0.55)
		cs.texture = K.tex("crate_raw")
		add_child(cs)
		spr = Sprite2D.new()
		spr.centered = false
		spr.texture = K.tex("crate_raw")
		spr.offset = Vector2(-160, -260)
		spr.scale = Vector2.ONE * (s / 200.0)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		mat = ShaderMaterial.new()
		mat.shader = FLASH
		spr.material = mat
		add_child(spr)

	func tick(dt: float) -> void:
		hit = maxf(0.0, hit - dt)
		mat.set_shader_parameter("flash", clampf(hit / 0.1, 0.0, 1.0))

class Pickup extends Node2D:
	const K = preload("res://scripts/k.gd")
	var kind := "H"
	var base := Vector2.ZERO
	var life := 10.0
	var t := 0.0
	var dead := false
	var spr: Sprite2D
	var halo: Sprite2D
	var gshadow: Sprite2D

	func _ready() -> void:
		z_index = 120
		gshadow = Sprite2D.new()
		gshadow.texture = K.shadow_tex()
		gshadow.scale = Vector2(0.2, 0.06)
		gshadow.light_mask = 0
		add_child(gshadow)
		halo = Sprite2D.new()
		halo.texture = K.glow_tex()
		halo.material = K.additive()
		halo.scale = Vector2.ONE * 0.45
		halo.modulate = Color(1, 1, 1, 0.5)
		add_child(halo)
		spr = Sprite2D.new()
		spr.texture = K.tex("pickup_%s" % kind)
		spr.scale = Vector2(0.5, 0.5)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		add_child(spr)
		tick(0.0)

	func tick(dt: float) -> void:
		life -= dt
		t += dt
		var bob := sin(t * 4.0) * 5.0
		position = base + Vector2(0, -34.0 + bob)
		if gshadow:
			gshadow.position = Vector2(0, 34.0 - bob)
			gshadow.scale = Vector2(0.2, 0.06) * (1.0 - bob * 0.02)
		var a := 1.0
		if life < 3.0:
			a = 1.0 if sin(t * 20.0) > 0.0 else 0.3
		modulate.a = a
		halo.scale = Vector2.ONE * (0.42 + sin(t * 5.0) * 0.05)
