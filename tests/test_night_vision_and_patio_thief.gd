extends Node
## Presencia que solo se ve con visión nocturna (se ahuyenta con la persiana) y
## ladrón del patio que fuerza la puerta trasera (se ahuyenta cerrándola).

var _passed := 0
var _failed := 0
var _main: Node
var _monitor: Node
var _player: Node
var _manager: AnomaliesManager
var _persiana: Node3D
var _door: Node3D


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("[NightThiefTest] OK   ", msg)
	else:
		_failed += 1
		print("[NightThiefTest] FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Espera hasta que `cond` sea verdadera o pasen `timeout` segundos
func _wait_until(cond: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while not cond.call():
		if elapsed >= timeout:
			return false
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return true


## Condición "la anomalía ya terminó" que no retiene la instancia (se libera al resolverse)
func _gone_check(anomaly: AnomalyBase) -> Callable:
	var ref: WeakRef = weakref(anomaly)
	return func(): return ref.get_ref() == null or ref.get_ref().is_resolved


func _ready() -> void:
	print("[NightThiefTest] Iniciando test de visión nocturna y ladrón del patio...")
	get_window().size = Vector2i(1280, 720)
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_manager = _main.get_node("AnomaliesManagement") as AnomaliesManager
	_manager.anomalies_enabled = false
	_monitor = _main.find_child("SecurityMonitor", true, false)
	_player = get_tree().get_first_node_in_group("player")
	_persiana = get_tree().get_first_node_in_group("persiana") as Node3D
	_door = get_tree().get_first_node_in_group("back_door") as Node3D
	GameManager.savings = 20000
	await _frames(3)

	await _test_night_vision_layers()
	await _test_night_entity_repelled()
	await _test_night_entity_attack()
	await _test_thief_repelled()
	await _test_thief_steals()

	print("[NightThiefTest] Resultado: %d OK, %d FAIL" % [_passed, _failed])
	if _failed == 0:
		print("[NightThiefTest]  ÉXITO: todos los pasos pasaron.")
	get_tree().quit(0 if _failed == 0 else 1)


func _collect_visuals(root: Node) -> Array[VisualInstance3D]:
	var out: Array[VisualInstance3D] = []
	if root is VisualInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_collect_visuals(c))
	return out


func _cam(channel_id: String) -> Camera3D:
	for c in _monitor.channels:
		if c.channel_id == channel_id:
			return c
	return null


func _test_night_vision_layers() -> void:
	var nv := CCTVCamera.NIGHT_VISION_RENDER_LAYER
	_check(_persiana != null, "La persiana está en el grupo 'persiana'")
	_check(_door != null and _door is BackDoor, "La puerta trasera usa BackDoor.gd y está en el grupo 'back_door'")
	_check(not _player.get_node("Camera3D").get_cull_mask_value(nv), "La cámara del jugador NO ve la capa de visión nocturna")
	for cam in _monitor.channels:
		_check(not cam.get_cull_mask_value(nv), "La cámara '%s' no ve la capa nocturna sin [F]" % cam.channel_id)

	_monitor.interact(_player)
	await _frames(2)
	_monitor.toggle_anomaly_vision()
	await _frames(2)
	for cam in _monitor.channels:
		_check(cam.get_cull_mask_value(nv), "Con [F], la cámara '%s' ve la capa nocturna" % cam.channel_id)
	var vp_cam: Camera3D = _monitor.security_cam_viewport.get_node("VPCamera")
	_check(vp_cam.get_cull_mask_value(nv), "La pantalla del monitor también ve la capa nocturna con [F]")
	_check(_monitor._feed_material.get_shader_parameter("night_vision") == 1.0, "El filtro del monitor se tiñe de visión nocturna")
	_check("VISIÓN NOCTURNA" in _monitor._channel_label.text, "El HUD indica la visión nocturna")

	_monitor.toggle_anomaly_vision()
	await _frames(2)
	for cam in _monitor.channels:
		_check(not cam.get_cull_mask_value(nv), "Al apagar [F], '%s' deja de ver la capa nocturna" % cam.channel_id)
	_monitor.interact(_player)
	await _frames(2)


func _test_night_entity_repelled() -> void:
	var zone: Node3D = _main.get_node("CCTVZones/EsquinaCalle")
	var entity := _manager.force_trigger_anomaly("cctv_night_entity", {"cctv_zone": zone}) as CCTVNightEntityAnomaly
	_check(entity != null, "Se dispara la presencia en la vereda")
	await _frames(2)
	_check(entity.channel_id == "frente", "La presencia aparece en el canal 'frente'")

	var visuals := _collect_visuals(entity)
	var only_nv := visuals.size() > 0
	for v in visuals:
		if v.layers != 1 << (CCTVCamera.NIGHT_VISION_RENDER_LAYER - 1):
			only_nv = false
		if v is GeometryInstance3D and v.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			only_nv = false
	_check(only_nv, "Sus visuales están solo en la capa de visión nocturna y sin sombras")

	var cam := _cam("frente")
	var head := Vector3(0, 1.8, 0)
	_check(cam.is_position_in_frustum(entity._start + head), "La CAM 01 encuadra el punto de partida")
	_check(cam.is_position_in_frustum(entity._target + head), "La CAM 01 encuadra la ventana adonde se acerca")

	# Mirando la CAM 01 sin visión nocturna: solo interferencia
	_monitor.interact(_player)
	_monitor.set_channel(0)
	await _frames(3)
	_check(entity.is_viewed_now and not entity.was_seen_with_night_vision, "Sin [F] el jugador mira el canal pero no la ve")
	_check(_monitor.get_channel_interference("frente") >= entity.clue_interference, "Sin [F] deja interferencia como pista")

	_monitor.toggle_anomaly_vision()
	await _frames(3)
	_check(entity.was_seen_with_night_vision, "Con [F] la presencia se ve")
	_check(_monitor.get_channel_interference("frente") == 0.0, "Con [F] la imagen queda limpia")

	var d0 := entity.global_position.distance_to(entity._target)
	await get_tree().create_timer(0.5).timeout
	_check(entity.global_position.distance_to(entity._target) < d0, "Se va acercando a la ventana")

	var money := GameManager.savings
	_persiana.close()
	await _frames(1)
	_check(entity.was_repelled, "Bajar la persiana la ahuyenta")
	var gone := await _wait_until(_gone_check(entity), 3.0)
	_check(gone, "La presencia desaparece después de ahuyentarla")
	_check(GameManager.savings == money, "No se pierde plata al ahuyentarla")
	_persiana.open()
	_monitor.toggle_anomaly_vision()
	_monitor.interact(_player)
	await get_tree().create_timer(0.6).timeout


func _test_night_entity_attack() -> void:
	var entity := _manager.force_trigger_anomaly("cctv_night_entity", {"cctv_zone": _main.get_node("CCTVZones/VeredaCentro")}) as CCTVNightEntityAnomaly
	entity.approach_time = 0.3
	var money := GameManager.savings
	var done := await _wait_until(_gone_check(entity), 4.0)
	_check(done, "Si nadie baja la persiana, llega a la ventana y termina")
	_check(GameManager.savings == money - 4000, "Con la persiana arriba se pierden $4.000 (%d -> %d)" % [money, GameManager.savings])


func _test_thief_repelled() -> void:
	_check(not _door.is_open, "La puerta trasera parte cerrada")
	var thief := _manager.force_trigger_anomaly("cctv_patio_thief") as CCTVPatioThiefAnomaly
	_check(thief != null, "Se dispara el ladrón del patio")
	await _frames(2)
	_check(thief.channel_id == "patio", "El ladrón aparece en el canal del patio")
	_check(thief.zone.name != "PuertaTrasera", "Parte lejos de la puerta (zona '%s')" % thief.zone.name)
	var world_visible := true
	for v in _collect_visuals(thief):
		if v.layers != 1:
			world_visible = false
	_check(world_visible, "El ladrón es visible en el mundo (no solo en CCTV)")

	var cam := _cam("patio")
	var head := Vector3(0, 1.6, 0)
	_check(cam.is_position_in_frustum(thief._start + head), "La CAM 02 encuadra por dónde entra al patio")
	_check(cam.is_position_in_frustum(thief._outside_point + head), "La CAM 02 encuadra la puerta trasera")

	thief.walk_speed = 8.0
	thief.force_time = 0.3
	thief.grace_time = 5.0
	var forcing := await _wait_until(func(): return thief.phase == CCTVPatioThiefAnomaly.Phase.FORCING, 4.0)
	_check(forcing, "Llega a la puerta y la forcejea")
	var lurking := await _wait_until(func(): return thief.phase == CCTVPatioThiefAnomaly.Phase.LURKING, 3.0)
	_check(lurking and thief.forced_door and _door.is_open, "Fuerza la puerta trasera y la deja abierta")

	var money := GameManager.savings
	await get_tree().create_timer(0.5).timeout
	_door.close()
	await _frames(2)
	_check(thief.was_repelled and thief.phase == CCTVPatioThiefAnomaly.Phase.FLEEING, "Cerrar la puerta trasera lo hace arrancar")
	var gone := await _wait_until(_gone_check(thief), 6.0)
	_check(gone, "El ladrón se va del patio")
	_check(GameManager.savings == money, "No se pierde plata si se cierra a tiempo")
	_check(_door.get_interaction_prompt(_player).text == "[E] Abrir puerta trasera", "La puerta cerrada ofrece abrirse")


func _test_thief_steals() -> void:
	await get_tree().create_timer(0.5).timeout
	var thief := _manager.force_trigger_anomaly("cctv_patio_thief") as CCTVPatioThiefAnomaly
	thief.walk_speed = 8.0
	thief.flee_speed = 12.0
	thief.force_time = 0.2
	thief.grace_time = 0.2
	var money := GameManager.savings
	var stole := await _wait_until(func(): return thief.did_steal, 6.0)
	_check(stole, "Si nadie cierra la puerta, el ladrón entra y roba")
	_check(GameManager.savings == money - 5000, "Se lleva $5.000 (%d -> %d)" % [money, GameManager.savings])
	_check(_door.is_open, "La puerta queda abierta después del robo")
	var gone := await _wait_until(_gone_check(thief), 6.0)
	_check(gone, "El ladrón escapa y el evento termina")
