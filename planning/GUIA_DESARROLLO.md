# Convenciones y guía para continuar el desarrollo

## Rutas recomendadas para agregar contenido

- **Escenas de gameplay**: `/home/runner/work/empanadas/empanadas/scenes/`
  - NPCs o variantes: `scenes/` o `scenes/items/` según tipo.
  - UI: `scenes/ui/`.
  - Mapa/interactivos físicos: `scenes/map/`.
- **Scripts**: `/home/runner/work/empanadas/empanadas/scripts/`
  - UI: `scripts/ui/`
  - Eventos: `scripts/events/` y `scripts/events/static/`
- **Recursos de ítems**: `/home/runner/work/empanadas/empanadas/resources/items/`

## Cómo agregar sin romper referencias

1. Usar siempre rutas `res://...` válidas en escenas/scripts exportados.
2. Si un nodo es referenciado por nombre (ej. `SpawnPoint`, `WindowPoint`, `ExitPoint`, `Label3D`, `PatienceBarPivot`, `Gun`), **mantener nombre y tipo** o actualizar código asociado.
3. Si se crea un evento nuevo:
   - heredar de `NPCEvent` o `StaticNPCEvent`;
   - registrar en `_register_default_events()` de `/scripts/events/NPCEventManager.gd`.
4. Si se agrega un nuevo tipo de estación:
   - extender casos en `IngredientStation.gd` (`get_interaction_prompt`, `interact`, `add_ingredient` del ítem si aplica).
5. Si se modifica el flujo por días:
   - revisar contratos de señales de `GameManager` consumidas por `UI.gd` y `NPCSpawner.gd`.
6. Si se cambia escena inicial/autoload/input/capas:
   - hacerlo en `/project.godot` y validar que scripts dependientes siguen coherentes.

## Convenciones observadas en el repositorio

- Uso de `@export` para parámetros de balance/debug en Inspector.
- Uso de grupos (`player`, `npcs`) para comunicación por escena.
- Uso de señales de `GameManager` como canal de sincronización de UI/estado.
- Scripts de escena embebidos en `shop.tscn` para interacciones puntuales (puerta/persiana/botón).

## Checklist rápido antes de commitear cambios de gameplay

- [ ] Escena carga sin referencias rotas (`Missing NodePath`/`Missing Script`).
- [ ] Autoloads (`GameManager`, `SFXManager`) siguen accesibles.
- [ ] `Player` puede interactuar con ítems/estaciones/NPC.
- [ ] Flujo de día y game over no se rompe.
- [ ] Documentación de `planning/` actualizada si cambió estructura o flujo.
