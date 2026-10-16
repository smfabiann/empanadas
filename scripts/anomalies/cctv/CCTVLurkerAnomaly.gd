class_name CCTVLurkerAnomaly
extends CCTVEventAnomaly
## "Silueta acechando" (HU-10): una figura inmóvil aparece en una zona vigilada.
## Solo se ve por el monitor de seguridad y, cada vez que el jugador vuelve a
## sintonizar el canal, está un poco más cerca de la cámara.

## Metros que avanza hacia la cámara cada vez que se vuelve a mirar el canal
@export var approach_step: float = 1.2
## Cantidad máxima de avances antes de quedarse quieta
@export var max_approaches: int = 3

var _silhouette: Node3D = null
var _approaches: int = 0
var _sway: float = 0.0


func _init_anomaly(context: Dictionary = {}) -> void:
	anomaly_id = "cctv_lurker"
	short_description = "Una silueta acecha en una zona vigilada y se acerca cada vez que la miras."
	tags = ["cctv", "visual", "silueta"]
	super._init_anomaly(context)


func _build_visuals() -> void:
	_silhouette = build_silhouette(1.9, Color(1.0, 0.95, 0.9))
	visuals_3d.add_child(_silhouette)


func _on_view_started() -> void:
	var cam := get_channel_camera()
	if cam:
		face_point_flat(_silhouette, cam.global_position)
	# La primera vez solo se deja ver; las siguientes, se ha acercado
	if times_viewed > 1 and _approaches < max_approaches and cam:
		var to := cam.global_position - global_position
		to.y = 0.0
		if to.length() > approach_step + 1.5:
			global_position += to.normalized() * approach_step
			_approaches += 1
			if cam:
				face_point_flat(_silhouette, cam.global_position)


func _update_event(delta: float) -> void:
	if _silhouette == null:
		return
	# Leve balanceo, casi imperceptible
	_sway += delta
	_silhouette.rotation.z = sin(_sway * 0.9) * 0.03
