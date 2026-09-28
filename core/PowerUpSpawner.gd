class_name PowerUpSpawner
extends RefCounted
## Helper para instanciar un power-up aleatorio al morir un enemigo.

const SCENES := {
	"weapon": preload("res://scenes/powerups/WeaponUpgrade.tscn"),
	"shield": preload("res://scenes/powerups/Shield.tscn"),
	"speed": preload("res://scenes/powerups/SpeedBoost.tscn"),
	"bomb": preload("res://scenes/powerups/Bomb.tscn"),
}
const TYPES := ["weapon", "shield", "speed", "bomb"]
const WEIGHTS := [0.4, 0.25, 0.25, 0.1]

static func spawn_random(parent: Node, global_pos: Vector3) -> Node:
	var power_type := _pick_weighted()
	var scene: PackedScene = SCENES[power_type]
	var instance: Node = scene.instantiate()
	parent.add_child(instance)
	instance.global_position = global_pos
	return instance

static func _pick_weighted() -> String:
	var total := 0.0
	for w in WEIGHTS:
		total += w
	var roll := randf() * total
	var acc := 0.0
	for i in TYPES.size():
		acc += WEIGHTS[i]
		if roll <= acc:
			return TYPES[i]
	return TYPES[0]
