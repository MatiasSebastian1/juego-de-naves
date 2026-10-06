shader_type canvas_item;

// Postproceso: aberracion cromatica, correccion de color, vineta, grano y flashes de dano.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float hurt = 0.0;
uniform float flash = 0.0;
uniform float time_s = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	float ca = 0.0015 + r2 * 0.006 + hurt * 0.004;
	vec3 col;
	col.r = texture(screen_tex, uv + d * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - d * ca).b;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.12);
	col = (col - 0.5) * 1.06 + 0.5;
	col *= 1.0 - smoothstep(0.16, 0.72, r2) * 0.55;
	col += (hash(uv * vec2(1280.0, 720.0) + time_s) - 0.5) * 0.018;
	col = mix(col, vec3(1.0, 0.9, 0.75), clamp(flash, 0.0, 0.6));
	col += vec3(hurt * smoothstep(0.08, 0.55, r2) * 0.95, 0.0, 0.0);
	COLOR = vec4(col, 1.0);
}
