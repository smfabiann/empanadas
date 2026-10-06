class_name AnomaliesManager
extends Node
## Gestor centralizado de anomalías configurables (anomaliesManagement).
## Homologa la estructura y estilo de eventosManagement (NPCEventManager), proveyendo
## registro modular en el Inspector, evaluación de disparadores (fijos, progreso, umbral, rareza)
## y control en tiempo de ejecución para depuración.

signal anomaly_triggered(data: AnomalyData, instance: AnomalyBase)
signal anomaly_resolved(anomaly_id: String, instance: AnomalyBase)
signal anomaly_registered(data: AnomalyData)

@export_group("Configuración General")
## Activa o desactiva el sistema de anomalías por completo
@export var anomalies_enabled: bool = true

## Probabilidad base de que se dispare una anomalía en un sorteo aleatorio (0.0 = nunca, 1.0 = siempre)
@export_range(0.0, 1.0, 0.05) var random_anomaly_chance: float = 0.35

## Si es false, no se disparará una nueva anomalía si ya hay una activa en pantalla
@export var allow_concurrent_anomalies: bool = true

## Límite máximo de anomalías simultáneas activas (0 = sin límite, permitiendo tantas concurrentes como se desee)
@export_range(0, 20, 1) var max_concurrent_anomalies: int = 0

@export_group("Catálogo de Anomalías (Inspector)")
## Lista de recursos de datos de anomalías (AnomalyData) registradas y configuradas
@export var registered_anomalies: Array[AnomalyData] = []

## Escenas empaquetadas directas para registro rápido sin recurso .tres independiente
@export var quick_packed_scenes: Array[PackedScene] = []

@export_group("Depuración (Debug & Runtime Control)")
## Forzar una anomalía específica por ID (ej. "glitch_sprite"). Dejar vacío para modo normal.
@export var debug_force_anomaly: String = ""

## Si está activo, ignora el azar y siempre lanza una anomalía en cada oportunidad (100% chance)
@export var debug_always_trigger: bool = false

## Registro en tiempo de ejecución: ID de la última anomalía disparada
@export var debug_last_triggered: String = ""

## Tecla rápida para forzar el disparo inmediato de la anomalía en tiempo de ejecución (por defecto F4)
@export var debug_trigger_key: Key = KEY_F4

## Cantidad actual de anomalías activas simultáneamente en el juego
@export var debug_active_count: int = 0

## Contador acumulado de anomalías disparadas en la partida
@export var debug_total_triggered_count: int = 0

var anomalies_by_id: Dictionary = {} # String (id) -> AnomalyData
var active_anomalies: Array[AnomalyBase] = []

# Referencias a contadores de la partida (sincronizados con GameManager)
var current_spawn_count: int = 0
var current_served_count: int = 0
var current_day_count: int = 1
var _last_evaluated_spawn: int = -1


func _ready() -> void:
	_setup_catalogue()
	_connect_game_signals()


func _unhandled_input(event: InputEvent) -> void:
	if debug_trigger_key != KEY_NONE and event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == debug_trigger_key:
			var target_id: String = debug_force_anomaly.strip_edges()
			if target_id.is_empty() and not anomalies_by_id.is_empty():
				target_id = anomalies_by_id.keys().front()
			if not target_id.is_empty():
				print("[AnomaliesManager] Forzando anomalía por tecla de depuración F4: ", target_id)
				force_trigger_anomaly(target_id)


func _setup_catalogue() -> void:
	anomalies_by_id.clear()

	# Cargar anomalía por defecto si la lista del inspector está vacía
	if registered_anomalies.is_empty():
		_register_default_anomalies()

	# Indexar recursos cargados desde el Inspector
	for data in registered_anomalies:
		if data != null and not data.id.is_empty():
			register_anomaly(data)

	# Procesar escenas de registro rápido
	for packed in quick_packed_scenes:
		if packed != null:
			_register_from_packed_scene(packed)


## Registra la anomalía de ejemplo funcional por defecto
func _register_default_anomalies() -> void:
	var default_res = load("res://resources/anomalies/glitch_sprite_anomaly.tres") as AnomalyData
	if default_res:
		register_anomaly(default_res)


## Registra o actualiza una anomalía en el catálogo central
func register_anomaly(data: AnomalyData) -> void:
	if data == null or data.id.is_empty():
		push_warning("AnomaliesManager: Intento de registrar AnomalyData nula o sin ID.")
		return

	anomalies_by_id[data.id] = data
	if not registered_anomalies.has(data):
		registered_anomalies.append(data)
	
	anomaly_registered.emit(data)


## Registra una PackedScene directamente creando un AnomalyData en memoria
func _register_from_packed_scene(packed: PackedScene) -> void:
	var dummy = packed.instantiate()
	var auto_id: String = ""
	if dummy is AnomalyBase and not dummy.anomaly_id.is_empty():
		auto_id = dummy.anomaly_id
	else:
		auto_id = packed.resource_path.get_file().get_basename().to_snake_case()
	dummy.queue_free()

	if not anomalies_by_id.has(auto_id):
		var data: AnomalyData = AnomalyData.new()
		data.id = auto_id
		data.anomaly_name = auto_id.capitalize()
		data.anomaly_scene = packed
		data.weight = 10.0
		register_anomaly(data)


func get_anomaly_data(anomaly_id: String) -> AnomalyData:
	return anomalies_by_id.get(anomaly_id, null)


# =========================================================
#  LÓGICA Y EVALUACIÓN DE DISPARADORES (TRIGGER CONDITIONS)
# =========================================================

## Evalúa y selecciona una o más anomalías según prioridad y soporte concurrente:
## 1. Modo Debug: Forzar ID específico.
## 2. Por Turno / Cliente Fijo Absoluto (trigger_exact_customer == spawn_count).
## 3. Por Umbral Relativo de Clientes Atendidos (trigger_min_served <= served_count).
## 4. Sorteo Probabilístico Ponderado (según peso y tier de rareza).
func evaluate_and_trigger(
	spawn_count: int,
	served_count: int,
	current_day: int,
	context: Dictionary = {}
) -> AnomalyBase:
	if not anomalies_enabled:
		return null

	if not allow_concurrent_anomalies and not active_anomalies.is_empty():
		return null

	if max_concurrent_anomalies > 0 and active_anomalies.size() >= max_concurrent_anomalies:
		return null

	# Prevenir doble evaluación redundante en el mismo cliente si llega tanto de NPCSpawner como de GameManager
	if spawn_count > 0 and spawn_count == _last_evaluated_spawn and context.get("event") == "npc_spawned":
		return null
	if spawn_count > 0:
		_last_evaluated_spawn = spawn_count

	current_spawn_count = spawn_count
	current_served_count = served_count
	current_day_count = current_day

	var last_spawned: AnomalyBase = null

	# 1. Modo Debug: Forzar anomalía específica
	var forced_id: String = debug_force_anomaly.strip_edges()
	if not forced_id.is_empty():
		if anomalies_by_id.has(forced_id):
			return spawn_anomaly(anomalies_by_id[forced_id], context)
		else:
			push_warning("AnomaliesManager: Anomalía de debug forzada '%s' no encontrada." % forced_id)

	# 2. Por Turno / Cliente Fijo Absoluto
	for data in anomalies_by_id.values():
		var anom_data: AnomalyData = data as AnomalyData
		if anom_data != null and anom_data.is_exact_match(spawn_count, current_day):
			var spawned: AnomalyBase = spawn_anomaly(anom_data, context)
			if not allow_concurrent_anomalies:
				return spawned
			last_spawned = spawned

	# 3. Por Umbral Relativo de Clientes Atendidos
	for data in anomalies_by_id.values():
		var anom_data: AnomalyData = data as AnomalyData
		if anom_data != null and anom_data.is_served_threshold_match(served_count, current_day):
			var spawned: AnomalyBase = spawn_anomaly(anom_data, context)
			if not allow_concurrent_anomalies:
				return spawned
			last_spawned = spawned

	# 4. Sorteo Probabilístico Ponderado por Rareza
	if last_spawned == null or allow_concurrent_anomalies:
		var chance: float = 1.0 if debug_always_trigger else random_anomaly_chance
		if randf() <= chance:
			var chosen_data: AnomalyData = _pick_weighted_random_anomaly(current_day)
			if chosen_data != null:
				var spawned: AnomalyBase = spawn_anomaly(chosen_data, context)
				last_spawned = spawned

	return last_spawned


## Selección aleatoria basada en pesos y filtros de progresión
func _pick_weighted_random_anomaly(current_day: int) -> AnomalyData:
	var candidates: Array[AnomalyData] = []
	var total_weight: float = 0.0

	for data in anomalies_by_id.values():
		var anom_data: AnomalyData = data as AnomalyData
		if anom_data == null:
			continue

		var eligible: bool = anom_data.is_eligible_for_lottery(current_day)
		# En modo debug_always_trigger, incluir también anomalías con cliente fijo para permitir pruebas inmediatas
		if debug_always_trigger and anom_data.enabled and not (anom_data.trigger_once and anom_data.has_triggered):
			eligible = true

		if eligible:
			candidates.append(anom_data)
			total_weight += anom_data.weight

	# Si todas las únicas ya dispararon pero debug_always_trigger sigue activo, permitir repetir para pruebas
	if candidates.is_empty() and debug_always_trigger and not anomalies_by_id.is_empty():
		for data in anomalies_by_id.values():
			var anom_data: AnomalyData = data as AnomalyData
			if anom_data != null and anom_data.enabled:
				candidates.append(anom_data)
				total_weight += anom_data.weight

	if candidates.is_empty() or total_weight <= 0.0:
		return null

	var roll: float = randf() * total_weight
	var accumulated: float = 0.0

	for data in candidates:
		accumulated += data.weight
		if roll <= accumulated:
			return data

	return candidates.front()


# =========================================================
#  INSTANCIACIÓN Y CICLO DE VIDA
# =========================================================

## Instancia la PackedScene de la anomalía, ejecuta su ciclo de vida y la añade al árbol
func spawn_anomaly(data: AnomalyData, context: Dictionary = {}) -> AnomalyBase:
	if data == null or data.anomaly_scene == null:
		push_warning("AnomaliesManager: No hay PackedScene asignada para '%s'." % (data.id if data else "null"))
		return null

	var instance = data.anomaly_scene.instantiate() as AnomalyBase
	if instance == null:
		push_error("AnomaliesManager: La escena '%s' no hereda de AnomalyBase." % data.anomaly_scene.resource_path)
		return null

	# Marcar como disparada en sus datos
	data.mark_triggered()
	debug_last_triggered = data.id
	debug_total_triggered_count += 1

	# Contexto extendido
	var full_context: Dictionary = context.duplicate()
	full_context["manager"] = self
	full_context["anomaly_data"] = data
	full_context["spawn_count"] = current_spawn_count
	full_context["served_count"] = current_served_count
	full_context["current_day"] = current_day_count

	# Registrar en lista de activas
	active_anomalies.append(instance)
	debug_active_count = active_anomalies.size()

	# Añadir al árbol de nodos
	add_child(instance)

	# Conectar señal de resolución
	instance.anomaly_resolved.connect(func(resolved_instance: AnomalyBase):
		_on_anomaly_resolved(data.id, resolved_instance)
	)

	# Ejecutar ciclo de vida estándar
	instance._init_anomaly(full_context)
	instance.execute_behavior()

	anomaly_triggered.emit(data, instance)
	return instance


## Manejo de la resolución de una anomalía activa
func _on_anomaly_resolved(anomaly_id: String, instance: AnomalyBase) -> void:
	if active_anomalies.has(instance):
		active_anomalies.erase(instance)
	debug_active_count = active_anomalies.size()
	anomaly_resolved.emit(anomaly_id, instance)


## Disparo manual directo para pruebas o scripting externo
func force_trigger_anomaly(anomaly_id: String, context: Dictionary = {}) -> AnomalyBase:
	var data: AnomalyData = get_anomaly_data(anomaly_id)
	if data:
		return spawn_anomaly(data, context)
	push_warning("AnomaliesManager.force_trigger_anomaly: ID '%s' no encontrado." % anomaly_id)
	return null


## Resuelve todas las anomalías que estén activas
func resolve_all_anomalies() -> void:
	var list: Array[AnomalyBase] = active_anomalies.duplicate()
	for anomaly in list:
		if is_instance_valid(anomaly) and anomaly.has_method("resolve"):
			anomaly.resolve()
	active_anomalies.clear()
	debug_active_count = 0


## Reinicia el estado de todas las anomalías (para nuevas partidas o cambio de día)
func reset_anomalies() -> void:
	resolve_all_anomalies()
	for data in anomalies_by_id.values():
		data.reset()


func get_active_anomalies() -> Array[AnomalyBase]:
	return active_anomalies


## Activa o desactiva una anomalía específica por su ID sin quitarla del catálogo
func set_anomaly_enabled(anomaly_id: String, enabled: bool) -> void:
	var data: AnomalyData = get_anomaly_data(anomaly_id)
	if data:
		data.enabled = enabled
		print("[AnomaliesManager] Anomalía '%s' %s." % [anomaly_id, "activada" if enabled else "desactivada"])
	else:
		push_warning("AnomaliesManager.set_anomaly_enabled: ID '%s' no encontrado." % anomaly_id)


## Quita una anomalía del catálogo por completo (para desactivarla permanentemente)
func unregister_anomaly(anomaly_id: String) -> void:
	if anomalies_by_id.has(anomaly_id):
		var data: AnomalyData = anomalies_by_id[anomaly_id]
		anomalies_by_id.erase(anomaly_id)
		registered_anomalies.erase(data)
		print("[AnomaliesManager] Anomalía '%s' desregistrada del catálogo." % anomaly_id)


## Devuelve la lista de IDs de anomalías registradas actualmente
func get_registered_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for key in anomalies_by_id.keys():
		ids.append(key)
	return ids


## Devuelve true si la anomalía con ese ID está registrada y habilitada
func is_anomaly_enabled(anomaly_id: String) -> bool:
	var data: AnomalyData = get_anomaly_data(anomaly_id)
	return data != null and data.enabled


## Devuelve un resumen del estado del sistema para depuración
func get_debug_summary() -> Dictionary:
	return {
		"enabled": anomalies_enabled,
		"registered_count": anomalies_by_id.size(),
		"registered_ids": get_registered_ids(),
		"active_count": active_anomalies.size(),
		"total_triggered": debug_total_triggered_count,
		"last_triggered": debug_last_triggered,
		"allow_concurrent": allow_concurrent_anomalies,
		"max_concurrent": max_concurrent_anomalies
	}


# =========================================================
#  INTEGRACIÓN Y SINCRONIZACIÓN CON GAMEPLAY
# =========================================================

func _connect_game_signals() -> void:
	if not GameManager:
		return

	if not GameManager.npc_spawned.is_connected(_on_game_npc_spawned):
		GameManager.npc_spawned.connect(_on_game_npc_spawned)

	if not GameManager.npc_served.is_connected(_on_game_npc_served):
		GameManager.npc_served.connect(_on_game_npc_served)

	if not GameManager.day_started.is_connected(_on_game_day_started):
		GameManager.day_started.connect(_on_game_day_started)

	if not GameManager.day_ended.is_connected(_on_game_day_ended):
		GameManager.day_ended.connect(_on_game_day_ended)


func _on_game_npc_spawned(total_spawned: int) -> void:
	current_spawn_count = total_spawned
	current_day_count = GameManager.current_day
	current_served_count = GameManager.npcs_served

	# Notificar a anomalías activas
	for anom in active_anomalies:
		if is_instance_valid(anom):
			var current_npc = get_tree().get_first_node_in_group("npcs")
			if current_npc:
				anom.on_customer_arrived(current_npc)

	# Evaluar si una nueva anomalía debe dispararse con este spawn
	evaluate_and_trigger(current_spawn_count, current_served_count, current_day_count, {
		"event": "npc_spawned",
		"spawn_number": total_spawned
	})


func _on_game_npc_served(total_served: int, is_correct: bool) -> void:
	current_served_count = total_served
	current_day_count = GameManager.current_day

	for anom in active_anomalies:
		if is_instance_valid(anom):
			anom.on_customer_served(null, is_correct)

	# Evaluar posibles disparadores por umbral de atendidos
	evaluate_and_trigger(current_spawn_count, current_served_count, current_day_count, {
		"event": "npc_served",
		"is_correct": is_correct
	})


func _on_game_day_started(day: int, _max_clients: int) -> void:
	current_day_count = day


func _on_game_day_ended(_day: int) -> void:
	# Limpiar anomalías activas al terminar la jornada
	resolve_all_anomalies()


## Reacción global al cierre de la persiana
func on_persiana_closed() -> void:
	for anom in active_anomalies:
		if is_instance_valid(anom) and anom.has_method("on_persiana_closed"):
			anom.on_persiana_closed()
