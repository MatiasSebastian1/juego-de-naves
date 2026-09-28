class_name StoryData
extends RefCounted
## Dialogos cortos entre niveles (modo historia). Placeholder de texto;
## los retratos son un circulo de color hasta tener arte real.

const INTRO := 0
const AFTER_LEVEL_1 := 1
const AFTER_LEVEL_2 := 2
const ENDING := 3

const LINES := {
	INTRO: [
		{"speaker": "Control", "color": Color(0.4, 0.8, 1.0), "text": "Piloto, la capa de nubes toxicas empieza en 10 segundos."},
		{"speaker": "Control", "color": Color(0.4, 0.8, 1.0), "text": "No hay retirada posible una vez que entremos."},
		{"speaker": "Piloto", "color": Color(0.9, 0.6, 0.3), "text": "Entendido. Llevando el Requiem a posicion."},
	],
	AFTER_LEVEL_1: [
		{"speaker": "Control", "color": Color(0.4, 0.8, 1.0), "text": "El Guardian cayo. Detectamos ruinas flotantes mas adelante."},
		{"speaker": "Piloto", "color": Color(0.9, 0.6, 0.3), "text": "Algo ahi abajo sigue con vida. Avanzando."},
	],
	AFTER_LEVEL_2: [
		{"speaker": "Control", "color": Color(0.4, 0.8, 1.0), "text": "La Ruina Flotante ya no transmite. El nucleo esta expuesto."},
		{"speaker": "Piloto", "color": Color(0.9, 0.6, 0.3), "text": "Es ahora o nunca. Voy por el nucleo de la invasion."},
	],
	ENDING: [
		{"speaker": "Control", "color": Color(0.4, 0.8, 1.0), "text": "Nucleo destruido. La senal de la invasion se apago."},
		{"speaker": "Piloto", "color": Color(0.9, 0.6, 0.3), "text": "Requiem cumplido. Volviendo a base."},
	],
}

static func get_lines(key: int) -> Array:
	return LINES.get(key, [])
