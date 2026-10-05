# Flujo de ejecución y de juego

## 1. Arranque

1. Godot carga `/home/runner/work/empanadas/empanadas/project.godot`.
2. Se inicializan autoloads:
   - `GameManager` (`/scripts/GameManager.gd`)
   - `SFXManager` (`/scripts/SFXManager.gd`)
3. Se abre escena principal de app: `res://scenes/ui/MainMenu.tscn`.

## 2. Inicio de partida

1. En `/scripts/ui/MainMenu.gd`, botón **JUGAR** ejecuta:
   - `GameManager.reset_game()`
   - `change_scene_to_file("res://scenes/Main.tscn")`
2. Se instancia `Main.tscn` con:
   - mundo (`shop`, `shelf`, `KitchenStations`),
   - `Player`, `UI`, `NPCSpawner`, `NPCEventManager`.

## 3. Ciclo principal por jornada

1. `NPCSpawner` espera `first_client_delay` y llama `_spawn_npc()`.
2. `NPCEventManager.pick_event_for_npc(...)` decide si hay evento:
   - debug forzado,
   - estático (ej. ladrón),
   - o aleatorio ponderado.
3. Se instancia NPC normal (`NPC.tscn`) o personalizado (`RobberNPC.tscn`).
4. NPC camina a `WindowPoint`, solicita pedido y comienza la paciencia.
5. Jugador:
   - toma pan en estación `bread`,
   - agrega ingredientes en estaciones,
   - entrega el completo al NPC.
6. `NPC.receive_item()` valida base (pan+vienesa) y receta.
7. `GameManager` registra resultado y emite señales.
8. `UI.gd` actualiza contadores y estado visible.

## 4. Cierre de jornada

1. `GameManager` cuenta clientes atendidos/perdidos del día.
2. Al cumplir cupo (`max_clients_per_day`) y salir el último NPC:
   - `NPCSpawner` llama `GameManager.end_day()`.
3. `UI.gd` muestra `DayEndPanel` con resumen.
4. Botón siguiente día:
   - si no es día final: `GameManager.start_next_day()`;
   - si es final: restaura estado y recarga escena.

## 5. Interacciones especiales

- **Persiana del mostrador** (`shop.tscn` script embebido): al cerrar, recorre grupo `npcs` y llama `on_persiana_closed()`/`_timeout()` según soporte del NPC.
- **Ladrón** (`RobberNPC.gd`): secuencia de completos; si falla o expira tiempo, activa secuencia de ira, posible disparo y `GameManager.trigger_game_over(...)`.
- **Pausa** (`PauseMenu.gd`): `ESC` alterna `get_tree().paused`.

## 6. Game Over y reinicio

1. `GameManager.game_over` notifica a `UI.gd`.
2. UI muestra panel de game over.
3. Desde UI se puede:
   - reintentar (`reload_current_scene` + `reset_game`),
   - volver a menú (`change_scene_to_file(MainMenu)` + `reset_game`).
