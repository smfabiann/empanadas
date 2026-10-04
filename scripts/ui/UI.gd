extends CanvasLayer
## UI minimalista para juego de terror / anomalías.
## Solo mira (crosshair), prompts contextuales de interacción, menú de pausa y herramientas de depuración.

@export_group("Debug")
## Activa o desactiva la visualización de contadores de depuración en la UI (arriba a la derecha)
@export var show_debug_counters: bool = true:
	set(value):
		show_debug_counters = value
		_update_debug_visibility()
## Tecla rápida para alternar la visibilidad de los contadores en tiempo de ejecución (por defecto F3)
@export var toggle_debug_key: Key = KEY_F3

@onready var crosshair: ColorRect = $HUD/Crosshair
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var debug_panel: PanelContainer = $HUD.get_node_or_null("DebugPanel")
@onready var debug_spawned_label: Label = $HUD.get_node_or_null("DebugPanel/DebugVBox/DebugSpawnedLabel")
@onready var debug_served_label: Label = $HUD.get_node_or_null("DebugPanel/DebugVBox/DebugServedLabel")

@onready var game_over_panel: PanelContainer = $HUD.get_node_or_null("GameOverPanel")
@onready var game_over_label: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/GameOverLabel")
@onready var final_score_label: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/FinalScoreLabel")
@onready var delivery_stat_label: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/DeliveryStatLabel")
@onready var retry_button: Button = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/RetryButton")
@onready var menu_button: Button = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/MenuButton")
@onready var damage_flash: ColorRect = $HUD.get_node_or_null("DamageFlash")


func _ready() -> void:
	# Ocultar todos los elementos de arcade / vidas / puntuación
	for node_name in [
			"ScoreLabel", 
			"LivesLabel",
			"ComboLabel",
			"DifficultyLabel",
			"TimeLabel",
			"GameOverPanel",
			"TutorialPanel",
			"DamageFlash",
			"SuccessFlash"
			]:
		var node = $HUD.get_node_or_null(node_name)
		if node:
			node.visible = false

	# Conectar botones del Game Over
	if retry_button:
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button:
		menu_button.pressed.connect(_on_menu_pressed)

	# Conectar señales de GameManager
	if GameManager:
		if not GameManager.npc_spawned.is_connected(_on_npc_spawned):
			GameManager.npc_spawned.connect(_on_npc_spawned)
		if not GameManager.npc_served.is_connected(_on_npc_served):
			GameManager.npc_served.connect(_on_npc_served)
		if not GameManager.game_over.is_connected(_on_game_over):
			GameManager.game_over.connect(_on_game_over)

		GameManager.restore_environment(get_tree())
		_update_spawned_count(GameManager.npcs_spawned)
		_update_served_count(GameManager.npcs_served)

	_update_debug_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if toggle_debug_key != KEY_NONE and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == toggle_debug_key:
			show_debug_counters = not show_debug_counters


func _update_debug_visibility() -> void:
	if is_node_ready() and debug_panel:
		debug_panel.visible = show_debug_counters


func _on_npc_spawned(total_spawned: int) -> void:
	_update_spawned_count(total_spawned)


func _on_npc_served(total_served: int, _is_correct: bool) -> void:
	_update_served_count(total_served)


func _update_spawned_count(count: int) -> void:
	if debug_spawned_label:
		debug_spawned_label.text = "NPCs aparecidos: %d" % count


func _update_served_count(count: int) -> void:
	if debug_served_label:
		debug_served_label.text = "NPCs atendidos: %d" % count


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


func _on_game_over(reason: String) -> void:
	# Flash rojo en pantalla simulando el impacto del disparo
	if damage_flash:
		damage_flash.visible = true
		damage_flash.color = Color(0.95, 0.05, 0.05, 0.85)
		var tween := create_tween()
		tween.tween_property(damage_flash, "color:a", 0.35, 0.85)

	if crosshair:
		crosshair.visible = false
	if prompt_label:
		prompt_label.visible = false

	# Pausa dramática para ver la caída de la cámara al suelo antes del menú
	await get_tree().create_timer(0.85).timeout

	if final_score_label:
		final_score_label.text = reason if reason != "" else "Has sido eliminado."

	if delivery_stat_label:
		delivery_stat_label.text = "📦 Clientes atendidos: %d" % GameManager.npcs_served

	# Ocultar estadísticas arcade secundarias
	for stat_name in ["HighScoreLabel", "ComboStatLabel", "TimeStatLabel", "DifficultyStatLabel", "Separator1"]:
		var node = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/" + stat_name)
		if node:
			node.visible = false

	if game_over_panel:
		game_over_panel.visible = true

	# Liberar el cursor para poder hacer clic en los botones
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_retry_pressed() -> void:
	if GameManager:
		GameManager.restore_environment(get_tree())
		GameManager.reset_game()
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	if GameManager:
		GameManager.restore_environment(get_tree())
		GameManager.reset_game()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
