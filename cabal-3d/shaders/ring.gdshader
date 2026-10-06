shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

// Anillo de aviso en el suelo (impacto de granada) y onda expansiva.
uniform vec4 color : source_color = vec4(1.0, 0.25, 0.1, 1.0);
uniform float fill = 0.12;      // relleno interior tenue
uniform float pulse = 0.0;      // 0..1 progreso
uniform float width = 0.08;
uniform float strength = 1.0;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	float edge = smoothstep(width, 0.0, abs(d - 0.93));
	float inner = smoothstep(width * 2.0, 0.0, abs(d - (0.93 * pulse)));
	float disc = (1.0 - smoothstep(0.85, 1.0, d)) * fill;
	float a = (edge + inner * 0.8 + disc) * step(d, 1.0) * strength;
	ALBEDO = color.rgb * a;
	ALPHA = clamp(a, 0.0, 1.0);
}
