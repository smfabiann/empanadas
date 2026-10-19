# Arquitectura del Proyecto

## 1. Configuración Base

- **Motor:** Godot 4 (3D)
- **Escena inicial:** `res://scenes/ui/MainMenu.tscn`
- **Escena principal de juego:** `res://scenes/Main.tscn`
- **Autoloads (Singletons):**
  - `GameManager` (`res://scripts/GameManager.gd`): Estado global de partida, jornadas (3 noches canónicas), clientes atendidos/perdidos, economía del escape (ahorros, meta del pasaje, pagos), intro narrativa, pistas, señales de UI y game over/victoria.
  - `SFXManager` (`res://scripts/SFXManager.gd`): Generación procedural de efectos de sonido y del ambiente nocturno en loop.
  - `DayCycle` (`res://scripts/DayCycle.gd`): Transición noche -> amanecer -> noche al dormir.
- **Capas de colisión 3D:**
  - Layer 1: `World` (entorno, muros, suelo)
  - Layer 2: `Interactable` (ítems recogibles, estaciones de cocina)
  - Layer 3: `NPC` (clientes, ladrón)
- **Capas de render 3D:**
  - Layer 11: `CCTV` (eventos de cámara; solo la ven las cámaras de seguridad, nunca la cámara del jugador)

## 2. Jerarquía de la Escena de Juego (`Main.tscn`)

- `Main (Node3D)`
  - `Environment/WorldEnvironment`: Iluminación y niebla nocturna.
  - `Map`: Entorno del local (`shop.tscn`, `KitchenStations.tscn` con la olla, luces), barrio (`Neighborhood.tscn`: cuadras `CityBlock`, letrero de neón, paradero, auto, árboles, postes) y utilería narrativa (`ShopDecor.tscn`: alcancía y calendario).
  - Marcadores de navegación: `SpawnPoint`, `WindowPoint`, `ExitPoint` (Marker3D).
  - `Player`: Controlador en primera persona (`Player.tscn`).
  - `UI`: CanvasLayer HUD, paneles y menús (`UI.tscn`).
  - `NPCSpawner`: Generador y temporizador de clientes con integración a eventos.
  - `NPCEventManager`: Gestor y catálogo de eventos de NPCs.
  - `AnomaliesManagement`: Gestor central de anomalías modulares (`AnomaliesManager.gd`).
  - `CCTVZones`: Marcadores (`CCTVZone.gd`) donde aparecen los eventos de CCTV.

## 3. Módulos Principales

- **Jugador (`Player.gd` + `Player.tscn`):**
  - Movimiento FPS, sprint, salto, cámara y `RayCast3D`.
  - Recoger, portar, ensamblar y entregar ítems (`Interactable`).
  - Bloqueo de interacción si `not GameManager.can_player_act()`.
- **Clientes (`NPC.gd` + `NPC.tscn`):**
  - Máquina de estados: `APPROACHING` -> `WAITING` -> `REACTING` -> `LEAVING`.
  - Paciencia con barra visible (`PatienceBarPivot`), pedidos aleatorios de completos y validación en `receive_item()`.
- **Cocina Interactiva 3D (`IngredientStation.gd` + `KitchenStations.tscn`):**
  - Ensamblado físico sin menús 2D. Estaciones: Pan, Vienesa, Palta, Mayo, Kétchup, Olla (moja el pan: completo mojado estilo Talca) y Basurero.
  - Regla base obligatoria: Pan + Vienesa. El ítem (`CompletoItem.gd`) actualiza su geometría 3D reactiva según los agregados.
- **Sistema de Eventos de NPCs (`NPCEvent.gd` + `NPCEventManager.gd`):**
  - Eventos aleatorios: `BigHeadEvent.gd`, `fastNPC.gd`.
  - Eventos estáticos: `StaticNPCEvent.gd`, `RobberEvent.gd` con escena dedicada `RobberNPC.tscn` (minijuego de atraco con pistola), `UfoEvent.gd`, `TalquinoEvent.gd` (completo mojado), `ScammerEvent.gd` (estafa del chip de perro) y `RappiEvent.gd` (pedido doble en moto). Los tres últimos usan la escena estándar de NPC y los ganchos `on_item_received`, `on_persiana_closed` y `on_timeout`.
- **Sistema de Anomalías Modulares (`AnomaliesManager.gd`):**
  - Base desacoplada: `AnomalyBase.gd` (soporte 2D/3D).
  - Configuración y disparadores: `AnomalyData.gd` (`.tres`).
  - Ejemplo activo: `GlitchSpriteAnomaly` al 3.er cliente. Ver detalle en [`docs/anomalies_workflow.md`](../docs/anomalies_workflow.md).
- **Cámaras de Seguridad y Eventos de CCTV (HU-09 / HU-10):**
  - `SecurityMonitor.gd`: vista a pantalla completa con canales (`[A]/[D]`), HUD de grabación y filtro CCTV.
  - Canales `CCTVCamera.gd`: CAM 01 `frente` (`Map/Shop/Camara`) y CAM 02 `patio` (`Map/Shop/Camara2`).
  - Eventos `CCTVEventAnomaly` (silueta acechando, intruso, fallo eléctrico) que aparecen en zonas `Main/CCTVZones` y solo se renderizan en la capa 11 (`CCTV`), invisible para el jugador. Ver [`scripts/anomalies/README.md`](../scripts/anomalies/README.md).
- **Narrativa y economía del escape (`GameManager.gd`):**
  - Meta: juntar `escape_goal` ($50.000) partiendo con `starting_savings` ($20.000) en 3 noches (configurables en `Main.tscn`).
  - `earn_money()` / `lose_money()` emiten `money_changed`; `calculate_completo_payment()` = $3.000 + propina por rapidez (hasta $1.000) + $500 si es mojado.
  - `trigger_victory()` solo gana si `has_escape_money()`; si no, `trigger_game_over("No juntaste la plata del pasaje...")`.
  - Pérdidas: el ladrón se lleva $5.000 si se le entrega todo; el estafador $5.000 si se le paga o se le ignora.
- **Interfaz (`UI.gd` + `UI.tscn`):**
  - Crosshair, prompts interactivos, panel debug F3, HUD de noche y ahorros (`DayPanel`: `SavingsLabel`, `SavingsBar`), aviso de plata (`MoneyPopup`), pistas (`HintPanel`), intro narrativa con "Cómo jugar" (`IntroPanel`), fin de jornada, victoria (`VictoryPanel`), game over y menú pausa (`PauseMenu.tscn`).

## 4. Flujo de Ejecución (Game Loop)

1. **Arranque:** `MainMenu.tscn` -> Botón Jugar -> `GameManager.reset_game()` + `show_intro = true` -> Carga `Main.tscn` -> `IntroPanel` (historia y cómo jugar; bloquea jugador y clientes) -> "Abrir el local" -> `GameManager.finish_intro()` -> `NPCSpawner` parte la Noche 1.
2. **Ciclo de Jornada:**
   - `NPCSpawner` genera clientes según cupo diario (`max_clients_per_day`).
   - `NPCEventManager` evalúa si el cliente tiene un evento asignado (estático o aleatorio).
   - El cliente avanza al mostrador (`WindowPoint`), pide un completo e inicia su temporizador de paciencia.
   - El jugador prepara el pedido en `KitchenStations.tscn` y se lo entrega.
   - `GameManager` registra acierto o fallo, suma el pago a los ahorros (`money_changed`) y emite señales hacia la UI.
   - Eventos estáticos por noche: Noche 1 Ladrón; Noche 2 OVNI y Talquino; Noche 3 Estafador y Rappi.
3. **Cierre de Jornada y Victoria:**
   - Al completar los clientes del día y retirarse el último NPC, se activa `DayEndPanel`.
   - Días 1 y 2: Botón para iniciar la siguiente jornada (`start_next_day()`).
   - Noche 3 (Final): al dormir, si se juntó la plata del pasaje `GameManager` emite `game_won` y se muestra `VictoryPanel` (escape) con estadísticas y plata juntada; si no alcanzó, termina con game over "Te quedaste en la ciudad".
4. **Mecánicas de Riesgo y Game Over:**
   - **Persiana:** El mostrador cuenta con persiana operable. Cerrarla a tiempo evade la ira y disparo del Ladrón.
   - **Persiana contra estafas:** bajar la persiana echa al Estafador del chip de perro sin perder plata.
   - **Game Over:** Disparo del ladrón o no juntar la plata del pasaje al final de la última noche detienen la partida y muestran el panel de Game Over.
