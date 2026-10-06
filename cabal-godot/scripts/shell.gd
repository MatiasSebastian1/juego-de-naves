extends Node2D
# Proyectil enemigo ("b") o granada ("g", enemiga o del jugador).  La logica vive en game.gd.

const K = preload("res://scripts/k.gd")

var kind := "b"
var own := "e"
var p0 := Vector2.ZERO
var tgt := Vector2.ZERO
var cur := Vector2.ZERO
var prev := Vector2.ZERO
var t := 0.0
var dur := 1.0
var z := 0.0
var dmg := 8.0
var rx := 130.0
var ry := 46.0
var dead := false
var marker: Node2D
var trail: Array = []   # ultimas posiciones (para la estela luminosa de las balas)

class Marker extends Node2D:
	var rx := 130.0
	var ry := 46.0
	var enemy := true
	var tm := 0.0
	func _process(dt: float) -> void:
		tm += dt
		queue_redraw()
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, ry / rx))
		var pulse := 0.5 + sin(tm * 18.0) * 0.25
		if enemy:
			draw_circle(Vector2.ZERO, rx, Color(1.0, 0.24, 0.16, 0.10 + pulse * 0.2))
		var col := Color(1.0, 0.27, 0.2, 0.85 if enemy else 0.5)
		var segs := 28
		for i in segs:
			var a0 := TAU * (float(i) + tm * 0.4) / segs
			var a1 := a0 + TAU / segs * 0.55
			draw_arc(Vector2.ZERO, rx, a0, a1, 6, col, 4.0)

func _ready() -> void:
	if kind == "b":
		z_index = 150
		material = K.additive()
	else:
		z_index = 151
		marker = Marker.new()
		marker.rx = rx
		marker.ry = ry
		marker.enemy = (own == "e")
		marker.top_level = true
		marker.position = tgt
		marker.z_index = 5
		add_child(marker)
	position = cur

func refresh() -> void:
	if kind == "b":
		trail.push_front(cur)
		if trail.size() > 7:
			trail.pop_back()
	position = cur
	queue_redraw()

func _draw() -> void:
	if kind == "b":
		var s := 3.0 + t * 11.0
		# estela: segmentos que se afinan y se apagan hacia atras, mas el rastro lineal original
		var last := Vector2.ZERO
		for i in trail.size():
			var q: Vector2 = trail[i] - position
			var k := 1.0 - float(i) / trail.size()
			if i > 0:
				draw_line(last, q, Color(1.0, 0.5 + 0.3 * k, 0.2, 0.55 * k), s * 0.9 * k)
			last = q
		draw_line(prev - position, Vector2.ZERO, Color(1.0, 0.59, 0.27, 0.7), s * 0.6)
		draw_texture_rect(K.glow_tex(), Rect2(-s * 3.0, -s * 3.0, s * 6.0, s * 6.0), false, Color(1.0, 0.43, 0.16, 0.9))
		draw_circle(Vector2.ZERO, s * 0.55, Color(1.0, 0.97, 0.85))
	else:
		var s := 7.0 + t * 7.0
		draw_circle(Vector2.ZERO, s, Color(0.145, 0.145, 0.17))
		draw_arc(Vector2.ZERO, s, 0.0, TAU, 20, Color(0.5, 0.9, 1.0) if own == "p" else Color(1.0, 0.42, 0.29), 2.5)
		draw_circle(Vector2(-s * 0.3, -s * 0.3), s * 0.3, Color(1, 1, 1, 0.3))
