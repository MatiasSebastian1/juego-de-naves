shader_type canvas_item;

// Postproceso: distorsion (calor y ondas de choque), profundidad de campo en lo lejano, aberracion en bordes,
// bloom por mips con umbral, correccion de color con tono dividido, vineta, grano y flashes de dano.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float hurt = 0.0;
uniform float flash = 0.0;
uniform float time_s = 0.0;
uniform float bloom_amt = 0.5;
uniform float bloom_thr = 0.6;
uniform float dof_amt = 0.6;
uniform float grain_amt = 0.03;
// fuentes de calor: xy = centro (uv), z = radio (alto de pantalla), w = intensidad
uniform vec4 heat0 = vec4(0.0);
uniform vec4 heat1 = vec4(0.0);
uniform vec4 heat2 = vec4(0.0);
uniform vec4 heat3 = vec4(0.0);
// ondas de choque: xy = centro (uv), z = edad en segundos (< 0 = apagada), w = amplitud
uniform vec4 shock0 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 shock1 = vec4(0.0, 0.0, -1.0, 0.0);
uniform vec4 shock2 = vec4(0.0, 0.0, -1.0, 0.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 heat_offset(vec2 uv, vec2 asp, vec4 h) {
	if (h.w <= 0.0) return vec2(0.0);
	vec2 d = (uv - h.xy) * asp;
	// columna que sube: mas ancha abajo, se estira hacia arriba
	d.y *= 0.55;
	float f = smoothstep(h.z, 0.0, length(d)) * h.w;
	float w1 = sin(uv.y * 160.0 - time_s * 9.0 + uv.x * 40.0);
	float w2 = sin(uv.y * 95.0 - time_s * 6.0 + 1.7);
	return vec2(w1 * 0.0016 + w2 * 0.0010, 0.0) * f;
}

vec2 shock_offset(vec2 uv, vec2 asp, vec4 s) {
	if (s.z < 0.0) return vec2(0.0);
	vec2 d = (uv - s.xy) * asp;
	float dist = length(d);
	float radius = s.z * 1.05;
	float ring = exp(-pow((dist - radius) / 0.055, 2.0));
	float env = clamp(1.0 - s.z / 0.65, 0.0, 1.0);
	vec2 dir = d / max(dist, 0.0001);
	return -(dir / asp) * ring * env * s.w * 0.05;
}

vec3 bright_tap(vec2 uv, float lod) {
	vec3 c = textureLod(screen_tex, uv, lod).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	return c * smoothstep(bloom_thr, bloom_thr + 0.3, l);
}

vec3 bloom(vec2 uv) {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 acc = vec3(0.0);
	float lods[4] = float[4](2.0, 3.0, 4.0, 5.5);
	float wts[4] = float[4](0.34, 0.3, 0.22, 0.14);
	for (int i = 0; i < 4; i++) {
		vec2 o = px * exp2(lods[i]) * 0.85;
		vec3 s = bright_tap(uv, lods[i]) * 0.4;
		s += bright_tap(uv + vec2(o.x, o.y), lods[i]) * 0.15;
		s += bright_tap(uv + vec2(-o.x, o.y), lods[i]) * 0.15;
		s += bright_tap(uv + vec2(o.x, -o.y), lods[i]) * 0.15;
		s += bright_tap(uv + vec2(-o.x, -o.y), lods[i]) * 0.15;
		acc += s * wts[i];
	}
	return acc;
}

void fragment() {
	vec2 asp = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 uv = SCREEN_UV;
	// distorsiones
	uv += heat_offset(uv, asp, heat0) + heat_offset(uv, asp, heat1) + heat_offset(uv, asp, heat2) + heat_offset(uv, asp, heat3);
	uv += shock_offset(uv, asp, shock0) + shock_offset(uv, asp, shock1) + shock_offset(uv, asp, shock2);
	uv = clamp(uv, vec2(0.001), vec2(0.999));

	vec2 d = uv - 0.5;
	float r2 = dot(d, d);
	// profundidad de campo: lo lejano (franja superior) se desenfoca un poco
	float dof = (1.0 - smoothstep(0.10, 0.40, uv.y)) * dof_amt;
	float lod = dof * 1.8;
	// aberracion cromatica: casi nula al centro, crece hacia los bordes
	float ca = 0.0004 + r2 * r2 * 0.05 + r2 * 0.0035 + hurt * 0.004;
	vec3 col;
	col.r = textureLod(screen_tex, uv + d * ca, lod).r;
	col.g = textureLod(screen_tex, uv, lod).g;
	col.b = textureLod(screen_tex, uv - d * ca, lod).b;

	// bloom
	col += bloom(uv) * bloom_amt;

	// correccion de color: contraste en S, saturacion y tono dividido (sombras frias, luces calidas)
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 1.14);
	col = mix(col, col * col * (3.0 - 2.0 * col), 0.30);
	float sh = 1.0 - smoothstep(0.0, 0.45, luma);
	float hi = smoothstep(0.4, 0.95, luma);
	col *= mix(vec3(1.0), vec3(0.88, 0.99, 1.14), sh * 0.55);
	col *= mix(vec3(1.0), vec3(1.10, 1.0, 0.86), hi * 0.5);
	// recorte suave de altas luces
	vec3 over = max(col - 0.82, vec3(0.0));
	col = min(col, vec3(0.82)) + 0.18 * (vec3(1.0) - exp(-over / 0.18));

	col *= 1.0 - smoothstep(0.14, 0.7, r2) * 0.55;
	float g = hash(FRAGCOORD.xy + fract(time_s) * 97.0) - 0.5;
	col += g * grain_amt * (1.0 - 0.5 * luma);
	col = mix(col, vec3(1.0, 0.9, 0.75), clamp(flash, 0.0, 0.6));
	col += vec3(hurt * smoothstep(0.08, 0.55, r2) * 0.95, 0.0, 0.0);
	COLOR = vec4(col, 1.0);
}
