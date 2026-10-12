extends Node

var tests_passed: int = 0
var tests_failed: int = 0

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		tests_passed += 1
		print("  [PASS] ", msg)
	else:
		tests_failed += 1
		printerr("  [FAIL] ", msg)


func _ready() -> void:
	print("=== RUNNING SINGLE ITEM PICKUP & STACK PREVENTION TEST SUITE ===")

	test_drop_and_pickup_other_item_does_not_stack_ground_item()
	test_interactable_direct_call_blocked_when_holding()
	test_pick_up_direct_blocked_when_holding()
	test_poop_and_completo_contextual_interactions_preserved()
	test_prompts_actionable_states()

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [tests_passed, tests_failed])
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func test_drop_and_pickup_other_item_does_not_stack_ground_item() -> void:
	print("\n--- Test 1: Drop hotdog, pick another hotdog, ensure ground hotdog cannot be picked/stacked ---")
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)

	var comp_scene = load("res://scenes/items/Completo.tscn")
	var hotdog1 = comp_scene.instantiate()
	var hotdog2 = comp_scene.instantiate()
	add_child(hotdog1)
	add_child(hotdog2)

	# 1. Grab hotdog1
	hotdog1.interact(player)
	assert_true(player.held_item == hotdog1, "Player picks up hotdog 1")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint has exactly 1 item (hotdog 1)")

	# 2. Drop hotdog1
	player._drop_held_item()
	assert_true(player.held_item == null, "Player held_item is null after dropping hotdog 1")
	assert_true(player.hold_point.get_child_count() == 0, "HoldPoint is empty after drop")
	assert_true(hotdog1.get_parent() != player.hold_point, "Hotdog 1 is no longer in HoldPoint")

	# 3. Pick up hotdog2
	hotdog2.interact(player)
	assert_true(player.held_item == hotdog2, "Player picks up hotdog 2")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint has exactly 1 item (hotdog 2)")

	# 4. Aim ray at hotdog1 on the ground and trigger interaction
	# Simulate ray colliding with hotdog1
	var mock_ray = player.get_node("Camera3D/RayCast3D")
	# Player attempts _handle_interact with hotdog1 as the target
	# Setup RayCast exception/target or directly test interact call under Player's logic
	hotdog1.interact(player)

	assert_true(player.held_item == hotdog2, "Player held_item remains hotdog 2")
	assert_true(hotdog1.get_parent() != player.hold_point, "Hotdog 1 was NOT picked up or added to HoldPoint")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint still has only 1 item (no stacking)")

	# 5. Drop hotdog2
	player._drop_held_item()
	assert_true(player.held_item == null, "Player held_item is null after drop")
	assert_true(player.hold_point.get_child_count() == 0, "HoldPoint is empty after dropping hotdog 2")

	# 6. Now that hands are empty, picking up hotdog1 works normally
	hotdog1.interact(player)
	assert_true(player.held_item == hotdog1, "Player can now pick up hotdog 1 with empty hands")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint contains hotdog 1")

	player._drop_held_item()
	hotdog1.queue_free()
	hotdog2.queue_free()
	player.queue_free()


func test_interactable_direct_call_blocked_when_holding() -> void:
	print("\n--- Test 2: Interactable.interact blocked when holding another item ---")
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)

	var drink = load("res://scenes/items/Drink.tscn").instantiate()
	var empanada = load("res://scenes/items/Empanada.tscn").instantiate()
	add_child(drink)
	add_child(empanada)

	drink.interact(player)
	assert_true(player.held_item == drink, "Player is holding Drink")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint has 1 item")

	# Try picking up Empanada while holding Drink
	empanada.interact(player)
	assert_true(player.held_item == drink, "Player still holds Drink")
	assert_true(empanada.get_parent() != player.hold_point, "Empanada NOT added to HoldPoint")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint still has 1 item only")

	player._drop_held_item()
	drink.queue_free()
	empanada.queue_free()
	player.queue_free()


func test_pick_up_direct_blocked_when_holding() -> void:
	print("\n--- Test 3: pick_up_direct blocked when holding item ---")
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)

	var sopaipilla = load("res://scenes/items/Sopaipilla.tscn").instantiate()
	var drink = load("res://scenes/items/Drink.tscn").instantiate()
	add_child(sopaipilla)
	add_child(drink)

	player.pick_up_direct(sopaipilla)
	assert_true(player.held_item == sopaipilla, "Player holds Sopaipilla")

	# Attempt pick_up_direct with Drink
	player.pick_up_direct(drink)
	assert_true(player.held_item == sopaipilla, "Player still holds Sopaipilla")
	assert_true(drink.get_parent() != player.hold_point, "Drink was not attached to HoldPoint")

	player._drop_held_item()
	sopaipilla.queue_free()
	drink.queue_free()
	player.queue_free()


func test_poop_and_completo_contextual_interactions_preserved() -> void:
	print("\n--- Test 4: Contextual interactions (poop on hotdog) preserved ---")
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)

	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	var poop = load("res://scenes/items/Poop.tscn").instantiate()
	add_child(comp)
	add_child(poop)

	# 1. Player holds poop, interacts with Completo on the ground
	poop.interact(player)
	assert_true(player.held_item == poop, "Player holds poop")

	# Interact with Completo on ground
	comp.interact(player)
	assert_true(comp.has_poop, "Poop smeared on Completo on the ground")
	assert_true(player.held_item == null, "Poop consumed from player hands")
	assert_true(comp.get_parent() != player.hold_point, "Ground Completo was NOT picked up into hands")

	# 2. Player holds Completo, interacts with new Poop on the ground
	comp.interact(player)
	assert_true(player.held_item == comp, "Player picked up Completo")

	var poop2 = load("res://scenes/items/Poop.tscn").instantiate()
	add_child(poop2)
	poop2.interact(player)
	assert_true(comp.poop_count == 2, "Second poop added to held Completo")
	assert_true(player.held_item == comp, "Player still holds Completo")
	assert_true(player.hold_point.get_child_count() == 1, "HoldPoint has only the Completo (no stacked poop item)")

	player._drop_held_item()
	comp.queue_free()
	player.queue_free()


func test_prompts_actionable_states() -> void:
	print("\n--- Test 5: Prompts actionable states ---")
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)

	var drink = load("res://scenes/items/Drink.tscn").instantiate()
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(drink)
	add_child(comp)

	# Empty hands
	var prompt_drink_empty = drink.get_interaction_prompt(player)
	assert_true(prompt_drink_empty.get("actionable", false) == true, "Drink prompt is actionable with empty hands")

	var prompt_comp_empty = comp.get_interaction_prompt(player)
	assert_true(prompt_comp_empty.get("actionable", false) == true, "Completo prompt is actionable with empty hands")

	# Holding Drink
	drink.interact(player)
	var prompt_comp_holding = comp.get_interaction_prompt(player)
	assert_true(prompt_comp_holding.get("actionable", true) == false, "Completo prompt is NOT actionable when holding Drink")

	var prompt_drink_holding = drink.get_interaction_prompt(player)
	assert_true(prompt_drink_holding.get("actionable", true) == false, "Drink prompt is NOT actionable when hands are full")

	player._drop_held_item()
	drink.queue_free()
	comp.queue_free()
	player.queue_free()
