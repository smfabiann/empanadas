class_name AwareNPCEvent
extends NPCEvent
## Evento para el cliente vinculado a la anomalía "El Consciente" (Aware / CCTV).
##
## El cliente acude al mostrador aparentando ser un cliente común, pero la entidad Consciente
## lo está custodiando y observa fijamente a través de las cámaras de seguridad.
##
## Regla de supervivencia:
## - ¡NO LO ATIENDAS! Si el jugador le entrega un ítem, la cara del NPC salta a la cámara
##   con un screamer violento y un ruido fuerte.
## - Comparte el sistema de 2 strikes con las anomalías de CCTV (GameManager.record_anomaly_strike()):
##   1 strike = advertencia aterradora, screamer y paredes burdeo.
##   2 strikes = Game Over mortal definitivo.
## - Bajar la persiana es la defensa correcta: destierra la anomalía y el cliente se retira.

var anomaly_node: Node = null


func _init(p_anomaly: Node = null) -> void:
	id = "aware_npc"
	event_name = "Cliente Observado por El Consciente"
	description = "Cliente vinculado a la anomalía Aware. Prohibido atender: screamer letal / advertencia. Bajar la persiana para desterrarlo."
	weight = 0.0 # Se asigna a través de la anomalía Aware
	anomaly_node = p_anomaly


## Al recibir un ítem: ¡EL JUGADOR ATENDIÓ A LA ANOMALÍA AWARE! Screamer de advertencia o muerte según strikes.
func on_item_received(npc: CharacterBody3D, item: Node) -> bool:
	if item != null and is_instance_valid(item):
		if item.get_parent():
			item.get_parent().remove_child(item)
		item.queue_free()

	if npc and npc.is_inside_tree():
		var player = npc.get_tree().get_first_node_in_group("player")
		if player and "held_item" in player:
			player.held_item = null

	if anomaly_node and is_instance_valid(anomaly_node) and anomaly_node.has_method("trigger_serving_consequence"):
		anomaly_node.trigger_serving_consequence(npc)
		return true
	return false


## Al bajar la persiana: acción correcta, destierra a Aware.
func on_persiana_closed(npc: CharacterBody3D) -> bool:
	if anomaly_node and is_instance_valid(anomaly_node) and anomaly_node.has_method("handle_persiana_closed"):
		return anomaly_node.handle_persiana_closed(npc)
	return false


## Al agotarse la paciencia sin bajar la persiana.
func on_timeout(npc: CharacterBody3D) -> bool:
	if anomaly_node and is_instance_valid(anomaly_node) and anomaly_node.has_method("handle_timeout"):
		return anomaly_node.handle_timeout(npc)
	return false
