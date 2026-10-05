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
signal game_won(stats: Dictionary)

var game_active: bool = true
var is_game_won: bool = false
var high_score: int = 0

## Contadores de clientes (totales de la partida)
var npcs_spawned: int = 0
var npcs_served: int = 0
var npcs_served_correctly: int = 0

## --- Jornada actual ---
## Día en curso (empieza en 1)
var current_day: int = 1
## Cupo de clientes por jornada. Lo sobrescribe NPCSpawner desde el Inspector.
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
	return game_active and day_active and not is_game_won and not is_day_quota_reached()


## Indica si el jugador puede moverse e interactuar (no durante el resumen del día, tras Game Over ni al ganar)
func can_player_act() -> bool:
	return game_active and day_active and not is_game_won


## Cierra la jornada actual y notifica a la UI para mostrar el resumen o la victoria (HU-06)
func end_day() -> void:
	if not day_active or not game_active:
		return
	day_active = false
	if is_final_day():
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
			"clients_correct_today": clients_served_correctly_today
		}
		game_won.emit(stats)
	day_ended.emit(current_day)


## Avanza al siguiente día y reinicia los contadores diarios
func start_next_day() -> void:
	current_day += 1
	_reset_day_counters()
	day_active = true
	day_started.emit(current_day, max_clients_per_day)
	day_progress.emit(clients_attended_today, max_clients_per_day)


func _reset_day_counters() -> void:
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
	npcs_spawned = 0
	npcs_served = 0
	npcs_served_correctly = 0
	current_day = 1
	day_active = true
	_reset_day_counters()
	npc_spawned.emit(npcs_spawned)
	npc_served.emit(npcs_served, true)
	day_progress.emit(clients_attended_today, max_clients_per_day)
	restore_environment()
