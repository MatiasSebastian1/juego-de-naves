extends LevelBase
## Nivel 2 - Ruinas Flotantes. Mas presion: bombarderos, drones kamikaze y
## porta-naves. Termina con la Ruina Flotante.

const CazaBasicoScene := preload("res://scenes/enemies/CazaBasico.tscn")
const CazaRapidoScene := preload("res://scenes/enemies/CazaRapido.tscn")
const TorretaFijaScene := preload("res://scenes/enemies/TorretaFija.tscn")
const BombarderoScene := preload("res://scenes/enemies/BombarderoEnemy.tscn")
const DronKamikazeScene := preload("res://scenes/enemies/DronKamikaze.tscn")
const PortaNavesScene := preload("res://scenes/enemies/PortaNaves.tscn")
const RuinaFlotanteScene := preload("res://scenes/bosses/RuinaFlotante.tscn")

func _build_timeline() -> void:
	level_id = 2
	scroll_speed = 3.3

	add_wave(3.0, CazaRapidoScene, -2.0)
	add_wave(3.5, CazaRapidoScene, 2.0)

	add_wave(8.0, BombarderoScene, 0.0)

	add_wave(13.0, DronKamikazeScene, -2.5)
	add_wave(14.0, DronKamikazeScene, 2.5)

	add_wave(19.0, CazaBasicoScene, -2.0)
	add_wave(19.0, CazaBasicoScene, 0.0)
	add_wave(19.0, CazaBasicoScene, 2.0)

	add_wave(25.0, TorretaFijaScene, -3.0)
	add_wave(25.0, BombarderoScene, 0.5)

	add_wave(31.0, PortaNavesScene, -1.0)

	add_wave(37.0, DronKamikazeScene, -1.5)
	add_wave(37.5, DronKamikazeScene, 0.0)
	add_wave(38.0, DronKamikazeScene, 1.5)

	add_wave(43.0, CazaRapidoScene, -2.5)
	add_wave(43.5, CazaRapidoScene, 2.5)
	add_wave(44.0, BombarderoScene, 0.0)

	add_wave(50.0, PortaNavesScene, 1.5)
	add_wave(50.0, TorretaFijaScene, -2.5)

	add_wave(56.0, DronKamikazeScene, -2.0)
	add_wave(56.5, DronKamikazeScene, 2.0)
	add_wave(57.0, CazaRapidoScene, 0.0)

	add_wave(63.0, BombarderoScene, -1.5)
	add_wave(63.0, BombarderoScene, 1.5)

	boss_scene = RuinaFlotanteScene
	boss_spawn_time = 72.0

func get_ambient_tint() -> Color:
	return Color(0.12, 0.09, 0.07)
