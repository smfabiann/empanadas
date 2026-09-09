extends Node
## Spawner de NPCs con soporte para cola de hasta 3 NPCs simultáneos.
## Adapta el intervalo de spawn según la dificultad.

var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
var active_npcs: Array = []
const MAX_NPCS := 3
const QUEUE_OFFSET := Vector3(0, 0, -1.5)  # Cada NPC en cola se aleja 1.5m

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
	# Limpiar NPCs inválidos
	active_npcs = active_npcs.filter(func(npc): return is_instance_valid(npc))

	if active_npcs.size() >= MAX_NPCS:
		return

	if not GameManager.game_active:
		return

	var npc = npc_scene.instantiate()
	npc.spawn_pos = spawn_point.global_position
	npc.counter_pos = counter_point.global_position
	npc.exit_pos = exit_point.global_position

	# Determinar posición en cola
	var queue_idx := active_npcs.size()
	get_parent().add_child(npc)

	if queue_idx == 0:
		# Primer NPC: va directo al mostrador
		npc.target_pos = counter_point.global_position
	else:
		# En cola: posición offset
		npc.target_pos = counter_point.global_position + QUEUE_OFFSET * queue_idx
		npc.state = npc.State.QUEUING

	npc.queue_index = queue_idx
	active_npcs.append(npc)

	# Conectar señal de salida para avanzar la cola
	npc.finished_leaving.connect(_on_npc_left.bind(npc))


func _on_npc_left(npc: Node) -> void:
	"""Cuando un NPC se va, avanzar la cola."""
	active_npcs.erase(npc)

	# Reorganizar la cola
	for i in active_npcs.size():
		var remaining_npc = active_npcs[i]
		if is_instance_valid(remaining_npc):
			remaining_npc.set_queue_position(i, QUEUE_OFFSET)


func _on_difficulty_changed(_level: int) -> void:
	timer.wait_time = GameManager.get_spawn_interval()


func _on_game_over() -> void:
	timer.stop()
