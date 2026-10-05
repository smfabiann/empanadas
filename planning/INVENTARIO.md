# Inventario técnico del proyecto

## Escenas (.tscn)

| Ruta | Propósito | Script principal enlazado |
|---|---|---|
| `/home/runner/work/empanadas/empanadas/scenes/ui/MainMenu.tscn` | Menú inicial | `/home/runner/work/empanadas/empanadas/scripts/ui/MainMenu.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/Main.tscn` | Escena principal de juego | `/home/runner/work/empanadas/empanadas/scripts/NPCSpawner.gd` (nodo `NPCSpawner`), `/scripts/events/NPCEventManager.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/Player.tscn` | Jugador FPS | `/home/runner/work/empanadas/empanadas/scripts/Player.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/NPC.tscn` | NPC base | `/home/runner/work/empanadas/empanadas/scripts/NPC.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/RobberNPC.tscn` | NPC ladrón | `/home/runner/work/empanadas/empanadas/scripts/events/static/RobberNPC.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/UI.tscn` | HUD + paneles | `/home/runner/work/empanadas/empanadas/scripts/ui/UI.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/map/shop.tscn` | Geometría local + persiana + puerta | Scripts embebidos en subrecursos (`GDScript_*`) |
| `/home/runner/work/empanadas/empanadas/scenes/map/shelf.tscn` | Repisa 3D | Sin script |
| `/home/runner/work/empanadas/empanadas/scenes/map/KitchenStations.tscn` | Estaciones de cocina | `/home/runner/work/empanadas/empanadas/scripts/IngredientStation.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/map/IngredientStation.tscn` | Prefab de estación individual | `/home/runner/work/empanadas/empanadas/scripts/IngredientStation.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/items/Completo.tscn` | Completo interactivo modular | `/home/runner/work/empanadas/empanadas/scripts/CompletoItem.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/items/Drink.tscn` | Bebida interactuable | `/home/runner/work/empanadas/empanadas/scripts/Interactable.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/items/Empanada.tscn` | Empanada interactuable | `/home/runner/work/empanadas/empanadas/scripts/Interactable.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/items/Sopaipilla.tscn` | Sopaipilla interactuable | `/home/runner/work/empanadas/empanadas/scripts/Interactable.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/items/Gun.tscn` | Modelo de arma del ladrón | Sin script |
| `/home/runner/work/empanadas/empanadas/scenes/ui/PauseMenu.tscn` | Menú de pausa | `/home/runner/work/empanadas/empanadas/scripts/ui/PauseMenu.gd` |
| `/home/runner/work/empanadas/empanadas/scenes/ui/FloatingText.tscn` | Texto flotante | `/home/runner/work/empanadas/empanadas/scripts/ui/FloatingText.gd` |

## Scripts (.gd)

### Núcleo

- `/home/runner/work/empanadas/empanadas/scripts/GameManager.gd` (autoload): estado global, contadores, señales, jornadas, game over.
- `/home/runner/work/empanadas/empanadas/scripts/SFXManager.gd` (autoload): tonos procedurales SFX.
- `/home/runner/work/empanadas/empanadas/scripts/Player.gd`: movimiento, cámara, interacción, entrega.
- `/home/runner/work/empanadas/empanadas/scripts/NPC.gd`: IA base cliente + receta completo + paciencia.
- `/home/runner/work/empanadas/empanadas/scripts/NPCSpawner.gd`: spawn de NPC único, ciclo por día.

### Ítems y cocina

- `/home/runner/work/empanadas/empanadas/scripts/ItemData.gd`
- `/home/runner/work/empanadas/empanadas/scripts/Interactable.gd`
- `/home/runner/work/empanadas/empanadas/scripts/CompletoItem.gd`
- `/home/runner/work/empanadas/empanadas/scripts/IngredientStation.gd`
- `/home/runner/work/empanadas/empanadas/scripts/ItemSpawner.gd` (presente en repo, no referenciado en `Main.tscn`)

### Eventos/anomalías

- `/home/runner/work/empanadas/empanadas/scripts/events/NPCEvent.gd`
- `/home/runner/work/empanadas/empanadas/scripts/events/NPCEventManager.gd`
- `/home/runner/work/empanadas/empanadas/scripts/events/BigHeadEvent.gd`
- `/home/runner/work/empanadas/empanadas/scripts/events/fastNPC.gd`
- `/home/runner/work/empanadas/empanadas/scripts/events/static/StaticNPCEvent.gd`
- `/home/runner/work/empanadas/empanadas/scripts/events/static/RobberEvent.gd`
- `/home/runner/work/empanadas/empanadas/scripts/events/static/RobberNPC.gd`

### UI

- `/home/runner/work/empanadas/empanadas/scripts/ui/UI.gd`
- `/home/runner/work/empanadas/empanadas/scripts/ui/MainMenu.gd`
- `/home/runner/work/empanadas/empanadas/scripts/ui/PauseMenu.gd`
- `/home/runner/work/empanadas/empanadas/scripts/ui/FloatingText.gd`

## Recursos/configuración

- Configuración Godot: `/home/runner/work/empanadas/empanadas/project.godot`
- ItemData:
  - `/home/runner/work/empanadas/empanadas/resources/items/completo.tres`
  - `/home/runner/work/empanadas/empanadas/resources/items/bebida.tres`
  - `/home/runner/work/empanadas/empanadas/resources/items/empanada.tres`
  - `/home/runner/work/empanadas/empanadas/resources/items/sopaipilla.tres`
