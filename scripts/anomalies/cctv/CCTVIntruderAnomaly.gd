class_name CCTVIntruderAnomaly
extends CCTVEventAnomaly
## "Intruso en el perímetro" (HU-10): una figura merodea de un lado a otro en una
## zona vigilada. Si el jugador la observa un rato por el monitor, se detiene y
## se gira hacia la cámara.

## Distancia del recorrido de ida y vuelta (sobre el eje X local de la zona)
@export var patrol_length: float = 3.0
## Velocidad de caminata en m/s
@export var walk_speed: float = 0.9
## Segundos de observación continua antes de que el intruso "note" la cámara
@export var notice_after: float = 2.0

var _silhouette: Node3D = null
var _origin: Vector3
var _axis: Vector3
var _progress: float = 0.0
var _direction: float = 1.0
var _watched_time: float = 0.0
var _bob: float = 0.0
var has_noticed_camera: bool = false


func _init_anomaly(context: Dictionary = {}) -> void:
	anomaly_id = "cctv_intruder"
	short_description = "Un intruso merodea por el perímetro vigilado."
	tags = ["cctv", "visual", "intruso"]
	super._init_anomaly(context)
	if zone:
		_origin = global_position
		_axis = global_transform.basis.x.normalized()


func _build_visuals() -> void:
	_silhouette = build_silhouette(1.8, Color(0.95, 0.25, 0.2))
	visuals_3d.add_child(_silhouette)


func _on_view_ended() -> void:
	_watched_time = 0.0
	has_noticed_camera = false


func _update_event(delta: float) -> void:
	if _silhouette == null:
		return

	if is_viewed_now:
		_watched_time += delta
		if _watched_time >= notice_after and not has_noticed_camera:
			has_noticed_camera = true

	if has_noticed_camera:
		var cam := get_channel_camera()
		if cam:
			face_point_flat(_silhouette, cam.global_position)
		return

	# Caminar de ida y vuelta por el perímetro
	_progress += _direction * walk_speed * delta
	if absf(_progress) >= patrol_length * 0.5:
		_progress = clampf(_progress, -patrol_length * 0.5, patrol_length * 0.5)
		_direction = -_direction
	global_position = _origin + _axis * _progress

	_bob += delta * walk_speed * 6.0
	_silhouette.position.y = absf(sin(_bob)) * 0.04
	face_point_flat(_silhouette, global_position + _axis * _direction)
