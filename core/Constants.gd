class_name Constants
extends RefCounted
## Constantes compartidas: layout del playfield, grupos y capas de colision.
## Un solo lugar de verdad para que jugador, enemigos y niveles coincidan.

## Ancho jugable (mitad, en unidades de mundo) a cada lado del eje X central.
const PLAYFIELD_HALF_WIDTH := 3.5

## Rango de Z visible en camara (fijo, el mundo se mueve por debajo).
const VISIBLE_Z_MIN := -6.2
const VISIBLE_Z_MAX := 6.2

## Rango de Z donde el jugador puede moverse (parte baja de la pantalla).
const PLAYER_MIN_Z := -3.0
const PLAYER_MAX_Z := 5.5

## Donde aparecen/desaparecen enemigos, balas y power-ups respecto del scroll.
const SPAWN_Z := -9.0
const DESPAWN_Z := 9.0

## Grupos (para chequeos por overlap sin depender de collision layers).
const GROUP_PLAYER := "player"
const GROUP_PLAYER_BULLET := "player_bullets"
const GROUP_ENEMY := "enemies"
const GROUP_ENEMY_BULLET := "enemy_bullets"
const GROUP_POWERUP := "powerups"
const GROUP_BOSS := "boss"

## Bits de collision layer (deben coincidir con [layer_names] en project.godot).
const LAYER_PLAYER := 1 << 0
const LAYER_PLAYER_BULLET := 1 << 1
const LAYER_ENEMY := 1 << 2
const LAYER_ENEMY_BULLET := 1 << 3
const LAYER_POWERUP := 1 << 4
const LAYER_BOSS := 1 << 5
const LAYER_PLAYER2 := 1 << 6
