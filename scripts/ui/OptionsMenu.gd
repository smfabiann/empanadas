extends Control
## Menú modal de configuración de pantalla y renderizado.
## Permite ajustar el modo de ventana, resolución, escalado de renderizado 3D (nitidez)
## y sincronización vertical (VSync).

signal closed()

@onready var window_mode_option: OptionButton = $CenterContainer/OptionsPanel/VBoxContainer/GridContainer/WindowModeOption
@onready var resolution_option: OptionButton = $CenterContainer/OptionsPanel/VBoxContainer/GridContainer/ResolutionOption
@onready var embedded_hint_label: Label = $CenterContainer/OptionsPanel/VBoxContainer.get_node_or_null("EmbeddedHintLabel")
@onready var render_scale_slider: HSlider = $CenterContainer/OptionsPanel/VBoxContainer/ScaleSection/SliderContainer/RenderScaleSlider
@onready var render_scale_label: Label = $CenterContainer/OptionsPanel/VBoxContainer/ScaleSection/ScaleValueLabel
@onready var btn_scale_50: Button = $CenterContainer/OptionsPanel/VBoxContainer/ScaleSection/PresetsContainer/Btn50
@onready var btn_scale_75: Button = $CenterContainer/OptionsPanel/VBoxContainer/ScaleSection/PresetsContainer/Btn75
@onready var btn_scale_100: Button = $CenterContainer/OptionsPanel/VBoxContainer/ScaleSection/PresetsContainer/Btn100
@onready var vsync_check: CheckButton = $CenterContainer/OptionsPanel/VBoxContainer/VSyncContainer/VSyncCheck
@onready var apply_button: Button = $CenterContainer/OptionsPanel/VBoxContainer/ButtonsVBox/ApplyButton
@onready var reset_button: Button = $CenterContainer/OptionsPanel/VBoxContainer/ButtonsVBox/ResetButton
@onready var close_button: Button = $CenterContainer/OptionsPanel/VBoxContainer/ButtonsVBox/CloseButton

var _resolutions: Array[Vector2i] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Poblar opciones de modo de pantalla
	window_mode_option.clear()
	window_mode_option.add_item("Ventana", SettingsManager.WindowModeOption.WINDOWED)
	window_mode_option.add_item("Pantalla Completa", SettingsManager.WindowModeOption.FULLSCREEN)
	window_mode_option.add_item("Ventana Sin Bordes", SettingsManager.WindowModeOption.BORDERLESS)

	# Poblar resoluciones disponibles
	_populate_resolutions()

	# Conexiones de controles
	resolution_option.item_selected.connect(_on_resolution_selected)
	render_scale_slider.value_changed.connect(_on_slider_value_changed)
	btn_scale_50.pressed.connect(func(): _set_slider_value(0.50))
	btn_scale_75.pressed.connect(func(): _set_slider_value(0.75))
	btn_scale_100.pressed.connect(func(): _set_slider_value(1.00))

	apply_button.pressed.connect(_on_apply_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	close_button.pressed.connect(_on_close_pressed)

	refresh_ui()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _populate_resolutions() -> void:
	resolution_option.clear()
	_resolutions = SettingsManager.get_available_resolutions()
	for i in range(_resolutions.size()):
		var res: Vector2i = _resolutions[i]
		var label_text: String = "%d × %d" % [res.x, res.y]
		if res == Vector2i(1920, 1080):
			label_text += " (FHD Recomendada)"
		elif res == Vector2i(1280, 720):
			label_text += " (HD)"
		resolution_option.add_item(label_text, i)


## Actualiza la interfaz con los valores vigentes en SettingsManager
func refresh_ui() -> void:
	if not SettingsManager:
		return

	# Modo de ventana
	for i in range(window_mode_option.item_count):
		if window_mode_option.get_item_id(i) == SettingsManager.current_window_mode:
			window_mode_option.select(i)
			break

	# Resolución seleccionada (siempre habilitada en todos los modos)
	resolution_option.disabled = false
	_select_resolution_in_dropdown(SettingsManager.current_resolution)

	# Render Scale
	render_scale_slider.value = SettingsManager.current_render_scale
	_update_scale_label(SettingsManager.current_render_scale)

	# VSync
	vsync_check.button_pressed = SettingsManager.current_vsync

	# Aviso de ventana incrustada en el editor
	if embedded_hint_label:
		embedded_hint_label.visible = SettingsManager.is_window_embedded()


func _select_resolution_in_dropdown(res: Vector2i) -> void:
	for i in range(_resolutions.size()):
		if _resolutions[i] == res:
			resolution_option.select(i)
			return
	if _resolutions.size() > 0:
		resolution_option.select(0)


func _on_resolution_selected(index: int) -> void:
	if index >= 0 and index < _resolutions.size():
		# Vista previa en vivo del cambio de resolución (sin persistir aún)
		SettingsManager.set_resolution(_resolutions[index], false)


func _on_slider_value_changed(val: float) -> void:
	_update_scale_label(val)
	# Vista previa en vivo del render scale 3D
	SettingsManager.set_render_scale(val, false)


func _set_slider_value(val: float) -> void:
	render_scale_slider.value = val
	_update_scale_label(val)
	SettingsManager.set_render_scale(val, false)


func _update_scale_label(val: float) -> void:
	var pct: int = int(round(val * 100.0))
	var desc: String = ""
	if pct >= 100:
		desc = "Nativo — Máxima nitidez"
	elif pct >= 85:
		desc = "Alta calidad"
	elif pct >= 75:
		desc = "Equilibrado"
	else:
		desc = "Rendimiento"
	render_scale_label.text = "%d%% — %s" % [pct, desc]


func _on_apply_pressed() -> void:
	var selected_mode: int = window_mode_option.get_selected_id()
	var res_idx: int = resolution_option.selected
	var target_res: Vector2i = _resolutions[res_idx] if res_idx >= 0 and res_idx < _resolutions.size() else Vector2i(1920, 1080)
	var scale_val: float = float(render_scale_slider.value)
	var vsync_val: bool = vsync_check.button_pressed

	SettingsManager.update_settings(selected_mode, target_res, scale_val, vsync_val)
	refresh_ui()


func _on_reset_pressed() -> void:
	SettingsManager.reset_to_defaults()
	refresh_ui()


func _on_close_pressed() -> void:
	# Restaurar la configuración guardada por si se cambió algo en vista previa sin aplicar
	SettingsManager.apply_settings()
	visible = false
	closed.emit()


## Abre el menú y refresca los datos
func open_menu() -> void:
	refresh_ui()
	visible = true
