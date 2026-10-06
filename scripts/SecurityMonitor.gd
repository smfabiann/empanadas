extends StaticBody3D
## Monitor de seguridad en la pared izquierda.
## Al interactuar, alterna entre la cámara del jugador y la cámara de seguridad.

@onready var screen_mesh: CSGBox3D = $ScreenMesh
@onready var security_cam_viewport: SubViewport = $SubViewport

var is_viewing: bool = false
var is_anomaly_vision: bool = false
var anomaly_env: Environment = null
var player_camera: Camera3D = null
var security_camera: Camera3D = null

var mat_off: StandardMaterial3D
var mat_on: StandardMaterial3D


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

	# Buscar la cámara de seguridad (en el padre, o en la escena)
	var cam_node = null
	if get_parent():
		cam_node = get_parent().get_node_or_null("Camara")
		if not cam_node:
			cam_node = get_parent().get_node_or_null("Camara2")
	if not cam_node:
		var root = get_tree().current_scene if get_tree() else null
		if root:
			cam_node = root.find_child("Camara", true, false)
			if not cam_node:
				cam_node = root.find_child("Camara2", true, false)
	if not cam_node:
		cam_node = get_tree().root.find_child("Camara", true, false)
	
	if cam_node:
		security_camera = cam_node.get_node_or_null("Camera3D") as Camera3D
		if not security_camera and cam_node is Camera3D:
			security_camera = cam_node

	if security_camera and security_cam_viewport:
		_setup_viewport_camera()


func _setup_viewport_camera() -> void:
	# Crear una cámara dentro del SubViewport que copie la posición de la de seguridad
	var vp_cam = Camera3D.new()
	vp_cam.name = "VPCamera"
	security_cam_viewport.add_child(vp_cam)
	
	# Actualizar la textura del material
	mat_on.albedo_texture = security_cam_viewport.get_texture()
	mat_on.emission_texture = security_cam_viewport.get_texture()


func _process(_delta: float) -> void:
	# Copiar la transform global de la cámara de seguridad al viewport camera
	if security_camera and security_cam_viewport:
		var vp_cam = security_cam_viewport.get_node_or_null("VPCamera") as Camera3D
		if vp_cam:
			vp_cam.global_transform = security_camera.global_transform
			vp_cam.fov = security_camera.fov

	# Siempre mostrar la textura en el monitor (pantalla siempre encendida)
	if security_cam_viewport and not is_viewing:
		screen_mesh.material = mat_on


static var active_monitor: StaticBody3D = null

func interact(player: Node3D) -> void:
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
		return {"text": "[E] Volver a tu vista\n[F] Visión Nocturna", "actionable": true}
	else:
		return {"text": "[E] Ver cámara de seguridad", "actionable": true}
