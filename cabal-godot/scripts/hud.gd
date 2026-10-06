extends Control
# Interfaz: HUD, pantallas de menu/pausa/game over, barra del jefe y mira.

# Zonas clicables del menu de pausa (game.gd las usa para procesar los clicks)
const BTN_RESUME := Rect2(490, 290, 300, 50)
const BTN_RESTART := Rect2(490, 352, 300, 50)
const BTN_MUTE := Rect2(490, 414, 300, 50)
const VOL_BAR := Rect2(490, 524, 300, 14)

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
	_dodge(p)
	_warnings(p)
	if pct < 0.3 and game.state == "play":
		# vida baja: marco rojo que late
		var a := 0.10 + (0.5 + sin(game.time * 7.0) * 0.5) * 0.16
		draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.1, 0.1, a), false, 16.0)
		_t("VIDA BAJA", 640, 700, 18, Color(1.0, 0.45, 0.4, 0.6 + a))
	for e in game.enemies:
		if e.type == "boss" and not e.dying and game.state != "over":
			_t("JEFE", 640, 132, 16, Color(1.0, 0.45, 0.4))
			_bar(Rect2(390, 140, 500, 14), e.hp / e.max_hp, Color(0.9, 0.2, 0.2), Color(1.0, 0.45, 0.25))
	if game.banner_t > 0.0 and game.state != "over":
		var a := clampf(game.banner_t, 0.0, 1.0)
		_t(game.banner_text, 640, 220, 64 if game.banner_text.length() < 26 else 46, Color(1.0, 0.83, 0.42, a))
	if game.toast_t > 0.0:
		_t(game.toast_text, 640, 690, 20, Color(0.8, 0.95, 1.0, clampf(game.toast_t * 2.0, 0.0, 1.0)))

# Indicador de esquiva: barra bajo el soldado mientras recarga, y panel fijo abajo a la izquierda.
func _dodge(p) -> void:
	var ready: bool = p.roll_cd <= 0.0
	var k: float = 1.0 if ready else 1.0 - p.roll_cd / p.ROLL_CD
	if not ready:
		var sp: Vector2 = p.position - game.cam.offset
		draw_rect(Rect2(sp.x - 30, sp.y + 14, 60, 4), Color(1, 1, 1, 0.15))
		draw_rect(Rect2(sp.x - 30, sp.y + 14, 60.0 * k, 4), Color(0.5, 0.9, 1.0))
	var pulse: float = clampf(p.roll_ready_t / 0.35, 0.0, 1.0)
	_panel(Rect2(20, 664, 178, 40))
	_t("ESQUIVAR", 32, 689, 13, Color(0.8, 0.87, 0.93), HORIZONTAL_ALIGNMENT_LEFT)
	var col := Color(0.5, 0.9, 1.0).lerp(Color.WHITE, pulse) if ready else Color(0.45, 0.62, 0.7)
	_bar(Rect2(112, 678, 74, 12), k, col, col)
	if pulse > 0.0:
		draw_rect(Rect2(110, 676, 78, 16), Color(0.7, 1.0, 1.0, pulse * 0.7), false, 2.0)

# Avisos de peligro: circulo en el punto de impacto de balas dirigidas al jugador, "!" sobre su cabeza
# cuando un impacto es inminente y flecha bajo los corredores que se acercan.
func _warnings(p) -> void:
	var off: Vector2 = game.cam.offset
	var c: Vector2 = Vector2(p.position.x, p.position.y - 50.0)
	var soon := 99.0
	for b in game.shells:
		if b.dead or b.own != "e":
			continue
		if b.kind == "b":
			var d: float = b.tgt.distance_to(c)
			if d < 95.0 and b.t > 0.2:
				var left: float = (1.0 - b.t) * b.dur
				soon = minf(soon, left)
				var r := 16.0 + left * 26.0
				draw_arc(b.tgt - off, r, 0.0, TAU, 20, Color(1.0, 0.3, 0.2, 0.85), 2.5)
		else:
			var dx: float = (p.position.x - b.tgt.x) / (b.rx * 1.25)
			var dy: float = (p.position.y - b.tgt.y) / (b.ry * 1.25)
			if dx * dx + dy * dy < 1.0:
				soon = minf(soon, (1.0 - b.t) * b.dur)
	if soon < 0.8 and game.state == "play":
		var sp: Vector2 = Vector2(p.position.x, p.position.y - 170.0) - off
		var a := 0.55 + sin(game.time * 24.0) * 0.4
		_t("!", sp.x, sp.y, 44, Color(1.0, 0.3, 0.2, a))
	for e in game.enemies:
		if e.type == "runner" and not e.dying and e.z > 0.45:
			var x: float = clampf(e.x - off.x, 30.0, 1250.0)
			var a := 0.5 + sin(game.time * 16.0) * 0.4
			var y := 712.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 14, y), Vector2(x + 14, y), Vector2(x, y - 22)]), Color(1.0, 0.25, 0.2, a))

func _screens() -> void:
	match game.state:
		"menu":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.025, 0.05, 0.55))
			var y := sin(game.time * 2.0) * 6.0
			_t("CABAL", 640, 200 + y, 140, Color(1.0, 0.7, 0.28))
			_t("H D", 640, 270 + y, 54, Color(1.0, 0.35, 0.23))
			_t("Resistí las oleadas, usá las barricadas y volá a los jefes.", 640, 340, 22, Color(0.87, 0.9, 0.94))
			var lines := ["WASD / Flechas  ·  Moverte", "Mouse  ·  Apuntar          Click  ·  Disparar", "Click derecho / G  ·  Granada          Espacio  ·  Esquivar (invulnerable)", "Disparale a las balas grandes para destruirlas  ·  Tiros a la cabeza = x2", "P / Esc  ·  Pausa          M  ·  Música          - / +  ·  Volumen          F11  ·  Pantalla completa"]
			for i in lines.size():
				_t(lines[i], 640, 400 + i * 32, 19, Color(0.73, 0.78, 0.85))
			if game.hiscore > 0:
				_t("RÉCORD  %d" % game.hiscore, 640, 580, 22, Color(1.0, 0.83, 0.42))
			if int(game.time * 2.0) % 2 == 0:
				_t("HACÉ CLICK PARA EMPEZAR", 640, 640, 34)
		"pause":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.025, 0.05, 0.62))
			_t("PAUSA", 640, 235, 80)
			_button(BTN_RESUME, "CONTINUAR  (P)")
			_button(BTN_RESTART, "REINICIAR  (R)")
			_button(BTN_MUTE, "MÚSICA: NO  (M)" if game.sfx.muted else "MÚSICA: SÍ  (M)")
			var lv: float = 0.0 if game.sfx.muted else game.sfx.level
			_t("VOLUMEN  %d%%     ( -  /  + )" % int(round(game.sfx.level * 100.0)), 640, 512, 18, Color(0.75, 0.85, 0.93))
			_bar(VOL_BAR, lv, Color(0.3, 0.7, 1.0), Color(0.5, 0.9, 1.0))
			_t("Puntaje %d   ·   Oleada %d" % [game.score, game.wave], 640, 600, 22, Color(0.87, 0.9, 0.94))
		"over":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.08, 0.0, 0.0, 0.62))
			_t("GAME OVER", 640, 140, 96, Color(1.0, 0.35, 0.3))
			var rec: bool = game.rank_idx == 0
			_t("¡NUEVO RÉCORD!  %d" % game.score if rec else "Puntaje  %d" % game.score, 640, 195, 34, Color(1.0, 0.83, 0.42) if rec else Color.WHITE)
			# estadisticas de la partida
			_panel(Rect2(210, 225, 400, 250))
			_t("RESUMEN", 410, 258, 20, Color(0.6, 0.75, 0.9))
			var secs := int(game.run_time)
			var st := [["Oleada alcanzada", str(game.wave)], ["Bajas", str(game.kills)], ["Precisión", "%d%%" % game.accuracy()], ["Mejor combo", "%d bajas" % game.best_streak], ["Tiempo", "%d:%02d" % [secs / 60, secs % 60]]]
			for i in st.size():
				_t(st[i][0], 236, 304 + i * 36, 20, Color(0.8, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
				_t(st[i][1], 584, 304 + i * 36, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
			# ranking local
			_panel(Rect2(670, 225, 400, 250))
			_t("TOP 5", 870, 258, 20, Color(0.6, 0.75, 0.9))
			for i in 5:
				var col := Color(1.0, 0.83, 0.42) if i == game.rank_idx else Color(0.8, 0.85, 0.9)
				if i < game.top.size():
					var e: Dictionary = game.top[i]
					_t("%d." % (i + 1), 696, 304 + i * 36, 20, col, HORIZONTAL_ALIGNMENT_LEFT)
					_t(str(e["score"]), 800, 304 + i * 36, 22, col, HORIZONTAL_ALIGNMENT_LEFT)
					_t(("Ol. %d" % e["wave"]) if e["wave"] > 0 else "", 1044, 304 + i * 36, 18, col, HORIZONTAL_ALIGNMENT_RIGHT)
				else:
					_t("%d.  ---" % (i + 1), 696, 304 + i * 36, 20, Color(0.5, 0.55, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
			if game.over_t > game.OVER_LOCK and int(game.time * 2.0) % 2 == 0:
				_t("CLICK o ENTER para reintentar", 640, 550, 30)

func _button(r: Rect2, label: String) -> void:
	var hot: bool = r.has_point(game.mouse)
	draw_rect(r, Color(0.15, 0.3, 0.42, 0.85) if hot else Color(0.03, 0.04, 0.06, 0.75))
	draw_rect(r, Color(0.5, 0.9, 1.0, 0.9) if hot else Color(1, 1, 1, 0.2), false, 2.0)
	_t(label, r.position.x + r.size.x / 2.0, r.position.y + 34.0, 24)

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
