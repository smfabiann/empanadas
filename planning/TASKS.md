# Tablero Activo de Tareas (Task Board)

Tablero de tareas del proyecto. El agente toma tareas de este documento, actualiza su estado, aplica los cambios, verifica su funcionamiento y registra notas de entrega.

---

## 🏃 Tarea Activa

*(Ninguna en curso. Listo para tomar la siguiente tarea del backlog).*

---

## 📋 Backlog / Tareas Pendientes

### [TASK-003] Pulido de Menú de Pausa y Tecla Escape
- **Estado:** `[ ] PENDIENTE`
- **Fase:** Fase 2 - Menús, Navegación y UX
- **Archivos afectados:**
  - `res://scenes/ui/PauseMenu.tscn`
  - `res://scripts/PauseMenu.gd`
- **Descripción:**
  Asegurar que el menú de pausa capture y libere el cursor del ratón correctamente y permita reiniciar o volver al Menú Principal sin desconfigurar el cursor ni el árbol de escenas.

### [TASK-004] Sistema de Audio FX para Retroalimentación de Jugador
- **Estado:** `[ ] PENDIENTE`
- **Fase:** Fase 3 - Audio y Atmósfera Retro
- **Archivos afectados:**
  - `res://scripts/SFXManager.gd`
  - `res://scripts/Player.gd`
  - `res://scripts/NPC.gd`
- **Descripción:**
  Integrar sonidos al levantar un ítem, soltarlo y al recibir la validación (acierto o error) del pedido del cliente.

---

## ✅ Tareas Completadas

### [TASK-004] Subida Automática de Escalones y Desniveles (Stair Stepping)
- **Estado:** `[x] COMPLETADO`
- **Fase:** Fase 1/2 - Movimiento y Control del Jugador
- **Archivos afectados:**
  - `res://scripts/Player.gd`
- **Descripción:**
  Permitir al jugador subir de forma continua y fluida desniveles, bordes y escalones pequeños de hasta 25 cm (`MAX_STEP_HEIGHT = 0.25`) sin quedarse frenado ni requerir saltar.
- **Criterios de Aceptación (DoD):**
  - [x] Detecta desniveles verticales con `PhysicsServer3D.body_test_motion`.
  - [x] Eleva suavemente la posición si la altura del desnivel es menor o igual a 25 cm.
  - [x] Mantiene adherencia al suelo al bajar con `floor_snap_length = 0.25`.
  - [x] No atraviesa paredes altas ni techos bajos.

### [TASK-003] Mecánica de Sprint con Shift
- **Estado:** `[x] COMPLETADO`
- **Fase:** Fase 1/2 - Movimiento y Control del Jugador
- **Archivos afectados:**
  - `res://scripts/Player.gd`
  - `res://scenes/ui/MainMenu.tscn`
  - `planning/ARCHITECTURE.md`
- **Descripción:**
  Permitir al jugador correr manteniendo pulsada la tecla Shift (mapeada a la acción `sprint`), aumentando la velocidad de 3.5 a 5.8 m/s, con ajuste dinámico de Head Bobbing y FOV cinemático.
- **Criterios de Aceptación (DoD):**
  - [x] Al mantener Shift (`sprint`), la velocidad aumenta a 5.8 m/s.
  - [x] Al soltar Shift, la velocidad regresa a 3.5 m/s.
  - [x] Head bobbing se intensifica de forma proporcional a la velocidad de carrera.
  - [x] La cámara realiza una transición suave de FOV (75° a 82°) al esprintar.
  - [x] Controles actualizados en el Menú Principal y en la documentación técnica.

### [TASK-002] Corrección del Atasco de NPCs en Mostrador y Salida
- **Estado:** `[x] COMPLETADO`
- **Fase:** Fase 1/2 - Estabilidad del Bucle de Juego
- **Archivos afectados:**
  - `res://scenes/Main.tscn`
  - `res://scripts/NPC.gd`
  - `res://scripts/NPCSpawner.gd`
- **Descripción:**
  Los NPCs se quedaban atorados caminando eternamente contra la pared derecha al intentar salir, impidiendo que la cola avanzara y congelando el bucle de juego con clientes acumulados.
- **Criterios de Aceptación (DoD):**
  - [x] Los NPCs salen en línea recta por la puerta hacia la vereda sin chocar con paredes.
  - [x] Al entrar en estado de salida (`State.LEAVING`), la máscara de colisiones se desactiva y el mostrador se declara vacante de inmediato (`counter_vacated`).
  - [x] La cola avanza automáticamente al siguiente cliente sin esperar a que el anterior camine toda la salida.
  - [x] Temporizador de rescate automático para que ningún NPC quede residual en memoria si ocurre un bloqueo imprevisto.
- **Notas de Implementación / Registro del Agente:**
  - Se corrigió `ExitPoint` en `Main.tscn` de `(4, 0, -4.5)` (colisionaba de frente contra `WallRight` en X=3.9) a `(0, 0, -5.5)` (alineado a la puerta abierta hacia la calle).
  - En `NPC.gd`, se añadió la señal `counter_vacated`, desactivación de colisiones al retirarse y fade de escala antes del `queue_free()`.
  - En `NPCSpawner.gd`, se desacopló el avance de la cola: ahora avanza apenas el cliente del mostrador termina su pedido, logrando fluidez continua sin clientes atorados.

### [TASK-001] Corrección y Rediseño del Menú Principal
- **Estado:** `[x] COMPLETADO`
- **Fase:** Fase 2 - Menús, Navegación y UX
- **Archivos afectados:**
  - `res://scenes/ui/MainMenu.tscn`
  - `res://scripts/MainMenu.gd`
- **Descripción:**
  El menú principal presentaba todos los elementos amontonados en la misma posición vertical debido a una animación que forzaba `position.y` en tiempo de ejecución sobre los nodos hijos de un `VBoxContainer`, rompiendo el sistema de layout de Godot. Se rediseñó la escena y su script.

### [TASK-000] Prototipo Core Retail (Fase 1)
- **Estado:** `[x] COMPLETADO`
- **Fase:** Fase 1 - Prototipo Core Retail
- **Archivos afectados:**
  - `res://scripts/ItemData.gd`, `res://scripts/Interactable.gd`, `res://scripts/Player.gd`, `res://scripts/NPC.gd`, `res://scripts/GameManager.gd`, `res://scripts/UI.gd`
- **Notas:**
  Completadas todas las tareas iniciales del prototipo detalladas en `TODO.md`.
