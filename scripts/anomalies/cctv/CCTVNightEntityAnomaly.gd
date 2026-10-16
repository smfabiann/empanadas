class_name CCTVNightEntityAnomaly
extends CCTVEventAnomaly
## "Presencia en la vereda": algo se acerca lentamente a la ventana del local.
##
## En la imagen normal de la CAM 01 no se ve nada, solo una leve interferencia: la
## figura vive en la capa de visión nocturna y únicamente aparece con [F]. Bajar la
## persiana la ahuyenta. Si llega a la ventana con la persiana arriba, golpea el
## vidrio y desaparece la plata de la caja.

## Segundos que tarda en llegar desde su zona hasta la ventana
@export var approach_time: float = 40.0
## Plata que se pierde si llega a la ventana con la persiana abierta
@export var penalty: int = 4000
## Interferencia que deja en su canal mientras no se mira con visión nocturna (la pista)
@export_range(0.0, 1.0, 0.01) var clue_interference: float = 0.12
## Segundos mirando el canal sin visión nocturna antes de sugerir [F]
@export var clue_hint_after: float = 2.5

enum Phase { APPROACH, RETREAT, ATTACK, DONE }

var phase: Phase = Phase.APPROACH
var was_seen_with_night_vision: bool = false
var was_repelled: bool = false
var did_attack: bool = false

var _silhouette: Node3D = null
var _start: Vector3
var _target: Vector3
var _progress: float = 0.0
var _phase_time: float = 0.0
var _plain_view_time: float = 0.0
var _sway: float = 0.0

# Las pistas se muestran una vez por sesión para no repetir el tutorial
static var _hinted_clue: bool = false
static var _hinted_seen: bool = false


func _init_anomaly(context: Dictionary = {}) -> void:
	anomaly_id = "cctv_night_entity"
	short_description = "Algo se acerca a la ventana; solo se ve con la visión nocturna. Se ahuyenta bajando la persiana."
	tags = ["cctv", "visual", "vision_nocturna"]
	if allowed_channels.is_empty():
		allowed_channels = PackedStringArray(["frente"])
	# La resolución la maneja la propia presencia (persiana o ataque), no un temporizador
	event_duration = 0.0
	add_to_group("cctv_feed_modifiers")
	super._init_anomaly(context)
	if zone == null or visuals_3d == null:
		return
	# Fuera de la capa de CCTV normal: solo la visión nocturna la renderiza
	CCTVCamera.make_night_vision_only(visuals_3d)

	_start = global_position
	_target = _start
	var persiana := _get_persiana()
	if persiana:
		# Justo afuera de la ventana del mostrador, a la altura de la vereda
		var outward := persiana.global_transform.basis.z.normalized() * -0.8
		_target = Vector3(persiana.global_position.x, _start.y, persiana.global_position.z) + outward
	face_point_flat(_silhouette, _target)


func _build_visuals() -> void:
	_silhouette = build_silhouette(2.15, Color(1.0, 1.0, 1.0))
	# Cuerpo pálido: en la visión nocturna resalta como una figura blanquecina
	var pale := StandardMaterial3D.new()
	pale.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pale.albedo_color = Color(0.78, 0.82, 0.78)
	pale.disable_fog = true
	for part in ["Body", "Head"]:
		var mesh := _silhouette.get_node_or_null(part) as MeshInstance3D
		if mesh:
			mesh.material_override = pale
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(0.02, 0.0, 0.0)
	for eye in ["EyeL", "EyeR"]:
		var mesh := _silhouette.get_node_or_null(eye) as MeshInstance3D
		if mesh:
			mesh.material_override = eye_mat
			mesh.scale = Vector3.ONE * 1.8
	visuals_3d.add_child(_silhouette)


func _get_persiana() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group("persiana") as Node3D


func is_persiana_closed() -> bool:
	var persiana := _get_persiana()
	return persiana != null and persiana.get("is_open") == false


## Interferencia leve en su canal mientras nadie la mira con visión nocturna
func get_feed_interference(target_channel_id: String) -> float:
	if phase != Phase.APPROACH or target_channel_id != channel_id or not is_inside_tree():
		return 0.0
	if CCTVCamera.is_channel_viewed_with_night_vision(get_tree(), channel_id):
		return 0.0
	return clue_interference


func _update_event(delta: float) -> void:
	if _silhouette == null:
		return
	_phase_time += delta
	match phase:
		Phase.APPROACH:
			_update_approach(delta)
		Phase.RETREAT:
			# Se aleja de espaldas a la ventana y se desvanece en la oscuridad
			global_position = global_position.move_toward(_start, 4.0 * delta)
			if _phase_time >= 1.2:
				_finish()
		Phase.ATTACK:
			_silhouette.position.x = sin(_phase_time * 60.0) * 0.05
			if _phase_time >= 1.0:
				_finish()


func _update_approach(delta: float) -> void:
	_progress = minf(_progress + delta / maxf(approach_time, 0.01), 1.0)
	global_position = _start.lerp(_target, _progress)
	_sway += delta
	_silhouette.rotation.z = sin(_sway * 0.7) * 0.04
	var cam := get_channel_camera()
	if cam and is_viewed_now:
		face_point_flat(_silhouette, cam.global_position)

	if is_viewed_now:
		if CCTVCamera.is_channel_viewed_with_night_vision(get_tree(), channel_id):
			if not was_seen_with_night_vision:
				was_seen_with_night_vision = true
				if not _hinted_seen:
					_hinted_seen = true
					_hint("¡Hay algo en la vereda acercándose a la ventana! Baja la persiana.")
		else:
			_plain_view_time += delta
			if _plain_view_time >= clue_hint_after and not _hinted_clue:
				_hinted_clue = true
				_hint("La imagen de la CAM 01 tiene interferencia... prueba la visión nocturna [F].")

	if _progress >= 1.0:
		if is_persiana_closed():
			_retreat()
		else:
			_attack()


## Hook estándar: bajar la persiana la ahuyenta
func on_persiana_closed() -> void:
	if phase == Phase.APPROACH and not is_resolved:
		_retreat()


func _retreat() -> void:
	phase = Phase.RETREAT
	_phase_time = 0.0
	was_repelled = true
	if debug_log:
		print("[CCTV] La presencia nocturna se retira (persiana cerrada).")
	if was_seen_with_night_vision:
		_hint("La persiana la espantó. Lo que había en la vereda se fue.")


func _attack() -> void:
	phase = Phase.ATTACK
	_phase_time = 0.0
	did_attack = true
	if debug_log:
		print("[CCTV] La presencia nocturna llegó a la ventana con la persiana abierta.")
	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_tense_anger"):
		SFXManager.play_tense_anger()
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.lose_money(penalty, "Algo golpeó la ventana")
	_hint("¡Algo golpeó el vidrio de la ventana! Cuando volviste a mirar, faltaba plata en la caja.")


func _finish() -> void:
	phase = Phase.DONE
	resolve()


func _hint(text: String) -> void:
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("request_hint"):
		GameManager.request_hint(text)
