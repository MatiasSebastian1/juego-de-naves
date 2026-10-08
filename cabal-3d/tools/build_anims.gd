extends SceneTree
# Extrae las animaciones de los GLB de Meshy (los que traen malla + textura, ~20 MB c/u) y las guarda como un
# AnimationLibrary chico (.res) sin malla ni texturas.  Uso:
#   godot --headless --path cabal-3d --script res://tools/build_anims.gd -- <carpeta_meshy> <salida.res> <modelo.glb> nombre=archivo:Animacion[:loop] ...
# Ej. jugador:
#   ... -- /ruta/meshychar res://assets/meshy/player_anims.res res://assets/meshy/character.glb \
#        idle=idle:Idle_02:loop walk=walk:Walking:loop run=run:Running:loop shot=shot:Side_Shot
# Que hace con cada animacion:
#  * anula el "root motion": la traslacion X/Z del hueso Hips se reemplaza por su promedio (el movimiento lo gobierna el
#    CharacterBody3D; la altura Y de la cadera se conserva);
#  * agrega una pista de rotacion en reposo para los huesos que no tienen pista, asi TODOS los huesos se reescriben en
#    cada cuadro (el codigo procedural de model.gd puede sumar rotaciones encima sin acumular);
#  * marca el loop (LINEAR) o no, y quita los duplicados vacios "X.001" de Meshy.
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() < 4:
		push_error("uso: ver comentario del script")
		quit(1)
		return
	var dir: String = a[0]
	var out_path: String = a[1]
	var model: Node = (load(a[2]) as PackedScene).instantiate()
	var sk: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var sk_path := str(model.get_path_to(sk))
	var lib := AnimationLibrary.new()
	for i in range(3, a.size()):
		var spec: PackedStringArray = a[i].split("=")
		var parts: PackedStringArray = spec[1].split(":")
		var d := GLTFDocument.new()
		var st := GLTFState.new()
		var err := d.append_from_file("%s/%s.glb" % [dir, parts[0]], st)
		if err != OK:
			push_error("no se pudo leer " + parts[0])
			quit(1)
			return
		var raw := d.generate_scene(st)
		var rap: AnimationPlayer = raw.find_children("*", "AnimationPlayer", true, false)[0]
		var an: Animation = rap.get_animation(parts[1]).duplicate(true)
		var has_rot := {}
		for t in an.get_track_count():
			var p := str(an.track_get_path(t))
			var bone := p.get_slice(":", 1)
			if an.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				has_rot[bone] = true
			elif an.track_get_type(t) == Animation.TYPE_POSITION_3D and bone == "mixamorig_Hips":
				var n := an.track_get_key_count(t)
				var mx := 0.0
				var mz := 0.0
				for k in n:
					var v: Vector3 = an.track_get_key_value(t, k)
					mx += v.x
					mz += v.z
				mx /= n
				mz /= n
				for k in n:
					var v: Vector3 = an.track_get_key_value(t, k)
					an.track_set_key_value(t, k, Vector3(mx, v.y, mz))
		for b in sk.get_bone_count():
			var bn := sk.get_bone_name(b)
			if not has_rot.has(bn):
				var nt := an.add_track(Animation.TYPE_ROTATION_3D)
				an.track_set_path(nt, NodePath("%s:%s" % [sk_path, bn]))
				an.rotation_track_insert_key(nt, 0.0, sk.get_bone_rest(b).basis.get_rotation_quaternion())
		an.loop_mode = Animation.LOOP_LINEAR if parts.size() > 2 and parts[2] == "loop" else Animation.LOOP_NONE
		lib.add_animation(spec[0], an)
		print("%s: %s %.3f s, %d pistas" % [spec[0], parts[1], an.length, an.get_track_count()])
		raw.free()
	var e := ResourceSaver.save(lib, out_path, ResourceSaver.FLAG_COMPRESS)
	print("guardado ", out_path, " err=", e)
	quit()
