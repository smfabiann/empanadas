class_name CompletoItem
extends Interactable
## Ítem de Completo 3D con ensamblado interactivo modular paso a paso (HU-11).
## Permite añadir ingredientes en estaciones 3D y renderiza visualmente cada capa.

@export var has_bun: bool = true
@export var has_sausage: bool = false
@export var has_palta: bool = false
@export var has_mayo: bool = false
@export var has_ketchup: bool = false

@onready var bun_mesh: CSGBox3D = get_node_or_null("Bun")
@onready var sausage_mesh: CSGBox3D = get_node_or_null("Sausage")
@onready var palta_mesh: CSGBox3D = get_node_or_null("Palta")
@onready var mayo_mesh: CSGBox3D = get_node_or_null("Mayo")
@onready var ketchup_mesh: CSGBox3D = get_node_or_null("Ketchup")
@onready var label: Label3D = get_node_or_null("Label3D")


func _ready() -> void:
	if item_data:
		item_data = item_data.duplicate()
	super._ready()
	_update_visuals()
	_update_labels()


## Actualiza la visibilidad de las capas según los ingredientes presentes
func _update_visuals() -> void:
	if bun_mesh:
		bun_mesh.visible = has_bun
	if sausage_mesh:
		sausage_mesh.visible = has_sausage
	if palta_mesh:
		palta_mesh.visible = has_palta
	if mayo_mesh:
		mayo_mesh.visible = has_mayo
	if ketchup_mesh:
		ketchup_mesh.visible = has_ketchup


## Intenta añadir un ingrediente al completo
func add_ingredient(type: String) -> bool:
	var added: bool = false
	var target_mesh: CSGBox3D = null

	match type:
		"sausage":
			if not has_sausage:
				has_sausage = true
				added = true
				target_mesh = sausage_mesh
		"palta":
			if not has_palta:
				has_palta = true
				added = true
				target_mesh = palta_mesh
		"mayo":
			if not has_mayo:
				has_mayo = true
				added = true
				target_mesh = mayo_mesh
		"ketchup":
			if not has_ketchup:
				has_ketchup = true
				added = true
				target_mesh = ketchup_mesh

	if added:
		_update_visuals()
		_update_labels()
		if target_mesh:
			_animate_ingredient_pop(target_mesh)
		return true

	return false


## Animación pop suave cuando cae un ingrediente sobre el pan
func _animate_ingredient_pop(mesh_node: Node3D) -> void:
	if mesh_node == null:
		return
	mesh_node.scale = Vector3(1.25, 1.4, 1.25)
	var tween := create_tween()
	tween.tween_property(mesh_node, "scale", Vector3.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## Verifica si el completo cuenta con la base obligatoria (Pan + Salchicha)
func is_valid_base() -> bool:
	return has_bun and has_sausage


## Retorna el nombre representativo del completo según su composición
func get_completo_name() -> String:
	if not has_sausage:
		if not has_palta and not has_mayo and not has_ketchup:
			return "Pan de Completo (Solo)"
		return "Pan con agregados (Sin vienesa)"

	# Con salchicha:
	if has_palta and has_mayo and has_ketchup:
		return "Completo con Todo (Palta, Mayo, Kétchup)"
	elif has_palta and has_mayo and not has_ketchup:
		return "Completo Italiano (Palta, Mayo)"
	elif has_palta and not has_mayo and has_ketchup:
		return "Completo Palta-Kétchup"
	elif has_palta and not has_mayo and not has_ketchup:
		return "Completo Palta"
	elif not has_palta and has_mayo and has_ketchup:
		return "Completo Mayo-Kétchup"
	elif not has_palta and has_mayo and not has_ketchup:
		return "Completo Mayo"
	elif not has_palta and not has_mayo and has_ketchup:
		return "Completo Kétchup"
	else:
		return "Completo Simple (Solo vienesa)"


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
