# Roadmap del Proyecto - Empanadas (Horror Retail 3D)

## Vision General
Juego 3D retro con atmosfera de terror psicologico y anomalias. Atencion nocturna de un local de comida rapida chilena en primera persona tras el mostrador.

## Fases

### Fase 1: Prototipo Core Retail (Completada)
- Controlador de jugador 1ra persona, salto, sprint y raycast interactivo.
- Items interactuables (empanada, sopaipilla, completo, bebida).
- Spawner de NPCs con maquina de estados y barra de paciencia.
- Autoloads GameManager y SFXManager.
- UI minimalista y panel de depuracion (F3).

### Fase 2: Sistema de Anomalias y Eventos (En Curso)
- Arquitectura desacoplada de eventos (NPCEvent y NPCEventManager).
- Arquitectura base y gestor central de anomalías configurables (`anomaliesManagement` / `AnomalyBase` / `AnomalyData`, HU-ANOM-13).
- Anomalía implementada: GlitchSpriteAnomaly (manifestación aberrante con shader y animación, disparo al 3.er cliente).
- Evento implementado: FastNPC (cliente rapido con paciencia reducida) y RobberNPC (minijuego de atraco armado).
- Proximos eventos y anomalías:
  - Cliente distorsionado o con glitch visual/audio.
  - Cliente de proporciones alteradas o comportamiento bizarro.
  - Cliente silencioso que no pide items o pide items imposibles.
  - Eventos ambientales de iluminacion y sonido en el local.

### Fase 3: Audio y Atmosfera
- Efectos de sonido (recoger, soltar, pasos, timbre pedido, validacion).
- Musica ambiental nocturna / tension retro lo-fi.
- Eventos auditivos de baja frecuencia y estatica.

### Fase 4: Bucle de Terror y Progresion
- Condiciones de tension o fallo por anomalias desatendidas.
- Progresion de noches / turnos laborales (Noche 1, Noche 2, etc.).
- Eventos ambientales en la calle y fuera de la ventana.
