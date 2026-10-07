class_name IngredientStation
extends StaticBody3D
## Estación de trabajo 3D para preparar completos (HU-11).
## Permite al jugador interactuar directamente en el mundo 3D sin menús ni interfaces 2D:
## - Toma el pan base
## - Aplica salchicha, palta, mayo o kétchup al completo que lleva en la mano
## - Descarta ítems equivocados en el basurero

@export_enum("bread", "sausage", "palta", "mayo", "ketchup", "trash") var station_type: String = "bread"
@export var station_name: String = "Pan"
@export var completo_scene: PackedScene = preload("res://scenes/items/Completo.tscn")

@onready var label: Label3D = get_node_or_null("Label3D")


func _ready() -> void:
	collision_layer = 2 # Capa Interactable
	collision_mask = 0


## Retorna el texto del prompt contextual según lo que el jugador lleve en las manos
func get_interaction_prompt(player: Node) -> Dictionary:
	var held = player.get("held_item")
	var is_completo: bool = held != null and held.has_method("add_ingredient")

	match station_type:
		"bread":
			if held == null:
				return {"text": "[E] Tomar Pan de Completo", "actionable": true}
			elif is_completo:
				return {"text": "Ya tienes un completo en mano", "actionable": false}
			else:
				return {"text": "Manos ocupadas", "actionable": false}

		"sausage":
			if is_completo:
				var count: int = held.get("sausage_count") if "sausage_count" in held else (1 if held.has_sausage else 0)
				if count == 0:
					return {"text": "[E] Poner Salchicha / Vienesa", "actionable": true}
				else:
					return {"text": "[E] Poner otra Salchicha / Vienesa", "actionable": true}
			elif held == null:
				return {"text": "Toma primero un Pan para poner la vienesa", "actionable": false}
			else:
				return {"text": "Ítem no compatible con vienesa", "actionable": false}

		"palta":
			if is_completo:
				var count: int = held.get("palta_count") if "palta_count" in held else (1 if held.has_palta else 0)
				if count == 0:
					return {"text": "[E] Untar Palta", "actionable": true}
				else:
					return {"text": "[E] Untar más Palta", "actionable": true}
			elif held == null:
				return {"text": "Toma primero un Pan para agregar palta", "actionable": false}
			else:
				return {"text": "Ítem no compatible con palta", "actionable": false}

		"mayo":
			if is_completo:
				var count: int = held.get("mayo_count") if "mayo_count" in held else (1 if held.has_mayo else 0)
				if count == 0:
					return {"text": "[E] Echar Mayonesa", "actionable": true}
				else:
					return {"text": "[E] Echar más Mayonesa", "actionable": true}
			elif held == null:
				return {"text": "Toma primero un Pan para agregar mayo", "actionable": false}
			else:
				return {"text": "Ítem no compatible con mayonesa", "actionable": false}

		"ketchup":
			if is_completo:
				var count: int = held.get("ketchup_count") if "ketchup_count" in held else (1 if held.has_ketchup else 0)
				if count == 0:
					return {"text": "[E] Echar Kétchup", "actionable": true}
				else:
					return {"text": "[E] Echar más Kétchup", "actionable": true}
			elif held == null:
				return {"text": "Toma primero un Pan para agregar kétchup", "actionable": false}
			else:
				return {"text": "Ítem no compatible con kétchup", "actionable": false}

		"trash":
			if held != null:
				return {"text": "[E] Tirar a la basura", "actionable": true}
			else:
				return {"text": "Basurero", "actionable": false}

	return {"text": station_name, "actionable": false}


## Ejecuta la interacción al presionar [E]
func interact(player: Node) -> void:
	var held = player.get("held_item")

	match station_type:
		"bread":
			if held == null:
				_dispense_bread(player)

		"sausage", "palta", "mayo", "ketchup":
			if held != null and held.has_method("add_ingredient"):
				var added: bool = held.add_ingredient(station_type)
				if added:
					SFXManager.play_pickup()
					_animate_station_bounce()

		"trash":
			if held != null:
				_discard_held_item(player)


## Entrega un nuevo pan de completo al jugador
func _dispense_bread(player: Node) -> void:
	if completo_scene == null or not is_inside_tree():
		return

	var new_completo = completo_scene.instantiate()
	var root: Node = get_tree().current_scene
	if root == null:
		root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)
	root.add_child(new_completo)
	new_completo.global_position = global_position + Vector3(0, 0.3, 0)

	if player.has_method("pick_up_direct"):
		player.pick_up_direct(new_completo)
	else:
		new_completo.interact(player)

	SFXManager.play_pickup()
	_animate_station_bounce()


## Desecha el ítem que sostiene el jugador
func _discard_held_item(player: Node) -> void:
	var held = player.get("held_item")
	if held == null:
		return

	player.set("held_item", null)
	var ray = player.get_node_or_null("Camera3D/RayCast3D")
	if ray and held != null:
		ray.remove_exception(held)

	if held.get_parent():
		held.get_parent().remove_child(held)
	held.queue_free()

	SFXManager.play_drop()
	_animate_station_bounce()


## Pequeño rebote visual en la estación al ser usada
func _animate_station_bounce() -> void:
	var visual = get_node_or_null("Visual") as Node3D
	if visual == null:
		visual = self
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3(1.1, 0.9, 1.1), 0.08)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.12).set_ease(Tween.EASE_OUT)
