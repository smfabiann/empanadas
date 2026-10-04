class_name NPCEvent
extends Resource
## Clase base para eventos y anomalías de los NPCs.
## Diseñada para ser escalable: cada anomalía o evento nuevo solo necesita heredar de esta clase.

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
