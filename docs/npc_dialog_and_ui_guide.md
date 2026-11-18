# Guía simple: Diálogo de NPCs, Audio y UI modular (`v0.0.9-d`)

Resumen rápido de **qué se puede personalizar** (en el Inspector o en código) y **qué conviene no tocar**.

---

## 1. Qué SÍ puedes personalizar en el Inspector (sin código)

### Caja de diálogo HUD (`scenes/ui/DialogBoxHUD.tscn` o dentro de `scenes/UI.tscn`)
Selecciona el nodo `DialogBoxHUD`:
- **Design:** `default_text_color`, `default_bg_color`, `default_border_color`, `border_width`, `corner_radius`, `font_size`, `speaker_color`.
- **Typewriter:** `default_char_delay` (velocidad por letra), `punctuation_pause` (pausa en `. ! ?`).
- **Audio:** `audio_enabled`, `default_voice_pitch`, `pitch_jitter`, `chars_per_blip`, `crunch_amount` (qué tan "crunchy" suena), `custom_voice_stream` (arrastra tu propio `.wav`/`.ogg` si no quieres el sonido procedural).

### NPCs y sonidos de entrega (`scenes/NPC.tscn` y `scenes/events/static/*.tscn`)
- **`correct_order_sound`** (en el nodo raíz `NPC`): arrastra cualquier `.wav` / `.mp3` / `.ogg` para que suene al entregar el pedido correcto.
- **`VoicePlayer`** (`AudioStreamPlayer3D`): ajusta `volume_db`, `unit_size` o `max_distance` para el audio posicional.
- **`Label3D`**: sigue mostrando el pedido flotante sobre la cabeza; puedes cambiar su fuente, tamaño o altura.
- **Escenas de eventos estáticos** (`TalquinoNPC.tscn`, `ScammerNPC.tscn`, `RappiNPC.tscn`, `UfoNPC.tscn`, `RobberNPC.tscn`): puedes abrirlas y editar sombrero, lentes, mochila, moto o materiales directo en 3D.

### Paneles de la UI (`scenes/ui/`)
Cada panel es su propia escena editable visualmente:
- `DayPanel.tscn`, `HintPanel.tscn`, `DebugPanel.tscn`, `GameOverPanel.tscn`, `DayEndPanel.tscn`, `VictoryPanel.tscn`, `IntroPanel.tscn`, `DialogBoxHUD.tscn`.

---

## 2. Qué puedes personalizar por código (por NPC o evento)

Usa `npc.set_dialog(lines, speaker, options)` (soporta BBCode como `[color=yellow]texto[/color]`):

```gdscript
npc.set_dialog(
	["¡Hola! Quiero un [color=yellow]Completo Italiano[/color]."],
	"Cliente",
	{
		"bg_color": Color(0, 0, 0, 0.94),
		"border_color": Color.WHITE,
		"text_color": Color.WHITE,
		"speaker_color": Color(1.0, 0.9, 0.35, 1.0),
		"char_delay": 0.026,
		"pitch": 1.0,
		"audio": true,
		# "stream": preload("res://assets/audio/tu_sonido.wav"),
	}
)
```

---

## 3. Qué NO conviene cambiar (fijo por código / tests)

- **Nombres y jerarquía de nodos dentro de `scenes/ui/*.tscn`** (por ejemplo `DayPanel/VBoxContainer/DayLabel`, `HintPanel/HintLabel`, `GameOverPanel/VBoxContainer/RetryButton`): `UI.gd` y los tests los buscan por esa ruta exacta. *(Mover posición, colores, tamaños o estilos sí es seguro.)*
- **El nodo `Label3D` en `NPC.tscn`:** no lo elimines ni lo renombres; además de mostrar el pedido flotante, varios tests (`test_poop_mechanic`, `test_stacking_hu`, `test_shadow_companion`) leen `npc.label.text`.
- **Enfoque de cámara al hablar (`Player.gd`):** el zoom (`fov = 50.0`), la distancia de acercamiento (`0.45`) y los tiempos de transición (`0.24s` / `0.20s`) están definidos en `_enter_npc_dialog()` y `_exit_npc_dialog()` en `scripts/Player.gd` (no están expuestos como `@export` en el Inspector).
