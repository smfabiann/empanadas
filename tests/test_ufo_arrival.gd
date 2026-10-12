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
	print("=== RUNNING DRAMATIC UFO ARRIVAL & LEVITATION TEST SUITE ===")
	test_ufo_scene_structure()
	test_ufo_dramatic_entrance_physics()
	test_ufo_departure()

	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [tests_passed, tests_failed])
	if tests_failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

func test_ufo_scene_structure() -> void:
	print("\n--- Test 1: UFO Scene Structure & Components ---")
	var scene: PackedScene = load("res://scenes/events/static/UfoNPC.tscn")
	assert_true(scene != null, "UfoNPC.tscn loaded successfully")

	var ufo: UfoNPC = scene.instantiate() as UfoNPC
	assert_true(ufo != null, "UfoNPC instantiated successfully")

	ufo.spawn_pos = Vector3(-0.43, 0.2, -11.0)
	ufo.target_pos = Vector3(-0.43, 0.2, -4.5)
	ufo.exit_pos = Vector3(-0.43, 0.2, -11.0)
	add_child(ufo)

	assert_true(ufo.ship_pivot != null, "ShipPivot exists")
	assert_true(ufo.body_mesh != null, "BodyMesh is resolved")
	assert_true(ufo.head != null, "Head is resolved")
	assert_true(ufo.saucer_rim != null, "SaucerRim exists")
	assert_true(ufo.tractor_beam != null, "TractorBeam SpotLight3D exists")
	assert_true(ufo.anim_player != null, "AnimationPlayer exists")
	assert_true(ufo.anim_player.has_animation("ufo_pulse"), "AnimationPlayer has 'ufo_pulse' animation")

	# Check initial sky altitude & hidden state
	assert_true(ufo.global_position.y >= ufo.target_pos.y + ufo.far_sky_height, "UFO starts elevated at sky emergence position (Y = %.2f)" % ufo.global_position.y)
	assert_true(not ufo.visible, "UFO is initially hidden (visible=false) during pre-rumble")
	assert_true(ufo.collision_mask == 0, "UFO collision_mask is 0 (does not collide with street obstacles)")
	assert_true(ufo.current_phase == UfoNPC.ApproachPhase.PRE_RUMBLE, "UFO starts in PRE_RUMBLE phase")

	ufo.queue_free()

func test_ufo_dramatic_entrance_physics() -> void:
	print("\n--- Test 2: Dramatic Entrance Physics & Suspense Timing ---")
	var scene: PackedScene = load("res://scenes/events/static/UfoNPC.tscn")
	var ufo: UfoNPC = scene.instantiate() as UfoNPC

	ufo.spawn_pos = Vector3(-0.43, 0.2, -11.0)
	ufo.target_pos = Vector3(-0.43, 0.2, -4.5)
	ufo.exit_pos = Vector3(-0.43, 0.2, -11.0)
	ufo.rumble_duration = 0.2
	ufo.hyper_flash_duration = 0.1
	ufo.suspense_duration = 0.2
	add_child(ufo)

	var start_pos: Vector3 = ufo.global_position

	# 1. Step through rumble (6 steps = 0.1s < 0.2s) -> ship must be hidden
	for i in range(6):
		ufo._physics_process(1.0 / 60.0)
	assert_true(not ufo.visible, "UFO remains hidden during PRE_RUMBLE")
	assert_true(ufo.current_phase == UfoNPC.ApproachPhase.PRE_RUMBLE, "UFO is still in PRE_RUMBLE")

	# 2. Step past rumble into flash & suspense (15 more steps = 0.25s)
	# At t = 0.35s total, rumble ended (0.2s) and hyper flash (0.1s) transitioned to suspense (0.2s)
	for i in range(15):
		ufo._physics_process(1.0 / 60.0)
	assert_true(ufo.current_phase == UfoNPC.ApproachPhase.SUSPENSE_PAUSE or ufo.current_phase == UfoNPC.ApproachPhase.HYPER_FLASH, "UFO entered suspense pause after flash")
	assert_true(not ufo.visible, "UFO is STILL HIDDEN during suspense pause before emergence")

	# 3. Step past suspense (18 more steps = 0.3s) -> enters FAR_EMERGENCE and SKY_CRUISE
	for i in range(18):
		ufo._physics_process(1.0 / 60.0)
	assert_true(ufo.visible, "UFO is now visible upon far emergence")
	assert_true(ufo.current_phase == UfoNPC.ApproachPhase.FAR_EMERGENCE or ufo.current_phase == UfoNPC.ApproachPhase.SKY_CRUISE, "UFO emerged in far sky and entered flight")

	# 4. Step through sky cruise
	for i in range(90):
		ufo._physics_process(1.0 / 60.0)

	assert_true(ufo.global_position.z > start_pos.z, "UFO moved forward toward shop (Z: %.2f > %.2f)" % [ufo.global_position.z, start_pos.z])
	assert_true(ufo.state == NPC.State.APPROACHING, "UFO remains in APPROACHING state during flight")
	# Check window line of sight altitude
	assert_true(ufo.global_position.y >= 1.5 and ufo.global_position.y <= 4.5, "UFO altitude (Y=%.2f) remains calibrated for shop window line-of-sight" % ufo.global_position.y)

	# Check local bobbing effect on ShipPivot
	assert_true(abs(ufo.ship_pivot.position.y) > 0.0 or abs(ufo.ship_pivot.rotation.x) > 0.0, "ShipPivot has organic hover bobbing/tilting")

	ufo.queue_free()

func test_ufo_departure() -> void:
	print("\n--- Test 4: UFO Space Departure ---")
	var scene: PackedScene = load("res://scenes/events/static/UfoNPC.tscn")
	var ufo: UfoNPC = scene.instantiate() as UfoNPC

	ufo.spawn_pos = Vector3(-0.43, 0.2, -11.0)
	ufo.target_pos = Vector3(-0.43, 0.2, -4.5)
	ufo.exit_pos = Vector3(-0.43, 0.2, -11.0)
	add_child(ufo)

	ufo.state = NPC.State.WAITING
	ufo.is_at_counter = true

	# Trigger departure
	ufo._start_leaving()
	assert_true(ufo.state == NPC.State.LEAVING, "UFO switched to LEAVING state")
	assert_true(not ufo.is_at_counter, "UFO is no longer at counter")
	assert_true(ufo._departure_tween != null and ufo._departure_tween.is_valid(), "Departure tween created for space blast-off")

	ufo.queue_free()
