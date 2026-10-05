# Arquitectura actual del juego

## 1) Configuración base

- Proyecto: `/home/runner/work/empanadas/empanadas/project.godot`
- Escena inicial: `res://scenes/ui/MainMenu.tscn`
- Autoloads:
  - `GameManager = res://scripts/GameManager.gd`
  - `SFXManager = res://scripts/SFXManager.gd`
- Capas físicas 3D:
  - Layer 1: `World`
  - Layer 2: `Interactable`
  - Layer 3: `NPC`

## 2) Módulos principales

- **Gameplay world** (`/scenes/Main.tscn`): instancia mapa, jugador, HUD, spawner y gestor de eventos.
- **Jugador** (`/scripts/Player.gd` + `/scenes/Player.tscn`): movimiento FPS, RayCast3D, recoger/soltar/entregar ítems.
- **NPC base** (`/scripts/NPC.gd` + `/scenes/NPC.tscn`): estados `APPROACHING/WAITING/LEAVING`, pedidos de completos, paciencia.
- **Cocina 3D** (`/scripts/IngredientStation.gd` + `/scenes/map/KitchenStations.tscn`): estaciones de pan, vienesa, palta, mayo, ketchup y basurero.
- **Ítems**:
  - Base recogible: `/scripts/Interactable.gd`
  - Completo modular: `/scripts/CompletoItem.gd` + `/scenes/items/Completo.tscn`
  - Recursos de datos: `/resources/items/*.tres`
- **Eventos/anomalías**:
  - Base evento: `/scripts/events/NPCEvent.gd`
  - Selección/registro: `/scripts/events/NPCEventManager.gd`
  - Aleatorios: `BigHeadEvent.gd`, `fastNPC.gd`
  - Estático: `RobberEvent.gd` + NPC dedicado `/scripts/events/static/RobberNPC.gd`
- **UI** (`/scripts/ui/UI.gd` + `/scenes/UI.tscn`): crosshair, prompt, debug, panel de jornada, game over y menú pausa.

## 3) Relaciones entre sistemas

- `MainMenu.gd` inicia partida (`change_scene_to_file("res://scenes/Main.tscn")`) y resetea estado global.
- `NPCSpawner.gd` depende de `GameManager` (cupos, jornada, timing) y de `NPCEventManager` (evento a aplicar).
- Cada NPC reporta resultado a `GameManager` (`register_npc_served` / `register_npc_left`).
- `UI.gd` escucha señales de `GameManager` para refrescar contador, jornada y game over.
- `Player.gd` usa `RayCast3D` para interactuar con `Interactable`, estaciones y NPCs.
- `shop.tscn` contiene scripts embebidos para persiana/puerta/botón; cierre de persiana notifica NPCs del grupo `npcs`.

## 4) Nodo raíz de ejecución (escena de juego)

`/home/runner/work/empanadas/empanadas/scenes/Main.tscn`:

- `Main (Node3D)`
  - `Enviroment/WorldEnvironment`
  - `Map` (instancia `shop.tscn`, `shelf.tscn`, `KitchenStations.tscn`, luces, suelo)
  - `SpawnPoint`, `WindowPoint`, `ExitPoint` (Marker3D)
  - `Player` (instancia `Player.tscn`)
  - `UI` (instancia `UI.tscn`)
  - `NPCSpawner` (con `Timer` hijo)
  - `NPCEventManager`

## 5) Referencias cruzadas clave

- `Main.tscn` enlaza `NPCSpawner.event_manager -> ../NPCEventManager`.
- `NPCSpawner` asigna `spawn_point/window_point/exit_point` desde marcadores en `Main`.
- `RobberEvent` define `custom_npc_scene = res://scenes/RobberNPC.tscn`.
- `UI.tscn` instancia `PauseMenu.tscn` como hijo (`PauseMenu`).

Ver también:
- [Inventario técnico](./INVENTARIO.md)
- [Flujo de ejecución](./FLUJO_DE_EJECUCION.md)
