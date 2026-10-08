extends SceneTree
# Contactos del rig de los personajes Meshy (jugador y zombi) con render real:
#   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 --fixed-fps 60 --path cabal-3d \
#       --script res://tests/rig_test.gd -- /ruta/salida [grupo]        (grupo: player | zombie | all)
# Genera rig_player.png / rig_zombie.png: cada celda es una pose (estado y vista indicados en CASES).
const Model = preload("res://scripts/model.gd")

var out := "/tmp"
var group := "all"
var fr := 0
var m
var piv: Node3D
var cam: Camera3D
var cells: Array = []
var ci := 0
var cur_cases: Array = []
var gname := ""
var queue: Array = []

# [etiqueta, funcion de preparacion (string), yaw de la camara (grados), cuadros de espera]
const PLAYER_CASES := [
	["idle", "idle", 35.0, 50], ["idle espalda", "idle", 200.0, 50],
	["apunta 3/4", "aim", 35.0, 50], ["apunta lado", "aim", 90.0, 50], ["apunta espalda", "aim", 190.0, 50],
	["apunta arriba", "aim_up", 90.0, 50], ["apunta abajo", "aim_down", 90.0, 50],
	["camina", "walk", 60.0, 50], ["corre", "run", 60.0, 50], ["corre apuntando", "run_aim", 35.0, 50],
	["agachado", "crouch", 60.0, 60], ["agachado apuntando", "crouch_aim", 60.0, 60],
	["manos cerca 1", "aim", 20.0, 40, 2.3, 1.2], ["manos cerca 2", "aim", 150.0, 40, 2.3, 1.2], ["manos cerca 3", "idle", 330.0, 40, 2.3, 1.1],
	["escopeta", "wd", 35.0, 40], ["rafaga", "we", 35.0, 40], ["rafaga lado", "we", 90.0, 40],
	["voltereta 0.15", "roll15", 90.0, 40], ["voltereta 0.4", "roll40", 90.0, 40], ["voltereta 0.65", "roll65", 90.0, 40], ["voltereta 0.9", "roll90", 90.0, 40], ["muerte 0.3s", "die", 90.0, 18], ["muerte 0.6s", "die", 90.0, 36], ["muerte 1.5s", "die", 90.0, 90],
]
const ZOMBIE_CASES := [
	["idle", "idle", 35.0, 50], ["camina", "walk", 35.0, 50], ["corre", "run", 35.0, 50], ["ataque", "attack", 35.0, 40], ["ataque2", "attack", 35.0, 70],
	["agachado", "crouch", 60.0, 60], ["muerte 0.3s", "die", 90.0, 18], ["muerte 1.5s", "die", 90.0, 90],
]

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	if a.size() > 1:
		group = a[1]
	if group != "zombie":
		queue.append("player")
	if group != "player":
		queue.append("zombie")

func _setup_scene() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	ground.mesh = pm
	var img := Image.create(16, 16, false, Image.FORMAT_RGB8)
	for x in 16:
		for y in 16:
			img.set_pixel(x, y, Color(0.62, 0.52, 0.38) if (x / 2 + y / 2) % 2 == 0 else Color(0.5, 0.42, 0.3))
	var gm := StandardMaterial3D.new()
	gm.albedo_texture = ImageTexture.create_from_image(img)
	gm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	gm.uv1_scale = Vector3(10, 10, 1)
	ground.material_override = gm
	root.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	sun.light_color = Color(1.0, 0.85, 0.65)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 230, 0)
	fill.light_color = Color(0.6, 0.7, 1.0)
	fill.light_energy = 0.45
	root.add_child(fill)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.55, 0.65)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.52, 0.5)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	root.add_child(we)
	cam = Camera3D.new()
	cam.fov = 40
	root.add_child(cam)
	cam.current = true

func _next_group() -> bool:
	if queue.is_empty():
		return false
	gname = queue.pop_front()
	cur_cases = PLAYER_CASES if gname == "player" else ZOMBIE_CASES
	cells.clear()
	ci = -1
	if m != null:
		m.queue_free()
	if piv != null:
		piv.queue_free()
	piv = Node3D.new()
	piv.position.y = 0.62
	root.add_child(piv)
	m = Model.new()
	piv.add_child(m)
	m.position.y = -0.62
	m.setup("player" if gname == "player" else "zombie", Color.WHITE, 0.12, 0.5)
	if gname == "player":
		m.give_weapon("blaster-a", 0.75)
	return true

func _prep(what: String) -> void:
	m.revive()
	m.gest = ""
	m.crouch = 0.0
	m.tuck = 0.0
	m.aim_k = 0.0
	m.base_emit = Color.BLACK
	m.rotation = Vector3.ZERO
	m.position = Vector3(0, -0.62, 0)
	piv.rotation = Vector3.ZERO
	if what.begins_with("roll"):
		m.play("run", 0.0, 1.6)
		m.tuck = 1.0
		piv.rotation.x = float(what.substr(4)) / 100.0 * TAU
	m.aim_world = Vector3(0, 0, 1)
	match what:
		"idle":
			m.play("idle", 0.0)
		"aim":
			m.play("idle", 0.0)
			m.aim_k = 1.0
		"wd":
			m.give_weapon("blaster-d", 0.85)
			m.play("idle", 0.0)
			m.aim_k = 1.0
		"we":
			m.give_weapon("blaster-e", 1.0)
			m.play("idle", 0.0)
			m.aim_k = 1.0
		"aim_up":
			m.play("idle", 0.0)
			m.aim_k = 1.0
			m.aim_world = Vector3(0, 0.55, 1).normalized()
		"aim_down":
			m.play("idle", 0.0)
			m.aim_k = 1.0
			m.aim_world = Vector3(0, -0.45, 1).normalized()
		"walk":
			m.play("walk", 0.0, 2.0)
		"run":
			m.play("run", 0.0, 1.4)
		"run_aim":
			m.play("run", 0.0, 1.4)
			m.aim_k = 1.0
		"crouch":
			m.play("idle", 0.0)
			m.crouch = 1.0
		"crouch_aim":
			m.play("idle", 0.0)
			m.crouch = 1.0
			m.aim_k = 1.0
		"tuck":
			m.play("run", 0.0)
			m.tuck = 1.0
			m.position.y = 0.0
		"die":
			m.play("run", 0.0)
			m.die(1.0)
		"attack":
			m.gesture("attack", 0.35, 1.0, 2.8)

var wait_left := 10

func _process(delta: float) -> bool:
	fr += 1
	if fr == 1:
		_setup_scene()
		_next_group()
		return false
	wait_left -= 1
	if wait_left > 0:
		return false
	if ci >= 0:
		cells.append(root.get_texture().get_image())
	ci += 1
	if ci >= cur_cases.size():
		_save()
		if not _next_group():
			quit()
			return false
		ci = 0
	var c: Array = cur_cases[ci]
	_prep(c[1])
	var y := deg_to_rad(float(c[2]))
	var dist := float(c[4]) if c.size() > 4 else 4.6
	var h := float(c[5]) if c.size() > 5 else 0.9
	var cp := Vector3(sin(y), 0.0, cos(y)) * dist + Vector3(0, h + 0.1, 0)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, h, 0) - cp, Vector3.UP), cp)
	wait_left = int(c[3]) + 3
	return false

func _save() -> void:
	var cols := 6
	var rows := (cells.size() + cols - 1) / cols
	var sheet := Image.create(300 * cols, 420 * rows, false, Image.FORMAT_RGB8)
	for i in cells.size():
		var c: Image = cells[i]
		c.convert(Image.FORMAT_RGB8)
		sheet.blit_rect(c, Rect2i(c.get_width() / 2 - 150, c.get_height() / 2 - 210, 300, 420), Vector2i((i % cols) * 300, (i / cols) * 420))
	sheet.save_png("%s/rig_%s.png" % [out, gname])
	print("guardado rig_", gname)
