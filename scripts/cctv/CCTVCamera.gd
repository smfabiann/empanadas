class_name CCTVCamera
extends Camera3D
## Cámara de seguridad (canal de CCTV) que el `SecurityMonitor` puede sintonizar.
##
## Cada cámara es un canal: el monitor recoge todas las del grupo "cctv_cameras"
## y las ordena por `channel_index`. Las cámaras de CCTV ven además la capa de
## render exclusiva `CCTV_RENDER_LAYER`, que la cámara del jugador NO ve: ahí viven
## los eventos de cámara (HU-10), visibles solo a través del monitor.

## Capa de render (1-20) reservada para elementos visibles únicamente por CCTV
const CCTV_RENDER_LAYER := 11
## Capa de render reservada para elementos que solo aparecen con la visión nocturna [F]
## del monitor. Ninguna cámara la ve por defecto: el monitor la enciende en sus canales
## mientras la visión nocturna está activa.
const NIGHT_VISION_RENDER_LAYER := 12

## Identificador del canal usado por zonas y eventos (ej. "frente", "patio")
@export var channel_id: String = "frente"
## Nombre mostrado en el HUD del monitor (ej. "FRENTE")
@export var channel_name: String = "FRENTE"
## Orden del canal en el monitor (CAM 01, CAM 02, ...)
@export var channel_index: int = 1


func _ready() -> void:
	add_to_group("cctv_cameras")
	set_cull_mask_value(CCTV_RENDER_LAYER, true)
	set_cull_mask_value(NIGHT_VISION_RENDER_LAYER, false)


## Mueve un VisualInstance3D (y todos sus descendientes) a la capa exclusiva de CCTV
## y desactiva sus sombras para que no se filtren a la vista del jugador.
static func make_cctv_only(root: Node) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = 1 << (CCTV_RENDER_LAYER - 1)
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		make_cctv_only(child)


## Mueve un VisualInstance3D (y sus descendientes) a la capa de visión nocturna: solo
## se ve por el monitor con [F] activo. Sin sombras, para no delatarse en la vista normal.
static func make_night_vision_only(root: Node) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = 1 << (NIGHT_VISION_RENDER_LAYER - 1)
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in root.get_children():
		make_night_vision_only(child)


## Oculta las capas de CCTV y de visión nocturna en una cámara que no es de seguridad
## (ej. la del jugador)
static func hide_cctv_layer(camera: Camera3D) -> void:
	if camera:
		camera.set_cull_mask_value(CCTV_RENDER_LAYER, false)
		camera.set_cull_mask_value(NIGHT_VISION_RENDER_LAYER, false)


## Devuelve true si algún monitor está mostrando a pantalla completa el canal indicado
static func is_channel_viewed(tree: SceneTree, target_channel_id: String) -> bool:
	if tree == null:
		return false
	for mon in tree.get_nodes_in_group("security_monitors"):
		if mon != null and mon.get("is_viewing") == true and mon.has_method("get_current_channel_id"):
			if mon.get_current_channel_id() == target_channel_id:
				return true
	return false


## Devuelve true si algún monitor muestra el canal indicado con la visión nocturna activa
static func is_channel_viewed_with_night_vision(tree: SceneTree, target_channel_id: String) -> bool:
	if tree == null:
		return false
	for mon in tree.get_nodes_in_group("security_monitors"):
		if mon != null and mon.get("is_viewing") == true and mon.get("is_anomaly_vision") == true \
				and mon.has_method("get_current_channel_id") and mon.get_current_channel_id() == target_channel_id:
			return true
	return false
