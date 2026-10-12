class_name Aware
extends AnomalyBase
## "El Consciente" ("The Aware") — anomalía reactiva al monitor de seguridad.
##
## Mecánica: solo se "activa" visualmente cuando el jugador mira A TRAVÉS del
## monitor de seguridad (`SecurityMonitor`). Si el jugador deja de mirar, la
## anomalía desaparece al instante. No hace NADA cuando no estamos viendo a través
## del monitor. Es decir, la anomalía "ve que te ven" y solo se manifiesta en ese momento.
##
## Desacoplada del monitor: comprueba si algún monitor de seguridad está en estado
## de visión (`is_viewing`), si el jugador tiene activo `is_viewing_monitor`, o si
## el monitor activo reporta visión activa.

## Se emite una vez al empezar a mirar a través del monitor (útil para pruebas y ganchos).
signal monitor_viewed
## Se emite al dejar de mirar a través del monitor.
signal monitor_averted

@onready var eye_root: Node2D = $Visuals2D/AwareEye if has_node("Visuals2D/AwareEye") else null
@onready var eye_shape: Polygon2D = $Visuals2D/AwareEye/EyeShape if has_node("Visuals2D/AwareEye/EyeShape") else null
@onready var pupil: Polygon2D = $Visuals2D/AwareEye/Pupil if has_node("Visuals2D/AwareEye/Pupil") else null
@onready var signal_label: Label = $Visuals2D/AwareEye/SignalLabel if has_node("Visuals2D/AwareEye/SignalLabel") else null

## Si está activo (para pruebas), muestra el ojo de inmediato sin necesidad de interactuar con el monitor
@export var debug_always_visible: bool = false

var _is_viewing_now: bool = false
var _blink_timer: float = 0.0
var _next_blink: float = randf_range(1.5, 4.0)
var _phase: float = 0.0


func _ready() -> void:
	super._ready()
	_ensure_references()
	if eye_root:
		eye_root.visible = false
		eye_root.modulate.a = 0.0
		_center_on_screen()


func _ensure_references() -> void:
	if eye_root == null and has_node("Visuals2D/AwareEye"):
		eye_root = $Visuals2D/AwareEye
	if eye_shape == null and has_node("Visuals2D/AwareEye/EyeShape"):
		eye_shape = $Visuals2D/AwareEye/EyeShape
	if pupil == null and has_node("Visuals2D/AwareEye/Pupil"):
		pupil = $Visuals2D/AwareEye/Pupil
	if signal_label == null and has_node("Visuals2D/AwareEye/SignalLabel"):
		signal_label = $Visuals2D/AwareEye/SignalLabel as Label


func _init_anomaly(context: Dictionary = {}) -> void:
	super._init_anomaly(context)
	anomaly_id = "aware"
	short_description = "Sientes que te ven cuando miras a través del monitor de seguridad."
	tags = ["visual", "monitor", "hud"]
	# Permanece activa mientras se interactúe con el monitor o hasta resolución externa.
	auto_resolve_duration = 0.0

	_ensure_references()
	_center_on_screen()


func execute_behavior() -> void:
	super.execute_behavior()
	_ensure_references()
	# Comienza oculta: únicamente se manifiesta al mirar a través del monitor (salvo debug_always_visible).
	if eye_root:
		eye_root.visible = false
		eye_root.modulate.a = 0.0
	print("[Aware] 👁️ Anomalía Aware activada. Está al acecho: interactúa con el monitor de seguridad [E] en la pared izquierda para verla.")


func _process(delta: float) -> void:
	if not is_active:
		return

	_ensure_references()
	if eye_root == null:
		return

	var viewing := _monitor_is_viewed() or debug_always_visible

	# Transición: entrar o salir del monitor de seguridad
	if viewing and not _is_viewing_now:
		_is_viewing_now = true
		monitor_viewed.emit()
		print("[Aware] 👁️ El Consciente detecta que lo observas a través del monitor.")
		if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_tense_anger"):
			SFXManager.play_tense_anger()
	elif not viewing and _is_viewing_now:
		_is_viewing_now = false
		monitor_averted.emit()
		print("[Aware] 👁️ El Consciente deja de verte (dejaste de mirar el monitor).")

	if viewing:
		eye_root.visible = true
		_center_on_screen()
		_update_while_viewed(delta)
	else:
		# Al dejar de mirar el monitor, desaparece por completo e instantáneamente
		eye_root.visible = false
		eye_root.modulate.a = 0.0


func _update_while_viewed(delta: float) -> void:
	# Fade-in suave al aparecer
	eye_root.modulate.a = move_toward(eye_root.modulate.a, 1.0, delta * 10.0)

	# Pulso rítmico de la pupila
	_phase += delta
	if pupil:
		var pulse := 0.7 + 0.3 * absf(sin(_phase * 2.5))
		pupil.scale = Vector2(pulse, pulse)

	# Parpadeo natural
	_blink_timer += delta
	if _blink_timer >= _next_blink:
		blink()
		_blink_timer = 0.0
		_next_blink = randf_range(1.5, 4.0)


func blink() -> void:
	if eye_root:
		var tw := create_tween()
		tw.tween_property(eye_root, "scale:y", 0.05, 0.05).set_trans(Tween.TRANS_SINE)
		tw.tween_property(eye_root, "scale:y", 1.0, 0.06).set_trans(Tween.TRANS_SINE)


func _center_on_screen() -> void:
	if eye_root and is_inside_tree() and get_viewport():
		eye_root.position = get_viewport().get_visible_rect().get_center()


## Comprueba si algún monitor de seguridad está siendo observado en este frame
func _monitor_is_viewed() -> bool:
	for mon in get_tree().get_nodes_in_group("security_monitors"):
		if mon != null and mon.get("is_viewing") == true:
			return true

	var sec_script = load("res://scripts/SecurityMonitor.gd")
	if sec_script and sec_script.active_monitor != null and sec_script.active_monitor.get("is_viewing") == true:
		return true

	var player = get_tree().get_first_node_in_group("player")
	if player != null and player.get("is_viewing_monitor") == true:
		return true

	return false


func on_persiana_closed() -> void:
	# Hook estándar: permite resolver si el jugador baja la persiana
	pass
