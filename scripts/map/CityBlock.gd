@tool
class_name CityBlock
extends Node3D
## Genera una cuadra de edificios bajos de barrio (fachadas, ventanas encendidas,
## cortinas metálicas y letreros) a lo largo del eje X local.
## La fachada mira hacia +Z local y los edificios se extienden hacia -Z.
## Es determinista (semilla) y se ve también en el editor gracias a @tool.

## Largo total de la cuadra (metros, eje X local)
@export var block_length: float = 40.0:
	set(v):
		block_length = v
		_queue_rebuild()
## Fondo de los edificios (metros, hacia -Z local)
@export var depth: float = 6.0:
	set(v):
		depth = v
		_queue_rebuild()
## Rango de pisos por edificio
@export var min_floors: int = 1:
	set(v):
		min_floors = v
		_queue_rebuild()
@export var max_floors: int = 4:
	set(v):
		max_floors = v
		_queue_rebuild()
## Probabilidad de que una ventana esté encendida
@export_range(0.0, 1.0, 0.05) var lit_window_chance: float = 0.35:
	set(v):
		lit_window_chance = v
		_queue_rebuild()
## Semilla para que la cuadra siempre se genere igual
@export var seed_value: int = 1:
	set(v):
		seed_value = v
		_queue_rebuild()
## Genera colisión simple por edificio
@export var with_collision: bool = true
## Agrega una luz cálida sobre algunos letreros de los locales (hace legible la fachada de noche)
@export var sign_lights: bool = false:
	set(v):
		sign_lights = v
		_queue_rebuild()

const FLOOR_HEIGHT := 3.0
const FACADE_COLORS: Array[Color] = [
	Color(0.62, 0.48, 0.32), Color(0.36, 0.5, 0.52), Color(0.6, 0.38, 0.34),
	Color(0.5, 0.5, 0.47), Color(0.66, 0.6, 0.42), Color(0.38, 0.4, 0.5),
	Color(0.55, 0.45, 0.5), Color(0.42, 0.47, 0.36)
]
const SHOP_SIGNS: Array[String] = [
	"BOTILLERÍA", "FARMACIA", "PELUQUERÍA", "SE ARRIENDA", "CYBER", "MINIMARKET",
	"FERRETERÍA", "LAVASECO", "SE VENDE", "PANADERÍA", "FUENTE DE SODA", "CERRAJERÍA"
]

var _rebuild_queued: bool = false
var _mat_cache: Dictionary = {}


func _ready() -> void:
	rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	rebuild.call_deferred()


## Borra y vuelve a generar todos los edificios de la cuadra
func rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		if child.has_meta("generated"):
			remove_child(child)
			child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var x := 0.0
	var index := 0
	while x < block_length - 2.0:
		var width: float = minf(rng.randf_range(4.0, 8.0), block_length - x)
		var floors: int = rng.randi_range(maxi(min_floors, 1), maxi(max_floors, min_floors))
		_build_building(rng, index, x + width * 0.5, width, floors)
		x += width + rng.randf_range(0.0, 0.4)
		index += 1


func _mat(key: String, color: Color, emission: float = 0.0) -> StandardMaterial3D:
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _build_building(rng: RandomNumberGenerator, index: int, center_x: float, width: float, floors: int) -> void:
	var b := Node3D.new()
	b.name = "Edificio_%d" % index
	b.set_meta("generated", true)
	b.position = Vector3(center_x, 0, 0)
	add_child(b)

	var height: float = floors * FLOOR_HEIGHT
	var color: Color = FACADE_COLORS[rng.randi() % FACADE_COLORS.size()]
	var facade := _mat("facade_%d" % (index % FACADE_COLORS.size()), color.darkened(0.25))
	_box(b, Vector3(width, height, depth), Vector3(0, height * 0.5, -depth * 0.5), facade)
	# Cornisa
	_box(b, Vector3(width + 0.2, 0.25, 0.35), Vector3(0, height + 0.12, -0.1), _mat("cornice", Color(0.25, 0.24, 0.23)))

	var lit := _mat("window_lit", Color(1.0, 0.8, 0.45), 1.6)
	var lit_tv := _mat("window_tv", Color(0.45, 0.6, 1.0), 1.4)
	var dark := _mat("window_dark", Color(0.06, 0.07, 0.09))
	var frame := _mat("frame", Color(0.15, 0.14, 0.13))
	var cols: int = maxi(1, int(width / 2.2))
	var spacing: float = width / cols

	# Pisos superiores: ventanas
	for f in range(1, floors):
		for c in cols:
			var wx: float = -width * 0.5 + spacing * (c + 0.5)
			var wy: float = f * FLOOR_HEIGHT + 1.5
			var roll := rng.randf()
			var wmat: Material = dark
			if roll < lit_window_chance:
				wmat = lit_tv if roll < lit_window_chance * 0.15 else lit
			_box(b, Vector3(1.0, 1.25, 0.06), Vector3(wx, wy, 0.03), frame)
			_box(b, Vector3(0.86, 1.1, 0.08), Vector3(wx, wy, 0.04), wmat)

	# Primer piso: local comercial con cortina metálica o puerta y ventana
	var shutter := _mat("shutter", Color(0.32, 0.33, 0.35))
	if rng.randf() < 0.6:
		var sw: float = minf(width - 1.0, 3.6)
		_box(b, Vector3(sw, 2.4, 0.08), Vector3(0, 1.2, 0.04), shutter)
		for s in 8:
			_box(b, Vector3(sw, 0.03, 0.1), Vector3(0, 0.25 + s * 0.28, 0.05), frame)
		if rng.randf() < 0.75:
			var sign_text: String = SHOP_SIGNS[rng.randi() % SHOP_SIGNS.size()]
			_box(b, Vector3(sw, 0.55, 0.12), Vector3(0, 2.75, 0.06), _mat("signboard_%d" % (index % 3), color.lightened(0.2)))
			var lbl := Label3D.new()
			lbl.text = sign_text
			lbl.font_size = 64
			lbl.pixel_size = 0.0055
			lbl.outline_size = 8
			lbl.modulate = Color(0.12, 0.1, 0.1)
			lbl.outline_modulate = Color(1, 1, 1, 0.25)
			lbl.position = Vector3(0, 2.75, 0.14)
			b.add_child(lbl)
			if sign_lights:
				var lamp := OmniLight3D.new()
				lamp.light_color = Color(1.0, 0.78, 0.5)
				lamp.light_energy = 1.6
				lamp.omni_range = 5.0
				lamp.position = Vector3(0, 3.3, 0.9)
				b.add_child(lamp)
	else:
		_box(b, Vector3(1.0, 2.2, 0.08), Vector3(-width * 0.25, 1.1, 0.04), _mat("door", Color(0.3, 0.2, 0.12)))
		var ground_win: Material = lit if rng.randf() < lit_window_chance else dark
		_box(b, Vector3(1.4, 1.1, 0.08), Vector3(width * 0.2, 1.5, 0.04), ground_win)

	if with_collision:
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(width, height, depth)
		col.shape = shape
		col.position = Vector3(0, height * 0.5, -depth * 0.5)
		body.add_child(col)
		b.add_child(body)
