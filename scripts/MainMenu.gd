extends Control
## Menú principal del juego.

@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)
	_update_high_score()


func _update_high_score() -> void:
	if GameManager.high_score > 0:
		high_score_label.text = "Mejor Puntaje: " + str(GameManager.high_score)
	else:
		high_score_label.text = ""


func _on_play() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit() -> void:
	get_tree().quit()
