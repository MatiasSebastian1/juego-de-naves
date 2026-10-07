extends Node
# Efectos (con variacion de tono) globales y posicionales (AudioStreamPlayer3D en pool) y musica en loop.

const NAMES := ["shot", "spread", "hit", "head", "boom", "hurt", "roll", "pickup", "enemy", "nade", "wave", "over"]

var streams := {}
var pool: Array = []
var pool3d: Array = []
var music: AudioStreamPlayer
var level := 0.7        # volumen de musica elegido por el jugador (0..1, lineal)
var muted := false      # M silencia la musica
var base_db := -11.0    # volumen segun el estado del juego (juego / pausa)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	for i in 16:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = 9.0
		p3.max_distance = 80.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(p3)
		pool3d.append(p3)
	music = AudioStreamPlayer.new()
	var m = load("res://assets/audio/music.wav")
	# music.wav se importa en ADPCM con bucle activado en el .import (edit/loop_mode=2); si llegara sin bucle
	# (PCM), se activa aqui
	if m is AudioStreamWAV and m.loop_mode == AudioStreamWAV.LOOP_DISABLED and m.format != AudioStreamWAV.FORMAT_IMA_ADPCM:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		var bytes := 2 if m.format == AudioStreamWAV.FORMAT_16_BITS else 1
		if m.stereo:
			bytes *= 2
		m.loop_end = int(m.data.size() / bytes)
	music.stream = m
	add_child(music)
	_apply()

func play(n: String, vol := 0.0, pitch_var := 0.07) -> void:
	if not streams.has(n):
		return
	for p in pool:
		if not p.playing:
			p.stream = streams[n]
			p.volume_db = vol
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.play()
			return

# Sonido posicional: se reutiliza el reproductor 3D libre (o el mas antiguo).
func play3d(n: String, pos: Vector3, vol := 0.0, pitch_var := 0.07, unit := 9.0) -> void:
	if not streams.has(n):
		return
	var best: AudioStreamPlayer3D = pool3d[0]
	for p in pool3d:
		if not p.playing:
			best = p
			break
	best.stream = streams[n]
	best.global_position = pos
	best.volume_db = vol
	best.unit_size = unit
	best.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	best.play()

func start_music() -> void:
	if not music.playing:
		music.play()

func music_volume(db: float) -> void:
	base_db = db
	_apply()

func set_level(v: float) -> void:
	level = clampf(v, 0.0, 1.0)
	_apply()

func set_muted(m: bool) -> void:
	muted = m
	_apply()

func _apply() -> void:
	music.volume_db = -80.0 if (muted or level <= 0.001) else base_db + linear_to_db(level) + 3.0
