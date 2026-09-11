extends Control
## Menú principal del juego.
## Incluye animación de entrada para dar una presentación pulida.

@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var vbox: VBoxContainer = $VBoxContainer


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play)
	quit_button.pressed.connect(_on_quit)
	_update_high_score()
	_animate_entrance()


func _animate_entrance() -> void:
	"""Anima la entrada secuencial de los elementos del menú."""
	for i in vbox.get_child_count():
		var child := vbox.get_child(i)
		child.modulate.a = 0.0
		child.position.y += 20.0
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "modulate:a", 1.0, 0.4).set_delay(i * 0.12).set_ease(Tween.EASE_OUT)
		tween.tween_property(child, "position:y", child.position.y - 20.0, 0.4).set_delay(i * 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)


func _update_high_score() -> void:
	if GameManager.high_score > 0:
		high_score_label.text = "🏆 Mejor Puntaje: " + str(GameManager.high_score)
	else:
		high_score_label.text = ""


func _on_play() -> void:
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit() -> void:
	get_tree().quit()
