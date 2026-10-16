class_name RappiEvent
extends StaticNPCEvent
## Evento Estático: El Repartidor de Rappi (HU-16).
## En el Día 3 llega un repartidor en moto con un pedido de la app de VARIOS completos.
## Se entregan uno por uno (en orden) contra el reloj de la app. Paga cada completo
## y una propina si se completa el pedido. Un completo equivocado descuenta tiempo.

## Cantidad de completos del pedido
@export var order_size: int = 2
## Tiempo total que da la app para todo el pedido (segundos)
@export var app_patience: float = 55.0
## Segundos descontados por entregar un completo equivocado
@export var wrong_item_penalty: float = 8.0
## Propina de la app al completar el pedido
@export var app_tip: int = 1500
## Velocidad de la moto al llegar
@export var moto_speed: float = 5.0


func _init() -> void:
	super._init()
	id = "rappi"
	event_name = "Repartidor de Rappi"
	description = "Un repartidor en moto retira un pedido de la app con varios completos contra el reloj."
	trigger_day = 3
	trigger_day_served_count = 3
	trigger_served_count = 0
	trigger_once = true


func apply(npc: CharacterBody3D) -> void:
	if "custom_appearance" in npc:
		npc.custom_appearance = true
	if "speed" in npc:
		npc.speed = moto_speed
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(1.0, 0.36, 0.05, 1)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06, 1)
	var body := npc.get_node_or_null("BodyMesh") as CSGCylinder3D
	if body:
		body.material = orange
	# Casco
	var helmet := CSGSphere3D.new()
	helmet.name = "Casco"
	helmet.radius = 0.27
	helmet.radial_segments = 12
	helmet.rings = 6
	helmet.position = Vector3(0, 1.68, 0)
	helmet.material = dark
	npc.add_child(helmet)
	# Mochila térmica naranja con el logo
	var bag := CSGBox3D.new()
	bag.name = "Mochila"
	bag.size = Vector3(0.5, 0.5, 0.4)
	bag.position = Vector3(0, 1.15, 0.38)
	bag.material = orange
	npc.add_child(bag)
	var logo := Label3D.new()
	logo.text = "rappi"
	logo.font_size = 48
	logo.pixel_size = 0.004
	logo.modulate = Color(1, 1, 1, 1)
	logo.position = Vector3(0, 1.18, 0.585)
	npc.add_child(logo)
	# Moto: dos ruedas y un chasis bajo el repartidor
	var moto := Node3D.new()
	moto.name = "Moto"
	for z in [-0.55, 0.55]:
		var wheel := CSGCylinder3D.new()
		wheel.radius = 0.26
		wheel.height = 0.1
		wheel.sides = 14
		wheel.rotation_degrees = Vector3(0, 0, 90)
		wheel.position = Vector3(0, 0.26, z)
		wheel.material = dark
		moto.add_child(wheel)
	var frame := CSGBox3D.new()
	frame.size = Vector3(0.18, 0.18, 1.0)
	frame.position = Vector3(0, 0.5, 0)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.7, 0.08, 0.08, 1)
	frame.material = red
	moto.add_child(frame)
	var handle := CSGBox3D.new()
	handle.size = Vector3(0.6, 0.05, 0.05)
	handle.position = Vector3(0, 1.0, -0.5)
	handle.material = dark
	moto.add_child(handle)
	var headlight := OmniLight3D.new()
	headlight.light_color = Color(1, 0.95, 0.8)
	headlight.light_energy = 1.2
	headlight.omni_range = 3.0
	headlight.position = Vector3(0, 0.9, -0.7)
	moto.add_child(headlight)
	npc.add_child(moto)


func on_arrive(npc: CharacterBody3D) -> void:
	var orders: Array = []
	for i in order_size:
		var rec: Dictionary = _pick_recipe()
		orders.append(rec)
	npc.set_meta("rappi_orders", orders)
	npc.set_meta("rappi_step", 0)
	npc.set_meta("rappi_code", randi_range(1000, 9999))
	npc.patience_time = app_patience
	npc.patience_remaining = app_patience
	_set_current_order(npc)
	SFXManager.play_moto_horn()
	GameManager.request_hint("Pedido de Rappi: entrega los %d completos en orden antes de que se acabe el tiempo de la app." % order_size)


func on_item_received(npc: CharacterBody3D, item: Node) -> bool:
	var orders: Array = npc.get_meta("rappi_orders", [])
	var step: int = npc.get_meta("rappi_step", 0)
	if step >= orders.size():
		return false
	var rec: Dictionary = orders[step]
	var is_correct := false
	if item and item.has_method("is_valid_base") and item.is_valid_base():
		is_correct = item.matches_order(true, rec["palta"], rec["mayo"], rec["ketchup"], rec.get("mojado", false))
	if item and item.get_parent():
		item.get_parent().remove_child(item)
	if item:
		item.queue_free()

	var label := npc.get_node_or_null("Label3D") as Label3D
	if not is_correct:
		npc.patience_remaining = maxf(0.5, npc.patience_remaining - wrong_item_penalty)
		SFXManager.play_incorrect()
		if label:
			label.text = " ¡Ese no es el del pedido! La app dice:\n%s " % _order_text(rec)
			label.modulate = Color(1.0, 0.4, 0.3, 1.0)
		return true

	var payment: int = GameManager.calculate_completo_payment(0.0, rec.get("mojado", false))
	GameManager.earn_money(payment, "Completo Rappi")
	SFXManager.play_cash()
	step += 1
	npc.set_meta("rappi_step", step)
	if step < orders.size():
		_set_current_order(npc)
		return true

	GameManager.earn_money(app_tip, "Propina de la app")
	npc.finish_visit(" ¡Pedido completo! 5 estrellas para el local.\n+$%s de propina " % GameManager.format_money(app_tip), "correct", Color(0.4, 1.0, 0.5, 1.0))
	return true


func on_timeout(npc: CharacterBody3D) -> bool:
	npc.finish_visit(" Se canceló el pedido en la app...\n1 estrella. ", "left", Color(1.0, 0.4, 0.3, 1.0))
	return true


func on_leave(npc: CharacterBody3D) -> void:
	SFXManager.play_moto_horn()
	if "speed" in npc:
		npc.speed = moto_speed


func _pick_recipe() -> Dictionary:
	var recipes: Array = NPC.COMPLETO_RECIPES
	var rec: Dictionary = (recipes.pick_random() as Dictionary).duplicate()
	rec["mojado"] = GameManager.mojados_unlocked and randf() < 0.35
	if rec["mojado"]:
		rec["name"] = String(rec["name"]) + " MOJADO"
		rec["desc"] = String(rec["desc"]) + " + pan mojado"
	return rec


func _order_text(rec: Dictionary) -> String:
	return "%s (%s)" % [rec.get("name", "Completo"), rec.get("desc", "")]


func _set_current_order(npc: CharacterBody3D) -> void:
	var orders: Array = npc.get_meta("rappi_orders", [])
	var step: int = npc.get_meta("rappi_step", 0)
	if step >= orders.size():
		return
	var rec: Dictionary = orders[step]
	npc.set_completo_order(String(rec["name"]), String(rec["desc"]), rec["palta"], rec["mayo"], rec["ketchup"], rec.get("mojado", false))
	var label := npc.get_node_or_null("Label3D") as Label3D
	if label:
		var lines := " Pedido Rappi #%d  [%d/%d]\n%s " % [npc.get_meta("rappi_code", 0), step + 1, orders.size(), _order_text(rec)]
		if step + 1 < orders.size():
			lines += "\nDespués: %s " % _order_text(orders[step + 1])
		label.text = lines
		label.modulate = Color(1.0, 0.6, 0.2, 1.0)
