extends Control
## Menú de pausa del juego.
## Se activa con ESC. Pausa todo el árbol de escena excepto este nodo.

@onready var panel_container: PanelContainer = $PanelContainer
@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var options_button: Button = $PanelContainer/VBoxContainer/OptionsButton
@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $PanelContainer/VBoxContainer/MenuButton
@onready var options_menu: Control = $OptionsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if options_menu:
		options_menu.visible = false
		options_menu.closed.connect(_on_options_closed)

	resume_button.pressed.connect(_on_resume)
	options_button.pressed.connect(_on_options)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if options_menu and options_menu.visible:
			_on_options_closed()
			get_viewport().set_input_as_handled()
		elif get_tree().paused:
			_resume()
			get_viewport().set_input_as_handled()
		elif GameManager.can_player_act():
			_pause()
			get_viewport().set_input_as_handled()


func _pause() -> void:
	panel_container.visible = true
	if options_menu:
		options_menu.visible = false
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume() -> void:
	if options_menu:
		options_menu.visible = false
	panel_container.visible = true
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume() -> void:
	_resume()


func _on_options() -> void:
	panel_container.visible = false
	if options_menu:
		options_menu.open_menu()


func _on_options_closed() -> void:
	if options_menu:
		options_menu.visible = false
	panel_container.visible = true


func _on_restart() -> void:
	_resume()
	GameManager.reset_game()
	get_tree().reload_current_scene()


func _on_menu() -> void:
	_resume()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
