class_name CCTVEventAnomaly
extends AnomalyBase
## Base para eventos visibles en CCTV (HU-10).
##
## El evento se coloca en una `CCTVZone` (marcador en `Main.tscn`, grupo "cctv_zones")
## cubierta por una cámara de seguridad, y todos sus visuales 3D se mueven a la capa
## de render exclusiva de CCTV: la cámara del jugador no los ve, solo el monitor de
## seguridad cuando sintoniza ese canal. Al resolverse, la instancia se libera por
## completo, de modo que el canal vuelve a su estado normal sin restos visuales.
##
## Para crear un evento nuevo: heredar de esta clase, construir los visuales dentro
## de `visuals_3d` en `_build_visuals()` y animarlos en `_update_event()`.

## Se emite la primera vez que el jugador ve el evento a través del monitor
signal seen_on_cctv(anomaly: CCTVEventAnomaly)

@export_group("Evento de CCTV")
## Canales donde puede aparecer (vacío = cualquier zona de cualquier canal)
@export var allowed_channels: PackedStringArray = []
## Segundos que dura el evento antes de desaparecer solo (0 = hasta resolución externa)
@export var event_duration: float = 35.0
## Si es true, imprime en consola dónde apareció (útil para depurar)
@export var debug_log: bool = true

## Zona asignada y canal que la cubre
var zone: Node3D = null
var channel_id: String = ""
## Estado de observación desde el monitor
var was_seen: bool = false
var times_viewed: int = 0
var is_viewed_now: bool = false
var time_alive: float = 0.0


func _init_anomaly(context: Dictionary = {}) -> void:
	auto_resolve_duration = event_duration
	super._init_anomaly(context)
	if tags.is_empty():
		tags = ["cctv", "visual"]

	zone = context.get("cctv_zone", null)
	if zone == null:
		zone = _pick_zone()
	if zone == null:
		push_warning("CCTVEventAnomaly '%s': no hay CCTVZone disponible; el evento se descarta." % anomaly_id)
		call_deferred("resolve")
		return

	channel_id = str(zone.get("channel_id")) if zone.get("channel_id") != null else ""
	global_transform = zone.global_transform

	if visuals_3d == null:
		visuals_3d = Node3D.new()
		visuals_3d.name = "Visuals3D"
		add_child(visuals_3d)
	_build_visuals()
	CCTVCamera.make_cctv_only(visuals_3d)

	if debug_log:
		print("[CCTV] Evento '%s' en canal '%s' (zona: %s)." % [anomaly_id, channel_id, zone.name])


## Elige una zona al azar entre las permitidas
func _pick_zone() -> Node3D:
	if not is_inside_tree():
		return null
	var candidates: Array[Node3D] = []
	for z in get_tree().get_nodes_in_group("cctv_zones"):
		if not (z is Node3D):
			continue
		var zone_channel = z.get("channel_id")
		if allowed_channels.is_empty() or allowed_channels.has(str(zone_channel)):
			candidates.append(z)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]


func _process(delta: float) -> void:
	if not is_active or is_resolved or zone == null:
		return
	time_alive += delta

	var viewed := CCTVCamera.is_channel_viewed(get_tree(), channel_id)
	if viewed and not is_viewed_now:
		is_viewed_now = true
		times_viewed += 1
		if not was_seen:
			was_seen = true
			seen_on_cctv.emit(self)
		_on_view_started()
	elif not viewed and is_viewed_now:
		is_viewed_now = false
		_on_view_ended()

	_update_event(delta)


## Cámara de seguridad que cubre el canal de este evento (o null)
func get_channel_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	for cam in get_tree().get_nodes_in_group("cctv_cameras"):
		if cam is Camera3D and cam.get("channel_id") == channel_id:
			return cam
	return null


func resolve() -> void:
	if is_resolved:
		return
	is_viewed_now = false
	if visuals_3d:
		visuals_3d.visible = false
	super.resolve()


# =========================================================
#  GANCHOS PARA SUBCLASES
# =========================================================

## Construye los nodos visuales dentro de `visuals_3d` (se pasan a la capa de CCTV después)
func _build_visuals() -> void:
	pass


## Se llama cada frame mientras el evento está activo
func _update_event(_delta: float) -> void:
	pass


## El jugador acaba de sintonizar el canal de este evento
func _on_view_started() -> void:
	pass


## El jugador dejó de mirar este canal
func _on_view_ended() -> void:
	pass


# =========================================================
#  UTILIDADES DE CONSTRUCCIÓN
# =========================================================

## Crea una silueta humanoide oscura con ojos brillantes (sin depender de assets)
static func build_silhouette(height: float = 1.85, eye_color: Color = Color(1.0, 0.92, 0.85)) -> Node3D:
	var root := Node3D.new()
	root.name = "Silhouette"

	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.albedo_color = Color(0.015, 0.012, 0.018)

	var scale_factor := height / 1.85

	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.24 * scale_factor
	capsule.height = 1.35 * scale_factor
	body.mesh = capsule
	body.material_override = body_mat
	body.position = Vector3(0, 0.72 * scale_factor, 0)
	body.scale = Vector3(1.0, 1.0, 0.65)
	root.add_child(body)

	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.15 * scale_factor
	sphere.height = 0.34 * scale_factor
	head.mesh = sphere
	head.material_override = body_mat
	head.position = Vector3(0, 1.6 * scale_factor, 0)
	root.add_child(head)

	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = eye_color
	eye_mat.disable_fog = true

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "EyeL" if side < 0.0 else "EyeR"
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.022 * scale_factor
		eye_mesh.height = 0.044 * scale_factor
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		# Los ojos miran hacia -Z (frente del marcador / de la silueta)
		eye.position = Vector3(0.055 * side * scale_factor, 1.63 * scale_factor, -0.13 * scale_factor)
		root.add_child(eye)

	return root


## Orienta un nodo en el plano XZ para que mire (-Z) hacia un punto
static func face_point_flat(node: Node3D, target: Vector3) -> void:
	var to := target - node.global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	node.global_rotation.y = atan2(-to.x, -to.z)
