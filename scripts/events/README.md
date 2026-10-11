# 🎪 Sistema de Eventos de NPCs (NPC Events)

Arquitectura modular para modificar la apariencia, comportamiento y lógica de los clientes que se presentan en la ventana. Pensado para rápida creación por desarrolladores y agentes de IA.

---

## 📌 Diferencia entre Eventos y Anomalías

| Sistema | Ubicación | Rol y Alcance |
|---|---|---|
| **Eventos (`NPCEvent`)** | `scripts/events/` | Modifican o reemplazan directamente a los clientes/NPCs en el mostrador (ej. `BigHead`, `FastNPC`, `RobberEvent`, `UfoEvent`). |
| **Anomalías (`AnomalyBase`)** | `scripts/anomalies/` | Fenómenos audiovisuales/ambientales independientes: shaders de distorsión, parpadeo de luces, niebla espesa o entidades de HUD. |

> [!NOTE]
> Para crear o editar anomalías visuales e independientes, consulta la guía dedicada: [`scripts/anomalies/README.md`](../anomalies/README.md).

---

## 🏗️ Arquitectura

| Archivo | Rol |
|---|---|
| [`NPCEvent.gd`](./NPCEvent.gd) | `Resource` base para eventos aleatorios de clientes. Ganchos de ciclo de vida. |
| [`StaticNPCEvent.gd`](./static/StaticNPCEvent.gd) | Plantilla base para eventos estáticos / narrativos con condiciones y modelos propios. |
| [`RobberNPC.gd`](./static/RobberNPC.gd) | Controlador y comportamiento del NPC del Ladrón para el evento estático (Día 1). |
| [`UfoEvent.gd`](./static/ufo/UfoEvent.gd) | Evento estático del Visitante Espacial / OVNI (Día 2). |
| [`UfoNPC.gd`](./static/ufo/UfoNPC.gd) | Controlador del NPC alienígena: temblor de pantalla previo, flash supersónico (Star Wars stop), planeo por el cielo, descenso flotante y retirada al cosmos. |
| [`NPCEventManager.gd`](./NPCEventManager.gd) | Nodo en escena (`Main.tscn`) y catálogo central. Resuelve: Debug > Estáticos/Condicionales > Sorteo Ponderado. |
| [`NPCSpawner.gd`](../NPCSpawner.gd) | Consulta evento, instancia la escena (estándar o dedicada) y le asigna el evento. |
| [`NPC.gd`](../NPC.gd) | Invoca los ganchos del evento activo en sus transiciones de estado. |

---

## ⏱️ Ciclo de Vida (`NPCEvent`)

Implementa solo los métodos que necesites:

| Método | Momento | Uso Típico |
|---|---|---|
| `apply(npc)` | En `_ready()` del NPC. | Escalar mallas, materiales/shaders, alterar `speed`, `patience_time`. |
| `on_arrive(npc)` | Al llegar al mostrador. | Modificar pedido, cambiar texto/color en `Label3D`, animaciones. |
| `on_leave(npc)` | Al retirarse. | Cambiar velocidad de huida, sonidos especiales, efectos de salida. |

---

## 🚀 Plantilla 1: Evento Aleatorio Rápido

Crea un script en `res://scripts/events/MiEventoRandom.gd`:

```gdscript
class_name MiEventoRandom
extends NPCEvent

func _init() -> void:
	id = "mi_evento"               # ID único
	event_name = "Nombre Mostrado"
	weight = 15.0                  # Probabilidad relativa (peso > 0)

func apply(npc: CharacterBody3D) -> void:
	if "speed" in npc:
		npc.speed = 4.0

func on_arrive(npc: CharacterBody3D) -> void:
	var label = npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "👾 " + label.text
```

---

## 🗿 Plantilla 2: Evento Estático / Narrativo (con Modelo Propio)

Crea un script en `res://scripts/events/static/MiEventoEstatico.gd` heredando de `StaticNPCEvent`:

```gdscript
class_name MiEventoEstatico
extends StaticNPCEvent

func _init() -> void:
	super._init()
	id = "mi_evento_estatico"
	event_name = "Evento Especial"
	trigger_day = 2                # Opcional: día mínimo (ej. día 2)
	trigger_day_served_count = 1   # Opcional: clientes atendidos en la jornada
	trigger_served_count = 5       # Opcional: clientes atendidos totales
	trigger_once = true            # Ocurre 1 sola vez por partida
	custom_npc_scene = preload("res://scenes/MiNPCScene.tscn") # Escena con modelo propio (opcional)

func apply(npc: CharacterBody3D) -> void:
	pass

func on_arrive(npc: CharacterBody3D) -> void:
	var label = npc.get_node_or_null("Label3D") as Label3D
	if label:
		label.text = "¡He llegado!"
```

---

## ⚙️ Registro de Eventos (`NPCEventManager.gd`)

Registra cualquier nuevo evento en `_register_default_events()`:
```gdscript
func _register_default_events() -> void:
	register_event(BigHeadEvent.new())
	register_event(FastNPCEvent.new())
	register_event(RobberEvent.new()) # Evento estático del ladrón
	register_event(UfoEvent.new())    # Evento estático del ovni / extraterrestre
```

---

## 🧪 Depuración (`NPCSpawner` y `NPCEventManager` en Inspector)

- **`events_enabled`**: Activar / desactivar sistema de eventos.
- **`random_event_chance`**: Probabilidad base de evento aleatorio (ej. `0.35` = 35%).
- **`debug_force_event`**: Escribe el `id` (ej. `"robber"`, `"ufo"`, `"big_head"`) para forzarlo en **todos** los spawns.
- **`debug_force_ufo`**: Toggle booleano para forzar la aparición inmediata del OVNI en el próximo cliente.
- **`debug_advance_day_key`**: Tecla rápida en tiempo de ejecución (por defecto `F6`) para avanzar inmediatamente al siguiente día.
- **`debug_always_trigger_event`**: Fuerza 100% de probabilidad en el sorteo aleatorio de eventos.
- **`robber_trigger_served_count`**: Cantidad de clientes atendidos para disparar el Ladrón.
- **`robber_max_day`**: Día límite para el Ladrón (por defecto: `1`, asegurando que solo aparezca en el Día 1).
- **`ufo_trigger_day`**: Día de activación del OVNI (por defecto: `2`).
- **`ufo_trigger_served_in_day`**: Clientes atendidos en la jornada antes de que aparezca el OVNI (por defecto: `1`).

---

## ⚠️ Reglas Clave de Implementación
1. **Acceso seguro:** Usa `npc.get_node_or_null("NodeName")` o `if "prop" in npc:` para evitar caídas si la escena cambia.
2. **NPCs con modelo propio:** En escenas personalizadas (como `RobberNPC.tscn` o `UfoNPC.tscn`), activar `custom_appearance = true` en el nodo raíz para que `NPC.gd` no sobrescriba tus materiales con colores aleatorios.
3. **Compensación de UI:** Si aumentas el tamaño del NPC o cabeza, sube `Label3D.position.y` y `PatienceBarPivot.position.y` para no tapar los pedidos.
4. **Desacoplamiento:** Los eventos de NPC nunca deben activar anomalías del gestor de anomalías sobre el mismo cliente.

---

## 👁️ Sistema de Anomalías Modulares (`scripts/anomalies/`)
Para la creación y gestión de anomalías independientes con escenas propias (`AnomalyBase`, `AnomalyData`, shaders y `AnomaliesManager`), consulta:
- **Documentación principal**: [`scripts/anomalies/README.md`](../anomalies/README.md)
- **Flujo de trabajo detallado**: [`docs/anomalies_workflow.md`](../../docs/anomalies_workflow.md)
