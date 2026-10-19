class_name EscapeProgressProp
extends Node3D
## Objetos del local que muestran el avance de la historia en el mundo 3D:
## - JAR: alcancía en el mostrador con los ahorros para el pasaje (se llena).
## - CALENDAR: calendario en la pared con la noche actual y las noches tachadas.

enum Mode { JAR, CALENDAR }

@export var mode: Mode = Mode.JAR
## Label3D que muestra el texto (por defecto el hijo "Text")
@export var text_label: Label3D
## Nodo con origen en la base que se escala en Y según el porcentaje ahorrado (solo JAR, por defecto el hijo "Fill")
@export var fill_node: Node3D

var _fill_full_height: float = 1.0


func _ready() -> void:
	if text_label == null:
		text_label = get_node_or_null("Text") as Label3D
	if fill_node == null:
		fill_node = get_node_or_null("Fill") as Node3D
	if fill_node:
		_fill_full_height = maxf(fill_node.scale.y, 0.001)
	if not GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.connect(_on_money_changed)
	if not GameManager.day_started.is_connected(_on_day_started):
		GameManager.day_started.connect(_on_day_started)
	refresh()


func _exit_tree() -> void:
	if GameManager.money_changed.is_connected(_on_money_changed):
		GameManager.money_changed.disconnect(_on_money_changed)
	if GameManager.day_started.is_connected(_on_day_started):
		GameManager.day_started.disconnect(_on_day_started)


func _on_money_changed(_savings: int, _delta: int, _reason: String) -> void:
	refresh()


func _on_day_started(_day: int, _max_clients: int) -> void:
	refresh()


func refresh() -> void:
	match mode:
		Mode.JAR:
			var ratio: float = clampf(float(GameManager.savings) / float(maxi(GameManager.escape_goal, 1)), 0.0, 1.0)
			if text_label:
				text_label.text = "PASAJE\n$%s / $%s" % [GameManager.format_money(GameManager.savings), GameManager.format_money(GameManager.escape_goal)]
			if fill_node:
				# El nodo Fill tiene su origen en la base: escalar Y "llena" la alcancía hacia arriba
				fill_node.scale.y = maxf(_fill_full_height * ratio, 0.001)
		Mode.CALENDAR:
			if text_label:
				var total: int = maxi(GameManager.max_days, 1)
				var marks: Array[String] = []
				for d in range(1, total + 1):
					if d < GameManager.current_day:
						marks.append("[X]")
					elif d == GameManager.current_day:
						marks.append("[%d]" % d)
					else:
						marks.append("[ ]")
				text_label.text = "NOCHE %d DE %d\n%s\nBUS: 06:00 AM" % [GameManager.current_day, total, " ".join(marks)]
