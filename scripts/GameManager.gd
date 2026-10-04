extends Node
## Autoload singleton — estado global del juego de anomalías.
## Gestiona el flujo del juego, contadores de clientes atendidos y señales de eventos.

signal item_delivered()
signal npc_left()
signal npc_spawned(total_spawned: int)
signal npc_served(total_served: int, is_correct: bool)
signal game_over(reason: String)

var game_active: bool = true
var high_score: int = 0

## Contadores de clientes
var npcs_spawned: int = 0
var npcs_served: int = 0
var npcs_served_correctly: int = 0

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
	item_delivered.emit()
	npc_served.emit(npcs_served, is_correct)
	return npcs_served


func register_npc_left() -> void:
	npc_left.emit()


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
	var target_tree := tree if tree != null else get_tree()
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
	npcs_spawned = 0
	npcs_served = 0
	npcs_served_correctly = 0
	npc_spawned.emit(npcs_spawned)
	npc_served.emit(npcs_served, true)
	restore_environment()
