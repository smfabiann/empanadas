extends Node

var _passed := 0
var _failed := 0


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  [PASS] " + message)
		_passed += 1
	else:
		push_error("  [FAIL] " + message)
		print("  [FAIL] " + message)
		_failed += 1


func _ready() -> void:
	print("=== RUNNING DAY & CLIENT PROGRESSION COUNTER TEST SUITE ===")

	var ui_scene = load("res://scenes/UI.tscn") as PackedScene
	_assert(ui_scene != null, "UI.tscn loaded successfully")

	var ui = ui_scene.instantiate()
	add_child(ui)
	_assert(ui != null, "UI instantiated successfully")

	# Test 1: DayPanel exists and contains DayLabel and DayProgressBar
	var day_panel = ui.get_node_or_null("HUD/DayPanel") as PanelContainer
	_assert(day_panel != null, "DayPanel exists in HUD")

	var day_label = ui.get_node_or_null("HUD/DayPanel/VBoxContainer/DayLabel") as Label
	_assert(day_label != null, "DayLabel exists inside DayPanel")

	var progress_bar = ui.get_node_or_null("HUD/DayPanel/VBoxContainer/DayProgressBar") as ProgressBar
	_assert(progress_bar != null, "DayProgressBar exists inside DayPanel")

	# Test 2: Font size verification (bigger than old 15)
	var font_size = day_label.get_theme_font_size("font_size")
	_assert(font_size >= 24, "DayLabel font_size is prominent (current: %d >= 24)" % font_size)

	# Test 3: Progression update with clients
	GameManager.current_day = 1
	GameManager.max_days = 3
	GameManager.day_active = true
	ui._on_day_progress(3, 8)
	_assert(day_label.text.contains("Clientes 3/8") or day_label.text.contains("3/8"), "DayLabel displays client progression in Spanish (current: '%s')" % day_label.text)
	_assert(day_label.text.contains("Día 1/3") or day_label.text.contains("Día"), "DayLabel displays Día in Spanish")
	_assert(progress_bar.max_value == 8.0, "DayProgressBar max_value is 8.0")

	# Test 4: Quota reached
	GameManager.day_active = false
	GameManager.clients_attended_today = 8
	ui._on_day_ended(1)
	_assert(day_label.text.contains("Turno terminado") or day_label.text.contains("Ve a la cama"), "DayLabel indicates Shift Complete in Spanish when day ends")
	_assert(progress_bar.value == progress_bar.max_value, "DayProgressBar is filled at shift completion")

	print("=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [_passed, _failed])
	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
