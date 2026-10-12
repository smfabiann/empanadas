class_name ChemicalToilet
extends StaticBody3D
## Inodoro químico dentro del baño químico (HU baño químico y caca).
## Permite al jugador:
## - Usar el inodoro para hacer caca (spawnea un ítem físico de caca 3D).
## - Si sostiene un completo, defecar directamente sobre el completo como ingrediente.
## - Descartar caca en el inodoro.

@export var poop_scene: PackedScene = preload("res://scenes/items/Poop.tscn")

@onready var toilet_spawn: Marker3D = get_node_or_null("SpawnPoint")
@onready var toilet_label: Label3D = get_node_or_null("Label3D")


func _ready() -> void:
	collision_layer = 2 # Capa Interactable
	collision_mask = 0


## Retorna el prompt contextual para la interacción con el inodoro
func get_interaction_prompt(player: Node) -> Dictionary:
	var held = player.get("held_item")
	var is_completo: bool = held != null and held.has_method("add_ingredient")
	var is_poop: bool = held != null and (held.is_in_group("poop") or (held.get("item_data") and held.item_data.id == "poop"))

	if is_completo:
		return {"text": "[E] Defecar en el Completo ", "actionable": true}
	elif is_poop:
		return {"text": "[E] Tirar caca al inodoro ", "actionable": true}
	elif held == null:
		return {"text": "[E] Usar baño químico (Hacer caca )", "actionable": true}
	else:
		return {"text": "Manos ocupadas", "actionable": false}


## Ejecuta la interacción al presionar [E]
func interact(player: Node) -> void:
	var held = player.get("held_item")
	var is_completo: bool = held != null and held.has_method("add_ingredient")
	var is_poop: bool = held != null and (held.is_in_group("poop") or (held.get("item_data") and held.item_data.id == "poop"))

	# Caso 1: Sosteniendo un Completo -> Defecar directamente sobre el completo
	if is_completo:
		_poop_on_completo(held, player)
		return

	# Caso 2: Sosteniendo Caca -> Desecharla en el inodoro
	if is_poop:
		_flush_held_poop(held, player)
		return

	# Caso 3: Manos vacías -> Hacer caca física en el inodoro
	if held == null:
		make_poop(player)


## Genera un ítem físico de caca en el inodoro
func make_poop(player: Node = null) -> Node:
	SFXManager.play_fart()

	if player and player.has_method("shake_camera"):
		player.shake_camera(0.4, 0.025)

	if poop_scene == null:
		return null

	var poop = poop_scene.instantiate()
	var spawn_pos: Vector3 = Vector3(0, 0.5, 0)
	if toilet_spawn and toilet_spawn.is_inside_tree():
		spawn_pos = toilet_spawn.global_position
	elif is_inside_tree():
		spawn_pos = global_position + Vector3(0, 0.5, 0)

	var target_parent: Node = null
	if is_inside_tree() and get_tree() != null:
		target_parent = get_tree().current_scene
		if target_parent == null:
			target_parent = get_tree().root
	if target_parent == null:
		target_parent = get_parent()
	if target_parent != null:
		target_parent.add_child(poop)
		poop.global_position = spawn_pos
	else:
		poop.position = spawn_pos

	# Rebote pop de salida
	poop.scale = Vector3(0.5, 0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(poop, "scale", Vector3(1.25, 1.25, 1.25), 0.15)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(poop, "scale", Vector3.ONE, 0.1)

	if toilet_label:
		_flash_toilet_label(" *¡PLOP!* Caca lista")

	return poop


## Defeca directamente en el completo que lleva el jugador
func _poop_on_completo(completo: Node, player: Node) -> void:
	SFXManager.play_fart()
	if player and player.has_method("shake_camera"):
		player.shake_camera(0.4, 0.03)

	var added: bool = completo.add_ingredient("poop")
	if added and toilet_label:
		_flash_toilet_label(" ¡Caca untada en el completo!")


## Descarta la caca que sostiene el jugador
func _flush_held_poop(held: Node, player: Node) -> void:
	SFXManager.play_drop()
	player.set("held_item", null)
	var ray = player.get_node_or_null("Camera3D/RayCast3D")
	if ray and held != null:
		ray.remove_exception(held)
	if held.get_parent():
		held.get_parent().remove_child(held)
	held.queue_free()

	if toilet_label:
		_flash_toilet_label(" ¡Caca descargada!")


func _flash_toilet_label(text_msg: String) -> void:
	if toilet_label == null:
		return
	var orig_text := toilet_label.text
	toilet_label.text = text_msg
	get_tree().create_timer(1.8).timeout.connect(func():
		if is_instance_valid(toilet_label):
			toilet_label.text = orig_text
	)
