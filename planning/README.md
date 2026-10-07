# Documentación del Proyecto (`planning/`)

Documentación técnica centralizada y optimizada para proporcionar contexto claro y directo a agentes y desarrolladores.

## Índice de Documentación

1. **[Arquitectura y Flujo de Juego (`ARCHITECTURE.md`)](./ARCHITECTURE.md)**:
   - Configuración base, autoloads y capas físicas 3D.
   - Jerarquía de nodos de `Main.tscn` y módulos principales.
   - Ciclo de juego (Game loop: arranque, jornadas, cocina 3D, victoria y derrota).
2. **[Guía de Desarrollo y Convenciones (`GUIA_DESARROLLO.md`)](./GUIA_DESARROLLO.md)**:
   - Reglas de oro y convenciones para no romper referencias de nodos ni señales.
   - Cómo agregar nuevos eventos, anomalías y estaciones de cocina.
   - Checklist de validación técnica.
3. **[Roadmap y Backlog de Tareas (`ROADMAP.md`)](./ROADMAP.md)**:
   - Visión del proyecto, estado actual y backlog activo de tareas prioritarias.
   - Fases de desarrollo (Fase 1 completada, Fase 2 en curso, fases futuras).

---

## Otras Referencias Clave

- [`docs/anomalies_workflow.md`](../docs/anomalies_workflow.md): Guía paso a paso para el sistema modular de anomalías.
- [`scripts/events/README.md`](../scripts/events/README.md): Guía técnica del sistema de eventos de clientes.
- [`changelog.md`](../changelog.md): Historial cronológico detallado de versiones y tareas completadas.
