extends Control
## Menú principal del juego con estilo R.E.P.O.
## Proporciona navegación al juego, opciones y créditos.

@onready var buttons_margin: Control = %ButtonsMargin
@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var credits_button: Button = %CreditsButton
@onready var quit_button: Button = %QuitButton
@onready var credits_modal: Control = %CreditsModal
@onready var close_credits_button: Button = %CloseCreditsButton
@onready var options_menu: Control = %OptionsMenu


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Iniciar ambiente sonoro nocturno
	if SFXManager and SFXManager.has_method("start_ambience"):
		SFXManager.start_ambience()

	# Conexión de señales de botones principales
	play_button.pressed.connect(_on_play)
	options_button.pressed.connect(_on_options_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit)

	# Conexión de modales
	close_credits_button.pressed.connect(_on_close_credits_pressed)
	options_menu.closed.connect(_on_options_closed)

	credits_modal.visible = false
	options_menu.visible = false

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
	# Animación suave de entrada de los botones
	buttons_margin.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(buttons_margin, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _on_play() -> void:
	GameManager.reset_game()
	GameManager.show_intro = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_options_pressed() -> void:
	options_menu.open_menu()


func _on_options_closed() -> void:
	options_menu.visible = false


func _on_credits_pressed() -> void:
	credits_modal.visible = true


func _on_close_credits_pressed() -> void:
	credits_modal.visible = false


func _on_quit() -> void:
	get_tree().quit()
