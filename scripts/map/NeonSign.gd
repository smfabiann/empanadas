class_name NeonSign
extends Node3D
## Letrero de neón del local: parpadea de vez en cuando como un tubo viejo.
## Si hay un Label3D "Text" y una luz "Glow" como hijos, los apaga/prende en conjunto.

@export var flicker_enabled: bool = true
## Segundos promedio entre parpadeos
@export var mean_interval: float = 7.0
@export var on_color: Color = Color(1.0, 0.25, 0.45, 1)
@export var off_color: Color = Color(0.25, 0.06, 0.1, 1)

@onready var _label: Label3D = get_node_or_null("Text")
@onready var _glow: Light3D = get_node_or_null("Glow")

var _base_energy: float = 1.0
var _timer: float = 0.0


func _ready() -> void:
	if _glow:
		_base_energy = _glow.light_energy
	_set_on(true)
	_timer = randf_range(mean_interval * 0.5, mean_interval * 1.5)


func _process(delta: float) -> void:
	if not flicker_enabled:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(mean_interval * 0.5, mean_interval * 1.5)
		_flicker()


func _flicker() -> void:
	var tween := create_tween()
	for i in randi_range(2, 4):
		tween.tween_callback(_set_on.bind(false))
		tween.tween_interval(randf_range(0.04, 0.12))
		tween.tween_callback(_set_on.bind(true))
		tween.tween_interval(randf_range(0.05, 0.2))


func _set_on(value: bool) -> void:
	if _label:
		_label.modulate = on_color if value else off_color
	if _glow:
		_glow.light_energy = _base_energy if value else _base_energy * 0.1
