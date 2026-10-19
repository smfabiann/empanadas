extends Node

const AwareNPCEventClass = preload("res://scripts/events/AwareNPCEvent.gd")

var _log: Array[String] = []

func _log_msg(msg: String) -> void:
	_log.append(msg)
	print("[IntegrationTest] ", msg)

func _ready() -> void:
	_log_msg("Iniciando test de integración de Anomalía Aware...")
	
	# 1. Verificar carga de Main.tscn
	var main_packed = load("res://scenes/Main.tscn") as PackedScene
	if not main_packed:
		_finish(false, "No se pudo cargar Main.tscn")
		return

	var main_instance = main_packed.instantiate()
	add_child(main_instance)

	var anomalies_mgr = main_instance.get_node_or_null("AnomaliesManagement") as AnomaliesManager
	if not anomalies_mgr:
		_finish(false, "No se encontró AnomaliesManagement en Main.tscn")
		return

	# 2. Verificar que 'aware' esté registrado en el catálogo
	var aware_data = anomalies_mgr.get_anomaly_data("aware")
	if not aware_data:
		_finish(false, "La anomalía 'aware' no está registrada en AnomaliesManagement")
		return
	_log_msg("Aware registrado correctamente en catálogo con nombre: " + aware_data.anomaly_name)

	# 3. Disparar forzadamente la anomalía 'aware'
	var aware_instance = anomalies_mgr.force_trigger_anomaly("aware") as Aware
	if not aware_instance:
		_finish(false, "Fallo al forzar el disparo de 'aware'")
		return
	_log_msg("Aware instanciado y activo en AnomaliesManagement.")

	# 4. Encontrar el monitor de seguridad en Main
	var monitor = main_instance.find_child("SecurityMonitor", true, false)
	if not monitor:
		_finish(false, "No se encontró SecurityMonitor en la escena Main")
		return

	# 5. Inicialmente no se debe ver
	if aware_instance.eye_root.visible:
		_finish(false, "El ojo de Aware NO debería estar visible antes de mirar el monitor")
		return
	_log_msg("Paso 1: Antes de mirar el monitor, ojo está oculto. [OK]")

	# 6. Simular mirar a través del monitor
	monitor.is_viewing = true
	# Procesar frame
	await get_tree().process_frame
	await get_tree().process_frame

	if not aware_instance.eye_root.visible:
		_finish(false, "El ojo de Aware DEBERÍA estar visible al mirar a través del monitor")
		return
	_log_msg("Paso 2: Al mirar a través del monitor, ojo está visible. [OK]")

	# 7. Simular dejar de mirar el monitor
	monitor.is_viewing = false
	await get_tree().process_frame
	await get_tree().process_frame

	if aware_instance.eye_root.visible:
		_finish(false, "El ojo de Aware NO debería estar visible tras dejar de mirar el monitor")
		return
	_log_msg("Paso 3: Al dejar de mirar el monitor, ojo se oculta inmediatamente. [OK]")

	# 8. Resolver anomalía inicial de monitor
	aware_instance.resolve()
	await get_tree().process_frame

	# 9. Test de servicio a Aware (Strike 1 - Screamer & Advertencia)
	GameManager.reset_game()
	var npc_scene = load("res://scenes/NPC.tscn") as PackedScene
	var npc1 = npc_scene.instantiate() as CharacterBody3D
	main_instance.add_child(npc1)
	npc1.global_position = Vector3(-0.43, 0.2, -4.5)
	await get_tree().process_frame
	await get_tree().process_frame

	var aware2 = anomalies_mgr.spawn_anomaly(aware_data, {"npc": npc1}) as Aware
	if not aware2:
		_finish(false, "No se pudo spawnear Aware vinculado a NPC")
		return

	if not npc1.active_event or not (npc1.active_event is AwareNPCEventClass):
		_finish(false, "El NPC no recibió el evento AwareNPCEvent")
		return
	_log_msg("Paso 4: AwareNPCEvent asignado correctamente al cliente. [OK]")

	var dummy_item1 = Node3D.new()
	var handled1 = npc1.active_event.on_item_received(npc1, dummy_item1)
	if not handled1:
		_finish(false, "on_item_received no fue manejado por AwareNPCEvent")
		return
	if GameManager.anomaly_strikes != 1:
		_finish(false, "GameManager debería registrar 1 strike, tiene: %d" % GameManager.anomaly_strikes)
		return

	var player = get_tree().get_first_node_in_group("player")
	if player and player.is_dead:
		_finish(false, "El jugador NO debería morir en el strike 1")
		return
	_log_msg("Paso 5: Strike 1 registrado, jugador sobrevive y se ejecuta screamer. [OK]")

	# Esperar a que terminen las consecuencias
	await get_tree().create_timer(2.2).timeout

	# 10. Test de servicio a Aware (Strike 2 - Letal)
	var npc2 = npc_scene.instantiate() as CharacterBody3D
	main_instance.add_child(npc2)
	npc2.global_position = Vector3(-0.43, 0.2, -4.5)
	await get_tree().process_frame
	await get_tree().process_frame

	var aware3 = anomalies_mgr.spawn_anomaly(aware_data, {"npc": npc2}) as Aware
	var dummy_item2 = Node3D.new()
	var handled2 = npc2.active_event.on_item_received(npc2, dummy_item2)
	if not handled2:
		_finish(false, "Segundo error: on_item_received no fue interceptado")
		return
	if GameManager.anomaly_strikes != 2:
		_finish(false, "GameManager debería registrar 2 strikes acumulados, tiene: %d" % GameManager.anomaly_strikes)
		return
	if player and not player.is_dead:
		_finish(false, "En el strike 2 el jugador debería morir fatalmente")
		return
	_log_msg("Paso 6: Strike 2 registrado, screamer letal y muerte del jugador (Game Over). [OK]")

	_finish(true, "Todos los pasos pasaron exitosamente!")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _finish(success: bool, msg: String) -> void:
	if success:
		_log_msg(" ÉXITO: " + msg)
		await _frames(2)
		get_tree().quit(0)
	else:
		push_error(" ERROR: " + msg)
		await _frames(2)
		get_tree().quit(1)
