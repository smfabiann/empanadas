class_name BedInteraction
extends StaticBody3D
## Interactive bed mechanic.
## Detects the player by proximity and only displays "Press E to sleep"
## when the day quota of clients has been completed (GameManager.can_sleep()).
## Interacting advances the day (or triggers victory on final day) without
## showing a blocking next-day popup menu.

signal bed_interacted
signal slept

@export var prompt_text: String = "Press E to sleep"
@export var interaction_distance: float = 3.2

const PLAYER_GROUP: String = "player"

@onready var interaction_area: Area3D = get_node_or_null("InteractionArea")
@onready var prompt_layer: CanvasLayer = get_node_or_null("PromptLayer")
@onready var prompt_panel: Control = get_node_or_null("PromptLayer/Prompt")
@onready var prompt_label: Label = get_node_or_null("PromptLayer/Prompt/Label")
@onready var fade_rect: ColorRect = get_node_or_null("PromptLayer/FadeOverlay")

var _player_inside: bool = false
var _prompt_active: bool = false
var _is_sleeping_transition: bool = false


func _ready() -> void:
	if prompt_layer:
		prompt_layer.visible = true
	if prompt_panel:
		prompt_panel.visible = false
	if prompt_label:
		prompt_label.text = prompt_text
	if fade_rect:
		fade_rect.visible = false
		fade_rect.color = Color(0, 0, 0, 0)

	if interaction_area:
		interaction_area.body_entered.connect(_on_body_entered)
		interaction_area.body_exited.connect(_on_body_exited)

	if GameManager:
		if not GameManager.day_started.is_connected(_on_day_started):
			GameManager.day_started.connect(_on_day_started)

	set_process(true)


func _on_body_entered(body: Node) -> void:
	if _is_player(body):
		_player_inside = true


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		_player_inside = false


func _is_player(body: Node) -> bool:
	return body.is_in_group(PLAYER_GROUP)


func _player_node() -> Node3D:
	return get_tree().get_first_node_in_group(PLAYER_GROUP) as Node3D


func _is_near_bed() -> bool:
	if _player_inside:
		return true
	var p := _player_node()
	if p != null:
		return global_position.distance_to(p.global_position) <= interaction_distance
	return false


func _can_sleep() -> bool:
	if GameManager == null:
		return false
	if GameManager.has_method("can_sleep"):
		return GameManager.can_sleep()
	return GameManager.game_active \
		and not GameManager.day_active \
		and not GameManager.is_game_won \
		and GameManager.clients_attended_today >= GameManager.max_clients_per_day


func _process(_delta: float) -> void:
	if _is_sleeping_transition:
		return
	_refresh_prompt()


func _refresh_prompt() -> void:
	var want := _is_near_bed() and _can_sleep()
	if want == _prompt_active:
		return
	_prompt_active = want

	if prompt_panel:
		prompt_panel.visible = want

	var ui = get_tree().root.find_child("UI", true, false)
	if ui and ui.has_method("set_prompt"):
		if want:
			ui.set_prompt(prompt_text, true)
		elif not _can_sleep() or not _is_near_bed():
			ui.set_prompt("", false)


func _input(event: InputEvent) -> void:
	if _prompt_active and not _is_sleeping_transition and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_sleep()


func _sleep() -> void:
	if _is_sleeping_transition:
		return
	_is_sleeping_transition = true
	_prompt_active = false

	if prompt_panel:
		prompt_panel.visible = false

	var player = _player_node()
	if player and player.has_method("_drop_held_item"):
		player.call("_drop_held_item")

	if GameManager:
		GameManager.is_sleeping = true

	bed_interacted.emit()
	slept.emit()

	if SFXManager and SFXManager.has_method("play_interact"):
		SFXManager.play_interact()

	if fade_rect:
		fade_rect.visible = true
		var tw := create_tween()
		tw.tween_property(fade_rect, "color:a", 1.0, 0.4).set_ease(Tween.EASE_IN_OUT)
		tw.tween_interval(0.3)
		tw.tween_callback(func():
			# Restaura el ambiente nocturno regular durante el sueño (pantalla en negro)
			var day_cycle = get_tree().root.get_node_or_null("DayCycle")
			if day_cycle and day_cycle.has_method("restore_to_night"):
				day_cycle.restore_to_night(true)
			if GameManager != null and GameManager.has_method("start_next_day"):
				GameManager.start_next_day()
		)
		tw.tween_property(fade_rect, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			fade_rect.visible = false
			_is_sleeping_transition = false
			if GameManager:
				GameManager.is_sleeping = false
		)
	else:
		var day_cycle = get_tree().root.get_node_or_null("DayCycle")
		if day_cycle and day_cycle.has_method("restore_to_night"):
			day_cycle.restore_to_night(true)
		if GameManager != null and GameManager.has_method("start_next_day"):
			GameManager.start_next_day()
		_is_sleeping_transition = false
		if GameManager:
			GameManager.is_sleeping = false


func _on_day_started(_day: int, _max_clients: int) -> void:
	_prompt_active = false
	if prompt_panel:
		prompt_panel.visible = false
