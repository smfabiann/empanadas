extends Node
## Autoload singleton — estado global del juego de anomalías.
## Gestiona el flujo del juego, contadores de clientes atendidos, el bucle de días
## (jornadas) y señales de eventos.

signal item_delivered()
signal npc_left()
signal npc_spawned(total_spawned: int)
signal npc_served(total_served: int, is_correct: bool)
signal game_over(reason: String)

## Bucle de días / jornadas
signal day_started(day: int, max_clients: int)
signal day_progress(attended: int, max_clients: int)
signal day_ended(day: int)
## Se emite cuando el jugador avanza al día siguiente (cama o menú de fin de
## jornada). Es el disparador único de la transición visual noche -> día y del
## reinicio de los contadores diarios (ver start_next_day).
signal day_advanced(day: int, max_clients: int)
signal game_won(stats: Dictionary)
## Economía del escape: se emite cada vez que cambian los ahorros (delta puede ser negativo)
signal money_changed(savings: int, delta: int, reason: String)
## Se emite cuando el jugador cierra la intro narrativa y abre el local (inicia la Noche 1)
signal intro_finished()
## Pista contextual para el jugador (la UI la muestra como aviso temporal)
signal hint_requested(text: String)

var game_active: bool = true
var is_game_won: bool = false
var is_sleeping: bool = false
var high_score: int = 0

## Contadores de clientes (totales de la partida)
var npcs_spawned: int = 0
var npcs_served: int = 0
var npcs_served_correctly: int = 0

## --- Jornada actual ---
## Día en curso (empieza en 1)
var current_day: int = 1
## Cupo de clientes por jornada. Lo sobrescribe NPCSpawner o Main desde el Inspector.
var max_clients_per_day: int = 8
## Cantidad máxima de días de la partida para ganar (HU-06: 3 días por defecto; 0 = días infinitos).
var max_days: int = 3
## Clientes cuya visita terminó hoy (atendidos con o sin éxito + los que se fueron)
var clients_attended_today: int = 0
var clients_served_correctly_today: int = 0
var clients_served_wrong_today: int = 0
var clients_lost_today: int = 0
## true mientras la jornada está en curso; false al mostrarse el resumen del día
var day_active: bool = true

## --- Narrativa: juntar la plata para escapar de la ciudad ---
## Ahorros con los que parte la partida (lo que ya tenías juntado)
const DEFAULT_STARTING_SAVINGS := 20000
## Plata total necesaria para el pasaje y escapar de la ciudad al amanecer del 4.º día
const DEFAULT_ESCAPE_GOAL := 50000
## Precio base que paga un cliente por un completo correcto
const COMPLETO_PRICE := 3000
## Recargo por completo mojado (olla, estilo Talca)
const MOJADO_EXTRA := 500
## Propina máxima si se atiende rápido (paciencia restante alta)
const MAX_TIP := 1000

var starting_savings: int = DEFAULT_STARTING_SAVINGS
var escape_goal: int = DEFAULT_ESCAPE_GOAL
var savings: int = DEFAULT_STARTING_SAVINGS
## Plata ganada (o perdida) durante la jornada actual
var earned_today: int = 0
## Se desbloquea cuando aparece el Talquino: desde ahí algunos clientes piden completos mojados
var mojados_unlocked: bool = false
## true cuando la partida se inició desde el menú y debe mostrarse la intro narrativa
var show_intro: bool = false
## true mientras la intro narrativa está en pantalla (bloquea al jugador y a los clientes)
var intro_active: bool = false

# Intervalo entre NPCs (segundos)
@export var SPAWN_INTERVAL := 6.0
# Tiempo que el NPC espera en la ventana antes de irse
const PATIENCE_TIME := 25.0


func get_spawn_interval() -> float:
	return SPAWN_INTERVAL


func get_patience_time() -> float:
	return PATIENCE_TIME


func register_npc_spawned() -> int:
	npcs_spawned += 1
	npc_spawned.emit(npcs_spawned)
	return npcs_spawned


func register_npc_served(is_correct: bool) -> int:
	npcs_served += 1
	if is_correct:
		npcs_served_correctly += 1
		clients_served_correctly_today += 1
	else:
		clients_served_wrong_today += 1
	_register_client_attended_today()
	item_delivered.emit()
	npc_served.emit(npcs_served, is_correct)
	return npcs_served


## Suma plata a los ahorros (pago de un cliente, propina, etc.)
func earn_money(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	savings += amount
	earned_today += amount
	money_changed.emit(savings, amount, reason)


## Resta plata de los ahorros (robo, estafa, etc.). Nunca baja de 0.
func lose_money(amount: int, reason: String = "") -> void:
	if amount <= 0:
		return
	var real_loss: int = mini(amount, savings)
	savings -= real_loss
	earned_today -= real_loss
	money_changed.emit(savings, -real_loss, reason)


## Cierra la intro narrativa y deja partir la Noche 1
func finish_intro() -> void:
	show_intro = false
	if not intro_active:
		return
	intro_active = false
	intro_finished.emit()


## Pide a la UI que muestre una pista temporal (eventos, tutoriales)
func request_hint(text: String) -> void:
	hint_requested.emit(text)


## Plata que todavía falta para escapar (0 si ya se juntó)
func get_money_missing() -> int:
	return maxi(0, escape_goal - savings)


## true si los ahorros alcanzan para el pasaje
func has_escape_money() -> bool:
	return savings >= escape_goal


## Configura la meta económica de la partida (Main.gd la expone en el Inspector)
func set_economy(start_savings: int, goal: int) -> void:
	starting_savings = maxi(start_savings, 0)
	escape_goal = maxi(goal, 1)
	savings = starting_savings
	earned_today = 0
	money_changed.emit(savings, 0, "")


## Calcula el pago de un completo correcto: precio base + mojado + propina por rapidez.
## patience_ratio: paciencia restante del cliente (0..1).
func calculate_completo_payment(patience_ratio: float, is_mojado: bool = false) -> int:
	var price: int = COMPLETO_PRICE
	if is_mojado:
		price += MOJADO_EXTRA
	var tip: int = int(round(clampf(patience_ratio, 0.0, 1.0) * MAX_TIP / 100.0)) * 100
	return price + tip


func register_npc_left() -> void:
	clients_lost_today += 1
	_register_client_attended_today()
	npc_left.emit()


# =========================================================
#  BUCLE DE DÍAS / JORNADAS
# =========================================================

func _register_client_attended_today() -> void:
	if not day_active:
		return
	clients_attended_today += 1
	day_progress.emit(clients_attended_today, max_clients_per_day)


## Configura el cupo de clientes de la jornada (llamado por NPCSpawner desde el Inspector)
func set_max_clients_per_day(value: int) -> void:
	max_clients_per_day = maxi(value, 1)
	day_progress.emit(clients_attended_today, max_clients_per_day)


## Configura la cantidad máxima de días de la partida (0 = días infinitos sin límite)
func set_max_days(value: int) -> void:
	max_days = maxi(value, 0)
	day_progress.emit(clients_attended_today, max_clients_per_day)


## true si el día actual es el último día configurado de la partida
func is_final_day() -> bool:
	return max_days > 0 and current_day >= max_days


## true cuando ya se alcanzó el cupo de clientes del día (no deben aparecer más)
func is_day_quota_reached() -> bool:
	return clients_attended_today >= max_clients_per_day


## Indica si el spawner puede generar un nuevo cliente en este momento
func can_spawn_npc() -> bool:
	return game_active and day_active and not is_game_won and not intro_active and not is_day_quota_reached()


## Indica si el jugador puede moverse e interactuar (no tras Game Over, victoria ni durante la transición de dormir)
func can_player_act() -> bool:
	return game_active and not is_game_won and not is_sleeping and not intro_active


## Retorna si el jugador puede ir a dormir a la cama.
## Solo es posible cuando la partida sigue activa, no se ha ganado, no está durmiendo,
## y la jornada terminó habiendo alcanzado el cupo máximo de clientes del día.
func can_sleep() -> bool:
	return game_active and not is_game_won and not is_sleeping and not day_active and is_day_quota_reached()


## Cierra la jornada actual al cumplir el cupo de clientes del día.
func end_day() -> void:
	if not day_active or not game_active:
		return
	day_active = false
	day_ended.emit(current_day)


## Avanza al siguiente día y reinicia los contadores diarios.
## Si ya era el día final, activa la pantalla de victoria.
func start_next_day() -> void:
	if is_final_day():
		trigger_victory()
		return
	current_day += 1
	# Reinicio de contadores diarios (clientes atendidos/correctos/etc.)
	_reset_day_counters()
	day_active = true
	day_started.emit(current_day, max_clients_per_day)
	# Transición visual noche -> día + nueva noche. Lo gestiona DayCycle.
	day_advanced.emit(current_day, max_clients_per_day)
	day_progress.emit(clients_attended_today, max_clients_per_day)


## Activa la pantalla y estado de victoria.
## Narrativa: al amanecer del último día se escapa solo si se juntó la plata del pasaje;
## si no alcanza, la partida termina en derrota (te quedas atrapado en la ciudad).
func trigger_victory() -> void:
	if not has_escape_money():
		trigger_game_over("No juntaste la plata del pasaje: te faltaron $%s.\nEl bus salió sin ti y quedaste atrapado en la ciudad." % format_money(get_money_missing()))
		return
	is_game_won = true
	game_active = false
	var stats: Dictionary = {
		"day": current_day,
		"max_days": max_days,
		"total_served": npcs_served,
		"total_correct": npcs_served_correctly,
		"total_wrong": npcs_served - npcs_served_correctly,
		"total_lost": maxi(0, npcs_spawned - npcs_served),
		"clients_attended_today": clients_attended_today,
		"clients_correct_today": clients_served_correctly_today,
		"savings": savings,
		"escape_goal": escape_goal
	}
	game_won.emit(stats)


## Fuerza el avance al siguiente día inmediatamente para depuración
func debug_advance_to_next_day() -> void:
	if not game_active:
		return
	day_active = false
	start_next_day()
	print("[GameManager DEBUG] Avanzado manualmente al día %d (Atendidos hoy: %d/%d)" % [current_day, clients_attended_today, max_clients_per_day])


func _reset_day_counters() -> void:
	earned_today = 0
	clients_attended_today = 0
	clients_served_correctly_today = 0
	clients_served_wrong_today = 0
	clients_lost_today = 0


# Valores originales del ambiente para restaurar tras eventos
const DEFAULT_AMBIENT_ENERGY := 0.4
const DEFAULT_AMBIENT_COLOR := Color(0.85, 0.78, 0.6, 1)
const DEFAULT_FOG_DENSITY := 0.015
const DEFAULT_FOG_COLOR := Color(0.05, 0.03, 0.08, 1)
const DEFAULT_DIR_LIGHT_ENERGY := 0.1
const DEFAULT_CEILING_LIGHT_ENERGY := 2.5


func trigger_game_over(reason: String = "") -> void:
	if not game_active:
		return
	game_active = false
	game_over.emit(reason)


## Restaura el ambiente, niebla y luces a sus valores originales
func restore_environment(tree: SceneTree = null) -> void:
	var target_tree: SceneTree = tree
	if target_tree == null and is_inside_tree():
		target_tree = get_tree()
	if target_tree == null or target_tree.root == null:
		return

	var world_env := target_tree.root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		env.ambient_light_energy = DEFAULT_AMBIENT_ENERGY
		env.ambient_light_color = DEFAULT_AMBIENT_COLOR
		env.fog_enabled = true
		env.fog_density = DEFAULT_FOG_DENSITY
		env.fog_light_color = DEFAULT_FOG_COLOR

	var dir_light := target_tree.root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		dir_light.light_energy = DEFAULT_DIR_LIGHT_ENERGY

	var ceiling_light := target_tree.root.find_child("CeilingLight", true, false) as Light3D
	if ceiling_light:
		ceiling_light.light_energy = DEFAULT_CEILING_LIGHT_ENERGY


func reset_game() -> void:
	game_active = true
	is_game_won = false
	is_sleeping = false
	intro_active = false
	npcs_spawned = 0
	npcs_served = 0
	npcs_served_correctly = 0
	current_day = 1
	day_active = true
	mojados_unlocked = false
	savings = starting_savings
	_reset_day_counters()
	money_changed.emit(savings, 0, "")
	npc_spawned.emit(npcs_spawned)
	npc_served.emit(npcs_served, true)
	day_progress.emit(clients_attended_today, max_clients_per_day)
	restore_environment()


## Formatea montos al estilo chileno: 50000 -> "50.000"
static func format_money(amount: int) -> String:
	var negative: bool = amount < 0
	var digits: String = str(absi(amount))
	var out: String = ""
	var count: int = 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if negative else "") + out
