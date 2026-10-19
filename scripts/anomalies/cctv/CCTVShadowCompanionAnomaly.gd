class_name CCTVShadowCompanionAnomaly
extends CCTVEventAnomaly

const CCTVCameraHelper = preload("res://scripts/cctv/CCTVCamera.gd")
## "El Acompañante Oculto" (CCTV / Anomalía Letal):
## Un cliente común y corriente llega al mostrador a pedir su comida.
## Sin embargo, si el jugador sintoniza la cámara exterior (CAM 01) y activa la
## VISIÓN NOCTURNA [F], descubrirá una copia idéntica y oscura de ese mismo cliente
## parada exactamente detrás de él, mirándolo fijamente a la cámara.
##
## REGLA DE SUPERVIVENCIA:
## - ¡LAS ANOMALÍAS NO SE ATIENDEN!
## - Si el jugador le entrega cualquier ítem o completo, la entidad ataca inmediatamente,
##   abatir al jugador y provocando un Game Over mortal (idéntico al fallo del ladrón).
## - La defensa correcta es cerrar la PERSIANA del mostrador: esto destierra la anomalía,
##   protege el negocio y hace que el cliente se retire en paz.
## - Si se le agota la paciencia sin cerrar la persiana, la anomalía roba plata de la caja.

@export var clue_hint_after: float = 3.0
@export var behind_distance: float = 0.65
@export var side_offset: float = 0.18

var target_npc: CharacterBody3D = null
var shadow_event: ShadowCompanionNPCEvent = null

var is_attacking: bool = false
var was_repelled: bool = false
var was_seen_with_night_vision: bool = false

var _shadow_clone: Node3D = null
var _plain_view_time: float = 0.0
var _sway: float = 0.0
var _hinted_clue: bool = false
var _hinted_seen: bool = false


func _init_anomaly(context: Dictionary = {}) -> void:
	anomaly_id = "cctv_shadow_companion"
	short_description = "Un cliente normal oculta a su doppelgänger oscuro detrás. Visible solo con visión nocturna [F]. ¡Prohibido atender! Cerrar persiana."
	tags = ["cctv", "visual", "vision_nocturna", "letal", "doble"]
	if allowed_channels.is_empty():
		allowed_channels = PackedStringArray(["frente"])
	event_duration = 0.0 # Se mantiene viva hasta que el cliente sea resuelto (persiana, timeout o muerte)

	# Buscar el NPC asociado desde el contexto de spawn
	var passed_npc = context.get("npc", null)
	if passed_npc is CharacterBody3D:
		target_npc = passed_npc
	elif is_inside_tree():
		target_npc = get_tree().get_first_node_in_group("npcs") as CharacterBody3D

	super._init_anomaly(context)

	if visuals_3d:
		CCTVCameraHelper.make_night_vision_only(visuals_3d)

	if target_npc:
		_bind_to_npc(target_npc)


func _bind_to_npc(npc: CharacterBody3D) -> void:
	target_npc = npc
	if not is_instance_valid(target_npc):
		return

	# Asignar el evento interceptor al cliente para controlar la entrega, persiana y timeout
	shadow_event = ShadowCompanionNPCEvent.new(self)
	target_npc.assign_event(shadow_event)

	# Construir la réplica visual idéntica
	_rebuild_clone_visuals()


## Hook llamado si el NPC llega al mostrador tras instanciarse la anomalía
func on_customer_arrived(npc: CharacterBody3D) -> void:
	if target_npc == null or not is_instance_valid(target_npc):
		_bind_to_npc(npc)


func _build_visuals() -> void:
	if visuals_3d == null:
		visuals_3d = Node3D.new()
		visuals_3d.name = "Visuals3D"
		add_child(visuals_3d)

	if target_npc != null and is_instance_valid(target_npc):
		_rebuild_clone_visuals()


## Construye un duplicado exacto del cliente (cuerpo, cabeza, textura/color)
func _rebuild_clone_visuals() -> void:
	if visuals_3d == null:
		return

	if _shadow_clone and is_instance_valid(_shadow_clone):
		_shadow_clone.queue_free()

	_shadow_clone = Node3D.new()
	_shadow_clone.name = "ShadowCompanionClone"

	var body_color: Color = Color(0.2, 0.22, 0.25, 1.0)
	var head_color: Color = Color(0.2, 0.22, 0.25, 1.0)
	var head_texture: Texture2D = null

	# Clonar colores y materiales del NPC original
	if target_npc:
		var orig_body = target_npc.get_node_or_null("BodyMesh")
		if orig_body and orig_body.get("material") is StandardMaterial3D:
			body_color = (orig_body.material as StandardMaterial3D).albedo_color

		var orig_head = target_npc.get_node_or_null("Head")
		if orig_head and orig_head.get("material") is StandardMaterial3D:
			var mat = orig_head.material as StandardMaterial3D
			head_color = mat.albedo_color
			head_texture = mat.albedo_texture

	# 1. Cuerpo idéntico (cilindro)
	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Tono ligeramente más pálido/tétrico pero manteniendo la identidad de la persona
	body_mat.albedo_color = Color(body_color.r * 0.85, body_color.g * 0.85, body_color.b * 0.85, 1.0)
	body_mat.disable_fog = true

	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "Body"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.2
	cyl.height = 1.4
	body_mesh.mesh = cyl
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.7, 0)
	_shadow_clone.add_child(body_mesh)

	# 2. Cabeza idéntica (esfera con la misma textura o color)
	var head_mat := StandardMaterial3D.new()
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	head_mat.albedo_color = head_color
	if head_texture:
		head_mat.albedo_texture = head_texture
	head_mat.disable_fog = true

	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "Head"
	var sph := SphereMesh.new()
	sph.radius = 0.24
	sph.height = 0.48
	head_mesh.mesh = sph
	head_mesh.material_override = head_mat
	head_mesh.position = Vector3(0, 1.6, 0)
	_shadow_clone.add_child(head_mesh)

	# 3. Ojos sobrenaturales blancos y penetrantes (mirando a la cámara)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 1.0, 1.0)
	eye_mat.disable_fog = true

	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.name = "EyeL" if side < 0.0 else "EyeR"
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.024
		eye_mesh.height = 0.048
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(0.065 * side, 1.63, -0.22)
		_shadow_clone.add_child(eye)

	visuals_3d.add_child(_shadow_clone)
	CCTVCameraHelper.make_night_vision_only(_shadow_clone)


func _update_event(delta: float) -> void:
	if is_resolved or not is_active:
		return

	# Si el cliente ya no existe o se fue, resolver la anomalía limpiamente
	if target_npc == null or not is_instance_valid(target_npc):
		resolve()
		return

	# Si está atacando, la animación de muerte ya tiene el control
	if is_attacking:
		return

	# Mantener la sombra parada directamente detrás del cliente
	if _shadow_clone and is_instance_valid(_shadow_clone):
		# Vector hacia la ventana: en Main.tscn la ventana está en +Z frente al cliente
		var behind_offset := Vector3(side_offset, 0.0, -behind_distance)
		_shadow_clone.global_position = target_npc.global_position + behind_offset

		_sway += delta
		_shadow_clone.position.y = sin(_sway * 2.2) * 0.025

		# Clavar la mirada fijamente hacia la cámara de seguridad CAM 01
		var cam := get_channel_camera()
		if cam:
			face_point_flat(_shadow_clone, cam.global_position)

	# Lógica de pistas si el jugador está mirando la cámara CAM 01
	if is_viewed_now:
		if CCTVCameraHelper.is_channel_viewed_with_night_vision(get_tree(), channel_id):
			if not was_seen_with_night_vision:
				was_seen_with_night_vision = true
				if not _hinted_seen:
					_hinted_seen = true
					_hint("¡CUIDADO! Hay una silueta idéntica acechando tras el cliente. ¡NO LO ATIENDAS! Bájale la persiana.")
		else:
			_plain_view_time += delta
			if _plain_view_time >= clue_hint_after and not _hinted_clue:
				_hinted_clue = true
				_hint("La imagen de la CAM 01 tiene una silueta borrosa... prueba la visión nocturna [F].")


## -----------------------------------------------------------------------------
## REACCIÓN AL ATENDER UNA ANOMALÍA (Sistema de 2 strikes)
## -----------------------------------------------------------------------------
func trigger_death_sequence(npc: CharacterBody3D) -> void:
	if is_resolved or is_attacking:
		return

	var strikes := 1
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("record_anomaly_strike"):
		strikes = GameManager.record_anomaly_strike()

	if strikes == 1:
		_execute_first_warning_strike(npc)
	else:
		_execute_fatal_strike(npc)


## Primer error: vibración, paredes burdeo sutiles, la anomalía se retira advirtiéndote
func _execute_first_warning_strike(npc: CharacterBody3D) -> void:
	is_attacking = true

	# 1. Vibración de cámara en el jugador
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("shake_camera"):
		player.shake_camera(2.0, 0.045)

	# 2. Sonidos siniestros de tensión y advertencia
	if typeof(SFXManager) != TYPE_NIL and SFXManager != null:
		if SFXManager.has_method("play_tense_anger"):
			SFXManager.play_tense_anger()
		if SFXManager.has_method("play_alien_suspense"):
			SFXManager.play_alien_suspense(2.0)

	# 3. Teñir las paredes interiores de la casa a rojo burdeo suave
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.apply_wall_corruption(get_tree(), true, 1.8)

	# 4. Diálogo de advertencia espeluznante en el cliente
	if npc and is_instance_valid(npc) and npc.label:
		npc.label.visible = true
		npc.label.text = " *Risa distorsionada* ... La casa se corrompe ... ¡Al próximo error no sobrevivirás! "
		npc.label.modulate = Color(0.78, 0.18, 0.25, 1.0)

	# 5. Notificación / Pista en pantalla
	_hint("¡ATENDISTE A UNA ANOMALÍA! La casa se tiñó de burdeo. ¡Al 2.º error morirás!")

	# 6. La sombra y el cliente se disuelven en la oscuridad
	if _shadow_clone and is_instance_valid(_shadow_clone):
		var tw := create_tween()
		tw.tween_property(_shadow_clone, "scale", Vector3.ZERO, 0.9)\
			.set_trans(Tween.TRANS_SINE)

	if npc and is_instance_valid(npc):
		if npc.has_method("finish_visit"):
			npc.finish_visit(" ... La presencia te perdona la vida... por ahora ... ", "wrong", Color(0.78, 0.18, 0.25, 1.0))
		elif npc.has_method("_start_leaving"):
			npc._start_leaving()

	get_tree().create_timer(1.2).timeout.connect(func():
		is_attacking = false
		resolve()
	)


## Segundo error: Jumpscare letal, derribo y Game Over definitivo
func _execute_fatal_strike(npc: CharacterBody3D) -> void:
	is_attacking = true

	# 1. Diálogo final de perdición
	if npc and is_instance_valid(npc) and npc.label:
		npc.label.visible = true
		npc.label.text = " ¡SEGUNDO ERROR! ¡NO TIENES ESCAPATORIA! "
		npc.label.modulate = Color(1.0, 0.05, 0.05, 1.0)

	# 2. Jumpscare en la cara del jugador
	if _shadow_clone and is_instance_valid(_shadow_clone):
		_make_clone_world_visible(_shadow_clone)
		var tween := create_tween().set_parallel(true)
		var jump_target := npc.global_position + Vector3(0.0, 0.25, 0.75)
		tween.tween_property(_shadow_clone, "global_position", jump_target, 0.16)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		tween.tween_property(_shadow_clone, "scale", Vector3(1.35, 1.35, 1.35), 0.16)

	# 3. Sonidos de disparo fatal y furia
	if typeof(SFXManager) != TYPE_NIL and SFXManager != null:
		if SFXManager.has_method("play_tense_anger"):
			SFXManager.play_tense_anger()
		if SFXManager.has_method("play_gunshot"):
			SFXManager.play_gunshot()

	# 4. Derribar al jugador al suelo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("fall_down"):
		player.fall_down()

	# 5. Flash de daño rojo en HUD
	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.get("damage_flash"):
		ui.damage_flash.visible = true

	# 6. Disparar Game Over en el sistema
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.trigger_game_over(
			"¡Segundo error fatal!\n" +
			"Atendiste a otra anomalía y la casa colapsó consumiendo tu cordura.\n" +
			"Regla de supervivencia: Si descubres una anomalía en las cámaras con visión nocturna [F], ¡bájale la persiana!"
		)

	get_tree().create_timer(0.35).timeout.connect(func():
		if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_game_over"):
			SFXManager.play_game_over()
	)


## -----------------------------------------------------------------------------
## DEFENSA EXITOSA: El jugador bajó la persiana
## -----------------------------------------------------------------------------
func handle_persiana_closed(npc: CharacterBody3D) -> bool:
	if is_resolved or is_attacking:
		return false
	was_repelled = true

	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_correct"):
		SFXManager.play_correct()

	_hint("¡Excelente! Cerraste la persiana a tiempo y desterraste a la anomalía.")

	if npc and is_instance_valid(npc) and npc.label:
		npc.label.visible = true
		npc.label.text = " *¡CLANG!* ... La sombra se desvanece en la oscuridad ... "
		npc.label.modulate = Color(0.4, 1.0, 0.5, 1.0)

	# Desvanecer la silueta
	if _shadow_clone and is_instance_valid(_shadow_clone):
		var tween := create_tween()
		tween.tween_property(_shadow_clone, "scale", Vector3.ZERO, 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_IN)

	# El cliente se retira de la ventana
	if npc and is_instance_valid(npc):
		if npc.has_method("finish_visit"):
			npc.finish_visit(" ... La anomalía fue desterrada ... ", "correct")
		elif npc.has_method("_start_leaving"):
			npc._start_leaving()

	get_tree().create_timer(0.5).timeout.connect(resolve)
	return true


## -----------------------------------------------------------------------------
## PACIENCIA AGOTADA: No se atendió pero tampoco se bajó la persiana a tiempo
## -----------------------------------------------------------------------------
func handle_timeout(npc: CharacterBody3D) -> bool:
	if is_resolved or is_attacking or was_repelled:
		return false

	# La anomalía mete la mano y roba plata de la caja
	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_tense_anger"):
		SFXManager.play_tense_anger()

	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.lose_money(3000, "La presencia metió la mano y robó la caja")
		_hint("¡Tardaste demasiado! La presencia oscura metió la mano por la ventana y te robó plata. ¡Debías bajar la persiana!")

	if npc and is_instance_valid(npc) and npc.has_method("finish_visit"):
		npc.finish_visit(" ... ", "wrong")

	get_tree().create_timer(0.5).timeout.connect(resolve)
	return true


func resolve() -> void:
	if is_resolved:
		return
	if _shadow_clone and is_instance_valid(_shadow_clone):
		_shadow_clone.visible = false
	super.resolve()


static func _make_clone_world_visible(root: Node) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = 1
	for child in root.get_children():
		_make_clone_world_visible(child)


func _hint(text: String) -> void:
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("request_hint"):
		GameManager.request_hint(text)
