class_name Aware
extends AnomalyBase
## "El Consciente" ("The Aware") — anomalía del cliente con cabeza vigilante y consecuencias letales.
##
## Comportamiento de Vigilancia:
## El cliente que acude al mostrador es consciente del jugador: su cabeza gira de forma antinatural
## para CLAVAR LA MIRADA SIEMPRE EN EL JUGADOR, siguiéndolo a donde sea que camine por la tienda.
## Si el jugador revisa el monitor de seguridad (CCTV), la cabeza del NPC gira para mirar fijamente
## directo al lente de la cámara que estás sintonizando.
##
## Consecuencias de Servicio (Sistema de 2 strikes compartido):
## ¡ESTÁ PROHIBIDO ATENDER A LA ANOMALÍA! Si el jugador le entrega cualquier comida o ítem:
## - 1.er Strike (Advertencia): Un SCREAMER violento lanza la cara del NPC a centímetros de la cámara
##   con un ruido estruendoso y sacudida de pantalla. Las paredes se tiñen de burdeo y advierte que al
##   próximo error morirás. El jugador sobrevive al primer strike.
## - 2.º Strike (Muerte Fatal): Screamer definitivo a quemarropa, derribo al suelo y Game Over inmediato.
##
## Defensa Correcta:
## Al notar que el cliente te sigue con la mirada o mira a la cámara, baja la persiana del mostrador.
## La persiana emite un estruendo metálico (*¡CLANG!*) y la anomalía es desterrada, marchándose el cliente.

## Se emite una vez al empezar a mirar a través del monitor (útil para pruebas y ganchos).
signal monitor_viewed
## Se emite al dejar de mirar a través del monitor.
signal monitor_averted

@export_group("Audio de Suspenso")
## Archivo de audio para el suspenso/silencio tenso cuando te observa por la cámara CCTV.
## Puedes arrastrar aquí tu archivo .ogg o .wav desde el Inspector de Godot.
@export var suspense_audio: AudioStream = null
## Volumen del audio de suspenso en decibelios (dB)
@export_range(-40.0, 6.0, 0.5) var suspense_volume_db: float = -4.0
## Si es true y no se ha asignado suspense_audio, reproduce un suspenso sutil de respaldo (false = silencio total tenso)
@export var fallback_suspense_sfx: bool = false

@export_group("Audio de Screamer / Consecuencias")
## Audio específico para el screamer al atender la anomalía (si es null, reproduce sonidos fuertes de impacto).
@export var screamer_sound: AudioStream = null
## Volumen en dB para el screamer fuerte
@export_range(-10.0, 12.0, 0.5) var screamer_volume_db: float = 6.0

@export_group("Configuración Visual")
## Velocidad de giro con la que la cabeza del NPC sigue al jugador
@export var head_tracking_speed: float = 12.0
## Si es true, muestra el ojo poligonal 2D en pantalla. Por defecto false para tener la vista despejada.
@export var show_2d_eye_overlay: bool = false
## Si está activo (para pruebas), manifiesta el estado de monitor de inmediato
@export var debug_always_visible: bool = false

@onready var eye_root: Node2D = $Visuals2D/AwareEye if has_node("Visuals2D/AwareEye") else null
@onready var eye_shape: Polygon2D = $Visuals2D/AwareEye/EyeShape if has_node("Visuals2D/AwareEye/EyeShape") else null
@onready var pupil: Polygon2D = $Visuals2D/AwareEye/Pupil if has_node("Visuals2D/AwareEye/Pupil") else null
@onready var signal_label: Label = $Visuals2D/AwareEye/SignalLabel if has_node("Visuals2D/AwareEye/SignalLabel") else null

var target_npc: CharacterBody3D = null
var aware_event: NPCEvent = null
var is_attacking: bool = false
var was_repelled: bool = false

var _audio_player: AudioStreamPlayer = null
var _is_viewing_now: bool = false
var _blink_timer: float = 0.0
var _next_blink: float = randf_range(1.5, 4.0)
var _phase: float = 0.0


func _ready() -> void:
	super._ready()
	_ensure_references()
	_setup_audio()

	if signal_label:
		signal_label.visible = false
		signal_label.text = ""

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
	if signal_label:
		signal_label.visible = false
		signal_label.text = ""


func _setup_audio() -> void:
	if _audio_player == null:
		if has_node("AudioStreamPlayer"):
			_audio_player = $AudioStreamPlayer as AudioStreamPlayer
		else:
			_audio_player = AudioStreamPlayer.new()
			_audio_player.name = "SuspenseAudioPlayer"
			add_child(_audio_player)
	_audio_player.volume_db = suspense_volume_db


func _init_anomaly(context: Dictionary = {}) -> void:
	super._init_anomaly(context)
	anomaly_id = "aware"
	short_description = "Un cliente consciente te sigue la mirada por la tienda y clava sus ojos en la cámara CCTV. ¡No lo atiendas!"
	tags = ["cctv", "visual", "monitor", "suspenso", "letal", "head_tracking"]
	auto_resolve_duration = 0.0

	_ensure_references()
	_setup_audio()
	_center_on_screen()

	var passed_npc = context.get("npc", null)
	if passed_npc is CharacterBody3D:
		_bind_to_npc(passed_npc)
	elif is_inside_tree():
		var first_npc = get_tree().get_first_node_in_group("npcs") as CharacterBody3D
		if first_npc:
			_bind_to_npc(first_npc)


func _bind_to_npc(npc: CharacterBody3D) -> void:
	target_npc = npc
	if not is_instance_valid(target_npc):
		return

	# Asignar evento interceptor para controlar la entrega, persiana y timeout
	var event_script = load("res://scripts/events/AwareNPCEvent.gd")
	if event_script:
		aware_event = event_script.new(self)
		target_npc.assign_event(aware_event)


func on_customer_arrived(npc: CharacterBody3D) -> void:
	if target_npc == null or not is_instance_valid(target_npc):
		_bind_to_npc(npc)


func execute_behavior() -> void:
	super.execute_behavior()
	_ensure_references()
	if signal_label:
		signal_label.visible = false
		signal_label.text = ""

	if eye_root:
		eye_root.visible = false
		eye_root.modulate.a = 0.0

	print("[Aware]  Anomalía Aware activada: el cliente es consciente de tu presencia.")


func _process(delta: float) -> void:
	if not is_active or is_resolved:
		return

	_ensure_references()

	var viewing := _monitor_is_viewed() or debug_always_visible

	# Transición: entrar o salir del monitor de seguridad
	if viewing and not _is_viewing_now:
		_is_viewing_now = true
		monitor_viewed.emit()
		print("[Aware]  El Consciente detecta que lo observas a través del monitor.")
		_start_suspense_audio()
	elif not viewing and _is_viewing_now:
		_is_viewing_now = false
		monitor_averted.emit()
		print("[Aware]  El Consciente deja de verte (dejaste de mirar el monitor).")
		_stop_suspense_audio()

	# Seguimiento de la cabeza del NPC: mira siempre al jugador (o a la cámara CCTV si está en el monitor)
	if not is_attacking and not was_repelled:
		_track_player_or_camera_with_head(delta)

	if viewing:
		if eye_root:
			eye_root.visible = true
			eye_root.modulate.a = 1.0 if show_2d_eye_overlay else 0.0
			_center_on_screen()
			_update_while_viewed(delta)
	else:
		if eye_root:
			eye_root.visible = false
			eye_root.modulate.a = 0.0


## La cabeza del NPC gira para mirar SIEMPRE al jugador (o a la cámara CCTV activa si mira el monitor)
func _track_player_or_camera_with_head(delta: float) -> void:
	if target_npc == null or not is_instance_valid(target_npc):
		# Intentar buscar el NPC si aún no se había vinculado
		if is_inside_tree():
			var first = get_tree().get_first_node_in_group("npcs") as CharacterBody3D
			if first:
				_bind_to_npc(first)
		return

	var head = target_npc.get_node_or_null("Head") as Node3D
	if head == null:
		return

	var target_pos := _get_current_look_target()
	if target_pos == Vector3.ZERO:
		return

	var head_pos: Vector3 = head.global_position
	var to: Vector3 = target_pos - head_pos
	if to.length_squared() < 0.01:
		return

	# Orientar suavemente la cabeza hacia el objetivo (eje -Z mirando al objetivo), preservando la escala del nodo
	var head_scale: Vector3 = head.scale
	var current_basis: Basis = head.global_transform.basis.orthonormalized()
	var target_transform: Transform3D = head.global_transform.looking_at(target_pos, Vector3.UP)
	var target_basis: Basis = target_transform.basis.orthonormalized()
	var next_basis: Basis = current_basis.slerp(target_basis, clampf(delta * head_tracking_speed, 0.0, 1.0))
	head.global_transform.basis = next_basis.scaled(head_scale)


## Determina hacia dónde debe clavar la mirada el NPC
func _get_current_look_target() -> Vector3:
	# Si el jugador está mirando el monitor de CCTV, el NPC mira a la cámara CCTV activa
	if _monitor_is_viewed():
		var cam := _get_active_cctv_camera()
		if cam != null and is_instance_valid(cam):
			return cam.global_position

	# Si el jugador está en la tienda, el NPC mira directamente a los ojos / cámara del jugador
	if is_inside_tree():
		var player = get_tree().get_first_node_in_group("player")
		if player != null and is_instance_valid(player):
			var player_cam = player.find_child("Camera3D", true, false) as Camera3D
			if player_cam != null and is_instance_valid(player_cam):
				return player_cam.global_position
			return player.global_position + Vector3(0, 1.6, 0)

	return Vector3.ZERO


func _get_active_cctv_camera() -> Camera3D:
	if not is_inside_tree():
		return null
	for mon in get_tree().get_nodes_in_group("security_monitors"):
		if mon != null and mon.get("is_viewing") == true:
			var sec_cam = mon.get("security_camera") as Camera3D
			if sec_cam != null and is_instance_valid(sec_cam):
				return sec_cam

	for cam in get_tree().get_nodes_in_group("cctv_cameras"):
		if cam is Camera3D and cam.current:
			return cam
	var all_cams = get_tree().get_nodes_in_group("cctv_cameras")
	if not all_cams.is_empty() and all_cams[0] is Camera3D:
		return all_cams[0] as Camera3D
	return null


func _start_suspense_audio() -> void:
	if _audio_player == null:
		_setup_audio()
	if _audio_player:
		if suspense_audio != null:
			_audio_player.stream = suspense_audio
			_audio_player.volume_db = suspense_volume_db
			_audio_player.play()
		elif fallback_suspense_sfx and typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_alien_suspense"):
			SFXManager.play_alien_suspense(3.0)


func _stop_suspense_audio() -> void:
	if _audio_player and is_instance_valid(_audio_player) and _audio_player.playing:
		_audio_player.stop()


func _update_while_viewed(delta: float) -> void:
	if signal_label:
		signal_label.visible = false
		signal_label.text = ""

	_phase += delta
	if pupil:
		var pulse := 0.7 + 0.3 * absf(sin(_phase * 2.5))
		pupil.scale = Vector2(pulse, pulse)

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


func _monitor_is_viewed() -> bool:
	if not is_inside_tree():
		return false

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


# =============================================================================
#  SISTEMA DE CONSECUENCIAS POR SERVIR A AWARE (2 STRIKES COMPARTIDOS)
# =============================================================================

## Disparado cuando el jugador comete el error de servir comida a Aware
func trigger_serving_consequence(npc: CharacterBody3D) -> void:
	if is_resolved or is_attacking:
		return

	var strikes := 1
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("record_anomaly_strike"):
		strikes = GameManager.record_anomaly_strike()

	if strikes == 1:
		_execute_screamer_warning(npc)
	else:
		_execute_screamer_fatal(npc)


## Strike 1: Screamer de la cara del NPC a centímetros de la cámara con ruido fuerte + advertencia burdeo
func _execute_screamer_warning(npc: CharacterBody3D) -> void:
	is_attacking = true

	# 1. Screamer visual: la cara del NPC salta disparada a escasos centímetros de la pantalla
	var screamer_face = _spawn_screamer_face(npc, false)

	# 2. Ruido fuerte e impactante
	_play_loud_screamer_sound()

	# 3. Sacudida violenta de la cámara del jugador
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("shake_camera"):
		player.shake_camera(2.2, 0.07)

	# 4. Teñir las paredes interiores de la casa a rojo burdeo suave
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.apply_wall_corruption(get_tree(), true, 1.8)

	# 5. Diálogo siniestro del NPC
	if npc and is_instance_valid(npc) and npc.label:
		npc.label.visible = true
		npc.label.text = " *¡GRITO ENSORDECEDOR!* ... ¡TE VEO! ... ¡Al próximo error no sobrevivirás! "
		npc.label.modulate = Color(1.0, 0.15, 0.15, 1.0)

	# 6. Notificación / Pista en pantalla
	_hint("¡ATENDISTE A LA ANOMALÍA CONSCIENTE! La casa se tiñó de burdeo. ¡Al 2.º error morirás!")

	# 7. CONSECUENCIAS PRIMERO: Esperar a que se completen las consecuencias antes de dar paso al fin de la jornada
	await get_tree().create_timer(2.0).timeout

	# Retirar el screamer con fade out suave
	if screamer_face and is_instance_valid(screamer_face):
		var tw := screamer_face.create_tween()
		tw.tween_property(screamer_face, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN)
		tw.tween_callback(screamer_face.queue_free)

	if not is_instance_valid(self):
		return

	# 8. Si el jugador sobrevive, el cliente concluye su visita y se retira
	if npc and is_instance_valid(npc):
		if npc.has_method("finish_visit"):
			npc.finish_visit(" ... El Consciente te perdona la vida... por ahora ... ", "wrong", Color(0.78, 0.18, 0.25, 1.0))
		elif npc.has_method("_start_leaving"):
			npc._start_leaving()

	is_attacking = false
	resolve()


## Strike 2: Screamer mortal definitivo, derribo al suelo y Game Over inmediato
func _execute_screamer_fatal(npc: CharacterBody3D) -> void:
	is_attacking = true

	# 1. Screamer letal a quemarropa cubriendo la pantalla
	var screamer_face = _spawn_screamer_face(npc, true)

	# 2. Ruido fuerte y demoledor
	_play_loud_screamer_sound()
	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_gunshot"):
		SFXManager.play_gunshot()

	# 3. Derribar al jugador al suelo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("fall_down"):
		player.fall_down()

	# 4. Flash rojo de daño en HUD
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.get("damage_flash"):
		ui.damage_flash.visible = true

	# 5. Diálogo final en el cliente
	if npc and is_instance_valid(npc) and npc.label:
		npc.label.visible = true
		npc.label.text = " ¡SEGUNDO ERROR! ¡EL CONSCIENTE CONSUME TU CORDURA! "
		npc.label.modulate = Color(1.0, 0.05, 0.05, 1.0)

	# 6. Disparar Game Over letal
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.trigger_game_over(
			"¡Segundo error fatal!\n" +
			"Atendiste a la anomalía consciente y consumió tu cordura.\n" +
			"Regla de supervivencia: ¡Las anomalías no se atienden! Si notas que te sigue la mirada, ¡bájale la persiana!"
		)

	get_tree().create_timer(0.35).timeout.connect(func():
		if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_game_over"):
			SFXManager.play_game_over()
	)


## Reproduce un ruido fuerte estridente para el screamer
func _play_loud_screamer_sound() -> void:
	if screamer_sound != null:
		if _audio_player == null:
			_setup_audio()
		if _audio_player:
			_audio_player.stream = screamer_sound
			_audio_player.volume_db = screamer_volume_db
			_audio_player.play()
			return

	if typeof(SFXManager) != TYPE_NIL and SFXManager != null:
		if SFXManager.has_method("play_sonic_boom"):
			SFXManager.play_sonic_boom()
		if SFXManager.has_method("play_gunshot"):
			SFXManager.play_gunshot()
		if SFXManager.has_method("play_tense_anger"):
			SFXManager.play_tense_anger()


## Construye y proyecta la cara del NPC directamente en primer plano de la cámara del jugador
func _spawn_screamer_face(npc: CharacterBody3D, is_fatal: bool = false) -> Node3D:
	if not is_inside_tree():
		return null
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		return null
	var player_cam = player.find_child("Camera3D", true, false) as Camera3D
	if player_cam == null:
		return null

	var screamer_root := Node3D.new()
	screamer_root.name = "AwareScreamerFace"

	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "ScreamerHead"
	var sph := SphereMesh.new()
	sph.radius = 0.22
	sph.height = 0.44
	head_mesh.mesh = sph

	var head_mat := StandardMaterial3D.new()
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if npc:
		var orig_head = npc.get_node_or_null("Head")
		if orig_head and orig_head.get("material") is StandardMaterial3D:
			var orig_mat = orig_head.material as StandardMaterial3D
			head_mat.albedo_color = orig_mat.albedo_color
			head_mat.albedo_texture = orig_mat.albedo_texture
		else:
			head_mat.albedo_color = Color(0.18, 0.2, 0.22, 1.0)
	else:
		head_mat.albedo_color = Color(0.18, 0.2, 0.22, 1.0)
	head_mat.disable_fog = true
	head_mesh.material_override = head_mat
	screamer_root.add_child(head_mesh)

	player_cam.add_child(screamer_root)

	screamer_root.position = Vector3(0.0, -0.1, -1.3)
	screamer_root.scale = Vector3(0.5, 0.5, 0.5)

	var target_dist: float = -0.32 if is_fatal else -0.38
	var target_scale: Vector3 = Vector3(2.5, 2.5, 2.5) if is_fatal else Vector3(1.9, 1.9, 1.9)

	var tween := screamer_root.create_tween().set_parallel(true)
	tween.tween_property(screamer_root, "position:z", target_dist, 0.10)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(screamer_root, "scale", target_scale, 0.10)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)

	var shake_tween := screamer_root.create_tween()
	for i in 8:
		var off := Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0.0)
		shake_tween.tween_property(screamer_root, "position", Vector3(0.0, -0.05, target_dist) + off, 0.035)

	return screamer_root


## Defensa con persiana: destierra a Aware exitosamente
func handle_persiana_closed(npc: CharacterBody3D) -> bool:
	if is_resolved or is_attacking:
		return false
	was_repelled = true

	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_correct"):
		SFXManager.play_correct()

	_hint("¡Excelente! Cerraste la persiana a tiempo y desterraste a la anomalía consciente.")

	if npc and is_instance_valid(npc):
		var head = npc.get_node_or_null("Head") as Node3D
		if head:
			head.rotation = Vector3.ZERO

		if npc.label:
			npc.label.visible = true
			npc.label.text = " *¡CLANG!* ... La presencia consciente se desvanece ... "
			npc.label.modulate = Color(0.4, 1.0, 0.5, 1.0)

		if npc.has_method("finish_visit"):
			npc.finish_visit(" *¡CLANG!* ... La anomalía fue desterrada ... ", "correct", Color(0.4, 1.0, 0.5, 1.0))
		elif npc.has_method("_start_leaving"):
			npc._start_leaving()

	get_tree().create_timer(0.5).timeout.connect(resolve)
	return true


## Timeout de paciencia
func handle_timeout(npc: CharacterBody3D) -> bool:
	if is_resolved or is_attacking or was_repelled:
		return false

	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_tense_anger"):
		SFXManager.play_tense_anger()

	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.lose_money(3000, "La presencia consciente cobró peaje por la espera")
		_hint("¡Tardaste demasiado! La presencia consciente te robó plata. ¡Debías bajar la persiana!")

	if npc and is_instance_valid(npc) and npc.has_method("finish_visit"):
		npc.finish_visit(" ... ", "wrong")

	get_tree().create_timer(0.5).timeout.connect(resolve)
	return true


func _hint(text: String) -> void:
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("request_hint"):
		GameManager.request_hint(text)


func resolve() -> void:
	if is_resolved:
		return
	_stop_suspense_audio()

	super.resolve()


func on_persiana_closed() -> void:
	pass
