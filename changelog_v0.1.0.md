# Lista de cambios v0.1.0 (Anomalías y Cámaras)

- **Sistema de Monitor de Seguridad y Cámaras**:
  - Implementación de un monitor de seguridad funcional en `shop.tscn` que usa un `SubViewport` para renderizar el feed de una cámara de vigilancia en tiempo real sobre la pared del local.
  - Corrección de mapeo UV (giro de 90 grados) en la pantalla `CSGBox3D` del monitor para mostrar la cámara con la orientación correcta en vertical.
  - **Interacción y Cámara (`SecurityMonitor.gd` y `Player.gd`)**: Al interactuar con el monitor, el jugador asume el control visual de la cámara de seguridad. El personaje del jugador (movimiento WASD y ratón) se congela completamente por inmersión y prevención de bugs hasta que vuelve a presionar `[E]` para salir.
- **Mecánica de Visión de Anomalías (Visión Pálida / Nocturna)**:
  - Nueva mecánica ligada al monitor: Al estar observando por la cámara, presionar la tecla `[F]` activa un modo de visión especial.
  - Se modificó dinámicamente el `Environment` de Godot para sobrescribir los ajustes de color en la cámara (alta desaturación, mayor brillo y contraste) para lograr un estilo tétrico y pálido ideal para buscar anomalías.
  - El filtro se aplica tanto al modo pantalla completa del jugador como al material renderizado en la propia caja 3D de la pared.
- **Mejoras en la Interfaz (UI)**:
  - Se movió el cartel de interacción (`PromptLabel`) de la zona muerta central hacia el centro-inferior de la pantalla para evitar que obstruya la visión del cursor y los modelos 3D.
  - Se redujo sutilmente el tamaño de fuente (de 18 a 14) y se configuró su crecimiento en `grow_vertical = 0` para manejar múltiples renglones de prompts dinámicos correctamente (ej: `[E] Volver\n[F] Visión Nocturna`).
