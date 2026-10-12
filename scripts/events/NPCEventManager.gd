class_name NPCEventManager
extends Node
## Administrador central de eventos para los NPCs.
## Gestiona el catálogo de eventos (modificadores de clientes y eventos narrativos estáticos).

@export_group("Configuración de Eventos de NPC")
## Activa o desactiva el sistema de eventos por completo
@export var events_enabled: bool = true
## Probabilidad base de que aparezca un evento aleatorio (0.0 = nunca, 1.0 = siempre)
@export_range(0.0, 1.0, 0.05) var random_event_chance: float = 0.35

@export_group("Depuración (Debug)")
## Forzar un evento específico por ID (ej. "big_head", "fast_npc", "robber", "ufo"). Dejar vacío para modo normal.
@export var debug_force_event: String = ""
## Si está activo, siempre lanza un evento (100% de probabilidad en sorteos)
@export var debug_always_trigger_event: bool = false
## Dispara el avance de día inmediatamente en tiempo de ejecución
@export var debug_advance_day_now: bool = false:
	set(val):
		if val:
			var gm = get_node_or_null("/root/GameManager")
			if gm and gm.has_method("debug_advance_to_next_day"):
				gm.debug_advance_to_next_day()

@export_group("Eventos Estáticos")
## Clientes atendidos para que aparezca el Ladrón (ajustar a 1 o 2 para debug rápido)
@export var robber_trigger_served_count: int = 5
## Día máximo en el cual puede aparecer el Ladrón (por defecto: 1, solo en Día 1)
@export var robber_max_day: int = 1
## Día en que se activa el evento OVNI/UFO (por defecto: día 2)
@export var ufo_trigger_day: int = 2
## Clientes atendidos en dicho día antes de que aparezca el UFO (por defecto: 1)
@export var ufo_trigger_served_in_day: int = 1
## Forzar aparición del UFO en el próximo cliente (para debug rápido)
@export var debug_force_ufo: bool = false

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
	set_static_event_day_range("robber", 1, robber_max_day)
	set_static_event_day_trigger("ufo", ufo_trigger_day, ufo_trigger_served_in_day)


## REGISTRO DE EVENTOS DISPONIBLES
func _register_default_events() -> void:
	# Eventos aleatorios (con weight > 0)
	register_event(BigHeadEvent.new())
	register_event(FastNPCEvent.new())
	
	# Eventos estáticos / narrativos (heredan de StaticNPCEvent, weight = 0)
	register_event(RobberEvent.new())
	register_event(UfoEvent.new())


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


## Permite cambiar el día y atendidos en el día de un evento estático (usado por debug e Inspector)
func set_static_event_day_trigger(event_id: String, day: int, served_in_day: int) -> void:
	var ev := get_event(event_id)
	if ev is StaticNPCEvent:
		ev.trigger_day = day
		ev.trigger_day_served_count = served_in_day


## Permite cambiar el rango de días de un evento estático (usado por debug e Inspector)
func set_static_event_day_range(event_id: String, min_day: int, max_day: int) -> void:
	var ev := get_event(event_id)
	if ev is StaticNPCEvent:
		ev.trigger_day = min_day
		ev.trigger_max_day = max_day


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

	# Sincronizar umbrales configurados en Inspector
	set_static_event_trigger("robber", robber_trigger_served_count)
	set_static_event_day_range("robber", 1, robber_max_day)
	set_static_event_day_trigger("ufo", ufo_trigger_day, ufo_trigger_served_in_day)

	# 1. Modo Debug: Forzar ID específico o toggle rápido
	var forced := override_force_id.strip_edges()
	if forced.is_empty():
		forced = debug_force_event.strip_edges()
	if forced.is_empty() and debug_force_ufo:
		forced = "ufo"

	if not forced.is_empty():
		if registered_events.has(forced):
			return registered_events[forced]
		else:
			push_warning("NPCEventManager: Evento de debug '%s' no encontrado." % forced)

	# 2. Eventos Estáticos y Condicionales
	var gm = get_node_or_null("/root/GameManager")
	var cur_day: int = gm.current_day if gm else 1
	var cur_day_served: int = gm.clients_attended_today if gm else 0
	for event in registered_events.values():
		if event is StaticNPCEvent and event.can_trigger(spawn_count, served_count, cur_day, cur_day_served):
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
		return null # Cliente normal, sin evento

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
