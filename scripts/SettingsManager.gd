extends Node
## Autoload singleton — gestor de configuración y preferencias del usuario.
## Administra resolución, modo de ventana, render scale 3D y sincronización vertical (VSync).
## Persiste los valores en user://settings.cfg y los aplica en DisplayServer y Viewport.

signal settings_changed()
signal render_scale_changed(new_scale: float)

const SETTINGS_FILE_PATH := "user://settings.cfg"
const SECTION_DISPLAY := "display"

enum WindowModeOption {
	WINDOWED = 0,
	FULLSCREEN = 1,
	BORDERLESS = 2
}

const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1366, 768),
	Vector2i(1280, 720)
]

# Valores por defecto
var current_window_mode: int = WindowModeOption.WINDOWED
var current_resolution: Vector2i = Vector2i(1920, 1080)
var current_render_scale: float = 1.0 # Multiplicador de nitidez (0.5 a 1.0)
var current_vsync: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_settings()

	var win := get_window()
	if win and not win.size_changed.is_connected(_on_window_size_changed):
		win.size_changed.connect(_on_window_size_changed)


func _on_window_size_changed() -> void:
	_apply_effective_render_scale()


## Indica si la ventana del juego se está ejecutando incrustada dentro del editor de Godot
func is_window_embedded() -> bool:
	var win := get_window()
	return win != null and win.is_embedded()


## Obtiene la lista de resoluciones recomendadas, incluyendo la del monitor actual si es distinta
func get_available_resolutions() -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)

	if screen_size.x > 0 and screen_size.y > 0 and not list.has(screen_size):
		list.append(screen_size)

	for res in COMMON_RESOLUTIONS:
		if not list.has(res):
			list.append(res)

	# Ordenar de mayor a menor resolución
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a.x * a.y) > (b.x * b.y)
	)
	return list


## Carga configuración desde disco o inicializa valores por defecto si no existe
func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE_PATH)

	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	var default_res: Vector2i = Vector2i(1920, 1080)
	if screen_size.x > 0 and screen_size.y > 0 and screen_size.x <= 1920:
		default_res = screen_size

	if err == OK:
		current_window_mode = config.get_value(SECTION_DISPLAY, "window_mode", WindowModeOption.WINDOWED)
		var width: int = config.get_value(SECTION_DISPLAY, "resolution_width", default_res.x)
		var height: int = config.get_value(SECTION_DISPLAY, "resolution_height", default_res.y)
		current_resolution = Vector2i(width, height)
		current_render_scale = clampf(config.get_value(SECTION_DISPLAY, "render_scale", 1.0), 0.5, 1.0)
		current_vsync = config.get_value(SECTION_DISPLAY, "vsync", true)
	else:
		current_window_mode = WindowModeOption.WINDOWED
		current_resolution = default_res
		current_render_scale = 1.0
		current_vsync = true
		save_settings()


## Guarda la configuración actual en user://settings.cfg
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_DISPLAY, "window_mode", current_window_mode)
	config.set_value(SECTION_DISPLAY, "resolution_width", current_resolution.x)
	config.set_value(SECTION_DISPLAY, "resolution_height", current_resolution.y)
	config.set_value(SECTION_DISPLAY, "render_scale", current_render_scale)
	config.set_value(SECTION_DISPLAY, "vsync", current_vsync)

	var err := config.save(SETTINGS_FILE_PATH)
	if err != OK:
		push_warning("[SettingsManager] Error al guardar configuraciones: %d" % err)


## Aplica la configuración completa al motor (DisplayServer y Viewport)
func apply_settings() -> void:
	var embedded: bool = is_window_embedded()

	# 1. Modo de ventana y tamaño de ventana en OS
	if not embedded:
		match current_window_mode:
			WindowModeOption.FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			WindowModeOption.BORDERLESS:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
				var screen_id: int = DisplayServer.window_get_current_screen()
				var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_id)
				DisplayServer.window_set_size(screen_rect.size)
				DisplayServer.window_set_position(screen_rect.position)
			WindowModeOption.WINDOWED, _:
				DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				_apply_window_resolution(current_resolution)

	# 2. VSync
	var vsync_mode := DisplayServer.VSYNC_ENABLED if current_vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)

	# 3. Aplicar la resolución real al 3D (Render Scale efectivo)
	_apply_effective_render_scale()

	settings_changed.emit()


## Aplica la resolución física de la ventana en modo Ventana
func _apply_window_resolution(res: Vector2i) -> void:
	if is_window_embedded():
		return
	if current_window_mode != WindowModeOption.WINDOWED:
		return

	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_id)

	# Limitar al tamaño de pantalla utilizable
	var target_w: int = mini(res.x, screen_rect.size.x)
	var target_h: int = mini(res.y, screen_rect.size.y)
	var target_res := Vector2i(target_w, target_h)

	DisplayServer.window_set_size(target_res)
	var centered_pos := screen_rect.position + (screen_rect.size - target_res) / 2
	DisplayServer.window_set_position(centered_pos)


## Calcula y aplica la escala de renderizado 3D real en el Viewport.
## Vincula la resolución elegida (ej. 720p vs 1080p) con el tamaño del viewport o monitor,
## garantizando que cambiar a 720p baje la resolución 3D real tanto en pantalla completa como en ventana.
func _apply_effective_render_scale() -> void:
	var vp: Viewport = get_viewport()
	if not vp:
		return

	var win_height: int = 1080
	if DisplayServer.get_name() != "headless":
		var win_size: Vector2i = DisplayServer.window_get_size()
		if win_size.y >= 400:
			win_height = win_size.y
		else:
			var screen_id: int = DisplayServer.window_get_current_screen()
			var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
			if screen_size.y >= 400:
				win_height = screen_size.y
	
	# Si la ventana física ya fue redimensionada a la resolución seleccionada (modo ventana normal),
	# no necesitamos reducir la escala 3D adicionalmente
	var res_ratio: float = 1.0
	if not is_window_embedded() and current_window_mode == WindowModeOption.WINDOWED:
		res_ratio = 1.0
	else:
		# En pantalla completa, sin bordes o ventana fija/incrustada, la escala 3D baja proporcionalmente a la resolución
		res_ratio = clampf(float(current_resolution.y) / float(win_height), 0.25, 1.5)

	# Multiplicar por el ajuste fino del slider (0.5 a 1.0)
	var final_scale: float = clampf(res_ratio * current_render_scale, 0.25, 2.0)

	vp.scaling_3d_scale = final_scale
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR

	render_scale_changed.emit(final_scale)


## Actualiza únicamente el render scale sin alterar posición ni tamaño de ventana
func set_render_scale(scale_val: float, persist: bool = true) -> void:
	current_render_scale = clampf(scale_val, 0.5, 1.0)
	_apply_effective_render_scale()
	if persist:
		save_settings()


## Actualiza la resolución seleccionada y aplica el nuevo renderizado
func set_resolution(res: Vector2i, persist: bool = true) -> void:
	current_resolution = res
	if not is_window_embedded() and current_window_mode == WindowModeOption.WINDOWED:
		_apply_window_resolution(current_resolution)
	_apply_effective_render_scale()
	if persist:
		save_settings()


## Métodos públicos para actualizar valores
func update_settings(mode: int, res: Vector2i, scale_val: float, vsync_val: bool) -> void:
	current_window_mode = mode
	current_resolution = res
	current_render_scale = clampf(scale_val, 0.5, 1.0)
	current_vsync = vsync_val
	apply_settings()
	save_settings()


## Restablece las opciones a los valores por defecto
func reset_to_defaults() -> void:
	var screen_id: int = DisplayServer.window_get_current_screen()
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	var default_res: Vector2i = Vector2i(1920, 1080)
	if screen_size.x > 0 and screen_size.y > 0 and screen_size.x <= 1920:
		default_res = screen_size

	update_settings(WindowModeOption.WINDOWED, default_res, 1.0, true)
