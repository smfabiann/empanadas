# Arquitectura y Convenciones Tecnicas

## Vision General
Juego 3D retro (low-poly/PSX) en Godot 4.x de atencion de local con tematica de terror y anomalias.
Escena principal: res://scenes/Main.tscn

## Estructura de Archivos
- scenes/
  - Main.tscn: Escena del local (SpawnPoint, WindowPoint, ExitPoint, luces, mapa).
  - Player.tscn: Jugador en 1ra persona (Camera3D + RayCast3D).
  - NPC.tscn: Clientes con maquina de estados y barra de paciencia.
  - UI.tscn: HUD minimalista, prompts, menu de pausa y panel de depuracion.
  - items/: Escenas fisicas de items interactuables.
  - ui/PauseMenu.tscn, ui/MainMenu.tscn: Menus.
- scripts/
  - Player.gd: Movimiento, mirada con mouse, salto, sprint, raycast picking/entregas.
  - NPC.gd: Estados (APPROACHING, WAITING, LEAVING), paciencia, recepcion de item.
  - NPCSpawner.gd: Spawnea 1 NPC a la vez, asigna anomalias, intervalo via Timer.
  - NPCEventManager.gd: Gestion y sorteo de eventos/anomalias.
  - events/NPCEvent.gd: Clase base de eventos (apply, on_arrive, on_leave).
  - events/fastNPC.gd: Anomalia de cliente rapido con baja paciencia.
  - GameManager.gd: Autoload singleton de estado global y contadores.
  - SFXManager.gd: Autoload singleton de audio.
  - UI.gd: HUD, reticula, prompts, panel debug (F3).
  - ItemData.gd, Interactable.gd, ItemSpawner.gd: Logica de items.
- resources/items/: Recursos .tres (empanada, sopaipilla, completo, bebida).

## Bucle de Juego y Flujo
1. Player: Interactua con E (recoger/entregar) o Q (soltar). Detecta capas 2 (items) y 3 (NPCs) con RayCast.
2. Items: ItemData (id, display_name). Interactable maneja agarre y fisicas.
3. NPCs:
   - APPROACHING: camina a WindowPoint.
   - WAITING: pide item al azar, drena paciencia. receive_item() compara id y notifica a GameManager.
   - LEAVING: desactiva colision, camina a ExitPoint, fade tween y queue_free.
4. Spawner y Anomalias:
   - NPCSpawner instancia 1 NPC tras delay inicial (2s) o cada SPAWN_INTERVAL.
   - NPCEventManager asigna eventos fijos o ponderados segun npcs_spawned y npcs_served.
5. Autoload GameManager:
   - Variables: game_active, npcs_spawned, npcs_served, npcs_served_correctly, SPAWN_INTERVAL (6.0), PATIENCE_TIME (25.0).
   - Senales: npc_spawned(total), npc_served(total, is_correct), item_delivered(), npc_left().
6. UI y Debug:
   - HUD minimalista con reticula y prompt dinamico.
   - Panel de depuracion superior derecho: cuenta NPCs aparecidos y atendidos.
   - Toggle por Inspector (show_debug_counters) y en runtime con tecla F3.
7. Persiana de Mostrador:
   - Alternable mediante boton interactuable en el local.
   - Al cerrarse ejecuta on_persiana_closed() en NPCs presentes en mostrador (can_react_to_persiana()).
   - NPC base: ejecuta _timeout() y se marcha.
   - RobberNPC:
     - En espera normal: se enfurece por el cierre, enfunda arma, restaura ambiente y huye corriendo a velocidad aumentada.
     - En secuencia de ira (error de item o timeout): el jugador dispone de una ventana de 2.6s antes del disparo fatal para pulsar el boton; al cerrar la persiana se cancela el disparo, se evita la muerte ("clutch save"), el ladron reacciona al bloqueo de la persiana, enfunda y huye.

## Capas de Fisicas 3D
- Capa 1 (World): Geometria estatica, paredes, suelo, mostrador.
- Capa 2 (Interactable): Objetos recogibles (comida y bebida).
- Capa 3 (NPC): Clientes.

## Mapeo de Entradas
- interact: E (recoger / entregar).
- drop_item: Q (soltar item en mano).
- pause: Escape (pausar juego).
- sprint: Shift (correr).
- jump: Espacio (saltar).
- debug: F3 (alternar contadores en pantalla).

## Reglas de Desarrollo
- Contenedores UI: no animar position/size directamente en hijos de Containers en Godot (usar modulate o animar el contenedor raiz).
- Mouse filter: overlays de UI deben usar mouse_filter = 2 (IGNORE) para no bloquear clics del juego.
- Sin emojis en documentacion tecnica para optimizar espacio y consumo de tokens.
