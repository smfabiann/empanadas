class_name TalkPromptHUD
extends Control
## Indicador flotante llamativo para hablar con el cliente:
## Tecla [E] estilizada + texto blanco grande con ligero flotado.

@export var key_text: String = "E"
@export var action_text: String = "Hablar con cliente"
@export var float_amplitude: float = 4.0
@export var float_speed: float = 4.0

@onready var box: HBoxContainer = $HBoxContainer
@onready var key_panel: PanelContainer = $HBoxContainer/KeyPanel
@onready var key_label: Label = $HBoxContainer/KeyPanel/KeyLabel
@onready var action_label: Label = $HBoxContainer/ActionLabel

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	if box:
		_base_y = box.position.y
	if key_label:
		key_label.text = key_text
	if action_label:
		action_label.text = action_text
	visible = false


func _process(delta: float) -> void:
	if not visible or box == null:
		return
	_time += delta * float_speed
	box.position.y = _base_y + sin(_time) * float_amplitude


func show_prompt(text: String = "Hablar con cliente") -> void:
	if action_label:
		action_label.text = text
	if not visible:
		_time = 0.0
		visible = true


func hide_prompt() -> void:
	if visible:
		visible = false
