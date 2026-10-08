extends Node3D
# Personajes de Meshy AI con Skeleton3D (rig estilo Mixamo de 28 huesos):
#   "player": el soldado (assets/meshy/character.glb + player_anims.res: idle, walk, run, shot)
#   "zombie": el zombi de todos los enemigos (assets/meshy/zombie.glb + zombie_anims.res: idle, walk, run, attack)
# El AnimationPlayer se avanza a mano (callback MANUAL) para poder poner encima poses procedurales en el mismo cuadro:
#   * jugador armado: torso/cabeza hacia el punto de mira, brazos con IK de 2 huesos hacia el arma (mano derecha en la
#     empunadura, izquierda en el guardamano) -> el arma cuelga de un BoneAttachment3D de la mano derecha;
#   * agacharse / cubrirse (cadera baja + piernas con IK para no deslizar los pies), voltereta (cuerpo encogido) y muerte
#     (rodillas que ceden + caida alrededor de los pies), todo procedural: Meshy solo entrego idle/walk/run/shot/attack.
# Las animaciones de Meshy no desplazan al personaje (el "root motion" se anulo en tools/build_anims.gd).

const Assets = preload("res://scripts/assets.gd")
const BLASTER_DIR := "res://assets/third_party/kenney/blasters/"

const KINDS := {
	"player": {"scene": "res://assets/meshy/character.glb", "anims": "res://assets/meshy/player_anims.res", "walk_ref": 1.7, "run_ref": 4.2},
	"zombie": {"scene": "res://assets/meshy/zombie.glb", "anims": "res://assets/meshy/zombie_anims.res", "walk_ref": 1.5, "run_ref": 3.4},
}
const HEIGHT := 1.8                                  # altura del personaje en metros (escala = HEIGHT / altura de la malla)
const BN := {
	"hips": "mixamorig_Hips", "spine": "mixamorig_Spine", "spine1": "mixamorig_Spine1", "spine2": "mixamorig_Spine2",
	"neck": "mixamorig_Neck", "head": "mixamorig_Head", "face": "headfront",
	"l_sh": "mixamorig_LeftShoulder", "l_arm": "mixamorig_LeftArm", "l_fore": "mixamorig_LeftForeArm", "l_hand": "mixamorig_LeftHand",
	"r_sh": "mixamorig_RightShoulder", "r_arm": "mixamorig_RightArm", "r_fore": "mixamorig_RightForeArm", "r_hand": "mixamorig_RightHand",
	"l_up": "mixamorig_LeftUpLeg", "l_leg": "mixamorig_LeftLeg", "l_foot": "mixamorig_LeftFoot",
	"r_up": "mixamorig_RightUpLeg", "r_leg": "mixamorig_RightLeg", "r_foot": "mixamorig_RightFoot",
}

# --- ajuste del agarre del arma (en el espacio del esqueleto: +Z adelante, +Y arriba, +X izquierda del personaje)
const GRIP_PALM := Vector3(0.0, 0.085, 0.0)           # de la muneca al centro de la palma (eje del hueso de la mano)
const GRIP_ROLL := -90.0                              # giro de la mano derecha alrededor de los dedos (palma hacia la izquierda)
const GRIP_FINGERS := Vector3(0.0, -0.75, 0.66)       # direccion de los dedos de la mano derecha en el espacio del arma
const SUPPORT_POS := Vector3(0.02, -0.06, 0.22)      # donde apoya la mano izquierda (espacio del arma, antes de escalar)
const SUPPORT_ROLL := 0.0
const READY_DIR := Vector3(0.0, -0.30, 1.0)           # arma "en descanso" (de paseo), baja y hacia adelante
const AIM_OFFSET := Vector3(0.04, -0.15, 0.30)        # empunadura al apuntar, respecto del hombro derecho (espacio del arma)
const READY_OFFSET := Vector3(-0.08, -0.36, 0.28)     # empunadura en descanso, respecto de spine2

var kind := "player"
var body: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var mats: Array = []
var bi := {}                       # nombre corto -> indice de hueso
var unit := 1.0
var gp: Array = []                 # poses globales (espacio del esqueleto) calculadas a mano en _fk()
var rest_g: Array = []
var cur := ""
var gest := ""                     # gesto en curso (bloquea la locomocion)
var gest_end := 0.0
var dwell := 0.0
var flash_t := 0.0
var glow := 0.0                    # brillo de aviso (telegrafo)
var glow_col := Color(1.0, 0.2, 0.1)
var base_emit := Color.BLACK
var alpha := 1.0
var walk_ref := 1.7
var run_ref := 4.2
var speed_var := 1.0               # variacion de velocidad de animacion por individuo
var lod := 1                       # 1 = cada cuadro; N = cada N cuadros (enemigos lejanos)
var _acc := 0.0
var _frame := 0
var _phase := 0
# pose procedural (la fijan player.gd / enemy.gd)
var crouch := 0.0                  # 0..1 agachado
var tuck := 0.0                    # 0..1 encogido (voltereta)
var armed := false                 # IK de brazos con el arma (solo el jugador)
var aim_k := 0.0                   # 0 = arma en descanso, 1 = apuntando
var aim_world := Vector3.FORWARD   # direccion del arma (mundo)
var dying := false
var die_t := 0.0
var die_side := 0.0
var collapse := 0.0
# arma
var weapon_holder: Node3D
var weapon: Node3D
var muzzle: Marker3D
var r_attach: BoneAttachment3D
var face_attach: BoneAttachment3D
var weapon_len := 1.0
var weapon_kick := 0.0
var weapon_z := 0.0
var grip_g := Basis.IDENTITY       # rotacion del soporte del arma respecto del hueso de la mano
var grip_pos_w := Vector3.ZERO

func setup(k: String, tint := Color.WHITE, rim := 0.35, rim_tint := 0.6) -> void:
	kind = k
	var d: Dictionary = KINDS[k]
	walk_ref = d.walk_ref
	run_ref = d.run_ref
	body = Assets.inst(d.scene)
	add_child(body)
	skel = body.find_children("*", "Skeleton3D", true, false)[0]
	var mh := 1.75
	for m in body.find_children("*", "MeshInstance3D", true, false):
		mh = (m as MeshInstance3D).get_aabb().size.y
	unit = HEIGHT / mh
	body.scale = Vector3.ONE * unit
	for key in BN:
		bi[key] = skel.find_bone(BN[key])
	mats = _make_mats(tint, rim, rim_tint)
	anim = AnimationPlayer.new()
	body.add_child(anim)
	anim.callback_mode_process = AnimationPlayer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	anim.add_animation_library("", Assets.res(d.anims))
	_phase = randi() % 6
	# pose de reposo en espacio del esqueleto (para orientar las manos)
	rest_g.clear()
	for i in skel.get_bone_count():
		var l := skel.get_bone_rest(i)
		var par := skel.get_bone_parent(i)
		rest_g.append(l if par < 0 else (rest_g[par] as Transform3D) * l)
	_calc_grip()
	if kind == "zombie":
		_make_face_muzzle()
	play("idle", 0.0)
	anim.advance(0.0)
	_fk()

# Materiales propios por instancia (tinte, borde de luz y destello de dano); conservan las texturas PBR de Meshy.
func _make_mats(tint: Color, rim: float, rim_tint: float) -> Array:
	var out := []
	if Assets.headless:
		return out
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var base = mi.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var d: StandardMaterial3D = base.duplicate()
				d.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				d.albedo_color = tint
				d.metallic = minf(d.metallic, 0.2)
				d.metallic_specular = 0.3
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

# ------------------------------------------------------------------ esqueleto: FK / IK a mano
# (get_bone_global_pose de Godot 4.2 puede devolver una cache vieja; aca se calcula todo con las poses locales)

func _fk() -> void:
	gp.resize(skel.get_bone_count())
	for i in skel.get_bone_count():
		var l := skel.get_bone_pose(i)
		var par := skel.get_bone_parent(i)
		gp[i] = l if par < 0 else (gp[par] as Transform3D) * l

func _set_g_basis(i: int, nb: Basis) -> void:
	var par := skel.get_bone_parent(i)
	var pb: Basis = Basis.IDENTITY if par < 0 else (gp[par] as Transform3D).basis
	skel.set_bone_pose_rotation(i, (pb.inverse() * nb.orthonormalized()).get_rotation_quaternion())
	_fk()

func _rot_g(i: int, q: Quaternion) -> void:
	_set_g_basis(i, Basis(q) * (gp[i] as Transform3D).basis)

func _aim_y(i: int, dir: Vector3) -> void:
	var cy: Vector3 = (gp[i] as Transform3D).basis.y.normalized()
	_rot_g(i, Quaternion(cy, dir.normalized()))

# IK analitico de dos huesos: b_up -> b_mid -> b_end alcanza `target` (espacio del esqueleto); `pole` orienta el codo/rodilla
func _ik2(b_up: int, b_mid: int, b_end: int, target: Vector3, pole: Vector3) -> void:
	var p0: Vector3 = (gp[b_up] as Transform3D).origin
	var l1 := skel.get_bone_rest(b_mid).origin.length()
	var l2 := skel.get_bone_rest(b_end).origin.length()
	var to_t := target - p0
	var dist := clampf(to_t.length(), absf(l1 - l2) + 0.02, l1 + l2 - 0.005)
	var dir := to_t.normalized()
	var a := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var pv := pole - dir * pole.dot(dir)
	if pv.length() < 0.001:
		pv = dir.cross(Vector3.UP)
	pv = pv.normalized()
	var elbow := p0 + dir * a + pv * h
	_aim_y(b_up, elbow - p0)
	var em: Vector3 = (gp[b_mid] as Transform3D).origin
	_aim_y(b_mid, p0 + dir * dist - em)

# ------------------------------------------------------------------ arma

# Rotacion fija del soporte del arma respecto de la mano derecha: la mano (orientada con la pose de reposo girada para que los
# dedos apunten a GRIP_FINGERS en el espacio del arma) abraza la empunadura; asi el arma sale apuntando a +Z.
func _calc_grip() -> void:
	var hb: Basis = (rest_g[bi.r_hand] as Transform3D).basis
	var f := GRIP_FINGERS.normalized()
	var hw := Basis(Quaternion(hb.y.normalized(), f)) * hb          # mano en el espacio del arma
	hw = Basis(f, deg_to_rad(GRIP_ROLL)) * hw
	grip_g = hw.orthonormalized().inverse()                          # hueso -> soporte

func _make_face_muzzle() -> void:
	face_attach = BoneAttachment3D.new()
	skel.add_child(face_attach)
	face_attach.bone_name = BN.face
	muzzle = Marker3D.new()
	face_attach.add_child(muzzle)
	muzzle.position = Vector3(0, 0.0, 0.0)

func give_weapon(wname: String, length := 1.0, tint := Color.WHITE) -> void:
	armed = true
	if weapon_holder:
		weapon_holder.queue_free()
	if r_attach == null:
		r_attach = BoneAttachment3D.new()
		skel.add_child(r_attach)
		r_attach.bone_name = BN.r_hand
	weapon_holder = Node3D.new()
	r_attach.add_child(weapon_holder)
	weapon_holder.transform = Transform3D(grip_g, GRIP_PALM)
	weapon = Assets.inst(BLASTER_DIR + wname + ".glb")
	Assets.make_lit(weapon, tint, 0.7)
	weapon_holder.add_child(weapon)
	var bb := Assets.aabb_of(weapon)
	weapon_len = length
	var sc := length / maxf(bb.size.z, 0.01) / unit     # el soporte vive dentro del esqueleto (escala `unit`)
	weapon.scale = Vector3.ONE * sc
	# la boca apunta a +Z del soporte; la empunadura (~28% desde atras, ~35% de altura) queda en el origen
	var gz := bb.position.z + bb.size.z * 0.28
	var gy := bb.position.y + bb.size.y * 0.30
	weapon.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * sc, -gy * sc, -gz * sc)
	muzzle = Marker3D.new()
	weapon_holder.add_child(muzzle)
	muzzle.position = Vector3(0, (bb.position.y + bb.size.y * 0.5 - gy) * sc, (bb.position.z + bb.size.z - gz) * sc)
	weapon_z = 0.0

# Apunta el arma hacia un punto del mundo.
func aim_weapon(target: Vector3) -> void:
	var from := global_position + Vector3(0, 1.3, 0)
	if weapon_holder != null and is_instance_valid(weapon_holder):
		from = weapon_holder.global_position
	var d := target - from
	if d.length() < 1.5:
		return
	aim_world = d.normalized()

func kick() -> void:
	weapon_kick = 1.0

# ------------------------------------------------------------------ animacion

func play(n: String, blend := 0.15, spd := 1.0) -> void:
	if anim == null or gest != "":
		return
	if n != cur and dwell > 0.0 and cur != "":
		return
	if n != cur:
		cur = n
		dwell = 0.22
		if not anim.has_animation(n):
			return
		anim.play(n, blend, spd * speed_var)
	else:
		anim.speed_scale = spd * speed_var

func play_once(n: String, blend := 0.05, spd := 1.0) -> void:
	cur = n
	dwell = 0.5
	if not anim.has_animation(n):
		return
	anim.play(n, blend, spd)

# Elige idle / walk / run segun la velocidad horizontal real; la animacion avanza proporcional a la velocidad (menos patinaje).
func locomote(hs: float, run_from := 3.4) -> void:
	if hs < 0.4:
		play("idle", 0.15, 1.0)
	elif hs < run_from:
		play("walk", 0.15, clampf(hs / walk_ref, 0.55, 2.2))
	else:
		play("run", 0.12, clampf(hs / run_ref, 0.8, 2.1))

func anim_time() -> float:
	return anim.current_animation_position if anim else 0.0

# arranca la animacion `n` en el instante `t` (p. ej. el gesto de lanzar del zombi) a velocidad `spd`; mientras dura
# (hasta el instante `until` de la animacion) bloquea la locomocion.
func gesture(n: String, t: float, spd := 1.0, until := -1.0, blend := 0.08) -> void:
	if anim == null or not anim.has_animation(n) or dying:
		return
	cur = n
	dwell = 0.0
	gest = n
	gest_end = until if until > 0.0 else anim.get_animation(n).length
	anim.play(n, blend, spd)
	anim.seek(t, false)

func cancel_gesture() -> void:
	gest = ""
	cur = ""

func randomize_phase() -> void:
	if anim.current_animation != "":
		anim.seek(randf() * anim.current_animation_length, false)

func die(side := 0.0) -> void:
	if dying:
		return
	dying = true
	die_t = 0.0
	die_side = side
	armed = false
	gest = ""
	anim.speed_scale = 0.0     # se congela la pose actual; la caida es procedural encima

# vuelve a la pose normal (reinicio de partida)
func revive() -> void:
	dying = false
	die_t = 0.0
	collapse = 0.0
	crouch = 0.0
	tuck = 0.0
	aim_k = 0.0
	gest = ""
	body.transform = Transform3D(Basis.from_scale(Vector3.ONE * unit), Vector3.ZERO)
	armed = weapon_holder != null
	cur = ""
	dwell = 0.0
	anim.speed_scale = 1.0

func hit_flash() -> void:
	flash_t = 0.09

func set_alpha(a: float) -> void:
	alpha = a
	for m in mats:
		if a < 0.999:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = a
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = 1.0

# ------------------------------------------------------------------ bucle

func _process(delta: float) -> void:
	dwell = maxf(0.0, dwell - delta)
	flash_t = maxf(0.0, flash_t - delta)
	_emission()
	if weapon_holder != null:
		weapon_kick = maxf(0.0, weapon_kick - delta * 9.0)
	if dying:
		die_t += delta
	_acc += delta
	_frame += 1
	if lod > 1 and (_frame + _phase) % lod != 0:
		return
	var dt := _acc
	_acc = 0.0
	if gest != "" and (anim.current_animation != gest or anim.current_animation_position >= gest_end):
		gest = ""
		cur = ""
	anim.advance(dt)
	_fk()
	_pose(dt)

func _emission() -> void:
	var e := base_emit
	var k := 1.0
	if flash_t > 0.0:
		e = Color(1.0, 0.85, 0.7)
		k = 0.9
	elif glow > 0.0:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
		e = glow_col * glow * pulse
		k = 1.5
	for m in mats:
		m.emission = e
		m.emission_energy_multiplier = k

func _pose(dt: float) -> void:
	var ck := maxf(crouch, collapse)
	if dying:
		var u := clampf(die_t / 0.45, 0.0, 1.0)
		collapse = u * u * (3.0 - 2.0 * u)
		ck = collapse
		var f := clampf((die_t - 0.2) / 0.85, 0.0, 1.0)
		var ang := (f * f) * deg_to_rad(86.0)
		# pequeno rebote al llegar al suelo
		if die_t > 1.05:
			ang -= sin(clampf((die_t - 1.05) * 9.0, 0.0, PI)) * 0.05
		body.transform = Transform3D(Basis.from_euler(Vector3(-ang, 0.0, die_side * ang * 0.35)) * Basis.from_scale(Vector3.ONE * unit), Vector3.ZERO)
	var need := ck > 0.005 or tuck > 0.005 or armed
	if not need:
		return
	var feet := [gp[bi.l_foot], gp[bi.r_foot]]
	# --- cadera: baja y se inclina (agacharse / encogerse / ceder al morir)
	var drop := 0.36 * ck + 0.20 * tuck
	var lean := 0.30 * ck + 1.0 * tuck
	if drop > 0.002:
		var hp := skel.get_bone_pose_position(bi.hips)
		skel.set_bone_pose_position(bi.hips, hp + Vector3(0.0, -drop, 0.05 * ck))
		_fk()
		_rot_g(bi.hips, Quaternion(Vector3.RIGHT, lean))
		for k in ["spine", "spine1", "spine2"]:
			_rot_g(bi[k], Quaternion(Vector3.RIGHT, -0.16 * ck + 0.50 * tuck))
		if dying:
			_rot_g(bi.head, Quaternion(Vector3.RIGHT, -0.35 * ck))
		var pole := Vector3(0.0, 0.3, 1.0)
		var hips_o: Vector3 = (gp[bi.hips] as Transform3D).origin
		for s in 2:
			var up: int = bi.l_up if s == 0 else bi.r_up
			var leg: int = bi.l_leg if s == 0 else bi.r_leg
			var ft: int = bi.l_foot if s == 0 else bi.r_foot
			var side := 1.0 if s == 0 else -1.0
			var tgt: Vector3 = (feet[s] as Transform3D).origin
			if tuck > 0.01:
				tgt = tgt.lerp(hips_o + Vector3(0.11 * side, -0.02, 0.17), tuck)
			_ik2(up, leg, ft, tgt, pole)
			_set_g_basis(ft, (feet[s] as Transform3D).basis)
	if armed and not dying:
		_arms()
	elif tuck > 0.01:
		pass

# torso y cabeza hacia la mira + brazos con IK sobre el arma
func _arms() -> void:
	var sb: Basis = skel.global_transform.basis.orthonormalized()
	var dir_aim: Vector3 = (sb.inverse() * aim_world).normalized()
	var dir_ready := READY_DIR.normalized()
	var k := clampf(aim_k, 0.0, 1.0)
	var dir := dir_ready.slerp(dir_aim, k).normalized()
	var yaw := atan2(dir.x, dir.z)
	var pit := asin(clampf(dir.y, -1.0, 1.0))
	var tw := clampf(yaw, -1.2, 1.2) * k
	var pk := pit * k
	var plan := [["spine", 0.18, 0.12], ["spine1", 0.22, 0.18], ["spine2", 0.28, 0.22], ["neck", 0.10, 0.12], ["head", 0.12, 0.2]]
	for e in plan:
		_rot_g(bi[e[0]], Quaternion(Vector3.UP, tw * e[1]) * Quaternion(Vector3.RIGHT, -pk * e[2]))
	var kick_back := weapon_kick * 0.07
	# --- arma: posicion de la empunadura (mezcla descanso/apuntado) y orientacion
	var fr := Basis.looking_at(-dir, Vector3.UP)
	var fa := Basis.looking_at(-dir_aim, Vector3.UP)
	var fready := Basis.looking_at(-dir_ready, Vector3.UP)
	var rs: Vector3 = (gp[bi.r_arm] as Transform3D).origin
	var p_aim: Vector3 = rs + fa * AIM_OFFSET
	var p_ready: Vector3 = (gp[bi.spine2] as Transform3D).origin + fready * READY_OFFSET
	var grip := p_ready.lerp(p_aim, k) - fr.z * kick_back
	var w := Transform3D(fr, grip)
	grip_pos_w = grip
	# --- mano derecha
	var hx := w * Transform3D(grip_g, GRIP_PALM).affine_inverse()
	_ik2(bi.r_arm, bi.r_fore, bi.r_hand, hx.origin, Vector3(-0.35, -1.0, -0.15))
	_set_g_basis(bi.r_hand, hx.basis)
	# --- mano izquierda en el guardamano (los dedos hacia adelante, palma arriba)
	var sup := weapon_len * 0.0 + 1.0
	var lt: Vector3 = w * (SUPPORT_POS * sup)
	var rest_b: Basis = (rest_g[bi.l_hand] as Transform3D).basis
	var fing: Vector3 = (fr * Vector3(0.18, -0.05, 1.0)).normalized()
	var lb := Basis(Quaternion(rest_b.y.normalized(), fing)) * rest_b
	lb = Basis(fing, deg_to_rad(SUPPORT_ROLL)) * lb
	_ik2(bi.l_arm, bi.l_fore, bi.l_hand, lt - lb.y * 0.05, Vector3(0.45, -1.0, -0.1))
	_set_g_basis(bi.l_hand, lb)
