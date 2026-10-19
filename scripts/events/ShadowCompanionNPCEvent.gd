class_name ShadowCompanionNPCEvent
extends NPCEvent
## Evento para el cliente poseído por la anomalía "El Acompañante Oculto" (CCTV).
## El cliente aparenta ser completamente ordinario (pide un completo normal),
## pero está custodiado por una entidad oscura detrás visible solo con visión nocturna [F].
##
## Regla de supervivencia:
## - ¡NO LO ATIENDAS! Si el jugador intenta entregarle un ítem, la entidad ataca (Game Over mortal).
## - Bajar la persiana es la defensa correcta: destierra la anomalía y el cliente se retira.
## - Si se agota la paciencia, la anomalía roba plata de la caja.

var anomaly_node: Node = null


func _init(p_anomaly: Node = null) -> void:
	id = "shadow_companion_npc"
	event_name = "Cliente con Acompañante Oculto"
	description = "Cliente normal con un doppelgänger oscuro detrás. Prohibido atender: hay que cerrar la persiana."
	weight = 0.0 # Se asigna exclusivamente a través de la anomalía de CCTV
	anomaly_node = p_anomaly


## Al recibir un ítem: ¡EL JUGADOR ATENDIÓ A LA ANOMALÍA! Ataque o advertencia según strikes.
func on_item_received(npc: CharacterBody3D, item: Node) -> bool:
	# Consumir y liberar inmediatamente el ítem entregado para no dejarlo trabado en las manos del jugador
	if item != null and is_instance_valid(item):
		if item.get_parent():
			item.get_parent().remove_child(item)
		item.queue_free()

	if npc and npc.is_inside_tree():
		var player = npc.get_tree().get_first_node_in_group("player")
		if player and "held_item" in player:
			player.held_item = null

	if anomaly_node and is_instance_valid(anomaly_node) and anomaly_node.has_method("trigger_death_sequence"):
		anomaly_node.trigger_death_sequence(npc)
		return true
	return false


## Al bajar la persiana: acción correcta, destierra a la anomalía.
func on_persiana_closed(npc: CharacterBody3D) -> bool:
	if anomaly_node and is_instance_valid(anomaly_node) and anomaly_node.has_method("handle_persiana_closed"):
		return anomaly_node.handle_persiana_closed(npc)
	return false


## Al agotarse la paciencia sin bajar la persiana.
func on_timeout(npc: CharacterBody3D) -> bool:
	if anomaly_node and is_instance_valid(anomaly_node) and anomaly_node.has_method("handle_timeout"):
		return anomaly_node.handle_timeout(npc)
	return false
