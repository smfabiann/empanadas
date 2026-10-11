class_name ExteriorBulp
extends Node3D
## Controlador de parpadeo intermitente para lámpara fluorescente exterior defectuosa.
## Optimizado para rendimiento: no utiliza _process() continuo, sino un Timer
## y Tweens puntuales que orquestan micro-cortes y fluctuaciones de tensión.

@export_group("Configuración de Iluminación")
## Energía base normal de la luz (si es 0.0, toma el valor inicial del OmniLight3D)
@export_range(0.0, 10.0, 0.1) var base_energy: float = 0.0

## Tiempo mínimo en segundos entre eventos de parpadeo
@export_range(0.5, 30.0, 0.5) var min_interval: float = 2.0

## Tiempo máximo en segundos entre eventos de parpadeo
@export_range(1.0, 60.0, 0.5) var max_interval: float = 6.5

## Sincronizar el brillo del material de la ampolleta (CSGSphere3D) con la luz
@export var sync_bulb_mesh: bool = true

@onready var omni_light: OmniLight3D = get_node_or_null("OmniLight3D") as OmniLight3D
@onready var timer: Timer = get_node_or_null("Timer") as Timer
@onready var bulb_mesh: GeometryInstance3D = get_node_or_null("CSGSphere3D") as GeometryInstance3D

var _bulb_material: StandardMaterial3D = null
var _base_bulb_color: Color = Color.WHITE
var _flicker_tween: Tween = null


func _ready() -> void:
	# 1. Detectar o fijar la energía base de la luz
	if omni_light:
		if base_energy <= 0.0:
			base_energy = omni_light.light_energy
		else:
			omni_light.light_energy = base_energy

	# 2. Duplicar y registrar el material de la ampolleta para variar su brillo al unísono
	if sync_bulb_mesh and bulb_mesh and bulb_mesh.material is StandardMaterial3D:
		_bulb_material = bulb_mesh.material.duplicate() as StandardMaterial3D
		bulb_mesh.material = _bulb_material
		_base_bulb_color = _bulb_material.albedo_color

	# 3. Configurar Timer para orquestar los intervalos sin consumir CPU en _process
	if timer:
		timer.one_shot = true
		timer.timeout.connect(_on_timer_timeout)
		_schedule_next_flicker()
	else:
		_schedule_fallback_timer()


func _exit_tree() -> void:
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()


## Programa el próximo parpadeo tras un intervalo aleatorio
func _schedule_next_flicker() -> void:
	if not is_inside_tree():
		return

	var wait_time: float = randf_range(min_interval, max_interval)
	if timer:
		timer.start(wait_time)
	else:
		_schedule_fallback_timer()


func _schedule_fallback_timer() -> void:
	var wait_time: float = randf_range(min_interval, max_interval)
	get_tree().create_timer(wait_time).timeout.connect(_on_timer_timeout)


## Se dispara cuando la lámpara decide fallar temporalmente
func _on_timer_timeout() -> void:
	if not is_inside_tree() or omni_light == null:
		return

	# Detener tween previo si siguiera en ejecución
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()

	_flicker_tween = create_tween()

	# Selección aleatoria entre 3 coreografías clásicas de tubo/ampolleta defectuosa
	var pattern: int = randi() % 3

	match pattern:
		0:
			# Patrón 1: Fluctuación previa (caída leve de tensión), micro-corte y encendido con rebote
			var dim_energy: float = base_energy * randf_range(0.45, 0.65)
			_flicker_tween.tween_callback(func(): _set_light_energy(dim_energy))
			_flicker_tween.tween_interval(randf_range(0.06, 0.12))
			_flicker_tween.tween_callback(func(): _set_light_energy(0.0)) # Corte instantáneo
			_flicker_tween.tween_interval(randf_range(0.03, 0.05))
			_flicker_tween.tween_callback(func(): _set_light_energy(base_energy * 1.08)) # Leve sobretensión
			_flicker_tween.tween_interval(0.03)
			_flicker_tween.tween_callback(func(): _set_light_energy(base_energy))

		1:
			# Patrón 2: Doble chispeo / corte intermitente rápido del cebador
			var dim_energy1: float = base_energy * randf_range(0.5, 0.7)
			_flicker_tween.tween_callback(func(): _set_light_energy(dim_energy1))
			_flicker_tween.tween_interval(0.05)
			_flicker_tween.tween_callback(func(): _set_light_energy(0.0))
			_flicker_tween.tween_interval(0.03)
			_flicker_tween.tween_callback(func(): _set_light_energy(base_energy * 0.75))
			_flicker_tween.tween_interval(0.04)
			_flicker_tween.tween_callback(func(): _set_light_energy(0.0))
			_flicker_tween.tween_interval(0.04)
			_flicker_tween.tween_callback(func(): _set_light_energy(base_energy))

		2:
			# Patrón 3: Parpadeo seco rápido con caída de tensión post-corte
			_flicker_tween.tween_callback(func(): _set_light_energy(0.0))
			_flicker_tween.tween_interval(0.04)
			_flicker_tween.tween_callback(func(): _set_light_energy(base_energy * 0.6))
			_flicker_tween.tween_interval(0.08)
			_flicker_tween.tween_callback(func(): _set_light_energy(base_energy))

	# Al terminar el ciclo de parpadeo, programar el siguiente evento
	_flicker_tween.tween_callback(_schedule_next_flicker)


## Ajusta sincronizadamente la energía de la luz y el brillo del material de la ampolleta
func _set_light_energy(energy: float) -> void:
	if omni_light:
		omni_light.light_energy = energy

	if _bulb_material and base_energy > 0.0:
		var ratio: float = clampf(energy / base_energy, 0.0, 1.2)
		_bulb_material.albedo_color = _base_bulb_color * ratio
