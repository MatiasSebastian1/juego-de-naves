shader_type canvas_item;
render_mode unshaded;

// Sombra proyectada: usa solo el alfa del sprite, borroso por mip (se difumina con la distancia a los pies).
// UV.y = 1 en la base del sprite (pies); la copia esta volteada, asi que la cabeza queda lejos de los pies.
uniform float blur = 1.6;
uniform vec3 tint = vec3(0.03, 0.01, 0.05);

void fragment() {
	float a = textureLod(TEXTURE, UV, blur).a;
	float far = clamp(1.0 - UV.y, 0.0, 1.0);
	float fade = mix(1.0, 0.18, far);
	COLOR = vec4(tint, a * fade * COLOR.a);
}
