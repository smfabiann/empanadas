extends Node
## Suite: narrativa de 3 noches (plata para escapar), olla y completos mojados,
## y los eventos del Talquino, el Estafador del chip de perro y el Rappi.

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
	print("=== RUNNING ESCAPE ECONOMY, OLLA Y EVENTOS TEST SUITE ===")
	test_money_format_and_payment()
	test_economy_and_endings()
	test_intro_gates_player_and_spawn()
	test_completo_mojado()
	await test_olla_station()
	test_event_registration_and_schedule()
	await test_talquino_event()
	await test_scammer_event()
	await test_rappi_event()

	GameManager.reset_game()
	print("\n=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [tests_passed, tests_failed])
	get_tree().quit(1 if tests_failed > 0 else 0)


func _reset() -> void:
	GameManager.set_economy(GameManager.DEFAULT_STARTING_SAVINGS, GameManager.DEFAULT_ESCAPE_GOAL)
	GameManager.reset_game()
	GameManager.max_days = 3


func _make_completo(palta: bool, mayo: bool, ketchup: bool, mojado: bool = false) -> Node:
	var comp = load("res://scenes/items/Completo.tscn").instantiate()
	add_child(comp)
	comp.add_ingredient("sausage")
	if palta: comp.add_ingredient("palta")
	if mayo: comp.add_ingredient("mayo")
	if ketchup: comp.add_ingredient("ketchup")
	if mojado: comp.mojar()
	return comp


func _spawn_npc_with_event(event: NPCEvent) -> NPC:
	var npc: NPC = load("res://scenes/NPC.tscn").instantiate()
	npc.spawn_pos = Vector3(0, 0, -10)
	npc.target_pos = Vector3(0, 0, -4)
	npc.exit_pos = Vector3(0, 0, -10)
	if event:
		npc.assign_event(event)
	add_child(npc)
	npc.set_physics_process(false)
	npc._arrive_at_counter()
	return npc


func test_money_format_and_payment() -> void:
	print("\n--- Test 1: Formato de plata y pago de completos ---")
	assert_true(GameManager.format_money(50000) == "50.000", "format_money(50000) == '50.000'")
	assert_true(GameManager.format_money(3500) == "3.500", "format_money(3500) == '3.500'")
	assert_true(GameManager.format_money(800) == "800", "format_money(800) == '800'")
	assert_true(GameManager.format_money(1234567) == "1.234.567", "format_money con millones")
	assert_true(GameManager.calculate_completo_payment(0.0) == 3000, "Completo sin propina paga $3.000")
	assert_true(GameManager.calculate_completo_payment(1.0) == 4000, "Atender al instante suma $1.000 de propina")
	assert_true(GameManager.calculate_completo_payment(0.0, true) == 3500, "Completo mojado paga $500 extra")


func test_economy_and_endings() -> void:
	print("\n--- Test 2: Ahorros, meta y finales ---")
	_reset()
	assert_true(GameManager.savings == 20000, "La partida parte con $20.000 ahorrados")
	assert_true(GameManager.get_money_missing() == 30000, "Faltan $30.000 para el pasaje")
	GameManager.earn_money(4000, "test")
	assert_true(GameManager.savings == 24000 and GameManager.earned_today == 4000, "earn_money suma a ahorros y a lo ganado hoy")
	GameManager.lose_money(100000, "test")
	assert_true(GameManager.savings == 0, "lose_money nunca deja los ahorros bajo 0")

	# Final sin plata: derrota narrativa
	_reset()
	var reasons: Array = []
	var cb := func(r: String): reasons.append(r)
	GameManager.game_over.connect(cb)
	GameManager.current_day = 3
	GameManager.day_active = false
	GameManager.start_next_day()
	assert_true(not GameManager.is_game_won, "Sin la plata del pasaje no se gana al terminar la última noche")
	assert_true(not GameManager.game_active, "Sin la plata la partida termina (game over)")
	assert_true(reasons.size() == 1 and String(reasons[0]).begins_with("No juntaste"), "El motivo explica que faltó plata")
	GameManager.game_over.disconnect(cb)

	# Final con plata: escape
	_reset()
	var won: Array = []
	var cb2 := func(stats: Dictionary): won.append(stats)
	GameManager.game_won.connect(cb2)
	GameManager.earn_money(30000, "test")
	GameManager.current_day = 3
	GameManager.day_active = false
	GameManager.start_next_day()
	assert_true(GameManager.is_game_won, "Con la plata del pasaje se escapa al terminar la última noche")
	assert_true(won.size() == 1 and int(won[0].get("savings", 0)) == 50000, "Las estadísticas de victoria incluyen la plata juntada")
	GameManager.game_won.disconnect(cb2)
	_reset()


func test_intro_gates_player_and_spawn() -> void:
	print("\n--- Test 3: Intro narrativa bloquea al jugador y a los clientes ---")
	_reset()
	GameManager.intro_active = true
	assert_true(not GameManager.can_player_act(), "Durante la intro el jugador no puede actuar")
	assert_true(not GameManager.can_spawn_npc(), "Durante la intro no llegan clientes")
	var fired: Array = []
	var cb := func(): fired.append(true)
	GameManager.intro_finished.connect(cb)
	GameManager.finish_intro()
	assert_true(fired.size() == 1, "finish_intro emite intro_finished")
	assert_true(GameManager.can_player_act() and GameManager.can_spawn_npc(), "Tras la intro parte la Noche 1")
	GameManager.intro_finished.disconnect(cb)

	var ui = load("res://scenes/UI.tscn").instantiate()
	add_child(ui)
	assert_true(ui.get_node_or_null("HUD/IntroPanel") != null, "UI tiene IntroPanel")
	assert_true(ui.get_node_or_null("HUD/DayPanel/VBoxContainer/SavingsLabel") != null, "HUD muestra los ahorros del pasaje")
	var story: String = ui.get_intro_story()
	assert_true(story.contains("$50.000") and story.contains("3 noches"), "La historia menciona la meta y las 3 noches")
	ui._update_savings()
	var savings_label: Label = ui.get_node("HUD/DayPanel/VBoxContainer/SavingsLabel")
	assert_true(savings_label.text.contains("Faltan $30.000"), "SavingsLabel dice cuánto falta: '%s'" % savings_label.text)
	ui.queue_free()


func test_completo_mojado() -> void:
	print("\n--- Test 4: Completo mojado ---")
	var comp = _make_completo(true, true, false)
	assert_true(not comp.is_mojado, "Un completo nuevo no está mojado")
	assert_true(comp.mojar(), "mojar() moja el pan la primera vez")
	assert_true(not comp.mojar(), "No se puede mojar dos veces")
	assert_true(comp.get_completo_name().begins_with("Completo Mojado Italiano"), "Nombre: '%s'" % comp.get_completo_name())
	assert_true(comp.matches_order(true, true, true, false, true), "Coincide con un Italiano MOJADO")
	assert_true(not comp.matches_order(true, true, true, false, false), "No coincide con un Italiano normal")
	assert_true(comp.get_match_error(true, true, true, false, false).contains("mojado"), "Error explica que no se pidió mojado")
	var dry = _make_completo(true, true, false)
	assert_true(dry.get_match_error(true, true, true, false, true).contains("MOJADO"), "Error explica que faltó mojar el pan")
	assert_true(dry.matches_order(true, true, true, false), "Pedidos antiguos (sin mojado) siguen funcionando")
	comp.queue_free()
	dry.queue_free()


func test_olla_station() -> void:
	print("\n--- Test 5: Olla en la cocina ---")
	var kitchen = load("res://scenes/map/KitchenStations.tscn").instantiate()
	add_child(kitchen)
	var olla = kitchen.get_node_or_null("Station_Olla")
	assert_true(olla != null and olla.station_type == "olla", "KitchenStations tiene Station_Olla de tipo 'olla'")
	var fake_player := Node3D.new()
	fake_player.set_script(load("res://tests/helpers/FakeHolder.gd"))
	add_child(fake_player)
	var info: Dictionary = olla.get_interaction_prompt(fake_player)
	assert_true(not info.get("actionable", true), "Sin completo en la mano la olla no es usable")
	var comp = _make_completo(false, false, true)
	fake_player.held_item = comp
	info = olla.get_interaction_prompt(fake_player)
	assert_true(info.get("actionable", false) and String(info.get("text", "")).contains("Mojar"), "Con completo en la mano: '%s'" % info.get("text", ""))
	olla.interact(fake_player)
	assert_true(comp.is_mojado, "Interactuar con la olla moja el completo")
	info = olla.get_interaction_prompt(fake_player)
	assert_true(not info.get("actionable", true), "Un completo ya mojado no se vuelve a mojar")
	await get_tree().process_frame
	kitchen.queue_free()
	fake_player.queue_free()
	comp.queue_free()


func test_event_registration_and_schedule() -> void:
	print("\n--- Test 6: Registro y calendario de eventos ---")
	var mgr := NPCEventManager.new()
	for id in ["talquino", "estafador_chip", "rappi"]:
		assert_true(mgr.get_event(id) is StaticNPCEvent, "Evento estático '%s' registrado" % id)
	var tal: StaticNPCEvent = mgr.get_event("talquino")
	var sca: StaticNPCEvent = mgr.get_event("estafador_chip")
	var rap: StaticNPCEvent = mgr.get_event("rappi")
	assert_true(tal.can_trigger(-1, -1, 2, 2) and not tal.can_trigger(-1, -1, 1, 4), "Talquino: Noche 2 tras 2 clientes")
	assert_true(sca.can_trigger(-1, -1, 3, 1) and not sca.can_trigger(-1, -1, 2, 4), "Estafador: Noche 3 tras 1 cliente")
	assert_true(rap.can_trigger(-1, -1, 3, 3) and not rap.can_trigger(-1, -1, 3, 2), "Rappi: Noche 3 tras 3 clientes")
	assert_true(tal.weight == 0.0 and sca.weight == 0.0 and rap.weight == 0.0, "Los eventos nuevos no salen en sorteos aleatorios")
	mgr.free()


func test_talquino_event() -> void:
	print("\n--- Test 7: El Talquino pide un completo mojado ---")
	_reset()
	var npc := _spawn_npc_with_event(TalquinoEvent.new())
	assert_true(npc.get_node_or_null("Chupalla") != null, "El Talquino usa chupalla")
	assert_true(GameManager.mojados_unlocked, "Su llegada desbloquea los pedidos mojados")
	assert_true(npc.order_req_mojado and npc.order_req_palta and npc.order_req_mayo, "Pide un Italiano MOJADO")
	var before := GameManager.savings
	npc.receive_item(_make_completo(true, true, false, true))
	assert_true(GameManager.savings - before >= 3500, "El mojado correcto paga precio + recargo (+$%d)" % (GameManager.savings - before))
	await get_tree().create_timer(0.1).timeout
	npc.queue_free()

	# Pedidos normales mojados tras el desbloqueo
	var any_mojado := false
	for i in 40:
		var n: NPC = load("res://scenes/NPC.tscn").instantiate()
		n._generate_completo_order()
		any_mojado = any_mojado or n.order_req_mojado
		n.free()
	assert_true(any_mojado, "Con la olla desbloqueada algunos clientes piden mojado")
	_reset()
	var none_mojado := true
	for i in 40:
		var n: NPC = load("res://scenes/NPC.tscn").instantiate()
		n._generate_completo_order()
		none_mojado = none_mojado and not n.order_req_mojado
		n.free()
	assert_true(none_mojado, "Antes del Talquino nadie pide mojado")


func test_scammer_event() -> void:
	print("\n--- Test 8: El Estafador del chip de perro ---")
	_reset()
	var npc := _spawn_npc_with_event(ScammerEvent.new())
	assert_true(npc.label.text.contains("CHIP DE PERRO"), "Dice que las vienesas tienen chip de perro")
	npc.on_persiana_closed()
	assert_true(GameManager.savings == 20000, "Bajar la persiana lo echa sin perder plata")
	assert_true(npc.is_order_resolved(), "La visita queda resuelta")
	assert_true(GameManager.clients_served_correctly_today == 1, "Echarlo cuenta como bien atendido")
	await get_tree().create_timer(0.1).timeout
	npc.queue_free()

	_reset()
	npc = _spawn_npc_with_event(ScammerEvent.new())
	npc.receive_item(_make_completo(false, true, false))
	assert_true(GameManager.savings == 15000, "Entregarle algo es caer en la estafa: -$5.000")
	await get_tree().create_timer(0.1).timeout
	npc.queue_free()

	_reset()
	npc = _spawn_npc_with_event(ScammerEvent.new())
	npc.patience_remaining = 0.0
	npc._update_patience(0.1)
	assert_true(GameManager.savings == 15000, "Si se le acaba la paciencia se cobra solo: -$5.000")
	assert_true(GameManager.clients_lost_today == 1, "Ignorarlo cuenta como cliente perdido")
	await get_tree().create_timer(0.1).timeout
	npc.queue_free()


func test_rappi_event() -> void:
	print("\n--- Test 9: Repartidor de Rappi ---")
	_reset()
	var ev := RappiEvent.new()
	var npc := _spawn_npc_with_event(ev)
	assert_true(npc.get_node_or_null("Moto") != null and npc.get_node_or_null("Mochila") != null, "Llega en moto con mochila")
	var orders: Array = npc.get_meta("rappi_orders", [])
	assert_true(orders.size() == 2, "El pedido de la app tiene 2 completos")
	assert_true(npc.label.text.contains("Rappi") and npc.label.text.contains("[1/2]"), "El cartel muestra el pedido y el progreso")

	var patience_before := npc.patience_remaining
	var wrong_palta: bool = not orders[0]["palta"]
	npc.receive_item(_make_completo(wrong_palta, orders[0]["mayo"], orders[0]["ketchup"], orders[0].get("mojado", false)))
	assert_true(npc.get_meta("rappi_step") == 0, "Un completo equivocado no avanza el pedido")
	assert_true(npc.patience_remaining < patience_before, "Un completo equivocado descuenta tiempo de la app")

	for i in 2:
		var rec: Dictionary = orders[i]
		npc.receive_item(_make_completo(rec["palta"], rec["mayo"], rec["ketchup"], rec.get("mojado", false)))
	assert_true(npc.is_order_resolved(), "Con los 2 completos el pedido queda listo")
	assert_true(GameManager.savings >= 20000 + 6000 + ev.app_tip, "Paga cada completo y la propina de la app (ahorros: %d)" % GameManager.savings)
	assert_true(GameManager.clients_served_correctly_today == 1, "Cuenta como un cliente bien atendido")
	await get_tree().create_timer(0.1).timeout
	npc.queue_free()
