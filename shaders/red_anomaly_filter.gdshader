shader_type canvas_item;

// Filtro rojo de pantalla completa para anomalías (post-procesado en CanvasLayer)
// Captura la escena renderizada (mundo 3D + cielo procedural) y aplica un tinte uniforme
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// Intensidad global del filtro (0.0 = imagen original sin alterar, 1.0 = filtro completo)
uniform float filter_intensity : hint_range(0.0, 1.0) = 0.0;

// Color del tinte de la anomalía
uniform vec4 filter_color : source_color = vec4(0.85, 0.05, 0.1, 1.0);

// Fuerza de la viñeta perimetral (oscurecimiento en las esquinas)
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.65;

// Velocidad del pulso respiratorio espectral
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

// Amplitud del pulso respiratorio
uniform float pulse_strength : hint_range(0.0, 0.5) = 0.07;

void fragment() {
	vec4 screen_col = texture(screen_texture, SCREEN_UV);

	// 1. Viñeta perimetral centrada para sensación claustrofóbica / horror
	vec2 center_uv = SCREEN_UV - vec2(0.5);
	float dist = length(center_uv);
	float vignette = smoothstep(0.25, 0.85, dist) * vignette_strength;

	// 2. Pulso sutil de respiración durante la manifestación
	float pulse = 1.0 + sin(TIME * pulse_speed) * pulse_strength;

	// 3. Tinte rojo estilizado:
	// Preserva los brillos y fuentes de luz, tiñendo tonos medios y sombras
	float lum = dot(screen_col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 red_tinted = mix(
		screen_col.rgb,
		screen_col.rgb * 0.35 + filter_color.rgb * lum * 1.35,
		0.75
	);

	// 4. Aplicar viñeta oscura/rojiza en los bordes
	vec3 with_vignette = mix(red_tinted, filter_color.rgb * 0.18, vignette);

	// 5. Mezcla final con la escena original según filter_intensity
	vec3 final_rgb = mix(screen_col.rgb, with_vignette * pulse, filter_intensity);

	COLOR = vec4(final_rgb, 1.0);
}
