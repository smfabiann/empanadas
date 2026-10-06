extends Node
## Autoload singleton — estado global del juego de anomalías.
## Simplificado: solo controla si el juego está activo y emite señales básicas.

signal item_delivered()
signal npc_left()

var game_active: bool = true
var high_score: int = 0

# Intervalo entre NPCs (segundos)
const SPAWN_INTERVAL := 6.0
# Tiempo que el NPC espera en la ventana antes de irse
const PATIENCE_TIME := 25.0


func get_spawn_interval() -> float:
	return SPAWN_INTERVAL


func get_patience_time() -> float:
	return PATIENCE_TIME


func reset_game() -> void:
	game_active = true
