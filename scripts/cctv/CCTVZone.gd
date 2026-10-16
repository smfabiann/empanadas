class_name CCTVZone
extends Marker3D
## Zona cubierta por una cámara de seguridad donde los eventos de CCTV (HU-10)
## pueden manifestarse. El evento se coloca en la posición/rotación de este marcador.

## Canal de la cámara que cubre esta zona (debe coincidir con `CCTVCamera.channel_id`)
@export var channel_id: String = "frente"
## Descripción legible para logs y debug (ej. "Vereda izquierda")
@export var zone_name: String = ""


func _ready() -> void:
	add_to_group("cctv_zones")
