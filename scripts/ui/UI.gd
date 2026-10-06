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

# --- Bucle de días ---
@onready var day_label: Label = $HUD.get_node_or_null("DayLabel")
@onready var day_banner: Label = $HUD.get_node_or_null("DayBanner")
@onready var day_end_panel: PanelContainer = $HUD.get_node_or_null("DayEndPanel")
@onready var day_end_subtitle: Label = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayEndSubtitle")
@onready var day_stat_attended: Label = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayStatAttended")
@onready var day_stat_correct: Label = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayStatCorrect")
@onready var day_stat_wrong: Label = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayStatWrong")
@onready var day_stat_lost: Label = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayStatLost")
@onready var next_day_button: Button = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/NextDayButton")
@onready var day_end_menu_button: Button = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayEndMenuButton")

# --- Pantalla de Victoria (HU-06) ---
@onready var victory_panel: PanelContainer = $HUD.get_node_or_null("VictoryPanel")
@onready var victory_title: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryTitle")
@onready var victory_subtitle: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictorySubtitle")
@onready var victory_lore: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryLore")
@onready var victory_stat_days: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryStatDays")
@onready var victory_stat_served: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryStatServed")
@onready var victory_stat_wrong: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryStatWrong")
@onready var victory_stat_lost: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryStatLost")
@onready var victory_restart_button: Button = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryRestartButton")
@onready var victory_menu_button: Button = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryMenuButton")

var _banner_tween: Tween = null


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

	# Conectar botones del resumen de jornada
	if day_end_panel:
		day_end_panel.visible = false
	if next_day_button:
		next_day_button.pressed.connect(_on_next_day_pressed)
	if day_end_menu_button:
		day_end_menu_button.pressed.connect(_on_menu_pressed)

	# Conectar botones de la pantalla de victoria (HU-06)
	if victory_panel:
		victory_panel.visible = false
	if victory_restart_button:
		victory_restart_button.pressed.connect(_on_victory_restart_pressed)
	if victory_menu_button:
		victory_menu_button.pressed.connect(_on_menu_pressed)

	# Conectar señales de GameManager
	if GameManager:
		if not GameManager.npc_spawned.is_connected(_on_npc_spawned):
			GameManager.npc_spawned.connect(_on_npc_spawned)
		if not GameManager.npc_served.is_connected(_on_npc_served):
			GameManager.npc_served.connect(_on_npc_served)
		if not GameManager.game_over.is_connected(_on_game_over):
			GameManager.game_over.connect(_on_game_over)
		if not GameManager.day_started.is_connected(_on_day_started):
			GameManager.day_started.connect(_on_day_started)
		if not GameManager.day_progress.is_connected(_on_day_progress):
			GameManager.day_progress.connect(_on_day_progress)
		if not GameManager.day_ended.is_connected(_on_day_ended):
			GameManager.day_ended.connect(_on_day_ended)
		if not GameManager.game_won.is_connected(_on_game_won):
			GameManager.game_won.connect(_on_game_won)

		GameManager.restore_environment(get_tree())
		_update_spawned_count(GameManager.npcs_spawned)
		_update_served_count(GameManager.npcs_served)
		_on_day_progress(GameManager.clients_attended_today, GameManager.max_clients_per_day)
		_show_day_banner(GameManager.current_day)

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


# =========================================================
#  BUCLE DE DÍAS / JORNADAS
# =========================================================

func _on_day_progress(attended: int, max_clients: int) -> void:
	if day_label:
		if GameManager.max_days > 0:
			day_label.text = "Día %d/%d  ·  Clientes %d/%d" % [GameManager.current_day, GameManager.max_days, attended, max_clients]
		else:
			day_label.text = "Día %d  ·  Clientes %d/%d" % [GameManager.current_day, attended, max_clients]


func _on_day_started(day: int, max_clients: int) -> void:
	if day_end_panel:
		day_end_panel.visible = false
	if crosshair:
		crosshair.visible = true
	if prompt_label:
		prompt_label.visible = true
	_on_day_progress(0, max_clients)
	_show_day_banner(day)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Muestra "DÍA N" en pantalla con fade in / out (solo anima modulate)
func _show_day_banner(day: int) -> void:
	if day_banner == null:
		return
	day_banner.text = "DÍA %d" % day
	day_banner.modulate.a = 0.0
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(day_banner, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.6)
	_banner_tween.tween_property(day_banner, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)


## Notifica al jugador que la jornada terminó y muestra el resumen del día (Días intermedios)
func _on_day_ended(day: int) -> void:
	# Si se ganó la partida (día final), la pantalla mostrada es VictoryPanel via _on_game_won
	if GameManager.is_game_won or GameManager.is_final_day():
		return

	if crosshair:
		crosshair.visible = false
	if prompt_label:
		prompt_label.visible = false
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	if day_banner:
		day_banner.modulate.a = 0.0

	var day_end_title = $HUD.get_node_or_null("DayEndPanel/VBoxContainer/DayEndTitle") as Label
	if day_end_title:
		day_end_title.text = "FIN DE LA JORNADA"
	if day_end_subtitle:
		day_end_subtitle.text = "Día %d completado" % day
	if next_day_button:
		next_day_button.text = "▶ Comenzar Día %d" % (day + 1)

	if day_stat_attended:
		day_stat_attended.text = "Clientes atendidos: %d/%d" % [GameManager.clients_attended_today, GameManager.max_clients_per_day]
	if day_stat_correct:
		day_stat_correct.text = "Pedidos correctos: %d" % GameManager.clients_served_correctly_today
	if day_stat_wrong:
		day_stat_wrong.text = "Pedidos equivocados: %d" % GameManager.clients_served_wrong_today
	if day_stat_lost:
		day_stat_lost.text = "Clientes que se fueron: %d" % GameManager.clients_lost_today

	if day_end_panel:
		day_end_panel.modulate.a = 0.0
		day_end_panel.visible = true
		create_tween().tween_property(day_end_panel, "modulate:a", 1.0, 0.4)

	# Liberar el cursor para poder hacer clic en los botones
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SFXManager.play_correct()


## Muestra la pantalla de victoria al sobrevivir los 3 días completos (HU-06)
func _on_game_won(stats: Dictionary) -> void:
	if crosshair:
		crosshair.visible = false
	if prompt_label:
		prompt_label.visible = false
	if day_end_panel:
		day_end_panel.visible = false
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	if day_banner:
		day_banner.modulate.a = 0.0

	var days_survived: int = int(stats.get("day", 3))
	var max_d: int = int(stats.get("max_days", 3))
	if victory_title:
		victory_title.text = "🏆 ¡HAS GANADO! 🏆"
	if victory_subtitle:
		victory_subtitle.text = "¡Has sobrevivido los %d días de turno nocturno!" % days_survived
	if victory_lore:
		victory_lore.text = "Lograste resistir a las anomalías y escapar de la ciudad a salvo."

	if victory_stat_days:
		victory_stat_days.text = "📅 Días sobrevividos: %d/%d" % [days_survived, max_d]
	if victory_stat_served:
		victory_stat_served.text = "✅ Pedidos correctos: %d" % int(stats.get("total_correct", 0))
	if victory_stat_wrong:
		victory_stat_wrong.text = "❌ Pedidos equivocados: %d" % int(stats.get("total_wrong", 0))
	if victory_stat_lost:
		victory_stat_lost.text = "🏃 Clientes que se fueron: %d" % int(stats.get("total_lost", 0))

	if victory_panel:
		victory_panel.modulate.a = 0.0
		victory_panel.visible = true
		create_tween().tween_property(victory_panel, "modulate:a", 1.0, 0.5)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if SFXManager.has_method("play_victory"):
		SFXManager.play_victory()
	else:
		SFXManager.play_correct()


func _on_victory_restart_pressed() -> void:
	if GameManager:
		GameManager.restore_environment(get_tree())
		GameManager.reset_game()
	get_tree().reload_current_scene()


func _on_next_day_pressed() -> void:
	if GameManager.is_final_day() or GameManager.is_game_won:
		if GameManager:
			GameManager.restore_environment(get_tree())
			GameManager.reset_game()
		get_tree().reload_current_scene()
	else:
		GameManager.start_next_day()


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
		delivery_stat_label.text = "📦 Clientes atendidos: %d  ·  Día %d" % [GameManager.npcs_served, GameManager.current_day]

	if day_end_panel:
		day_end_panel.visible = false

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
