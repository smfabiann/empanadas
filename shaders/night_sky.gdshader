shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.01, 0.02, 0.05); // Noche profunda
uniform vec3 horizon_color : source_color = vec3(0.12, 0.07, 0.03); // Resplandor de ciudad
uniform vec3 ground_color : source_color = vec3(0.01, 0.015, 0.02);  // Base bajo el horizonte
uniform float star_density : hint_range(20.0, 500.0, 1.0) = 80.0;
uniform float star_threshold : hint_range(0.95, 0.9999, 0.0005) = 0.998; // Mayor umbral = menos estrellas (ciudad)
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

	// 2. Estrellas en el domo superior
	if (EYEDIR.y > 0.02) {
		vec2 sky_uv = EYEDIR.xz / (EYEDIR.y + 0.2) * star_density;
		float n = hash(floor(sky_uv));
		if (n > star_threshold) {
			float star = smoothstep(star_threshold, 1.0, n);
			// Atenuación suave cerca del horizonte por contaminación lumínica urbana
			float city_glow_fade = smoothstep(0.02, 0.25, EYEDIR.y);
			col += vec3(star * star_brightness * city_glow_fade); // Brillo HDR
		}
	}

	COLOR = col;
}
