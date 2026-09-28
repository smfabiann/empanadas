extends Control
## Menú principal del juego.
## Proporciona inicio de partida, visualización de récord y controles.

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var high_score_label: Label = $CenterContainer/MainPanel/VBoxContainer/HighScoreLabel
@onready var play_button: Button = $CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/PlayButton
@onready var quit_button: Button = $CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/QuitButton


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)
	_update_high_score()
	_animate_entrance()


func _animate_entrance() -> void:
	# Animamos la opacidad del panel general de manera limpia
	# Evitamos manipular posiciones individuales de hijos dentro de contenedores VBoxContainer
	main_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(main_panel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _update_high_score() -> void:
	if GameManager.high_score > 0:
		high_score_label.text = "🏆 Récord Actual: " + str(GameManager.high_score) + " pts"
		high_score_label.visible = true
	else:
		high_score_label.text = ""
		high_score_label.visible = false


func _on_play() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit() -> void:
	get_tree().quit()
