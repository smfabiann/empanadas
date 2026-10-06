# Estado actual, limitaciones, TODOs y riesgos

## Hechos verificados (basados en repositorio)

1. El sistema de eventos está activo y registra por defecto:
   - `BigHeadEvent`, `FastNPCEvent`, `RobberEvent` (`/scripts/events/NPCEventManager.gd`).
2. El ladrón usa escena personalizada (`/scenes/RobberNPC.tscn`) vía `custom_npc_scene` (`/scripts/events/static/RobberEvent.gd`).
3. Hay backlog explícito en documentación existente:
   - `/planning/TASKS.md` (`TASK-005`, `TASK-006`, `TASK-008`).
4. El roadmap marca trabajo “En Curso” en anomalías (`/planning/ROADMAP.md`).
5. Existe `ItemSpawner.gd` en código, pero `Main.tscn` no instancia nodo con ese script.
6. Condición de victoria implementada (HU-06): al sobrevivir los 3 días canónicos, se detiene el flujo de eventos y se muestra la pantalla de victoria con narrativa de escape y botones de reinicio / menú principal.
7. Arquitectura base y gestor de anomalías modulares implementado (HU-ANOM-13): `AnomaliesManager` (`AnomaliesManagement` en `Main.tscn`), plantilla base `AnomalyBase` (2D/3D), recurso `AnomalyData` con disparadores fijos, de umbral y de progresión, y ejemplo funcional `GlitchSpriteAnomaly` configurado al 3.er cliente.

## Limitaciones técnicas observadas

- `RobberEvent.gd` mantiene hooks `apply` y `on_leave` vacíos (`pass`), por lo que su efecto principal es de disparador/escena.
- `scripts/events/README.md` contiene enlaces `file:///c:/...` (rutas locales Windows no portables en otros entornos).
- Variables exportadas de secuencia en `RobberNPC.gd` (`item_sequence`, `randomize_sequence`, `random_sequence_count`) no gobiernan actualmente la secuencia efectiva, que se define en `robber_recipes`.

## Inferencias (separadas de hechos)

- **Inferencia**: `ItemSpawner.gd` podría ser código legado o reservado para una variante de flujo de ítems, porque el flujo actual de cocina/entrega funciona sin su instancia en `Main.tscn`.
- **Inferencia**: la coexistencia de documentación histórica extensa (ROADMAP/TASKS/changelog) con arquitectura viva puede desalinearse con el tiempo si no se actualiza en cada cambio estructural.

## Riesgos de mantenimiento

1. Renombrar nodos clave en escenas (ej. `Label3D`, `PatienceBarPivot`, `Gun`, `SpawnPoint`) puede romper scripts con `get_node_or_null` o NodePath exportado.
2. Cambiar señales de `GameManager` sin sincronizar `UI.gd`/`NPCSpawner.gd` rompe el flujo de día y paneles.
3. Mover scripts/escenas sin actualizar rutas `res://` rompe cargas de `PackedScene`/`preload`.
