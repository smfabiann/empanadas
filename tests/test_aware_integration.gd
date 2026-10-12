extends Node

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

	# 8. Resolver anomalía y verificar limpieza
	aware_instance.resolve()
	await get_tree().process_frame

	_finish(true, "Todos los pasos pasaron exitosamente!")


func _finish(success: bool, msg: String) -> void:
	if success:
		_log_msg("✅ ÉXITO: " + msg)
		get_tree().quit(0)
	else:
		push_error("❌ ERROR: " + msg)
		get_tree().quit(1)
