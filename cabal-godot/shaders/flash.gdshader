shader_type canvas_item;

// Destello blanco al recibir un impacto + aclarado de borde (rim) para despegar el sprite del fondo.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// COLOR trae el color de vertice (incluye modulate: desvanecidos y parpadeo de invulnerabilidad)
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a) * COLOR;
}
