shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.01, 0.02, 0.05); // Noche profunda
uniform vec3 horizon_color : source_color = vec3(0.06, 0.08, 0.14); // Resplandor de ciudad / horizonte nocturno
uniform vec3 ground_color : source_color = vec3(0.01, 0.015, 0.02);  // Base bajo el horizonte
uniform float star_density : hint_range(20.0, 500.0, 1.0) = 65.0;
uniform float star_threshold : hint_range(0.95, 0.9999, 0.0005) = 0.993; // Mayor umbral = menos estrellas
uniform float star_brightness : hint_range(0.1, 10.0, 0.1) = 2.0;

// Generador de ruido hash para estrellas procedimentales
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	// 1. Degradado del cielo (Horizonte urbano hacia arriba)
	float h = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, sky_top_color, pow(h, 0.4));

	// Degradado hacia el suelo bajo el horizonte
	if (EYEDIR.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-EYEDIR.y * 2.5, 0.0, 1.0));
	}

	// 2. Estrellas en el domo superior (cantidad moderada y limpia)
	if (EYEDIR.y > 0.03) {
		float city_glow_fade = smoothstep(0.03, 0.22, EYEDIR.y);

		vec2 sky_uv = EYEDIR.xz / (EYEDIR.y + 0.25) * star_density;
		vec2 cell_id = floor(sky_uv);
		float n = hash(cell_id);

		if (n > star_threshold) {
			vec2 star_pos = fract(sky_uv) - 0.5;
			float dist = length(star_pos);
			float star_size = 0.26 + (n - star_threshold) / (1.0 - star_threshold) * 0.18;
			float star_point = smoothstep(star_size, 0.0, dist);

			// Variación sutil de color y brillo
			float hue_rand = hash(cell_id + vec2(7.3, 11.1));
			vec3 star_color = mix(vec3(0.9, 0.94, 1.0), vec3(1.0, 0.96, 0.85), hue_rand);

			col += star_color * (star_point * star_brightness * city_glow_fade * (0.7 + 0.3 * n));
		}
	}

	COLOR = col;
}
