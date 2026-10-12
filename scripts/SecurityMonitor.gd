extends StaticBody3D
## Monitor de seguridad en la pared izquierda.
## Al interactuar, alterna entre la cámara del jugador y la cámara de seguridad.
## Soporta varios canales de CCTV (nodos `CCTVCamera`): mientras se mira el monitor,
## [A]/[D] o las flechas cambian de canal. Los eventos de cámara (HU-10) se ven
## solo en el canal que cubre su zona.

## Se emite al cambiar de canal (índice en `channels`, id del canal y nombre visible)
signal channel_changed(index: int, channel_id: String, channel_name: String)

const FEED_SHADER := preload("res://shaders/cctv_feed.gdshader")
## Duración de la ráfaga de estática al cambiar de canal
const SWITCH_STATIC_DURATION := 0.25

@onready var screen_mesh: CSGBox3D = $ScreenMesh
@onready var security_cam_viewport: SubViewport = $SubViewport

var is_viewing: bool = false
var is_anomaly_vision: bool = false
var anomaly_env: Environment = null
var player_camera: Camera3D = null
var security_camera: Camera3D = null

## Cámaras disponibles ordenadas por canal
var channels: Array[Camera3D] = []
var current_channel: int = 0

var mat_off: StandardMaterial3D
var mat_on: StandardMaterial3D

# HUD del monitor (solo visible a pantalla completa)
var _overlay_layer: CanvasLayer = null
var _feed_rect: ColorRect = null
var _feed_material: ShaderMaterial = null
var _channel_label: Label = null
var _clock_label: Label = null
var _no_signal_label: Label = null
var _switch_static: float = 0.0
var _feed_clock: float = 0.0


func _ready() -> void:
	add_to_group("security_monitors")
	# Material cuando el monitor está apagado (pantalla oscura)
	mat_off = StandardMaterial3D.new()
	mat_off.albedo_color = Color(0.02, 0.02, 0.05, 1.0)
	mat_off.emission_enabled = true
	mat_off.emission = Color(0.01, 0.01, 0.03, 1.0)
	mat_off.emission_energy_multiplier = 0.2

	# Material cuando el monitor muestra la cámara (usa la textura del SubViewport)
	mat_on = StandardMaterial3D.new()
	mat_on.albedo_color = Color.WHITE
	mat_on.emission_enabled = true
	mat_on.emission = Color(0.5, 0.5, 0.5, 1.0)
	mat_on.emission_energy_multiplier = 0.8

	screen_mesh.material = mat_off

	_build_overlay()
	# Esperar a que todas las CCTVCamera de la escena se registren en su grupo
	call_deferred("refresh_channels")


## Recolecta los canales de CCTV de la escena. Si no hay `CCTVCamera`, usa la cámara
## heredada "Camara"/"Camara2" para mantener compatibilidad con escenas antiguas.
func refresh_channels() -> void:
	channels.clear()
	if is_inside_tree():
		for cam in get_tree().get_nodes_in_group("cctv_cameras"):
			if cam is Camera3D:
				channels.append(cam)
	channels.sort_custom(func(a, b): return _channel_index_of(a) < _channel_index_of(b))

	if channels.is_empty():
		var legacy := _find_legacy_camera()
		if legacy:
			channels.append(legacy)

	current_channel = clampi(current_channel, 0, maxi(channels.size() - 1, 0))
	security_camera = channels[current_channel] if not channels.is_empty() else null

	if security_camera and security_cam_viewport and not security_cam_viewport.has_node("VPCamera"):
		_setup_viewport_camera()


func _channel_index_of(cam: Camera3D) -> int:
	var idx = cam.get("channel_index")
	return idx if idx != null else 0


func _find_legacy_camera() -> Camera3D:
	var cam_node = null
	if get_parent():
		cam_node = get_parent().get_node_or_null("Camara")
		if not cam_node:
			cam_node = get_parent().get_node_or_null("Camara2")
	if not cam_node and is_inside_tree():
		var root = get_tree().current_scene
		if root:
			cam_node = root.find_child("Camara", true, false)
			if not cam_node:
				cam_node = root.find_child("Camara2", true, false)
		if not cam_node:
			cam_node = get_tree().root.find_child("Camara", true, false)

	if cam_node:
		var cam = cam_node.get_node_or_null("Camera3D") as Camera3D
		if not cam and cam_node is Camera3D:
			cam = cam_node
		return cam
	return null


func _setup_viewport_camera() -> void:
	# Crear una cámara dentro del SubViewport que copie la posición de la de seguridad
	var vp_cam = Camera3D.new()
	vp_cam.name = "VPCamera"
	security_cam_viewport.add_child(vp_cam)

	# Actualizar la textura del material
	mat_on.albedo_texture = security_cam_viewport.get_texture()
	mat_on.emission_texture = security_cam_viewport.get_texture()


func _process(delta: float) -> void:
	# Copiar la transform global de la cámara de seguridad al viewport camera
	if security_camera and security_cam_viewport:
		var vp_cam = security_cam_viewport.get_node_or_null("VPCamera") as Camera3D
		if vp_cam:
			vp_cam.global_transform = security_camera.global_transform
			vp_cam.fov = security_camera.fov
			vp_cam.cull_mask = security_camera.cull_mask

	# Siempre mostrar la textura en el monitor (pantalla siempre encendida)
	if security_cam_viewport and not is_viewing:
		screen_mesh.material = mat_on

	_update_overlay(delta)


static var active_monitor: StaticBody3D = null

func interact(player: Node3D) -> void:
	if security_camera == null:
		refresh_channels()
	if security_camera == null:
		return

	player_camera = player.get_node_or_null("Camera3D") as Camera3D
	if player_camera == null:
		return

	is_viewing = not is_viewing

	if is_viewing:
		active_monitor = self
		# Cambiar a la cámara de seguridad
		security_camera.current = true
		screen_mesh.material = mat_on
		if player.has_method("set"):
			player.is_viewing_monitor = true
		_switch_static = SWITCH_STATIC_DURATION
	else:
		active_monitor = null
		# Volver a la cámara del jugador
		player_camera.current = true
		screen_mesh.material = mat_on
		if player.has_method("set"):
			player.is_viewing_monitor = false

		# Apagar visión nocturna al salir
		if is_anomaly_vision:
			toggle_anomaly_vision()

	if _overlay_layer:
		_overlay_layer.visible = is_viewing


## Cambia al canal siguiente (+1) o anterior (-1)
func switch_channel(step: int) -> void:
	if channels.size() <= 1:
		return
	set_channel((current_channel + step + channels.size()) % channels.size())


## Sintoniza un canal concreto por índice
func set_channel(index: int) -> void:
	if channels.is_empty():
		return
	index = clampi(index, 0, channels.size() - 1)
	var previous := security_camera
	current_channel = index
	security_camera = channels[index]

	# Mantener la visión nocturna al cambiar de canal
	if previous and previous != security_camera:
		previous.environment = null
		if is_anomaly_vision and anomaly_env:
			security_camera.environment = anomaly_env

	if is_viewing:
		security_camera.current = true
	_switch_static = SWITCH_STATIC_DURATION

	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method("play_pickup"):
		SFXManager.play_pickup()

	channel_changed.emit(current_channel, get_current_channel_id(), get_current_channel_name())


func get_current_channel_id() -> String:
	if security_camera == null:
		return ""
	var id = security_camera.get("channel_id")
	return id if id != null else "frente"


func get_current_channel_name() -> String:
	if security_camera == null:
		return ""
	var channel_label = security_camera.get("channel_name")
	return channel_label if channel_label != null else "FRENTE"


## Interferencia actual del canal sintonizado (0..1), aportada por eventos de cámara
## del grupo "cctv_feed_modifiers" que implementan get_feed_interference(channel_id).
func get_channel_interference(channel_id: String) -> float:
	var amount := 0.0
	if not is_inside_tree():
		return amount
	for mod in get_tree().get_nodes_in_group("cctv_feed_modifiers"):
		if mod != null and mod.has_method("get_feed_interference"):
			amount = maxf(amount, float(mod.get_feed_interference(channel_id)))
	return clampf(amount, 0.0, 1.0)


func toggle_anomaly_vision() -> void:
	if not security_camera:
		return
	is_anomaly_vision = not is_anomaly_vision

	if is_anomaly_vision:
		# Si no hemos creado el entorno, lo creamos ahora
		if not anomaly_env:
			var normal_env = null
			var world_env_node = get_tree().root.find_child("WorldEnvironment", true, false)
			if world_env_node and world_env_node.environment:
				normal_env = world_env_node.environment
				anomaly_env = normal_env.duplicate()
			else:
				anomaly_env = Environment.new()

			anomaly_env.adjustment_enabled = true
			anomaly_env.adjustment_saturation = 0.25 # Pálido
			anomaly_env.adjustment_brightness = 1.3
			anomaly_env.adjustment_contrast = 1.1

		security_camera.environment = anomaly_env

		# También aplicamos el entorno a la cámara interna para que la pantalla del monitor se vea pálida desde afuera
		var vp_cam = security_cam_viewport.get_node_or_null("VPCamera") as Camera3D
		if vp_cam:
			vp_cam.environment = anomaly_env
	else:
		security_camera.environment = null
		var vp_cam = security_cam_viewport.get_node_or_null("VPCamera") as Camera3D
		if vp_cam:
			vp_cam.environment = null


func get_interaction_prompt(_player: Node3D) -> Dictionary:
	if is_viewing:
		var text := "[E] Volver a tu vista\n[F] Visión Nocturna"
		if channels.size() > 1:
			text += "\n[A/D] Cambiar cámara"
		return {"text": text, "actionable": true}
	else:
		return {"text": "[E] Ver cámara de seguridad", "actionable": true}


# =========================================================
#  HUD DEL MONITOR (canal, hora, filtro CCTV)
# =========================================================

func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "CCTVOverlay"
	_overlay_layer.layer = 0
	_overlay_layer.visible = false
	add_child(_overlay_layer)

	_feed_material = ShaderMaterial.new()
	_feed_material.shader = FEED_SHADER

	_feed_rect = ColorRect.new()
	_feed_rect.name = "Feed"
	_feed_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feed_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_rect.material = _feed_material
	_overlay_layer.add_child(_feed_rect)

	_channel_label = _make_label("ChannelLabel", 22, HORIZONTAL_ALIGNMENT_LEFT)
	_channel_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_channel_label.position = Vector2(28, 52)
	_overlay_layer.add_child(_channel_label)

	_clock_label = _make_label("ClockLabel", 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_clock_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_clock_label.offset_left = -360
	_clock_label.offset_top = -60
	_clock_label.offset_right = -28
	_clock_label.offset_bottom = -24
	_overlay_layer.add_child(_clock_label)

	_no_signal_label = _make_label("NoSignalLabel", 34, HORIZONTAL_ALIGNMENT_CENTER)
	_no_signal_label.set_anchors_preset(Control.PRESET_CENTER)
	_no_signal_label.offset_left = -240
	_no_signal_label.offset_right = 240
	_no_signal_label.offset_top = -24
	_no_signal_label.offset_bottom = 24
	_no_signal_label.text = "SIN SEÑAL"
	_no_signal_label.visible = false
	_overlay_layer.add_child(_no_signal_label)


func _make_label(label_name: String, font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	return label


func _update_overlay(delta: float) -> void:
	if _overlay_layer == null:
		return
	_overlay_layer.visible = is_viewing
	if not is_viewing:
		return

	_feed_clock += delta
	_switch_static = maxf(_switch_static - delta, 0.0)

	var interference := get_channel_interference(get_current_channel_id())
	var switch_noise := 1.0 if _switch_static > 0.0 else 0.0
	_feed_material.set_shader_parameter("interference", maxf(interference, switch_noise))

	# Etiqueta "● REC CAM 01 · FRENTE" con el punto de grabación parpadeando
	var rec := "●" if int(_feed_clock * 2.0) % 2 == 0 else "  "
	_channel_label.text = "%s REC   CAM %02d · %s" % [rec, current_channel + 1, get_current_channel_name()]

	# Reloj nocturno ficticio que avanza desde las 23:00
	var day := 1
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		day = GameManager.current_day
	var total := int(_feed_clock) + 23 * 3600
	_clock_label.text = "DÍA %d   %02d:%02d:%02d" % [day, (total / 3600) % 24, (total / 60) % 60, total % 60]

	_no_signal_label.visible = interference >= 0.85 and int(_feed_clock * 3.0) % 2 == 0
