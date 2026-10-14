# Completos (Placeholder)

Videojuego 3D desarrollado en **Godot Engine 4.7** para la asignatura **Taller de Juegos (2026)**.

---

## 📌 Identificación del Proyecto (Criterio de Rúbrica)

- **Nombre del juego**: `Completos` *(Placeholder / Nombre provisional solicitado)*
- **Creadores**:
  - **Nicolaz Perez**
  - **Nicolas Vargas**
  - **Fabian San Martin**
- **Asignatura / Contexto**: Taller de Juegos — 2026

---

## 🎨 Créditos y Atribuciones del Contenido Base

Un análisis del proyecto y sus recursos determina lo siguiente:

1. **Motor de Videojuego y Físicas**:
   - **Godot Engine 4.7** (Render Forward+).
   - **Godot Jolt Physics** como motor de física 3D integrado.

2. **Modelado y Geometría 3D**:
   - Todo el apartado visual y espacial (local de comida, estaciones de cocina, ingredientes, calle, edificios, baño químico y personajes) está modelado íntegramente mediante **primitivas geométricas nativas (CSG - Constructive Solid Geometry)** de Godot (`CSGBox3D`, `CSGCylinder3D`, `CSGSphere3D`) y materiales `StandardMaterial3D`.
   - **No se utilizaron paquetes de modelos 3D externos ni assets de terceros** (como packs de Kenney, Synty u otros).

3. **Audio y Efectos Sonoros (SFX)**:
   - Todo el sonido del juego es **procedural y sintetizado en tiempo real por software** utilizando el nodo `AudioStreamGenerator` en `SFXManager.gd`.
   - Los tonos de interacción, victorias, derrotas, estallidos sónicos y zumbidos cósmicos se calculan matemáticamente (ondas senoidales, ruido blanco y barridos exponenciales/lineales de frecuencia).
   - **No se emplean archivos de audio externos** (`.mp3`, `.wav`, `.ogg`).

4. **Shaders y Efectos Visuales**:
   - Shaders GLSL desarrollados a medida para el proyecto:
     - `glitch_anomaly.gdshader`: Distorsión y aberración cromática para eventos de anomalías.
     - `night_sky.gdshader`: Renderizado procedural del cielo nocturno estrellado.
     - `red_anomaly_filter.gdshader`: Filtro ambiental dinámico de eventos.

5. **Texturas y Gráficos 2D**:
   - Fotografía / textura propia del equipo: `resources/npc_textures/nachito.jpg` (utilizada en el rostro del NPC).
   - Ícono estándar del motor: `icon.svg` (Godot Engine).
   - Tipografía: Fuentes nativas de Godot Engine.

---

## 🎮 Controles

| Tecla / Acción | Descripción |
| :--- | :--- |
| **W, A, S, D** | Moverse por el local y la cocina |
| **Shift** | Correr / Sprint |
| **E** | Interactuar / Recoger ingrediente o plato / Entregar pedido |
| **Q** | Soltar objeto sostenido |
| **ESC** | Pausar / Reanudar juego (o cerrar modal de créditos) |

---

## 🚀 Cómo Ejecutar el Proyecto

1. Abrir **Godot Engine 4.7** (versión Standard o .NET).
2. Importar o seleccionar el archivo `project.godot` de esta carpeta.
3. Presionar **F5** (o el botón *Play* en el editor) para ejecutar el juego.
   - Escena principal de inicio: `res://scenes/ui/MainMenu.tscn`.
