extends Node
# Reproductor de efectos (con variacion de tono) y musica en loop.

const NAMES := ["shot", "spread", "hit", "head", "boom", "hurt", "roll", "pickup", "enemy", "nade", "wave", "over"]

var streams := {}
var pool: Array = []
var music: AudioStreamPlayer
var level := 0.7        # volumen de musica elegido por el jugador (0..1, lineal)
var muted := false      # M silencia la musica
var base_db := -10.0    # volumen segun el estado del juego (juego / game over / pausa)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music = AudioStreamPlayer.new()
	var m = load("res://assets/audio/music.wav")
	if m is AudioStreamWAV:
		m.loop_mode = AudioStreamWAV.LOOP_FORWARD
		m.loop_begin = 0
		# loop_end va en muestras: depende del formato (8/16 bits, mono/estereo)
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

func start_music() -> void:
	if not music.playing:
		music.play()

# Volumen base de la musica segun el estado (el nivel del jugador se aplica encima).
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
