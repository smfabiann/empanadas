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


func interact(player: Node3D) -> void:
	"""Recoge el objeto y lo reparenta al HoldPoint del jugador."""
	_original_parent = get_parent()
	var hold_point: Marker3D = player.get_node("Camera3D/HoldPoint")

	# Desactivar físicas y colisiones para que no bloquee el RayCast del jugador
	freeze = true
	collision_layer = 0
	collision_mask = 0

	# Ocultar etiqueta 3D si existe para no estorbar la visión
	var lbl := get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.visible = false

	# Reparentar al HoldPoint
	get_parent().remove_child(self)
	hold_point.add_child(self)

	# Resetear transform local para que quede en el HoldPoint
	transform = Transform3D.IDENTITY

	SFXManager.play_pickup()


func drop() -> void:
	"""Suelta el objeto restaurando sus físicas."""
	var global_xform := global_transform

	# Restaurar etiqueta 3D
	var lbl := get_node_or_null("Label3D") as Label3D
	if lbl:
		lbl.visible = true

	# Reparentar de vuelta a la escena principal
	get_parent().remove_child(self)
	_original_parent.add_child(self)

	# Restaurar posición global, colisiones y físicas
	global_transform = global_xform
	collision_layer = 2
	collision_mask = 1
	freeze = false

	SFXManager.play_drop()
