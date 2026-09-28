extends CharacterBody3D
## NPC que se acerca al mostrador, pide un ítem y se va.
## Incluye: paciencia con timer visual, variación de color, reacciones y salida sin bloqueos.

enum State { APPROACHING, QUEUING, WAITING, LEAVING }

const SPEED := 2.5

@onready var label: Label3D = $Label3D
@onready var body_mesh: CSGCylinder3D = $BodyMesh
@onready var patience_bar_bg: CSGBox3D = $PatienceBarPivot/PatienceBarBG
@onready var patience_bar_fill: CSGBox3D = $PatienceBarPivot/PatienceBarFill
@onready var patience_bar_pivot: Node3D = $PatienceBarPivot

var state: State = State.APPROACHING
var spawn_pos: Vector3
var counter_pos: Vector3
var exit_pos: Vector3
var target_pos: Vector3
var queue_index: int = 0

var requested_item: ItemData = null
var patience_time: float = 20.0
var patience_remaining: float = 20.0
var is_at_counter: bool = false
var is_leaving_cleanly: bool = false

# Lista de posibles ítems a pedir
var possible_items: Array[ItemData] = [
	preload("res://resources/items/sopaipilla.tres"),
	preload("res://resources/items/bebida.tres"),
	preload("res://resources/items/empanada.tres"),
	preload("res://resources/items/completo.tres"),
]

# Colores aleatorios para variación visual
const NPC_COLORS: Array[Color] = [
	Color(0.6, 0.2, 0.5, 1),   # Morado
	Color(0.2, 0.5, 0.6, 1),   # Teal
	Color(0.7, 0.3, 0.2, 1),   # Rojo ladrillo
	Color(0.3, 0.6, 0.3, 1),   # Verde
	Color(0.6, 0.5, 0.2, 1),   # Mostaza
	Color(0.4, 0.3, 0.6, 1),   # Lavanda
	Color(0.7, 0.4, 0.5, 1),   # Rosa
	Color(0.3, 0.4, 0.5, 1),   # Gris azulado
]

signal finished_leaving()
signal counter_vacated()


func _ready() -> void:
	add_to_group("npcs")
	label.visible = false
	patience_bar_pivot.visible = false
	global_position = spawn_pos
	if target_pos == Vector3.ZERO:
		target_pos = counter_pos

	# Color aleatorio
	var mat := StandardMaterial3D.new()
	mat.albedo_color = NPC_COLORS.pick_random()
	body_mesh.material = mat

	# Paciencia según dificultad
	patience_time = GameManager.get_patience_time()
	patience_remaining = patience_time


func _physics_process(delta: float) -> void:
	match state:
		State.APPROACHING:
			_move_toward_point(target_pos, delta)
			if _is_close_to(target_pos) or (is_on_wall() and global_position.distance_to(target_pos) < 1.0):
				_arrive_at_counter()

		State.QUEUING:
			_move_toward_point(target_pos, delta)
			# Si llegó a su lugar en la fila, orientar la vista al mostrador
			if global_position.distance_to(target_pos) < 0.25:
				look_at(global_position + Vector3(0, 0, 1), Vector3.UP)

		State.WAITING:
			_update_patience(delta)

		State.LEAVING:
			_move_toward_point(exit_pos, delta)
			# Si llegó a la salida o ya cruzó hacia la vereda exterior
			if _is_close_to(exit_pos) or global_position.z <= -4.8:
				_fade_and_free()


func _move_toward_point(target: Vector3, _delta: float) -> void:
	var direction := (target - global_position)
	direction.y = 0.0

	var dist := direction.length()
	if dist < 0.15:
		velocity = Vector3.ZERO
		return

	direction = direction.normalized()
	velocity = direction * SPEED
	move_and_slide()

	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func _is_close_to(point: Vector3) -> bool:
	var flat_distance := Vector2(global_position.x, global_position.z).distance_to(
		Vector2(point.x, point.z)
	)
	return flat_distance < 0.65


func _arrive_at_counter() -> void:
	state = State.WAITING
	is_at_counter = true
	velocity = Vector3.ZERO

	# Elegir un ítem aleatorio para pedir
	requested_item = possible_items.pick_random()
	label.text = "💬 Quiero: " + requested_item.display_name
	label.visible = true

	# Mostrar barra de paciencia
	patience_bar_pivot.visible = true
	patience_remaining = patience_time

	# Girar hacia el jugador (hacia el mostrador / dirección +Z)
	look_at(global_position + Vector3(0, 0, 1), Vector3.UP)

	SFXManager.play_npc_arrive()


func _update_patience(delta: float) -> void:
	patience_remaining -= delta

	# Actualizar barra visual
	var ratio := clampf(patience_remaining / patience_time, 0.0, 1.0)
	patience_bar_fill.scale.x = ratio

	# Color de la barra: verde -> amarillo -> rojo
	var fill_mat := patience_bar_fill.material as StandardMaterial3D
	if fill_mat:
		if ratio > 0.5:
			fill_mat.albedo_color = Color(0.2, 0.8, 0.2, 1)  # Verde
		elif ratio > 0.25:
			fill_mat.albedo_color = Color(0.9, 0.8, 0.1, 1)  # Amarillo
		else:
			fill_mat.albedo_color = Color(0.9, 0.2, 0.1, 1)  # Rojo

	if patience_remaining <= 0:
		_timeout()


func _timeout() -> void:
	"""El NPC se cansó de esperar."""
	if state != State.WAITING:
		return
		
	label.text = "¡Me voy!"
	patience_bar_pivot.visible = false

	GameManager.npc_timeout()
	SFXManager.play_npc_timeout()

	await get_tree().create_timer(1.0).timeout
	_start_leaving()


func can_receive_item() -> bool:
	return state == State.WAITING and requested_item != null and is_at_counter


func receive_item(item_node: Interactable) -> void:
	"""Llamado por el jugador al entregar un ítem."""
	if not can_receive_item() or item_node == null or item_node.item_data == null:
		return

	# Desactivar recepción inmediata para evitar entregas duplicadas
	is_at_counter = false

	var is_correct: bool = (requested_item != null and item_node.item_data.id == requested_item.id)

	# Notificar al GameManager
	GameManager.handle_order(is_correct)

	# Reacción visual
	if is_correct:
		label.text = "😊 ¡Gracias! ✅"
		SFXManager.play_correct()
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(1.15, 0.9, 1.15), 0.1)
		tween.tween_property(self, "scale", Vector3(0.95, 1.1, 0.95), 0.1)
		tween.tween_property(self, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	else:
		label.text = "😠 ¡Esto no es! ❌"
		SFXManager.play_incorrect()
		var tween := create_tween()
		var orig_x := global_position.x
		tween.tween_property(self, "global_position:x", orig_x + 0.1, 0.05)
		tween.tween_property(self, "global_position:x", orig_x - 0.1, 0.05)
		tween.tween_property(self, "global_position:x", orig_x + 0.05, 0.05)
		tween.tween_property(self, "global_position:x", orig_x, 0.05)

	patience_bar_pivot.visible = false

	# Liberar el objeto entregado
	if item_node.get_parent():
		item_node.get_parent().remove_child(item_node)
	item_node.queue_free()

	await get_tree().create_timer(1.0).timeout
	_start_leaving()


func _start_leaving() -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	is_at_counter = false
	label.visible = false
	patience_bar_pivot.visible = false

	# Desactivar máscara de colisión para que no se trabe con paredes o esquinas al salir
	collision_mask = 0

	# Notificar de inmediato que el mostrador quedó libre para que avance el siguiente cliente
	counter_vacated.emit()

	# Salvaguarda: si por cualquier motivo sigue activo tras 4 segundos, eliminar
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(self):
			_fade_and_free()
	)


func _fade_and_free() -> void:
	if is_leaving_cleanly:
		return
	is_leaving_cleanly = true
	finished_leaving.emit()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func set_queue_position(idx: int, queue_offset: Vector3) -> void:
	"""Establece la posición del NPC en la cola."""
	queue_index = idx
	if idx == 0:
		target_pos = counter_pos
		if state == State.QUEUING:
			state = State.APPROACHING
	else:
		target_pos = counter_pos + queue_offset * idx
		if state != State.LEAVING:
			state = State.QUEUING


func advance_to_counter() -> void:
	"""Mueve este NPC de la cola al mostrador."""
	queue_index = 0
	target_pos = counter_pos
	state = State.APPROACHING
