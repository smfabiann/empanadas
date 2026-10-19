# Guía de Desarrollo y Convenciones

Guía rápida para agentes y desarrolladores. Reglas clave para mantener la consistencia y no romper contratos del juego.

---

## 1. Estructura de Rutas del Proyecto

Usar siempre rutas relativas estándar de Godot (`res://...`):

- **Escenas (`res://scenes/`):**
  - Gameplay principal: `res://scenes/Main.tscn`
  - Mapa y entorno: `res://scenes/map/` (`shop.tscn`, `KitchenStations.tscn`, `Neighborhood.tscn`, `ShopDecor.tscn`, etc.)
  - Jugador y NPCs: `res://scenes/Player.tscn`, `res://scenes/NPC.tscn`, `res://scenes/RobberNPC.tscn`
  - Ítems: `res://scenes/items/` (`Completo.tscn`, `Drink.tscn`, `Empanada.tscn`, `Sopaipilla.tscn`)
  - Anomalías: `res://scenes/anomalies/` (`AnomalyBase.tscn`, `GlitchSpriteAnomaly.tscn`, `Aware.tscn`, `CCTVLurker.tscn`, `CCTVIntruder.tscn`, `CCTVPowerFailure.tscn`)
  - UI: `res://scenes/ui/` (`MainMenu.tscn`, `PauseMenu.tscn`, `FloatingText.tscn`)
- **Scripts (`res://scripts/`):**
  - Autoloads: `GameManager.gd`, `SFXManager.gd`
  - Lógica base: `Player.gd`, `NPC.gd`, `NPCSpawner.gd`, `IngredientStation.gd`, `Interactable.gd`
  - Eventos: `scripts/events/` y `scripts/events/static/` (`ufo/`, `talca/`, `estafador/`, `rappi/`)
  - Mapa: `scripts/map/` (`CityBlock.gd`, `NeonSign.gd`, `EscapeProgressProp.gd`, baño químico, ampolletas)
  - Anomalías: `scripts/anomalies/` (eventos de CCTV en `scripts/anomalies/cctv/`)
  - Cámaras de seguridad: `scripts/cctv/` (`CCTVCamera.gd`, `CCTVZone.gd`) y `SecurityMonitor.gd`
  - UI: `scripts/ui/`
- **Recursos (`res://resources/`):**
  - Ítems: `resources/items/*.tres`
  - Anomalías: `resources/anomalies/*.tres`

---

## 2. Reglas de Oro (Para Evitar Regresiones)

1. **Respetar nombres y tipos de nodos clave:**
   - En `Main.tscn`: `SpawnPoint`, `WindowPoint`, `ExitPoint`, `Player`, `NPCSpawner`, `NPCEventManager`, `AnomaliesManagement`, `CCTVZones`.
   - En `NPC.tscn` / `RobberNPC.tscn`: `Label3D`, `PatienceBarPivot`, `CollisionShape3D`, `Gun`.
   - En `Player.tscn`: `Camera3D`, `RayCast3D`, `HandPosition`.
   *Renombrar estos nodos rompe `NodePath` exportados y llamadas `get_node_or_null()`.*
2. **Usar los grupos de nodos estándar:**
   - Jugador: grupo `"player"`.
   - Clientes: grupo `"npcs"`.
3. **Sincronización mediante `GameManager`:**
   - La UI y el Spawner reaccionan a señales de `GameManager` (`day_started`, `day_ended`, `game_won`, `game_over`, `stats_updated`). No acoplar la UI directamente a los NPCs.
4. **Capa de render 11 (`CCTV`) reservada:**
   - Solo la ven las cámaras de seguridad (`CCTVCamera.gd`). No usarla para objetos que el jugador deba ver.
5. **Verificar control del jugador:**
   - Respetar `GameManager.can_player_act()` en `Player.gd` antes de procesar movimiento o interacción (es `false` durante la intro, el sueño, la victoria y el game over).
6. **La plata pasa siempre por `GameManager`:**
   - Usar `earn_money()` / `lose_money()` con un motivo corto; nunca modificar `savings` directamente fuera de tests. La UI, la alcancía y el calendario escuchan `money_changed` y `day_started`.

---

## 3. Cómo Extender Sistemas

### A. Crear un nuevo Evento de NPC
1. Heredar de `NPCEvent` (aleatorio) o `StaticNPCEvent` (narrativo/condicional).
2. Implementar ganchos necesarios: `apply(npc)`, `on_arrive(npc)`, `on_leave(npc)` y, si el evento cambia la entrega o la salida, `on_item_received(npc, item)`, `on_persiana_closed(npc)` u `on_timeout(npc)` (retornan `true` si manejaron el caso). Para pedidos y cierres usar `npc.set_completo_order(...)` y `npc.finish_visit(...)`; el estado por visita va en `npc.set_meta(...)` porque el evento es un `Resource` compartido.
3. Registrar en `_register_default_events()` de `res://scripts/events/NPCEventManager.gd`.
4. Guía detallada en [`scripts/events/README.md`](../scripts/events/README.md).

### B. Crear una nueva Anomalía Modular
1. Crear una escena heredando de `res://scenes/anomalies/AnomalyBase.tscn` y extender `AnomalyBase.gd`.
2. Crear un recurso `AnomalyData` (`.tres`) para definir condiciones de disparo (días, clientes atendidos, etc.).
3. Registrar en el nodo `AnomaliesManagement` de `Main.tscn`.
4. Guía técnica detallada en [`docs/anomalies_workflow.md`](../docs/anomalies_workflow.md).

### C. Crear un nuevo Evento de CCTV (visible solo por el monitor)
1. Escena heredada de `AnomalyBase.tscn` (`auto_execute_on_ready = false`) con un script que extienda `CCTVEventAnomaly`.
2. Construir los visuales en `_build_visuals()` y animarlos en `_update_event()`; la base los coloca en una `CCTVZone` y los pasa a la capa 11.
3. Crear su `AnomalyData` (`.tres`) y registrarlo en `AnomaliesManagement`.
4. Para una cámara nueva: `Camera3D` con `CCTVCamera.gd` (canal único) y marcadores `CCTVZone.gd` en `Main/CCTVZones` dentro de su encuadre.
5. Guía detallada en [`scripts/anomalies/README.md`](../scripts/anomalies/README.md#eventos-de-cctv-hu-10). Validar con `tests/test_cctv_events.tscn`.

### D. Agregar una nueva Estación de Cocina
1. Agregar un `StaticBody3D` con `IngredientStation.gd` dentro de `KitchenStations.tscn` (ver `Station_Olla` como ejemplo con mueble propio).
2. Asignar el tipo exportado (`station_type`) y manejar su prompt e interacción en `IngredientStation.gd`; si cambia el completo, agregar el estado en `CompletoItem.gd` y, si los clientes lo pueden pedir, un parámetro opcional en `matches_order()` / `get_match_error()` para no romper llamadas existentes.

### E. Ajustar la meta del escape o el barrio
1. Meta y ahorros iniciales: `starting_savings` y `escape_goal` en el Inspector del nodo raíz de `Main.tscn`; precios en las constantes de `GameManager.gd`.
2. Barrio: cada cuadra de `Neighborhood.tscn` es un `CityBlock` (`@tool`): cambiar `seed_value`, `block_length`, pisos o `sign_lights` y se regenera en el editor. Mantener libres la línea de los clientes (x ≈ -0.43, z de -11 a -4.5) y el encuadre de las cámaras de CCTV.

---

## 4. Checklist Rápido de Validación

Antes de finalizar cualquier tarea técnica:
- [ ] No usar rutas absolutas de disco (`file:///...` o `/home/...`), usar `res://`.
- [ ] La escena principal `Main.tscn` carga sin errores de dependencias rotas.
- [ ] El flujo de interacción del jugador ([E], recoger, cocinar, entregar) funciona.
- [ ] Las señales entre `GameManager`, `NPCSpawner` y `UI` se mantienen intactas.
- [ ] Las suites de `tests/` pasan en headless: `godot --headless res://tests/<suite>.tscn` (código de salida 0).
