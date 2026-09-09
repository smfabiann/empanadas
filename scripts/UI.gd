extends CanvasLayer
## HUD del juego: puntuación, vidas, combo, crosshair, feedback y Game Over.

@onready var score_label: Label = $HUD/ScoreLabel
@onready var lives_label: Label = $HUD/LivesLabel
@onready var combo_label: Label = $HUD/ComboLabel
@onready var difficulty_label: Label = $HUD/DifficultyLabel
@onready var crosshair: ColorRect = $HUD/Crosshair
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var damage_flash: ColorRect = $HUD/DamageFlash
@onready var game_over_panel: PanelContainer = $HUD/GameOverPanel
@onready var game_over_score: Label = $HUD/GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var game_over_highscore: Label = $HUD/GameOverPanel/VBoxContainer/HighScoreLabel
@onready var retry_button: Button = $HUD/GameOverPanel/VBoxContainer/RetryButton
@onready var menu_button: Button = $HUD/GameOverPanel/VBoxContainer/MenuButton
@onready var floating_text_container: Control = $HUD/FloatingTextContainer

var floating_text_scene: PackedScene = preload("res://scenes/ui/FloatingText.tscn")

const DIFFICULTY_NAMES := ["Fácil", "Medio", "Difícil", "¡CAÓTICO!"]
const DIFFICULTY_COLORS: Array[Color] = [
	Color(0.3, 0.8, 0.3, 1),
	Color(0.9, 0.8, 0.1, 1),
	Color(0.9, 0.4, 0.1, 1),
	Color(0.9, 0.1, 0.1, 1),
]


func _ready() -> void:
	game_over_panel.visible = false
	damage_flash.visible = false
	damage_flash.modulate.a = 0.0
	combo_label.visible = false

	GameManager.ui_updated.connect(_on_ui_updated)
	GameManager.game_over_reached.connect(_on_game_over)
	GameManager.combo_updated.connect(_on_combo_updated)
	GameManager.difficulty_changed.connect(_on_difficulty_changed)
	GameManager.order_result.connect(_on_order_result)

	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

	_on_ui_updated(GameManager.score, GameManager.lives)
	_on_difficulty_changed(GameManager.difficulty_level)


func _on_ui_updated(score: int, lives: int) -> void:
	score_label.text = "⭐ " + str(score)
	lives_label.text = "❤️ " + str(lives)


func _on_combo_updated(combo_count: int, multiplier: int) -> void:
	if multiplier > 1:
		combo_label.visible = true
		combo_label.text = "🔥 x" + str(multiplier)
		# Animación de escala
		combo_label.scale = Vector2(1.5, 1.5)
		var tween := create_tween()
		tween.tween_property(combo_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT)
	else:
		combo_label.visible = false


func _on_difficulty_changed(level: int) -> void:
	difficulty_label.text = DIFFICULTY_NAMES[level]
	difficulty_label.add_theme_color_override("font_color", DIFFICULTY_COLORS[level])


func _on_order_result(is_correct: bool, points: int) -> void:
	if is_correct:
		_spawn_floating_text("+" + str(points), Color(0.2, 1.0, 0.3, 1))
		if GameManager.combo_multiplier > 1:
			_spawn_floating_text("¡Combo x" + str(GameManager.combo_multiplier) + "!", Color(1.0, 0.85, 0.1, 1), 20, Vector2(0, 25))
	else:
		_spawn_floating_text("-1 ❤️", Color(1.0, 0.2, 0.2, 1))
		_flash_damage()


func _spawn_floating_text(text: String, color: Color, size: int = 28, offset: Vector2 = Vector2.ZERO) -> void:
	var ft = floating_text_scene.instantiate()
	floating_text_container.add_child(ft)
	ft.setup(text, color, size)
	ft.position = Vector2(0, 0) + offset


func _flash_damage() -> void:
	damage_flash.visible = true
	damage_flash.modulate.a = 0.4
	var tween := create_tween()
	tween.tween_property(damage_flash, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): damage_flash.visible = false)


func _on_game_over() -> void:
	game_over_panel.visible = true
	game_over_score.text = "Puntaje: " + str(GameManager.score)

	if GameManager.score >= GameManager.high_score:
		game_over_highscore.text = "🏆 ¡NUEVO RÉCORD! 🏆"
		game_over_highscore.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1))
	else:
		game_over_highscore.text = "Mejor: " + str(GameManager.high_score)
		game_over_highscore.add_theme_color_override("font_color", Color(0.7, 0.65, 0.8, 1))

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SFXManager.play_game_over()


func _on_retry_pressed() -> void:
	game_over_panel.visible = false
	GameManager.reset_game()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func set_prompt(text: String, is_interactable: bool = false) -> void:
	if prompt_label:
		prompt_label.text = text
	if crosshair:
		if is_interactable:
			crosshair.color = Color(1.0, 0.85, 0.2, 1.0)
			crosshair.scale = Vector2(1.5, 1.5)
		else:
			crosshair.color = Color(1.0, 1.0, 1.0, 0.6)
			crosshair.scale = Vector2(1.0, 1.0)
