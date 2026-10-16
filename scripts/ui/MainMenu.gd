extends Control
## Menú principal del juego.
## Proporciona inicio de partida, visualización de récord y controles.

@onready var main_panel: PanelContainer = $CenterContainer/MainPanel
@onready var high_score_label: Label = $CenterContainer/MainPanel/VBoxContainer/HighScoreLabel
@onready var play_button: Button = $CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/PlayButton
@onready var credits_button: Button = $CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/CreditsButton
@onready var options_button: Button = $CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/OptionsButton
@onready var quit_button: Button = $CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/QuitButton
@onready var credits_modal: Control = $CreditsModal
@onready var close_credits_button: Button = $CreditsModal/CenterContainer/CreditsPanel/VBoxContainer/CloseCreditsButton
@onready var options_menu: Control = $OptionsMenu


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	play_button.pressed.connect(_on_play)
	credits_button.pressed.connect(_on_credits_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit)
	close_credits_button.pressed.connect(_on_close_credits_pressed)
	options_menu.closed.connect(_on_options_closed)
	credits_modal.visible = false
	options_menu.visible = false
	_update_high_score()
	_animate_entrance()


func _input(event: InputEvent) -> void:
	if options_menu.visible:
		if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_on_options_closed()
			get_viewport().set_input_as_handled()
	elif credits_modal.visible:
		if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
			_on_close_credits_pressed()
			get_viewport().set_input_as_handled()


func _animate_entrance() -> void:
	# Animamos la opacidad del panel general de manera limpia
	# Evitamos manipular posiciones individuales de hijos dentro de contenedores VBoxContainer
	main_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(main_panel, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _update_high_score() -> void:
	high_score_label.visible = false


func _on_play() -> void:
	GameManager.reset_game()
	GameManager.show_intro = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_credits_pressed() -> void:
	credits_modal.visible = true


func _on_close_credits_pressed() -> void:
	credits_modal.visible = false


func _on_options_pressed() -> void:
	options_menu.open_menu()


func _on_options_closed() -> void:
	options_menu.visible = false


func _on_quit() -> void:
	get_tree().quit()

