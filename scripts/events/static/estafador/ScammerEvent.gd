class_name ScammerEvent
extends StaticNPCEvent
## Evento Estático: El Estafador del "chip de perro" (HU-15).
## En el Día 3 llega un supuesto inspector que asegura que las vienesas tienen chip
## de perro y exige plata para no "denunciar" el local. Es una estafa:
## - Bajar la persiana lo echa sin perder nada (respuesta correcta).
## - Entregarle cualquier cosa es aceptar el soborno: se lleva el ítem y la plata.
## - Si se le agota la paciencia, saca la plata de la caja por su cuenta.

## Monto que exige / roba el estafador
@export var scam_amount: int = 5000
## Paciencia del estafador (segundos) antes de cobrarse solo
@export var scammer_patience: float = 20.0
## Segundos antes de mostrar la pista de la persiana
@export var hint_delay: float = 4.0


func _init() -> void:
	super._init()
	id = "estafador_chip"
	event_name = "El Estafador del Chip de Perro"
	description = "Un falso inspector dice que las vienesas tienen chip de perro y exige plata. Hay que echarlo con la persiana."
	trigger_day = 3
	trigger_day_served_count = 1
	trigger_served_count = 0
	trigger_once = true


func apply(npc: CharacterBody3D) -> void:
	if "custom_appearance" in npc:
		npc.custom_appearance = true
	var body := npc.get_node_or_null("BodyMesh") as CSGCylinder3D
	if body:
		var suit := StandardMaterial3D.new()
		suit.albedo_color = Color(0.16, 0.17, 0.2, 1)
		body.material = suit
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.02, 0.02, 1)
	black.roughness = 0.1
	# Lentes oscuros de "inspector"
	var glasses := CSGBox3D.new()
	glasses.name = "Lentes"
	glasses.size = Vector3(0.36, 0.08, 0.06)
	glasses.position = Vector3(0, 1.64, -0.22)
	glasses.material = black
	npc.add_child(glasses)
	# Credencial trucha colgando del cuello
	var badge := CSGBox3D.new()
	badge.name = "Credencial"
	badge.size = Vector3(0.14, 0.18, 0.02)
	badge.position = Vector3(0, 1.15, -0.21)
	var badge_mat := StandardMaterial3D.new()
	badge_mat.albedo_color = Color(0.95, 0.95, 0.9, 1)
	badge.material = badge_mat
	npc.add_child(badge)
	var badge_text := Label3D.new()
	badge_text.text = "INSPECTOR\n(trucho)"
	badge_text.font_size = 9
	badge_text.pixel_size = 0.004
	badge_text.modulate = Color(0.1, 0.1, 0.4, 1)
	badge_text.position = Vector3(0, 1.15, -0.225)
	badge_text.rotation_degrees = Vector3(0, 180, 0)
	npc.add_child(badge_text)


func on_arrive(npc: CharacterBody3D) -> void:
	var demand := ItemData.new()
	demand.id = "estafa"
	demand.display_name = "$%s de \"multa\" por chip de perro" % GameManager.format_money(scam_amount)
	npc.requested_item = demand
	npc.patience_time = scammer_patience
	npc.patience_remaining = scammer_patience
	var label := npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = " ¡Oiga! Soy inspector sanitario.\nSus vienesas tienen CHIP DE PERRO.\nPáseme $%s o lo denuncio. " % GameManager.format_money(scam_amount)
		label.modulate = Color(1.0, 0.6, 0.25, 1.0)
	if npc.is_inside_tree():
		npc.get_tree().create_timer(hint_delay).timeout.connect(func():
			if is_instance_valid(npc) and npc.has_method("is_order_resolved") and not npc.is_order_resolved():
				GameManager.request_hint("¿Chip de perro? Es una estafa. Baja la persiana (botón del mostrador) para echarlo sin pagar.")
		)


## Entregarle algo = caer en la estafa: se lleva el ítem y la plata
func on_item_received(npc: CharacterBody3D, item: Node) -> bool:
	if item and item.get_parent():
		item.get_parent().remove_child(item)
	if item:
		item.queue_free()
	GameManager.lose_money(scam_amount, "Caíste en la estafa del chip de perro")
	SFXManager.play_money_lost()
	npc.finish_visit(" Mmm... sí, clarito el chip.\nMe llevo esto de evidencia... y la plata. -$%s " % GameManager.format_money(scam_amount), "wrong", Color(1.0, 0.35, 0.25, 1.0))
	return true


## Bajar la persiana: el estafador se va sin llevarse nada
func on_persiana_closed(npc: CharacterBody3D) -> bool:
	SFXManager.play_correct()
	npc.finish_visit(" ¡Ya, ya, me voy! Igual era puro chamullo... ", "correct", Color(0.4, 1.0, 0.5, 1.0))
	GameManager.request_hint("¡Bien! No caíste en la estafa del chip de perro.")
	return true


## Si nadie lo echa, se cobra solo de la caja
func on_timeout(npc: CharacterBody3D) -> bool:
	GameManager.lose_money(scam_amount, "El estafador se cobró solo")
	SFXManager.play_money_lost()
	npc.finish_visit(" ¿No me va a pagar? Ya, me pago solito de la caja. -$%s " % GameManager.format_money(scam_amount), "left", Color(1.0, 0.35, 0.25, 1.0))
	return true
