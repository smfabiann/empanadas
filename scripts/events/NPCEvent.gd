class_name NPCEvent
extends Resource
## Clase base para eventos de los NPCs (modificadores de clientes y personajes especiales).
## Diseñada para ser escalable: cada evento nuevo solo necesita heredar de esta clase.
## (Para anomalías modulares ambientales/HUD con escenas propias, ver AnomalyBase).

@export var id: String = ""
@export var event_name: String = ""
@export_multiline var description: String = ""

## Peso o rareza del evento para selección ponderada (a mayor peso, más frecuencia en sorteos aleatorios)
@export_range(0.0, 100.0, 0.1) var weight: float = 10.0


## Se ejecuta cuando el NPC se instancia / inicializa
func apply(_npc: CharacterBody3D) -> void:
	pass


## Se ejecuta cuando el NPC llega al mostrador / ventana
func on_arrive(_npc: CharacterBody3D) -> void:
	pass


## Se ejecuta cuando el NPC comienza a retirarse
func on_leave(_npc: CharacterBody3D) -> void:
	pass


## Se ejecuta cuando el jugador le entrega un ítem al NPC.
## Retorna true si el evento manejó la entrega por completo (el NPC no aplica su lógica normal).
func on_item_received(_npc: CharacterBody3D, _item: Node) -> bool:
	return false


## Se ejecuta cuando se baja la persiana con el NPC en el mostrador.
## Retorna true si el evento manejó la reacción (el NPC no se va por timeout normal).
func on_persiana_closed(_npc: CharacterBody3D) -> bool:
	return false


## Se ejecuta cuando al NPC se le agota la paciencia.
## Retorna true si el evento manejó la salida (el NPC no ejecuta su timeout normal).
func on_timeout(_npc: CharacterBody3D) -> bool:
	return false
