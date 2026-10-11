# 👁️ Sistema de Anomalías Modulares (Anomalies)

Arquitectura modular para crear y gestionar manifestaciones anómalas (ambientales, visuales, shaders y HUD) desacopladas de los clientes. Diseñado para rápida creación por desarrolladores y agentes de IA.

---

## 📌 Diferencia entre Eventos y Anomalías

| Sistema | Ubicación | Rol y Alcance |
|---|---|---|
| **Eventos (`NPCEvent`)** | `scripts/events/` | Modifican o reemplazan directamente a los clientes/NPCs en el mostrador (ej. `BigHead`, `FastNPC`, `RobberEvent`, `UfoEvent`). |
| **Anomalías (`AnomalyBase`)** | `scripts/anomalies/` | Fenómenos independientes del NPC: distorsiones en pantalla, filtros de shaders, parpadeo de luces, niebla espesa, audio tenso o entidades de HUD. |

> [!IMPORTANT]
> Son sistemas independientes. Cuando un cliente tiene un evento activo (especialmente eventos estáticos narrativos como el OVNI o el Ladrón), las anomalías aleatorias no se disparan para evitar interferencias y confusiones.

---

## 🏗️ Arquitectura

| Archivo / Recurso | Rol |
|---|---|
| [`AnomalyBase.tscn`](../../scenes/anomalies/AnomalyBase.tscn) / [`AnomalyBase.gd`](./AnomalyBase.gd) | Escena base heredable. Provee contenedores `Visuals2D` (HUD/CanvasLayer) y `Visuals3D` (mundo), timer y ciclo de vida. |
| [`AnomalyData.gd`](./AnomalyData.gd) | Recurso (`.tres`) exportable con disparadores (turno exacto, umbral de atendidos, días, peso/rareza) y referencia a la escena. |
| [`AnomaliesManager.gd`](./AnomaliesManager.gd) | Nodo central en `Main.tscn` (`AnomaliesManagement`). Gestiona catálogo, sorteo probabilístico, concurrencia y depuración. |
| [`GlitchSpriteAnomaly.tscn`](../../scenes/anomalies/GlitchSpriteAnomaly.tscn) | Ejemplo funcional: distorsión espectral con shader de aberración cromática, parpadeo de luces, niebla y filtro rojo. |

---

## ⏱️ Ciclo de Vida (`AnomalyBase`)

Toda anomalía implementa los siguientes pasos:

1. **`_init_anomaly(context: Dictionary)`**: Recibe `{npc, spawn_number, current_day, manager}`. Captura estado ambiental previo y emite `anomaly_started`.
2. **`execute_behavior()`**: Inicia la manifestación activa (animaciones, shaders, tweens, SFX, distorsión de luces/niebla).
3. **`resolve()`**: Concluye la manifestación. Restaura el ambiente, reproduce animación de salida (si existe), emite `anomaly_resolved` y libera la instancia con `queue_free()`.

### Ganchos Opcionales (Hooks)
- `on_customer_arrived(npc)`: Se dispara cuando un cliente llega al mostrador mientras la anomalía está activa.
- `on_customer_served(npc, is_correct)`: Se dispara cuando se entrega un pedido.
- `on_persiana_closed()`: Se dispara cuando el jugador baja la persiana (ideal para ahuyentar entidades).

---

## 🚀 Paso a Paso: Crear una Nueva Anomalía

### 1. Crear Escena Heredada
En Godot: Clic derecho sobre `res://scenes/anomalies/AnomalyBase.tscn` → **New Inherited Scene**.
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

## 🎛️ Disparadores Disponibles (`AnomalyData`)

| Parámetro | Tipo | Efecto |
|---|---|---|
| `trigger_exact_customer` | `int` | Disparo garantizado en el cliente N exacto de la partida (`-1` o `0` = desactivado). |
| `trigger_min_served` | `int` | Umbral: requiere haber atendido al menos X clientes (`0` = sin requisito). |
| `min_day` / `max_day` | `int` | Rango de días en los que puede ocurrir (`max_day = 0` significa sin límite). |
| `weight` | `float` | Peso para sorteo probabilístico (a mayor peso, más frecuencia). |
| `trigger_once` | `bool` | Si `true`, solo ocurre una vez por partida. |
| `enabled` | `bool` | Toggle para activar/desactivar sin desregistrar. |

---

## 🧪 Depuración en Tiempo de Ejecución

- **Tecla `F4`**: Fuerza la activación inmediata de la anomalía configurada en `debug_force_anomaly` (o la primera del catálogo).
- **Tecla `F3`**: Muestra el panel con contadores de depuración y estado de anomalías activas.
- **`debug_force_anomaly`**: Escribe el ID (ej. `"glitch_sprite"`) en el Inspector para forzarla.
- **`debug_always_trigger`**: Toggle para forzar 100% de probabilidad en todos los sorteos.
