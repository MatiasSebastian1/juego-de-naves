shader_type canvas_item;

// Postproceso suave: vineta, grano fino, aberracion cromatica solo en los bordes, leve correccion de color
// calida (sombras frias, luces calidas) y flash rojo de dano. Pensado para NO perder legibilidad.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float hurt = 0.0;
uniform float time_s = 0.0;
uniform float grain_amt = 0.022;
uniform float vignette = 0.42;
uniform float low_hp = 0.0;
uniform float flash = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	float ca = 0.0004 + r2 * r2 * 0.02 + hurt * 0.004;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ca).b;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	// saturacion y contraste suaves (Compatibility no tiene 'adjustments')
	col = mix(vec3(luma), col, 1.12);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.22);
	luma = dot(col, vec3(0.299, 0.587, 0.114));
	// tono dividido
	col *= mix(vec3(1.0), vec3(0.92, 0.99, 1.08), (1.0 - smoothstep(0.0, 0.4, luma)) * 0.5);
	col *= mix(vec3(1.0), vec3(1.05, 1.0, 0.94), smoothstep(0.45, 0.95, luma) * 0.4);
	// vineta
	col *= 1.0 - smoothstep(0.12, 0.62, r2) * vignette;
	// grano
	float g = hash(FRAGCOORD.xy + fract(time_s) * 91.0) - 0.5;
	col += g * grain_amt * (1.0 - 0.6 * luma);
	// dano y vida baja
	float edge = smoothstep(0.06, 0.5, r2);
	col += vec3(hurt * edge * 0.9 + low_hp * edge * 0.22, 0.0, 0.0);
	col = mix(col, vec3(1.0, 0.95, 0.85), clamp(flash, 0.0, 0.5));
	COLOR = vec4(col, 1.0);
}
