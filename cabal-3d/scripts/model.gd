extends Node3D
# Personaje "blocky" de Kenney (rig por nodos rigidos, sin Skeleton3D): arma en la mano, animaciones mezcladas
# (piernas de idle/walk/sprint + brazos de 'holding-both' para sostener el arma), destello de dano y fundido.

const Assets = preload("res://scripts/assets.gd")
const CHAR_DIR := "res://assets/third_party/kenney/characters/"
const BLASTER_DIR := "res://assets/third_party/kenney/blasters/"
const UNIT := 0.68   # el modelo mide ~2.7 unidades: 0.68 -> ~1.85 m

var body: Node3D
var anim: AnimationPlayer
var torso: Node3D
var mats: Array = []
var weapon_holder: Node3D
var weapon: Node3D
var muzzle: Marker3D
var cur := ""
var flash_t := 0.0
var glow := 0.0          # brillo de aviso (telegrafo)
var glow_col := Color(1.0, 0.2, 0.1)
var base_emit := Color.BLACK
var alpha := 1.0
var weapon_kick := 0.0
var weapon_z := 0.0
var dwell := 0.0

func setup(letter: String, tint := Color.WHITE, rim := 0.35, rim_tint := 0.6) -> void:
	body = Assets.inst(CHAR_DIR + "character-%s.glb" % letter)
	body.scale = Vector3.ONE * UNIT
	add_child(body)
	mats = Assets.make_unique_lit(body, tint, rim, rim_tint)
	anim = body.get_node("AnimationPlayer")
	torso = body.find_child("torso", true, false)
	_build_anims(letter)
	play("idle_h", 0.0)

# Animaciones mezcladas por personaje (se arman una sola vez y se comparten; cada instancia tiene su propia biblioteca).
static var _anim_cache := {}

func _build_anims(letter: String) -> void:
	var lib: AnimationLibrary = anim.get_animation_library("")
	if not _anim_cache.has(letter):
		var made := {}
		var hold: Animation = lib.get_animation("holding-both")
		for loco in ["idle", "walk", "sprint"]:
			var a: Animation = lib.get_animation(loco).duplicate(true)
			a.loop_mode = Animation.LOOP_LINEAR
			for t in range(a.get_track_count() - 1, -1, -1):
				var p := str(a.track_get_path(t))
				if p.ends_with("arm-left") or p.ends_with("arm-right"):
					a.remove_track(t)
			for t in hold.get_track_count():
				var p := str(hold.track_get_path(t))
				if p.ends_with("arm-left") or p.ends_with("arm-right"):
					var nt := a.add_track(Animation.TYPE_ROTATION_3D)
					a.track_set_path(nt, hold.track_get_path(t))
					a.rotation_track_insert_key(nt, 0.0, hold.rotation_track_interpolate(t, 0.0))
			made[loco + "_h"] = a
			var base: Animation = lib.get_animation(loco).duplicate(true)
			base.loop_mode = Animation.LOOP_LINEAR
			made[loco] = base
		for n in ["die", "attack-melee-right", "holding-both"]:
			var an: Animation = lib.get_animation(n).duplicate(true)
			an.loop_mode = Animation.LOOP_NONE
			made[n] = an
		_anim_cache[letter] = made
	var own := AnimationLibrary.new()
	for n in _anim_cache[letter]:
		own.add_animation(n, _anim_cache[letter][n])
	anim.remove_animation_library("")
	anim.add_animation_library("", own)

# Desplazamiento lateral del arma (a un costado del cuerpo para que se vea desde la camara sobre el hombro).
const WEAPON_SIDE := -0.52

# Apunta el arma hacia un punto del mundo (la boca mira a +Z del soporte).
func aim_weapon(target: Vector3) -> void:
	if weapon_holder == null or not is_instance_valid(weapon_holder):
		return
	var d := target - weapon_holder.global_position
	if d.length() < 2.0:
		return
	var want := Basis.looking_at(-d.normalized(), Vector3.UP)
	var par := weapon_holder.get_parent() as Node3D
	var local := par.global_transform.basis.orthonormalized().inverse() * want
	weapon_holder.basis = weapon_holder.basis.orthonormalized().slerp(local.orthonormalized(), 0.6)

func give_weapon(name: String, length := 1.7, tint := Color.WHITE) -> void:
	if weapon_holder:
		weapon_holder.queue_free()
	weapon_holder = Node3D.new()
	torso.add_child(weapon_holder)
	weapon_holder.position = Vector3(WEAPON_SIDE, 1.16, 0.0)
	weapon = Assets.inst(BLASTER_DIR + name + ".glb")
	Assets.make_lit(weapon, tint, 0.7)
	weapon_holder.add_child(weapon)
	var bb := Assets.aabb_of(weapon)
	var sc := length / maxf(bb.size.z, 0.01)
	weapon.scale = Vector3.ONE * sc
	# la boca apunta a +Z del torso; se centra en altura y se adelanta entre las manos
	weapon.position = Vector3(-(bb.position.x + bb.size.x * 0.5) * sc, -(bb.position.y + bb.size.y * 0.55) * sc, 0.30 - bb.position.z * sc)
	muzzle = Marker3D.new()
	weapon_holder.add_child(muzzle)
	muzzle.position = Vector3(0, 0, 0.30 + length)
	weapon_z = 0.0

func play(n: String, blend := 0.15, spd := 1.0) -> void:
	if anim == null:
		return
	if n != cur and dwell > 0.0 and cur != "":
		return
	if n != cur:
		cur = n
		dwell = 0.22
		if not anim.has_animation(n):
			return
		anim.play(n, blend, spd)
	else:
		anim.speed_scale = spd

func play_once(n: String, blend := 0.05) -> void:
	cur = n
	dwell = 0.5
	if not anim.has_animation(n):
		return
	anim.play(n, blend, 1.0)

func hit_flash() -> void:
	flash_t = 0.09

func kick() -> void:
	weapon_kick = 1.0

func set_alpha(a: float) -> void:
	alpha = a
	for m in mats:
		if a < 0.999:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = a
		else:
			m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			m.albedo_color.a = 1.0

func _process(delta: float) -> void:
	dwell = maxf(0.0, dwell - delta)
	flash_t = maxf(0.0, flash_t - delta)
	var e := base_emit
	var k := 0.0
	if flash_t > 0.0:
		e = Color(1.0, 0.85, 0.7)
		k = 0.9
	elif glow > 0.0:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
		e = glow_col * glow * pulse
		k = 1.5
	else:
		k = 1.0
	for m in mats:
		m.emission = e
		m.emission_energy_multiplier = k
	if weapon_holder:
		weapon_kick = maxf(0.0, weapon_kick - delta * 9.0)
		weapon_holder.position.z = weapon_z - weapon_kick * 0.16
