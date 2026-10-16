class_name BackDoor
extends AnimatableBody3D
## Puerta trasera del local: da al patio, que vigila la CAM 02.
## Se abre y cierra con [E]. El ladrón del patio (`cctv_patio_thief`) puede forzarla
## para meterse a robar; cerrarla a tiempo lo ahuyenta.

## Se emite al empezar a abrirse (true) o a cerrarse (false)
signal door_toggled(is_open: bool)

## Ángulo de la puerta abierta (gira hacia adentro del local)
const OPEN_ANGLE := -90.0
## Segundos que tarda en abrirse o cerrarse
const SWING_TIME := 0.4

var is_open: bool = false
var is_moving: bool = false
var _jiggle_tween: Tween = null
var _closed_transform: Transform3D


func _ready() -> void:
	add_to_group("back_door")
	_closed_transform = transform


## Transform global de la puerta cerrada (no cambia aunque esté abierta)
func get_closed_global_transform() -> Transform3D:
	var parent := get_parent_node_3d()
	return parent.global_transform * _closed_transform if parent else _closed_transform


## Centro del vano de la puerta (la bisagra está en el borde, a 0.55 m del centro)
func get_doorway_center() -> Vector3:
	return get_closed_global_transform() * Vector3(0.55, 0.0, 0.0)


## Normal del vano de la puerta (hacia +Z local de la puerta cerrada)
func get_doorway_normal() -> Vector3:
	return get_closed_global_transform().basis.z.normalized()


func interact(_player: Node3D) -> void:
	toggle()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	_swing(true)


func close() -> void:
	_swing(false)


func _swing(to_open: bool) -> void:
	if is_moving or is_open == to_open:
		return
	_stop_jiggle()
	is_moving = true
	is_open = to_open
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:y", OPEN_ANGLE if to_open else 0.0, SWING_TIME)
	tween.tween_callback(func(): is_moving = false)
	door_toggled.emit(is_open)


## Sacude la puerta cerrada (alguien la está forzando desde el patio)
func jiggle(duration: float = 3.0) -> void:
	if is_open or is_moving:
		return
	_stop_jiggle()
	var shakes := maxi(1, int(duration / 0.2))
	_jiggle_tween = create_tween()
	for i in shakes:
		_jiggle_tween.tween_property(self, "rotation_degrees:y", -3.5 if i % 2 == 0 else 0.0, 0.1)
	_jiggle_tween.tween_property(self, "rotation_degrees:y", 0.0, 0.1)


func _stop_jiggle() -> void:
	if _jiggle_tween and _jiggle_tween.is_valid():
		_jiggle_tween.kill()
	_jiggle_tween = null


func get_interaction_prompt(_player: Node3D) -> Dictionary:
	if is_moving:
		return {"text": "Puerta trasera...", "actionable": false}
	if is_open:
		return {"text": "[E] Cerrar puerta trasera", "actionable": true}
	return {"text": "[E] Abrir puerta trasera", "actionable": true}
