# Rúbrica Alpha: estado y brechas (140 pts)

Revisión del 14-10-2026 sobre la rama `v0.123` (commit `8676756`, con HU-10). Entrega: semana del 9 de noviembre. Actualizar este documento a medida que se cierren brechas.

| Ítem | Pts máx | Estado | Estimado hoy |
|---|---|---|---|
| Identificación | 5 | Falta | 0 |
| Entrega (ejecutable) | 5 | Falta | 0 |
| Meta | 10 | Cumple (16-10) | 10 |
| Desafío | 10 | Cumple (16-10) | 10 |
| Ventanas de inicio y fin | 10 | Cumple (16-10, verificar) | 10 |
| Flujo completo | 20 | Cumple (verificar) | 20 |
| Mecánicas principales | 20 | Cumple (verificar bugs) | 20 |
| Arte y sonidos | 20 | Parcial (escenario mejorado) | 10 |
| Documentación | 20 | Parcial | 10 |
| Avance | 20 | Depende de clases | ? |

## 1. Identificación (5): falta
- **Evidencia:** `scenes/ui/MainMenu.tscn` sólo dice "EMPANADAS", "ALPHA v0.1" y "Taller de Juegos — 2026". No hay nombres de integrantes, paralelo ni créditos. `project.godot` tiene `config/name="empanadas"`.
- **Para cerrarlo:** agregar en el menú (o en un botón "Créditos") nombre del juego, integrantes, paralelo y créditos de contenido externo (ej. `resources/npc_textures/nachito.jpg`, fuentes, cualquier asset bajado). Lo mismo va en el PDF de entrega.

## 2. Entrega (5): falta
- **Evidencia:** no existe `export_presets.cfg` y `.gitignore` excluye `/export/`, o sea nunca se ha exportado.
- **Para cerrarlo:** crear preset Windows (o Web) en Proyecto → Exportar, con nombre claro (ej. `Empanadas_Alpha_Win.exe`) y probar el .exe en otro PC. "Soportes claros de resoluciones": ya hay `stretch/mode="canvas_items"` y `aspect="expand"`; falta fijar una resolución base (`window/size/viewport_width/height`), probar 1366×768, 1920×1080 y ultrawide, y decir en el PDF qué resoluciones se soportan (idealmente opción de pantalla completa / ventana).

## 3. Meta (10): parcial
- **Evidencia:** la meta existe en código (`max_days = 3` en `GameManager.gd`, victoria en `UI.gd::_on_game_won`), pero el jugador sólo la descubre al ganar. El menú dice "Atiende el local · Sirve rápido · Sobrevive" y el HUD muestra "Día 1 · Clientes 0/8", sin decir "de 3".
- **Para cerrarlo:** decir explícitamente al inicio "Sobrevive 3 noches atendiendo el local" (esto es lo de HU-05 intro) y mostrar "Noche 1/3" en el HUD y en el banner de día.

## 4. Desafío (10): parcial
- **Evidencia:** hay presión de tiempo (paciencia), recetas exactas de completos, ladrón armado, anomalías y CCTV (HU-10). Pero la **única** forma de perder es el ladrón (`trigger_game_over` sólo se llama en `RobberNPC.gd:437`). Errar pedidos o dejar ir clientes no tiene consecuencia, y mecánicas como la persiana, el CCTV, la cama o el baño no se explican en ningún lado.
- **Para cerrarlo:** (a) que el juego enseñe las herramientas: instrucciones en pantalla o tutorial para persiana, CCTV, armado de completos y menú de recetas; (b) idealmente una condición de derrota más por desempeño (ej. demasiados clientes perdidos o anomalías no atendidas) para que el desafío se sienta en toda la partida, no sólo con el ladrón. HU-07 (dificultad) encaja aquí.

## 5. Ventanas de inicio y fin (10): parcial (una falencia → 5)
- **Inicio:** tiene identificación del juego e instrucciones de controles (`WASD | Shift | E | Q | ESC`), pero **no describe la mecánica principal** (atender clientes, armar completos, vigilar anomalías) y los controles están incompletos (falta Espacio para saltar, persiana, monitor CCTV, etc.).
- **Fin:** victoria bien resuelta (dice lo logrado: "sobreviviste los 3 días… escapar de la ciudad" + estadísticas). Game over muestra el motivo y "Clientes atendidos · Día N", aceptable. La escena de Game Over en `UI.tscn` aún arrastra textos arcade antiguos ("Puntaje", "Mejor", "Combo", "Dificultad: Fácil") que se ocultan por código; conviene limpiarlos.
- **Arte:** las ventanas son paneles de UI con colores/temática, integración básica OK; un fondo o imagen del local en el menú lo haría más sólido.
- **Para cerrarlo:** pantalla de "Cómo jugar" (o intro de HU-05) con la mecánica principal y todos los controles.

## 6. Flujo completo (20): probablemente cumple
- **Evidencia:** Menú → Día 1..3 con cupo de clientes → fin de jornada → siguiente día → victoria, con game over y reintentar/menú. Todo existe.
- **Para asegurarlo:** grabar una partida completa de principio a fin (también se pide en el formato de entrega) y confirmar que no hay bloqueos.

## 7. Mecánicas principales (20): probablemente cumple
- **Evidencia:** movimiento, recoger/soltar, armado de completos, pedidos con validación, paciencia, eventos (Fast, BigHead, Ladrón, OVNI), anomalías, CCTV, días, victoria/derrota. Hay tests en `tests/`.
- **Riesgo:** la nota exige "sin más de 2 bugs críticos". Pasar una ronda de QA antes de entregar (en el .exe exportado, no sólo en el editor).

## 8. Arte y sonidos (20): mayor riesgo
- **Evidencia:** casi todo el arte es geometría primitiva de Godot más un shader de cielo; la única imagen es `nachito.jpg`. Todo el audio es **procedural** (`AudioStreamGenerator` en `SFXManager.gd`): no hay archivos de sonido ni música, y no hay pasos ni ambiente.
- **Para cerrarlo:** integrar assets reales en al menos ~40% del juego: modelos o texturas para el local, clientes e ítems; música ambiente nocturna; SFX de pasos, puerta/persiana, timbre. Esto coincide con HU-08 (ambientación del mapa). Recordar acreditarlos (ítem 1).

## 9. Documentación (20): parcial
- **Evidencia:** en la rama local `planning/` sólo tiene ARCHITECTURE, GUIA_DESARROLLO, README y ROADMAP (228 líneas en total), más `docs/anomalies_workflow.md` y changelogs. Es documentación técnica, **no hay GDD** (visión, meta, mecánicas, controles, loop, arte, audio, historia). Ojo: la carpeta compartida del proyecto tiene una versión más antigua de `planning/` con ESTADO_ACTUAL, INVENTARIO, TASKS, etc. que ya no está en la rama local.
- **Para cerrarlo:** escribir un GDD corto que describa ≥80% del juego (concepto, meta de 3 noches, mecánicas, eventos y anomalías, controles, arte y audio, flujo de pantallas) y una sección de proceso (historias de usuario/issues HU-xx, roadmap, changelog por versión). Las issues de GitHub sirven como evidencia del proceso.

## 10. Avance (20): depende de lo presentado en clases
- No se puede verificar desde el código. Hay commits desde el 9 de septiembre y versiones v0.0.5, v0.0.6 y v0.123. Si se mostraron 3 avances jugables en clase, son 20 pts; si no, presentar los que queden antes del 9 de noviembre.

## Actualización 16-10-2026 (juego completo de Alpha)
- **Meta:** la intro dice explícitamente "3 noches para escapar": juntar $50.000 para el pasaje partiendo con $20.000. El HUD muestra "Noche N/3" y la plata que falta, y el local tiene alcancía y calendario.
- **Desafío:** ahora hay dos formas de perder (el disparo del ladrón y no juntar la plata del pasaje) y la economía hace que cada pedido equivocado, cliente perdido, robo o estafa cuente durante toda la partida.
- **Ventanas:** la intro incluye "Cómo jugar" con la mecánica principal y todos los controles (persiana, olla, monitor, cama). El final distingue escape (victoria) y "Te quedaste en la ciudad" (derrota), en español.
- **Arte y sonido:** barrio nocturno (cuadras con ventanas y letreros iluminados, neón, paradero, auto, árboles, postes), olla con vapor y ambiente sonoro en loop. Sigue siendo geometría CSG y audio procedural: falta integrar assets reales para el 40%.
- **Pendiente igual que antes:** exportar el ejecutable (ítem 2), GDD (ítem 9) y QA en el .exe.

## Prioridades sugeridas
1. **Rápido y barato (≈20 pts en juego):** créditos e identificación, exportar el .exe con resoluciones, pantalla "Cómo jugar" con meta y controles, "Noche N/3" en el HUD.
2. **Más trabajo, más puntos:** arte y audio reales (HU-08), y el GDD.
3. **Pulido:** condición de derrota extra o dificultad (HU-07), limpieza del panel Game Over, QA en el ejecutable y video de partida completa.
