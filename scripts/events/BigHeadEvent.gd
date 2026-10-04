class_name BigHeadEvent
extends NPCEvent
## Evento / Anomalía: Aumenta significativamente el tamaño de la cabeza del NPC.

@export var head_scale: Vector3 = Vector3(2.4, 2.4, 2.4)
@export var head_offset_y: float = 0.25
@export var ui_offset_y: float = 0.45


func _init() -> void:
	id = "big_head"
	event_name = "Cabeza Gigante"
	description = "El cliente tiene una cabeza desproporcionadamente grande."
	weight = 25.0


func apply(npc: CharacterBody3D) -> void:
	var head_node = npc.get_node_or_null("Head")
	if head_node:
		head_node.scale = head_scale
		head_node.position.y += head_offset_y

	# Ajustar altura de UI flotante para que la cabeza gigante no la oculte
	var label_node = npc.get_node_or_null("Label3D")
	if label_node:
		label_node.position.y += ui_offset_y

	var patience_pivot = npc.get_node_or_null("PatienceBarPivot")
	if patience_pivot:
		patience_pivot.position.y += ui_offset_y
