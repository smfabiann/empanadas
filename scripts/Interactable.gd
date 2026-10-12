class_name Interactable
extends RigidBody3D
## Script base para objetos recogibles del mostrador.
## Incluye tracking del punto de spawn para respawn automático.

@export var item_data: ItemData

var _original_parent: Node = null
var spawn_position: Vector3 = Vector3.ZERO
var spawn_marker_name: String = ""


func _ready() -> void:
	# Congelar físicas al estar en el estante para evitar caídas o desfasajes
	freeze = true
	spawn_position = global_position



## Retorna el prompt contextual de interacción según si el jugador tiene las manos libres
func get_interaction_prompt(player: Node) -> Dictionary:
	var held = player.get("held_item")
	var display_name: String = item_data.display_name if item_data else "Ítem"
	if held == null:
		return {"text": "[E] Recoger " + display_name, "actionable": true}
	else:
		return {"text": display_name, "actionable": false}


func interact(player: Node3D) -> void:
	"""Recoge el objeto y lo reparenta al HoldPoint del jugador."""
	# Si el jugador ya tiene las manos ocupadas con otro ítem, no permitir recoger
	var current_held = player.get("held_item")
	if current_held != null and current_held != self:
		return

	var hold_point: Marker3D = player.get_node_or_null("Camera3D/HoldPoint")
	if hold_point == null:
		return

	# Si el HoldPoint ya contiene otro ítem, evitar apilar
	for child in hold_point.get_children():
		if child != self and child is Interactable:
			return

	if get_parent() != null:
		_original_parent = get_parent()

	# Desactivar físicas y colisiones para que no bloquee el RayCast del jugador
	freeze = true
	collision_layer = 0
	collision_mask = 0

	# Ocultar etiqueta 3D si existe para no estorbar la visión
	var lbl := get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.visible = false

	# Reparentar al HoldPoint
	if get_parent() != null:
		get_parent().remove_child(self)
	hold_point.add_child(self)

	# Resetear transform local para que quede en el HoldPoint
	transform = Transform3D.IDENTITY

	if current_held == null and "held_item" in player:
		player.set("held_item", self)

	SFXManager.play_pickup()


func drop() -> void:
	"""Suelta el objeto restaurando sus físicas."""
	var global_xform := global_transform

	# Restaurar etiqueta 3D
	var lbl := get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.visible = true

	# Asegurar que _original_parent exista
	if _original_parent == null or not is_instance_valid(_original_parent):
		_original_parent = get_tree().current_scene if (is_inside_tree() and get_tree()) else null
		if _original_parent == null and is_inside_tree() and get_tree():
			_original_parent = get_tree().root

	# Reparentar de vuelta a la escena principal
	if get_parent() != null:
		get_parent().remove_child(self)
	if _original_parent != null:
		_original_parent.add_child(self)

	# Restaurar posición global, colisiones y físicas
	if is_inside_tree():
		global_transform = global_xform
	collision_layer = 2
	collision_mask = 1
	freeze = false

	SFXManager.play_drop()
