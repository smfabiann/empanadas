class_name UfoEvent
extends StaticNPCEvent
## Evento Estático: El Visitante Espacial / OVNI.
## Aparece en el Día 2 tras atender a 1 cliente.
## El personaje desciende del cielo con apariencia verde fosforescente brillante.
## Utiliza la escena dedicada res://scenes/UfoNPC.tscn para su apariencia y comportamiento.

func _init() -> void:
	super._init()
	id = "ufo"
	event_name = "Visitante Espacial"
	description = "Un misterioso cliente fosforescente que desciende del cosmos tras atender al primer cliente del Día 2."
	trigger_day = 2
	trigger_day_served_count = 1
	trigger_served_count = 0
	trigger_once = true
	custom_npc_scene = preload("res://scenes/events/static/UfoNPC.tscn")


func apply(npc: CharacterBody3D) -> void:
	# Respaldo: si por alguna razón no se usó la escena dedicada, aplicamos el material verde fosforescente
	if not (npc is UfoNPC):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.15, 1.0, 0.25, 1.0)
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.35, 1.0)
		mat.emission_energy_multiplier = 2.2

		var body := npc.get_node_or_null("BodyMesh") as CSGCylinder3D
		if body:
			body.material = mat
		var head := npc.get_node_or_null("Head") as CSGSphere3D
		if head:
			head.material = mat


func on_arrive(npc: CharacterBody3D) -> void:
	if npc is UfoNPC:
		return

	var label := npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = " ⟒⋔⌿⏃⋏⏃⎅⏃⌇... Saludos terrícola!\nQuiero una empanada cósmica."
		label.modulate = Color(0.25, 1.0, 0.45, 1.0)


func on_leave(npc: CharacterBody3D) -> void:
	var label := npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = " ⏁⊑⏃⋏⋞ ⊬⍜⎍... (Regresando a las estrellas)"
