class_name TalquinoEvent
extends StaticNPCEvent
## Evento Estático: El Talquino (HU-14, completos mojados).
## Un cliente de Talca llega en el Día 2 y exige un completo MOJADO: el pan se moja
## en la olla de caldo de vienesas de la cocina. Desde su visita, otros clientes
## también pueden pedir completos mojados (GameManager.mojados_unlocked).

## Paciencia extra: el jugador probablemente no conoce la olla todavía
@export var talquino_patience: float = 45.0


func _init() -> void:
	super._init()
	id = "talquino"
	event_name = "El Talquino"
	description = "Un cliente de Talca que pide un completo mojado en la olla. Desbloquea los pedidos mojados."
	trigger_day = 2
	trigger_day_served_count = 2
	trigger_served_count = 0
	trigger_once = true


func apply(npc: CharacterBody3D) -> void:
	# Manta café y chupalla (sombrero de paja) del huaso talquino
	var body := npc.get_node_or_null("BodyMesh") as CSGCylinder3D
	if body:
		var poncho := StandardMaterial3D.new()
		poncho.albedo_color = Color(0.45, 0.27, 0.14, 1)
		body.material = poncho
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.86, 0.74, 0.42, 1)
	var hat := Node3D.new()
	hat.name = "Chupalla"
	hat.position = Vector3(0, 1.82, 0)
	var brim := CSGCylinder3D.new()
	brim.radius = 0.42
	brim.height = 0.03
	brim.sides = 16
	brim.material = straw
	hat.add_child(brim)
	var crown := CSGCylinder3D.new()
	crown.radius = 0.2
	crown.height = 0.16
	crown.sides = 16
	crown.position = Vector3(0, 0.09, 0)
	crown.material = straw
	hat.add_child(crown)
	var band := CSGCylinder3D.new()
	band.radius = 0.205
	band.height = 0.04
	band.sides = 16
	band.position = Vector3(0, 0.04, 0)
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.1, 0.08, 0.06, 1)
	band.material = band_mat
	hat.add_child(band)
	npc.add_child(hat)


func on_arrive(npc: CharacterBody3D) -> void:
	GameManager.mojados_unlocked = true
	if npc.has_method("set_completo_order"):
		npc.set_completo_order("Completo Italiano MOJADO", "Palta + Mayo + pan mojado en la olla", true, true, false, true)
	npc.patience_time = talquino_patience
	npc.patience_remaining = talquino_patience
	var label := npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = " ¡Wena compadre! Vengo de Talca.\nUn Italiano MOJADO, con el pan\nmojadito en la olla, como allá. "
		label.modulate = Color(1.0, 0.85, 0.45, 1.0)
	GameManager.request_hint("Completo mojado: arma el completo y moja el pan en la OLLA de la cocina antes de entregarlo.")


func on_leave(npc: CharacterBody3D) -> void:
	var label := npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.visible = true
		label.text = " ¡Ahora sí que me siento en Talca! "
