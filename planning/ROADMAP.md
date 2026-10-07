# Roadmap y Backlog de Tareas

## Visión General
Juego 3D retro con atmósfera de terror psicológico y anomalías. El jugador atiende un local nocturno de comida rápida chilena en primera persona tras el mostrador durante una semana de supervivencia laboral.

---

## Backlog Activo (Próximas Tareas Prioritarias)

- **[TASK-005] Nueva Anomalía: Cliente silencioso / estático**:
  - Cliente que llega al mostrador sin realizar pedido o solicitando ítems imposibles, aumentando la tensión psicológica.
- **[TASK-006] Implementación de SFX Faltantes**:
  - Efectos de sonido ambientales y de interacción: recoger/soltar ítem, timbre de pedido, pasos del jugador.
- **[TASK-008] Efectos Ambientales de Terror**:
  - Parpadeo de luces en mostrador y calle tras la aparición de anomalías o eventos de tensión.

---

## Fases del Proyecto

### Fase 1: Prototipo Core Retail (✅ Completada)
- Controlador de jugador FPS con sprint, salto y raycast interactivo.
- Sistema de cocina interactiva 3D de completos (pan, vienesa, palta, mayo, ketchup, basurero).
- IA de clientes con máquina de estados, pedidos y barra de paciencia.
- Bucle de jornadas laborales (3 días canónicos), fin de jornada y condición de victoria (HU-06).
- Autoloads `GameManager` y `SFXManager`, menús y HUD debug (F3).

### Fase 2: Sistema de Anomalías y Eventos (🔄 En Curso)
- Arquitectura desacoplada de eventos de NPCs (`NPCEventManager`, `BigHeadEvent`, `fastNPC`).
- Evento estático del Ladrón (`RobberNPC`) con mecánica defensiva de persiana.
- Gestor central de anomalías modulares (`AnomaliesManager` / `AnomalyBase` / `AnomalyData`, HU-ANOM-13).
- Ejemplo práctico implementado: `GlitchSpriteAnomaly` al 3.er cliente.
- *Pendiente:* Nuevas anomalías visuales y auditivas (TASK-005, eventos de luces TASK-008).

### Fase 3: Audio y Atmósfera (⏳ Planificada)
- Sonidos ambientales lo-fi retro y estática.
- SFX de interacción física (TASK-006).
- Eventos de audio posicional y frecuencias perturbadoras.

### Fase 4: Bucle de Terror y Progresión Avanzada (⏳ Planificada)
- Penalizaciones y consecuencias por ignorar anomalías.
- Eventos dinámicos en el exterior y calle fuera de la ventana.

---

> Para el detalle histórico completo de cambios y tareas ya implementadas, consultar [`changelog.md`](../changelog.md).
