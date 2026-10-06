shader_type canvas_item;

// Capas de fondo / primer plano: tinte, desenfoque por mip (profundidad de campo) y bruma atmosferica.
uniform vec4 tint : source_color = vec4(1.0);
uniform float blur = 0.0;
uniform float haze = 0.0;
uniform vec3 haze_col : source_color = vec3(0.85, 0.5, 0.5);

void fragment() {
	vec4 c = textureLod(TEXTURE, UV, blur);
	c.rgb = mix(c.rgb, haze_col * max(c.a, 0.0), haze);
	COLOR = c * tint * COLOR;
}
