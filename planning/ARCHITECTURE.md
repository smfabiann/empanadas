# Arquitectura del Proyecto

## 1. Configuración Base

- **Motor:** Godot 4 (3D)
- **Escena inicial:** `res://scenes/ui/MainMenu.tscn`
- **Escena principal de juego:** `res://scenes/Main.tscn`
- **Autoloads (Singletons):**
  - `GameManager` (`res://scripts/GameManager.gd`): Estado global de partida, jornadas (3 días canónicos), clientes atendidos/perdidos, señales de UI y game over/victoria.
  - `SFXManager` (`res://scripts/SFXManager.gd`): Generación procedural y reproducción de efectos de sonido.
- **Capas de colisión 3D:**
  - Layer 1: `World` (entorno, muros, suelo)
  - Layer 2: `Interactable` (ítems recogibles, estaciones de cocina)
  - Layer 3: `NPC` (clientes, ladrón)

## 2. Jerarquía de la Escena de Juego (`Main.tscn`)

- `Main (Node3D)`
  - `Environment/WorldEnvironment`: Iluminación y niebla nocturna.
  - `Map`: Entorno del local (`shop.tscn`, `shelf.tscn`, `KitchenStations.tscn`, luces).
  - Marcadores de navegación: `SpawnPoint`, `WindowPoint`, `ExitPoint` (Marker3D).
  - `Player`: Controlador en primera persona (`Player.tscn`).
  - `UI`: CanvasLayer HUD, paneles y menús (`UI.tscn`).
  - `NPCSpawner`: Generador y temporizador de clientes con integración a eventos.
  - `NPCEventManager`: Gestor y catálogo de eventos de NPCs.
  - `AnomaliesManagement`: Gestor central de anomalías modulares (`AnomaliesManager.gd`).

## 3. Módulos Principales

- **Jugador (`Player.gd` + `Player.tscn`):**
  - Movimiento FPS, sprint, salto, cámara y `RayCast3D`.
  - Recoger, portar, ensamblar y entregar ítems (`Interactable`).
  - Bloqueo de interacción si `not GameManager.can_player_act()`.
- **Clientes (`NPC.gd` + `NPC.tscn`):**
  - Máquina de estados: `APPROACHING` -> `WAITING` -> `REACTING` -> `LEAVING`.
  - Paciencia con barra visible (`PatienceBarPivot`), pedidos aleatorios de completos y validación en `receive_item()`.
- **Cocina Interactiva 3D (`IngredientStation.gd` + `KitchenStations.tscn`):**
  - Ensamblado físico sin menús 2D. Estaciones: Pan, Vienesa, Palta, Mayo, Kétchup y Basurero.
  - Regla base obligatoria: Pan + Vienesa. El ítem (`CompletoItem.gd`) actualiza su geometría 3D reactiva según los agregados.
- **Sistema de Eventos de NPCs (`NPCEvent.gd` + `NPCEventManager.gd`):**
  - Eventos aleatorios: `BigHeadEvent.gd`, `fastNPC.gd`.
  - Eventos estáticos: `StaticNPCEvent.gd`, `RobberEvent.gd` con escena dedicada `RobberNPC.tscn` (minijuego de atraco con pistola).
- **Sistema de Anomalías Modulares (`AnomaliesManager.gd`):**
  - Base desacoplada: `AnomalyBase.gd` (soporte 2D/3D).
  - Configuración y disparadores: `AnomalyData.gd` (`.tres`).
  - Ejemplo activo: `GlitchSpriteAnomaly` al 3.er cliente. Ver detalle en [`docs/anomalies_workflow.md`](../docs/anomalies_workflow.md).
- **Interfaz (`UI.gd` + `UI.tscn`):**
  - Crosshair, prompts interactivos, panel debug F3, fin de jornada (`DayEndPanel`), victoria (`VictoryPanel`), game over y menú pausa (`PauseMenu.tscn`).

## 4. Flujo de Ejecución (Game Loop)

1. **Arranque:** `MainMenu.tscn` -> Botón Jugar -> `GameManager.reset_game()` -> Carga `Main.tscn`.
2. **Ciclo de Jornada:**
   - `NPCSpawner` genera clientes según cupo diario (`max_clients_per_day`).
   - `NPCEventManager` evalúa si el cliente tiene un evento asignado (estático o aleatorio).
   - El cliente avanza al mostrador (`WindowPoint`), pide un completo e inicia su temporizador de paciencia.
   - El jugador prepara el pedido en `KitchenStations.tscn` y se lo entrega.
   - `GameManager` registra acierto o fallo y emite señales hacia la UI.
3. **Cierre de Jornada y Victoria:**
   - Al completar los clientes del día y retirarse el último NPC, se activa `DayEndPanel`.
   - Días 1 y 2: Botón para iniciar la siguiente jornada (`start_next_day()`).
   - Día 3 (Final): Al sobrevivir el tercer día, `GameManager` emite `game_won`, detiene spawners/eventos y despliega `VictoryPanel` con estadísticas finales y opciones de reinicio o volver al menú.
4. **Mecánicas de Riesgo y Game Over:**
   - **Persiana:** El mostrador cuenta con persiana operable. Cerrarla a tiempo evade la ira y disparo del Ladrón.
   - **Game Over:** Disparo del ladrón o condiciones críticas detienen la partida y muestran el panel de Game Over.
