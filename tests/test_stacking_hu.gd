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
	print("=== RUNNING STACKING AND MULTI-LAYER HU TEST SUITE ===")
	
	test_initial_bun()
	test_repeated_layer_stacking()
	test_arbitrary_sequence()
	test_visual_volume_and_movement()
	test_ingredient_station_stacking()
	test_npc_order_validation()
	
	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [tests_passed, tests_failed])
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_initial_bun() -> void:
	print("\n--- Test 1: Initial Bun ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(comp)
	
	assert_true(comp.has_bun, "Active bun starts with has_bun=true")
	assert_true(comp.sausage_count == 0, "Initial sausage_count is 0")
	assert_true(comp.palta_count == 0, "Initial palta_count is 0")
	assert_true(comp.mayo_count == 0, "Initial mayo_count is 0")
	assert_true(comp.ketchup_count == 0, "Initial ketchup_count is 0")
	assert_true(not comp.is_valid_base(), "Initial bun without sausage is not valid base")
	assert_true(comp.get_completo_name() == "Pan de Completo (Solo)", "Correct name for solo bun")
	comp.queue_free()

func test_repeated_layer_stacking() -> void:
	print("\n--- Test 2: Repeated Layer Stacking (Mayo on Mayo, Palta on Palta, Sausage on Sausage) ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(comp)
	
	# Add double sausage
	assert_true(comp.add_ingredient("sausage"), "Added 1st sausage")
	assert_true(comp.sausage_count == 1, "sausage_count is 1")
	assert_true(comp.add_ingredient("sausage"), "Added 2nd sausage (sausage on sausage)")
	assert_true(comp.sausage_count == 2, "sausage_count increments to 2")
	
	# Add double palta
	assert_true(comp.add_ingredient("palta"), "Added 1st palta")
	assert_true(comp.palta_count == 1, "palta_count is 1")
	assert_true(comp.add_ingredient("palta"), "Added 2nd palta (palta on palta)")
	assert_true(comp.palta_count == 2, "palta_count increments to 2")
	
	# Add double mayo
	assert_true(comp.add_ingredient("mayo"), "Added 1st mayo")
	assert_true(comp.mayo_count == 1, "mayo_count is 1")
	assert_true(comp.add_ingredient("mayo"), "Added 2nd mayo (mayo on mayo)")
	assert_true(comp.mayo_count == 2, "mayo_count increments to 2")
	
	# Verify layers sequence and count
	assert_true(comp.get_layer_count() == 6, "Total layers count is 6")
	assert_true(comp.get_layers() == ["sausage", "sausage", "palta", "palta", "mayo", "mayo"], "Layers match exact order")
	
	# Verify visual nodes and cumulative vertical offset
	var container = comp.get_node("LayersContainer")
	assert_true(container != null, "LayersContainer exists")
	assert_true(container.get_child_count() == 6, "6 visual layer meshes instantiated")
	
	var children = container.get_children()
	var prev_top_y: float = comp.BASE_Y
	var all_offsets_valid: bool = true
	var no_z_fighting: bool = true
	
	for i in range(children.size()):
		var layer_node = children[i] as CSGBox3D
		var pos_y: float = layer_node.position.y
		var thickness: float = layer_node.size.y
		var bottom_y: float = pos_y - (thickness * 0.5)
		var top_y: float = pos_y + (thickness * 0.5)
		
		# Bounding bottom must be >= previous top (cumulative vertical offset)
		if bottom_y < prev_top_y - 0.0001:
			no_z_fighting = false
		if i > 0 and pos_y <= children[i - 1].position.y:
			all_offsets_valid = false
		prev_top_y = top_y
	
	assert_true(all_offsets_valid, "Every layer has cumulative vertical offset (strictly higher position.y)")
	assert_true(no_z_fighting, "Every layer renders above previous layer without Z-fighting")
	
	# Verify display name reflects extras
	var name_str: String = comp.get_completo_name()
	assert_true("Completo Italiano" in name_str, "Base name is Completo Italiano")
	assert_true("2x Vienesa" in name_str, "Shows 2x Vienesa in name: " + name_str)
	assert_true("2x Palta" in name_str, "Shows 2x Palta in name")
	assert_true("2x Mayo" in name_str, "Shows 2x Mayo in name")
	
	comp.queue_free()

func test_arbitrary_sequence() -> void:
	print("\n--- Test 3: Arbitrary Sequence (Mayo first, then Palta, then Sausage) ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(comp)
	
	# Sequence: Mayo first, Palta second, Sausage third
	assert_true(comp.add_ingredient("mayo"), "Allowed mayo first")
	assert_true(comp.add_ingredient("palta"), "Allowed palta second")
	assert_true(comp.add_ingredient("sausage"), "Allowed sausage third")
	assert_true(comp.add_ingredient("mayo"), "Allowed second mayo on top")
	
	assert_true(comp.get_layers() == ["mayo", "palta", "sausage", "mayo"], "Layers stored in reverse/custom sequence")
	assert_true(comp.is_valid_base(), "Hot dog has sausage and bun, valid base")
	
	# Verify mayo is at bottom, palta above mayo, sausage above palta, 2nd mayo at top
	var container = comp.get_node("LayersContainer")
	var children = container.get_children()
	assert_true(children[0].position.y < children[1].position.y, "Mayo (layer 0) is below Palta (layer 1)")
	assert_true(children[1].position.y < children[2].position.y, "Palta (layer 1) is below Sausage (layer 2)")
	assert_true(children[2].position.y < children[3].position.y, "Sausage (layer 2) is below 2nd Mayo (layer 3)")
	
	comp.queue_free()

func test_visual_volume_and_movement() -> void:
	print("\n--- Test 4: Visual Silhouette and Movement Propagation ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(comp)
	
	for i in range(4):
		comp.add_ingredient("sausage")
		comp.add_ingredient("palta")
	
	# Stack of 8 layers should have significant height
	assert_true(comp.current_stack_height > 0.35, "Total stack height reflects volume (> 0.35m): %f" % comp.current_stack_height)
	assert_true(comp.label.position.y > 0.45, "Label adjusted above stacked ingredients: %f" % comp.label.position.y)
	
	# Test moving the Completo moves all layers
	comp.global_position = Vector3(10.0, 5.0, -10.0)
	var container = comp.get_node("LayersContainer")
	for child in container.get_children():
		var child_global_y = child.global_position.y
		assert_true(child_global_y > 5.0, "Layer mesh global position reflects Completo movement")
	
	comp.queue_free()

func test_ingredient_station_stacking() -> void:
	print("\n--- Test 5: IngredientStation Stacking Prompts and Interaction ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(comp)
	
	var fake_player = load("res://scenes/Player.tscn").instantiate()
	add_child(fake_player)
	fake_player.held_item = comp
	
	var station_sausage = IngredientStation.new()
	station_sausage.station_type = "sausage"
	add_child(station_sausage)
	
	# First prompt
	var prompt1 = station_sausage.get_interaction_prompt(fake_player)
	assert_true(prompt1["actionable"] == true, "Station allows first sausage")
	station_sausage.interact(fake_player)
	assert_true(comp.sausage_count == 1, "First sausage added via station")
	
	# Second prompt (repeated)
	var prompt2 = station_sausage.get_interaction_prompt(fake_player)
	assert_true(prompt2["actionable"] == true, "Station allows second sausage (repeated layer!)")
	station_sausage.interact(fake_player)
	assert_true(comp.sausage_count == 2, "Second sausage added via station")
	
	# Station palta
	var station_palta = IngredientStation.new()
	station_palta.station_type = "palta"
	add_child(station_palta)
	
	var p_palta1 = station_palta.get_interaction_prompt(fake_player)
	assert_true(p_palta1["actionable"] == true, "Station allows first palta")
	station_palta.interact(fake_player)
	assert_true(comp.palta_count == 1, "First palta added")
	
	var p_palta2 = station_palta.get_interaction_prompt(fake_player)
	assert_true(p_palta2["actionable"] == true, "Station allows second palta")
	station_palta.interact(fake_player)
	assert_true(comp.palta_count == 2, "Second palta added")
	
	station_sausage.queue_free()
	station_palta.queue_free()
	comp.queue_free()
	fake_player.queue_free()

func test_npc_order_validation() -> void:
	print("\n--- Test 6: NPC Order Validation and Acceptance ---")
	
	# Setup NPC
	var npc = load("res://scenes/NPC.tscn").instantiate()
	add_child(npc)
	npc._arrive_at_counter()
	
	# Set order to Completo Italiano: req_sausage=true, req_palta=true, req_mayo=true, req_ketchup=false
	npc.order_req_sausage = true
	npc.order_req_palta = true
	npc.order_req_mayo = true
	npc.order_req_ketchup = false
	npc.requested_item = ItemData.new()
	npc.requested_item.id = "completo"
	
	# Case 6a: Standard single-layer Italiano
	var c_std = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_std)
	c_std.add_ingredient("sausage")
	c_std.add_ingredient("palta")
	c_std.add_ingredient("mayo")
	assert_true(c_std.matches_order(true, true, true, false), "Standard Italiano matches order")
	c_std.queue_free()
	
	# Case 6b: Extra duplicate layers (2 sausages, 3 paltas, 2 mayos)
	var c_dup = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_dup)
	c_dup.add_ingredient("sausage")
	c_dup.add_ingredient("sausage")
	c_dup.add_ingredient("palta")
	c_dup.add_ingredient("palta")
	c_dup.add_ingredient("palta")
	c_dup.add_ingredient("mayo")
	c_dup.add_ingredient("mayo")
	assert_true(c_dup.matches_order(true, true, true, false), "Italiano with extra duplicate layers matches order")
	
	# Case 6c: Reverse order with extra layers (mayo, mayo, palta, sausage, sausage)
	var c_rev = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_rev)
	c_rev.add_ingredient("mayo")
	c_rev.add_ingredient("mayo")
	c_rev.add_ingredient("palta")
	c_rev.add_ingredient("sausage")
	c_rev.add_ingredient("sausage")
	assert_true(c_rev.matches_order(true, true, true, false), "Italiano in reversed layering order matches order")
	c_rev.queue_free()
	
	# Case 6d: Missing requested ingredient (missing mayo)
	var c_no_mayo = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_no_mayo)
	c_no_mayo.add_ingredient("sausage")
	c_no_mayo.add_ingredient("palta")
	assert_true(not c_no_mayo.matches_order(true, true, true, false), "Italiano missing mayo does NOT match order")
	assert_true(c_no_mayo.get_match_error(true, true, true, false) == "¡Le falta la mayonesa!", "Error string specifies missing mayo")
	c_no_mayo.queue_free()
	
	# Case 6e: Missing mandatory base (no sausage)
	var c_no_sausage = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_no_sausage)
	c_no_sausage.add_ingredient("palta")
	c_no_sausage.add_ingredient("mayo")
	assert_true(not c_no_sausage.is_valid_base(), "Hot dog without sausage is NOT valid base")
	assert_true(not c_no_sausage.matches_order(true, true, true, false), "Hot dog without sausage does NOT match order")
	assert_true(c_no_sausage.get_match_error(true, true, true, false) == "¡Le falta la vienesa obligatoria!", "Error string specifies missing sausage")
	c_no_sausage.queue_free()
	
	# Case 6f: Missing bun
	var c_no_bun = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_no_bun)
	c_no_bun.has_bun = false
	c_no_bun.add_ingredient("sausage")
	c_no_bun.add_ingredient("palta")
	c_no_bun.add_ingredient("mayo")
	assert_true(not c_no_bun.is_valid_base(), "Hot dog without bun is NOT valid base")
	c_no_bun.queue_free()
	
	# Case 6g: Unrequested ingredient (Italiano with added ketchup)
	var c_unreq = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_unreq)
	c_unreq.add_ingredient("sausage")
	c_unreq.add_ingredient("palta")
	c_unreq.add_ingredient("mayo")
	c_unreq.add_ingredient("ketchup")
	assert_true(not c_unreq.matches_order(true, true, true, false), "Italiano with unrequested ketchup does NOT match order")
	assert_true(c_unreq.get_match_error(true, true, true, false) == "¡No pedí con kétchup!", "Error string specifies unrequested ketchup")
	c_unreq.queue_free()
	
	# Case 6h: Deliver the duplicate-layered Italiano to NPC and verify acceptance!
	npc._is_order_resolved = false
	npc.state = NPC.State.WAITING
	npc.is_at_counter = true
	var orig_served = GameManager.npcs_served
	npc.receive_item(c_dup) # c_dup is freed inside receive_item
	assert_true("¡Buenísimo completo!" in npc.label.text, "NPC accepted duplicate-layered hot dog with praise")
	assert_true(GameManager.npcs_served == orig_served + 1, "GameManager registered successful delivery")
	
	# Case 6i: Deliver an invalid hot dog (missing palta) to another NPC and verify rejection!
	var npc2 = load("res://scenes/NPC.tscn").instantiate()
	add_child(npc2)
	npc2._arrive_at_counter()
	npc2.order_req_sausage = true
	npc2.order_req_palta = true
	npc2.order_req_mayo = true
	npc2.order_req_ketchup = false
	npc2.requested_item = ItemData.new()
	npc2.requested_item.id = "completo"
	
	var c_bad = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(c_bad)
	c_bad.add_ingredient("sausage")
	c_bad.add_ingredient("mayo")
	
	var orig_served_corr = GameManager.npcs_served_correctly
	npc2.receive_item(c_bad)
	assert_true("¡Le falta la palta!" in npc2.label.text, "NPC rejected delivery showing dissatisfaction with missing ingredient")
	assert_true(GameManager.npcs_served_correctly == orig_served_corr, "GameManager did not increment correctly served counter")
	
	npc.queue_free()
	npc2.queue_free()
