shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Arena del horizonte (marco alrededor del diorama y montanas lejanas): color por ruido en coordenadas de mundo,
// con vetas suaves de duna. Es barato a proposito: solo se ve de lejos y con niebla.
uniform vec3 sand_a : source_color = vec3(0.86, 0.69, 0.5);
uniform vec3 sand_b : source_color = vec3(0.74, 0.55, 0.4);
uniform float far_dim = 0.0;

varying vec3 wp;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float n = noise(p * 0.05) * 0.6 + noise(p * 0.23) * 0.3 + noise(p * 1.7) * 0.1;
	float vein = smoothstep(0.35, 0.65, noise(vec2(p.x * 0.02 + p.y * 0.035, p.y * 0.01) * 3.0));
	vec3 col = mix(sand_a, sand_b, clamp(n * 0.8 + vein * 0.35, 0.0, 1.0));
	col *= mix(1.0, 0.8, far_dim * clamp((wp.y) / 40.0, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
