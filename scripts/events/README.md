# 🎪 Sistema de Eventos y Anomalías (NPCs)

Arquitectura modular para modificar la apariencia, comportamiento y lógica de los clientes. Pensado para rápida creación por desarrolladores y agentes de IA.

---

## 🏗️ Arquitectura

| Archivo | Rol |
|---|---|
| [`NPCEvent.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/events/NPCEvent.gd) | `Resource` base para anomalías aleatorias. Ganchos de ciclo de vida. |
| [`StaticNPCEvent.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/events/static/StaticNPCEvent.gd) | Plantilla base para eventos estáticos / narrativos con condiciones y modelos propios. |
| [`RobberNPC.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/events/static/RobberNPC.gd) | Controlador y comportamiento del NPC del Ladrón para el evento estático. |
| [`NPCEventManager.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/events/NPCEventManager.gd) | Nodo en escena (`Main.tscn`) y catálogo central. Resuelve: Debug > Estáticos/Condicionales > Sorteo Ponderado. |
| [`NPCSpawner.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/NPCSpawner.gd) | Consulta evento, instancia la escena (estándar o dedicada) y le asigna el evento. |
| [`NPC.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/NPC.gd) | Invoca los ganchos del evento activo en sus transiciones de estado. |

---

## ⏱️ Ciclo de Vida (`NPCEvent`)

Implementa solo los métodos que necesites:

| Método | Momento | Uso Típico |
|---|---|---|
| `apply(npc)` | En `_ready()` del NPC. | Escalar mallas, materiales/shaders, alterar `speed`, `patience_time`. |
| `on_arrive(npc)` | Al llegar al mostrador. | Modificar pedido, cambiar texto/color en `Label3D`, animaciones. |
| `on_leave(npc)` | Al retirarse. | Cambiar velocidad de huida, sonidos especiales, efectos de salida. |

---

## 🚀 Plantilla 1: Evento Aleatorio / Anomalía Rápida

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
	trigger_served_count = 5       # Se activa tras atender X clientes
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
```

---

## 🧪 Depuración (`NPCSpawner` en Inspector)

- **`events_enabled`**: Activar / desactivar sistema.
- **`random_chance`**: Probabilidad base de anomalía aleatoria (ej. `0.35` = 35%).
- **`debug_force_event`**: Escribe el `id` (ej. `"robber"`, `"big_head"`) para forzarlo en **todos** los spawns.
- **`debug_always_trigger_event`**: Fuerza 100% de probabilidad en el sorteo aleatorio.
- **`robber_trigger_served_count`**: Cantidad de clientes atendidos para disparar el Ladrón (poner en `1` para probar inmediatamente).

---

## ⚠️ Reglas Clave de Implementación
1. **Acceso seguro:** Usa `npc.get_node_or_null("NodeName")` o `if "prop" in npc:` para evitar caídas si la escena cambia.
2. **NPCs con modelo propio:** En escenas personalizadas (como `RobberNPC.tscn`), activar `custom_appearance = true` en el nodo raíz para que `NPC.gd` no sobrescriba tus materiales con colores aleatorios.
3. **Compensación de UI:** Si aumentas el tamaño del NPC o cabeza, sube `Label3D.position.y` y `PatienceBarPivot.position.y` para no tapar los pedidos.

---

## 👁️ Sistema de Anomalías Visuales y Configurables (`anomaliesManagement` - HU-ANOM-13)

Para crear anomalías con escenas propias (sprites 2D/3D, animaciones, shaders, etc.) desacopladas de los NPCs estándar:
- **Gestor**: [`AnomaliesManager.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/anomalies/AnomaliesManager.gd) (nodo `AnomaliesManagement` en `Main.tscn`).
- **Base**: [`AnomalyBase.tscn`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scenes/anomalies/AnomalyBase.tscn) / [`AnomalyBase.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/anomalies/AnomalyBase.gd).
- **Recurso**: [`AnomalyData.gd`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/scripts/anomalies/AnomalyData.gd).
- **Guía completa paso a paso**: Consulta [`docs/anomalies_workflow.md`](file:///c:/Users/fabi/Documents/godot_projects/empanadas/empanadas/docs/anomalies_workflow.md).
