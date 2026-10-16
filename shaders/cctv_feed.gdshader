shader_type canvas_item;
// Filtro de monitor de seguridad (CCTV): líneas de escaneo, grano, viñeta e interferencia.
// `interference` (0..1) lo controlan los eventos de cámara (ej. fallo eléctrico) y el cambio de canal.

uniform float scanline_strength : hint_range(0.0, 1.0) = 0.18;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.06;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.55;
uniform float interference : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Líneas de escaneo horizontales que se desplazan lentamente
	float scan = 0.5 + 0.5 * sin((uv.y + t * 0.02) * 900.0);
	float alpha = scan * scanline_strength;
	vec3 col = vec3(0.0);

	// Grano fino permanente
	float g = hash(floor(FRAGCOORD.xy * 0.5) + vec2(floor(t * 24.0)));
	col = mix(col, vec3(g), grain_strength);
	alpha = max(alpha, grain_strength * g);

	// Viñeta oscura en los bordes
	float d = distance(uv, vec2(0.5));
	alpha = max(alpha, smoothstep(0.45, 0.85, d) * vignette_strength);

	// Interferencia: estática gruesa y bandas que saltan
	if (interference > 0.0) {
		float block = hash(vec2(floor(uv.y * 60.0), floor(t * 18.0)));
		float n = hash(floor(FRAGCOORD.xy * 0.33) + vec2(floor(t * 30.0) * 7.0));
		float band = step(1.0 - interference * 0.35, block);
		vec3 stat = vec3(n);
		float a = clamp(interference * (0.55 + 0.45 * n) + band * 0.6, 0.0, 1.0);
		col = mix(col, stat, a);
		alpha = max(alpha, a);
	}

	COLOR = vec4(col, alpha);
}
