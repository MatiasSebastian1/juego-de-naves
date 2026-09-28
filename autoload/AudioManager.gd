extends Node
## AudioManager: SFX procedurales (sin assets externos) + reproductor de musica.
## Regla: empezar con sonidos placeholder generados en runtime; reemplazar por
## packs/musica real mas adelante sin tocar la API publica (play_sfx/play_music).

const MIX_RATE := 22050
const SFX_POOL_SIZE := 10

var _sfx_cache: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _pool_cursor: int = 0
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_setup_buses()
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
	_build_sfx_cache()

func _setup_buses() -> void:
	for bus_name in ["SFX", "Music"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.5)))

func play_sfx(sfx_name: String, pitch_variance: float = 0.05) -> void:
	if not _sfx_cache.has(sfx_name):
		return
	var player := _sfx_pool[_pool_cursor]
	_pool_cursor = (_pool_cursor + 1) % _sfx_pool.size()
	player.stream = _sfx_cache[sfx_name]
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()

func play_music(stream_path: String, fade_in: float = 0.5) -> void:
	if not ResourceLoader.exists(stream_path):
		return
	_music_player.stream = load(stream_path)
	_music_player.volume_db = -40.0
	_music_player.play()
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", 0.0, fade_in)

func stop_music(fade_out: float = 0.5) -> void:
	if not _music_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_music_player, "volume_db", -40.0, fade_out)
	tween.tween_callback(_music_player.stop)

## --- Generacion procedural ------------------------------------------------

func _build_sfx_cache() -> void:
	_sfx_cache["shoot"] = _generate_tone(880.0, 0.08, "square", 0.5)
	_sfx_cache["shoot_heavy"] = _generate_tone(220.0, 0.14, "square", 0.6)
	_sfx_cache["hit_player"] = _generate_tone(140.0, 0.18, "noise", 0.6)
	_sfx_cache["hit_enemy"] = _generate_tone(600.0, 0.06, "square", 0.4)
	_sfx_cache["explosion_small"] = _generate_tone(120.0, 0.25, "noise", 0.7)
	_sfx_cache["explosion_big"] = _generate_tone(80.0, 0.6, "noise", 0.9)
	_sfx_cache["powerup"] = _generate_tone(660.0, 0.2, "sine_up", 0.5)
	_sfx_cache["shield_break"] = _generate_tone(300.0, 0.3, "noise", 0.6)
	_sfx_cache["bomb"] = _generate_tone(60.0, 0.8, "noise", 1.0)
	_sfx_cache["menu_move"] = _generate_tone(440.0, 0.05, "square", 0.3)
	_sfx_cache["menu_confirm"] = _generate_tone(880.0, 0.12, "sine_up", 0.4)
	_sfx_cache["boss_alert"] = _generate_tone(160.0, 0.5, "square", 0.7)

func _generate_tone(freq: float, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq * 1000.0)
	for i in sample_count:
		var t := float(i) / MIX_RATE
		var progress := float(i) / float(max(sample_count - 1, 1))
		var envelope := 1.0 - progress # decay lineal simple
		var sample := 0.0
		match wave_type:
			"square":
				sample = sign(sin(TAU * freq * t))
			"noise":
				sample = rng.randf_range(-1.0, 1.0)
			"sine_up":
				var sweep_freq := freq * (1.0 + progress * 1.5)
				sample = sin(TAU * sweep_freq * t)
			_:
				sample = sin(TAU * freq * t)
		sample *= envelope * volume
		var sample_i16 := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, sample_i16)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream
