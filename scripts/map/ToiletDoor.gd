class_name ToiletDoor
extends AnimatableBody3D
## Puerta batiente para el baño químico.

@export var is_open: bool = false
var is_moving: bool = false


func _ready() -> void:
	collision_layer = 3 # Layer 1 (World) + Layer 2 (Interactable)
	collision_mask = 0


func get_interaction_prompt(_player: Node) -> Dictionary:
	if is_moving:
		return {"text": "Puerta...", "actionable": false}
	if is_open:
		return {"text": "[E] Cerrar Puerta del Baño", "actionable": true}
	else:
		return {"text": "[E] Abrir Baño Químico ", "actionable": true}


func interact(_player: Node) -> void:
	if is_moving:
		return
	is_moving = true
	var target_rot: float = -95.0 if not is_open else 0.0
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:y", target_rot, 0.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	is_open = not is_open
	tween.tween_callback(func(): is_moving = false)
	SFXManager.play_pickup()
