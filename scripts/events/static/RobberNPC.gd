class_name RobberNPC
extends NPC
## Controlador específico del cliente Ladrón.
## Funciona como un minijuego de secuencia: exige una lista ordenada de items
## bajo amenaza armada antes de que se le agote la paciencia.

@export_group("Minijuego de Secuencia")
## Lista ordenada de items que exigirá el ladrón (por defecto: Completo, Bebida, Empanada)
@export var item_sequence: Array[ItemData] = [
	preload("res://resources/items/completo.tres"),
	preload("res://resources/items/bebida.tres"),
	preload("res://resources/items/empanada.tres"),
]
## Si es true, genera una secuencia aleatoria en cada aparición en lugar de la fija
@export var randomize_sequence: bool = false
## Cantidad de items a generar si randomize_sequence está activo
@export var random_sequence_count: int = 3
## Tiempo de paciencia (en segundos) disponible para cada ítem de la secuencia
@export var patience_per_item: float = 20.0
## Cantidad de segundos de paciencia descontados al entregar un ítem incorrecto
@export var wrong_item_patience_penalty: float = 5.0
## Si es true, el ladrón intentará robar si se le agota la paciencia
@export var steal_on_timeout: bool = true

@export_group("Puntos de Manipulación del Arma (Handles)")
## Referencia al nodo del arma (se busca $Gun automáticamente si está vacío)
@export var gun: Node3D
## Marker3D opcional para posicionar el arma al apuntar de forma visual en el visor 3D
@export var gun_aim_marker: Marker3D
## Marker3D opcional para posicionar el arma enfundada de forma visual en el visor 3D
@export var gun_hidden_marker: Marker3D
## Coordenadas relativas donde apunta el arma (usadas si no hay Marker asignado)
@export var gun_aim_position: Vector3 = Vector3(0.44, 1.285, -0.425)
## Coordenadas relativas donde se enfunda el arma (usadas si no hay Marker asignado)
@export var gun_hidden_position: Vector3 = Vector3(0.2, 0.8, 0.0)

@export_group("Efecto Ambiental")
## Si es true, oscurece sutilmente el entorno cuando el ladrón está presente
@export var dim_environment_on_appear: bool = true
## Duración de la transición al oscurecer (segundos)
@export var dim_transition_duration: float = 2.0
## Duración de la transición al restaurar la iluminación (segundos)
@export var restore_transition_duration: float = 2.5
## Energía de la luz ambiente durante la presencia del ladrón
@export var dimmed_ambient_energy: float = 0.16
## Energía de la luz direccional durante la presencia del ladrón
@export var dimmed_dir_light_energy: float = 0.03
## Energía de la luz del techo durante la presencia del ladrón
@export var dimmed_ceiling_light_energy: float = 1.5
## Densidad de niebla durante la presencia del ladrón
@export var dimmed_fog_density: float = 0.025

var current_step: int = 0
var is_game_over: bool = false
var is_about_to_shoot: bool = false
var _shot_cancelled: bool = false
var _approach_tween: Tween = null
var _shake_tween: Tween = null

var _env_tween: Tween = null
var _orig_ambient_energy: float = -1.0
var _orig_ambient_color: Color = Color.WHITE
var _orig_fog_density: float = -1.0
var _orig_fog_color: Color = Color.WHITE
var _orig_dir_light_energy: float = -1.0
var _orig_ceiling_light_energy: float = -1.0
var _has_captured_original: bool = false
var _is_environment_dimmed: bool = false


func get_aim_pos() -> Vector3:
	return gun_aim_marker.position if gun_aim_marker != null else gun_aim_position


func get_hidden_pos() -> Vector3:
	return gun_hidden_marker.position if gun_hidden_marker != null else gun_hidden_position


func _ready() -> void:
	custom_appearance = true
	if gun == null:
		gun = get_node_or_null("Gun") as Node3D
	# Ocultar el arma al aparecer y situarla en posición enfundada
	if gun:
		gun.visible = false
		gun.position = get_hidden_pos()
	super._ready()
	_dim_environment()


func _exit_tree() -> void:
	if _is_environment_dimmed and not is_game_over:
		if _env_tween and _env_tween.is_valid():
			_env_tween.kill()
		GameManager.restore_environment(get_tree())
		_is_environment_dimmed = false


func can_react_to_persiana() -> bool:
	return not _is_order_resolved and (is_at_counter or is_about_to_shoot) and not is_game_over and state != State.LEAVING


func can_receive_item() -> bool:
	return super.can_receive_item() and not is_game_over and not is_about_to_shoot


## Se ejecuta cuando el ladrón llega al mostrador de la tienda
func _arrive_at_counter() -> void:
	super._arrive_at_counter()
	
	# Inicializar la secuencia del minijuego
	_setup_sequence()

	# Mostrar y desenfundar suavemente el arma con un Tween
	if gun:
		gun.visible = true
		var tween := create_tween()
		tween.tween_property(gun, "position", get_aim_pos(), 0.35)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)
	
	# Configurar el primer pedido y la paciencia
	_start_current_step()


var robber_recipes: Array[Dictionary] = [
	{
		"name": "Completo Italiano",
		"desc": "Palta + Mayo",
		"palta": true,
		"mayo": true,
		"ketchup": false
	},
	{
		"name": "Completo con Todo",
		"desc": "Palta + Mayo + Kétchup",
		"palta": true,
		"mayo": true,
		"ketchup": true
	}
]


## Prepara la lista de pedidos de completos para el atraco (HU-11)
func _setup_sequence() -> void:
	current_step = 0


## Configura el completo actual que exige el ladrón
func _start_current_step() -> void:
	if current_step < robber_recipes.size():
		var rec: Dictionary = robber_recipes[current_step]
		requested_item = ItemData.new()
		requested_item.id = "completo"
		requested_item.display_name = "%s (%s)" % [rec["name"], rec["desc"]]
		patience_time = patience_per_item
		patience_remaining = patience_time
		_update_robber_dialogue()


## Actualiza el texto en pantalla con el progreso de la secuencia
func _update_robber_dialogue() -> void:
	if not label or requested_item == null or is_game_over:
		return
	var progress := "[%d/%d]" % [current_step + 1, robber_recipes.size()]
	label.text = "😈 ¡Pasa ya: %s %s!" % [progress, requested_item.display_name]
	label.modulate = Color(1.0, 0.25, 0.25, 1.0)


## Se ejecuta cuando el jugador le entrega un item
func receive_item(item_node: Interactable) -> void:
	if not can_receive_item() or item_node == null:
		return

	var is_correct: bool = false
	if item_node != null and item_node.has_method("is_valid_base"):
		var comp = item_node
		if comp.is_valid_base() and current_step < robber_recipes.size():
			var rec: Dictionary = robber_recipes[current_step]
			is_correct = comp.matches_order(true, rec["palta"], rec["mayo"], rec["ketchup"])

	# Consumir el item entregado
	if item_node.get_parent():
		item_node.get_parent().remove_child(item_node)
	item_node.queue_free()

	if is_correct:
		current_step += 1
		
		if current_step < robber_recipes.size():
			# Pequeño salto de satisfacción y siguiente pedido
			var tween := create_tween()
			tween.tween_property(self, "scale", Vector3(1.1, 0.92, 1.1), 0.08)
			tween.tween_property(self, "scale", Vector3.ONE, 0.1).set_ease(Tween.EASE_OUT)
			
			_start_current_step()
		else:
			# ¡Minijuego completado con éxito!
			_is_order_resolved = true
			state = State.REACTING
			is_at_counter = false
			requested_item = null
			patience_bar_pivot.visible = false
			
			if label:
				label.text = "😈 ¡Trato hecho! Me voy satisfecho con mis completos... 💰"
				label.modulate = Color(0.2, 1.0, 0.4, 1.0)
			
			_holster_gun()
			GameManager.register_npc_served(true)
			await get_tree().create_timer(1.2).timeout
			if is_instance_valid(self):
				_start_leaving()
	else:
		# ¡Error! Iniciar secuencia de ira dramática antes de disparar
		_start_anger_sequence("¡Le diste un completo incorrecto al ladrón!")


## Secuencia cinemática de ira: oscurece el entorno, niebla densa, avanza lentamente y prepara disparo fatal
func _start_anger_sequence(reason: String) -> void:
	if is_game_over or is_about_to_shoot or _is_order_resolved:
		return
	is_about_to_shoot = true
	state = State.REACTING
	_shot_cancelled = false
	patience_bar_pivot.visible = false

	# 1. Diálogo de furia
	if label:
		label.text = "😠 ¿¿Qué es esto...?? ¡Te dije que no jugaras conmigo!"
		label.modulate = Color(1.0, 0.1, 0.1, 1.0)
		label.visible = true

	# Sonido tenso y amenazante
	SFXManager.play_tense_anger()

	# 2. Oscurecer el ambiente e incrementar la niebla rápidamente
	_darken_environment()

	# 3. El ladrón avanza muy poquito y lentamente hacia el mostrador / jugador
	if _approach_tween and _approach_tween.is_valid():
		_approach_tween.kill()
	_approach_tween = create_tween()
	_approach_tween.tween_property(self, "global_position:z", global_position.z + 0.38, 2.5)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	# Temblor sutil de rabia en su cuerpo
	if body_mesh:
		if _shake_tween and _shake_tween.is_valid():
			_shake_tween.kill()
		_shake_tween = create_tween()
		for i in range(10):
			var offset := 0.02 if i % 2 == 0 else -0.02
			_shake_tween.tween_property(body_mesh, "position:x", offset, 0.12)
		_shake_tween.tween_property(body_mesh, "position:x", 0.0, 0.1)

	# 4. Ventana de tensión para que el jugador reaccione y baje la persiana (evitando la muerte)
	await get_tree().create_timer(2.6).timeout

	# Si el jugador cerró la persiana a tiempo, se canceló el disparo: ¡EVITÓ LA MUERTE!
	if _shot_cancelled or not is_about_to_shoot:
		return

	# 5. Si no cerró la persiana, momento del disparo fatal y Game Over
	is_game_over = true
	is_at_counter = false
	is_about_to_shoot = false
	_execute_shot(reason)


## Captura los valores de luz y niebla actuales para poder restaurarlos fielmente al retirarse el ladrón
func _capture_original_environment() -> void:
	if _has_captured_original:
		return
	_has_captured_original = true

	var world_env := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		_orig_ambient_energy = world_env.environment.ambient_light_energy
		_orig_ambient_color = world_env.environment.ambient_light_color
		_orig_fog_density = world_env.environment.fog_density
		_orig_fog_color = world_env.environment.fog_light_color
	else:
		_orig_ambient_energy = GameManager.DEFAULT_AMBIENT_ENERGY
		_orig_ambient_color = GameManager.DEFAULT_AMBIENT_COLOR
		_orig_fog_density = GameManager.DEFAULT_FOG_DENSITY
		_orig_fog_color = GameManager.DEFAULT_FOG_COLOR

	var dir_light := get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		_orig_dir_light_energy = dir_light.light_energy
	else:
		_orig_dir_light_energy = GameManager.DEFAULT_DIR_LIGHT_ENERGY

	var ceiling_light := get_tree().root.find_child("CeilingLight", true, false) as Light3D
	if ceiling_light:
		_orig_ceiling_light_energy = ceiling_light.light_energy
	else:
		_orig_ceiling_light_energy = GameManager.DEFAULT_CEILING_LIGHT_ENERGY


## Atenúa suavemente el ambiente al aparecer el ladrón para generar atmósfera de tensión
func _dim_environment() -> void:
	if not dim_environment_on_appear or is_game_over:
		return

	_capture_original_environment()
	_is_environment_dimmed = true

	if _env_tween and _env_tween.is_valid():
		_env_tween.kill()
	_env_tween = create_tween().set_parallel(true)

	var world_env := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		_env_tween.tween_property(env, "ambient_light_energy", dimmed_ambient_energy, dim_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_env_tween.tween_property(env, "fog_density", dimmed_fog_density, dim_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var dir_light := get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		_env_tween.tween_property(dir_light, "light_energy", dimmed_dir_light_energy, dim_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var ceiling_light := get_tree().root.find_child("CeilingLight", true, false) as Light3D
	if ceiling_light:
		_env_tween.tween_property(ceiling_light, "light_energy", dimmed_ceiling_light_energy, dim_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Restaura suavemente el ambiente a sus valores normales cuando el ladrón se retira
func _restore_environment() -> void:
	if not _is_environment_dimmed or is_game_over:
		return

	if _env_tween and _env_tween.is_valid():
		_env_tween.kill()
	_env_tween = create_tween().set_parallel(true)

	var world_env := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		_env_tween.tween_property(env, "ambient_light_energy", _orig_ambient_energy, restore_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_env_tween.tween_property(env, "ambient_light_color", _orig_ambient_color, restore_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_env_tween.tween_property(env, "fog_density", _orig_fog_density, restore_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_env_tween.tween_property(env, "fog_light_color", _orig_fog_color, restore_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var dir_light := get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		_env_tween.tween_property(dir_light, "light_energy", _orig_dir_light_energy, restore_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var ceiling_light := get_tree().root.find_child("CeilingLight", true, false) as Light3D
	if ceiling_light:
		_env_tween.tween_property(ceiling_light, "light_energy", _orig_ceiling_light_energy, restore_transition_duration)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_env_tween.chain().tween_callback(func():
		_is_environment_dimmed = false
	)


## Oscurece las luces y eleva la niebla para bloquear la visibilidad más allá de la tienda
func _darken_environment() -> void:
	if _env_tween and _env_tween.is_valid():
		_env_tween.kill()

	var world_env := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		var tween := create_tween().set_parallel(true)
		# Oscurecer luz ambiente
		tween.tween_property(env, "ambient_light_energy", 0.05, 2.0)
		tween.tween_property(env, "ambient_light_color", Color(0.25, 0.04, 0.04, 1.0), 2.0)
		# Niebla densa
		env.fog_enabled = true
		tween.tween_property(env, "fog_density", 0.085, 2.0)
		tween.tween_property(env, "fog_light_color", Color(0.03, 0.01, 0.02, 1.0), 2.0)

	var dir_light := get_tree().root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		var ltween := create_tween()
		ltween.tween_property(dir_light, "light_energy", 0.01, 2.0)

	var ceiling_light := get_tree().root.find_child("CeilingLight", true, false) as Light3D
	if ceiling_light:
		var ctween := create_tween()
		ctween.tween_property(ceiling_light, "light_energy", 0.6, 2.0)


## Disparo fatal y caída del jugador
func _execute_shot(reason: String) -> void:
	if label:
		label.text = "💥 ¡BANG!"
		label.modulate = Color(1.0, 0.05, 0.05, 1.0)

	# Sonido de disparo
	SFXManager.play_gunshot()

	# Animación brusca de retroceso (recoil)
	if gun:
		var recoil_tween := create_tween()
		recoil_tween.tween_property(gun, "position", get_aim_pos() + Vector3(0.0, 0.1, 0.2), 0.04)
		recoil_tween.tween_property(gun, "rotation_degrees:x", -15.0, 0.04)
		recoil_tween.tween_property(gun, "position", get_aim_pos(), 0.16)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		recoil_tween.tween_property(gun, "rotation_degrees:x", 0.0, 0.16)

	# Derribar la cámara del jugador hacia el suelo (inclinada / ladeada)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("fall_down"):
		player.fall_down()

	# Disparar Game Over en el sistema
	GameManager.trigger_game_over(reason)
	get_tree().create_timer(0.35).timeout.connect(SFXManager.play_game_over)


## Guarda el arma suavemente
func _holster_gun() -> void:
	if gun and gun.visible:
		var tween := create_tween()
		tween.tween_property(gun, "position", get_hidden_pos(), 0.25)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_IN)
		tween.tween_callback(func(): if gun: gun.visible = false)


## Se ejecuta cuando el jugador cierra la persiana del mostrador frente al ladrón
func on_persiana_closed() -> void:
	if is_game_over or state == State.LEAVING or _is_order_resolved:
		return
	if state != State.WAITING and not is_about_to_shoot:
		return

	_is_order_resolved = true
	state = State.REACTING

	# Si estaba en la secuencia de ira a punto de disparar, el jugador salvó su vida
	var saved_from_death: bool = is_about_to_shoot
	_shot_cancelled = true
	is_about_to_shoot = false
	is_at_counter = false
	requested_item = null
	patience_bar_pivot.visible = false

	# Detener avance y temblores de ira previa si estaban activos
	if _approach_tween and _approach_tween.is_valid():
		_approach_tween.kill()
	if _shake_tween and _shake_tween.is_valid():
		_shake_tween.kill()
	if body_mesh:
		body_mesh.position.x = 0.0

	# Diálogo de furia y frustración (reacción especial si el jugador se salvó cerrando la persiana)
	if label:
		if saved_from_death:
			label.text = "💥 ¡CLANG! 🤬 ¡¿Cerraste la persiana?! ¡Te salvaste por ahora!"
		else:
			label.text = "🤬 ¡¿Me cerraste la persiana?! ¡Ya vas a ver!"
		label.modulate = Color(1.0, 0.2, 0.2, 1.0)
		label.visible = true

	# Sonido de indignación
	SFXManager.play_npc_timeout()

	# Reacción física de furia: temblor en el sitio
	if body_mesh:
		var shake_tween := create_tween()
		for i in range(5):
			var offset := 0.04 if i % 2 == 0 else -0.04
			shake_tween.tween_property(body_mesh, "position:x", offset, 0.05)
		shake_tween.tween_property(body_mesh, "position:x", 0.0, 0.05)

	# Enfunda el arma de inmediato
	_holster_gun()

	# Restaura la iluminación original
	_restore_environment()

	# Registrar que el cliente se retira
	GameManager.register_npc_left()

	# Breve pausa para transmitir la reacción antes de huir
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(self):
		# Escapa corriendo a gran velocidad
		speed = 6.5
		_start_leaving()


## Se ejecuta cuando se agota el tiempo de espera
func _timeout() -> void:
	if _is_order_resolved or state != State.WAITING or is_game_over or is_about_to_shoot:
		return
	_start_anger_sequence("¡Tardaste demasiado y el ladrón disparó!")


func _start_leaving() -> void:
	_holster_gun()
	_restore_environment()
	super._start_leaving()
