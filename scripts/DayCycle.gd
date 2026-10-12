extends Node
## Gestor de ciclo día/noche y transición ambiental.
##
## Flujo de jornada (HU - Bucle de Días & Cama):
## 1. Durante la jornada de atención de clientes: Ambiente nocturno habitual.
## 2. Al atender al último cliente y finalizar el turno (day_ended):
##    El entorno comienza una transición lenta y suave hacia la mañana (10 segundos),
##    elevando la luz del sol matutino, aclarando el cielo y la atmósfera.
## 3. Al interactuar con la cama para dormir (start_next_day):
##    Se restaura de inmediato el ambiente nocturno previo y continúa el nuevo turno.

## Duración en segundos de la transición hacia la mañana al terminar la jornada
const MORNING_TRANSITION_SECONDS := 10.0

var _world_env: WorldEnvironment = null
var _sun: DirectionalLight3D = null
var _sky_material: ShaderMaterial = null
var _tween: Tween = null

var _night_settings: Dictionary = {}
var _captured_night: bool = false


func _ready() -> void:
	_setup_signals()
	_ensure_nodes()
	if get_tree():
		if not get_tree().tree_changed.is_connected(_on_tree_changed):
			get_tree().tree_changed.connect(_on_tree_changed)


func _on_tree_changed() -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(_world_env) or not is_instance_valid(_sun):
		_ensure_nodes()


func _setup_signals() -> void:
	if GameManager == null:
		return
	if not GameManager.is_connected("day_ended", Callable(self, "_on_day_ended")):
		GameManager.day_ended.connect(_on_day_ended)
	if not GameManager.is_connected("day_started", Callable(self, "_on_day_started")):
		GameManager.day_started.connect(_on_day_started)
	if not GameManager.is_connected("day_advanced", Callable(self, "_on_day_advanced")):
		GameManager.day_advanced.connect(_on_day_advanced)


## Llamado por MainScene._ready() cuando la escena principal se carga en el árbol
func on_main_scene_ready() -> void:
	_ensure_nodes(true)
	if GameManager and not GameManager.day_active and GameManager.can_sleep():
		transition_to_morning()
	else:
		restore_to_night(true)


## Asegura que las referencias a WorldEnvironment, DirectionalLight3D y Sky sean válidas
func _ensure_nodes(force_rebind: bool = false) -> bool:
	if not is_inside_tree() or get_tree() == null or get_tree().root == null:
		return false

	if not force_rebind and is_instance_valid(_world_env) and is_instance_valid(_sun) and is_instance_valid(_sky_material):
		return true

	var root := get_tree().root
	var env_node := root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if is_instance_valid(env_node):
		_world_env = env_node
		if _world_env.environment:
			var sky := _world_env.environment.sky as Sky
			if sky and sky.sky_material is ShaderMaterial:
				_sky_material = sky.sky_material as ShaderMaterial

	var lights := root.find_children("DirectionalLight3D", "DirectionalLight3D", true, false)
	_sun = null
	for l in lights:
		if l is DirectionalLight3D and l.visible and not (l.get_parent() is DirectionalLight3D):
			_sun = l
			break
	if _sun == null and not lights.is_empty():
		for l in lights:
			if l is DirectionalLight3D and not (l.get_parent() is DirectionalLight3D):
				_sun = l
				break
		if _sun == null:
			_sun = lights[0] as DirectionalLight3D

	if is_instance_valid(_world_env) and is_instance_valid(_sun) and not _captured_night:
		_capture_night_settings()

	return is_instance_valid(_world_env) and is_instance_valid(_sun)


## Guarda los ajustes nocturnos originales de la escena para poder restaurarlos fielmente al dormir
func _capture_night_settings() -> void:
	if not is_instance_valid(_world_env) or not is_instance_valid(_sun):
		return
	var env := _world_env.environment
	_night_settings = {
		"sun_energy": _sun.light_energy,
		"sun_color": _sun.light_color,
		"ambient_energy": env.ambient_light_energy if env else 0.4,
		"ambient_color": env.ambient_light_color if env else Color(0.85, 0.78, 0.6, 1.0),
		"bg_energy_multiplier": env.background_energy_multiplier if env else 0.33,
		"fog_enabled": env.fog_enabled if env else false,
		"fog_density": env.fog_density if env else 0.015,
		"fog_color": env.fog_light_color if env else Color(0.44, 0.48, 0.55, 1.0),
	}
	if _sky_material:
		_night_settings["sky_top"] = _sky_material.get_shader_parameter("sky_top_color")
		_night_settings["horizon"] = _sky_material.get_shader_parameter("horizon_color")
		_night_settings["ground"] = _sky_material.get_shader_parameter("ground_color")
		_night_settings["stars"] = _sky_material.get_shader_parameter("star_density")
		_night_settings["star_brightness"] = _sky_material.get_shader_parameter("star_brightness")
	_captured_night = true


## Se dispara al terminar la jornada (tras atender al último cliente del día).
## Comienza la transición lenta hacia la mañana (el sol saliendo durante 10 segundos).
func _on_day_ended(_day: int) -> void:
	if GameManager and GameManager.is_game_won:
		return
	transition_to_morning(MORNING_TRANSITION_SECONDS)


## Se dispara al comenzar un nuevo día (tras dormir o reiniciar).
## Restaura el ambiente nocturno habitual.
func _on_day_started(_day: int, _max_clients: int) -> void:
	restore_to_night(true)


func _on_day_advanced(_day: int, _max_clients: int) -> void:
	restore_to_night(true)


## Inicia la transición hacia la mañana (el sol saliendo poco a poco durante 'duration' segundos)
func transition_to_morning(duration: float = -1.0) -> void:
	_ensure_nodes()
	var dur := duration if duration > 0.0 else MORNING_TRANSITION_SECONDS
	if _tween and _tween.is_running():
		_tween.kill()

	var morning_items := _build_items(_morning_preset())
	if morning_items.is_empty():
		_apply_values(_morning_preset())
		return

	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_items(_tween, morning_items, dur)


## Restaura los ajustes de ambiente exactamente al estado nocturno original.
## Si immediate es true, lo aplica de inmediato (por ej. durante el fundido a negro al dormir).
func restore_to_night(immediate: bool = true) -> void:
	_ensure_nodes()
	if _tween and _tween.is_running():
		_tween.kill()
	var night_vals := _night_settings if not _night_settings.is_empty() else _fallback_night()
	if immediate:
		_apply_values(night_vals)
	else:
		var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween_items(tw, _build_items(night_vals), 2.0)


# --- Presets -------------------------------------------------------------

## Ajustes de reserva nocturnos (por si aún no se capturaron de la escena)
func _fallback_night() -> Dictionary:
	return {
		"sky_top": Color(0.01, 0.02, 0.05, 1.0),
		"horizon": Color(0.059, 0.083, 0.14, 1.0),
		"ground": Color(0.01, 0.015, 0.02, 1.0),
		"stars": 30.0,
		"star_brightness": 2.0,
		"bg_energy_multiplier": 0.33,
		"ambient_energy": 0.4,
		"ambient_color": Color(0.85, 0.78, 0.60, 1.0),
		"sun_energy": 0.001,
		"sun_color": Color(0.34, 0.34, 0.40, 1.0),
		"fog_enabled": false,
	}


## Mañana suave:
## Sol matutino dorado cálido saliendo poco a poco (10s), cielo con resplandor de amanecer, sin niebla invasiva.
func _morning_preset() -> Dictionary:
	return {
		"sky_top": Color(0.20, 0.42, 0.75, 1.0),
		"horizon": Color(0.92, 0.62, 0.38, 1.0),
		"ground": Color(0.12, 0.10, 0.08, 1.0),
		"stars": 0.0,
		"star_brightness": 0.0,
		"bg_energy_multiplier": 1.0,
		"ambient_energy": 1.0,
		"ambient_color": Color(0.96, 0.90, 0.82, 1.0),
		"sun_energy": 2.0,
		"sun_color": Color(1.0, 0.88, 0.70, 1.0),
	}


# --- Aplicación / interpolación ------------------------------------------

func _build_items(p: Dictionary) -> Array:
	var items := []
	if _sky_material:
		if p.has("sky_top") and p["sky_top"] != null:
			items.append(single_property(_sky_material, "shader_parameter/sky_top_color", p["sky_top"]))
		if p.has("horizon") and p["horizon"] != null:
			items.append(single_property(_sky_material, "shader_parameter/horizon_color", p["horizon"]))
		if p.has("ground") and p["ground"] != null:
			items.append(single_property(_sky_material, "shader_parameter/ground_color", p["ground"]))
		if p.has("stars") and p["stars"] != null:
			items.append(single_property(_sky_material, "shader_parameter/star_density", p["stars"]))
		if p.has("star_brightness") and p["star_brightness"] != null:
			items.append(single_property(_sky_material, "shader_parameter/star_brightness", p["star_brightness"]))
	if _sun:
		if p.has("sun_energy"):
			items.append(single_property(_sun, "light_energy", p["sun_energy"]))
		if p.has("sun_color") and p["sun_color"] != null:
			items.append(single_property(_sun, "light_color", p["sun_color"]))
	if _world_env and _world_env.environment:
		var env := _world_env.environment
		if p.has("bg_energy_multiplier"):
			items.append(single_property(env, "background_energy_multiplier", p["bg_energy_multiplier"]))
		if p.has("ambient_energy"):
			items.append(single_property(env, "ambient_light_energy", p["ambient_energy"]))
		if p.has("ambient_color") and p["ambient_color"] != null:
			items.append(single_property(env, "ambient_light_color", p["ambient_color"]))
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


func _apply_values(p: Dictionary) -> void:
	if _sky_material:
		if p.has("sky_top") and p["sky_top"] != null:
			_sky_material.set_shader_parameter("sky_top_color", p["sky_top"])
		if p.has("horizon") and p["horizon"] != null:
			_sky_material.set_shader_parameter("horizon_color", p["horizon"])
		if p.has("ground") and p["ground"] != null:
			_sky_material.set_shader_parameter("ground_color", p["ground"])
		if p.has("stars") and p["stars"] != null:
			_sky_material.set_shader_parameter("star_density", p["stars"])
		if p.has("star_brightness") and p["star_brightness"] != null:
			_sky_material.set_shader_parameter("star_brightness", p["star_brightness"])
	if _sun:
		if p.has("sun_energy"):
			_sun.light_energy = p["sun_energy"]
		if p.has("sun_color") and p["sun_color"] != null:
			_sun.light_color = p["sun_color"]
	if _world_env and _world_env.environment:
		var env := _world_env.environment
		if p.has("bg_energy_multiplier"):
			env.background_energy_multiplier = p["bg_energy_multiplier"]
		if p.has("ambient_energy"):
			env.ambient_light_energy = p["ambient_energy"]
		if p.has("ambient_color") and p["ambient_color"] != null:
			env.ambient_light_color = p["ambient_color"]
		if p.has("fog_enabled"):
			env.fog_enabled = p["fog_enabled"]


func single_property(object: Object, property: String, value: Variant) -> Dictionary:
	return { "object": object, "property": property, "value": value }
