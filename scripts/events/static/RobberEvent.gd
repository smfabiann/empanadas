class_name RobberEvent
extends StaticNPCEvent
## Evento Estático: El Ladrón.
## Aparece tras atender cierta cantidad de clientes (configurable en el Inspector).
## Utiliza la escena dedicada res://scenes/RobberNPC.tscn para su apariencia física.

func _init() -> void:
	super._init()
	id = "robber"
	event_name = "El Ladrón"
	description = "Un sospechoso cliente con intenciones dudosas que aparece tras atender clientes."
	trigger_served_count = 5
	trigger_once = true
	custom_npc_scene = preload("res://scenes/RobberNPC.tscn")


func apply(_npc: CharacterBody3D) -> void:
	# Aquí se podrán inicializar mecánicas especiales del ladrón
	pass


func on_arrive(npc: CharacterBody3D) -> void:
	if npc is RobberNPC:
		return
	var label = npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "😈 Dame todo... ¡y una empanada!"
		label.modulate = Color(1.0, 0.2, 0.2, 1.0)


func on_leave(_npc: CharacterBody3D) -> void:
	# Aquí se ejecutará la lógica al retirarse el ladrón
	pass
