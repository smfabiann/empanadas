extends Node
## Autoload singleton que gestiona el estado global del juego.
## Maneja: score, vidas, combos, dificultad progresiva, estadísticas y high score persistente.

signal ui_updated(score: int, lives: int)
signal game_over_reached()
signal combo_updated(combo: int, multiplier: int)
signal difficulty_changed(level: int)
signal item_delivered()
signal order_result(is_correct: bool, points: int)
signal time_updated(elapsed: float)

# --- Estado del juego ---
var score: int = 0
var lives: int = 3
var game_active: bool = true

# --- Timer ---
var elapsed_time: float = 0.0

# --- Estadísticas ---
var total_deliveries: int = 0
var correct_deliveries: int = 0
var best_combo: int = 0

# --- Combo ---
var combo: int = 0
var combo_multiplier: int = 1
const MAX_MULTIPLIER := 4

# --- Dificultad ---
## 0 = Fácil, 1 = Medio, 2 = Difícil, 3 = Caótico
var difficulty_level: int = 0
const DIFFICULTY_THRESHOLDS := [0, 50, 150, 300]
const SPAWN_INTERVALS := [5.0, 4.0, 3.0, 2.0]
const PATIENCE_TIMES := [20.0, 16.0, 12.0, 9.0]

# --- High Score ---
var high_score: int = 0
const SAVE_PATH := "user://highscore.save"


func _ready() -> void:
	_load_high_score()


func _process(delta: float) -> void:
	if game_active:
		elapsed_time += delta
		time_updated.emit(elapsed_time)


func handle_order(is_correct: bool) -> void:
	"""Procesa el resultado de una entrega."""
	if not game_active:
		return

	var points := 0

	if is_correct:
		combo += 1
		combo_multiplier = mini(combo, MAX_MULTIPLIER)
		points = 10 * combo_multiplier
		score += points
		correct_deliveries += 1
		if combo > best_combo:
			best_combo = combo
	else:
		combo = 0
		combo_multiplier = 1
		lives -= 1

	total_deliveries += 1

	item_delivered.emit()
	combo_updated.emit(combo, combo_multiplier)
	ui_updated.emit(score, lives)
	order_result.emit(is_correct, points)

	# Verificar cambio de dificultad
	_check_difficulty()

	if lives <= 0:
		game_active = false
		_save_high_score()
		game_over_reached.emit()


func npc_timeout() -> void:
	"""Llamado cuando un NPC pierde la paciencia."""
	if not game_active:
		return
	combo = 0
	combo_multiplier = 1
	lives -= 1

	combo_updated.emit(combo, combo_multiplier)
	ui_updated.emit(score, lives)
	order_result.emit(false, 0)

	if lives <= 0:
		game_active = false
		_save_high_score()
		game_over_reached.emit()


func get_spawn_interval() -> float:
	return SPAWN_INTERVALS[difficulty_level]


func get_patience_time() -> float:
	return PATIENCE_TIMES[difficulty_level]


func reset_game() -> void:
	"""Reinicia las variables del juego."""
	score = 0
	lives = 3
	combo = 0
	combo_multiplier = 1
	difficulty_level = 0
	elapsed_time = 0.0
	total_deliveries = 0
	correct_deliveries = 0
	best_combo = 0
	game_active = true
	ui_updated.emit(score, lives)
	combo_updated.emit(combo, combo_multiplier)
	difficulty_changed.emit(difficulty_level)


func _check_difficulty() -> void:
	var new_level := 0
	for i in range(DIFFICULTY_THRESHOLDS.size() - 1, -1, -1):
		if score >= DIFFICULTY_THRESHOLDS[i]:
			new_level = i
			break
	if new_level != difficulty_level:
		difficulty_level = new_level
		difficulty_changed.emit(difficulty_level)


func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_64()
			file.close()


func _save_high_score() -> void:
	if score > high_score:
		high_score = score
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_64(high_score)
		file.close()
