class_name AnomalyData
extends Resource
## Recurso de datos para configuración de anomalías (AnomalyData).
## Define metadatos, condiciones de aparición (rareza, disparadores fijos, progresión)
## y la referencia a la PackedScene propia de la anomalía.

enum Tier {
	COMMON,      ## Anomalía común / frecuente
	UNCOMMON,    ## Poco común
	RARE,        ## Rara o de alta tensión
	NIGHTMARE    ## Crítica / evento extremo de pesadilla
}

@export_group("Identificación")
## Identificador único de la anomalía (ej. "glitch_sprite", "watcher", "shadow_npc")
@export var id: String = ""
## Nombre legible mostrado en logs, debug y documentación
@export var anomaly_name: String = ""
## Descripción narrativa o técnica de lo que hace la anomalía
@export_multiline var description: String = ""
## Si es false, esta anomalía queda desactivada globalmente
@export var enabled: bool = true

@export_group("Rareza y Probabilidad")
## Nivel de rareza / tier de la anomalía
@export var tier: Tier = Tier.COMMON
## Peso relativo para sorteos probabilísticos aleatorios (a mayor peso, mayor frecuencia)
@export_range(0.0, 100.0, 0.1) var weight: float = 10.0

@export_group("Condiciones de Aparición (Trigger Conditions)")
## Disparo garantizado en un turno o cliente exacto (ej. 3 para ser obligatoriamente el 3.er cliente; -1 = desactivado)
@export var trigger_exact_customer: int = -1

## Disparo por umbral relativo: requiere haber atendido al menos esta cantidad acumulada de NPCs (0 = sin requisito)
@export var trigger_min_served: int = 0

## Progresión temporal: día mínimo en que esta anomalía puede empezar a aparecer (por defecto Día 1)
@export_range(1, 30, 1) var min_day: int = 1

## Progresión temporal: día máximo en que esta anomalía puede aparecer (0 = sin límite de día máximo)
@export_range(0, 30, 1) var max_day: int = 0

## Si es true, la anomalía solo se disparará una única vez por partida
@export var trigger_once: bool = true

## Estado en tiempo de ejecución: indica si ya ocurrió en la partida actual
@export var has_triggered: bool = false

@export_group("Escena Visual Propia")
## Escena empaquetada (PackedScene) que hereda de AnomalyBase.tscn con sus propios sprites y lógica
@export var anomaly_scene: PackedScene = null


## Evalúa si la progresión de días es válida para esta anomalía
func is_day_eligible(current_day: int) -> bool:
	if current_day < min_day:
		return false
	if max_day > 0 and current_day > max_day:
		return false
	return true


## Evalúa si cumple la condición de disparo fijo absoluto (por turno / número de cliente)
func is_exact_match(spawn_count: int, current_day: int) -> bool:
	if not enabled:
		return false
	if trigger_once and has_triggered:
		return false
	if not is_day_eligible(current_day):
		return false
	return trigger_exact_customer > 0 and spawn_count == trigger_exact_customer


## Evalúa si cumple la condición por umbral relativo de clientes atendidos
func is_served_threshold_match(served_count: int, current_day: int) -> bool:
	if not enabled:
		return false
	if trigger_once and has_triggered:
		return false
	if not is_day_eligible(current_day):
		return false
	return trigger_min_served > 0 and served_count >= trigger_min_served


## Evalúa si es elegible para el sorteo probabilístico (peso > 0 y dentro de días)
func is_eligible_for_lottery(current_day: int) -> bool:
	if not enabled or weight <= 0.0:
		return false
	if trigger_once and has_triggered:
		return false
	# Las anomalías con disparo fijo exclusivo (trigger_exact_customer > 0) se reservan para su cliente exacto
	if trigger_exact_customer > 0:
		return false
	return is_day_eligible(current_day)


## Evalúa de forma general si la anomalía puede dispararse
func can_trigger(spawn_count: int, served_count: int, current_day: int) -> bool:
	if not enabled:
		return false
	if trigger_once and has_triggered:
		return false
	if not is_day_eligible(current_day):
		return false
	if trigger_exact_customer > 0:
		return spawn_count == trigger_exact_customer
	if trigger_min_served > 0:
		return served_count >= trigger_min_served
	return true


## Marca la anomalía como disparada
func mark_triggered() -> void:
	has_triggered = true


## Reinicia el estado de ejecución (para nuevas partidas o reinicios)
func reset() -> void:
	has_triggered = false
