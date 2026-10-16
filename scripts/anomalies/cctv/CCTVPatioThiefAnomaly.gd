class_name CCTVPatioThiefAnomaly
extends CCTVEventAnomaly
## "Ladrón del patio": alguien se cuela por el patio trasero (CAM 02), fuerza la
## puerta de atrás y se mete a robar la caja.
##
## Desde el mostrador solo se oye el forcejeo: hay que revisar la CAM 02 y cerrar
## la puerta trasera antes de que entre. Si la puerta se cierra mientras él sigue
## afuera, arranca. Si logra entrar, se lleva plata y escapa por donde vino.
## A diferencia de otros eventos de CCTV, es una persona real: también se ve en el
## mundo (por ejemplo, si el jugador mira por la puerta abierta).

## Velocidad de caminata (m/s)
@export var walk_speed: float = 1.1
## Velocidad al huir (m/s)
@export var flee_speed: float = 3.8
## Segundos forcejeando la puerta antes de abrirla
@export var force_time: float = 4.0
## Segundos que espera en la puerta abierta antes de meterse
@export var grace_time: float = 6.0
## Plata que se lleva si logra entrar
@export var steal_amount: int = 5000

enum Phase { APPROACH, FORCING, LURKING, ENTERING, ESCAPING, FLEEING, DONE }

var phase: Phase = Phase.APPROACH
var door: Node3D = null
var did_steal: bool = false
var was_repelled: bool = false
## true si la puerta la abrió él (para que el test y los logs lo distingan)
var forced_door: bool = false

var _silhouette: Node3D = null
var _start: Vector3
var _outside_point: Vector3
var _inside_point: Vector3
var _phase_time: float = 0.0
var _bob: float = 0.0


func _init_anomaly(context: Dictionary = {}) -> void:
	anomaly_id = "cctv_patio_thief"
	short_description = "Un ladrón entra por el patio y fuerza la puerta trasera. Hay que cerrarla a tiempo."
	tags = ["cctv", "visual", "ladron", "patio"]
	if allowed_channels.is_empty():
		allowed_channels = PackedStringArray(["patio"])
	event_duration = 0.0
	door = _find_door()
	super._init_anomaly(context)
	if zone == null or visuals_3d == null:
		return
	if door == null or _another_thief_active():
		if debug_log:
			print("[CCTV] Ladrón del patio descartado (sin puerta trasera o ya hay uno).")
		call_deferred("resolve")
		return
	_make_world_visible(visuals_3d)

	_start = global_position
	var door_center: Vector3 = door.get_doorway_center()
	var into_patio := (_start - door_center)
	into_patio.y = 0.0
	var normal: Vector3 = door.get_doorway_normal()
	if normal.dot(into_patio) < 0.0:
		normal = -normal
	_outside_point = Vector3(door_center.x, _start.y, door_center.z) + normal * 0.7
	_inside_point = Vector3(door_center.x, door_center.y, door_center.z) - normal * 1.6


func _find_door() -> Node3D:
	if not is_inside_tree():
		return null
	var found := get_tree().get_first_node_in_group("back_door") as Node3D
	if found and found.has_method("get_doorway_center"):
		return found
	return null


func _another_thief_active() -> bool:
	if get_parent() == null:
		return false
	for node in get_parent().get_children():
		if node != self and node is CCTVPatioThiefAnomaly and not node.is_resolved:
			return true
	return false


## Elige la zona del patio más lejana a la puerta, para que se le vea cruzar el patio
func _pick_zone() -> Node3D:
	if door == null:
		return super._pick_zone()
	var best: Node3D = null
	var best_dist := -1.0
	for z in get_tree().get_nodes_in_group("cctv_zones"):
		if not (z is Node3D):
			continue
		if not allowed_channels.is_empty() and not allowed_channels.has(str(z.get("channel_id"))):
			continue
		var d: float = (z as Node3D).global_position.distance_to(door.global_position)
		if d > best_dist:
			best_dist = d
			best = z
	return best


func _build_visuals() -> void:
	_silhouette = build_silhouette(1.78, Color(0.9, 0.9, 0.8))
	var hoodie := StandardMaterial3D.new()
	hoodie.albedo_color = Color(0.09, 0.1, 0.14)
	for part in ["Body", "Head"]:
		var mesh := _silhouette.get_node_or_null(part) as MeshInstance3D
		if mesh:
			mesh.material_override = hoodie

	# Gorro de lana
	var beanie_mat := StandardMaterial3D.new()
	beanie_mat.albedo_color = Color(0.55, 0.08, 0.08)
	var beanie := MeshInstance3D.new()
	beanie.name = "Beanie"
	var beanie_mesh := SphereMesh.new()
	beanie_mesh.radius = 0.155
	beanie_mesh.height = 0.2
	beanie.mesh = beanie_mesh
	beanie.material_override = beanie_mat
	beanie.position = Vector3(0, 1.66, 0)
	_silhouette.add_child(beanie)

	# Mochila para la plata
	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.2, 0.22, 0.12)
	var bag := MeshInstance3D.new()
	bag.name = "Bag"
	var bag_mesh := BoxMesh.new()
	bag_mesh.size = Vector3(0.32, 0.4, 0.16)
	bag.mesh = bag_mesh
	bag.material_override = bag_mat
	bag.position = Vector3(0, 1.0, 0.2)
	_silhouette.add_child(bag)

	visuals_3d.add_child(_silhouette)


## Lo devuelve a la capa normal del mundo (la base lo dejó solo en la capa de CCTV)
static func _make_world_visible(root: Node) -> void:
	if root is VisualInstance3D:
		(root as VisualInstance3D).layers = 1
	for child in root.get_children():
		_make_world_visible(child)


func is_door_open() -> bool:
	return door != null and door.get("is_open") == true


func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	if debug_log:
		print("[CCTV] Ladrón del patio: ", Phase.keys()[new_phase])


func _update_event(delta: float) -> void:
	if _silhouette == null or door == null:
		return
	_phase_time += delta
	match phase:
		Phase.APPROACH:
			if _walk_to(_outside_point, walk_speed, delta):
				if is_door_open():
					_set_phase(Phase.LURKING)
				else:
					_set_phase(Phase.FORCING)
					if door.has_method("jiggle"):
						door.jiggle(force_time)
					_play_sfx("play_drop")
					_hint("Se escucha forcejeo en la puerta de atrás... revisa la CAM 02 [A/D].")
		Phase.FORCING:
			face_point_flat(_silhouette, _inside_point)
			_silhouette.position.y = -0.25  # agachado frente a la chapa
			if is_door_open():
				_silhouette.position.y = 0.0
				_set_phase(Phase.LURKING)
			elif _phase_time >= force_time:
				_silhouette.position.y = 0.0
				forced_door = true
				if door.has_method("open"):
					door.open()
				_play_sfx("play_npc_arrive")
				_set_phase(Phase.LURKING)
		Phase.LURKING:
			face_point_flat(_silhouette, _inside_point)
			if not is_door_open():
				_flee()
			elif _phase_time >= grace_time:
				_set_phase(Phase.ENTERING)
		Phase.ENTERING:
			# Mientras siga afuera, cerrar la puerta lo deja fuera
			if not is_door_open() and _is_outside():
				_flee()
			elif _walk_to(_inside_point, walk_speed, delta):
				_steal()
		Phase.ESCAPING:
			if _walk_to(_start, flee_speed, delta):
				_finish()
		Phase.FLEEING:
			if _walk_to(_start, flee_speed, delta):
				_finish()


## Camina en el plano XZ hacia `target`; devuelve true al llegar
func _walk_to(target: Vector3, speed: float, delta: float) -> bool:
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var to := flat_target - global_position
	if to.length() <= 0.05:
		global_position = flat_target
		_silhouette.position.y = 0.0
		return true
	face_point_flat(_silhouette, flat_target)
	global_position = global_position.move_toward(flat_target, speed * delta)
	_bob += delta * speed * 6.0
	_silhouette.position.y = absf(sin(_bob)) * 0.04
	return false


func _is_outside() -> bool:
	var door_center: Vector3 = door.get_doorway_center()
	return (global_position - door_center).dot(_outside_point - door_center) > 0.0


func _flee() -> void:
	was_repelled = true
	_silhouette.position.y = 0.0
	_set_phase(Phase.FLEEING)
	_hint("Cerraste la puerta trasera: el ladrón arrancó por el patio.")


func _steal() -> void:
	did_steal = true
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		GameManager.lose_money(steal_amount, "Robo por la puerta trasera")
	_play_sfx("play_money_lost")
	_hint("¡Se metieron por la puerta de atrás y se llevaron plata de la caja!")
	_set_phase(Phase.ESCAPING)


func _finish() -> void:
	phase = Phase.DONE
	resolve()


func _play_sfx(method: String) -> void:
	if typeof(SFXManager) != TYPE_NIL and SFXManager != null and SFXManager.has_method(method):
		SFXManager.call(method)


func _hint(text: String) -> void:
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("request_hint"):
		GameManager.request_hint(text)
