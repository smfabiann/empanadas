#  Sistema de Anomalías Modulares (Anomalies)

Arquitectura modular para crear y gestionar manifestaciones anómalas (ambientales, visuales, shaders y HUD) desacopladas de los clientes. Diseñado para rápida creación por desarrolladores y agentes de IA.

---

##  Diferencia entre Eventos y Anomalías

| Sistema | Ubicación | Rol y Alcance |
|---|---|---|
| **Eventos (`NPCEvent`)** | `scripts/events/` | Modifican o reemplazan directamente a los clientes/NPCs en el mostrador (ej. `BigHead`, `FastNPC`, `RobberEvent`, `UfoEvent`). |
| **Anomalías (`AnomalyBase`)** | `scripts/anomalies/` | Fenómenos independientes del NPC: distorsiones en pantalla, filtros de shaders, parpadeo de luces, niebla espesa, audio tenso o entidades de HUD. |

> [!IMPORTANT]
> Son sistemas independientes. Cuando un cliente tiene un evento activo (especialmente eventos estáticos narrativos como el OVNI o el Ladrón), las anomalías aleatorias no se disparan para evitar interferencias y confusiones.

---

##  Arquitectura

| Archivo / Recurso | Rol |
|---|---|
| [`AnomalyBase.tscn`](../../scenes/anomalies/AnomalyBase.tscn) / [`AnomalyBase.gd`](./AnomalyBase.gd) | Escena base heredable. Provee contenedores `Visuals2D` (HUD/CanvasLayer) y `Visuals3D` (mundo), timer y ciclo de vida. |
| [`AnomalyData.gd`](./AnomalyData.gd) | Recurso (`.tres`) exportable con disparadores (turno exacto, umbral de atendidos, días, peso/rareza) y referencia a la escena. |
| [`AnomaliesManager.gd`](./AnomaliesManager.gd) | Nodo central en `Main.tscn` (`AnomaliesManagement`). Gestiona catálogo, sorteo probabilístico, concurrencia y depuración. |
| [`GlitchSpriteAnomaly.tscn`](../../scenes/anomalies/GlitchSpriteAnomaly.tscn) | Ejemplo funcional: distorsión espectral con shader de aberración cromática, parpadeo de luces, niebla y filtro rojo. |
| [`Aware.tscn`](../../scenes/anomalies/Aware.tscn) / [`Aware.gd`](./Aware.gd) | Ejemplo reactivo: reacciona al monitor de seguridad (`SecurityMonitor.gd`), manifestando un ojo vigilante y señal visual solo cuando el jugador mira a través del monitor. |
| [`cctv/CCTVEventAnomaly.gd`](./cctv/CCTVEventAnomaly.gd) | Base de los eventos visibles en CCTV (HU-10): se colocan en una `CCTVZone` y solo se ven a través del monitor de seguridad. Ver sección **Eventos de CCTV**. |

---

## ⏱ Ciclo de Vida (`AnomalyBase`)

Toda anomalía implementa los siguientes pasos:

1. **`_init_anomaly(context: Dictionary)`**: Recibe `{npc, spawn_number, current_day, manager}`. Captura estado ambiental previo y emite `anomaly_started`.
2. **`execute_behavior()`**: Inicia la manifestación activa (animaciones, shaders, tweens, SFX, distorsión de luces/niebla).
3. **`resolve()`**: Concluye la manifestación. Restaura el ambiente, reproduce animación de salida (si existe), emite `anomaly_resolved` y libera la instancia con `queue_free()`.

### Ganchos Opcionales (Hooks)
- `on_customer_arrived(npc)`: Se dispara cuando un cliente llega al mostrador mientras la anomalía está activa.
- `on_customer_served(npc, is_correct)`: Se dispara cuando se entrega un pedido.
- `on_persiana_closed()`: Se dispara cuando el jugador baja la persiana (ideal para ahuyentar entidades).

---

##  Paso a Paso: Crear una Nueva Anomalía

### 1. Crear Escena Heredada
En Godot: Clic derecho sobre `res://scenes/anomalies/AnomalyBase.tscn`  **New Inherited Scene**.
- Elementos 2D en pantalla (shaders, sprites, HUD): Colócalos dentro de `$Visuals2D`.
- Elementos 3D en el mundo (partículas, luces, mallas): Colócalos dentro de `$Visuals3D`.
- Guarda en `res://scenes/anomalies/MiAnomalia.tscn`.

### 2. Crear Script (`res://scripts/anomalies/MiAnomalia.gd`)
```gdscript
class_name MiAnomalia
extends AnomalyBase

@export var duration: float = 6.0
@onready var sprite: Sprite2D = $Visuals2D.get_node_or_null("Sprite")

func _init_anomaly(context: Dictionary = {}) -> void:
	super._init_anomaly(context)
	auto_resolve_duration = duration

func execute_behavior() -> void:
	super.execute_behavior()
	if SFXManager:
		SFXManager.play_tense_anger()
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 1.0, 0.3)

func resolve() -> void:
	if is_resolved:
		return
	if sprite:
		var tw = create_tween()
		tw.tween_property(sprite, "modulate:a", 0.0, 0.3)
		await tw.finished
	super.resolve()

func on_persiana_closed() -> void:
	resolve() # Ahuyentada al cerrar persiana
```

### 3. Crear Recurso `AnomalyData` (`.tres`)
En `res://resources/anomalies/mi_anomalia.tres`:
- **`id`**: `"mi_anomalia"` (único).
- **`anomaly_name`**: Nombre legible (ej. `"Sombra Errante"`).
- **`anomaly_scene`**: Asignar `MiAnomalia.tscn`.
- **`weight`**: Peso relativo en la lotería (ej. `15.0`).
- **`tier`**: `COMMON`, `UNCOMMON`, `RARE`, `NIGHTMARE`.
- **`enabled`**: `true`.

### 4. Registrar en `Main.tscn`
Selecciona el nodo `AnomaliesManagement` en `Main.tscn` y agrega el `.tres` al array `registered_anomalies`.

---

##  Disparadores Disponibles (`AnomalyData`)

| Parámetro | Tipo | Efecto |
|---|---|---|
| `trigger_exact_customer` | `int` | Disparo garantizado en el cliente N exacto de la partida (`-1` o `0` = desactivado). |
| `trigger_min_served` | `int` | Umbral: requiere haber atendido al menos X clientes (`0` = sin requisito). |
| `min_day` / `max_day` | `int` | Rango de días en los que puede ocurrir (`max_day = 0` significa sin límite). |
| `weight` | `float` | Peso para sorteo probabilístico (a mayor peso, más frecuencia). |
| `trigger_once` | `bool` | Si `true`, solo ocurre una vez por partida. |
| `enabled` | `bool` | Toggle para activar/desactivar sin desregistrar. |

---

##  Depuración desde el Inspector (`AnomaliesManagement`)

Para depurar en tiempo de ejecución mientras el juego está corriendo:
1. En la pestaña **Scene** (panel izquierdo del editor de Godot), cambia de **Local** a **Remote**.
2. Selecciona el nodo `root/Main/AnomaliesManagement`.
3. En el **Inspector**:
   - **`debug_force_anomaly`**: Escribe el ID (ej. `"aware"` o `"glitch_sprite"`). También tolera el nombre de la anomalía (ej. `"El Consciente"`).
   - **`debug_trigger_now`**: Marca esta casilla (checkbox) para disparar la anomalía **inmediatamente**. Se desmarcará sola tras dispararla.
   - Si no marcas `debug_trigger_now`, la anomalía seleccionada en `debug_force_anomaly` se disparará con la llegada del **siguiente cliente**.
   - **`debug_always_trigger`**: Toggle para forzar 100% de probabilidad en todos los sorteos normales.

> [!NOTE]
> **Comportamiento especial de "El Consciente" (`Aware`)**:
> Esta anomalía está diseñada para acechar en silencio: **no muestra nada en el mostrador ni en la ventana**.
> Solo se manifiesta visiblemente (el ojo rojo y alerta) cuando el jugador se acerca al monitor de seguridad en la pared izquierda e interactúa con **`[E]`** para ver las cámaras.
> Si deseas ver el ojo directamente sin mirar el monitor para pruebas rápidas, selecciona el nodo instanciado `root/Main/AnomaliesManagement/Aware` en el árbol **Remote** y marca la casilla **`Debug Always Visible`**.

---

##  Eventos de CCTV (HU-10)

Eventos que ocurren en zonas cubiertas por las cámaras de seguridad. **Solo se ven a través del monitor** (pantalla completa con `[E]`, o en la pantalla del monitor en la pared); la cámara del jugador no los renderiza. Obligan al jugador a revisar las cámaras periódicamente.

### Piezas

| Archivo | Rol |
|---|---|
| [`scripts/cctv/CCTVCamera.gd`](../cctv/CCTVCamera.gd) | Script de cada cámara de seguridad (un canal). Define `channel_id`, `channel_name` y `channel_index`. Ve la capa de render 11 (`CCTV`). |
| [`scripts/cctv/CCTVZone.gd`](../cctv/CCTVZone.gd) | `Marker3D` bajo `Main/CCTVZones` que marca dónde puede aparecer un evento y qué canal lo cubre (`channel_id`). |
| [`cctv/CCTVEventAnomaly.gd`](./cctv/CCTVEventAnomaly.gd) | Base: elige zona, se coloca en ella, mueve sus visuales a la capa de CCTV sin sombras y detecta cuándo el jugador sintoniza su canal. |
| [`SecurityMonitor.gd`](../SecurityMonitor.gd) | Recorre los canales (`[A]/[D]` o flechas mientras se mira), muestra el HUD (`REC CAM 01 · FRENTE`, hora, filtro con líneas de escaneo) y aplica interferencia por canal. |

### Eventos incluidos

| ID | Nombre | Comportamiento | Desde |
|---|---|---|---|
| `cctv_lurker` | Silueta Acechando | Figura inmóvil; cada vez que vuelves a sintonizar su canal está más cerca de la cámara. | Día 1 |
| `cctv_intruder` | Intruso en el Perímetro | Merodea de un lado a otro; si lo observas ~2 s, se detiene y mira a la cámara. | Día 2 |
| `cctv_power_failure` | Fallo Eléctrico | Caja eléctrica chisporroteando; la señal de ese canal se llena de estática con cortes de "SIN SEÑAL". Los demás canales siguen normales. | Día 1 |
| `cctv_night_entity` | Presencia en la Vereda | Figura pálida que se acerca a la ventana por la CAM 01. **Solo se ve con la visión nocturna `[F]`**; sin ella deja una leve interferencia. Bajar la persiana la ahuyenta; si llega a la ventana con la persiana arriba se pierden $4.000. | Día 1 |
| `cctv_patio_thief` | Ladrón del Patio | Cruza el patio por la CAM 02, fuerza la puerta trasera y espera antes de entrar. **Cerrar la puerta trasera** mientras sigue afuera lo hace arrancar; si entra, roba $5.000. También es visible en el mundo. | Día 2 |
| `cctv_shadow_companion` | El Acompañante Oculto | Un doppelgänger oscuro acecha justo detrás de un cliente normal. **Solo visible con visión nocturna `[F]` en CAM 01**. ¡Prohibido atenderlo! Atenderlo acumula strikes hasta un Game Over letal. Se neutraliza bajando la persiana. | Día 1 |

Canales actuales: `frente` (CAM 01, cámara `Map/Shop/Camara`) y `patio` (CAM 02, cámara `Map/Shop/Camara2`).

### Visión nocturna

La capa de render 12 (`NightVision`) solo la ven las cámaras de CCTV mientras el jugador tiene la visión nocturna `[F]` activa en el monitor. Para que algo exista solo en la visión nocturna, llamar `CCTVCamera.make_night_vision_only(visuals_3d)` después de `super._init_anomaly()` (ver `CCTVNightEntityAnomaly`). `CCTVCamera.is_channel_viewed_with_night_vision(tree, channel_id)` dice si el jugador la está mirando así.

### Persiana y puerta trasera

- La persiana del mostrador está en el grupo `persiana` (`is_open`) y al bajarse llama `on_persiana_closed()` en todas las anomalías activas.
- La puerta trasera (`scripts/map/BackDoor.gd`) está en el grupo `back_door`: `is_open`, `open()`, `close()`, `jiggle()` y la señal `door_toggled(is_open)`.

### Crear un evento de CCTV nuevo

1. Escena heredada de `AnomalyBase.tscn` con `auto_execute_on_ready = false` y un script que extienda `CCTVEventAnomaly`.
2. Construir los visuales dentro de `visuals_3d` en `_build_visuals()` (la base los pasa a la capa de CCTV). `CCTVEventAnomaly.build_silhouette()` crea una silueta lista para usar.
3. Animar en `_update_event(delta)`; reaccionar con `_on_view_started()` / `_on_view_ended()`. `is_viewed_now`, `was_seen` y la señal `seen_on_cctv` dicen si el jugador lo está viendo.
4. Para alterar la señal del canal, agregar el nodo al grupo `cctv_feed_modifiers` e implementar `get_feed_interference(channel_id) -> float` (0..1).
5. Opcional: `allowed_channels` limita en qué canales puede aparecer. Para forzar una zona concreta, pasar `{"cctv_zone": nodo}` en el contexto de `force_trigger_anomaly()`.
6. Crear su `AnomalyData` (`.tres`) y registrarlo en `AnomaliesManagement`.

Para agregar una cámara nueva: crear un `Camera3D` con el script `CCTVCamera.gd` (canal e índice únicos) y agregar `Marker3D` con `CCTVZone.gd` dentro de su encuadre en `Main/CCTVZones`. El test `tests/test_cctv_events.tscn` verifica que cada zona esté dentro del encuadre de su cámara.

> [!IMPORTANT]
> La capa de render 11 (`CCTV`) está reservada: la cámara del jugador la oculta en `Player.gd`. Los visuales de un evento de CCTV no deben proyectar sombras (la base las desactiva), o se verían desde la vista del jugador.
