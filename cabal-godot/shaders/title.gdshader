shader_type canvas_item;

// Titulo del menu: degradado calido vertical y brillo que lo barre periodicamente.
void fragment() {
	vec2 s = SCREEN_UV;
	float g = smoothstep(0.12, 0.42, s.y);
	vec3 top = vec3(1.0, 0.93, 0.62);
	vec3 bot = vec3(1.0, 0.36, 0.14);
	vec3 col = mix(top, bot, g);
	float x = fract(TIME * 0.16) * 2.2 - 0.6;
	float band = smoothstep(0.09, 0.0, abs(s.x - s.y * 0.35 - x));
	vec4 c = COLOR;
	// el relleno se dibuja en blanco puro y toma el degradado; contorno negro y brillo naranja conservan su tono
	float fill = step(0.97, c.r) * step(0.97, c.g) * step(0.97, c.b);
	c.rgb = mix(c.rgb, col, fill);
	c.rgb += band * vec3(1.0, 0.95, 0.8) * 0.85 * c.a;
	COLOR = c;
}
