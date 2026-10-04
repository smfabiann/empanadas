extends Node
## Spawner de NPCs — solo 1 cliente a la vez frente a la ventana.
## Gestiona el ciclo de vida y la asignación de eventos/anomalías.

@export_group("Eventos y Anomalías")
## Referencia al nodo gestor de eventos en la escena. Si está vacío, se busca automáticamente.
@export var event_manager: NPCEventManager

## Activa o desactiva el sistema de eventos por completo
@export var events_enabled: bool = true
## Probabilidad base de que aparezca un evento aleatorio (0.0 = nunca, 1.0 = siempre)
@export_range(0.0, 1.0, 0.05) var random_event_chance: float = 0.35
## Forzar un evento específico por ID (ej. "big_head", "fast_npc", "robber") para debug. Dejar vacío para modo normal.
@export var debug_force_event: String = ""
## Si está activo, ignora el azar y siempre lanza un evento (100% de probabilidad)
@export var debug_always_trigger_event: bool = false

@export_subgroup("Eventos Estáticos")
## Cantidad de clientes atendidos para activar el Ladrón (cambiar en Inspector para debug)
@export var robber_trigger_served_count: int = 5

@export_group("Puntos de Navegación (Handles)")
## Marker en la escena donde aparecen los clientes
@export var spawn_point: Marker3D
## Marker frente al mostrador donde se detienen a ordenar
@export var window_point: Marker3D
## Marker hacia donde caminan para salir del mapa
@export var exit_point: Marker3D

var npc_scene: PackedScene = preload("res://scenes/NPC.tscn")
var current_npc: Node = null

@onready var timer: Timer = $Timer


func _ready() -> void:
	if event_manager == null:
		event_manager = get_parent().get_node_or_null("NPCEventManager") as NPCEventManager
	if event_manager == null:
		event_manager = NPCEventManager.new()
		get_parent().add_child.call_deferred(event_manager)

	if robber_trigger_served_count > 0:
		event_manager.set_static_event_trigger("robber", robber_trigger_served_count)

	if spawn_point == null:
		spawn_point = get_parent().get_node_or_null("SpawnPoint")
	if window_point == null:
		window_point = get_parent().get_node_or_null("WindowPoint")
	if exit_point == null:
		exit_point = get_parent().get_node_or_null("ExitPoint")

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

	var spawned_number: int = GameManager.register_npc_spawned()

	# Sincronizar umbral configurado en Inspector
	if robber_trigger_served_count > 0:
		event_manager.set_static_event_trigger("robber", robber_trigger_served_count)

	# 1. Seleccionar evento (estático, fijo, aleatorio o forzado por debug)
	var event: NPCEvent = event_manager.pick_event_for_npc(
		spawned_number,
		GameManager.npcs_served,
		events_enabled,
		random_event_chance,
		debug_force_event,
		debug_always_trigger_event
	)

	# 2. Si el evento provee un modelo/escena de NPC propia (ej. RobberNPC), usarla
	var scene_to_spawn: PackedScene = npc_scene
	if event is StaticNPCEvent and event.custom_npc_scene != null:
		scene_to_spawn = event.custom_npc_scene

	var npc = scene_to_spawn.instantiate()
	npc.spawn_pos = spawn_point.global_position
	npc.target_pos = window_point.global_position
	npc.exit_pos = exit_point.global_position

	if event:
		npc.assign_event(event)

	current_npc = npc

	# Re-conectamos las señales relevantes
	npc.tree_exited.connect(_on_npc_removed)
	
	# Cambiamos estado inicial
	npc.state = npc.State.APPROACHING

	get_parent().add_child(npc)


func _on_npc_removed() -> void:
	current_npc = null
	if GameManager.game_active:
		timer.wait_time = GameManager.get_spawn_interval()
		timer.start()
