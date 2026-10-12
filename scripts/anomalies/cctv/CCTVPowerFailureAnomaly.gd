class_name CCTVPowerFailureAnomaly
extends CCTVEventAnomaly
## "Fallo eléctrico" (HU-10): una caja eléctrica chisporrotea en una zona vigilada
## y la señal de ese canal se llena de interferencia, con cortes de "SIN SEÑAL".
## Otros canales no se ven afectados.

## Interferencia base del canal mientras dura el fallo (0..1)
@export_range(0.0, 1.0, 0.05) var base_interference: float = 0.35
## Probabilidad por segundo de un corte total de señal
@export_range(0.0, 1.0, 0.05) var blackout_chance: float = 0.45

var _blackout_left: float = 0.0
var _spark_light: MeshInstance3D = null
var _sparks: CPUParticles3D = null
var _flicker: float = 0.0


func _init_anomaly(context: Dictionary = {}) -> void:
	anomaly_id = "cctv_power_failure"
	short_description = "Un fallo eléctrico interfiere la señal de una cámara."
	tags = ["cctv", "visual", "electrico"]
	add_to_group("cctv_feed_modifiers")
	super._init_anomaly(context)


func _build_visuals() -> void:
	var box_mat := StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.22, 0.24, 0.2)
	var box := MeshInstance3D.new()
	box.name = "ElectricBox"
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.7, 0.2)
	box.mesh = box_mesh
	box.material_override = box_mat
	box.position = Vector3(0, 1.3, 0)
	visuals_3d.add_child(box)

	# Poste que sostiene la caja (así funciona en cualquier zona, con o sin muro)
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.08, 1.0, 0.08)
	pole.mesh = pole_mesh
	pole.material_override = box_mat
	pole.position = Vector3(0, 0.5, 0.05)
	visuals_3d.add_child(pole)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.7, 0.85, 1.0)
	glow_mat.disable_fog = true
	_spark_light = MeshInstance3D.new()
	_spark_light.name = "Arc"
	var arc_mesh := SphereMesh.new()
	arc_mesh.radius = 0.09
	arc_mesh.height = 0.18
	_spark_light.mesh = arc_mesh
	_spark_light.material_override = glow_mat
	_spark_light.position = Vector3(0, 1.15, -0.14)
	visuals_3d.add_child(_spark_light)

	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.85, 0.4)
	spark_mat.disable_fog = true
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.025, 0.025)
	spark_mesh.material = spark_mat
	_sparks = CPUParticles3D.new()
	_sparks.name = "Sparks"
	_sparks.mesh = spark_mesh
	_sparks.amount = 24
	_sparks.lifetime = 0.6
	_sparks.explosiveness = 0.6
	_sparks.direction = Vector3(0, 0.3, -1)
	_sparks.spread = 60.0
	_sparks.initial_velocity_min = 1.0
	_sparks.initial_velocity_max = 2.5
	_sparks.gravity = Vector3(0, -6.0, 0)
	_sparks.position = _spark_light.position
	visuals_3d.add_child(_sparks)


func _update_event(delta: float) -> void:
	_blackout_left = maxf(_blackout_left - delta, 0.0)
	if _blackout_left <= 0.0 and randf() < blackout_chance * delta:
		_blackout_left = randf_range(0.4, 1.2)

	# Parpadeo irregular del arco eléctrico
	_flicker -= delta
	if _flicker <= 0.0 and _spark_light:
		_spark_light.visible = randf() < 0.6
		if _sparks:
			_sparks.emitting = _spark_light.visible
		_flicker = randf_range(0.04, 0.25)


## Usado por SecurityMonitor: interferencia que este fallo aporta al canal indicado
func get_feed_interference(target_channel_id: String) -> float:
	if is_resolved or not is_active or target_channel_id != channel_id:
		return 0.0
	if _blackout_left > 0.0:
		return 1.0
	return base_interference


func resolve() -> void:
	if is_in_group("cctv_feed_modifiers"):
		remove_from_group("cctv_feed_modifiers")
	super.resolve()
