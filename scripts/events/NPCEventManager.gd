class_name NPCEventManager
extends Node
## Administrador central de eventos y anomalías para los NPCs.
## Gestiona el catálogo de anomalías, condiciones de activación y selección de eventos.

@export_group("Configuración de Anomalías")
## Activa o desactiva el sistema de eventos por completo
@export var events_enabled: bool = true
## Probabilidad base de que aparezca un evento aleatorio (0.0 = nunca, 1.0 = siempre)
@export_range(0.0, 1.0, 0.05) var random_event_chance: float = 0.35

@export_group("Depuración (Debug)")
## Forzar un evento específico por ID (ej. "big_head", "fast_npc", "robber"). Dejar vacío para modo normal.
@export var debug_force_event: String = ""
## Si está activo, siempre lanza un evento (100% de probabilidad en sorteos)
@export var debug_always_trigger_event: bool = false

@export_group("Eventos Estáticos")
## Clientes atendidos para que aparezca el Ladrón (ajustar a 1 o 2 para debug rápido)
@export var robber_trigger_served_count: int = 5

var registered_events: Dictionary = {} # id -> NPCEvent

## Reglas fijas legacy por clientes atendidos: { cantidad_atendida: event_id }
var fixed_events_by_served: Dictionary = {}

## Reglas fijas legacy por número de spawn total: { numero_spawn: event_id }
var fixed_events_by_spawn: Dictionary = {}


func _init() -> void:
	_register_default_events()


func _ready() -> void:
	if registered_events.is_empty():
		_register_default_events()
	set_static_event_trigger("robber", robber_trigger_served_count)


## REGISTRO DE EVENTOS DISPONIBLES
func _register_default_events() -> void:
	# Eventos aleatorios (con weight > 0)
	register_event(BigHeadEvent.new())
	register_event(FastNPCEvent.new())
	
	# Eventos estáticos / narrativos (heredan de StaticNPCEvent, weight = 0)
	register_event(RobberEvent.new())


func register_event(event: NPCEvent) -> void:
	if event != null and not event.id.is_empty():
		registered_events[event.id] = event


func get_event(event_id: String) -> NPCEvent:
	return registered_events.get(event_id, null)


## Permite cambiar el umbral de activación de un evento estático (usado por debug e Inspector)
func set_static_event_trigger(event_id: String, served_count: int) -> void:
	var ev := get_event(event_id)
	if ev is StaticNPCEvent:
		ev.trigger_served_count = served_count


## Reinicia el estado de los eventos estáticos (para nuevas partidas)
func reset_static_events() -> void:
	for ev in registered_events.values():
		if ev is StaticNPCEvent:
			ev.reset_event()


## Selecciona el evento correspondiente para el nuevo NPC.
## Prioridad:
## 1. Debug forzado (si se configuró en el inspector de este nodo o del spawner).
## 2. Eventos estáticos / condicionales que cumplan requisitos (StaticNPCEvent).
## 3. Evento fijo por diccionario de atendidos / spawn.
## 4. Evento aleatorio ponderado según rareza.
func pick_event_for_npc(
	spawn_count: int,
	served_count: int,
	override_enabled: bool = true,
	override_chance: float = -1.0,
	override_force_id: String = "",
	override_always_trigger: bool = false
) -> NPCEvent:
	var is_enabled: bool = events_enabled and override_enabled
	if not is_enabled:
		return null

	# Sincronizar umbral configurado en Inspector
	set_static_event_trigger("robber", robber_trigger_served_count)

	# 1. Modo Debug: Forzar ID específico
	var forced := override_force_id.strip_edges()
	if forced.is_empty():
		forced = debug_force_event.strip_edges()

	if not forced.is_empty():
		if registered_events.has(forced):
			return registered_events[forced]
		else:
			push_warning("NPCEventManager: Evento de debug '%s' no encontrado." % forced)

	# 2. Eventos Estáticos y Condicionales
	for event in registered_events.values():
		if event is StaticNPCEvent and event.can_trigger(spawn_count, served_count):
			event.mark_triggered()
			return event

	# 3. Diccionarios de reglas fijas legacy
	if fixed_events_by_served.has(served_count):
		var fixed_id: String = fixed_events_by_served[served_count]
		if registered_events.has(fixed_id):
			return registered_events[fixed_id]

	if fixed_events_by_spawn.has(spawn_count):
		var fixed_id: String = fixed_events_by_spawn[spawn_count]
		if registered_events.has(fixed_id):
			return registered_events[fixed_id]

	# 4. Evento aleatorio basado en probabilidad y pesos
	var chance := override_chance if override_chance >= 0.0 else random_event_chance
	var always_trigger := override_always_trigger or debug_always_trigger_event
	var effective_chance := 1.0 if always_trigger else chance
	if randf() > effective_chance:
		return null # Cliente normal, sin anomalía

	return _pick_weighted_random_event()


func _pick_weighted_random_event() -> NPCEvent:
	var candidates: Array[NPCEvent] = []
	var total_weight: float = 0.0

	for event in registered_events.values():
		if event.weight > 0.0:
			candidates.append(event)
			total_weight += event.weight

	if candidates.is_empty() or total_weight <= 0.0:
		return null

	var roll := randf() * total_weight
	var accumulated: float = 0.0

	for event in candidates:
		accumulated += event.weight
		if roll <= accumulated:
			return event

	return candidates.front()
