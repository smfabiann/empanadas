extends Label
## Texto flotante que sube y se desvanece. Se auto-destruye al terminar.

var rise_speed: float = 60.0
var fade_duration: float = 1.2
var elapsed: float = 0.0


func _ready() -> void:
	# Centrar el texto
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func setup(text_content: String, color: Color = Color.WHITE, font_size_val: int = 24) -> void:
	text = text_content
	add_theme_color_override("font_color", color)
	add_theme_font_size_override("font_size", font_size_val)


func _process(delta: float) -> void:
	elapsed += delta

	# Subir
	position.y -= rise_speed * delta

	# Fade out
	var alpha := 1.0 - (elapsed / fade_duration)
	modulate.a = maxf(alpha, 0.0)

	if elapsed >= fade_duration:
		queue_free()
