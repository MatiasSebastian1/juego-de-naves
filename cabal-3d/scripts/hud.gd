extends Control
# Interfaz 2D (se dibuja con _draw sobre el 3D): vida, municion, granadas, oleada, puntaje, combo, mira dinamica,
# hitmarker, indicadores de direccion de dano, aviso de granadas, barra de jefe, banners y pantallas.

const BTN_RESUME := Rect2(490, 232, 300, 50)
const BTN_RESTART := Rect2(490, 294, 300, 50)
const BTN_MUTE := Rect2(490, 356, 300, 50)
const BTN_MENU := Rect2(490, 418, 300, 50)
const VOL_BAR := Rect2(490, 520, 300, 14)
const FONT_PATH := "res://assets/third_party/kenney/fonts/Kenney Future.ttf"

var game
var font: Font
var panel_sb: StyleBoxFlat
var ui_t := 0.0

func _ready() -> void:
	var sysf := SystemFont.new()
	sysf.font_names = PackedStringArray(["Impact", "Arial Black", "Segoe UI", "Roboto", "DejaVu Sans", "sans-serif"])
	sysf.font_weight = 800
	sysf.fallbacks = [ThemeDB.fallback_font]
	font = sysf
	if ResourceLoader.exists(FONT_PATH):
		var ff = load(FONT_PATH)
		if ff is Font:
			ff.fallbacks = [sysf]
			font = ff
	panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.04, 0.04, 0.07, 0.62)
	panel_sb.set_corner_radius_all(10)
	panel_sb.set_border_width_all(2)
	panel_sb.border_color = Color(1, 1, 1, 0.14)

func _process(delta: float) -> void:
	ui_t += delta
	queue_redraw()

func _t(s: String, x: float, y: float, size: int, col := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := 1200.0
	var px := x - w / 2.0
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		px = x
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		px = x - w
	draw_string_outline(font, Vector2(px, y), s, align, w, size, maxi(3, size / 8), Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(px, y), s, align, w, size, col)

func _panel(r: Rect2) -> void:
	draw_style_box(panel_sb, r)

func _bar(r: Rect2, pct: float, c0: Color, c1: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.1))
	var w := r.size.x * clampf(pct, 0.0, 1.0)
	if w < 1.0:
		return
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(w, 0), r.position + Vector2(w, r.size.y), r.position + Vector2(0, r.size.y)]), PackedColorArray([c0, c1, c1, c0]))
	draw_rect(Rect2(r.position, Vector2(w, r.size.y * 0.4)), Color(1, 1, 1, 0.14))

func _draw() -> void:
	if game == null or game.player == null:
		return
	var p = game.player
	if game.state == "play" or game.state == "pause":
		_hud(p)
	_screens()
	if game.state == "play":
		_crosshair(p)

func _hud(p) -> void:
	# vida y granadas
	_panel(Rect2(20, 18, 316, 92))
	var pct: float = p.hp / p.max_hp
	_bar(Rect2(34, 30, 288, 20), pct, Color(0.91, 0.27, 0.24), Color(0.3, 0.85, 0.39) if pct > 0.35 else Color(1.0, 0.62, 0.26))
	_t("VIDA %d" % ceili(p.hp), 42, 46, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	for i in mini(8, p.gren):
		var c := Vector2(48 + i * 26, 76)
		draw_circle(c, 9.0, Color(1.0, 0.62, 0.26))
		draw_arc(c, 9.0, 0.0, TAU, 16, Color.BLACK, 2.0)
		draw_rect(Rect2(c.x - 3, c.y - 13, 6, 5), Color(0.8, 0.8, 0.85))
	if p.gren == 0:
		_t("SIN GRANADAS  (G)", 42, 82, 13, Color(0.6, 0.6, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	if p.in_cover:
		_panel(Rect2(20, 118, 190, 30))
		_t("EN COBERTURA", 115, 140, 13, Color(0.5, 0.9, 1.0))
	# puntaje
	_panel(Rect2(944, 18, 316, 78))
	_t(str(game.score).pad_zeros(7), 1244, 58, 36, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_t("RECORD %d" % game.hiscore, 1244, 84, 13, Color(0.6, 0.67, 0.73), HORIZONTAL_ALIGNMENT_RIGHT)
	_t("OLEADA %d / %d" % [maxi(game.wave, 1), game.MAX_WAVE], 640, 30, 17, Color(0.85, 0.9, 0.95))
	if game.wave > 0:
		_t("QUEDAN %d" % (game.alive_count() + game.queue.size()), 640, 52, 12, Color(0.7, 0.76, 0.84))
	if game.mult() > 1:
		_t("COMBO x%d" % game.mult(), 640, 84, 26, Color(1.0, 0.83, 0.42))
	elif game.streak > 1:
		_t("RACHA %d" % game.streak, 640, 82, 16, Color(0.85, 0.85, 0.9))
	# municion
	_panel(Rect2(1010, 596, 250, 104))
	if p.weapon == "rifle":
		var low: bool = p.ammo <= 8
		_t(str(p.ammo).pad_zeros(2), 1148, 662, 54, Color(1.0, 0.4, 0.3) if low else Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		_t("/ %d" % p.reserve, 1246, 662, 24, Color(0.75, 0.8, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	else:
		_t("INF", 1148, 662, 54, Color(0.4, 0.85, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_t(p.WEAPONS[p.weapon].name, 1026, 622, 15, Color(0.75, 0.82, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	if p.reloading:
		var k: float = 1.0 - p.reload_t / p.RELOAD_TIME
		_bar(Rect2(1026, 684, 218, 8), k, Color(1.0, 0.8, 0.3), Color(1.0, 0.8, 0.3))
		_t("RECARGANDO", 1244, 622, 13, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
	elif p.weapon == "rifle" and p.ammo == 0 and p.reserve == 0:
		_t("SIN MUNICION", 1135, 692, 15, Color(1.0, 0.4, 0.3))
	if p.wtime > 0.0:
		_panel(Rect2(1010, 560, 250, 30))
		_bar(Rect2(1018, 580, 234, 5), p.wtime / 22.0, Color(0.31, 0.76, 1.0), Color(0.31, 0.76, 1.0))
		_t("%s  %ds" % [p.WEAPONS[p.weapon].name, ceili(p.wtime)], 1135, 576, 13, Color(0.31, 0.76, 1.0))
	# esquiva
	var ready: bool = p.roll_cd <= 0.0
	var k2: float = 1.0 if ready else 1.0 - p.roll_cd / p.ROLL_CD
	_panel(Rect2(20, 660, 214, 42))
	_t("RODAR (ESPACIO)", 32, 686, 12, Color(0.8, 0.87, 0.93), HORIZONTAL_ALIGNMENT_LEFT)
	_bar(Rect2(32, 692, 190, 5), k2, Color(0.5, 0.9, 1.0), Color(0.5, 0.9, 1.0) if ready else Color(0.45, 0.62, 0.7))
	if game.state == "play":
		_indicators(p)
	if pct < 0.3 and game.state == "play":
		var a := 0.08 + (0.5 + sin(game.time * 7.0) * 0.5) * 0.14
		draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.1, 0.1, a), false, 14.0)
		_t("VIDA BAJA", 640, 704, 16, Color(1.0, 0.45, 0.4, 0.6 + a))
	# jefe
	for e in game.enemies:
		if is_instance_valid(e) and e.type == "boss" and not e.dying and game.state == "play":
			_t("JEFE", 640, 128, 16, Color(1.0, 0.45, 0.9))
			_bar(Rect2(390, 138, 500, 14), e.hp / e.max_hp, Color(0.8, 0.15, 0.7), Color(1.0, 0.4, 0.5))
			draw_rect(Rect2(390, 138, 500, 14), Color(1, 1, 1, 0.3), false, 2.0)
	if game.banner_t > 0.0 and game.state == "play" and game.banner_text != "":
		var a := clampf(game.banner_t, 0.0, 1.0)
		_t(game.banner_text, 640, 230, 58 if game.banner_text.length() < 22 else 42, Color(1.0, 0.83, 0.42, a))
	if game.toast_t > 0.0:
		_t(game.toast_text, 640, 600, 20, Color(0.8, 0.95, 1.0, clampf(game.toast_t * 2.0, 0.0, 1.0)))

# Direccion de dano recibido y aviso de granadas enemigas (flechas alrededor de la mira).
func _indicators(p) -> void:
	var c := Vector2(640, 360)
	var fwd := Vector3(-sin(p.yaw), 0, -cos(p.yaw))
	var right := Vector3(cos(p.yaw), 0, -sin(p.yaw))
	for d in game.dmg_ind:
		var v: Vector3 = d.pos - p.global_position
		v.y = 0.0
		if v.length() < 0.1:
			continue
		v = v.normalized()
		var a := atan2(right.dot(v), fwd.dot(v))
		var dir := Vector2(sin(a), -cos(a))
		var al := clampf(d.t / 1.4, 0.0, 1.0)
		var pts := PackedVector2Array([c + dir * 205.0, c + dir * 150.0 + dir.orthogonal() * 22.0, c + dir * 150.0 - dir.orthogonal() * 22.0])
		draw_colored_polygon(pts, Color(1.0, 0.15, 0.1, 0.85 * al))
	var danger := false
	for g in game.grenades:
		if not is_instance_valid(g) or g.by_player:
			continue
		var v: Vector3 = g.global_position - p.global_position
		v.y = 0.0
		var dist := v.length()
		if dist > 24.0:
			continue
		var a := atan2(right.dot(v.normalized()), fwd.dot(v.normalized()))
		var dir := Vector2(sin(a), -cos(a))
		var flash := 0.6 + 0.4 * sin(game.time * 16.0)
		var pos := c + dir * 185.0
		draw_circle(pos, 15.0, Color(1.0, 0.55, 0.1, 0.9 * flash))
		draw_arc(pos, 15.0, 0.0, TAU, 20, Color.BLACK, 2.5)
		draw_colored_polygon(PackedVector2Array([pos + dir * 30.0, pos + dir * 17.0 + dir.orthogonal() * 8.0, pos + dir * 17.0 - dir.orthogonal() * 8.0]), Color(1.0, 0.55, 0.1, flash))
		var td := Vector2(g.target.x - p.global_position.x, g.target.z - p.global_position.z).length()
		if td < g.radius + 1.0 and g.age < g.fuse:
			danger = true
	if danger:
		var flash2 := 0.55 + 0.45 * sin(game.time * 14.0)
		_t("GRANADA!  SALI DE AHI", 640, 190, 30, Color(1.0, 0.45, 0.2, flash2))

func _crosshair(p) -> void:
	var c := Vector2(640, 360)
	var fov_half := tan(deg_to_rad(p.camera.fov * 0.5))
	var sp_px := tan(deg_to_rad(p.current_spread())) / fov_half * 360.0
	var gap := clampf(sp_px, 6.0, 90.0)
	var over: bool = p.aim_over_enemy
	var col := Color(1.0, 0.35, 0.3) if over else Color(0.55, 1.0, 0.85)
	if p.dead:
		col.a = 0.0
	var glow := Color(col.r, col.g, col.b, 0.22)
	for pass_i in 2:
		var w := 5.0 if pass_i == 0 else 2.2
		var cc := glow if pass_i == 0 else col
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_line(c + d * gap, c + d * (gap + 11.0), cc, w)
	draw_circle(c, 2.0, Color(1.0, 0.3, 0.3, col.a))
	# hitmarker
	if game.hit_t > 0.0:
		var a: float = clampf(game.hit_t / 0.2, 0.0, 1.0)
		var hc := Color(1, 1, 1, a)
		if game.hit_head:
			hc = Color(1.0, 0.25, 0.2, a)
		elif game.hit_kill:
			hc = Color(1.0, 0.85, 0.3, a)
		var r0 := 8.0 + (1.0 - a) * 6.0
		var r1 := r0 + 9.0
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dn: Vector2 = d.normalized()
			draw_line(c + dn * r0, c + dn * r1, Color(0, 0, 0, a * 0.7), 5.0)
			draw_line(c + dn * r0, c + dn * r1, hc, 2.6)
	if game.head_t > 0.0:
		_t("HEADSHOT", 640, 308, 22, Color(1.0, 0.3, 0.25, clampf(game.head_t * 2.0, 0.0, 1.0)))

func _screens() -> void:
	match game.state:
		"menu":
			draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(1280, 0), Vector2(1280, 720), Vector2(0, 720)]),
				PackedColorArray([Color(0.03, 0.02, 0.05, 0.12), Color(0.03, 0.02, 0.05, 0.12), Color(0.03, 0.02, 0.05, 0.82), Color(0.03, 0.02, 0.05, 0.82)]))
			var y := sin(game.time * 2.0) * 4.0
			for i in 4:
				draw_string_outline(font, Vector2(40, 170 + y), "CABAL 3D", HORIZONTAL_ALIGNMENT_CENTER, 1200.0, 104, 12 + i * 8, Color(1.0, 0.45, 0.12, 0.10 - i * 0.02))
			draw_string_outline(font, Vector2(40, 170 + y), "CABAL 3D", HORIZONTAL_ALIGNMENT_CENTER, 1200.0, 104, 12, Color(0.12, 0.03, 0.02, 0.95))
			draw_string(font, Vector2(40, 170 + y), "CABAL 3D", HORIZONTAL_ALIGNMENT_CENTER, 1200.0, 104, Color(1, 0.96, 0.9))
			_t("Sobreviví 15 oleadas en %s. Usá la cobertura." % ("la aldea" if game.level.meshy else "el patio"), 640, 232, 20, Color(0.95, 0.88, 0.8))
			var lines := ["WASD  ·  Mover          SHIFT  ·  Correr          MOUSE  ·  Apuntar", "CLICK IZQ  ·  Disparar          CLICK DER  ·  Apuntar de cerca", "R  ·  Recargar          G  ·  Granada          C / CTRL  ·  Agacharse", "ESPACIO  ·  Rodar (invulnerable) / saltar          P / ESC  ·  Pausa", "M  ·  Música          - / +  ·  Volumen          [ / ]  ·  Sensibilidad          F11  ·  Pantalla completa"]
			for i in lines.size():
				_t(lines[i], 640, 470 + i * 30, 16, Color(0.78, 0.82, 0.88))
			if game.hiscore > 0:
				_t("RECORD  %d" % game.hiscore, 640, 410, 22, Color(1.0, 0.83, 0.42))
			var pulse := 0.65 + 0.35 * sin(game.time * 4.0)
			_t("CLICK PARA EMPEZAR", 640, 664, 28, Color(1, 1, 1, 0.55 + 0.45 * pulse))
		"pause":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.025, 0.05, 0.6))
			_t("PAUSA", 640, 190, 76)
			_button(BTN_RESUME, "CONTINUAR  (P)")
			_button(BTN_RESTART, "REINICIAR  (R)")
			_button(BTN_MUTE, "MÚSICA: NO  (M)" if game.sfx.muted else "MÚSICA: SÍ  (M)")
			_button(BTN_MENU, "AL MENÚ  [Q]")
			var lv: float = 0.0 if game.sfx.muted else game.sfx.level
			_t("VOLUMEN  %d%%     ( -  /  + )" % int(round(game.sfx.level * 100.0)), 640, 506, 16, Color(0.75, 0.85, 0.93))
			_bar(VOL_BAR, lv, Color(0.3, 0.7, 1.0), Color(0.5, 0.9, 1.0))
			_t("Puntaje %d   ·   Oleada %d" % [game.score, game.wave], 640, 600, 22, Color(0.87, 0.9, 0.94))
		"over":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.0, 0.0, 0.64) if not game.victory else Color(0.0, 0.06, 0.1, 0.64))
			_t("VICTORIA" if game.victory else "GAME OVER", 640, 130, 92, Color(0.5, 1.0, 0.7) if game.victory else Color(1.0, 0.35, 0.3))
			var rec: bool = game.rank_idx == 0
			_t("NUEVO RECORD!  %d" % game.score if rec else "Puntaje  %d" % game.score, 640, 190, 34, Color(1.0, 0.83, 0.42) if rec else Color.WHITE)
			_panel(Rect2(200, 225, 420, 260))
			_t("RESUMEN", 410, 258, 20, Color(0.6, 0.75, 0.9))
			var secs := int(game.run_time)
			var st := [["Oleada alcanzada", str(game.wave)], ["Bajas", str(game.kills)], ["Precisión", "%d%%" % game.accuracy()], ["Mejor combo", "%d bajas" % game.best_streak], ["Tiempo", "%d:%02d" % [secs / 60, secs % 60]]]
			for i in st.size():
				_t(st[i][0], 226, 306 + i * 36, 19, Color(0.8, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
				_t(st[i][1], 594, 306 + i * 36, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
			_panel(Rect2(660, 225, 420, 260))
			_t("TOP 5", 870, 258, 20, Color(0.6, 0.75, 0.9))
			for i in 5:
				var col := Color(1.0, 0.83, 0.42) if i == game.rank_idx else Color(0.8, 0.85, 0.9)
				if i < game.top.size():
					var e: Dictionary = game.top[i]
					_t("%d." % (i + 1), 686, 306 + i * 36, 19, col, HORIZONTAL_ALIGNMENT_LEFT)
					_t(str(e["score"]), 750, 306 + i * 36, 21, col, HORIZONTAL_ALIGNMENT_LEFT)
					_t(("Ol. %d" % e["wave"]) if e["wave"] > 0 else "", 1054, 306 + i * 36, 17, col, HORIZONTAL_ALIGNMENT_RIGHT)
				else:
					_t("%d.  ---" % (i + 1), 686, 306 + i * 36, 19, Color(0.5, 0.55, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
			if game.over_t > game.OVER_LOCK and int(game.time * 2.0) % 2 == 0:
				_t("CLICK o ENTER para reintentar", 640, 560, 28)

func _button(r: Rect2, label: String) -> void:
	var hot: bool = r.has_point(get_viewport().get_mouse_position())
	draw_rect(r, Color(0.15, 0.3, 0.42, 0.88) if hot else Color(0.03, 0.04, 0.06, 0.78))
	draw_rect(r, Color(0.5, 0.9, 1.0, 0.9) if hot else Color(1, 1, 1, 0.22), false, 2.0)
	_t(label, r.position.x + r.size.x / 2.0, r.position.y + 33.0, 22)
