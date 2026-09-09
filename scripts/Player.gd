extends CharacterBody3D
## Jugador en primera persona detrás del mostrador.
## Movimiento WASD en el área del cajero + rotación 360° con el ratón.
## Agarra ítems del estante (E), los entrega a clientes (E), y puede soltarlos (Q).

const MOUSE_SENSITIVITY := 0.002
const PITCH_LIMIT := deg_to_rad(80.0)
const MOVE_SPEED := 3.5

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var hold_point: Marker3D = $Camera3D/HoldPoint
@onready var ui: CanvasLayer = get_parent().get_node_or_null("UI")

var held_item: Interactable = null


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if not GameManager.game_active:
		return
	_handle_movement(delta)


func _process(_delta: float) -> void:
	if not GameManager.game_active:
		if ui and ui.has_method("set_prompt"):
			ui.set_prompt("", false)
		return
	_update_interaction_prompt()


func _handle_movement(delta: float) -> void:
	# Gravedad estándar
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0.0

	var input_vec := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_vec.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_vec.x += 1.0

	if input_vec != Vector2.ZERO:
		input_vec = input_vec.normalized()
		# Moverse relativo a la orientación horizontal del jugador
		var forward := -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized()

		var right := global_transform.basis.x
		right.y = 0.0
		right = right.normalized()

		var move_dir := (right * input_vec.x + forward * -input_vec.y)
		velocity.x = move_dir.x * MOVE_SPEED
		velocity.z = move_dir.z * MOVE_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, MOVE_SPEED)
		velocity.z = move_toward(velocity.z, 0.0, MOVE_SPEED)

	# Movimiento completamente libre con colisiones
	move_and_slide()


func _update_interaction_prompt() -> void:
	if not ui or not ui.has_method("set_prompt"):
		return

	if held_item != null:
		var target_npc := _get_target_npc()
		if target_npc != null and target_npc.requested_item != null:
			ui.set_prompt("[E] Entregar " + held_item.item_data.display_name + " (Pide: " + target_npc.requested_item.display_name + ")", true)
		else:
			ui.set_prompt("Sosteniendo: " + held_item.item_data.display_name + "  |  [Q] Soltar", false)
	else:
		if ray.is_colliding():
			var collider := ray.get_collider()
			if collider is Interactable and collider.item_data:
				ui.set_prompt("[E] Recoger " + collider.item_data.display_name, true)
				return

		# Si miramos al cliente con las manos vacías, mostrar lo que pide
		var target_npc := _get_target_npc()
		if target_npc != null and target_npc.requested_item != null:
			ui.set_prompt("👤 Cliente pide: " + target_npc.requested_item.display_name, false)
			return

		ui.set_prompt("", false)


func _get_target_npc() -> Node:
	# 1. Intentar colisión directa del RayCast con el NPC
	if ray.is_colliding():
		var col := ray.get_collider()
		if col and col.has_method("receive_item"):
			if not col.has_method("can_receive_item") or col.can_receive_item():
				return col

	# 2. Si apuntamos hacia un NPC que esté esperando con un pedido
	var npcs := get_tree().get_nodes_in_group("npcs")
	for npc in npcs:
		if npc.has_method("can_receive_item") and npc.can_receive_item():
			var dist := global_position.distance_to(npc.global_position)
			if dist < 3.8:
				return npc

	return null


func _input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return

	# Rotar la vista con el ratón (360° horizontal, limitado vertical)
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
		get_viewport().set_input_as_handled()

	# Interactuar: recoger ítem o entregar a NPC
	if event.is_action_pressed("interact"):
		_handle_interact()

	# Soltar ítem
	if event.is_action_pressed("drop_item"):
		_drop_held_item()


func _handle_interact() -> void:
	# Caso 1: Manos vacías -> recoger ítem
	if held_item == null:
		if ray.is_colliding():
			var collider := ray.get_collider()
			if collider is Interactable:
				held_item = collider as Interactable
				ray.add_exception(held_item)
				held_item.interact(self)
		return

	# Caso 2: Sosteniendo ítem -> entregar al NPC
	var target_npc := _get_target_npc()
	if target_npc != null:
		var item_to_deliver := held_item
		held_item = null
		ray.remove_exception(item_to_deliver)
		target_npc.receive_item(item_to_deliver)


func _drop_held_item() -> void:
	if held_item == null:
		return
	var item_to_drop := held_item
	held_item = null
	ray.remove_exception(item_to_drop)
	item_to_drop.drop()
