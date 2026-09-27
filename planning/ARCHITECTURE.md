# Arquitectura y Convenciones Técnicas

Documento de referencia para el desarrollo y mantenimiento del proyecto en Godot 4.x.

---

## 🏗️ Estructura del Proyecto

```
empanadas/
├── planning/              # Roadmap, tareas activas y arquitectura
├── resources/             # Recursos de Godot (.tres)
│   └── items/             # Definiciones de comida/bebida
├── scenes/                # Escenas del juego (.tscn)
│   ├── items/             # Modelos y físicas de objetos recogibles
│   ├── ui/                # Menú principal, pausa, HUD
│   ├── Main.tscn          # Escena principal 3D del local
│   ├── Player.tscn        # Jugador en 1ra persona
│   └── NPC.tscn           # Clientes animados por máquina de estados
├── scripts/               # Lógica en GDScript (.gd)
│   ├── GameManager.gd     # Autoload singleton de estado global
│   ├── SFXManager.gd      # Autoload singleton de audio
│   └── ...
└── project.godot          # Configuración del motor
```

---

## ⚡ Autoloads (Singletons)

1. **`GameManager` (`res://scripts/GameManager.gd`)**
   - Estado del juego: `score`, `lives`, `high_score`, `is_game_over`.
   - Señales: `ui_updated(score, lives)`, `game_over_reached()`.
   - Funciones: `reset_game()`, `handle_order(is_correct: bool)`.

2. **`SFXManager` (`res://scripts/SFXManager.gd`)**
   - Gestión de reproducción de efectos de sonido sintetizados o por streams.

---

## 📐 Capas de Físicas 3D (Physics Layers)

| Capa | Nombre | Uso |
|---|---|---|
| **1** | `World` | Geometría estática, paredes, suelo, mostrador. |
| **2** | `Interactable` | Objetos recogibles (Empanadas, Sopaipillas, Bebidas). |
| **3** | `NPC` | Clientes que se acercan al mostrador y reciben pedidos. |

---

## 🎮 Mapeo de Entradas (Input Map)

- `interact`: Tecla `E` (Recoger objeto / entregar al NPC).
- `drop_item`: Tecla `Q` (Soltar objeto en mano).
- `pause`: Tecla `Escape` (Alternar menú de pausa).
- `sprint`: Tecla `Shift` (Correr / acelerar movimiento).

---

## 🧩 Reglas Clave para UI en Godot

> [!CAUTION]
> **No modificar `position` ni `size` directamente en hijos de un `Container`:**
> En Godot, los nodos `Container` (`VBoxContainer`, `HBoxContainer`, `CenterContainer`, etc.) calculan dinámicamente las posiciones en cada frame. Intentar animar `child.position` romperá el layout amontonando los elementos en `(0, 0)`. Para animar elementos dentro de contenedores:
> - Usar propiedades de canvas (`modulate`, `modulate.a`).
> - O animar la posición/escala del contenedor raíz completo.
