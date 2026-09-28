extends Node
## SaveManager: historial rotativo de checkpoints + ranking local.
## Reglas seguidas (aprendidas en Dia Blanco):
##  - Historial rotativo de ~6 puntos.
##  - "Volver a punto anterior" disponible desde pausa.
##  - Verificacion por lista blanca al leer de disco, nunca lista negra.
##  - Al agregar estado nuevo: sumarlo en GameManager.build/apply_checkpoint_snapshot()
##    Y en CHECKPOINT_KEY_WHITELIST de este archivo.
##  - Los valores derivados se recalculan de cero al cargar, nunca se incrementan.

const SAVE_PATH := "user://requiem_save.json"
const RANKING_PATH := "user://requiem_ranking.json"
const MAX_HISTORY := 6
const MAX_RANKING_ENTRIES := 10

## Lista blanca de claves aceptadas al deserializar un checkpoint desde disco.
## Cualquier clave que no este aca se descarta silenciosamente.
const CHECKPOINT_KEY_WHITELIST := [
	"level_id", "wave_index", "game_mode", "selected_ship",
	"scores", "lives", "continues_left", "bombs",
	"weapon_level", "shield_charges", "story_flags", "label", "timestamp",
]

const RANKING_KEY_WHITELIST := ["name", "score", "level_reached", "timestamp"]

var _history: Array[Dictionary] = []

func _ready() -> void:
	_load_from_disk()

## --- Checkpoints -----------------------------------------------------

func push_checkpoint(label: String = "") -> Dictionary:
	var snapshot := GameManager.build_checkpoint_snapshot({
		"label": label if label != "" else "Nivel %d" % GameManager.current_level_id,
		"timestamp": Time.get_unix_time_from_system(),
	})
	_history.append(_sanitize_checkpoint(snapshot))
	while _history.size() > MAX_HISTORY:
		_history.pop_front()
	_flush_to_disk()
	return snapshot

func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)

func has_checkpoints() -> bool:
	return not _history.is_empty()

func revert_to(index: int) -> bool:
	if index < 0 or index >= _history.size():
		return false
	var snapshot: Dictionary = _history[index]
	GameManager.apply_checkpoint_snapshot(snapshot)
	# Al volver a un punto anterior se descartan los puntos posteriores.
	_history = _history.slice(0, index + 1)
	_flush_to_disk()
	return true

func revert_to_last() -> bool:
	if _history.is_empty():
		return false
	return revert_to(_history.size() - 1)

func clear_history() -> void:
	_history.clear()
	_flush_to_disk()

func _sanitize_checkpoint(raw: Dictionary) -> Dictionary:
	var clean := {}
	for key in CHECKPOINT_KEY_WHITELIST:
		if raw.has(key):
			clean[key] = raw[key]
	return clean

## --- Ranking local -----------------------------------------------------

func submit_ranking_entry(player_name: String, score: int, level_reached: int) -> void:
	var ranking := load_ranking()
	ranking.append({
		"name": player_name.substr(0, 12) if player_name.length() > 0 else "PILOTO",
		"score": score,
		"level_reached": level_reached,
		"timestamp": Time.get_unix_time_from_system(),
	})
	ranking.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if ranking.size() > MAX_RANKING_ENTRIES:
		ranking.resize(MAX_RANKING_ENTRIES)
	var file := FileAccess.open(RANKING_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(ranking))
		file.close()

func load_ranking() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(RANKING_PATH):
		return out
	var file := FileAccess.open(RANKING_PATH, FileAccess.READ)
	if not file:
		return out
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return out
	for entry in parsed:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var clean := {}
		for key in RANKING_KEY_WHITELIST:
			if entry.has(key):
				clean[key] = entry[key]
		if clean.has("name") and clean.has("score"):
			out.append(clean)
	return out

## --- Persistencia en disco ---------------------------------------------

func _flush_to_disk() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(_history))
	file.close()

func _load_from_disk() -> void:
	_history.clear()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		return
	for entry in parsed:
		if typeof(entry) == TYPE_DICTIONARY:
			_history.append(_sanitize_checkpoint(entry))
	while _history.size() > MAX_HISTORY:
		_history.pop_front()
