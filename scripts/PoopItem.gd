class_name PoopItem
extends Interactable
## Ítem físico de Caca producido por el baño químico.
## Se puede recoger, sostener, soltar y añadir como ingrediente al completo.

func _ready() -> void:
	add_to_group("poop")
	if item_data == null:
		item_data = load("res://resources/items/poop.tres")
	super._ready()


func get_interaction_prompt(player: Node) -> Dictionary:
	var held = player.get("held_item")
	if held != null and held.has_method("add_ingredient"):
		return {"text": "[E] Añadir caca al Completo 💩", "actionable": true}
	elif held == null:
		return {"text": "[E] Recoger Caca 💩", "actionable": true}
	else:
		return {"text": "Manos ocupadas", "actionable": false}


func interact(player: Node) -> void:
	var held = player.get("held_item")
	if held != null and held != self and held.has_method("add_ingredient"):
		var added: bool = held.add_ingredient("poop")
		if added:
			SFXManager.play_pickup()
			if is_inside_tree() and get_parent() != null:
				get_parent().remove_child(self)
			queue_free()
		return

	if held == null:
		player.set("held_item", self)
		var ray = player.get_node_or_null("Camera3D/RayCast3D")
		if ray:
			ray.add_exception(self)

	super.interact(player)
