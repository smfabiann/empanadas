extends Node3D
## Controla la cámara aérea cinematográfica de fondo para el menú principal.
## Proporciona un paneo suave y continuo (slow drift) que da vida a la escena.

@onready var camera: Camera3D = %MenuCamera

@export var look_target: Vector3 = Vector3(-1.2, 1.6, -4.5)
@export var drift_amplitude: Vector3 = Vector3(1.8, 0.4, 0.8)
@export var drift_speed: float = 0.12

var _base_position: Vector3
var _time: float = 0.0


func _ready() -> void:
	if camera:
		_base_position = camera.global_position
		camera.look_at(look_target)


func _process(delta: float) -> void:
	if not camera:
		return

	_time += delta

	# Movimiento sutil y continuo estilo dron / slow pan cinematográfico
	var offset_x := sin(_time * drift_speed) * drift_amplitude.x
	var offset_y := sin(_time * drift_speed * 1.5) * drift_amplitude.y
	var offset_z := cos(_time * drift_speed * 0.8) * drift_amplitude.z

	camera.global_position = _base_position + Vector3(offset_x, offset_y, offset_z)
	camera.look_at(look_target)
