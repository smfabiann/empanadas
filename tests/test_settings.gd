extends Node
## Test automatizado de SettingsManager y OptionsMenu.

var _passed := 0
var _failed := 0


func _check(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("[SettingsTest] OK   ", msg)
	else:
		_failed += 1
		print("[SettingsTest] FAIL ", msg)


func _ready() -> void:
	print("[SettingsTest] Iniciando pruebas de configuración y render scale...")

	_check(SettingsManager != null, "SettingsManager existe como Autoload singleton")

	# 1. Verificar resoluciones disponibles
	var res_list: Array[Vector2i] = SettingsManager.get_available_resolutions()
	_check(res_list.size() >= 4, "Hay al menos 4 resoluciones disponibles (%d encontradas)" % res_list.size())
	_check(res_list.has(Vector2i(1920, 1080)), "Lista incluye 1920x1080")
	_check(res_list.has(Vector2i(1280, 720)), "Lista incluye 1280x720")

	# 2. Render Scale y Resolución vinculada
	SettingsManager.current_resolution = Vector2i(1920, 1080)
	SettingsManager.current_render_scale = 1.0
	SettingsManager.apply_settings()
	_check(is_equal_approx(get_viewport().scaling_3d_scale, 1.0), "Render scale 1.0 a 1080p se aplica al Viewport")

	# En Fullscreen, al bajar a 720p en pantalla de 1080p, la escala de renderizado baja a ~0.667
	SettingsManager.current_window_mode = SettingsManager.WindowModeOption.FULLSCREEN
	SettingsManager.set_resolution(Vector2i(1280, 720), false)
	_check(get_viewport().scaling_3d_scale < 0.75, "Al cambiar resolución a 720p en Fullscreen la escala de renderizado baja proporcionalmente (%f)" % get_viewport().scaling_3d_scale)

	# Al volver a 1080p
	SettingsManager.set_resolution(Vector2i(1920, 1080), false)
	_check(is_equal_approx(get_viewport().scaling_3d_scale, 1.0), "Al volver a 1080p la escala vuelve a 1.0")

	# 3. Persistencia
	SettingsManager.update_settings(SettingsManager.WindowModeOption.WINDOWED, Vector2i(1920, 1080), 1.0, true)
	_check(FileAccess.file_exists(SettingsManager.SETTINGS_FILE_PATH), "El archivo user://settings.cfg fue creado y existe")

	var config := ConfigFile.new()
	var err := config.load(SettingsManager.SETTINGS_FILE_PATH)
	_check(err == OK, "user://settings.cfg se lee correctamente con ConfigFile")
	_check(config.get_value(SettingsManager.SECTION_DISPLAY, "render_scale") == 1.0, "render_scale guardado correctamente como 1.0")
	_check(config.get_value(SettingsManager.SECTION_DISPLAY, "resolution_width") == 1920, "resolution_width guardado como 1920")

	# 4. Instanciación y controles de OptionsMenu
	var options_scene := load("res://scenes/ui/OptionsMenu.tscn") as PackedScene
	_check(options_scene != null, "OptionsMenu.tscn se carga correctamente")
	var options_instance = options_scene.instantiate()
	add_child(options_instance)
	await get_tree().process_frame

	_check(options_instance.window_mode_option.item_count == 3, "OptionsMenu tiene los 3 modos de ventana")
	_check(not options_instance.resolution_option.disabled, "Dropdown de resolución está habilitado")
	_check(options_instance.render_scale_slider.min_value == 0.5, "Slider tiene min_value en 0.5")
	_check(options_instance.render_scale_slider.max_value == 1.0, "Slider tiene max_value en 1.0")
	_check(is_equal_approx(options_instance.render_scale_slider.value, 1.0), "Slider inicia en 1.0")

	# Probar botones presets
	options_instance.btn_scale_75.emit_signal("pressed")
	_check(is_equal_approx(options_instance.render_scale_slider.value, 0.75), "Preset 75% actualiza el slider a 0.75")
	options_instance.btn_scale_100.emit_signal("pressed")
	_check(is_equal_approx(options_instance.render_scale_slider.value, 1.0), "Preset 100% actualiza el slider a 1.0")

	options_instance.queue_free()
	await get_tree().process_frame

	# Limpiar archivo de test si es necesario
	SettingsManager.reset_to_defaults()

	print("[SettingsTest] Resultado: %d OK, %d FAIL" % [_passed, _failed])
	if _failed == 0:
		print("[SettingsTest]  ÉXITO: todas las pruebas de Settings pasaron.")
	else:
		push_error("[SettingsTest] Fallaron %d pruebas" % _failed)
	get_tree().quit(0 if _failed == 0 else 1)
