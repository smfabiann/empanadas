class_name UfoNPC
extends NPC
## Controlador específico del cliente Ovni / Visitante Espacial.
## Aparece en el Día 2 con apariencia verde fosforescente brillante y
## desciende del cielo para realizar su pedido en la tienda.

@export_group("Descenso del Cielo")
## Si es true, el NPC inicia en el cielo y desciende suavemente al aparecer
@export var enable_sky_descent: bool = true
## Altura de inicio de la flotación/descenso (en metros)
@export var descent_height: float = 8.0
## Duración del descenso en segundos
@export var descent_duration: float = 2.5

@export_group("Apariencia Fosforescente")
## Color base verde fosforescente
@export var alien_color: Color = Color(0.15, 1.0, 0.25, 1.0)
## Color de emisión de brillo
@export var emission_color: Color = Color(0.2, 1.0, 0.35, 1.0)
## Multiplicador de energía de emisión
@export var emission_energy: float = 2.2

var is_descending: bool = false
var _descent_tween: Tween = null
var _glow_light: OmniLight3D = null


func _ready() -> void:
	custom_appearance = true
	_apply_phosphorescent_appearance()

	if enable_sky_descent:
		is_descending = true
		global_position = spawn_pos + Vector3(0.0, descent_height, 0.0)
		_start_sky_descent()
	else:
		global_position = spawn_pos

	super._ready()


func _apply_phosphorescent_appearance() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = alien_color
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = emission_color
	mat.emission_energy_multiplier = emission_energy

	if body_mesh:
		body_mesh.material = mat
	if head:
		head.material = mat

	# Luz ambiental verde que emana del visitante
	_glow_light = get_node_or_null("AlienGlow") as OmniLight3D
	if _glow_light == null:
		_glow_light = OmniLight3D.new()
		_glow_light.name = "AlienGlow"
		_glow_light.light_color = emission_color
		_glow_light.light_energy = 1.6
		_glow_light.omni_range = 4.5
		_glow_light.position = Vector3(0.0, 1.2, 0.0)
		add_child(_glow_light)


func _start_sky_descent() -> void:
	if _descent_tween and _descent_tween.is_valid():
		_descent_tween.kill()

	_descent_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_descent_tween.tween_property(self, "global_position:y", spawn_pos.y, descent_duration)
	_descent_tween.tween_callback(func():
		is_descending = false
	)


func _physics_process(delta: float) -> void:
	if is_descending:
		velocity = Vector3.ZERO
		return
	super._physics_process(delta)


func _arrive_at_counter() -> void:
	super._arrive_at_counter()
	if label:
		label.text = "👽 ⟒⋔⌿⏃⋏⏃⎅⏃⌇... Saludos terrícola!\nQuiero: %s\n(%s)" % [
			order_recipe.get("name", "Completo"),
			order_recipe.get("desc", "")
		]
		label.modulate = Color(0.25, 1.0, 0.45, 1.0)


func _exit_tree() -> void:
	if _descent_tween and _descent_tween.is_valid():
		_descent_tween.kill()
