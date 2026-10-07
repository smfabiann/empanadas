class_name CompletoItem
extends Interactable
## Ítem de Completo 3D con ensamblado interactivo modular paso a paso (HU-11).
## Permite añadir múltiples capas del mismo o diferentes ingredientes con apilamiento vertical 3D.

@export var has_bun: bool = true
@export var sausage_count: int = 0
@export var palta_count: int = 0
@export var mayo_count: int = 0
@export var ketchup_count: int = 0

## Secuencia cronológica de capas añadidas
var layers: Array[String] = []

## Propiedades booleanas retrocompatibles
var has_sausage: bool:
	get:
		return sausage_count > 0
	set(value):
		if value and sausage_count == 0:
			add_ingredient("sausage")
		elif not value and sausage_count > 0:
			sausage_count = 0
			layers = layers.filter(func(l): return l != "sausage")
			_rebuild_visuals()
			_update_labels()

var has_palta: bool:
	get:
		return palta_count > 0
	set(value):
		if value and palta_count == 0:
			add_ingredient("palta")
		elif not value and palta_count > 0:
			palta_count = 0
			layers = layers.filter(func(l): return l != "palta")
			_rebuild_visuals()
			_update_labels()

var has_mayo: bool:
	get:
		return mayo_count > 0
	set(value):
		if value and mayo_count == 0:
			add_ingredient("mayo")
		elif not value and mayo_count > 0:
			mayo_count = 0
			layers = layers.filter(func(l): return l != "mayo")
			_rebuild_visuals()
			_update_labels()

var has_ketchup: bool:
	get:
		return ketchup_count > 0
	set(value):
		if value and ketchup_count == 0:
			add_ingredient("ketchup")
		elif not value and ketchup_count > 0:
			ketchup_count = 0
			layers = layers.filter(func(l): return l != "ketchup")
			_rebuild_visuals()
			_update_labels()

@onready var bun_mesh: CSGBox3D = get_node_or_null("Bun")
@onready var sausage_mesh: CSGBox3D = get_node_or_null("Sausage")
@onready var palta_mesh: CSGBox3D = get_node_or_null("Palta")
@onready var mayo_mesh: CSGBox3D = get_node_or_null("Mayo")
@onready var ketchup_mesh: CSGBox3D = get_node_or_null("Ketchup")
@onready var label: Label3D = get_node_or_null("Label3D")

## Constantes de renderizado y apilamiento 3D
const BASE_Y: float = 0.105
const LAYER_GAP: float = 0.001

const LAYER_CONFIG: Dictionary = {
	"sausage": {
		"thickness": 0.046,
		"size": Vector3(0.32, 0.046, 0.08),
		"color": Color(0.82, 0.22, 0.15, 1)
	},
	"palta": {
		"thickness": 0.034,
		"size": Vector3(0.28, 0.034, 0.09),
		"color": Color(0.38, 0.72, 0.2, 1)
	},
	"mayo": {
		"thickness": 0.022,
		"size": Vector3(0.25, 0.022, 0.036),
		"color": Color(0.96, 0.96, 0.92, 1)
	},
	"ketchup": {
		"thickness": 0.022,
		"size": Vector3(0.25, 0.022, 0.036),
		"color": Color(0.88, 0.15, 0.12, 1)
	}
}

var current_stack_height: float = BASE_Y


func _ready() -> void:
	if item_data:
		item_data = item_data.duplicate()
	super._ready()

	# Duplicar el BoxShape3D para no alterar otras instancias al redimensionar la colisión
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape:
		col.shape = col.shape.duplicate()

	# Ocultar mallas estáticas de plantilla para que las capas se generen modularmente
	if sausage_mesh: sausage_mesh.visible = false
	if palta_mesh: palta_mesh.visible = false
	if mayo_mesh: mayo_mesh.visible = false
	if ketchup_mesh: ketchup_mesh.visible = false

	# Si las capas estaban vacías pero los contadores tenían valores iniciales (ej. desde inspector)
	if layers.is_empty():
		for i in range(sausage_count):
			layers.append("sausage")
		for i in range(palta_count):
			layers.append("palta")
		for i in range(mayo_count):
			layers.append("mayo")
		for i in range(ketchup_count):
			layers.append("ketchup")

	_update_visuals()
	_update_labels()


func _get_layers_container() -> Node3D:
	var container = get_node_or_null("LayersContainer") as Node3D
	if container == null:
		container = Node3D.new()
		container.name = "LayersContainer"
		add_child(container)
	return container


func _get_material_for(type: String) -> Material:
	match type:
		"sausage":
			if sausage_mesh and sausage_mesh.material:
				return sausage_mesh.material
		"palta":
			if palta_mesh and palta_mesh.material:
				return palta_mesh.material
		"mayo":
			if mayo_mesh and mayo_mesh.material:
				return mayo_mesh.material
		"ketchup":
			if ketchup_mesh and ketchup_mesh.material:
				return ketchup_mesh.material

	var mat := StandardMaterial3D.new()
	if LAYER_CONFIG.has(type):
		mat.albedo_color = LAYER_CONFIG[type]["color"]
	return mat


func _calculate_z_offset(type: String, count_of_type: int) -> float:
	match type:
		"sausage":
			if count_of_type == 1:
				return 0.0
			return 0.012 if (count_of_type % 2 == 0) else -0.012
		"palta":
			if count_of_type == 1:
				return 0.0
			return 0.005 if (count_of_type % 2 == 0) else -0.005
		"mayo":
			if ketchup_count > 0:
				return -0.020 + (0.006 * ((count_of_type - 1) % 2))
			if count_of_type == 1:
				return -0.012
			return 0.012 if (count_of_type % 2 == 0) else -0.012
		"ketchup":
			if mayo_count > 0:
				return 0.020 - (0.006 * ((count_of_type - 1) % 2))
			if count_of_type == 1:
				return 0.012
			return -0.012 if (count_of_type % 2 == 0) else 0.012
	return 0.0


func _create_layer_mesh_node(type: String, count_of_type: int, layer_index: int) -> CSGBox3D:
	if not LAYER_CONFIG.has(type):
		return null

	var config: Dictionary = LAYER_CONFIG[type]
	var layer_mesh := CSGBox3D.new()
	layer_mesh.name = "%s_%d" % [type.capitalize(), layer_index]
	layer_mesh.size = config["size"]
	layer_mesh.material = _get_material_for(type)

	var z_offset := _calculate_z_offset(type, count_of_type)
	var center_y: float = current_stack_height + (config["thickness"] * 0.5)
	layer_mesh.position = Vector3(0.0, center_y, z_offset)

	current_stack_height += config["thickness"] + LAYER_GAP
	return layer_mesh


func _update_height_bounds() -> void:
	if label:
		label.position.y = maxf(0.38, current_stack_height + 0.12)

	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col and col.shape is BoxShape3D:
		var total_h: float = maxf(0.25, current_stack_height + 0.04)
		col.shape.size.y = total_h
		col.position.y = total_h * 0.5


## Reconstruye todas las capas visuales según la secuencia de 'layers'
func _rebuild_visuals() -> void:
	if bun_mesh:
		bun_mesh.visible = has_bun

	var container = _get_layers_container()
	for child in container.get_children():
		child.queue_free()

	current_stack_height = BASE_Y
	var counts := {"sausage": 0, "palta": 0, "mayo": 0, "ketchup": 0}

	for i in range(layers.size()):
		var type := layers[i]
		counts[type] = counts.get(type, 0) + 1
		var node := _create_layer_mesh_node(type, counts[type], i)
		if node:
			container.add_child(node)

	_update_height_bounds()


## Actualiza la visibilidad de las capas según los ingredientes presentes
func _update_visuals() -> void:
	_rebuild_visuals()


## Intenta añadir un ingrediente al completo
func add_ingredient(type: String) -> bool:
	if not LAYER_CONFIG.has(type):
		return false

	match type:
		"sausage":
			sausage_count += 1
		"palta":
			palta_count += 1
		"mayo":
			mayo_count += 1
		"ketchup":
			ketchup_count += 1

	layers.append(type)
	var count_of_type: int = get_ingredient_count(type)
	var layer_mesh := _create_layer_mesh_node(type, count_of_type, layers.size() - 1)
	if layer_mesh:
		_get_layers_container().add_child(layer_mesh)
		if is_inside_tree():
			_animate_ingredient_pop(layer_mesh)

	_update_height_bounds()
	_update_labels()
	return true


func get_ingredient_count(type: String) -> int:
	match type:
		"sausage":
			return sausage_count
		"palta":
			return palta_count
		"mayo":
			return mayo_count
		"ketchup":
			return ketchup_count
	return 0


func get_layer_count() -> int:
	return layers.size()


func get_layers() -> Array[String]:
	return layers.duplicate()


## Animación pop suave cuando cae un ingrediente sobre el pan
func _animate_ingredient_pop(mesh_node: Node3D) -> void:
	if mesh_node == null or not is_inside_tree():
		return
	mesh_node.scale = Vector3(1.25, 1.4, 1.25)
	var tween := create_tween()
	if tween:
		tween.tween_property(mesh_node, "scale", Vector3.ONE, 0.2)\
			.set_trans(Tween.TRANS_BACK)\
			.set_ease(Tween.EASE_OUT)


## Verifica si el completo cuenta con la base obligatoria (Pan + Salchicha)
func is_valid_base() -> bool:
	return has_bun and sausage_count >= 1


## Retorna el nombre representativo del completo según su composición
func get_completo_name() -> String:
	var base_name: String = ""
	if sausage_count == 0:
		if palta_count == 0 and mayo_count == 0 and ketchup_count == 0:
			base_name = "Pan de Completo (Solo)"
		else:
			base_name = "Pan con agregados (Sin vienesa)"
	else:
		# Con salchicha:
		if palta_count > 0 and mayo_count > 0 and ketchup_count > 0:
			base_name = "Completo con Todo (Palta, Mayo, Kétchup)"
		elif palta_count > 0 and mayo_count > 0 and ketchup_count == 0:
			base_name = "Completo Italiano (Palta, Mayo)"
		elif palta_count > 0 and mayo_count == 0 and ketchup_count > 0:
			base_name = "Completo Palta-Kétchup"
		elif palta_count > 0 and mayo_count == 0 and ketchup_count == 0:
			base_name = "Completo Palta"
		elif palta_count == 0 and mayo_count > 0 and ketchup_count > 0:
			base_name = "Completo Mayo-Kétchup"
		elif palta_count == 0 and mayo_count > 0 and ketchup_count == 0:
			base_name = "Completo Mayo"
		elif palta_count == 0 and mayo_count == 0 and ketchup_count > 0:
			base_name = "Completo Kétchup"
		else:
			base_name = "Completo Simple (Solo vienesa)"

	var extras: Array[String] = []
	if sausage_count > 1:
		extras.append("%dx Vienesa" % sausage_count)
	if palta_count > 1:
		extras.append("%dx Palta" % palta_count)
	if mayo_count > 1:
		extras.append("%dx Mayo" % mayo_count)
	if ketchup_count > 1:
		extras.append("%dx Kétchup" % ketchup_count)

	if not extras.is_empty():
		return "%s [%s]" % [base_name, ", ".join(extras)]
	return base_name


## Actualiza el texto 3D flotante y el display_name del item_data
func _update_labels() -> void:
	var c_name := get_completo_name()
	if item_data:
		item_data.display_name = c_name

	if label:
		label.text = "🌭 " + c_name


## Compara la composición actual con los requisitos de una orden
func matches_order(req_sausage: bool, req_palta: bool, req_mayo: bool, req_ketchup: bool) -> bool:
	return (
		has_sausage == req_sausage
		and has_palta == req_palta
		and has_mayo == req_mayo
		and has_ketchup == req_ketchup
	)


## Retorna el motivo de desacuerdo si no coincide
func get_match_error(req_sausage: bool, req_palta: bool, req_mayo: bool, req_ketchup: bool) -> String:
	if not has_sausage and req_sausage:
		return "¡Le falta la vienesa obligatoria!"
	if has_sausage and not req_sausage:
		return "¡No pedí con vienesa!"
	if req_palta and not has_palta:
		return "¡Le falta la palta!"
	if not req_palta and has_palta:
		return "¡No pedí con palta!"
	if req_mayo and not has_mayo:
		return "¡Le falta la mayonesa!"
	if not req_mayo and has_mayo:
		return "¡No pedí con mayonesa!"
	if req_ketchup and not has_ketchup:
		return "¡Le falta el kétchup!"
	if not req_ketchup and has_ketchup:
		return "¡No pedí con kétchup!"
	return "¡La combinación no coincide!"

