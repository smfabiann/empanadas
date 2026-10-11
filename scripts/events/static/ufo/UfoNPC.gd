class_name UfoNPC
extends NPC
## Controlador específico del cliente OVNI / Visitante Espacial.
## Entrada cinematográfica dramática:
## 1. Temblor premonitorio en pantalla anunciando algo extraño que se aproxima.
## 2. Destello blanco/cian cegador (flash) con estallido sónico (Star Wars hyperdrive stop / choque).
## 3. Aparición a lo lejos en el cielo frenando en seco bruscamente.
## 4. Desplazamiento lento y majestuoso por el firmamento hacia la tienda.
## 5. Descenso flotante suave hacia el mostrador, pedido y retirada cósmica hacia las estrellas.

enum ApproachPhase {
	PRE_RUMBLE,       ## 1. Temblor premonitorio anunciando algo extraño
	HYPER_FLASH,      ## 2. Flash cegador + estallido sónico (nave aún oculta)
	SUSPENSE_PAUSE,   ## 3. Silencio y tono misterioso tras el destello (nave aún oculta)
	FAR_EMERGENCE,    ## 4. Aparición repentina en el cielo lejano con frenado brusco (Star Wars stop)
	SKY_CRUISE,       ## 5. Desplazamiento lento por el firmamento hacia la tienda (visible por la ventana)
	DESCENT           ## 6. Descenso suave hacia la ventana/mostrador
}

@export_group("Entrada Dramática (Supersónica / Star Wars)")
## Duración del temblor premonitorio previo a la aparición (segundos)
@export_range(0.1, 5.0, 0.1) var rumble_duration: float = 2.0
## Intensidad máxima del temblor de pantalla in crescendo durante el pre-rumble
@export_range(0.01, 0.2, 0.01) var rumble_shake_intensity: float = 0.07
## Duración del destello inicial (segundos)
@export_range(0.1, 1.0, 0.05) var hyper_flash_duration: float = 0.35
## Intensidad de la sacudida de cámara por el impacto supersónico / flash
@export_range(0.02, 0.35, 0.01) var sonic_shake_intensity: float = 0.14
## Pausa de suspenso tras el destello antes de que la nave aparezca (segundos)
@export_range(0.1, 5.0, 0.1) var suspense_duration: float = 1.8
## Distancia en Z en la calle/cielo lejano donde la nave aparece y frena (metros)
@export var far_sky_distance: float = 26.0
## Altura en el cielo lejano calibrada para verse directo por la ventana de la tienda
@export var far_sky_height: float = 3.2
## Velocidad lenta de crucero en el cielo hacia la tienda (m/s)
@export_range(0.5, 10.0, 0.1) var sky_cruise_speed: float = 3.2
## Altura inicial del descenso sobre la calle frente a la tienda
@export var sky_descent_height: float = 2.2
## Distancia en Z antes de la ventana donde comienza a descender hacia el mostrador
@export var sky_descent_distance: float = 3.5

@export_group("Vuelo y Levitación")
## Altura sobre el suelo a la que la nave levita frente a la tienda
@export_range(0.5, 3.0, 0.05) var hover_height: float = 1.35
## Altura en el cielo donde aparece la nave inicialmente
@export_range(2.0, 25.0, 0.5) var sky_start_height: float = 3.2
## Velocidad de avance de la nave hacia el mostrador durante el descenso (m/s)
@export_range(0.5, 10.0, 0.1) var flight_speed: float = 2.0
## Frecuencia de la oscilación vertical (vaivén de flotación)
@export_range(0.5, 8.0, 0.1) var hover_frequency: float = 2.4
## Amplitud del vaivén vertical en metros
@export_range(0.01, 0.5, 0.01) var hover_amplitude: float = 0.10
## Inclinación máxima de la nave hacia adelante al avanzar (en radianes)
@export_range(0.0, 0.5, 0.01) var tilt_angle: float = 0.12
## Tambaleo lateral orgánico (wobble)
@export_range(0.0, 0.2, 0.01) var wobble_amplitude: float = 0.04
## Velocidad de rotación del anillo / platillo sobre su propio eje (rad/s)
@export_range(0.0, 10.0, 0.1) var saucer_spin_speed: float = 2.0

@export_group("Despegue / Retirada Cósmica")
## Si es true, la nave despega hacia el cielo estrellado al retirarse
@export var depart_to_sky: bool = true
## Duración del ascenso al retirarse (segundos)
@export_range(1.0, 10.0, 0.5) var depart_duration: float = 2.5
## Altura a la que sube antes de desvanecerse
@export_range(5.0, 30.0, 1.0) var depart_height: float = 16.0

@export_group("Apariencia Fosforescente")
## Color base alienígena
@export var alien_color: Color = Color(0.15, 1.0, 0.25, 1.0)
## Color de emisión de brillo cósmico
@export var emission_color: Color = Color(0.2, 1.0, 0.35, 1.0)
## Multiplicador de energía de emisión
@export_range(0.5, 8.0, 0.1) var emission_energy: float = 2.4

# Compatibilidad con inspectores y versiones previas
@export_group("Compatibilidad")
@export var enable_sky_descent: bool = true:
	get: return sky_start_height > 0.0
	set(val):
		if not val: sky_start_height = 0.0
@export var descent_height: float:
	get: return sky_start_height
	set(val): sky_start_height = val
@export var descent_duration: float = 2.5

@onready var ship_pivot: Node3D = get_node_or_null("ShipPivot")
@onready var saucer_rim: Node3D = get_node_or_null("ShipPivot/SaucerRim")
@onready var tractor_beam: SpotLight3D = get_node_or_null("ShipPivot/TractorBeam")
@onready var anim_player: AnimationPlayer = get_node_or_null("AnimationPlayer")

var current_phase: ApproachPhase = ApproachPhase.PRE_RUMBLE
var _phase_timer: float = 0.0
var _time_elapsed: float = 0.0
var _departure_tween: Tween = null
var _glow_light: OmniLight3D = null

# Waypoints de navegación dramática
var _hyper_origin_pos: Vector3 = Vector3.ZERO
var _far_sky_pos: Vector3 = Vector3.ZERO
var _sky_descent_pos: Vector3 = Vector3.ZERO
var _target_hover_pos: Vector3 = Vector3.ZERO


func _ready() -> void:
	custom_appearance = true
	collision_mask = 0 # No colisiona con veredas ni suelo al levitar

	_calc_waypoints()

	# Posicionar inicialmente en el punto de hiperespacio distante (oculto durante el rumble previo)
	global_position = _hyper_origin_pos
	visible = false

	_apply_phosphorescent_appearance()

	if anim_player and anim_player.has_animation("ufo_pulse"):
		anim_player.play("ufo_pulse")

	_start_rumble_phase()


func _calc_waypoints() -> void:
	var base_target := target_pos if target_pos != Vector3.ZERO else Vector3(-0.43, 0.2, -4.5)

	# 1. Punto final frente al mostrador (a la altura de atención)
	_target_hover_pos = base_target + Vector3(0.0, hover_height, 0.0)

	# 2. Punto cercano en el aire donde inicia la bajada hacia el mostrador
	_sky_descent_pos = Vector3(
		base_target.x,
		base_target.y + sky_descent_height,
		base_target.z - sky_descent_distance
	)

	# 3. Punto en el cielo lejano donde la nave frena en seco tras emerger
	# Calibrado milimétricamente para estar dentro de la abertura de la ventana frontal (Y ~ 2.26)
	_far_sky_pos = Vector3(
		base_target.x,
		base_target.y + far_sky_height,
		base_target.z - far_sky_distance
	)

	# 4. Origen lejano del streak supersónico
	_hyper_origin_pos = Vector3(
		base_target.x,
		base_target.y + far_sky_height + 1.2,
		base_target.z - far_sky_distance - 12.0
	)


func _start_rumble_phase() -> void:
	current_phase = ApproachPhase.PRE_RUMBLE
	_phase_timer = 0.0
	visible = false

	# Sacudir la cámara del jugador in crescendo
	var player := _get_player()
	if player and player.has_method("shake_camera_crescendo"):
		player.shake_camera_crescendo(rumble_duration, rumble_shake_intensity)

	# Zumbido sordo premonitorio
	if SFXManager and SFXManager.has_method("play_cosmic_rumble"):
		SFXManager.play_cosmic_rumble(rumble_duration)


func _apply_phosphorescent_appearance() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = alien_color
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = emission_energy

	if body_mesh:
		body_mesh.material = mat
	if head:
		head.material = mat

	# Luz ambiental verde que emana del platillo / visitante
	_glow_light = get_node_or_null("ShipPivot/AlienGlow") as OmniLight3D
	if _glow_light == null:
		_glow_light = get_node_or_null("AlienGlow") as OmniLight3D
	if _glow_light == null:
		_glow_light = OmniLight3D.new()
		_glow_light.name = "AlienGlow"
		_glow_light.light_color = emission_color
		_glow_light.light_energy = 1.8
		_glow_light.omni_range = 4.5
		_glow_light.position = Vector3(0.0, 0.6, 0.0)
		if ship_pivot:
			ship_pivot.add_child(_glow_light)
		else:
			add_child(_glow_light)


func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	_apply_hover_bobbing(delta)

	match state:
		State.APPROACHING:
			_process_approaching(delta)

		State.WAITING:
			_update_patience(delta)
			_look_at_counter(delta)

		State.REACTING:
			velocity = Vector3.ZERO

		State.LEAVING:
			if not depart_to_sky:
				_move_toward_point(exit_pos, delta)
				if _is_close_to(exit_pos) or global_position.z <= -4.8:
					_fade_and_free()


func _apply_hover_bobbing(delta: float) -> void:
	if not ship_pivot or not visible:
		return

	# Vaivén vertical sinusoidal continuo
	var bob_y := sin(_time_elapsed * hover_frequency) * hover_amplitude
	ship_pivot.position.y = bob_y

	# Tambaleo orgánico en rotación (balanceo y cabeceo cósmico)
	var roll := sin(_time_elapsed * (hover_frequency * 0.8)) * wobble_amplitude
	var pitch := cos(_time_elapsed * (hover_frequency * 0.6)) * (wobble_amplitude * 0.7)

	# Inclinación hacia adelante basada en la velocidad de traslación
	var speed_ratio := clampf(velocity.length() / maxf(flight_speed, 0.1), 0.0, 1.0)
	var forward_tilt := -speed_ratio * tilt_angle

	ship_pivot.rotation.x = forward_tilt + pitch
	ship_pivot.rotation.z = roll

	# Giro constante del anillo de propulsión de la nave
	if saucer_rim:
		saucer_rim.rotate_y(saucer_spin_speed * delta)


func _process_approaching(delta: float) -> void:
	_phase_timer += delta

	match current_phase:
		ApproachPhase.PRE_RUMBLE:
			if _phase_timer >= rumble_duration:
				_trigger_hyper_flash()

		ApproachPhase.HYPER_FLASH:
			if _phase_timer >= hyper_flash_duration:
				_start_suspense_pause()

		ApproachPhase.SUSPENSE_PAUSE:
			if _phase_timer >= suspense_duration:
				_trigger_far_emergence()

		ApproachPhase.FAR_EMERGENCE:
			_process_far_emergence_braking(delta)

		ApproachPhase.SKY_CRUISE:
			_process_sky_cruise(delta)

		ApproachPhase.DESCENT:
			_process_descent(delta)


## Fase 2: Flash cegador + estallido sónico en el cielo (la nave todavía no se ve)
func _trigger_hyper_flash() -> void:
	current_phase = ApproachPhase.HYPER_FLASH
	_phase_timer = 0.0
	visible = false

	# 1. Flash blanco/cian a pantalla completa
	_create_screen_flash()

	# 2. Sonido de choque supersónico / Star Wars shock boom
	if SFXManager and SFXManager.has_method("play_sonic_boom"):
		SFXManager.play_sonic_boom()

	# 3. Temblor de impacto en la cámara
	var player := _get_player()
	if player and player.has_method("shake_camera"):
		player.shake_camera(0.65, sonic_shake_intensity)


## Fase 3: Pausa de suspenso cósmico tras el flash (la nave sigue oculta)
func _start_suspense_pause() -> void:
	current_phase = ApproachPhase.SUSPENSE_PAUSE
	_phase_timer = 0.0
	visible = false

	# Silencio y tono misterioso alienígena que añade suspenso antes de ver qué causó el estruendo
	if SFXManager and SFXManager.has_method("play_alien_suspense"):
		SFXManager.play_alien_suspense(suspense_duration)


## Fase 4: Aparición a lo lejos en el cielo frenando en seco bruscamente
func _trigger_far_emergence() -> void:
	current_phase = ApproachPhase.FAR_EMERGENCE
	_phase_timer = 0.0
	visible = true
	global_position = _hyper_origin_pos

	# Destello puntual 3D en el cielo lejano visible desde la ventana
	_create_sky_flash_light(_far_sky_pos)


func _process_far_emergence_braking(_delta: float) -> void:
	const BRAKE_TIME := 0.35
	var t: float = clampf(_phase_timer / BRAKE_TIME, 0.0, 1.0)
	# Frenada abrupta exponencial / Star Wars stop
	var ease_t: float = 1.0 - pow(1.0 - t, 4.0)
	global_position = _hyper_origin_pos.lerp(_far_sky_pos, ease_t)

	# Inercia de frenada brusca en la rotación
	if ship_pivot:
		ship_pivot.rotation.x = -0.32 * (1.0 - t)

	if _phase_timer >= BRAKE_TIME:
		global_position = _far_sky_pos
		if ship_pivot:
			ship_pivot.rotation.x = 0.0
		current_phase = ApproachPhase.SKY_CRUISE
		_phase_timer = 0.0


## Fase 5: Desplazamiento lento por el firmamento hacia la tienda (visible por la ventana)
func _process_sky_cruise(delta: float) -> void:
	var diff := _sky_descent_pos - global_position
	var dist := diff.length()

	# Llegada al punto sobre la calle cerca de la tienda para iniciar el descenso
	if dist < 0.35:
		current_phase = ApproachPhase.DESCENT
		_phase_timer = 0.0
		return

	var dir := diff.normalized()
	velocity = dir * sky_cruise_speed
	global_position += velocity * delta

	_look_towards(_sky_descent_pos, delta)


## Fase 6: Descenso suave y gradual hacia el mostrador de atención
func _process_descent(delta: float) -> void:
	var diff := _target_hover_pos - global_position
	var dist := diff.length()

	# Llegada al mostrador
	if dist < 0.22:
		global_position = _target_hover_pos
		velocity = Vector3.ZERO
		_arrive_at_counter()
		return

	var dir := diff.normalized()
	var current_speed := flight_speed
	if dist < 1.8:
		current_speed = maxf(flight_speed * (dist / 1.8), 0.6)

	var step := dir * current_speed * delta
	if step.length() >= dist:
		global_position = _target_hover_pos
		velocity = Vector3.ZERO
		_arrive_at_counter()
		return

	global_position += step
	velocity = dir * current_speed

	_look_towards(_target_hover_pos, delta)


func _create_screen_flash() -> void:
	var tree := get_tree()
	if tree == null or tree.root == null:
		return

	var canvas := CanvasLayer.new()
	canvas.layer = 95
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.color = Color(0.92, 1.0, 0.98, 0.95)
	canvas.add_child(rect)
	tree.root.add_child.call_deferred(canvas)

	var tween := create_tween()
	tween.tween_interval(0.05)
	tween.tween_property(rect, "color:a", 0.0, 0.55)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_callback(canvas.queue_free)


func _create_sky_flash_light(pos: Vector3) -> void:
	var p := get_parent()
	if p == null:
		return

	var flash_light := OmniLight3D.new()
	flash_light.light_color = Color(0.35, 1.0, 0.75, 1.0)
	flash_light.light_energy = 8.5
	flash_light.omni_range = 45.0
	flash_light.position = pos
	p.add_child.call_deferred(flash_light)

	var tw := create_tween()
	tw.tween_property(flash_light, "light_energy", 0.0, 0.5)\
		.set_trans(Tween.TRANS_EXPO)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash_light.queue_free)


func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player") if get_tree() else null


func _look_towards(target: Vector3, delta: float) -> void:
	var look_pos := Vector3(target.x, global_position.y, target.z)
	if global_position.distance_squared_to(look_pos) > 0.01:
		var target_basis := Transform3D().looking_at(look_pos - global_position, Vector3.UP).basis
		transform.basis = transform.basis.slerp(target_basis, delta * 4.0)


func _look_at_counter(delta: float) -> void:
	var face_dir := Vector3(0.0, 0.0, 1.0)
	var target_basis := Transform3D().looking_at(face_dir, Vector3.UP).basis
	transform.basis = transform.basis.slerp(target_basis, delta * 3.0)


func _arrive_at_counter() -> void:
	super._arrive_at_counter()
	if label:
		label.text = "👽 ⟒⋔⌿⏃⋏⏃⎅⏃⌇... Saludos terrícola!\nQuiero: %s\n(%s)" % [
			order_recipe.get("name", "Completo"),
			order_recipe.get("desc", "")
		]
		label.modulate = Color(0.25, 1.0, 0.45, 1.0)


func _start_leaving() -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	is_at_counter = false
	if label:
		label.visible = false
	if patience_bar_pivot:
		patience_bar_pivot.visible = false
	collision_mask = 0

	if active_event:
		active_event.on_leave(self)

	if depart_to_sky:
		_start_sky_departure()
	else:
		super._start_leaving()


func _start_sky_departure() -> void:
	if _departure_tween and _departure_tween.is_valid():
		_departure_tween.kill()

	_departure_tween = create_tween().set_parallel(true)
	var sky_target := global_position + Vector3(0.0, depart_height, -8.0)
	_departure_tween.tween_property(self, "global_position", sky_target, depart_duration)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	_departure_tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), depart_duration)\
		.set_ease(Tween.EASE_IN)
	_departure_tween.chain().tween_callback(queue_free)


func _exit_tree() -> void:
	if _departure_tween and _departure_tween.is_valid():
		_departure_tween.kill()
