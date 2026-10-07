# Guía de Desarrollo y Convenciones

Guía rápida para agentes y desarrolladores. Reglas clave para mantener la consistencia y no romper contratos del juego.

---

## 1. Estructura de Rutas del Proyecto

Usar siempre rutas relativas estándar de Godot (`res://...`):

- **Escenas (`res://scenes/`):**
  - Gameplay principal: `res://scenes/Main.tscn`
  - Mapa y entorno: `res://scenes/map/` (`shop.tscn`, `KitchenStations.tscn`, etc.)
  - Jugador y NPCs: `res://scenes/Player.tscn`, `res://scenes/NPC.tscn`, `res://scenes/RobberNPC.tscn`
  - Ítems: `res://scenes/items/` (`Completo.tscn`, `Drink.tscn`, `Empanada.tscn`, `Sopaipilla.tscn`)
  - Anomalías: `res://scenes/anomalies/` (`AnomalyBase.tscn`, `GlitchSpriteAnomaly.tscn`)
  - UI: `res://scenes/ui/` (`MainMenu.tscn`, `PauseMenu.tscn`, `FloatingText.tscn`)
- **Scripts (`res://scripts/`):**
  - Autoloads: `GameManager.gd`, `SFXManager.gd`
  - Lógica base: `Player.gd`, `NPC.gd`, `NPCSpawner.gd`, `IngredientStation.gd`, `Interactable.gd`
  - Eventos: `scripts/events/` y `scripts/events/static/`
  - Anomalías: `scripts/anomalies/`
  - UI: `scripts/ui/`
- **Recursos (`res://resources/`):**
  - Ítems: `resources/items/*.tres`
  - Anomalías: `resources/anomalies/*.tres`

---

## 2. Reglas de Oro (Para Evitar Regresiones)

1. **Respetar nombres y tipos de nodos clave:**
   - En `Main.tscn`: `SpawnPoint`, `WindowPoint`, `ExitPoint`, `Player`, `NPCSpawner`, `NPCEventManager`, `AnomaliesManagement`.
   - En `NPC.tscn` / `RobberNPC.tscn`: `Label3D`, `PatienceBarPivot`, `CollisionShape3D`, `Gun`.
   - En `Player.tscn`: `Camera3D`, `RayCast3D`, `HandPosition`.
   *Renombrar estos nodos rompe `NodePath` exportados y llamadas `get_node_or_null()`.*
2. **Usar los grupos de nodos estándar:**
   - Jugador: grupo `"player"`.
   - Clientes: grupo `"npcs"`.
3. **Sincronización mediante `GameManager`:**
   - La UI y el Spawner reaccionan a señales de `GameManager` (`day_started`, `day_ended`, `game_won`, `game_over`, `stats_updated`). No acoplar la UI directamente a los NPCs.
4. **Verificar control del jugador:**
   - Respetar `GameManager.can_player_act()` en `Player.gd` antes de procesar movimiento o interacción.

---

## 3. Cómo Extender Sistemas

### A. Crear un nuevo Evento de NPC
1. Heredar de `NPCEvent` (aleatorio) o `StaticNPCEvent` (narrativo/condicional).
2. Implementar ganchos necesarios: `apply(npc)`, `on_arrive(npc)`, `on_leave(npc)`.
3. Registrar en `_register_default_events()` de `res://scripts/events/NPCEventManager.gd`.
4. Guía detallada en [`scripts/events/README.md`](../scripts/events/README.md).

### B. Crear una nueva Anomalía Modular
1. Crear una escena heredando de `res://scenes/anomalies/AnomalyBase.tscn` y extender `AnomalyBase.gd`.
2. Crear un recurso `AnomalyData` (`.tres`) para definir condiciones de disparo (días, clientes atendidos, etc.).
3. Registrar en el nodo `AnomaliesManagement` de `Main.tscn`.
4. Guía técnica detallada en [`docs/anomalies_workflow.md`](../docs/anomalies_workflow.md).

### C. Agregar una nueva Estación de Cocina
1. Instanciar `IngredientStation.tscn` dentro de `KitchenStations.tscn`.
2. Asignar el tipo de ingrediente exportado (`station_type`) y manejar su lógica en `IngredientStation.gd` y `CompletoItem.gd`.

---

## 4. Checklist Rápido de Validación

Antes de finalizar cualquier tarea técnica:
- [ ] No usar rutas absolutas de disco (`file:///...` o `/home/...`), usar `res://`.
- [ ] La escena principal `Main.tscn` carga sin errores de dependencias rotas.
- [ ] El flujo de interacción del jugador ([E], recoger, cocinar, entregar) funciona.
- [ ] Las señales entre `GameManager`, `NPCSpawner` y `UI` se mantienen intactas.
