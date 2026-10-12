extends Node
## Automated test suite for Bed Sleeping mechanic (Godot 4.7)

var _passed_tests: int = 0
var _failed_tests: int = 0

func _assert_test(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] %s" % message)
		_passed_tests += 1
	else:
		print("  [FAIL] %s" % message)
		_failed_tests += 1


func _ready() -> void:
	print("\n=== RUNNING BED SLEEPING MECHANIC TEST SUITE ===")
	_run_tests()


func _run_tests() -> void:
	var main_scene: Node = load("res://scenes/Main.tscn").instantiate()
	add_child(main_scene)

	# Give a frame for _ready
	await get_tree().process_frame

	var bed: BedInteraction = main_scene.get_node_or_null("Map/Bed") as BedInteraction
	var player: CharacterBody3D = main_scene.get_node_or_null("Player") as CharacterBody3D
	var ui: CanvasLayer = main_scene.get_node_or_null("UI") as CanvasLayer

	print("\n--- Test 1: Node Setup & Initial States ---")
	_assert_test(bed != null, "Bed exists in scene")
	_assert_test(player != null, "Player exists in scene")
	_assert_test(ui != null, "UI exists in scene")
	_assert_test(bed is BedInteraction, "Bed script is BedInteraction")
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt") != null, "Bed has PromptLayer/Prompt panel")
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt").visible == false, "Prompt panel is hidden initially")
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt/Label").text == "Press E to sleep", "Prompt label is in English ('Press E to sleep')")
	_assert_test(main_scene is MainScene, "Root scene node has MainScene script")
	_assert_test("max_clients_per_day" in main_scene, "Main scene exposes max_clients_per_day in Inspector")
	
	# Test changing limit in Inspector
	main_scene.max_clients_per_day = 12
	_assert_test(GameManager.max_clients_per_day == 12, "Setting max_clients_per_day on Main updates GameManager")
	var spawner_node = main_scene.get_node_or_null("NPCSpawner")
	_assert_test(spawner_node != null and spawner_node.max_clients_per_day == 12, "Setting max_clients_per_day on Main syncs with NPCSpawner")
	main_scene.max_clients_per_day = 8

	print("\n--- Test 2: Prompt Does NOT Show During Active Day ---")
	GameManager.game_active = true
	GameManager.day_active = true
	GameManager.is_game_won = false
	GameManager.is_sleeping = false
	GameManager.clients_attended_today = 0
	GameManager.max_clients_per_day = 5
	_assert_test(not GameManager.can_sleep(), "GameManager.can_sleep() is false during day")

	# Move player directly onto the bed
	player.global_position = bed.global_position
	bed._refresh_prompt()
	_assert_test(bed._is_near_bed(), "Player is detected near bed")
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt").visible == false, "Prompt remains hidden while day is active even near bed")

	print("\n--- Test 3: Prompt Does NOT Show When Far Even If Shift Ended ---")
	# End day shift
	GameManager.clients_attended_today = 5
	GameManager.end_day()
	_assert_test(not GameManager.day_active, "Day is no longer active after end_day()")
	_assert_test(GameManager.can_sleep(), "GameManager.can_sleep() is true after quota completed")

	# Move player far away
	player.global_position = Vector3(100, 0, 100)
	bed._player_inside = false
	bed._refresh_prompt()
	_assert_test(not bed._is_near_bed(), "Player is NOT near bed when far away")
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt").visible == false, "Prompt is hidden when player is far away")

	print("\n--- Test 4: Prompt Appears When Near AND Can Sleep ---")
	player.global_position = bed.global_position
	bed._refresh_prompt()
	_assert_test(bed._is_near_bed(), "Player is near bed")
	_assert_test(bed._can_sleep(), "Bed detects can_sleep() is true")
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt").visible == true, "Prompt panel is VISIBLE when near bed and can sleep")
	_assert_test(GameManager.can_player_act(), "Player can still act/move after shift ends to reach the bed")

	print("\n--- Test 5: No DayEndPanel Popup Menu On Shift End ---")
	var day_end_panel: Control = ui.get_node_or_null("HUD/DayEndPanel") as Control
	_assert_test(day_end_panel != null, "DayEndPanel node exists in HUD")
	_assert_test(day_end_panel.visible == false, "DayEndPanel popup menu is NOT shown (replaced by bed navigation)")
	_assert_test(ui.day_banner != null and ui.day_banner.text.contains("SHIFT COMPLETE"), "Shift completed banner is displayed in English")

	# Check subtle morning transition
	var day_cycle = get_tree().root.get_node_or_null("DayCycle")
	_assert_test(day_cycle != null, "DayCycle singleton exists")
	_assert_test(day_cycle._tween != null and day_cycle._tween.is_running(), "DayCycle is transitioning environment toward morning subtly")
	_assert_test(day_cycle._world_env.environment.fog_enabled == false, "Horrible terrain fog is NOT enabled (fog_enabled == false)")

	# Wait a short duration to verify morning properties are progressing smoothly
	await get_tree().create_timer(0.6).timeout
	_assert_test(day_cycle._sun != null and day_cycle._sun.light_energy > 0.05, "Sunlight energy is increasing smoothly for morning (sun rising)")
	_assert_test(day_cycle._world_env.environment.ambient_light_energy > 0.4, "Ambient light energy is brightening for morning")
	_assert_test(day_cycle._world_env.environment.background_energy_multiplier > 0.33, "Sky background energy is brightening for morning")

	print("\n--- Test 6: Sleeping Advances To Next Day & Restores Night ---")
	var current_day_before = GameManager.current_day
	bed._sleep()
	# Wait for sleep tween (0.4s fade in + 0.3s hold + 0.6s fade out = 1.3s)
	await get_tree().create_timer(1.4).timeout

	_assert_test(GameManager.current_day == current_day_before + 1, "GameManager advanced to Day %d" % GameManager.current_day)
	_assert_test(GameManager.day_active == true, "New day is active")
	_assert_test(GameManager.clients_attended_today == 0, "Clients attended today reset to 0")
	_assert_test(day_cycle._sun != null and day_cycle._sun.light_energy < 0.05, "Environment restored to dark night upon sleeping")
	_assert_test(is_equal_approx(day_cycle._world_env.environment.ambient_light_energy, 0.4), "Ambient energy restored to previous night value (0.4)")
	_assert_test(is_equal_approx(day_cycle._world_env.environment.background_energy_multiplier, 0.33), "Sky background energy restored to previous night value (0.33)")
	_assert_test(day_cycle._world_env.environment.fog_enabled == false, "Fog remains disabled after night restoration")
	bed._refresh_prompt()
	_assert_test(bed.get_node_or_null("PromptLayer/Prompt").visible == false, "Prompt hides automatically on new day start")

	print("\n--- Test 7: Final Day Sleeping Triggers Victory ---")
	GameManager.current_day = GameManager.max_days # Day 3
	GameManager.clients_attended_today = GameManager.max_clients_per_day
	GameManager.end_day()
	_assert_test(GameManager.is_final_day(), "GameManager reports is_final_day() == true")
	_assert_test(GameManager.can_sleep(), "Player can sleep on final day")

	bed._sleep()
	await get_tree().create_timer(1.4).timeout

	_assert_test(GameManager.is_game_won == true, "Sleeping on final day triggers victory (is_game_won == true)")
	var victory_panel: Control = ui.get_node_or_null("HUD/VictoryPanel") as Control
	_assert_test(victory_panel != null and victory_panel.visible == true, "VictoryPanel is displayed")
	var victory_title: Label = ui.get_node_or_null("HUD/VictoryPanel/VBoxContainer/VictoryTitle") as Label
	_assert_test(victory_title != null and victory_title.text.contains("YOU WON"), "Victory title is in English: '%s'" % victory_title.text)

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [_passed_tests, _failed_tests])

	main_scene.queue_free()
	get_tree().quit(1 if _failed_tests > 0 else 0)
