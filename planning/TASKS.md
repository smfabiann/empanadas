# Tablero de Tareas

## Tarea Activa
(Ninguna en curso. Listo para seleccionar del backlog).

## Backlog / Pendientes
- [TASK-005] Diseno e implementacion de nueva anomalia: Cliente silencioso / estatico.
- [TASK-006] Implementar SFX basicos (recoger item, soltar, timbre de pedido y pasos).
- [TASK-008] Efectos ambientales de terror (parpadeo de luces en mostrador tras evento anomalo).

## Tareas Completadas
- [TASK-013] Sistema base, plantilla modular y gestor (anomaliesManagement) para Anomalías configurables (HU-ANOM-13, Issue #24). Escena y script base AnomalyBase con ciclo de vida desacoplado (_init_anomaly, execute_behavior, resolve) y contenedores para nodos visuales 2D/3D; recurso AnomalyData con condiciones de aparición (rareza, turno exacto, progresión temporal de días, umbral de atendidos); gestor central AnomaliesManager/AnomaliesManagement con controles en Inspector y runtime; ejemplo funcional GlitchSpriteAnomaly con shader y disparo al 3.er cliente; integración en Main.tscn y panel debug F3; y guía técnica en docs/anomalies_workflow.md.
- [TASK-012] Condicion de victoria al sobrevivir 3 dias (HU-06, Issue #9). Configuración de 3 días canónicos por partida en GameManager y NPCSpawner, detención de flujo de eventos, emisión de señal game_won con estadísticas completas, pantalla de victoria con mensaje de escape ("Has ganado") y opciones de reinicio o volver al menú principal.
- [TASK-011] Sistema de armado e interaccion de completos al estilo cocina interactiva 3D (HU-11, Issue #14). Estaciones 3D en el estante (pan, vienesa, palta, mayo, ketchup, basurero) sin ventanas 2D. Base obligatoria (pan + vienesa), ensamblado modular reactivo visual, recetas chilenas en NPCs y adaptacion del evento del Ladron.
- [TASK-007] Bucle de dias y rondas basado en clientes (HU-01, Issue #3). Contador de clientes por jornada, bloqueo de spawn al cupo, pantalla de fin de jornada, y avance a la siguiente jornada.
- [TASK-010] Interaccion de persiana con NPCs, evasion de muerte por disparo (cancelar ira/muerte al cerrar persiana) y huida del Ladron.
- [TASK-009] Plantilla modular de eventos estáticos (StaticNPCEvent), escena RobberNPC y trigger configurable en Inspector.
- [TASK-004] Contadores de depuracion en UI (NPCs aparecidos y atendidos, toggle Inspector y F3).
- [TASK-003] Sistema modular de eventos y anomalias de NPCs (NPCEventManager y FastNPC).
- [TASK-002] Movimiento de jugador: Stair stepping y mecanica de sprint.
- [TASK-001] Correccion de colas y desatasco de navegacion de salida de NPCs.
- [TASK-000] Prototipo base retail (Player, Items, NPC, GameManager, UI).
