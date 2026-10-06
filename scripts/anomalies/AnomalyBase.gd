class_name AnomalyBase
extends Node3D
## Clase base y plantilla estándar para todas las anomalías configurables.
## Ofrece un ciclo de vida desacoplado (_init_anomaly, execute_behavior, resolve)
## y contenedores dedicados para nodos visuales 2D (Sprite2D, AnimatedSprite2D, Shaders en CanvasLayer)
## y nodos visuales 3D (Sprite3D, partículas, mallas 3D).

signal anomaly_started(anomaly: AnomalyBase)
signal anomaly_resolved(anomaly: AnomalyBase)
signal anomaly_interacted(anomaly: AnomalyBase, data: Dictionary)

@export_group("Configuración Base")
## Identificador único de la anomalía (debe coincidir con su AnomalyData)
@export var anomaly_id: String = ""

## Si es true, llama a execute_behavior() automáticamente al instanciar y estar listo
@export var auto_execute_on_ready: bool = true

## Tiempo en segundos antes de resolver la anomalía automáticamente (0.0 = manual / indefinido)
@export var auto_resolve_duration: float = 0.0

@export_group("Clasificación Modular")
## Categoría o tags para filtrar anomalías (ej. ["visual", "ambiental", "sonoro"])
@export var tags: PackedStringArray = []
## Descripción breve visible en logs de debug
@export var short_description: String = ""

# Referencias a nodos estándar de la plantilla
@onready var visuals_2d: CanvasLayer = $Visuals2D if has_node("Visuals2D") else null
@onready var visuals_3d: Node3D = $Visuals3D if has_node("Visuals3D") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer if has_node("AudioStreamPlayer") else null
@onready var duration_timer: Timer = $DurationTimer if has_node("DurationTimer") else null

var is_active: bool = false
var is_resolved: bool = false
var context_data: Dictionary = {}


func _ready() -> void:
	if duration_timer:
		duration_timer.one_shot = true
		duration_timer.timeout.connect(_on_duration_timeout)

	if auto_execute_on_ready and not is_active:
		execute_behavior()


## 1. INICIALIZACIÓN DEL CICLO DE VIDA
## Se llama inmediatamente después de instanciar la escena y antes de execute_behavior().
## Permite inyectar contexto (NPC actual, jugador, contadores de partida, gestor, etc.)
func _init_anomaly(context: Dictionary = {}) -> void:
	context_data = context
	is_active = true
	is_resolved = false

	# Configurar temporizador si se especificó auto_resolve_duration
	if auto_resolve_duration > 0.0 and duration_timer:
		duration_timer.wait_time = auto_resolve_duration
		duration_timer.start()

	anomaly_started.emit(self)


## 2. EJECUCIÓN DEL COMPORTAMIENTO
## Sobrescribir en scripts hijos para definir la lógica única, disparar animaciones,
## alterar shaders o activar efectos visuales / auditivos.
func execute_behavior() -> void:
	is_active = true
	if animation_player and animation_player.has_animation("execute"):
		animation_player.play("execute")


## 3. RESOLUCIÓN / FINALIZACIÓN DE LA ANOMALÍA
## Se llama cuando la anomalía concluye su ciclo (por tiempo, interacción del jugador o fin de evento).
## Limpia visuales, detiene timers y libera la instancia de memoria.
func resolve() -> void:
	if is_resolved:
		return
	is_resolved = true
	is_active = false

	if duration_timer and not duration_timer.is_stopped():
		duration_timer.stop()

	anomaly_resolved.emit(self)

	# Si hay animación de salida ("resolve"), la reproduce antes de liberar
	if animation_player and animation_player.has_animation("resolve"):
		animation_player.play("resolve")
		await animation_player.animation_finished
	
	if is_instance_valid(self):
		queue_free()


func _on_duration_timeout() -> void:
	resolve()


# =========================================================
#  GANCHOS OPCIONALES DE INTEGRACIÓN CON EL JUEGO (HOOKS)
# =========================================================

## Se dispara si un NPC llega al mostrador mientras esta anomalía está activa
func on_customer_arrived(_npc: CharacterBody3D) -> void:
	pass


## Se dispara cuando el jugador entrega un pedido a un NPC
func on_customer_served(_npc: CharacterBody3D, _is_correct: bool) -> void:
	pass


## Se dispara si el jugador cierra la persiana del mostrador
func on_persiana_closed() -> void:
	pass


## Permite interacción directa del jugador (ej. mediante RayCast3D o tecla)
func interact(_interactor: Node = null) -> void:
	anomaly_interacted.emit(self, {"interactor": _interactor})
