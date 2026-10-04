class_name StaticNPCEvent
extends NPCEvent
## Plantilla base para Eventos Estáticos y Narrativos de NPCs.
## A diferencia de los eventos aleatorios, los eventos estáticos se activan bajo
## condiciones específicas (ej. cantidad de clientes atendidos) y pueden usar un modelo/escena de NPC propia.

@export_group("Condiciones de Activación")
## Clientes atendidos requeridos para disparar este evento. (0 o menor = desactivado por atendidos)
@export var trigger_served_count: int = 5

## Número de aparición (spawn) requerido para disparar este evento. (-1 = desactivado por spawn)
@export var trigger_spawn_count: int = -1

## Si es true, el evento se ejecuta solo una vez por partida.
@export var trigger_once: bool = true

## Estado: indica si este evento estático ya fue activado en la partida.
@export var has_triggered: bool = false

@export_group("Modelo / Escena Personalizada")
## Escena de NPC dedicada para este evento (ej. modelo de Ladrón, Policía, etc.).
## Si es null, se utiliza la escena base de NPC estándar.
@export var custom_npc_scene: PackedScene = null


func _init() -> void:
	# Los eventos estáticos tienen peso 0 para NO ser elegidos en sorteos aleatorios
	weight = 0.0


## Evalúa si se cumplen las condiciones para que este evento ocurra.
func can_trigger(spawn_count: int, served_count: int) -> bool:
	if trigger_once and has_triggered:
		return false

	# Condición por clientes atendidos con éxito
	if trigger_served_count > 0 and served_count >= trigger_served_count:
		return true

	# Condición por número de spawn
	if trigger_spawn_count > 0 and spawn_count >= trigger_spawn_count:
		return true

	return false


## Marca el evento como disparado.
func mark_triggered() -> void:
	has_triggered = true


## Reinicia el estado del evento (útil al reiniciar la partida).
func reset_event() -> void:
	has_triggered = false


## Devuelve la escena personalizada si existe.
func get_custom_npc_scene() -> PackedScene:
	return custom_npc_scene
