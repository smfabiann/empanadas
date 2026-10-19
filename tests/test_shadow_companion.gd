extends Node

const CCTVCameraClass = preload("res://scripts/cctv/CCTVCamera.gd")
const CCTVShadowCompanionClass = preload("res://scripts/anomalies/cctv/CCTVShadowCompanionAnomaly.gd")

var _passed := 0
var _failed := 0
var _main: Node
var _manager: Node
var _monitor: Node


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("[ShadowTest] OK   ", msg)
	else:
		_failed += 1
		print("[ShadowTest] FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	print("[ShadowTest] Iniciando suite de pruebas para El Acompañante Oculto...")
	_main = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	add_child(_main)
	_manager = _main.get_node("AnomaliesManagement")
	_manager.anomalies_enabled = false
	_monitor = _main.find_child("SecurityMonitor", true, false)
	await _frames(3)

	await _test_registration()
	await _test_layer_and_tracking()
	await _test_persiana_defense()
	await _test_lethal_serving()

	print("\n[ShadowTest] RESULTADOS: %d pasadas, %d fallidas." % [_passed, _failed])
	if _failed > 0:
		push_error("[ShadowTest] Hubo fallas en las pruebas.")
	else:
		print("[ShadowTest] ¡TODAS LAS PRUEBAS PASARON EXITOSAMENTE!")
	get_tree().quit(0 if _failed == 0 else 1)


func _test_registration() -> void:
	_check(_manager.is_anomaly_enabled("cctv_shadow_companion"), "cctv_shadow_companion está registrada y habilitada en AnomaliesManager")


func _test_layer_and_tracking() -> void:
	# Crear un NPC de prueba
	var npc_scene := load("res://scenes/NPC.tscn") as PackedScene
	var npc: CharacterBody3D = npc_scene.instantiate()
	_main.add_child(npc)
	npc.global_position = Vector3(-0.43, 0.2, -4.5)
	await _frames(2)

	# Forzar la anomalía pasándole el NPC
	var anom: CCTVShadowCompanionClass = _manager.spawn_anomaly(_manager.get_anomaly_data("cctv_shadow_companion"), {"npc": npc}) as CCTVShadowCompanionClass
	_check(anom != null, "La anomalía CCTVShadowCompanionAnomaly se instancia correctamente")

	await _frames(2)

	var clone: Node3D = anom._shadow_clone
	_check(clone != null, "El clon de sombra se construyó")

	# Verificar que todos los nodos visuales del clon estén en la capa 12 (NIGHT_VISION_RENDER_LAYER)
	var expected_layer: int = 1 << (CCTVCameraClass.NIGHT_VISION_RENDER_LAYER - 1)
	var all_nv := true
	for child in clone.get_children():
		if child is VisualInstance3D:
			if (child as VisualInstance3D).layers != expected_layer:
				all_nv = false
	_check(all_nv, "La sombra está asignada exclusivamente a la capa 12 (Visión Nocturna CCTV)")

	# Mover el NPC y verificar seguimiento
	npc.global_position = Vector3(1.0, 0.2, -5.0)
	anom._update_event(0.1)
	var dist_to_npc = clone.global_position.distance_to(npc.global_position)
	_check(dist_to_npc < 1.0, "La sombra acompaña la posición del NPC (distancia relativa: %.2f m)" % dist_to_npc)

	anom.resolve()
	npc.queue_free()
	await _frames(2)


func _test_persiana_defense() -> void:
	var npc_scene := load("res://scenes/NPC.tscn") as PackedScene
	var npc: CharacterBody3D = npc_scene.instantiate()
	_main.add_child(npc)
	npc.global_position = Vector3(-0.43, 0.2, -4.5)
	await _frames(2)

	var anom: CCTVShadowCompanionClass = _manager.spawn_anomaly(_manager.get_anomaly_data("cctv_shadow_companion"), {"npc": npc}) as CCTVShadowCompanionClass
	await _frames(2)

	_check(npc.active_event != null, "El NPC recibió el evento ShadowCompanionNPCEvent")

	# Simular que el jugador baja la persiana
	var handled = npc.active_event.on_persiana_closed(npc)
	_check(handled == true, "on_persiana_closed fue manejado por la anomalía")
	_check(anom.was_repelled == true, "La anomalía fue repelida con éxito")

	await get_tree().create_timer(0.6).timeout
	_check(not is_instance_valid(anom) or anom.is_resolved == true, "La anomalía se resolvió y liberó tras cerrar la persiana")

	npc.queue_free()
	await _frames(2)


func _test_lethal_serving() -> void:
	GameManager.reset_game()
	_check(GameManager.anomaly_strikes == 0, "GameManager inicia con 0 strikes de anomalías")

	var npc_scene := load("res://scenes/NPC.tscn") as PackedScene
	var npc: CharacterBody3D = npc_scene.instantiate()
	_main.add_child(npc)
	npc.global_position = Vector3(-0.43, 0.2, -4.5)
	await _frames(2)

	var anom: CCTVShadowCompanionClass = _manager.spawn_anomaly(_manager.get_anomaly_data("cctv_shadow_companion"), {"npc": npc}) as CCTVShadowCompanionClass
	await _frames(2)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.is_dead = false

	# ----------------------------------------------------
	# STRIKE 1: Primer error al atender la anomalía
	# ----------------------------------------------------
	var dummy_item := Node3D.new()
	var handled = npc.active_event.on_item_received(npc, dummy_item)
	_check(handled == true, "Primer error: on_item_received interceptado")
	_check(GameManager.anomaly_strikes == 1, "GameManager registra exactamente 1 strike")
	if player:
		_check(player.is_dead == false, "Primer error: el jugador NO muere, solo recibe advertencia")

	await get_tree().create_timer(1.9).timeout

	# Comprobar que las paredes cambiaron al color burdeo tras la transición
	var shop = _main.find_child("Shop", true, false)
	var wall = shop.find_child("WallBack", true, false) if shop else null
	if wall and wall.material is StandardMaterial3D:
		var col: Color = wall.material.albedo_color
		_check(col.r > col.b and col.r > col.g, "Primer error: las paredes interiores se tiñen de rojo burdeo (R: %.2f, G: %.2f, B: %.2f)" % [col.r, col.g, col.b])

	_check(not is_instance_valid(dummy_item) or dummy_item.is_queued_for_deletion(), "El ítem entregado fue consumido y liberado de las manos")
	npc.queue_free()
	await _frames(2)

	# ----------------------------------------------------
	# PERSISTENCIA: Avanzar al día siguiente
	# ----------------------------------------------------
	GameManager.start_next_day()
	_check(GameManager.current_day == 2, "Avanzó al Día 2")
	_check(GameManager.anomaly_strikes == 1, "El strike persiste intacto en el Día 2")
	if wall and wall.material is StandardMaterial3D:
		var col2: Color = wall.material.albedo_color
		_check(col2.r > col2.b and col2.r > col2.g, "En el Día 2 las paredes continúan teñidas de burdeo")

	# ----------------------------------------------------
	# STRIKE 2: Segundo error al atender otra anomalía (Muerte)
	# ----------------------------------------------------
	var npc2: CharacterBody3D = npc_scene.instantiate()
	_main.add_child(npc2)
	npc2.global_position = Vector3(-0.43, 0.2, -4.5)
	await _frames(2)

	var anom2: CCTVShadowCompanionClass = _manager.spawn_anomaly(_manager.get_anomaly_data("cctv_shadow_companion"), {"npc": npc2}) as CCTVShadowCompanionClass
	await _frames(2)

	var dummy_item2 := Node3D.new()
	var handled2 = npc2.active_event.on_item_received(npc2, dummy_item2)
	_check(handled2 == true, "Segundo error: on_item_received interceptado")
	_check(GameManager.anomaly_strikes == 2, "GameManager registra 2 strikes acumulados")
	if player:
		_check(player.is_dead == true, "Segundo error: el jugador es abatido letalmente (is_dead = true)")

	npc2.queue_free()
	if is_instance_valid(dummy_item2):
		dummy_item2.queue_free()
	await _frames(2)
