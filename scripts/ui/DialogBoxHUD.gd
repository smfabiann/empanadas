class_name DialogBoxHUD
extends Control
## Caja de diálogo modular estilo HUD (Undertale-like):
## - Fondo negro con borde blanco y texto blanco (soporta BBCode)
## - Efecto máquina de escribir (typewriter) por carácter
## - Audio "crunchy" posicional (usa el AudioStreamPlayer3D del NPC si se entrega, o fallback 2D)

signal dialog_opened()
signal dialog_closed()
signal line_started(line_index: int, text: String)
signal line_finished(line_index: int)

@export_group("Design")
@export var default_text_color: Color = Color.WHITE
@export var default_bg_color: Color = Color(0.0, 0.0, 0.0, 0.94)
@export var default_border_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var border_width: int = 3
@export var corner_radius: int = 4
@export var font_size: int = 24
@export var speaker_color: Color = Color(1.0, 0.9, 0.35, 1.0)

@export_group("Typewriter")
@export var default_char_delay: float = 0.026
@export var punctuation_pause: float = 0.07

@export_group("Audio")
@export var audio_enabled: bool = true
@export var default_voice_pitch: float = 1.0
@export_range(0.0, 0.4, 0.01) var pitch_jitter: float = 0.12
@export_range(1, 6) var chars_per_blip: int = 2
@export_range(0.0, 1.0, 0.05) var crunch_amount: float = 0.78
@export var custom_voice_stream: AudioStream = null

@onready var panel: PanelContainer = $PanelContainer
@onready var speaker_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpeakerLabel
@onready var rich_label: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/DialogText
@onready var continue_hint: Label = $PanelContainer/MarginContainer/VBoxContainer/ContinueHint
@onready var fallback_player: AudioStreamPlayer = $FallbackVoicePlayer

var _panel_style: StyleBoxFlat = null
var _crunchy_stream: AudioStreamWAV = null

var _lines: Array[String] = []
var _current_index: int = 0
var _options: Dictionary = {}
var _type_token: int = 0
var _is_typing: bool = false
var _is_open: bool = false


func _ready() -> void:
	_setup_styles()
	_crunchy_stream = build_crunchy_blip(crunch_amount)
	if fallback_player:
		fallback_player.stream = custom_voice_stream if custom_voice_stream else _crunchy_stream
	visible = false


func _setup_styles() -> void:
	if panel:
		_panel_style = StyleBoxFlat.new()
		_panel_style.bg_color = default_bg_color
		_panel_style.border_color = default_border_color
		_panel_style.set_border_width_all(border_width)
		_panel_style.set_corner_radius_all(corner_radius)
		panel.add_theme_stylebox_override("panel", _panel_style)

	if speaker_label:
		speaker_label.add_theme_color_override("font_color", speaker_color)

	if rich_label:
		rich_label.bbcode_enabled = true
		rich_label.add_theme_color_override("default_color", default_text_color)
		rich_label.add_theme_font_size_override("normal_font_size", font_size)


## Abre la caja de diálogo con una lista de líneas y opciones de diseño/audio.
## options soporta:
## - "speaker": String
## - "voice_player_3d": AudioStreamPlayer3D (audio posicional del NPC)
## - "text_color": Color
## - "bg_color": Color
## - "border_color": Color
## - "char_delay": float
## - "audio": bool
## - "pitch": float
## - "stream": AudioStream
func open_dialog(lines: Array, options: Dictionary = {}) -> void:
	_lines.clear()
	for line in lines:
		_lines.append(String(line))
	if _lines.is_empty():
		return

	_options = options
	_current_index = 0
	_is_open = true
	visible = true

	var text_col: Color = options.get("text_color", default_text_color)
	var bg_col: Color = options.get("bg_color", default_bg_color)
	var border_col: Color = options.get("border_color", default_border_color)
	set_colors(text_col, bg_col, border_col)

	var speaker_name: String = String(options.get("speaker", ""))
	if speaker_label:
		speaker_label.text = speaker_name
		speaker_label.visible = not speaker_name.is_empty()

	dialog_opened.emit()
	_show_line(_current_index)


## Si está escribiendo, completa la línea al instante.
## Si ya terminó la línea, avanza a la siguiente o cierra el diálogo.
## Devuelve true si el diálogo sigue abierto, false si se cerró.
func advance_or_skip() -> bool:
	if not _is_open:
		return false
	if _is_typing:
		skip_typewriter()
		return true
	_current_index += 1
	if _current_index < _lines.size():
		_show_line(_current_index)
		return true
	close_dialog()
	return false


func skip_typewriter() -> void:
	_type_token += 1
	_is_typing = false
	if rich_label:
		rich_label.visible_characters = -1
	_update_continue_hint(true)
	line_finished.emit(_current_index)


func close_dialog() -> void:
	if not _is_open and not visible:
		return
	_type_token += 1
	_is_typing = false
	_is_open = false
	visible = false
	_stop_voice()
	dialog_closed.emit()


func is_open() -> bool:
	return _is_open


func set_colors(
	text_color: Color,
	bg_color: Color = default_bg_color,
	border_color: Color = default_border_color
) -> void:
	if rich_label:
		rich_label.add_theme_color_override("default_color", text_color)
	if _panel_style:
		_panel_style.bg_color = bg_color
		_panel_style.border_color = border_color


func _show_line(index: int) -> void:
	if index < 0 or index >= _lines.size() or rich_label == null:
		return

	_type_token += 1
	var token := _type_token
	var line_text := _lines[index]

	var char_delay: float = float(_options.get("char_delay", default_char_delay))
	var use_audio: bool = bool(_options.get("audio", audio_enabled))
	var base_pitch: float = float(_options.get("pitch", default_voice_pitch))

	_prepare_voice_stream()
	rich_label.text = line_text
	_update_continue_hint(false)
	line_started.emit(index, line_text)

	var plain := rich_label.get_parsed_text()
	var total_chars := plain.length()

	if char_delay <= 0.0 or not is_inside_tree() or total_chars == 0:
		rich_label.visible_characters = -1
		_is_typing = false
		_update_continue_hint(true)
		line_finished.emit(index)
		return

	rich_label.visible_characters = 0
	_is_typing = true

	var non_space_count := 0
	for i in range(total_chars):
		if token != _type_token or not is_instance_valid(self) or not is_inside_tree():
			return

		rich_label.visible_characters = i + 1

		var ch := plain.substr(i, 1)
		var is_space := ch == " " or ch == "\n" or ch == "\t"
		if not is_space:
			if use_audio and (non_space_count % maxi(1, chars_per_blip) == 0):
				_play_blip(base_pitch)
			non_space_count += 1

		var wait_time := char_delay
		if ch in [".", "!", "?", "\n"]:
			wait_time += punctuation_pause

		await get_tree().create_timer(wait_time).timeout

	if token == _type_token and is_instance_valid(self):
		rich_label.visible_characters = -1
		_is_typing = false
		_update_continue_hint(true)
		line_finished.emit(index)


func _update_continue_hint(finished: bool) -> void:
	if continue_hint == null:
		return
	if not finished:
		continue_hint.text = "[E] Saltar"
		continue_hint.modulate = Color(0.65, 0.65, 0.65, 0.85)
	elif _current_index + 1 < _lines.size():
		continue_hint.text = "[E] Siguiente ▼"
		continue_hint.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		continue_hint.text = "[E] Cerrar"
		continue_hint.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _prepare_voice_stream() -> void:
	var stream_to_use: AudioStream = _options.get("stream", null)
	if stream_to_use == null:
		stream_to_use = custom_voice_stream if custom_voice_stream else _crunchy_stream

	var player_3d := _options.get("voice_player_3d", null) as AudioStreamPlayer3D
	if player_3d and is_instance_valid(player_3d):
		player_3d.stream = stream_to_use
	elif fallback_player:
		fallback_player.stream = stream_to_use


func _play_blip(base_pitch: float) -> void:
	var pitch := maxf(0.25, base_pitch + randf_range(-pitch_jitter, pitch_jitter))
	var player_3d := _options.get("voice_player_3d", null) as AudioStreamPlayer3D
	if player_3d and is_instance_valid(player_3d) and player_3d.is_inside_tree() and player_3d.stream != null:
		player_3d.pitch_scale = pitch
		player_3d.play()
		return
	if fallback_player and fallback_player.stream != null:
		fallback_player.pitch_scale = pitch
		fallback_player.play()


func _stop_voice() -> void:
	var player_3d := _options.get("voice_player_3d", null) as AudioStreamPlayer3D
	if player_3d and is_instance_valid(player_3d) and player_3d.playing:
		player_3d.stop()
	if fallback_player and fallback_player.playing:
		fallback_player.stop()


## Genera un blip corto y "crunchy" (8 kHz + onda cuadrada + ruido + cuantización)
static func build_crunchy_blip(crunch: float = 0.78, base_freq: float = 260.0) -> AudioStreamWAV:
	var rate := 8000
	var duration := 0.042
	var count := int(rate * duration)
	var data := PackedByteArray()
	data.resize(count * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	var quant_levels := lerpf(32.0, 5.0, clampf(crunch, 0.0, 1.0))

	for i in count:
		var t := float(i) / rate
		var env := 1.0 - (float(i) / count)
		var square := 1.0 if sin(TAU * base_freq * t) >= 0.0 else -1.0
		var noise := rng.randf_range(-1.0, 1.0)
		var raw := (square * 0.55 + noise * 0.45) * env
		var crushed := roundf(raw * quant_levels) / quant_levels
		var sample := clampf(crushed * 0.65, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
