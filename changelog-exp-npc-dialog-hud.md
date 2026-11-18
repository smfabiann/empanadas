# Lista de cambios

## `exp/npc-dialog-hud` (candidato a v0.0.10 / v0.0.9-d)

> Rama experimental que reemplaza el diálogo flotante en 3D por una caja de diálogo estilo HUD con enfoque de cámara, audio posicional "crunchy" y escenas dedicadas para eventos estáticos.  
> *(La primera iteración en 3D con `SubViewport` quedó respaldada en la rama local `exp/npc-dialog-3d`.)*

- **Caja de diálogo HUD modular (`scenes/ui/DialogBoxHUD.tscn`, `scripts/ui/DialogBoxHUD.gd`, `scripts/ui/UI.gd`)**:
  - Panel inferior centrado con fondo negro (`Color(0, 0, 0, 0.94)`), borde y letras blancas con soporte **BBCode** (`RichTextLabel`) y nombre del hablante (`SpeakerLabel`).
  - Efecto máquina de escribir (`visible_characters`) con pausa sutil en puntuación y avance/salto mediante `[E]`, `Espacio`/`Enter` o clic izquierdo (`advance_or_skip()`).
  - Propiedades `@export` y diccionario `options` por línea para personalizar colores (`bg_color`, `border_color`, `text_color`, `speaker_color`), velocidad (`char_delay`) y voz (`pitch`, `audio`, `stream`).
  - Integrado en `UI.gd` mediante `get_dialog_box()` (instanciación perezosa sobre `$HUD`).

- **Audio posicional "crunchy" estilo Undertale (`DialogBoxHUD.gd`, `scenes/NPC.tscn`, `scripts/NPC.gd`)**:
  - Generador procedural `DialogBoxHUD.build_crunchy_blip()` (`AudioStreamWAV` a 8 kHz combinando onda cuadrada, ruido blanco y cuantización tipo bitcrush) reproducido con variación aleatoria de tono (`pitch_jitter`).
  - `VoicePlayer` (`AudioStreamPlayer3D`) en `scenes/NPC.tscn` (y creado automáticamente en `NPC._ready()` si una escena derivada no lo incluye) para que la voz suene desde la posición del cliente.

- **Interacción con el cliente y enfoque de cámara (`scripts/Player.gd`, `scripts/NPC.gd`)**:
  - `Label3D` sobre el NPC se mantiene mostrando únicamente su pedido flotante; el diálogo completo pasa al HUD al interactuar.
  - Con las manos vacías y mirando a un cliente en espera (`can_talk()`), el prompt muestra `[E] Hablar con cliente (Pide: ...)`.
  - Al presionar `[E]` (`_enter_npc_dialog()`), la cámara se acerca suavemente y enfoca la cabeza del cliente (`fov: 75 → 50`) mientras se abre `DialogBoxHUD`; al cerrar o con `ESC` (`_exit_npc_dialog()`), la cámara regresa a su posición y FOV originales.
  - Corregido `_handle_interact()` en `Player.gd` para que no retorne antes de tiempo cuando el `RayCast3D` golpea al propio NPC o al mostrador, y tipado explícito en `advance_click: bool`.

- **Eventos estáticos con HUD temático y escenas `.tscn` dedicadas**:
  - Corregido el crash del Día 2 (`Invalid assignment of property or key 'dialog_lines' with value of type 'Array' on a base object of type 'CharacterBody3D (NPC)'`) cambiando `dialog_lines` a `Array` sin tipo estricto y agregando `NPC.set_dialog(lines, speaker, options)`.
  - HUD temático por evento estático (colores, título y tono de voz propios):
    - **Visitante Espacial (`UfoNPC.gd`)**: HUD verde fósforo alienígena (`pitch: 1.48`).
    - **El Talquino (`TalquinoEvent.gd`)**: HUD dorado/café (`pitch: 0.95`).
    - **Asaltante (`RobberNPC.gd`)**: HUD rojo carmesí (`pitch: 0.72`).
    - **Estafador del chip (`ScammerEvent.gd`)**: HUD ámbar (`pitch: 0.85`).
    - **Repartidor Rappi (`RappiEvent.gd`)**: HUD naranja Rappi (`char_delay: 0.018`, `pitch: 1.15`).
  - Nuevas escenas heredadas de `NPC.tscn` en `scenes/events/static/` para los eventos que antes solo existían en código:
    - [`scenes/events/static/TalquinoNPC.tscn`](scenes/events/static/TalquinoNPC.tscn) (poncho y chupalla).
    - [`scenes/events/static/ScammerNPC.tscn`](scenes/events/static/ScammerNPC.tscn) (traje, lentes oscuros y credencial trucha).
    - [`scenes/events/static/RappiNPC.tscn`](scenes/events/static/RappiNPC.tscn) (uniforme naranja, casco, mochila con logo y moto con foco).
