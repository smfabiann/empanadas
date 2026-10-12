extends CharacterBody3D
## Jugador en primera persona detrás del mostrador.
## Movimiento WASD en el área del cajero + rotación 360° con el ratón.
## Agarra ítems del estante (E), los entrega a clientes (E), y puede soltarlos (Q).

const MOUSE_SENSITIVITY := 0.002
const PITCH_LIMIT := deg_to_rad(80.0)
const WALK_SPEED := 3.5
const SPRINT_SPEED := 5.8
const JUMP_VELOCITY := 3.0

# --- Head bob y FOV ---
const BOB_FREQUENCY := 10.0
const BOB_AMPLITUDE := 0.03
const BASE_FOV := 75.0
const SPRINT_FOV := 82.0
var _bob_timer: float = 0.0

@onready var camera: Camera3D = $Camera3D
@onready var ray: RayCast3D = $Camera3D/RayCast3D
@onready var hold_point: Marker3D = $Camera3D/HoldPoint
@onready var ui: CanvasLayer = get_parent().get_node_or_null("UI")

var held_item: Interactable = null
var is_dead: bool = false

var is_viewing_monitor: bool = false

# --- Efectos de temblor de cámara (Screen Shake) ---
var _shake_timer: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_is_crescendo: bool = false


func _ready() -> void:
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	floor_snap_length = 0.25
	floor_constant_speed = true
	camera.current = true


func _physics_process(delta: float) -> void:
	_update_camera_shake(delta)
	if not GameManager.can_player_act() or is_dead or is_viewing_monitor:
		return
	_handle_movement(delta)


## Activa un temblor de pantalla que decae con el tiempo
func shake_camera(duration: float, intensity: float = 0.06) -> void:
	_shake_duration = maxf(duration, 0.05)
	_shake_timer = _shake_duration
	_shake_intensity = intensity
	_shake_is_crescendo = false


## Activa un temblor de pantalla que aumenta progresivamente en intensidad (in crescendo)
func shake_camera_crescendo(duration: float, max_intensity: float = 0.08) -> void:
	_shake_duration = maxf(duration, 0.05)
	_shake_timer = _shake_duration
	_shake_intensity = max_intensity
	_shake_is_crescendo = true


## Detiene inmediatamente cualquier temblor y resetea la cámara
func stop_camera_shake() -> void:
	_shake_timer = 0.0
	if camera:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _update_camera_shake(delta: float) -> void:
	if not camera:
		return
	if _shake_timer > 0.0:
		_shake_timer -= delta
		var progress: float = clampf(_shake_timer / _shake_duration, 0.0, 1.0)
		var current_amp: float = 0.0
		if _shake_is_crescendo:
			current_amp = _shake_intensity * lerpf(1.0, 0.15, progress)
		else:
			current_amp = _shake_intensity * progress
		camera.h_offset = randf_range(-current_amp, current_amp)
		camera.v_offset = randf_range(-current_amp, current_amp)
	else:
		if camera.h_offset != 0.0 or camera.v_offset != 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0


func _process(_delta: float) -> void:
	if not GameManager.can_player_act() or is_dead:
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

	# Salto (acción 'jump' configurada en el Input Map)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_vec := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_vec.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_vec.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_vec.x += 1.0

	# Sprint con la acción 'sprint' mapeada a Shift
	var is_sprinting := (
		(Input.is_action_pressed("sprint") or Input.is_physical_key_pressed(KEY_SHIFT))
		and input_vec != Vector2.ZERO
	)
	var current_speed := SPRINT_SPEED if is_sprinting else WALK_SPEED

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
		velocity.x = move_dir.x * current_speed
		velocity.z = move_dir.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	# Movimiento completamente libre con colisiones
	move_and_slide()

	# Head bob al caminar / correr
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > 0.5 and is_on_floor():
		var bob_freq := BOB_FREQUENCY * (1.3 if is_sprinting else 1.0)
		var bob_amp := BOB_AMPLITUDE * (1.2 if is_sprinting else 1.0)
		_bob_timer += delta * bob_freq
		camera.position.y = 1.6 + sin(_bob_timer) * bob_amp
	else:
		_bob_timer = 0.0
		camera.position.y = lerpf(camera.position.y, 1.6, delta * 10.0)

	# Suave ajuste de FOV dinámico al correr
	var target_fov := SPRINT_FOV if (is_sprinting and horizontal_speed > 1.0) else BASE_FOV
	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)


func pick_up_direct(item: Interactable) -> void:
	"""Recoge un ítem de forma directa (ej. dispensado por una estación)."""
	held_item = item
	ray.add_exception(held_item)
	held_item.interact(self)


func _update_interaction_prompt() -> void:
	if not ui or not ui.has_method("set_prompt"):
		return

	if is_viewing_monitor:
		var sec_script = load("res://scripts/SecurityMonitor.gd")
		if sec_script and sec_script.active_monitor:
			var info: Dictionary = sec_script.active_monitor.get_interaction_prompt(self)
			ui.set_prompt(info.get("text", ""), info.get("actionable", true))
		else:
			ui.set_prompt("[E] Volver a tu vista\n[F] Visión Nocturna", true)
		return

	# Si sostenemos un ítem:
	if held_item != null:
		if ray.is_colliding():
			var col = ray.get_collider()
			if col != null and col != held_item and col.has_method("get_interaction_prompt"):
				var info: Dictionary = col.get_interaction_prompt(self)
				ui.set_prompt(info.get("text", ""), info.get("actionable", false))
				return

		var target_npc := _get_target_npc()
		if target_npc != null and target_npc.requested_item != null:
			var item_desc: String = held_item.item_data.display_name if held_item.item_data else "Ítem"
			ui.set_prompt("[E] Entregar " + item_desc + " (Pide: " + target_npc.requested_item.display_name + ")", true)
		else:
			var item_desc: String = held_item.item_data.display_name if held_item.item_data else "Ítem"
			ui.set_prompt("Sosteniendo: " + item_desc + "  |  [Q] Soltar", false)
		return

	# Si las manos están vacías:
	if ray.is_colliding():
		var col = ray.get_collider()
		if col is Interactable:
			var prompt_text: String = "[E] Recoger " + (col.item_data.display_name if col.item_data else "Ítem")
			if col.has_method("get_interaction_prompt"):
				var info: Dictionary = col.get_interaction_prompt(self)
				prompt_text = info.get("text", prompt_text)
			ui.set_prompt(prompt_text, true)
			return
		elif col != null and col.has_method("get_interaction_prompt"):
			var info: Dictionary = col.get_interaction_prompt(self)
			ui.set_prompt(info.get("text", ""), info.get("actionable", false))
			return
		elif col != null and col.has_method("interact"):
			ui.set_prompt("[E] Interactuar", true)
			return

	# Si miramos al cliente con las manos vacías, mostrar lo que pide
	var target_npc := _get_target_npc()
	if target_npc != null and target_npc.requested_item != null:
		ui.set_prompt(" Cliente pide: " + target_npc.requested_item.display_name, false)
		return

	ui.set_prompt("", false)


func _get_target_npc() -> Node:
	# 1. Intentar colisión directa del RayCast con el NPC
	if ray.is_colliding():
		var col := ray.get_collider()
		if col and col.has_method("receive_item"):
			if not col.has_method("can_receive_item") or col.can_receive_item():
				return col

	# 2. Si miramos hacia un NPC que esté esperando con un pedido
	var npcs := get_tree().get_nodes_in_group("npcs")
	var cam_fwd: Vector3 = -camera.global_transform.basis.z
	for npc in npcs:
		if npc.has_method("can_receive_item") and npc.can_receive_item():
			var to_npc: Vector3 = (npc.global_position - camera.global_position).normalized()
			if cam_fwd.dot(to_npc) > 0.25:
				var dist: float = global_position.distance_to(npc.global_position)
				if dist < 4.2:
					return npc

	return null


func _input(event: InputEvent) -> void:
	if not GameManager.can_player_act() or is_dead:
		return

	# Rotar la vista con el ratón (360° horizontal, limitado vertical)
	if event is InputEventMouseMotion and not is_viewing_monitor:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		camera.rotation.x = clampf(camera.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)
		get_viewport().set_input_as_handled()

	# Interactuar: recoger ítem, usar estación o entregar a NPC
	if event.is_action_pressed("interact"):
		_handle_interact()

	# Soltar ítem
	if event.is_action_pressed("drop_item"):
		_drop_held_item()
		
	# Visión de anomalías en el monitor (tecla F)
	if event is InputEventKey and event.keycode == KEY_F and event.pressed and not event.echo:
		if is_viewing_monitor:
			var sec_script = load("res://scripts/SecurityMonitor.gd")
			if sec_script and sec_script.active_monitor:
				sec_script.active_monitor.toggle_anomaly_vision()
			elif ray.is_colliding():
				var collider = ray.get_collider()
				if collider.has_method("toggle_anomaly_vision"):
					collider.toggle_anomaly_vision()


func _handle_interact() -> void:
	# Si ya estamos viendo el monitor, presionar E nos regresa inmediatamente
	if is_viewing_monitor:
		var sec_script = load("res://scripts/SecurityMonitor.gd")
		if sec_script and sec_script.active_monitor:
			sec_script.active_monitor.interact(self)
			_update_interaction_prompt()
			return

	# Prioridad: Manos vacías -> recoger ítem o usar estaciones / botones
	if held_item == null:
		if ray.is_colliding():
			var collider := ray.get_collider()
			if collider is Interactable:
				held_item = collider as Interactable
				ray.add_exception(held_item)
				held_item.interact(self)
			elif collider != null and collider.has_method("get_interaction_prompt"):
				collider.interact(self)
			elif collider != null and collider.has_method("interact"):
				collider.interact(self)
			_update_interaction_prompt()
		return

	# Prioridad: Sosteniendo ítem -> Usar en estación o interactuable compatible
	if ray.is_colliding():
		var collider = ray.get_collider()
		if collider != null and collider != held_item and collider.has_method("get_interaction_prompt"):
			collider.interact(self)
			_update_interaction_prompt()
			return

	# Prioridad: Sosteniendo ítem -> Entregar al NPC
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
	if ray:
		ray.remove_exception(item_to_drop)
	if item_to_drop.has_method("drop"):
		item_to_drop.drop()


## Anima la caída del jugador al ser abatido (cámara al suelo ladeada)
func fall_down() -> void:
	if is_dead:
		return
	is_dead = true

	# Soltar inmediatamente lo que tenga en las manos
	_drop_held_item()
	velocity = Vector3.ZERO

	# Caída al suelo: cabeza en el piso (Y = 0.22), ladeada hacia arriba/lado
	var tween := create_tween().set_parallel(true)
	# Caída vertical rápida
	tween.tween_property(camera, "position:y", 0.22, 0.45)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	# Ladeada (roll Z = 38°) como la mejilla apoyada en el piso
	tween.tween_property(camera, "rotation_degrees:z", 38.0, 0.5)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)
	# Ligeramente inclinada hacia arriba/suelo (pitch X = -16°)
	tween.tween_property(camera, "rotation_degrees:x", -16.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
