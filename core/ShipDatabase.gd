class_name ShipDatabase
extends RefCounted
## Datos base de las 3 naves iniciales. Placeholder hasta que lleguen los .glb
## de Meshy (ver docs/MESHY_WORKFLOW.md): mientras tanto cada nave se dibuja
## con primitivas coloreadas en Player.gd.

const SHIPS := {
	"interceptor": {
		"display_name": "Interceptor",
		"speed": 9.0,
		"fire_cooldown": 0.12,
		"bullet_damage": 1,
		"max_hp": 3,
		"color": Color(0.35, 0.85, 1.0),
		"passive_shield_regen": false,
	},
	"bombardero": {
		"display_name": "Bombardero",
		"speed": 5.0,
		"fire_cooldown": 0.28,
		"bullet_damage": 3,
		"max_hp": 6,
		"color": Color(1.0, 0.55, 0.25),
		"passive_shield_regen": false,
	},
	"prototipo": {
		"display_name": "Prototipo",
		"speed": 7.0,
		"fire_cooldown": 0.18,
		"bullet_damage": 2,
		"max_hp": 4,
		"color": Color(0.75, 0.4, 1.0),
		"passive_shield_regen": true,
	},
}

## Multiplicadores por nivel de arma (1-3). Se recalculan de cero, nunca se
## incrementan sobre el valor previo, para evitar arrastrar bugs entre saves.
const WEAPON_LEVEL_BULLET_COUNT := {1: 1, 2: 2, 3: 3}
const WEAPON_LEVEL_DAMAGE_MULT := {1: 1.0, 2: 1.3, 3: 1.7}
const WEAPON_LEVEL_COOLDOWN_MULT := {1: 1.0, 2: 0.85, 3: 0.7}

static func get_stats(ship_id: String) -> Dictionary:
	return SHIPS.get(ship_id, SHIPS["interceptor"])

static func compute_bullet_count(weapon_level: int) -> int:
	return WEAPON_LEVEL_BULLET_COUNT.get(clampi(weapon_level, 1, 3), 1)

static func compute_damage(ship_id: String, weapon_level: int) -> float:
	var base := float(get_stats(ship_id).get("bullet_damage", 1))
	return base * WEAPON_LEVEL_DAMAGE_MULT.get(clampi(weapon_level, 1, 3), 1.0)

static func compute_cooldown(ship_id: String, weapon_level: int) -> float:
	var base := float(get_stats(ship_id).get("fire_cooldown", 0.2))
	return base * WEAPON_LEVEL_COOLDOWN_MULT.get(clampi(weapon_level, 1, 3), 1.0)
