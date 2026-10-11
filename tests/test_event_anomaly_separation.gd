extends Node

var tests_passed: int = 0
var tests_failed: int = 0

func assert_true(cond: bool, msg: String) -> void:
	if cond:
		tests_passed += 1
		print("  [PASS] ", msg)
	else:
		tests_failed += 1
		printerr("  [FAIL] ", msg)

func _ready() -> void:
	print("=== RUNNING EVENT & ANOMALY DECOUPLING TEST SUITE ===")
	test_ufo_is_event_not_anomaly()
	test_anomalies_manager_ignores_event_npc()
	test_static_event_resolves_lingering_anomalies()
	test_normal_customer_can_trigger_anomaly()

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [tests_passed, tests_failed])
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_ufo_is_event_not_anomaly() -> void:
	print("\n--- Test 1: UFO is StaticNPCEvent and not in AnomaliesManager ---")
	var event_mgr := NPCEventManager.new()
	add_child(event_mgr)

	var ufo_event = event_mgr.get_event("ufo")
	assert_true(ufo_event != null, "UFO event is registered in NPCEventManager")
	assert_true(ufo_event is StaticNPCEvent, "UFO event inherits from StaticNPCEvent")
	assert_true(not (ufo_event is AnomalyBase), "UFO event is NOT AnomalyBase")

	var anomalies_mgr := AnomaliesManager.new()
	add_child(anomalies_mgr)

	assert_true(not anomalies_mgr.anomalies_by_id.has("ufo"), "UFO is NOT registered in AnomaliesManager")

	event_mgr.queue_free()
	anomalies_mgr.queue_free()

func test_anomalies_manager_ignores_event_npc() -> void:
	print("\n--- Test 2: AnomaliesManager does not trigger on event NPCs ---")
	var anomalies_mgr := AnomaliesManager.new()
	anomalies_mgr.debug_always_trigger = true # Force 100% chance for testing
	add_child(anomalies_mgr)

	var ufo_scene: PackedScene = load("res://scenes/events/static/UfoNPC.tscn")
	var ufo_npc: UfoNPC = ufo_scene.instantiate() as UfoNPC
	var ufo_event := UfoEvent.new()
	ufo_npc.assign_event(ufo_event)
	add_child(ufo_npc)

	# 1. Attempt to trigger anomaly with context has_event = true
	var result_with_has_event = anomalies_mgr.evaluate_and_trigger(1, 0, 2, {
		"npc": ufo_npc,
		"has_event": true,
		"event": "npc_spawned"
	})
	assert_true(result_with_has_event == null, "evaluate_and_trigger returned null when has_event=true")

	# 2. Attempt to trigger anomaly with context referencing NPC with active_event
	var result_with_npc = anomalies_mgr.evaluate_and_trigger(1, 0, 2, {
		"npc": ufo_npc,
		"event": "npc_spawned"
	})
	assert_true(result_with_npc == null, "evaluate_and_trigger returned null when NPC has active_event")
	assert_true(anomalies_mgr.active_anomalies.is_empty(), "No active anomalies spawned for UFO")

	ufo_npc.queue_free()
	anomalies_mgr.queue_free()

func test_static_event_resolves_lingering_anomalies() -> void:
	print("\n--- Test 3: Static events resolve lingering anomalies ---")
	var anomalies_mgr := AnomaliesManager.new()
	add_child(anomalies_mgr)

	# Force trigger glitch sprite anomaly
	var anomaly = anomalies_mgr.force_trigger_anomaly("glitch_sprite")
	assert_true(anomaly != null, "Glitch sprite anomaly successfully triggered")
	assert_true(anomalies_mgr.active_anomalies.size() == 1, "AnomaliesManager has 1 active anomaly")

	# When a static event like UFO or Robber starts, resolve_all_anomalies is called
	anomalies_mgr.resolve_all_anomalies()
	assert_true(anomalies_mgr.active_anomalies.is_empty(), "Lingering anomalies resolved cleanly for static event")

	anomalies_mgr.queue_free()

func test_normal_customer_can_trigger_anomaly() -> void:
	print("\n--- Test 4: Normal customer without event can trigger anomaly ---")
	var anomalies_mgr := AnomaliesManager.new()
	anomalies_mgr.debug_always_trigger = true
	add_child(anomalies_mgr)

	var npc_scene: PackedScene = load("res://scenes/NPC.tscn")
	var normal_npc: NPC = npc_scene.instantiate() as NPC
	add_child(normal_npc)

	assert_true(normal_npc.active_event == null, "Normal NPC has no active event")

	var result = anomalies_mgr.evaluate_and_trigger(1, 0, 1, {
		"npc": normal_npc,
		"event": "npc_spawned",
		"has_event": false
	})
	assert_true(result != null, "Normal NPC successfully triggered anomaly under debug_always_trigger")
	assert_true(anomalies_mgr.active_anomalies.size() == 1, "Anomaly is active for normal NPC")

	anomalies_mgr.resolve_all_anomalies()
	normal_npc.queue_free()
	anomalies_mgr.queue_free()
