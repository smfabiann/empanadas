class_name GlitchSpriteAnomaly
extends AnomalyBase
## Anomalía de Distorsión Espectral — ejemplo funcional modular.
## Al activarse distorsiona el ambiente del juego: las luces parpadean,
## la niebla aumenta, un overlay de aberración cromática cubre la pantalla
## y un sprite "fantasma" con glitch aparece en el HUD de forma errática.
## Se resuelve automáticamente tras un tiempo o al cerrar la persiana.

@export_group("Configuración Visual Específica")
## Duración de la manifestación (segundos)
@export var manifestation_duration: float = 8.0
## Intensidad del efecto de oscurecimiento ambiental (0.0 = nada, 1.0 = apagar luces)
@export_range(0.0, 1.0, 0.05) var darkness_intensity: float = 0.7
## Intensidad del parpadeo de luces (frecuencia)
@export_range(0.0, 5.0, 0.1) var flicker_speed: float = 3.0
## Si es true, produce un sonido tenso al manifestarse
@export var play_tension_sound: bool = true
## Si es true, la niebla se espesa durante la anomalía
@export var thicken_fog: bool = true

@onready var glitch_sprite: Sprite2D = $Visuals2D.get_node_or_null("GlitchSprite") as Sprite2D
@onready var warning_label: Label = $Visuals2D.get_node_or_null("WarningLabel") as Label
@onready var screen_overlay: ColorRect = $Visuals2D.get_node_or_null("ScreenOverlay") as ColorRect

# Estado ambiental original para restaurar
var _original_ambient_energy: float = 0.4
var _original_fog_density: float = 0.015
var _original_fog_color: Color = Color(0.05, 0.03, 0.08, 1)
var _original_dir_light_energy: float = 0.1
var _flicker_tween: Tween = null
var _jitter_tween: Tween = null
var _elapsed: float = 0.0


func _ready() -> void:
	auto_resolve_duration = manifestation_duration
	super._ready()


## 1. Inicialización: Captura estado ambiental original y configura visuales
func _init_anomaly(context: Dictionary = {}) -> void:
	super._init_anomaly(context)

	# Capturar estado ambiental original para poder restaurarlo
	_capture_environment_state()

	# Configurar el overlay de pantalla completa (aberración cromática / tinte rojo)
	if screen_overlay:
		screen_overlay.visible = false
		screen_overlay.modulate.a = 0.0

	# Configurar el sprite fantasma
	if glitch_sprite:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		glitch_sprite.position = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.35)
		glitch_sprite.modulate.a = 0.0
		glitch_sprite.visible = true

	if warning_label:
		warning_label.text = "⚠️ [ANOMALÍA DETECTADA: DISTORSIÓN ESPECTRAL] ⚠️"
		warning_label.modulate.a = 0.0


## 2. Ejecución: Dispara la distorsión ambiental y efectos visuales
func execute_behavior() -> void:
	super.execute_behavior()

	# Sonido de tensión al manifestarse
	if play_tension_sound and SFXManager:
		SFXManager.play_tense_anger()

	# a) Distorsionar el ambiente (oscurecer luces, aumentar niebla)
	_distort_environment()

	# b) Activar overlay de pantalla
	_activate_screen_overlay()

	# c) Mostrar el warning con fade-in
	_show_warning_label()

	# d) Animar el sprite fantasma con jitter errático
	_animate_glitch_sprite()

	# e) Iniciar parpadeo de luces
	_start_light_flicker()


## Animación procedural del sprite con temblor errático y parpadeo
func _animate_glitch_sprite() -> void:
	if glitch_sprite == null:
		return

	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var center: Vector2 = Vector2(viewport_size.x * 0.5, viewport_size.y * 0.35)
	glitch_sprite.position = center
	glitch_sprite.scale = Vector2(0.3, 0.3)

	# Fade in rápido
	var appear_tween: Tween = create_tween()
	appear_tween.tween_property(glitch_sprite, "modulate:a", 0.85, 0.15).set_trans(Tween.TRANS_BOUNCE)
	appear_tween.parallel().tween_property(glitch_sprite, "scale", Vector2(0.5, 0.5), 0.2)

	# Jitter continuo durante toda la manifestación
	await appear_tween.finished
	_start_jitter_loop(center)


## Bucle de jitter: el sprite salta de posición erráticamente
func _start_jitter_loop(center: Vector2) -> void:
	if not is_active or is_resolved or glitch_sprite == null:
		return

	_jitter_tween = create_tween()
	_jitter_tween.set_loops(int(manifestation_duration / 0.15))

	for i in range(int(manifestation_duration / 0.15)):
		var offset: Vector2 = Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
		_jitter_tween.tween_property(glitch_sprite, "position", center + offset, 0.08)
		_jitter_tween.tween_property(glitch_sprite, "rotation_degrees", randf_range(-15.0, 15.0), 0.07)
		# Parpadeo aleatorio del alfa
		var target_alpha: float = randf_range(0.3, 0.95)
		_jitter_tween.parallel().tween_property(glitch_sprite, "modulate:a", target_alpha, 0.06)


## Distorsiona el ambiente: oscurece luces y espesa la niebla
func _distort_environment() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	var world_env := tree.root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		var tween: Tween = create_tween().set_parallel(true)
		# Oscurecer luz ambiental
		tween.tween_property(env, "ambient_light_energy",
			_original_ambient_energy * (1.0 - darkness_intensity), 0.8)
		# Aumentar niebla
		if thicken_fog:
			tween.tween_property(env, "fog_density",
				_original_fog_density * 4.0, 1.0)
			tween.tween_property(env, "fog_light_color",
				Color(0.15, 0.02, 0.05, 1), 1.2)

	# Oscurecer luz direccional
	var dir_light := tree.root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		create_tween().tween_property(dir_light, "light_energy",
			_original_dir_light_energy * 0.2, 0.6)


## Overlay de aberración cromática / tinte rojo a pantalla completa
func _activate_screen_overlay() -> void:
	if screen_overlay == null:
		return
	screen_overlay.visible = true
	screen_overlay.color = Color(0.6, 0.0, 0.05, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(screen_overlay, "color:a", 0.12, 0.5)
	tween.tween_property(screen_overlay, "color:a", 0.06, 0.3)
	tween.set_loops(3)


## Muestra el texto de alerta con un fade-in/out cíclico
func _show_warning_label() -> void:
	if warning_label == null:
		return
	warning_label.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(warning_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(warning_label, "modulate:a", 0.3, 0.5)
	tween.tween_property(warning_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.0)
	tween.tween_property(warning_label, "modulate:a", 0.0, 0.8)


## Parpadeo errático de luces durante la anomalía
func _start_light_flicker() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	var omni_lights: Array = []
	for child in tree.root.find_children("*", "OmniLight3D", true, false):
		omni_lights.append(child)
	var spot_lights: Array = []
	for child in tree.root.find_children("*", "SpotLight3D", true, false):
		spot_lights.append(child)

	if omni_lights.is_empty() and spot_lights.is_empty():
		return

	_flicker_tween = create_tween()
	var flicker_steps: int = int(manifestation_duration * flicker_speed)
	for i in range(flicker_steps):
		var intensity_mult: float = randf_range(0.1, 1.2)
		for light in omni_lights:
			if is_instance_valid(light):
				_flicker_tween.parallel().tween_property(light, "light_energy",
					light.light_energy * intensity_mult, 0.05 + randf() * 0.1)
		for light in spot_lights:
			if is_instance_valid(light):
				_flicker_tween.parallel().tween_property(light, "light_energy",
					light.light_energy * intensity_mult, 0.05 + randf() * 0.1)
		_flicker_tween.tween_interval(0.1 + randf() * 0.2)


## Captura el estado ambiental original para restaurar al resolver
func _capture_environment_state() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	var world_env := tree.root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		_original_ambient_energy = env.ambient_light_energy
		_original_fog_density = env.fog_density
		_original_fog_color = env.fog_light_color

	var dir_light := tree.root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		_original_dir_light_energy = dir_light.light_energy


## 3. Resolución: Restaura el ambiente, oculta visuales y limpia
func resolve() -> void:
	if is_resolved:
		return

	# Detener tweens activos
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()
	if _jitter_tween and _jitter_tween.is_valid():
		_jitter_tween.kill()

	# Ocultar warning
	if warning_label:
		warning_label.modulate.a = 0.0

	# Fade out del overlay
	if screen_overlay:
		var overlay_tween: Tween = create_tween()
		overlay_tween.tween_property(screen_overlay, "color:a", 0.0, 0.3)

	# Fade out del sprite
	if glitch_sprite:
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(glitch_sprite, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
		fade_tween.parallel().tween_property(glitch_sprite, "scale", Vector2(0.1, 0.1), 0.4)
		await fade_tween.finished

	# Restaurar el ambiente a sus valores originales
	_restore_environment()

	# Esperar un instante para la restauración visual antes de liberar
	await get_tree().create_timer(0.3).timeout

	super.resolve()


## Restaura luces, niebla y ambiente a sus valores originales
func _restore_environment() -> void:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return

	var world_env := tree.root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if world_env and world_env.environment:
		var env := world_env.environment
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(env, "ambient_light_energy", _original_ambient_energy, 1.0)
		tween.tween_property(env, "fog_density", _original_fog_density, 1.2)
		tween.tween_property(env, "fog_light_color", _original_fog_color, 1.0)

	var dir_light := tree.root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	if dir_light:
		create_tween().tween_property(dir_light, "light_energy", _original_dir_light_energy, 0.8)

	# Restaurar OmniLights y SpotLights via GameManager defaults
	if GameManager:
		GameManager.restore_environment(tree)


# =========================================================
#  GANCHOS DE INTEGRACIÓN REACTIVA
# =========================================================

func on_customer_served(_npc: CharacterBody3D, _is_correct: bool) -> void:
	# Resolver la anomalía inmediatamente si se atiende al cliente
	resolve()


func on_persiana_closed() -> void:
	# El cierre de persiana ahuyenta la anomalía
	resolve()
