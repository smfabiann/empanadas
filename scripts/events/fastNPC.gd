class_name FastNPCEvent
extends NPCEvent
## Evento / Anomalía: El cliente se mueve mucho más rápido y tiene menos paciencia.

@export var custom_speed: float = 5.5
@export var patience_multiplier: float = 0.5
@export var patience_drain_rate: float = 1.5


func _init() -> void:
	id = "fast_npc"
	event_name = "Cliente Acelerado"
	description = "El cliente corre rápidamente hacia el mostrador y su paciencia se agota mucho más rápido."
	weight = 15.0


func apply(npc: CharacterBody3D) -> void:
	if "speed" in npc:
		npc.speed = custom_speed
	elif "SPEED" in npc:
		npc.set("SPEED", custom_speed)

	if "patience_time" in npc:
		npc.patience_time = maxf(4.0, npc.patience_time * patience_multiplier)
		npc.patience_remaining = npc.patience_time

	if "patience_drain_rate" in npc:
		npc.patience_drain_rate = patience_drain_rate


func on_arrive(npc: CharacterBody3D) -> void:
	if "patience_time" in npc:
		npc.patience_remaining = npc.patience_time

	var label = npc.get_node_or_null("Label3D") as Label3D
	if label:
		var order_text: String = label.text.replace("💬 ", "")
		label.text = "⚡ ¡RÁPIDO! " + order_text


func on_leave(npc: CharacterBody3D) -> void:
	if "speed" in npc:
		npc.speed = custom_speed * 1.2
