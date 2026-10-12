extends Node
## Gestor de ciclo día/noche y transición ambiental.
##
## Flujo de jornada (HU - Bucle de Días & Cama):
## 1. Durante la jornada de atención de clientes: Ambiente nocturno habitual (_night()).
## 2. Al atender al último cliente y finalizar el turno (day_ended):
##    El entorno transiciona muy lenta y sutilmente hacia una mañana suave / amanecer (_morning_preset()),
##    simulando que la noche termina y amanece mientras el jugador va a la cama.
## 3. Al interactuar con la cama para dormir (start_next_day):
##    Se restaura el ambiente nocturno regular (_night()) y continúa el nuevo día/noche.

## Duración en segundos de la transición sutil hacia la mañana al terminar la jornada
const MORNING_TRANSITION_SECONDS := 10.0

var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _sky_material: ShaderMaterial = null
var _tween: Tween = null


func _ready() -> void:
	_setup_signals()
	call_deferred("_prepare")


func _setup_signals() -> void:
	if GameManager == null:
		return
	if not GameManager.is_connected("day_ended", Callable(self, "_on_day_ended")):
		GameManager.day_ended.connect(_on_day_ended)
	if not GameManager.is_connected("day_started", Callable(self, "_on_day_started")):
		GameManager.day_started.connect(_on_day_started)
	if not GameManager.is_connected("day_advanced", Callable(self, "_on_day_advanced")):
		GameManager.day_advanced.connect(_on_day_advanced)


func _prepare() -> void:
	if _world_env != null:
		return
	var root := get_tree().root
	if root == null:
		return

	var env_node := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	_world_env = env_node
	if not _world_env or not _world_env.environment:
		return
	_sun = root.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	var sky := _world_env.environment.sky as Sky
	if sky:
		_sky_material = sky.sky_material as ShaderMaterial
	_apply_preset(_night(), true)


## Se dispara al terminar la jornada (tras atender al último cliente del día).
## Comienza la transición lenta y sutil hacia el amanecer/mañana suave.
func _on_day_ended(_day: int) -> void:
	if GameManager and GameManager.is_game_won:
		return
	transition_to_morning()


## Se dispara al comenzar un nuevo día (tras dormir o reiniciar).
## Asegura que el ambiente sea la noche habitual.
func _on_day_started(_day: int, _max_clients: int) -> void:
	restore_to_night(true)


func _on_day_advanced(_day: int, _max_clients: int) -> void:
	restore_to_night(true)


## Inicia la transición sutil y gradual hacia la mañana (amanecer)
func transition_to_morning(duration: float = -1.0) -> void:
	var dur := duration if duration > 0.0 else MORNING_TRANSITION_SECONDS
	if _tween and _tween.is_running():
		_tween.kill()

	var morning_items := _build_items(_morning_preset())
	if morning_items.is_empty():
		_apply_values(_morning_preset(), null)
		return

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_items(_tween, morning_items, dur)


## Restaura el ambiente al estado de noche regular.
## Si immediate es true, lo aplica de golpe (ideal durante la pantalla en negro al dormir).
func restore_to_night(immediate: bool = true) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if immediate:
		_apply_values(_night(), null)
	else:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween_items(tw, _build_items(_night()), 2.0)


# --- Presets -------------------------------------------------------------

## Ambiente de noche regular de trabajo
func _night() -> Dictionary:
	return {
		"sky_top": Vector3(0.01, 0.02, 0.05),
		"horizon": Vector3(0.059, 0.083, 0.14),
		"ground": Vector3(0.01, 0.015, 0.02),
		"stars": 30.0,
		"star_brightness": 2.0,
		"ambient_energy": 0.4,
		"ambient_color": Vector3(0.85, 0.78, 0.6),
		"sun_energy": 0.001,
		"sun_color": Vector3(0.7, 0.72, 0.9),
		"fog_density": 0.1,
		"fog_color": Vector3(0.02, 0.02, 0.03),
	}


## Mañana suave / amanecer: no es un día brillante al mediodía, sino
## el final de la noche con resplandor cálido en el horizonte, cielo añil y tenue luz matutina.
func _morning_preset() -> Dictionary:
	return {
		"sky_top": Vector3(0.08, 0.16, 0.32),
		"horizon": Vector3(0.62, 0.38, 0.20),
		"ground": Vector3(0.03, 0.04, 0.07),
		"stars": 0.0,
		"star_brightness": 0.0,
		"ambient_energy": 0.7,
		"ambient_color": Vector3(0.92, 0.82, 0.70),
		"sun_energy": 0.75,
		"sun_color": Vector3(1.0, 0.85, 0.68),
		"fog_density": 0.05,
		"fog_color": Vector3(0.18, 0.19, 0.24),
	}


# --- Aplicación / interpolación ------------------------------------------

func _build_items(p: Dictionary) -> Array:
	var items := []
	if _sky_material:
		items.append(single_property(_sky_material, "shader_parameter/sky_top_color", p["sky_top"]))
		items.append(single_property(_sky_material, "shader_parameter/horizon_color", p["horizon"]))
		items.append(single_property(_sky_material, "shader_parameter/ground_color", p["ground"]))
		items.append(single_property(_sky_material, "shader_parameter/star_density", p["stars"]))
		items.append(single_property(_sky_material, "shader_parameter/star_brightness", p["star_brightness"]))
	if _sun:
		var sun_col: Vector3 = p["sun_color"]
		items.append(single_property(_sun, "light_energy", p["sun_energy"]))
		items.append(single_property(_sun, "light_color", Color(sun_col.x, sun_col.y, sun_col.z, 1.0)))
	if _world_env and _world_env.environment:
		var amb_col: Vector3 = p["ambient_color"]
		var fog_col: Vector3 = p["fog_color"]
		items.append(single_property(_world_env.environment, "ambient_light_energy", p["ambient_energy"]))
		items.append(single_property(_world_env.environment, "ambient_light_color", Color(amb_col.x, amb_col.y, amb_col.z, 1.0)))
		items.append(single_property(_world_env.environment, "fog_density", p["fog_density"]))
		items.append(single_property(_world_env.environment, "fog_light_color", Color(fog_col.x, fog_col.y, fog_col.z, 1.0)))
	return items


func _tween_items(tw: Tween, items: Array, duration: float) -> void:
	if items.is_empty() or tw == null:
		return
	for i in range(items.size()):
		var item: Dictionary = items[i]
		if i == 0:
			tw.tween_property(item.object, item.property, item.value, duration)
		else:
			tw.parallel().tween_property(item.object, item.property, item.value, duration)


func _apply_preset(p: Dictionary, immediate: bool = false) -> Tween:
	if immediate:
		_apply_values(p, null)
		return null

	var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var items := _build_items(p)
	if items.is_empty():
		_apply_values(p, null)
		return tw
	_tween_items(tw, items, MORNING_TRANSITION_SECONDS)
	return tw


func _apply_values(p: Dictionary, _tw: Tween) -> void:
	if _sky_material:
		_sky_material.set_shader_parameter("sky_top_color", p["sky_top"])
		_sky_material.set_shader_parameter("horizon_color", p["horizon"])
		_sky_material.set_shader_parameter("ground_color", p["ground"])
		_sky_material.set_shader_parameter("star_density", p["stars"])
		_sky_material.set_shader_parameter("star_brightness", p["star_brightness"])
	if _sun:
		var sun_col: Vector3 = p["sun_color"]
		_sun.light_energy = p["sun_energy"]
		_sun.light_color = Color(sun_col.x, sun_col.y, sun_col.z, 1.0)
	if _world_env and _world_env.environment:
		var amb_col: Vector3 = p["ambient_color"]
		var fog_col: Vector3 = p["fog_color"]
		_world_env.environment.ambient_light_energy = p["ambient_energy"]
		_world_env.environment.ambient_light_color = Color(amb_col.x, amb_col.y, amb_col.z, 1.0)
		_world_env.environment.fog_enabled = true
		_world_env.environment.fog_density = p["fog_density"]
		_world_env.environment.fog_light_color = Color(fog_col.x, fog_col.y, fog_col.z, 1.0)


func single_property(object: Object, property: String, value: Variant) -> Dictionary:
	return { "object": object, "property": property, "value": value }
