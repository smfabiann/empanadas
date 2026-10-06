extends CanvasLayer
## UI minimalista para juego de terror / anomalías.
## Solo mira (crosshair), prompts contextuales de interacción y menú de pausa.

@onready var crosshair: ColorRect = $HUD/Crosshair
@onready var prompt_label: Label = $HUD/PromptLabel


func _ready() -> void:
	# Ocultar todos los elementos de arcade / vidas / puntuación
	for node_name in ["ScoreLabel", "LivesLabel", "ComboLabel", "DifficultyLabel", "TimeLabel", "GameOverPanel", "TutorialPanel", "DamageFlash", "SuccessFlash"]:
		var node = $HUD.get_node_or_null(node_name)
		if node:
			node.visible = false


func set_prompt(text: String, is_interactable: bool = false) -> void:
	if prompt_label:
		prompt_label.text = text
	if crosshair:
		if is_interactable:
			crosshair.color = Color(1.0, 0.85, 0.2, 1.0)
			crosshair.scale = Vector2(1.5, 1.5)
		else:
			crosshair.color = Color(1.0, 1.0, 1.0, 0.6)
			crosshair.scale = Vector2(1.0, 1.0)
