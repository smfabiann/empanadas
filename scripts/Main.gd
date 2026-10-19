class_name MainScene
extends Node3D
## Root script for Main.tscn.
## Exposes core game settings and daily quotas directly in the Godot Inspector
## so designers can adjust daily client limits and win conditions easily.

@export_group("Daily Quota & Game Progression")
## Maximum customers per day before the shift ends.
## When this quota is completed, the shift ends and the player can go to bed to advance the day.
@export_range(1, 50, 1) var max_clients_per_day: int = 8:
	set(value):
		max_clients_per_day = maxi(value, 1)
		if GameManager:
			GameManager.set_max_clients_per_day(max_clients_per_day)
		var spawner = get_node_or_null("NPCSpawner")
		if spawner and "max_clients_per_day" in spawner:
			spawner.max_clients_per_day = max_clients_per_day

## Total days required to win the game (HU-06: 3 days by default; 0 = endless mode).
@export_range(0, 30, 1) var max_days: int = 3:
	set(value):
		max_days = maxi(value, 0)
		if GameManager:
			GameManager.set_max_days(max_days)
		var spawner = get_node_or_null("NPCSpawner")
		if spawner and "max_days" in spawner:
			spawner.max_days = max_days


@export_group("Narrativa: plata para escapar")
## Ahorros con los que parte el jugador
@export var starting_savings: int = 20000
## Plata total necesaria para el pasaje (meta para ganar al final de la última noche)
@export var escape_goal: int = 50000
## Ambiente sonoro nocturno procedural (zumbido, ciudad lejana, grillos)
@export var play_ambience: bool = true


func _ready() -> void:
	if GameManager:
		GameManager.set_economy(starting_savings, escape_goal)
	if play_ambience and SFXManager and SFXManager.has_method("start_ambience"):
		SFXManager.start_ambience()

	var spawner = get_node_or_null("NPCSpawner")
	if spawner:
		# If user customized NPCSpawner in the Inspector, respect it
		if "max_clients_per_day" in spawner and spawner.max_clients_per_day != 8 and max_clients_per_day == 8:
			max_clients_per_day = spawner.max_clients_per_day
		elif "max_clients_per_day" in spawner:
			spawner.max_clients_per_day = max_clients_per_day

		if "max_days" in spawner and spawner.max_days != 3 and max_days == 3:
			max_days = spawner.max_days
		elif "max_days" in spawner:
			spawner.max_days = max_days

	if GameManager:
		GameManager.set_max_clients_per_day(max_clients_per_day)
		GameManager.set_max_days(max_days)

	if DayCycle and DayCycle.has_method("on_main_scene_ready"):
		DayCycle.on_main_scene_ready()

	if GameManager:
		GameManager.apply_wall_corruption(get_tree(), false)
