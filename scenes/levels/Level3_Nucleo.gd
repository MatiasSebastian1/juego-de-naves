extends LevelBase
## Nivel 3 - Nucleo de la Invasion. Mezcla de todos los enemigos a mayor
## ritmo. Termina con el jefe final.

const CazaBasicoScene := preload("res://scenes/enemies/CazaBasico.tscn")
const CazaRapidoScene := preload("res://scenes/enemies/CazaRapido.tscn")
const TorretaFijaScene := preload("res://scenes/enemies/TorretaFija.tscn")
const BombarderoScene := preload("res://scenes/enemies/BombarderoEnemy.tscn")
const DronKamikazeScene := preload("res://scenes/enemies/DronKamikaze.tscn")
const PortaNavesScene := preload("res://scenes/enemies/PortaNaves.tscn")
const NucleoInvasionScene := preload("res://scenes/bosses/NucleoInvasion.tscn")

func _build_timeline() -> void:
	level_id = 3
	scroll_speed = 3.6

	add_wave(2.0, CazaRapidoScene, -2.0)
	add_wave(2.0, CazaRapidoScene, 2.0)
	add_wave(6.0, DronKamikazeScene, 0.0)

	add_wave(11.0, BombarderoScene, -1.5)
	add_wave(11.0, BombarderoScene, 1.5)

	add_wave(17.0, TorretaFijaScene, -3.0)
	add_wave(17.0, TorretaFijaScene, 3.0)
	add_wave(17.5, CazaRapidoScene, 0.0)

	add_wave(23.0, PortaNavesScene, 0.0)
	add_wave(23.0, DronKamikazeScene, -2.5)
	add_wave(23.5, DronKamikazeScene, 2.5)

	add_wave(29.0, CazaBasicoScene, -2.5)
	add_wave(29.0, CazaBasicoScene, -1.0)
	add_wave(29.0, CazaBasicoScene, 1.0)
	add_wave(29.0, CazaBasicoScene, 2.5)

	add_wave(35.0, BombarderoScene, 0.0)
	add_wave(35.0, CazaRapidoScene, -2.0)
	add_wave(35.5, CazaRapidoScene, 2.0)

	add_wave(41.0, DronKamikazeScene, -1.5)
	add_wave(41.3, DronKamikazeScene, 0.0)
	add_wave(41.6, DronKamikazeScene, 1.5)

	add_wave(47.0, PortaNavesScene, -1.5)
	add_wave(47.0, PortaNavesScene, 1.5)

	add_wave(53.0, TorretaFijaScene, 0.0)
	add_wave(53.0, BombarderoScene, -2.0)
	add_wave(53.0, BombarderoScene, 2.0)

	add_wave(59.0, CazaRapidoScene, -2.5)
	add_wave(59.3, CazaRapidoScene, -0.8)
	add_wave(59.6, CazaRapidoScene, 0.8)
	add_wave(59.9, CazaRapidoScene, 2.5)

	add_wave(65.0, DronKamikazeScene, -2.0)
	add_wave(65.0, DronKamikazeScene, 2.0)

	boss_scene = NucleoInvasionScene
	boss_spawn_time = 74.0

func get_ambient_tint() -> Color:
	return Color(0.14, 0.04, 0.05)
