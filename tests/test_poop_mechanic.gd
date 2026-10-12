extends Node

const ToiletDoor = preload("res://scripts/map/ToiletDoor.gd")
const PoopItem = preload("res://scripts/PoopItem.gd")

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
	print("=== RUNNING CHEMICAL TOILET, POOP, AND CLIENT DEATH TEST SUITE ===")

	await test_chemical_toilet_and_door()
	await test_poop_item_creation_and_toilet_dispense()
	test_completo_poop_layer_and_visuals()
	test_poop_interaction_with_completo()
	await test_npc_eats_poop_hotdog_and_dies()
	await test_robber_eats_poop_hotdog_and_dies()

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [tests_passed, tests_failed])
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func test_chemical_toilet_and_door() -> void:
	print("\n--- Test 1: Chemical Toilet Scene & Door Toggle ---")
	var toilet_scene = load("res://scenes/map/ChemicalToilet.tscn")
	assert_true(toilet_scene != null, "ChemicalToilet.tscn loads successfully")
	var cabin = toilet_scene.instantiate()
	add_child(cabin)

	var door = cabin.get_node_or_null("Door") as ToiletDoor
	var toilet = cabin.get_node_or_null("Toilet") as ChemicalToilet

	assert_true(door != null, "Toilet door exists in cabin")
	assert_true(toilet != null, "Toilet station exists in cabin")

	# Door interaction
	var fake_player = Node3D.new()
	var door_prompt_closed = door.get_interaction_prompt(fake_player)
	assert_true("Abrir" in door_prompt_closed.get("text", ""), "Prompt shows open door when closed")

	door.interact(fake_player)
	assert_true(door.is_open, "Door is now open after interact")

	await get_tree().create_timer(0.4).timeout
	var door_prompt_open = door.get_interaction_prompt(fake_player)
	assert_true("Cerrar" in door_prompt_open.get("text", ""), "Prompt shows close door when open")

	fake_player.queue_free()
	cabin.queue_free()


func test_poop_item_creation_and_toilet_dispense() -> void:
	print("\n--- Test 2: Toilet Poop Dispensing & Poop Item ---")
	var cabin = load("res://scenes/map/ChemicalToilet.tscn").instantiate()
	add_child(cabin)
	var toilet = cabin.get_node("Toilet") as ChemicalToilet

	var fake_player = Node.new()
	fake_player.set_meta("held_item", null)
	var prompt = toilet.get_interaction_prompt(fake_player)
	assert_true("Hacer caca" in prompt.get("text", ""), "Toilet prompt allows pooping with empty hands")

	# Make poop
	var poop = toilet.make_poop(null) as PoopItem
	assert_true(poop != null, "Toilet instantiated a PoopItem")
	assert_true(poop.is_in_group("poop"), "Poop item is in 'poop' group")
	# Test picking up poop with Player
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)
	poop.interact(player)
	assert_true(player.held_item == poop, "Player is now holding the poop item")
	assert_true(poop.get_parent() == player.get_node("Camera3D/HoldPoint"), "Poop is parented to player HoldPoint")

	# Test dropping poop
	player._drop_held_item()
	assert_true(player.held_item == null, "Player held_item is null after drop")
	assert_true(poop.get_parent() != player.get_node("Camera3D/HoldPoint"), "Poop reparented back to world after drop")

	poop.queue_free()
	cabin.queue_free()
	fake_player.queue_free()
	player.queue_free()


func test_completo_poop_layer_and_visuals() -> void:
	print("\n--- Test 3: Completo Poop Layer Stacking & Naming ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate() as CompletoItem
	add_child(comp)

	assert_true(comp.poop_count == 0, "Initial poop_count is 0")
	assert_true(not comp.has_poop, "Initial has_poop is false")

	# Add sausage + palta + mayo + poop
	assert_true(comp.add_ingredient("sausage"), "Added sausage")
	assert_true(comp.add_ingredient("palta"), "Added palta")
	assert_true(comp.add_ingredient("mayo"), "Added mayo")
	assert_true(comp.add_ingredient("poop"), "Added poop as ingredient")

	assert_true(comp.poop_count == 1, "poop_count is 1")
	assert_true(comp.has_poop, "has_poop is true")
	assert_true(comp.get_layer_count() == 4, "Total layers is 4")
	assert_true(comp.layers.has("poop"), "Layers sequence contains poop")

	# Check visual mesh generated
	var container = comp.get_node("LayersContainer")
	assert_true(container != null and container.get_child_count() == 4, "4 visual layer meshes instantiated")

	var poop_mesh = container.get_child(3) as CSGBox3D
	assert_true(poop_mesh != null, "Poop visual mesh exists in sandwich stack")

	# Check display name
	var comp_name = comp.get_completo_name()
	assert_true("Caca" in comp_name, "Completo display name reflects poop ingredient: " + comp_name)

	# Check solo bun with poop
	var poop_bun = load("res://scenes/items/Completo.tscn").instantiate() as CompletoItem
	add_child(poop_bun)
	poop_bun.add_ingredient("poop")
	assert_true("Pan con Caca" in poop_bun.get_completo_name(), "Solo bun with poop is named 'Pan con Caca'")
	assert_true(poop_bun.is_valid_base(), "Pan con Caca is valid base food")

	comp.queue_free()
	poop_bun.queue_free()


func test_poop_interaction_with_completo() -> void:
	print("\n--- Test 4: Poop Item Applied To Held Completo & Toilet Direct Poop ---")
	var comp = load("res://scenes/items/Completo.tscn").instantiate() as CompletoItem
	add_child(comp)

	# 1. PoopItem applied to held Completo
	var poop = load("res://scenes/items/Poop.tscn").instantiate() as PoopItem
	add_child(poop)

	var fake_player = load("res://scenes/Player.tscn").instantiate()
	add_child(fake_player)
	fake_player.held_item = comp

	var prompt = poop.get_interaction_prompt(fake_player)
	assert_true("Añadir caca al Completo" in prompt.get("text", ""), "Prompt allows adding poop to held Completo")

	poop.interact(fake_player)
	assert_true(comp.has_poop, "Held completo now has poop")

	# 2. Chemical toilet direct poop onto held Completo
	var toilet_node = load("res://scenes/map/ChemicalToilet.tscn").instantiate()
	add_child(toilet_node)
	var toilet = toilet_node.get_node("Toilet") as ChemicalToilet

	var toilet_prompt = toilet.get_interaction_prompt(fake_player)
	assert_true("Defecar en el Completo" in toilet_prompt.get("text", ""), "Toilet prompt detects held Completo")

	toilet.interact(fake_player)
	assert_true(comp.poop_count == 2, "Completo now has 2x poop applied directly from toilet")

	comp.queue_free()
	toilet_node.queue_free()
	fake_player.queue_free()


func test_npc_eats_poop_hotdog_and_dies() -> void:
	print("\n--- Test 5: Client Eats Hotdog with Poop and Dies ---")
	var npc = load("res://scenes/NPC.tscn").instantiate() as NPC
	npc.spawn_pos = Vector3(0, 0, 0)
	npc.target_pos = Vector3(0, 0, 0)
	add_child(npc)

	# Set up NPC at counter waiting for order
	npc._arrive_at_counter()
	assert_true(npc.can_receive_item(), "NPC is ready to receive food")

	# Create a hotdog with poop
	var comp = load("res://scenes/items/Completo.tscn").instantiate() as CompletoItem
	add_child(comp)
	comp.add_ingredient("sausage")
	comp.add_ingredient("palta")
	comp.add_ingredient("mayo")
	comp.add_ingredient("poop")
	assert_true(comp.has_poop, "Hotdog has poop")

	# Give hotdog with poop to NPC
	npc.receive_item(comp)

	assert_true(npc.state == NPC.State.REACTING, "NPC entered REACTING state upon eating")
	assert_true("TIENE CACA" in npc.label.text or "CACA" in npc.label.text, "NPC immediately reacts to poop in food: " + npc.label.text)

	# Wait for fatal collapse (0.6s delay + 0.35s tween)
	await get_tree().create_timer(1.1).timeout

	assert_true("Muerto" in npc.label.text or "AGHHH" in npc.label.text, "NPC is dead: " + npc.label.text)
	assert_true(abs(npc.rotation_degrees.x - (-90.0)) < 5.0, "NPC rotated -90 deg flat on the floor (collapsed corpse)")
	assert_true(npc.position.y <= 0.35, "NPC collapsed to floor level Y: %f" % npc.position.y)

	npc.queue_free()


func test_robber_eats_poop_hotdog_and_dies() -> void:
	print("\n--- Test 6: Robber Eats Hotdog with Poop and Dies ---")
	var robber_scene = load("res://scenes/RobberNPC.tscn")
	if robber_scene == null:
		print("  [SKIP] RobberNPC.tscn not found, skipping")
		return

	var robber = robber_scene.instantiate()
	robber.spawn_pos = Vector3(0, 0, 0)
	robber.target_pos = Vector3(0, 0, 0)
	add_child(robber)

	robber._arrive_at_counter()
	assert_true(robber.can_receive_item(), "Robber is at counter waiting")

	var comp = load("res://scenes/items/Completo.tscn").instantiate() as CompletoItem
	add_child(comp)
	comp.add_ingredient("sausage")
	comp.add_ingredient("poop")

	robber.receive_item(comp)

	assert_true(robber._shot_cancelled, "Robber shot cancelled due to fatal poisoning")
	assert_true(robber.gun == null or not robber.gun.visible, "Robber gun hidden / dropped")

	await get_tree().create_timer(1.1).timeout

	assert_true("Muerto" in robber.label.text or "AGHHH" in robber.label.text, "Robber is dead: " + robber.label.text)
	assert_true(abs(robber.rotation_degrees.x - (-90.0)) < 5.0, "Robber collapsed dead on floor")

	robber.queue_free()

