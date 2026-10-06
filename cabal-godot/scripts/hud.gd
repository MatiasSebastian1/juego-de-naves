extends Control
# Interfaz: HUD, pantallas de menu/pausa/game over, barra del jefe y mira.

var game
var font: Font
var panel_sb: StyleBoxFlat

func _ready() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Impact", "Arial Black", "Segoe UI", "Roboto", "DejaVu Sans", "sans-serif"])
	f.font_weight = 800
	f.fallbacks = [ThemeDB.fallback_font]
	font = f
	panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.03, 0.04, 0.06, 0.66)
	panel_sb.set_corner_radius_all(12)
	panel_sb.set_border_width_all(2)
	panel_sb.border_color = Color(1, 1, 1, 0.14)

func _t(s: String, x: float, y: float, size: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := 1200.0
	var px := x - w / 2.0
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		px = x
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		px = x - w
	draw_string_outline(font, Vector2(px, y), s, align, w, size, maxi(4, size / 5), Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(px, y), s, align, w, size, col)

func _panel(r: Rect2) -> void:
	draw_style_box(panel_sb, r)

func _bar(r: Rect2, pct: float, c0: Color, c1: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.09))
	var w := r.size.x * clampf(pct, 0.0, 1.0)
	if w < 1.0:
		return
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w, r.size.y), r.position + Vector2(0, r.size.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_rect(Rect2(r.position, Vector2(w, r.size.y * 0.4)), Color(1, 1, 1, 0.14))

func _draw() -> void:
	if game == null:
		return
	var p = game.player
	if game.state != "menu":
		_hud(p)
	_screens()
	_crosshair()

func _hud(p) -> void:
	_panel(Rect2(20, 18, 300, 78))
	var pct: float = p.hp / p.max_hp
	_bar(Rect2(34, 30, 272, 18), pct, Color(0.91, 0.27, 0.24), Color(0.3, 0.85, 0.39) if pct > 0.35 else Color(1.0, 0.62, 0.26))
	_t("VIDA %d" % ceili(p.hp), 40, 45, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	for i in mini(9, p.gren):
		draw_circle(Vector2(46 + i * 24, 72), 8.0, Color(1.0, 0.62, 0.26))
		draw_arc(Vector2(46 + i * 24, 72), 8.0, 0.0, TAU, 16, Color.BLACK, 2.0)
	if p.gren == 0:
		_t("SIN GRANADAS", 36, 78, 14, Color(0.55, 0.55, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
	_panel(Rect2(960, 18, 300, 78))
	_t(str(game.score).pad_zeros(7), 1246, 56, 36, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_t("RÉCORD %d" % game.hiscore, 1246, 82, 14, Color(0.6, 0.67, 0.73), HORIZONTAL_ALIGNMENT_RIGHT)
	_t("OLEADA %d" % game.wave, 640, 28, 16, Color(0.8, 0.87, 0.93))
	if game.mult() > 1:
		_t("COMBO x%d" % game.mult(), 640, 60, 30, Color(1.0, 0.83, 0.42))
	if p.wt > 0.0:
		_panel(Rect2(20, 106, 170, 32))
		_t("%s %ds" % ["ESCOPETA" if p.weapon == "spread" else "RÁFAGA", int(p.wt)], 105, 129, 16, Color(0.31, 0.76, 1.0))
	if p.roll_cd > 0.0:
		var sp: Vector2 = p.position - game.cam.offset
		draw_rect(Rect2(sp.x - 30, sp.y + 14, 60, 4), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(sp.x - 30, sp.y + 14, 60.0 * (1.0 - p.roll_cd / 0.95), 4), Color(0.5, 0.9, 1.0))
	for e in game.enemies:
		if e.type == "boss" and not e.dying:
			_t("JEFE", 640, 132, 16, Color(1.0, 0.45, 0.4))
			_bar(Rect2(390, 140, 500, 14), e.hp / e.max_hp, Color(0.9, 0.2, 0.2), Color(1.0, 0.45, 0.25))
	if game.banner_t > 0.0:
		var a := clampf(game.banner_t, 0.0, 1.0)
		_t(game.banner_text, 640, 220, 64, Color(1.0, 0.83, 0.42, a))

func _screens() -> void:
	match game.state:
		"menu":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.025, 0.05, 0.55))
			var y := sin(game.time * 2.0) * 6.0
			_t("CABAL", 640, 200 + y, 140, Color(1.0, 0.7, 0.28))
			_t("H D", 640, 270 + y, 54, Color(1.0, 0.35, 0.23))
			_t("Resistí las oleadas, usá las barricadas y volá a los jefes.", 640, 340, 22, Color(0.87, 0.9, 0.94))
			var lines := ["WASD / Flechas  ·  Moverte", "Mouse  ·  Apuntar          Click  ·  Disparar", "Click derecho / G  ·  Granada          Espacio  ·  Esquivar (invulnerable)", "Disparale a las balas grandes para destruirlas  ·  Tiros a la cabeza = x2", "P  ·  Pausa          F11  ·  Pantalla completa"]
			for i in lines.size():
				_t(lines[i], 640, 400 + i * 32, 19, Color(0.73, 0.78, 0.85))
			if int(game.time * 2.0) % 2 == 0:
				_t("HACÉ CLICK PARA EMPEZAR", 640, 620, 34)
		"pause":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.025, 0.05, 0.6))
			_t("PAUSA", 640, 360, 80)
			_t("P para continuar", 640, 410, 22, Color(0.75, 0.85, 0.93))
		"over":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.0, 0.0, 0.55))
			_t("GAME OVER", 640, 270, 110, Color(1.0, 0.35, 0.3))
			_t("Puntaje %d   ·   Oleada %d" % [game.score, game.wave], 640, 340, 32)
			_t("¡NUEVO RÉCORD!" if (game.score >= game.hiscore and game.score > 0) else "Récord %d" % game.hiscore, 640, 385, 24, Color(1.0, 0.83, 0.42))
			if int(game.time * 2.0) % 2 == 0:
				_t("CLICK o ENTER para reintentar", 640, 470, 30)

func _crosshair() -> void:
	var m: Vector2 = game.mouse
	var firing: bool = game.player.flash > 0.0
	var gap := 10.0 + (6.0 if firing else 0.0)
	var col := Color(0.5, 1.0, 0.83) if game.state == "play" else Color.WHITE
	var glow := Color(col.r, col.g, col.b, 0.22)
	for pass_i in 2:
		var w := 6.0 if pass_i == 0 else 2.5
		var c := glow if pass_i == 0 else col
		draw_arc(m, 18.0, 0.0, TAU, 40, c, w)
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(m + d * gap, m + d * (gap + 14.0), c, w)
	draw_circle(m, 2.5, Color(1.0, 0.3, 0.3))
