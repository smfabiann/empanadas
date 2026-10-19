extends Node
## HU-10: Detonación de eventos visibles en CCTV.
## Verifica canales del monitor, la capa de render exclusiva de CCTV, la posición
## de los eventos en sus zonas y la limpieza sin artefactos al resolverse.

var _passed := 0
var _failed := 0
var _main: Node
var _monitor: Node
var _player: Node
var _manager: AnomaliesManager


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("[CCTVTest] OK   ", msg)
	else:
		_failed += 1
		print("[CCTVTest] FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	print("[CCTVTest] Iniciando test de eventos visibles en CCTV (HU-10)...")
	# En modo headless la ventana es cuadrada: usar la proporción 16:9 del juego para los encuadres
	get_window().size = Vector2i(1280, 720)
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_manager = _main.get_node("AnomaliesManagement") as AnomaliesManager
	# Sin anomalías aleatorias: el test fuerza las que necesita
	_manager.anomalies_enabled = false
	_monitor = _main.find_child("SecurityMonitor", true, false)
	_player = get_tree().get_first_node_in_group("player")
	await _frames(3)

	await _test_channels()
	await _test_flashlight()
	await _test_render_layers()
	await _test_zones_covered()
	await _test_lurker()
	await _test_power_failure()
	await _test_intruder()
	await _test_cleanup()

	print("[CCTVTest] Resultado: %d OK, %d FAIL" % [_passed, _failed])
	if _failed == 0:
		print("[CCTVTest]  ÉXITO: todos los pasos pasaron.")
	get_tree().quit(0 if _failed == 0 else 1)


func _test_channels() -> void:
	_check(_monitor != null, "SecurityMonitor existe en Main.tscn")
	_check(_monitor.channels.size() == 2, "El monitor tiene 2 canales (tiene %d)" % _monitor.channels.size())
	_check(_monitor.get_current_channel_id() == "frente", "El canal inicial es 'frente'")

	_monitor.interact(_player)
	await _frames(2)
	_check(_monitor.is_viewing and _player.is_viewing_monitor, "Al interactuar se entra a la vista CCTV")
	_check(_monitor.channels[0].current, "La cámara del canal 1 queda activa")
	_check(_monitor._overlay_layer.visible, "El HUD del monitor (canal/hora/filtro) es visible")
	_check("CAM 01" in _monitor._channel_label.text, "El HUD muestra 'CAM 01'")

	_monitor.switch_channel(1)
	await _frames(2)
	_check(_monitor.get_current_channel_id() == "patio", "[D] cambia al canal 'patio'")
	_check(_monitor.channels[1].current, "La cámara del patio queda activa")
	_check("PATIO" in _monitor._channel_label.text, "El HUD muestra el nombre del canal del patio")

	_monitor.switch_channel(1)
	await _frames(1)
	_check(_monitor.get_current_channel_id() == "frente", "Cambiar de canal da la vuelta al primero")


func _test_flashlight() -> void:
	_check(_monitor.is_viewing, "El monitor está en modo vista")
	_check(not _monitor.is_flashlight_on, "La linterna inicia apagada")

	# 1. Encender linterna (simulando click izquierdo)
	_monitor.toggle_flashlight()
	await _frames(2)
	_check(_monitor.is_flashlight_on, "Al hacer click izquierdo la linterna se enciende")
	_check(_monitor._flashlight != null and _monitor._flashlight is SpotLight3D, "Existe el nodo SpotLight3D de la linterna")
	_check(_monitor._flashlight.visible, "El foco SpotLight3D está visible")
	_check(_monitor._flashlight.get_parent() == _monitor.security_camera, "La linterna está montada en la cámara activa (frente)")

	# 2. Cambiar al canal de patio: la linterna debe mudarse a la cámara de patio
	_monitor.switch_channel(1)
	await _frames(2)
	_check(_monitor._flashlight.get_parent() == _monitor.security_camera, "Al cambiar de canal, la linterna se reubica en la cámara de patio")
	_check(_monitor._flashlight.visible, "La linterna sigue encendida e iluminando el nuevo canal")

	# 3. Volver al frente y apagar linterna
	_monitor.switch_channel(1)
	await _frames(2)
	_monitor.toggle_flashlight()
	await _frames(2)
	_check(not _monitor.is_flashlight_on, "Al hacer click de nuevo, la linterna se apaga")
	_check(not _monitor._flashlight.visible, "El foco SpotLight3D se oculta")


func _test_render_layers() -> void:
	var player_cam: Camera3D = _player.get_node("Camera3D")
	_check(not player_cam.get_cull_mask_value(CCTVCamera.CCTV_RENDER_LAYER), "La cámara del jugador NO ve la capa de CCTV")
	for cam in _monitor.channels:
		_check(cam.get_cull_mask_value(CCTVCamera.CCTV_RENDER_LAYER), "La cámara '%s' ve la capa de CCTV" % cam.channel_id)
	var vp_cam: Camera3D = _monitor.security_cam_viewport.get_node("VPCamera")
	_check(vp_cam.get_cull_mask_value(CCTVCamera.CCTV_RENDER_LAYER), "La pantalla del monitor (SubViewport) también ve la capa de CCTV")


func _test_zones_covered() -> void:
	var zones := get_tree().get_nodes_in_group("cctv_zones")
	_check(zones.size() >= 4, "Hay zonas de CCTV en Main.tscn (%d)" % zones.size())
	for zone in zones:
		var cam: Camera3D = null
		for c in _monitor.channels:
			if c.channel_id == zone.channel_id:
				cam = c
		var head: Vector3 = zone.global_position + Vector3(0, 1.6, 0)
		_check(cam != null and cam.is_position_in_frustum(head), "La zona '%s' está dentro del encuadre de su cámara" % zone.name)


func _zone(zone_name: String) -> Node3D:
	return _main.get_node("CCTVZones/" + zone_name)


func _test_lurker() -> void:
	var zone := _zone("PatioCentro")
	var lurker := _manager.force_trigger_anomaly("cctv_lurker", {"cctv_zone": zone}) as CCTVLurkerAnomaly
	_check(lurker != null, "Se dispara la silueta acechando")
	await _frames(2)
	_check(lurker.channel_id == "patio", "La silueta pertenece al canal del patio")
	_check(lurker.global_position.distance_to(zone.global_position) < 0.01, "La silueta aparece en la posición asignada")

	var visuals := _collect_visuals(lurker)
	_check(visuals.size() > 0, "La silueta tiene visuales 3D")
	var only_cctv := true
	for v in visuals:
		if v.layers != 1 << (CCTVCamera.CCTV_RENDER_LAYER - 1):
			only_cctv = false
		if v is GeometryInstance3D and v.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			only_cctv = false
	_check(only_cctv, "Todos sus visuales están solo en la capa de CCTV y sin sombras")

	# El monitor está en 'frente': no la ve
	await _frames(3)
	_check(not lurker.was_seen, "No se considera vista mientras el canal sintonizado es otro")

	_monitor.set_channel(1)
	await _frames(3)
	_check(lurker.was_seen and lurker.is_viewed_now, "Se ve al sintonizar el canal del patio")
	var cam: Camera3D = _monitor.channels[1]
	var dist_before := _flat_dist(lurker.global_position, cam.global_position)

	_monitor.set_channel(0)
	await _frames(2)
	_monitor.set_channel(1)
	await _frames(2)
	var dist_after := _flat_dist(lurker.global_position, cam.global_position)
	_check(dist_after < dist_before - 0.5, "Al volver a mirar, la silueta está más cerca (%.2f -> %.2f m)" % [dist_before, dist_after])
	lurker.resolve()
	await _frames(2)


func _test_power_failure() -> void:
	var failure := _manager.force_trigger_anomaly("cctv_power_failure", {"cctv_zone": _zone("VeredaCentro")}) as CCTVPowerFailureAnomaly
	_check(failure != null, "Se dispara el fallo eléctrico")
	_monitor.set_channel(0)
	await _frames(3)
	_check(_monitor.get_channel_interference("frente") >= failure.base_interference, "El canal 'frente' tiene interferencia")
	_check(_monitor.get_channel_interference("patio") == 0.0, "El canal 'patio' no se ve afectado")
	await _frames(15)
	var shader_value: float = _monitor._feed_material.get_shader_parameter("interference")
	_check(shader_value >= failure.base_interference, "El filtro del monitor muestra la interferencia (%.2f)" % shader_value)
	failure.resolve()
	await _frames(2)
	_check(_monitor.get_channel_interference("frente") == 0.0, "Al terminar el fallo, el canal 'frente' vuelve a la normalidad")


func _test_intruder() -> void:
	var intruder := _manager.force_trigger_anomaly("cctv_intruder", {"cctv_zone": _zone("VeredaPoniente")}) as CCTVIntruderAnomaly
	_check(intruder != null, "Se dispara el intruso en el perímetro")
	var start := intruder.global_position
	await _frames(30)
	_check(intruder.global_position.distance_to(start) > 0.05, "El intruso se desplaza por el perímetro")
	intruder.notice_after = 0.05
	_monitor.set_channel(0)
	await _frames(10)
	_check(intruder.has_noticed_camera, "Al observarlo por el monitor, el intruso nota la cámara")


func _test_cleanup() -> void:
	# Forzar varios eventos activos y terminar la jornada
	_manager.force_trigger_anomaly("cctv_lurker", {"cctv_zone": _zone("BanoQuimico")})
	_manager.force_trigger_anomaly("cctv_power_failure", {"cctv_zone": _zone("PuertaTrasera")})
	await _frames(2)
	_manager.resolve_all_anomalies()
	await _frames(3)

	_check(get_tree().get_nodes_in_group("cctv_feed_modifiers").is_empty(), "No quedan modificadores de señal activos")
	_check(_count_cctv_visuals(get_tree().root) == 0, "No quedan visuales en la capa de CCTV (sin artefactos residuales)")
	_check(_monitor.get_channel_interference("patio") == 0.0 and _monitor.get_channel_interference("frente") == 0.0, "Ningún canal conserva interferencia")

	_monitor.interact(_player)
	await _frames(2)
	_check(not _monitor.is_viewing and not _player.is_viewing_monitor, "Se sale de la vista CCTV")
	_check(_player.get_node("Camera3D").current, "La cámara del jugador vuelve a estar activa")
	_check(not _monitor._overlay_layer.visible, "El HUD del monitor se oculta al salir")


func _collect_visuals(root: Node) -> Array[VisualInstance3D]:
	var out: Array[VisualInstance3D] = []
	if root is VisualInstance3D:
		out.append(root)
	for c in root.get_children():
		out.append_array(_collect_visuals(c))
	return out


func _count_cctv_visuals(root: Node) -> int:
	var count := 0
	for v in _collect_visuals(root):
		if v.layers == 1 << (CCTVCamera.CCTV_RENDER_LAYER - 1) and v.is_visible_in_tree():
			count += 1
	return count


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
