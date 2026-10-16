# Roadmap y Backlog de Tareas

## Visión General
Juego 3D retro con atmósfera de terror psicológico y anomalías. La ciudad se está poniendo rara y el protagonista quiere irse: trabaja 3 noches en el local de completos de su tío para juntar la plata del pasaje ($50.000) antes de que salga el bus del amanecer. Atiende en primera persona tras el mostrador, arma completos (incluidos los mojados de Talca), vigila las cámaras y se defiende de ladrones y estafadores.

---

## Backlog Activo (Próximas Tareas Prioritarias)

- **[RUB-01] Entrega Alpha**: exportar el ejecutable (preset Windows), fijar resolución base y probarlo en otro PC (ver `RUBRICA_ALPHA.md`).
- **[RUB-02] GDD corto**: concepto, meta de 3 noches, mecánicas, eventos, controles, arte y audio.
- **[RUB-03] Arte y audio reales**: reemplazar parte de la geometría CSG y del audio procedural por assets acreditados.

- **[TASK-005] Nueva Anomalía: Cliente silencioso / estático**:
  - Cliente que llega al mostrador sin realizar pedido o solicitando ítems imposibles, aumentando la tensión psicológica.
- **[TASK-006] Implementación de SFX Faltantes**:
  - Efectos de sonido ambientales y de interacción: recoger/soltar ítem, timbre de pedido, pasos del jugador.
- **[TASK-008] Efectos Ambientales de Terror**:
  - Parpadeo de luces en mostrador y calle tras la aparición de anomalías o eventos de tensión.

---

## Fases del Proyecto

### Fase 1: Prototipo Core Retail ( Completada)
- Controlador de jugador FPS con sprint, salto y raycast interactivo.
- Sistema de cocina interactiva 3D de completos (pan, vienesa, palta, mayo, ketchup, basurero).
- IA de clientes con máquina de estados, pedidos y barra de paciencia.
- Bucle de jornadas laborales (3 días canónicos), fin de jornada y condición de victoria (HU-06).
- Autoloads `GameManager` y `SFXManager`, menús y HUD debug (F3).

### Fase 2: Sistema de Anomalías y Eventos ( En Curso)
- Arquitectura desacoplada de eventos de NPCs (`NPCEventManager`, `BigHeadEvent`, `fastNPC`).
- Evento estático del Ladrón (`RobberNPC`) con mecánica defensiva de persiana.
- Gestor central de anomalías modulares (`AnomaliesManager` / `AnomalyBase` / `AnomalyData`, HU-ANOM-13).
- Ejemplo práctico implementado: `GlitchSpriteAnomaly` al 3.er cliente.
- Monitor de seguridad con canales CAM 01 (frente) y CAM 02 (patio trasero), HUD de grabación y filtro CCTV (HU-09).
- Eventos visibles solo por CCTV: silueta acechando, intruso en el perímetro y fallo eléctrico (HU-10, Issue #13).
- *Pendiente:* Nuevas anomalías visuales y auditivas (TASK-005, eventos de luces TASK-008).

### Fase 2.5: Juego Completo de Alpha ( Completada)
- Narrativa de 3 noches para juntar la plata del pasaje y escapar, con intro y "Cómo jugar" (HU-05).
- Economía: pagos, propinas, ahorros en el HUD, alcancía y calendario en el local; final de escape o derrota según la plata.
- Olla y completos mojados estilo Talca, con el evento del Talquino (HU-14).
- Evento del Estafador del chip de perro (HU-15) y del Repartidor de Rappi (HU-16).
- Barrio nocturno con cuadras, letrero de neón, paradero, auto, árboles y postes (HU-08), más ambiente sonoro procedural.

### Fase 3: Audio y Atmósfera (⏳ En curso)
- Ambiente nocturno procedural en loop (hecho); faltan sonidos lo-fi retro y estática.
- SFX de interacción física (TASK-006).
- Eventos de audio posicional y frecuencias perturbadoras.

### Fase 4: Bucle de Terror y Progresión Avanzada (⏳ Planificada)
- Penalizaciones y consecuencias por ignorar anomalías.
- Eventos dinámicos en el exterior y calle fuera de la ventana.

---

> Para el detalle histórico completo de cambios y tareas ya implementadas, consultar [`changelog.md`](../changelog.md).
