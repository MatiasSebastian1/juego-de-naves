extends Node
# Reproductor de efectos (con variacion de tono) y musica en loop.

const NAMES := ["shot", "spread", "hit", "head", "boom", "hurt", "roll", "pickup", "enemy", "nade", "wave", "over"]

var streams := {}
var pool: Array = []
var music: AudioStreamPlayer

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
		m.loop_end = int(m.data.size() / 2)
	music.stream = m
	music.volume_db = -10.0
	add_child(music)

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

func music_volume(db: float) -> void:
	music.volume_db = db
