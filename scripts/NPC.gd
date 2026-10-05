class_name NPC
extends CharacterBody3D

enum State { APPROACHING, WAITING, LEAVING }

@export var speed: float = 2.5
## Si es true, preserva los materiales y apariencia definidos en la escena del NPC
@export var custom_appearance: bool = false
var SPEED: float:
	get:
		return speed
	set(value):
		speed = value

var patience_drain_rate: float = 1.0

@onready var label: Label3D = $Label3D
@onready var body_mesh: CSGCylinder3D = $BodyMesh
@onready var head: CSGSphere3D = $Head
@onready var patience_bar_bg: CSGBox3D = $PatienceBarPivot/PatienceBarBG
@onready var patience_bar_fill: CSGBox3D = $PatienceBarPivot/PatienceBarFill
@onready var patience_bar_pivot: Node3D = $PatienceBarPivot

var state: State = State.APPROACHING
var spawn_pos: Vector3
var target_pos: Vector3
var exit_pos: Vector3

var requested_item: ItemData = null
var patience_time: float = 20.0
var patience_remaining: float = 20.0
var is_at_counter: bool = false
var is_leaving_cleanly: bool = false

var active_event: NPCEvent = null

## Recetas de completos interactivos (HU-11)
const COMPLETO_RECIPES: Array[Dictionary] = [
	{
		"name": "Completo Italiano",
		"desc": "Palta + Mayo",
		"palta": true,
		"mayo": true,
		"ketchup": false,
		"weight": 35
	},
	{
		"name": "Completo con Todo",
		"desc": "Palta + Mayo + Kétchup",
		"palta": true,
		"mayo": true,
		"ketchup": true,
		"weight": 25
	},
	{
		"name": "Completo Palta",
		"desc": "Solo Palta",
		"palta": true,
		"mayo": false,
		"ketchup": false,
		"weight": 12
	},
	{
		"name": "Completo Mayo",
		"desc": "Solo Mayo",
		"palta": false,
		"mayo": true,
		"ketchup": false,
		"weight": 10
	},
	{
		"name": "Completo Kétchup",
		"desc": "Solo Kétchup",
		"palta": false,
		"mayo": false,
		"ketchup": true,
		"weight": 10
	},
	{
		"name": "Completo Mayo-Kétchup",
		"desc": "Mayo + Kétchup",
		"palta": false,
		"mayo": true,
		"ketchup": true,
		"weight": 8
	}
]

var order_recipe: Dictionary = {}
var order_req_sausage: bool = true
var order_req_palta: bool = false
var order_req_mayo: bool = false
var order_req_ketchup: bool = false

const NPC_COLORS: Array[Color] = [
	Color(0.6, 0.2, 0.5, 1), Color(0.2, 0.5, 0.6, 1), Color(0.7, 0.3, 0.2, 1),
	Color(0.3, 0.6, 0.3, 1), Color(0.6, 0.5, 0.2, 1), Color(0.4, 0.3, 0.6, 1),
	Color(0.7, 0.4, 0.5, 1), Color(0.3, 0.4, 0.5, 1)
]


func _ready() -> void:
	add_to_group("npcs")
	label.visible = false
	patience_bar_pivot.visible = false
	global_position = spawn_pos

	if not custom_appearance:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = NPC_COLORS.pick_random()
		body_mesh.material = mat
		if head:
			head.material = mat

	patience_time = GameManager.get_patience_time()
	patience_remaining = patience_time

	if active_event:
		_apply_active_event()


func assign_event(event: NPCEvent) -> void:
	active_event = event
	if is_node_ready():
		_apply_active_event()


func _apply_active_event() -> void:
	if active_event:
		active_event.apply(self)


func _physics_process(delta: float) -> void:
	match state:
		State.APPROACHING:
			_move_toward_point(target_pos, delta)
			if _is_close_to(target_pos) or (is_on_wall() and global_position.distance_to(target_pos) < 1.0):
				_arrive_at_counter()

		State.WAITING:
			_update_patience(delta)

		State.LEAVING:
			_move_toward_point(exit_pos, delta)
			if _is_close_to(exit_pos) or global_position.z <= -4.8:
				_fade_and_free()


func _move_toward_point(target: Vector3, _delta: float) -> void:
	var direction := (target - global_position)
	direction.y = 0.0

	var dist := direction.length()
	if dist < 0.15:
		velocity = Vector3.ZERO
		return

	direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()

	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func _is_close_to(point: Vector3) -> bool:
	var flat_distance := Vector2(global_position.x, global_position.z).distance_to(
		Vector2(point.x, point.z)
	)
	return flat_distance < 0.65


func _arrive_at_counter() -> void:
	state = State.WAITING
	is_at_counter = true
	velocity = Vector3.ZERO

	_generate_completo_order()
	label.text = "💬 Quiero: %s\n(%s)" % [order_recipe.get("name", "Completo"), order_recipe.get("desc", "")]
	label.visible = true

	patience_bar_pivot.visible = true
	patience_remaining = patience_time

	look_at(global_position + Vector3(0, 0, 1), Vector3.UP)

	if active_event:
		active_event.on_arrive(self)


func _generate_completo_order() -> void:
	var total_w := 0
	for r in COMPLETO_RECIPES:
		total_w += r.get("weight", 10)
	var roll := randi_range(1, total_w)
	var acc := 0
	order_recipe = COMPLETO_RECIPES[0]
	for r in COMPLETO_RECIPES:
		acc += r.get("weight", 10)
		if roll <= acc:
			order_recipe = r
			break

	order_req_sausage = true
	order_req_palta = order_recipe.get("palta", false)
	order_req_mayo = order_recipe.get("mayo", false)
	order_req_ketchup = order_recipe.get("ketchup", false)

	requested_item = ItemData.new()
	requested_item.id = "completo"
	requested_item.display_name = "%s (%s)" % [order_recipe.get("name", "Completo"), order_recipe.get("desc", "")]


func _update_patience(delta: float) -> void:
	patience_remaining -= delta * patience_drain_rate

	var ratio := clampf(patience_remaining / patience_time, 0.0, 1.0)
	patience_bar_fill.scale.x = ratio

	var fill_mat := patience_bar_fill.material as StandardMaterial3D
	if fill_mat:
		if ratio > 0.5:
			fill_mat.albedo_color = Color(0.2, 0.8, 0.2, 1)
		elif ratio > 0.25:
			fill_mat.albedo_color = Color(0.9, 0.8, 0.1, 1)
		else:
			fill_mat.albedo_color = Color(0.9, 0.2, 0.1, 1)

	if patience_remaining <= 0:
		_timeout()


func _timeout() -> void:
	if state != State.WAITING:
		return
		
	label.text = "¡Me voy!"
	patience_bar_pivot.visible = false
	
	GameManager.register_npc_left()

	await get_tree().create_timer(1.0).timeout
	_start_leaving()


## Determina si el NPC está en posición y estado para reaccionar a la persiana
func can_react_to_persiana() -> bool:
	return is_at_counter and state == State.WAITING


## Se ejecuta cuando se cierra la persiana del mostrador
func on_persiana_closed() -> void:
	_timeout()


func can_receive_item() -> bool:
	return state == State.WAITING and requested_item != null and is_at_counter


func receive_item(item_node: Interactable) -> void:
	if not can_receive_item() or item_node == null:
		return

	is_at_counter = false
	var is_correct: bool = false

	if item_node != null and item_node.has_method("is_valid_base"):
		var completo = item_node
		if not completo.is_valid_base():
			is_correct = false
			label.text = "😠 ¡Le falta la vienesa obligatoria! ❌"
		elif completo.matches_order(order_req_sausage, order_req_palta, order_req_mayo, order_req_ketchup):
			is_correct = true
			label.text = "😊 ¡Buenísimo completo! ✅"
		else:
			is_correct = false
			var err: String = String(completo.get_match_error(order_req_sausage, order_req_palta, order_req_mayo, order_req_ketchup))
			label.text = "😠 %s ❌" % err
	else:
		is_correct = false
		label.text = "😠 ¡Esto no es un completo! ❌"

	if is_correct:
		if body_mesh:
			var tween := create_tween()
			tween.tween_property(body_mesh, "scale", Vector3(1.15, 0.9, 1.15), 0.1)
			tween.tween_property(body_mesh, "scale", Vector3(0.95, 1.1, 0.95), 0.1)
			tween.tween_property(body_mesh, "scale", Vector3.ONE, 0.15).set_ease(Tween.EASE_OUT)
	else:
		if body_mesh:
			var tween := create_tween()
			var orig_x := body_mesh.position.x
			tween.tween_property(body_mesh, "position:x", orig_x + 0.1, 0.05)
			tween.tween_property(body_mesh, "position:x", orig_x - 0.1, 0.05)
			tween.tween_property(body_mesh, "position:x", orig_x + 0.05, 0.05)
			tween.tween_property(body_mesh, "position:x", orig_x, 0.05)

	patience_bar_pivot.visible = false

	if item_node.get_parent():
		item_node.get_parent().remove_child(item_node)
	item_node.queue_free()
	
	GameManager.register_npc_served(is_correct)

	await get_tree().create_timer(1.2).timeout
	_start_leaving()


func _start_leaving() -> void:
	if state == State.LEAVING:
		return
	state = State.LEAVING
	is_at_counter = false
	label.visible = false
	patience_bar_pivot.visible = false

	collision_mask = 0

	if active_event:
		active_event.on_leave(self)

	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(self):
			_fade_and_free()
	)


func _fade_and_free() -> void:
	if is_leaving_cleanly:
		return
	is_leaving_cleanly = true
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(0.1, 0.1, 0.1), 0.25).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
