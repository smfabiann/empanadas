extends Node
## Gestiona los puntos de spawn de ítems en el estante.
## Cuando un ítem se entrega, lo respawnea tras un delay.

## Diccionario: { spawn_marker_name: { scene: PackedScene, position: Vector3 } }
var _spawn_points: Dictionary = {}

## Escenas de ítems disponibles, mapeadas por nombre de marker
var item_scenes: Dictionary = {
	"ItemSpawn_Sopaipilla": preload("res://scenes/items/Sopaipilla.tscn"),
	"ItemSpawn_Bebida": preload("res://scenes/items/Drink.tscn"),
	"ItemSpawn_Empanada": preload("res://scenes/items/Empanada.tscn"),
	"ItemSpawn_Completo": preload("res://scenes/items/Completo.tscn"),
}

@export_group("Puntos de Spawn en Estante (Handles)")
## Marker para el punto de spawn de Sopaipilla
@export var sopaipilla_marker: Marker3D
## Marker para el punto de spawn de Bebida
@export var bebida_marker: Marker3D
## Marker para el punto de spawn de Empanada
@export var empanada_marker: Marker3D
## Marker para el punto de spawn de Completo
@export var completo_marker: Marker3D

const RESPAWN_DELAY := 3.0


func _ready() -> void:
	# Esperar un frame a que la escena principal esté completamente inicializada
	# para evitar el error "Parent node is busy setting up children"
	await get_tree().process_frame

	var marker_map: Dictionary = {
		"ItemSpawn_Sopaipilla": sopaipilla_marker,
		"ItemSpawn_Bebida": bebida_marker,
		"ItemSpawn_Empanada": empanada_marker,
		"ItemSpawn_Completo": completo_marker,
	}

	for marker_name in item_scenes.keys():
		var marker: Marker3D = marker_map.get(marker_name)
		if marker == null:
			marker = get_parent().get_node_or_null(marker_name) as Marker3D
		if marker:
			_spawn_points[marker_name] = {
				"scene": item_scenes[marker_name],
				"position": marker.global_position,
			}
			_spawn_item(marker_name)

	# Conectar señal de entrega para respawn
	GameManager.item_delivered.connect(_on_item_delivered)


func _spawn_item(marker_name: String) -> void:
	if not _spawn_points.has(marker_name):
		return
	var data: Dictionary = _spawn_points[marker_name]
	var item: Interactable = data["scene"].instantiate()
	item.spawn_marker_name = marker_name
	item.position = data["position"]
	get_parent().add_child(item)
	item.global_position = data["position"]


func _on_item_delivered() -> void:
	# Verificar qué ítems faltan y respawnear tras delay
	await get_tree().create_timer(RESPAWN_DELAY).timeout

	if not GameManager.game_active:
		return

	for marker_name in _spawn_points.keys():
		if not _item_exists_for_marker(marker_name):
			_spawn_item(marker_name)


func _item_exists_for_marker(marker_name: String) -> bool:
	"""Verifica si ya existe un ítem con este marker en la escena."""
	for child in get_parent().get_children():
		if child is Interactable and child.spawn_marker_name == marker_name:
			return true
	return false
