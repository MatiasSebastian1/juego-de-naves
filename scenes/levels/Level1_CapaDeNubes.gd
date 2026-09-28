extends LevelBase
## Nivel 1 - Capa de Nubes. Ensenia controles: cazas basicos, algun caza
## rapido y una torreta fija. Termina con el Guardian de la Nube.

const CazaBasicoScene := preload("res://scenes/enemies/CazaBasico.tscn")
const CazaRapidoScene := preload("res://scenes/enemies/CazaRapido.tscn")
const TorretaFijaScene := preload("res://scenes/enemies/TorretaFija.tscn")
const GuardianNubeScene := preload("res://scenes/bosses/GuardianNube.tscn")

func _build_timeline() -> void:
	level_id = 1
	scroll_speed = 3.0

	# Oleada 1: linea recta, aprender a esquivar.
	add_wave(3.0, CazaBasicoScene, -2.0)
	add_wave(4.0, CazaBasicoScene, 0.0)
	add_wave(5.0, CazaBasicoScene, 2.0)

	# Oleada 2: pares laterales.
	add_wave(10.0, CazaBasicoScene, -1.5)
	add_wave(10.0, CazaBasicoScene, 1.5)
	add_wave(13.0, CazaBasicoScene, -1.5)
	add_wave(13.0, CazaBasicoScene, 1.5)

	# Primeros cazas rapidos con zigzag.
	add_wave(17.0, CazaRapidoScene, -2.5)
	add_wave(18.0, CazaRapidoScene, 2.5)

	add_wave(23.0, CazaBasicoScene, -2.0)
	add_wave(23.5, CazaBasicoScene, 0.0)
	add_wave(24.0, CazaBasicoScene, 2.0)

	# Primeras torretas fijas.
	add_wave(29.0, TorretaFijaScene, -3.0)
	add_wave(29.0, TorretaFijaScene, 3.0)

	add_wave(35.0, CazaRapidoScene, 0.0)
	add_wave(37.0, CazaBasicoScene, -1.0)
	add_wave(37.0, CazaBasicoScene, 1.0)

	add_wave(42.0, CazaBasicoScene, -2.0)
	add_wave(42.6, CazaBasicoScene, 0.0)
	add_wave(43.2, CazaBasicoScene, 2.0)

	add_wave(48.0, CazaRapidoScene, -2.0)
	add_wave(48.5, CazaRapidoScene, 2.0)

	add_wave(53.0, TorretaFijaScene, 0.0)

	add_wave(58.0, CazaBasicoScene, -2.5)
	add_wave(58.0, CazaBasicoScene, 0.0)
	add_wave(58.0, CazaBasicoScene, 2.5)

	add_wave(63.0, CazaRapidoScene, -1.5)
	add_wave(63.5, CazaRapidoScene, 1.5)

	boss_scene = GuardianNubeScene
	boss_spawn_time = 70.0

func get_ambient_tint() -> Color:
	return Color(0.09, 0.11, 0.15)
