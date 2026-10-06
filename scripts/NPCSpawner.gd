extends Node
## Spawner de NPCs — solo 1 cliente a la vez frente a la ventana.
## Cuando se va, espera un intervalo y genera el siguiente.

var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
var current_npc: Node = null

@onready var timer: Timer = $Timer
@onready var spawn_point: Marker3D
@onready var window_point: Marker3D
@onready var exit_point: Marker3D


func _ready() -> void:
	spawn_point = get_parent().get_node("SpawnPoint")
	# Renombramos CounterPoint a WindowPoint en Main.tscn
	window_point = get_parent().get_node("WindowPoint")
	exit_point = get_parent().get_node("ExitPoint")

	timer.wait_time = GameManager.get_spawn_interval()
	timer.one_shot = true
	timer.timeout.connect(_spawn_npc)

	# Spawnear el primer NPC tras un breve delay
	timer.start(2.0)


func _spawn_npc() -> void:
	if not GameManager.game_active:
		return
	if current_npc != null and is_instance_valid(current_npc):
		return

	var npc = npc_scene.instantiate()
	npc.spawn_pos = spawn_point.global_position
	# La posicion de destino ahora sera la ventana
	npc.target_pos = window_point.global_position
	npc.exit_pos = exit_point.global_position

	current_npc = npc

	# Re-conectamos las seales relevantes
	npc.tree_exited.connect(_on_npc_removed)
	
	# Cambiamos estado inicial
	npc.state = npc.State.APPROACHING

	get_parent().add_child(npc)


func _on_npc_removed() -> void:
	current_npc = null
	if GameManager.game_active:
		timer.wait_time = GameManager.get_spawn_interval()
		timer.start()
