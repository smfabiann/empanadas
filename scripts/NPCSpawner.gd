extends Node
## Spawner de NPCs con soporte para cola de hasta 3 clientes en el local.
## Adapta el intervalo de spawn según la dificultad y avanza la cola sin demoras.

var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
var waiting_queue: Array = []
const MAX_QUEUE := 3
const QUEUE_OFFSET := Vector3(0, 0, -1.3)

@onready var timer: Timer = $Timer
@onready var spawn_point: Marker3D
@onready var counter_point: Marker3D
@onready var exit_point: Marker3D


func _ready() -> void:
	spawn_point = get_parent().get_node("SpawnPoint")
	counter_point = get_parent().get_node("CounterPoint")
	exit_point = get_parent().get_node("ExitPoint")

	timer.wait_time = GameManager.get_spawn_interval()
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	timer.start()

	GameManager.game_over_reached.connect(_on_game_over)
	GameManager.difficulty_changed.connect(_on_difficulty_changed)


func _on_timer_timeout() -> void:
	_cleanup_queue()

	if waiting_queue.size() >= MAX_QUEUE:
		return

	if not GameManager.game_active:
		return

	var npc = npc_scene.instantiate()
	npc.spawn_pos = spawn_point.global_position
	npc.counter_pos = counter_point.global_position
	npc.exit_pos = exit_point.global_position

	var queue_idx := waiting_queue.size()
	if queue_idx == 0:
		npc.target_pos = counter_point.global_position
		npc.state = npc.State.APPROACHING
	else:
		npc.target_pos = counter_point.global_position + QUEUE_OFFSET * queue_idx
		npc.state = npc.State.QUEUING

	npc.queue_index = queue_idx
	waiting_queue.append(npc)

	# Conexión a señales de salida y liberación de mostrador
	npc.counter_vacated.connect(_on_counter_vacated.bind(npc))
	npc.tree_exited.connect(_on_npc_removed.bind(npc))

	get_parent().add_child(npc)


func _on_counter_vacated(npc: Node) -> void:
	"""Cuando un cliente termina su turno en el mostrador, avanzar la cola de inmediato."""
	if npc in waiting_queue:
		waiting_queue.erase(npc)
	_advance_queue()


func _on_npc_removed(npc: Node) -> void:
	if npc in waiting_queue:
		waiting_queue.erase(npc)
		_advance_queue()


func _advance_queue() -> void:
	_cleanup_queue()
	for i in waiting_queue.size():
		var remaining_npc = waiting_queue[i]
		if is_instance_valid(remaining_npc):
			if i == 0:
				remaining_npc.advance_to_counter()
			else:
				remaining_npc.set_queue_position(i, QUEUE_OFFSET)


func _cleanup_queue() -> void:
	waiting_queue = waiting_queue.filter(
		func(npc): return is_instance_valid(npc) and npc.state != npc.State.LEAVING
	)


func _on_difficulty_changed(_level: int) -> void:
	timer.wait_time = GameManager.get_spawn_interval()


func _on_game_over() -> void:
	timer.stop()
