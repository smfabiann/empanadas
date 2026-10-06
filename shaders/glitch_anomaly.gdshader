shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_jitter : hint_range(0.0, 1.0) = 0.25;
uniform vec4 tint_color : source_color = vec4(1.0, 0.1, 0.2, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	
	// Desplazamiento horizontal por bandas de escaneo (jitter)
	if (scanline_jitter > 0.0) {
		float slice = sin(uv.y * 80.0 + TIME * 20.0);
		if (slice > 0.6) {
			uv.x += (slice - 0.6) * 0.04 * scanline_jitter;
		}
	}
	
	// Aberración cromática (separación de canales R y B)
	float split = 0.02 * glitch_intensity;
	float r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, uv - vec2(split, 0.0)).b;
	float a = texture(TEXTURE, uv).a;
	
	vec4 base_color = vec4(r, g, b, a);
	
	// Mezcla con tinte anormal
	vec4 final_color = mix(base_color, vec4(tint_color.rgb, base_color.a), tint_mix);
	COLOR = final_color * COLOR;
}
