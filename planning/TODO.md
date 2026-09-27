# TASK.md - Prototipo Retail Retro 3D (Godot 4.x + GDScript)

## 📌 Contexto para el Agente (Antigravity)
Eres un desarrollador experto en Godot 4.x y GDScript. Tu tarea es implementar el prototipo de un juego 3D con estética retro (low-poly/PSX). 
- **Mecánica principal:** El jugador atiende un mostrador en primera persona. Un NPC se acerca, pide un objeto específico (ej. Sopaipilla, Bebida), y el jugador debe recogerlo y entregárselo.
- **Bucle de juego:** Infinito. Entrega correcta = Puntos. Entrega incorrecta = Pierde 1 vida. 0 vidas = Game Over.
- **Pre-requisitos completados por el usuario:** La escena `Main.tscn` ya existe con un `WorldEnvironment` (estética retro configurada), un suelo (`CSGBox3D`), un mostrador (`CSGBox3D`), iluminación y 3 `Marker3D` (`SpawnPoint`, `CounterPoint`, `ExitPoint`). Los inputs `interact` y `drop_item` están mapeados. Las capas de físicas están configuradas: 1 (World), 2 (Interactable), 3 (NPC).

Debes completar las siguientes tareas secuencialmente, marcando las casillas `[x]` al terminar y asegurándote de usar buenas prácticas de GDScript.

---

## 🛠️ Fase 1: Datos y Objetos Interactuables
- [x] **1.1 Crear `ItemData.gd`:** Crea un script en `res://scripts/ItemData.gd` que extienda de `Resource`. Debe exportar un `id` (String) y un `display_name` (String).
- [x] **1.2 Crear recursos `.tres`:** Crea una carpeta `res://resources/items/` y genera dos recursos basados en `ItemData.gd`: uno con id `"sopaipilla"` y otro con id `"bebida"`.
- [x] **1.3 Crear `Interactable.gd`:** Crea un script base para objetos recogibles. Debe tener un método `interact(player)` y `drop()`.
- [x] **1.4 Crear escenas de Ítems (`Sopaipilla.tscn` y `Drink.tscn`):**
  - Raíz: `RigidBody3D` (Capa de física 2 - Interactable, colisiona con 1).
  - Añade un `CollisionShape3D` y un modelo temporal (ej. `CSGBox3D` o `CSGSphere3D` pequeño y de colores distintivos).
  - Adjunta el script `Interactable.gd`.
  - Exporta una variable en el script para asignarle su respectivo recurso `ItemData` (sopaipilla o bebida).
  - Coloca instancias de estos objetos sobre el mostrador en `Main.tscn`.

## 🧍 Fase 2: Jugador e Interacción
- [x] **2.1 Crear escena `Player.tscn`:**
  - Raíz: `CharacterBody3D` (Capa 1).
  - Hijo: `Camera3D` a la altura de los ojos.
  - Hijo de Camera3D: `RayCast3D` apuntando al centro (eje Z negativo, longitud 2.5m). Su `Collision Mask` debe estar configurada para detectar solo las capas 2 (Interactable) y 3 (NPC).
  - Hijo de Camera3D: `Marker3D` llamado `HoldPoint` (donde irá el objeto cuando se recoja, ej. `Z: -1.0`, `Y: -0.3`).
- [x] **2.2 Programar `Player.gd`:**
  - Lógica para mirar alrededor con el ratón (movimiento restringido, no necesita caminar, solo mirar desde detrás del mostrador).
  - Si pulsa la acción `interact`:
    - Si el RayCast colisiona con un objeto de capa 2 (Interactable) y tiene las manos vacías: reparenta el objeto al `HoldPoint`, desactiva su gravedad/físicas y lo guarda en una variable `held_item`.
    - Si el RayCast colisiona con un NPC (capa 3) y tiene un `held_item`: llama al método `receive_item(held_item)` del NPC y elimina el objeto de las manos del jugador.
  - Si pulsa la acción `drop_item`: Suelta el objeto, restaura sus físicas y lo desvincula del jugador.

## 🤖 Fase 3: Lógica del NPC y Pedidos
- [x] **3.1 Crear escena `NPC.tscn`:**
  - Raíz: `CharacterBody3D` (Capa de física 3 - NPC, colisiona con 1).
  - Malla: un `CSGCylinder3D` simple.
  - Colisión: `CollisionShape3D` (Cápsula).
  - UI Flotante: un `Label3D` sobre su cabeza (inicialmente vacío o invisible).
- [x] **3.2 Programar `NPC.gd`:**
  - Referencias a puntos globales (`spawn_pos`, `counter_pos`, `exit_pos`).
  - Máquina de estados simple (Enum): `APPROACHING`, `WAITING`, `LEAVING`.
  - En `_physics_process`: moverse usando `move_toward` o cálculo simple de velocidad hacia el punto objetivo actual dependiendo del estado. No requiere NavigationAgent complejo.
  - Al llegar a `counter_pos`: cambia al estado `WAITING`, elige aleatoriamente un `ItemData` de una lista predefinida, y muestra el texto `"Quiero: " + item.display_name` en el `Label3D`.
  - **Método `receive_item(item_node)`:** 
    - Compara `item_node.item_data.id` con el `id` solicitado.
    - Llama a `GameManager` para sumar puntos o restar vidas según el resultado.
    - Oculta el `Label3D`, cambia el estado a `LEAVING` hacia `exit_pos` y libera el objeto entregado (`queue_free`).
  - Al llegar a `exit_pos`: se auto-destruye (`queue_free()`).

## ⚙️ Fase 4: Bucle de Juego (Game Loop)
- [x] **4.1 Crear y configurar Autoload `GameManager.gd`:**
  - Variables: `score = 0`, `lives = 3`.
  - Señales: `ui_updated(score, lives)`, `game_over_reached()`.
  - Funciones:
    - `handle_order(is_correct: bool)`: Si es true, `score += 10`. Si es false, `lives -= 1`. Emite `ui_updated`. Si `lives <= 0`, emite `game_over_reached`.
- [x] **4.2 Spawner de NPCs (`NPCSpawner.gd`):**
  - Añade un nodo genérico en `Main.tscn` llamado `NPCSpawner`.
  - Lógica: Usa un `Timer`. Cuando termina, si no hay un NPC actualmente en el mostrador, instancia `NPC.tscn` en `SpawnPoint`, le pasa las posiciones de los 3 Markers y lo agrega a la escena.

## 🖥️ Fase 5: Interfaz de Usuario y Conexión Final
- [x] **5.1 Crear `UI.tscn` (CanvasLayer):**
  - Agrega un `Label` para Puntuación y otro para Vidas en las esquinas.
  - Agrega un pequeño `ColorRect` o `TextureRect` en el centro de la pantalla para que sirva de retícula/crosshair.
  - Crea un panel de Game Over con un botón de "Reintentar" (oculto por defecto).
  - Conecta el script de UI al Autoload `GameManager` para actualizar los textos de vidas y puntos.
- [x] **5.2 Integración final en `Main.tscn`:**
  - Asegúrate de que Player, UI, NPCSpawner y los ítems iniciales estén instanciados y funcionen en conjunto.