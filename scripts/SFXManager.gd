extends Node
## Autoload singleton para efectos de sonido procedurales.
## Genera tonos simples sin necesidad de archivos de audio externos.

var _players: Array[AudioStreamPlayer] = []
const POOL_SIZE := 6


func _ready() -> void:
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)


func play_pickup() -> void:
	_play_tone(660.0, 0.08)


func play_correct() -> void:
	_play_sequence([523.25, 659.25, 783.99], 0.08)


func play_victory() -> void:
	_play_sequence([523.25, 659.25, 783.99, 1046.50], 0.12)


func play_incorrect() -> void:
	_play_sequence([200.0, 150.0], 0.15)


func play_combo(level: int) -> void:
	var base_freq := 700.0 + (level * 100.0)
	_play_sequence([base_freq, base_freq * 1.25, base_freq * 1.5], 0.06)


func play_game_over() -> void:
	_play_sequence([400.0, 350.0, 300.0, 200.0], 0.2)


func play_gunshot() -> void:
	_play_sequence([220.0, 110.0, 55.0], 0.06)


func play_tense_anger() -> void:
	_play_sequence([125.0, 105.0, 85.0, 65.0], 0.35)


## Estallido sónico / salida de hiperespacio (Star Wars shock boom)
func play_sonic_boom() -> void:
	var player := _get_available_player()
	if player == null:
		return

	var duration := 0.85
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05

	player.stream = stream
	player.volume_db = -1.5
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(22050.0 * duration)
	var phase := 0.0

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var freq := lerpf(360.0, 36.0, pow(t, 0.38))
		var increment := freq / 22050.0
		var noise := randf_range(-0.45, 0.45) if t < 0.09 else 0.0
		var tone := sin(phase * TAU) * 0.65
		var envelope := pow(1.0 - t, 1.8)
		var sample: float = (tone + noise) * envelope

		playback.push_frame(Vector2(sample, sample))
		phase += increment
		if phase >= 1.0:
			phase -= 1.0


## Vibración / zumbido cósmico premonitorio
func play_cosmic_rumble(duration: float = 2.2) -> void:
	var player := _get_available_player()
	if player == null:
		return

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05

	player.stream = stream
	player.volume_db = -3.5
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(22050.0 * duration)
	var phase1 := 0.0
	var phase2 := 0.0

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var inc1 := 48.0 / 22050.0
		var inc2 := 56.0 / 22050.0
		var envelope := lerpf(0.15, 0.75, pow(t, 1.4))
		var pulse := 0.7 + 0.3 * sin(t * 22.0 * TAU)
		var sample: float = (sin(phase1 * TAU) * 0.5 + sin(phase2 * TAU) * 0.4) * envelope * pulse

		playback.push_frame(Vector2(sample, sample))
		phase1 += inc1
		if phase1 >= 1.0:
			phase1 -= 1.0
		phase2 += inc2
		if phase2 >= 1.0:
			phase2 -= 1.0


## Tono misterioso / suspenso alienígena tras el destello sónico
func play_alien_suspense(duration: float = 1.8) -> void:
	var player := _get_available_player()
	if player == null:
		return

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05

	player.stream = stream
	player.volume_db = -5.0
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(22050.0 * duration)
	var phase := 0.0

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var vibrato := sin(t * 7.5 * TAU) * 18.0
		var freq := 460.0 + vibrato
		var increment := freq / 22050.0
		var envelope := sin(t * PI)
		var sample: float = sin(phase * TAU) * 0.45 * envelope

		playback.push_frame(Vector2(sample, sample))
		phase += increment
		if phase >= 1.0:
			phase -= 1.0


func play_npc_arrive() -> void:
	_play_sequence([880.0, 1100.0], 0.05)


func play_npc_timeout() -> void:
	_play_sequence([300.0, 250.0, 200.0], 0.12)


func play_drop() -> void:
	_play_tone(330.0, 0.06)


## Sonido procedural de pedo / defecación para el baño químico
func play_fart() -> void:
	var player := _get_available_player()
	if player == null:
		return

	var duration := 0.48
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05

	player.stream = stream
	player.volume_db = 1.0
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(22050.0 * duration)
	var phase := 0.0

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var flutter := sin(t * 28.0 * TAU) * 18.0
		var freq := maxf(40.0, 95.0 - (t * 48.0) + flutter)
		var increment := freq / 22050.0
		var noise := randf_range(-0.2, 0.2)
		var buzz := (phase * 2.0 - 1.0) * 0.45
		var env := sin(t * PI)
		var sample := (buzz + noise * 0.25) * env * 0.7

		playback.push_frame(Vector2(sample, sample))
		phase += increment
		if phase >= 1.0:
			phase -= 1.0


## Sonido de asfixia y colapso letal del NPC al comer caca
func play_npc_death() -> void:
	_play_sequence([240.0, 180.0, 110.0, 55.0], 0.14)


func _play_tone(frequency: float, duration: float) -> void:
	var player := _get_available_player()
	if player == null:
		return

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = duration + 0.05

	player.stream = stream
	player.play()

	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var sample_count := int(22050.0 * duration)
	var phase := 0.0
	var increment := frequency / 22050.0

	for i in sample_count:
		var t := float(i) / float(sample_count)
		var envelope := 1.0 - t  # Linear fade out
		var sample := sin(phase * TAU) * 0.3 * envelope
		playback.push_frame(Vector2(sample, sample))
		phase += increment
		if phase >= 1.0:
			phase -= 1.0


func _play_sequence(frequencies: Array, note_duration: float) -> void:
	for i in frequencies.size():
		var freq: float = frequencies[i]
		# Use a timer to stagger the notes
		get_tree().create_timer(i * note_duration).timeout.connect(
			_play_tone.bind(freq, note_duration)
		)


func _get_available_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	# All busy, return the first one (will restart it)
	return _players[0]
