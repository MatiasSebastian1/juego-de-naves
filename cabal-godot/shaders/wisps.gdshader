shader_type canvas_item;
render_mode unshaded;

// Nubes finas que derivan lentamente (ruido repetible desplazado con TIME).
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec3 col_a : source_color = vec3(1.0, 0.62, 0.5);
uniform vec3 col_b : source_color = vec3(0.55, 0.3, 0.45);
uniform float speed = 0.004;
uniform float amount = 0.3;

void fragment() {
	vec2 uv = UV * vec2(2.5, 0.9);
	float n1 = texture(noise, uv + vec2(TIME * speed, 0.0)).r;
	float n2 = texture(noise, uv * 1.9 + vec2(-TIME * speed * 0.55, 0.37)).r;
	float m = smoothstep(0.52, 0.86, n1 * 0.62 + n2 * 0.48);
	float band = smoothstep(0.0, 0.25, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	COLOR = vec4(mix(col_a, col_b, n2), m * band * amount);
}
