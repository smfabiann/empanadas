extends Control
## Menú de pausa del juego.
## Se activa con ESC. Pausa todo el árbol de escena excepto este nodo.

@onready var resume_button: Button = $PanelContainer/VBoxContainer/ResumeButton
@onready var restart_button: Button = $PanelContainer/VBoxContainer/RestartButton
@onready var menu_button: Button = $PanelContainer/VBoxContainer/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if get_tree().paused:
			_resume()
		elif GameManager.game_active:
			_pause()
		get_viewport().set_input_as_handled()


func _pause() -> void:
	visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _on_resume() -> void:
	_resume()


func _on_restart() -> void:
	_resume()
	GameManager.reset_game()
	get_tree().reload_current_scene()


func _on_menu() -> void:
	_resume()
	GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
