extends CanvasLayer
## UI minimalista para juego de terror / anomalías.
## Solo mira (crosshair), prompts contextuales de interacción, menú de pausa y herramientas de depuración.

@export_group("Debug")
## Activa o desactiva la visualización de contadores de depuración en la UI (arriba a la derecha)
@export var show_debug_counters: bool = true:
	set(value):
		show_debug_counters = value
		_update_debug_visibility()

@onready var crosshair: ColorRect = $HUD/Crosshair
@onready var prompt_label: Label = $HUD/PromptLabel
@onready var debug_panel: PanelContainer = $HUD.get_node_or_null("DebugPanel")
@onready var debug_spawned_label: Label = $HUD.get_node_or_null("DebugPanel/DebugVBox/DebugSpawnedLabel")
@onready var debug_served_label: Label = $HUD.get_node_or_null("DebugPanel/DebugVBox/DebugServedLabel")
@onready var debug_anomalies_label: Label = $HUD.get_node_or_null("DebugPanel/DebugVBox/DebugAnomaliesLabel")
var _anomalies_mgr: Node = null

@onready var game_over_panel: PanelContainer = $HUD.get_node_or_null("GameOverPanel")
@onready var game_over_label: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/GameOverLabel")
@onready var final_score_label: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/FinalScoreLabel")
@onready var delivery_stat_label: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/DeliveryStatLabel")
@onready var retry_button: Button = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/RetryButton")
@onready var menu_button: Button = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/MenuButton")
@onready var damage_flash: ColorRect = $HUD.get_node_or_null("DamageFlash")

# --- Bucle de días ---
@onready var day_panel: PanelContainer = $HUD.get_node_or_null("DayPanel")
@onready var day_label: Label = $HUD.get_node_or_null("DayPanel/VBoxContainer/DayLabel") if $HUD.has_node("DayPanel/VBoxContainer/DayLabel") else $HUD.get_node_or_null("DayLabel")
@onready var day_progress_bar: ProgressBar = $HUD.get_node_or_null("DayPanel/VBoxContainer/DayProgressBar") if $HUD.has_node("DayPanel/VBoxContainer/DayProgressBar") else $HUD.get_node_or_null("DayProgressBar")
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

@onready var victory_stat_money: Label = $HUD.get_node_or_null("VictoryPanel/VBoxContainer/VictoryStatMoney")

# --- Narrativa y economía del escape ---
@onready var savings_label: Label = $HUD.get_node_or_null("DayPanel/VBoxContainer/SavingsLabel")
@onready var savings_bar: ProgressBar = $HUD.get_node_or_null("DayPanel/VBoxContainer/SavingsBar")
@onready var money_popup: Label = $HUD.get_node_or_null("MoneyPopup")
@onready var hint_panel: PanelContainer = $HUD.get_node_or_null("HintPanel")
@onready var hint_label: Label = $HUD.get_node_or_null("HintPanel/HintLabel")
@onready var intro_panel: Control = $HUD.get_node_or_null("IntroPanel")
@onready var intro_story: Label = $HUD.get_node_or_null("IntroPanel/CenterContainer/IntroBox/VBoxContainer/IntroStory")
@onready var intro_howto: Label = $HUD.get_node_or_null("IntroPanel/CenterContainer/IntroBox/VBoxContainer/IntroHowTo")
@onready var intro_start_button: Button = $HUD.get_node_or_null("IntroPanel/CenterContainer/IntroBox/VBoxContainer/IntroStartButton")
@onready var game_over_title: Label = $HUD.get_node_or_null("GameOverPanel/VBoxContainer/GameOverLabel")

## Segundos que se muestra una pista en pantalla
@export var hint_duration: float = 6.5

var _banner_tween: Tween = null
var _money_tween: Tween = null
var _hint_tween: Tween = null

const HOW_TO_PLAY_TEXT := "• Lee el pedido del cliente en la ventana y arma el completo en la cocina: PAN, luego VIENESA y los agregados (palta, mayo, kétchup).\n• Entrega mirando al cliente con [E]. Si lo pide MOJADO, moja el pan en la OLLA antes de entregarlo.\n• El botón del mostrador baja la PERSIANA: úsala contra ladrones y estafadores.\n• El MONITOR del escritorio muestra las cámaras: [A]/[D] cambia de cámara y [F] activa la visión nocturna.\n• Cuando atiendas a todos los clientes de la noche, ve a la CAMA a dormir.\n\nWASD mover · Ratón mirar · Shift correr · Espacio saltar · E usar / entregar · Q soltar · ESC pausa"


func _ready() -> void:
	# Ocultar todos los elementos de arcade / vidas / puntuación y paneles modales
	for node_name in [
			"ScoreLabel", 
			"LivesLabel",
			"ComboLabel",
			"DifficultyLabel",
			"TimeLabel",
			"GameOverPanel",
			"TutorialPanel",
			"DamageFlash",
			"SuccessFlash",
			"IntroPanel",
			"DayEndPanel",
			"VictoryPanel"
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
		if not GameManager.money_changed.is_connected(_on_money_changed):
			GameManager.money_changed.connect(_on_money_changed)
		if not GameManager.hint_requested.is_connected(show_hint):
			GameManager.hint_requested.connect(show_hint)

		GameManager.restore_environment(get_tree())
		_update_spawned_count(GameManager.npcs_spawned)
		_update_served_count(GameManager.npcs_served)
		_on_day_progress(GameManager.clients_attended_today, GameManager.max_clients_per_day)
		_update_savings()
		if GameManager.show_intro:
			_show_intro.call_deferred()
		else:
			_show_day_banner(GameManager.current_day)

	if intro_start_button:
		intro_start_button.pressed.connect(_on_intro_start_pressed)

	_setup_anomalies_debug()
	_update_debug_visibility()


func _update_debug_visibility() -> void:
	if is_node_ready() and debug_panel:
		debug_panel.visible = show_debug_counters


func _on_npc_spawned(total_spawned: int) -> void:
	_update_spawned_count(total_spawned)


func _on_npc_served(total_served: int, _is_correct: bool) -> void:
	_update_served_count(total_served)


func _update_spawned_count(count: int) -> void:
	if debug_spawned_label:
		debug_spawned_label.text = "NPCs spawned: %d" % count


func _update_served_count(count: int) -> void:
	if debug_served_label:
		debug_served_label.text = "NPCs served: %d" % count


func _setup_anomalies_debug() -> void:
	_anomalies_mgr = get_tree().root.find_child("AnomaliesManagement", true, false)
	if _anomalies_mgr == null:
		_anomalies_mgr = get_tree().root.find_child("anomaliesManagement", true, false)
	if _anomalies_mgr:
		if _anomalies_mgr.has_signal("anomaly_triggered"):
			_anomalies_mgr.connect("anomaly_triggered", func(_d, _i): _update_anomalies_debug())
		if _anomalies_mgr.has_signal("anomaly_resolved"):
			_anomalies_mgr.connect("anomaly_resolved", func(_id, _i): _update_anomalies_debug())
	_update_anomalies_debug()


func _update_anomalies_debug() -> void:
	if debug_anomalies_label:
		if _anomalies_mgr:
			var active: int = _anomalies_mgr.get("debug_active_count") if "debug_active_count" in _anomalies_mgr else 0
			var last: String = _anomalies_mgr.get("debug_last_triggered") if "debug_last_triggered" in _anomalies_mgr else ""
			if last.is_empty():
				debug_anomalies_label.text = "Anomalies: %d active" % active
			else:
				debug_anomalies_label.text = "Anomalies: %d (%s)" % [active, last]
		else:
			debug_anomalies_label.text = "Anomalies: Inactive"


# =========================================================
#  BUCLE DE DÍAS / JORNADAS
# =========================================================

func _on_day_progress(attended: int, max_clients: int) -> void:
	if day_progress_bar:
		day_progress_bar.max_value = max(1, max_clients)
		var tween := create_tween()
		tween.tween_property(day_progress_bar, "value", float(attended), 0.25).set_ease(Tween.EASE_OUT)

	if day_panel and attended > 0:
		var punch := create_tween()
		punch.tween_property(day_panel, "scale", Vector2(1.03, 1.03), 0.08).set_ease(Tween.EASE_OUT)
		punch.tween_property(day_panel, "scale", Vector2(1.0, 1.0), 0.12).set_ease(Tween.EASE_IN)

	if day_label:
		if not GameManager.day_active and GameManager.is_day_quota_reached():
			if GameManager.max_days > 0:
				day_label.text = "Noche %d/%d  ·  Turno terminado - Ve a la cama" % [GameManager.current_day, GameManager.max_days]
			else:
				day_label.text = "Noche %d  ·  Turno terminado - Ve a la cama" % GameManager.current_day
			day_label.modulate = Color(0.4, 1.0, 0.5, 1.0)
		elif GameManager.max_days > 0:
			day_label.text = "Noche %d/%d  ·  Clientes %d/%d" % [GameManager.current_day, GameManager.max_days, attended, max_clients]
			day_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			day_label.text = "Noche %d  ·  Clientes %d/%d" % [GameManager.current_day, attended, max_clients]
			day_label.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _on_day_started(day: int, max_clients: int) -> void:
	if day_end_panel:
		day_end_panel.visible = false
	if crosshair:
		crosshair.visible = true
	if prompt_label:
		prompt_label.visible = true
	if day_label:
		day_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_on_day_progress(0, max_clients)
	_show_day_banner(day)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


## Muestra "NOCHE N/M" y la plata que falta con fade in / out (solo anima modulate)
func _show_day_banner(day: int) -> void:
	var title := "NOCHE %d" % day
	if GameManager.max_days > 0:
		title = "NOCHE %d/%d" % [day, GameManager.max_days]
	var missing: int = GameManager.get_money_missing()
	if missing > 0:
		_show_banner_text("%s\nFaltan $%s para el pasaje" % [title, GameManager.format_money(missing)])
	else:
		_show_banner_text("%s\n¡Ya tienes la plata del pasaje!" % title)


## Muestra un banner en pantalla con fade in / out
func _show_banner_text(text: String) -> void:
	if day_banner == null:
		return
	day_banner.text = text
	day_banner.modulate.a = 0.0
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(day_banner, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.8)
	_banner_tween.tween_property(day_banner, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)


## Notifica al jugador que la jornada terminó (el avance de día se realiza durmiendo en la cama)
func _on_day_ended(_day: int) -> void:
	if not GameManager.game_active or GameManager.is_game_won:
		return

	# Reemplazado por la mecánica de la cama:
	# El panel emergente de resumen queda oculto y el cursor sigue capturado para ir a la cama.
	if day_end_panel:
		day_end_panel.visible = false

	if day_progress_bar:
		day_progress_bar.value = day_progress_bar.max_value

	if day_label:
		if GameManager.max_days > 0:
			day_label.text = "Noche %d/%d  ·  Turno terminado - Ve a la cama" % [GameManager.current_day, GameManager.max_days]
		else:
			day_label.text = "Noche %d  ·  Turno terminado - Ve a la cama" % GameManager.current_day
		day_label.modulate = Color(0.4, 1.0, 0.5, 1.0)

	var earned: int = GameManager.earned_today
	var earned_text := "Ganaste $%s esta noche" % GameManager.format_money(earned) if earned >= 0 else "Perdiste $%s esta noche" % GameManager.format_money(-earned)
	if GameManager.is_final_day():
		_show_banner_text("TURNO TERMINADO\n%s · Ve a la cama: el bus sale al amanecer" % earned_text)
	else:
		_show_banner_text("TURNO TERMINADO\n%s · Ve a la cama a dormir" % earned_text)
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
		victory_title.text = " ¡ESCAPASTE! "
	if victory_subtitle:
		victory_subtitle.text = "Sobreviviste las %d noches y juntaste la plata del pasaje." % days_survived
	if victory_lore:
		victory_lore.text = "Al amanecer cierras el local, le dejas las llaves al tío y te subes al primer bus. Por la ventana, la ciudad se queda atrás... y algo en el cielo te sigue mirando."

	if victory_stat_days:
		victory_stat_days.text = " Noches trabajadas: %d/%d" % [days_survived, max_d]
	if victory_stat_served:
		victory_stat_served.text = " Pedidos correctos: %d" % int(stats.get("total_correct", 0))
	if victory_stat_wrong:
		victory_stat_wrong.text = " Pedidos equivocados: %d" % int(stats.get("total_wrong", 0))
	if victory_stat_lost:
		victory_stat_lost.text = " Clientes que se fueron: %d" % int(stats.get("total_lost", 0))
	if victory_stat_money:
		victory_stat_money.text = " Plata juntada: $%s / $%s" % [GameManager.format_money(int(stats.get("savings", 0))), GameManager.format_money(int(stats.get("escape_goal", 0)))]

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
		final_score_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if game_over_title:
		game_over_title.text = "TE QUEDASTE EN LA CIUDAD" if reason.begins_with("No juntaste") else "FIN DEL JUEGO"

	if delivery_stat_label:
		delivery_stat_label.text = " Clientes atendidos: %d  ·  Noche %d  ·  Ahorros $%s / $%s" % [GameManager.npcs_served, GameManager.current_day, GameManager.format_money(GameManager.savings), GameManager.format_money(GameManager.escape_goal)]

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


# =========================================================
#  NARRATIVA: INTRO, AHORROS Y PISTAS
# =========================================================

## Texto de la historia de la intro (usa la meta configurada en GameManager)
func get_intro_story() -> String:
	return "La ciudad se está poniendo rara: luces en el cielo, gente que no parece gente y cosas que solo se ven por las cámaras. Ya decidiste irte. El bus sale al amanecer del cuarto día y entre el pasaje y lo justo para empezar de nuevo necesitas $%s. Tienes ahorrados $%s.\n\nTu tío te dejó a cargo de su local de completos por %d noches. Cada completo bien hecho son $%s, más propina si atiendes rápido. Junta los $%s que faltan... y que nadie te quite la plata." % [
		GameManager.format_money(GameManager.escape_goal),
		GameManager.format_money(GameManager.savings),
		maxi(GameManager.max_days, 1),
		GameManager.format_money(GameManager.COMPLETO_PRICE),
		GameManager.format_money(GameManager.get_money_missing())
	]


func _show_intro() -> void:
	if intro_panel == null:
		GameManager.show_intro = false
		_show_day_banner(GameManager.current_day)
		return
	GameManager.intro_active = true
	if intro_story:
		intro_story.text = get_intro_story()
	if intro_howto:
		intro_howto.text = HOW_TO_PLAY_TEXT
	intro_panel.visible = true
	if crosshair:
		crosshair.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_intro_start_pressed() -> void:
	if intro_panel:
		intro_panel.visible = false
	if crosshair:
		crosshair.visible = true
	GameManager.finish_intro()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_show_day_banner(GameManager.current_day)
	SFXManager.play_correct()


func _update_savings() -> void:
	var goal: int = GameManager.escape_goal
	var current: int = GameManager.savings
	var missing: int = GameManager.get_money_missing()
	if savings_label:
		if missing > 0:
			savings_label.text = "Pasaje: $%s / $%s  ·  Faltan $%s" % [GameManager.format_money(current), GameManager.format_money(goal), GameManager.format_money(missing)]
			savings_label.modulate = Color(1, 1, 1, 1)
		else:
			savings_label.text = "Pasaje: $%s / $%s  ·  ¡Listo para escapar!" % [GameManager.format_money(current), GameManager.format_money(goal)]
			savings_label.modulate = Color(0.6, 1.0, 0.6, 1)
	if savings_bar:
		savings_bar.max_value = maxi(goal, 1)
		var tween := create_tween()
		tween.tween_property(savings_bar, "value", float(mini(current, goal)), 0.35).set_ease(Tween.EASE_OUT)


func _on_money_changed(_savings: int, delta: int, reason: String) -> void:
	_update_savings()
	if delta == 0 or money_popup == null:
		return
	var sign_text := "+" if delta > 0 else "-"
	money_popup.text = "%s$%s  %s" % [sign_text, GameManager.format_money(absi(delta)), reason]
	money_popup.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5, 1) if delta > 0 else Color(1.0, 0.35, 0.3, 1))
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()
	money_popup.modulate.a = 1.0
	_money_tween = create_tween()
	_money_tween.tween_interval(1.6)
	_money_tween.tween_property(money_popup, "modulate:a", 0.0, 0.8)


## Muestra una pista temporal en pantalla (eventos, tutoriales)
func show_hint(text: String) -> void:
	if hint_panel == null or hint_label == null:
		return
	hint_label.text = text
	hint_panel.visible = true
	hint_panel.modulate.a = 0.0
	if _hint_tween and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(hint_panel, "modulate:a", 1.0, 0.3)
	_hint_tween.tween_interval(hint_duration)
	_hint_tween.tween_property(hint_panel, "modulate:a", 0.0, 0.6)
	_hint_tween.tween_callback(func(): hint_panel.visible = false)
