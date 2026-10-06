shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Suelo procedural del patio: losas de hormigon con juntas irregulares, mugre, manchas de aceite,
// parches de tierra, marcas de pintura gastada y grietas. Todo en coordenadas de mundo (sin tiling visible).
uniform vec3 concrete_a : source_color = vec3(0.36, 0.35, 0.34);
uniform vec3 concrete_b : source_color = vec3(0.47, 0.45, 0.42);
uniform vec3 dirt_col : source_color = vec3(0.33, 0.24, 0.17);
uniform vec3 paint_col : source_color = vec3(0.86, 0.66, 0.16);
uniform float arena_half = 30.0;

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
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 17.1;
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	// losas de 5 m con juntas desplazadas por fila
	float row = floor(p.y / 5.0);
	vec2 q = vec2(p.x + hash(vec2(row, 3.0)) * 5.0, p.y) / 5.0;
	vec2 cell = floor(q);
	vec2 f = fract(q);
	float seam = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)) * 5.0;
	float seam_m = (1.0 - smoothstep(0.0, 0.06, seam)) * smoothstep(0.25, 0.6, noise(p * 0.35 + 11.0));
	float cr = hash(cell + 7.0);
	vec3 col = mix(concrete_a, concrete_b, cr);
	// variacion a gran y pequena escala
	float n1 = fbm(p * 0.22);
	float n2 = fbm(p * 1.6 + 5.0);
	float n3 = noise(p * 9.0);
	col *= 0.78 + 0.45 * n1;
	col *= 0.9 + 0.2 * n2;
	col *= 0.96 + 0.08 * n3;
	// parches de tierra
	float dirt = smoothstep(0.52, 0.72, fbm(p * 0.11 + 31.0) + 0.12 * (length(p) / arena_half));
	col = mix(col, dirt_col * (0.8 + 0.4 * n2), dirt * 0.8);
	// manchas oscuras de aceite
	float oil = smoothstep(0.64, 0.74, fbm(p * 0.35 + 90.0));
	col = mix(col, col * 0.55, oil * 0.7);
	// grietas
	float crack = 1.0 - smoothstep(0.0, 0.012, abs(fbm(p * 0.8 + 3.0) - 0.5));
	col *= 1.0 - crack * 0.22 * (1.0 - dirt);
	// juntas
	col *= 1.0 - seam_m * 0.32;
	// circulo de pintura gastada en el centro y franjas de peligro cerca de los bordes
	float r = length(p);
	float ring = smoothstep(0.35, 0.0, abs(r - 12.0));
	float worn = smoothstep(0.35, 0.65, fbm(p * 0.9 + 70.0));
	col = mix(col, paint_col * (0.6 + 0.3 * n2), ring * worn * 0.55 * (1.0 - dirt));
	float lane = smoothstep(0.22, 0.0, abs(abs(p.x) - 1.8)) * step(r, 24.0) * step(14.0, r);
	col = mix(col, paint_col * 0.7, lane * worn * 0.4 * (1.0 - dirt));
	ALBEDO = col;
	ROUGHNESS = mix(0.78, 0.98, n2) - oil * 0.35;
	SPECULAR = 0.25 + oil * 0.3;
}
