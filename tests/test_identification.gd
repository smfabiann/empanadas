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
	print("=== RUNNING IDENTIFICATION & CREDITS TEST SUITE ===")
	
	# Test 1: Project configuration
	var app_name = ProjectSettings.get_setting("application/config/name")
	_assert(app_name == "Completos", "project.godot application/config/name is 'Completos' (current: '%s')" % app_name)
	
	# Test 2: MainMenu scene instantiation
	var menu_scene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	_assert(menu_scene != null, "MainMenu.tscn loaded successfully")
	
	var menu = menu_scene.instantiate()
	add_child(menu)
	_assert(menu != null, "MainMenu instantiated successfully")
	
	# Test 3: Title check
	var title_label = menu.get_node_or_null("CenterContainer/MainPanel/VBoxContainer/TitleLabel") as Label
	_assert(title_label != null, "TitleLabel found")
	_assert(title_label != null and title_label.text == "COMPLETOS", "Title is 'COMPLETOS'")
	
	# Test 4: Footer Credits check
	var credits_label = menu.get_node_or_null("CreditsLabel") as Label
	_assert(credits_label != null, "CreditsLabel found on main screen")
	if credits_label:
		_assert(credits_label.text.contains("Completos"), "CreditsLabel contains 'Completos'")
		_assert(credits_label.text.contains("Nicolaz Perez"), "CreditsLabel contains 'Nicolaz Perez'")
		_assert(credits_label.text.contains("Nicolas Vargas"), "CreditsLabel contains 'Nicolas Vargas'")
		_assert(credits_label.text.contains("Fabian San Martin"), "CreditsLabel contains 'Fabian San Martin'")
	
	# Test 5: Credits Button & Modal interaction
	var credits_btn = menu.get_node_or_null("CenterContainer/MainPanel/VBoxContainer/ButtonsVBox/CreditsButton") as Button
	_assert(credits_btn != null, "CreditsButton exists in ButtonsVBox")
	
	var credits_modal = menu.get_node_or_null("CreditsModal") as Control
	_assert(credits_modal != null, "CreditsModal exists")
	_assert(credits_modal != null and not credits_modal.visible, "CreditsModal is initially hidden")
	
	if credits_btn and credits_modal:
		credits_btn.emit_signal("pressed")
		_assert(credits_modal.visible, "CreditsModal becomes visible when CreditsButton is pressed")
		
		var info_label = credits_modal.get_node_or_null("CenterContainer/CreditsPanel/VBoxContainer/GameInfoLabel") as RichTextLabel
		_assert(info_label != null, "GameInfoLabel exists in modal")
		if info_label:
			_assert(info_label.text.contains("Nicolaz Perez"), "GameInfoLabel lists 'Nicolaz Perez'")
			_assert(info_label.text.contains("Nicolas Vargas"), "GameInfoLabel lists 'Nicolas Vargas'")
			_assert(info_label.text.contains("Fabian San Martin"), "GameInfoLabel lists 'Fabian San Martin'")
			_assert(info_label.text.contains("Godot Engine 4.7"), "GameInfoLabel credits 'Godot Engine 4.7'")
			_assert(info_label.text.contains("AudioStreamGenerator"), "GameInfoLabel notes procedural audio (AudioStreamGenerator)")
			_assert(info_label.text.contains("CSG"), "GameInfoLabel notes procedural 3D CSG geometry")
		
		var close_btn = credits_modal.get_node_or_null("CenterContainer/CreditsPanel/VBoxContainer/CloseCreditsButton") as Button
		_assert(close_btn != null, "CloseCreditsButton exists")
		if close_btn:
			close_btn.emit_signal("pressed")
			_assert(not credits_modal.visible, "CreditsModal hides when CloseCreditsButton is pressed")
	
	# Test 6: PauseMenu scene
	var pause_scene = load("res://scenes/ui/PauseMenu.tscn") as PackedScene
	_assert(pause_scene != null, "PauseMenu.tscn loaded successfully")
	var pause_menu = pause_scene.instantiate()
	add_child(pause_menu)
	var footer = pause_menu.get_node_or_null("PanelContainer/VBoxContainer/FooterLabel") as Label
	_assert(footer != null, "PauseMenu has FooterLabel")
	if footer:
		_assert(footer.text.contains("Nicolaz Perez"), "PauseMenu footer contains 'Nicolaz Perez'")
	
	print("=== TEST SUMMARY: %d PASSED, %d FAILED ===" % [_passed, _failed])
	if _failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)
