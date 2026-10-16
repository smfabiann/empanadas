class_name NPC
extends CharacterBody3D

enum State { APPROACHING, WAITING, REACTING, LEAVING }

@export var speed: float = 2.5
## Si es true, preserva los materiales y apariencia definidos en la escena del NPC
@export var custom_appearance: bool = false
var SPEED: float:
	get:
		return speed
	set(value):
		speed = value

var patience_drain_rate: float = 1.0
var _is_order_resolved: bool = false

@onready var label: Label3D = $Label3D
@onready var body_mesh: CSGCylinder3D = (get_node_or_null("BodyMesh") as CSGCylinder3D) if get_node_or_null("BodyMesh") else (get_node_or_null("ShipPivot/BodyMesh") as CSGCylinder3D)
@onready var head: CSGSphere3D = (get_node_or_null("Head") as CSGSphere3D) if get_node_or_null("Head") else (get_node_or_null("ShipPivot/Head") as CSGSphere3D)
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
## Completo mojado en la olla (estilo Talca). Solo aparece cuando GameManager.mojados_unlocked.
var order_req_mojado: bool = false
## Probabilidad de que un cliente normal lo pida mojado una vez desbloqueada la olla
const MOJADO_ORDER_CHANCE := 0.3

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
		var random_color: Color = NPC_COLORS.pick_random()

		# Preservar materiales o texturas configurados en la escena
		if body_mesh and not _should_preserve_material(body_mesh.material):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = random_color
			body_mesh.material = mat

		if head and not _should_preserve_material(head.material):
			var mat := StandardMaterial3D.new()
			mat.albedo_color = random_color
			head.material = mat

	patience_time = GameManager.get_patience_time()
	patience_remaining = patience_time

	if active_event:
		_apply_active_event()


## Determina si el material asignado en la escena debe preservarse (ej. si contiene texturas o shaders)
func _should_preserve_material(mat: Material) -> bool:
	if mat == null:
		return false
	if mat is StandardMaterial3D or mat is ORMMaterial3D:
		return mat.albedo_texture != null
	return true


## Asigna o reemplaza la textura de la cabeza del NPC (preparado para eventos de rareza)
func set_head_texture(tex: Texture2D) -> void:
	if head:
		if head.material is StandardMaterial3D:
			var mat: StandardMaterial3D = head.material.duplicate()
			mat.albedo_texture = tex
			head.material = mat
		else:
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex
			head.material = mat


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

		State.REACTING:
			velocity = Vector3.ZERO

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
	_is_order_resolved = false
	is_at_counter = true
	velocity = Vector3.ZERO

	_generate_completo_order()
	label.text = " Quiero: %s\n(%s)" % [order_recipe.get("name", "Completo"), order_recipe.get("desc", "")]
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
	order_req_mojado = GameManager.mojados_unlocked and randf() < MOJADO_ORDER_CHANCE
	if order_req_mojado:
		order_recipe = order_recipe.duplicate()
		order_recipe["name"] = String(order_recipe.get("name", "Completo")) + " MOJADO"
		order_recipe["desc"] = String(order_recipe.get("desc", "")) + " + pan mojado en la olla"

	requested_item = ItemData.new()
	requested_item.id = "completo"
	requested_item.display_name = "%s (%s)" % [order_recipe.get("name", "Completo"), order_recipe.get("desc", "")]


## Fija un pedido concreto (lo usan los eventos para pedir algo específico, ej. el Talquino)
func set_completo_order(recipe_name: String, desc: String, palta: bool, mayo: bool, ketchup: bool, mojado: bool = false) -> void:
	order_recipe = {"name": recipe_name, "desc": desc, "palta": palta, "mayo": mayo, "ketchup": ketchup}
	order_req_sausage = true
	order_req_palta = palta
	order_req_mayo = mayo
	order_req_ketchup = ketchup
	order_req_mojado = mojado
	requested_item = ItemData.new()
	requested_item.id = "completo"
	requested_item.display_name = "%s (%s)" % [recipe_name, desc]


## Paciencia restante normalizada (0..1), usada para calcular la propina
func get_patience_ratio() -> float:
	if patience_time <= 0.0:
		return 0.0
	return clampf(patience_remaining / patience_time, 0.0, 1.0)


func _update_patience(delta: float) -> void:
	if _is_order_resolved or state != State.WAITING:
		return

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
	if _is_order_resolved or state != State.WAITING:
		return
	if active_event and active_event.on_timeout(self):
		return

	_is_order_resolved = true
	state = State.REACTING
	is_at_counter = false
	patience_bar_pivot.visible = false
	label.text = "¡Me voy!"
	SFXManager.play_npc_timeout()

	GameManager.register_npc_left()

	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(self):
		_start_leaving()


## Determina si el NPC está en posición y estado para reaccionar a la persiana
func can_react_to_persiana() -> bool:
	return not _is_order_resolved and is_at_counter and state == State.WAITING


## Se ejecuta cuando se cierra la persiana del mostrador
func on_persiana_closed() -> void:
	if not can_react_to_persiana():
		return
	if active_event and active_event.on_persiana_closed(self):
		return
	_timeout()


func can_receive_item() -> bool:
	return not _is_order_resolved and state == State.WAITING and requested_item != null and is_at_counter


func receive_item(item_node: Interactable) -> void:
	if _is_order_resolved or not can_receive_item() or item_node == null:
		return

	# Comprobar si el completo contiene caca (letal para el cliente)
	var has_poop: bool = false
	if item_node.has_method("get_ingredient_count") and item_node.get_ingredient_count("poop") > 0:
		has_poop = true
	elif item_node.get("has_poop") == true or (item_node.get("poop_count") != null and item_node.poop_count > 0):
		has_poop = true

	if has_poop:
		_die_from_poison(item_node)
		return

	# Los eventos pueden tomar el control de la entrega (estafador, Rappi, etc.)
	if active_event and active_event.on_item_received(self, item_node):
		return

	var patience_ratio: float = get_patience_ratio()
	_is_order_resolved = true
	state = State.REACTING
	is_at_counter = false
	var is_correct: bool = false

	if item_node != null and item_node.has_method("is_valid_base"):
		var completo = item_node
		if not completo.is_valid_base():
			is_correct = false
			label.text = " ¡Le falta la vienesa obligatoria! "
		elif completo.matches_order(order_req_sausage, order_req_palta, order_req_mayo, order_req_ketchup, order_req_mojado):
			is_correct = true
			label.text = " ¡Buenísimo completo! "
		else:
			is_correct = false
			var err: String = String(completo.get_match_error(order_req_sausage, order_req_palta, order_req_mayo, order_req_ketchup, order_req_mojado))
			label.text = " %s " % err
	else:
		is_correct = false
		if item_node.is_in_group("poop") or (item_node.item_data and item_node.item_data.id == "poop"):
			label.text = " ¡¿ME ESTÁS DANDO CACA?! ¡QUÉ ASCO! "
		else:
			label.text = " ¡Esto no es un completo! "

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
	if is_correct:
		var payment: int = GameManager.calculate_completo_payment(patience_ratio, order_req_mojado)
		GameManager.earn_money(payment, "Completo vendido")
		SFXManager.play_cash()
		label.text += "\n+$%s" % GameManager.format_money(payment)

	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(self):
		_start_leaving()


## Secuencia letal cuando el cliente come un completo con caca
func _die_from_poison(item_node: Interactable) -> void:
	_is_order_resolved = true
	state = State.REACTING
	is_at_counter = false
	patience_bar_pivot.visible = false

	# Consumir el alimento letal
	if item_node.get_parent():
		item_node.get_parent().remove_child(item_node)
	item_node.queue_free()

	# 1. Asfixia y reacción inicial de envenenamiento
	label.visible = true
	label.text = " *Gulp*... ¡¿QUÉ ES ESTO?! ¡TIENE CACA! "
	label.modulate = Color(0.4, 0.95, 0.2, 1.0) # Verde tóxico

	# Cambiar color de cuerpo y cabeza a tono tóxico / nauseabundo
	var toxic_mat := StandardMaterial3D.new()
	toxic_mat.albedo_color = Color(0.22, 0.60, 0.18, 1.0)
	if body_mesh:
		body_mesh.material = toxic_mat
	if head:
		head.material = toxic_mat

	# Convulsión violenta
	var orig_pos := global_position
	var shake_tween := create_tween()
	for i in 6:
		var offset := Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
		shake_tween.tween_property(self, "global_position", orig_pos + offset, 0.05)
	shake_tween.tween_property(self, "global_position", orig_pos, 0.05)

	SFXManager.play_npc_death()

	# 2. Colapso mortal: el cliente cae tieso al suelo
	await get_tree().create_timer(0.6).timeout
	if not is_instance_valid(self):
		return

	label.text = " ¡AGHHH...! *Muerto* "
	label.modulate = Color(1.0, 0.15, 0.15, 1.0)

	collision_mask = 0
	var death_tween := create_tween().set_parallel(true)
	death_tween.tween_property(self, "rotation_degrees:x", -90.0, 0.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	death_tween.tween_property(self, "position:y", 0.22, 0.35)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)

	# Registrar en GameManager
	GameManager.register_npc_served(false)

	# El cadáver permanece en el suelo antes de desvanecerse
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(self):
		_fade_and_free()


## Cierra la visita del cliente con un mensaje final (lo usan los eventos con lógica propia).
## result: "correct" (atendido bien), "wrong" (atendido mal) o "left" (se fue sin ser atendido).
func finish_visit(text: String, result: String = "correct", color: Color = Color(1, 0.94, 0.25, 1), delay: float = 1.6) -> void:
	if _is_order_resolved:
		return
	_is_order_resolved = true
	state = State.REACTING
	is_at_counter = false
	velocity = Vector3.ZERO
	patience_bar_pivot.visible = false
	label.visible = true
	label.text = text
	label.modulate = color

	match result:
		"correct":
			GameManager.register_npc_served(true)
		"wrong":
			GameManager.register_npc_served(false)
		_:
			GameManager.register_npc_left()

	if not is_inside_tree():
		return
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(self):
		_start_leaving()


## true si la visita ya terminó (pedido resuelto o cliente retirándose)
func is_order_resolved() -> bool:
	return _is_order_resolved


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
