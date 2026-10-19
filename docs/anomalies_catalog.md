#  Catálogo y Guía Completa de Anomalías

Este documento describe todas las anomalías implementadas en el juego, su comportamiento en el juego, condiciones de disparo, métodos de detección, mecánicas de defensa/resolución y consecuencias si son ignoradas o mal gestionadas.

---

## 📋 Resumen del Catálogo

| ID | Nombre | Tipo / Ubicación | Detección Clave | Peligrosidad / Penalización | Método de Resolución |
|---|---|---|---|---|---|
| `glitch_sprite` | **Distorsión Espectral** | Ambiental / Pantalla (HUD) | Efecto visual obvio en pantalla, niebla roja y parpadeo de luces | Tensión ambiental y desorientación visual | Se disipa sola (8s) o bajando la persiana |
| `aware` | **El Consciente** | HUD / Monitor de Seguridad | Solo aparece al mirar el monitor de seguridad (`[E]`) | Presencia psicológica inquietante | Dejar de mirar el monitor |
| `cctv_lurker` | **Silueta Acechando** | Cámara CCTV (CAM 01 / CAM 02) | Mirar la cámara de seguridad asignada | Se acerca progresivamente hacia la cámara al cambiar de canal | Desaparece sola tras 35s |
| `cctv_intruder` | **Intruso en el Perímetro** | Cámara CCTV (CAM 01 / CAM 02) | Mirar la cámara de seguridad asignada | Merodea el perímetro; si lo miras >2s se detiene y te mira fijamente | Desaparece solo tras 35s |
| `cctv_power_failure` | **Fallo Eléctrico** | Cámara CCTV / Modificador de Feed | Pérdida de señal e interferencias en un canal específico | Deja ciega una cámara con estática y cortes de "SIN SEÑAL" | Se repara solo tras 35s |
| `cctv_night_entity` | **Presencia en la Vereda** | CCTV (CAM 01 Frente) + Visión Nocturna | **Solo visible con Visión Nocturna (`[F]`)** en CAM 01 | **Robo de $4.000** si llega a la ventana | **Bajar la persiana** antes de que alcance el local |
| `cctv_patio_thief` | **Ladrón del Patio** | CCTV (CAM 02 Patio) + Mundo Real 3D | Revisar CAM 02 o escuchar el forcejeo en la puerta trasera | **Robo de $5.000** si logra entrar a la cocina | **Cerrar la puerta trasera (`[E]`)** mientras sigue afuera |
| `cctv_shadow_companion` | **El Acompañante Oculto** | CCTV (CAM 01 Frente) + Visión Nocturna + Cliente | **Solo visible con Visión Nocturna (`[F]`)** detrás de un cliente | 💀 **LETAL (2 Strikes)**: Game Over si se le atiende. Robo de $3.000 si se agota el tiempo | **¡PROHIBIDO ATENDER! Bajar la persiana** para desterrarlo |

---

## 🕹️ Detalle de Cada Anomalía

### 1. Distorsión Espectral (`glitch_sprite`)
- **Archivos**:
  - Script: [`scripts/anomalies/GlitchSpriteAnomaly.gd`](../scripts/anomalies/GlitchSpriteAnomaly.gd)
  - Escena: `scenes/anomalies/GlitchSpriteAnomaly.tscn`
  - Recurso: `resources/anomalies/glitch_sprite_anomaly.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 1.
  - Peso probabilístico: `25.0` (Tier RARE).
  - Puede ocurrir como evento aleatorio o configurarse por cliente exacto.
- **¿Qué hace?**:
  1. Oscurece la iluminación ambiental del local y reduce la luz direccional.
  2. Espesa la niebla volumétrica y tiñe la pantalla con un filtro rojo espectral y shader de aberración cromática.
  3. Muestra una etiqueta de advertencia en el HUD: `[ANOMALÍA DETECTADA: DISTORSIÓN ESPECTRAL]`.
  4. Manifiesta un sprite fantasmal flotante en el centro de la pantalla que salta y vibra de forma errática (jitter, rotación y fluctuación de opacidad).
  5. Hace parpadear las luces del local y reproduce sonidos de tensión (`SFXManager.play_tense_anger()`).
- **Resolución**:
  - Se resuelve de forma automática tras 8 segundos, restaurando la iluminación original suavemente.
  - El jugador puede forzar su resolución inmediata cerrando la persiana del mostrador.

---

### 2. El Consciente (`aware`)
- **Archivos**:
  - Script: [`scripts/anomalies/Aware.gd`](../scripts/anomalies/Aware.gd)
  - Escena: `scenes/anomalies/Aware.tscn`
  - Recurso: `resources/anomalies/aware.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 1.
  - Peso probabilístico: `10.0` (Tier RARE).
- **¿Qué hace?**:
  1. Permanece en total latencia mientras el jugador se encuentra en el mostrador o atendiendo pedidos. No hay cambios visuales en el mundo físico.
  2. En el instante exacto en que el jugador se acerca al monitor de seguridad de la pared izquierda e interactúa (`[E]`) para ver las cámaras, la anomalía "se da cuenta de que la estás mirando".
  3. Manifiesta un gran ojo rojo estilizado en el centro del HUD, con pulsaciones rítmicas de pupila, parpadeos periódicos y un sonido de advertencia espeluznante.
  4. En cuanto el jugador suelta el monitor o deja de mirar las cámaras, el ojo desaparece de inmediato.
- **Resolución**:
  - No penaliza económicamente; es una anomalía de tensión psicológica que juega con la paranoia del jugador mientras monitorea el perímetro.

---

### 3. Silueta Acechando (`cctv_lurker`)
- **Archivos**:
  - Script: [`scripts/anomalies/cctv/CCTVLurkerAnomaly.gd`](../scripts/anomalies/cctv/CCTVLurkerAnomaly.gd)
  - Escena: `scenes/anomalies/CCTVLurker.tscn`
  - Recurso: `resources/anomalies/cctv_lurker.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 1.
  - Peso probabilístico: `8.0` (Tier UNCOMMON).
  - Canales: Cualquier zona con cámara (Frente o Patio).
- **¿Qué hace?**:
  1. Instancia una silueta humanoide pálida de 1.9 metros en una zona vigilada por cámaras.
  2. Pertenece a la capa exclusiva de CCTV (capa 11): la cámara del jugador en primera persona no puede verla, únicamente se percibe a través del monitor de seguridad.
  3. Cada vez que el jugador sintoniza el canal de la cámara donde está la silueta, cambia de canal y vuelve a mirar, la figura se ha teletransportado 1.2 metros más cerca de la cámara (hasta un máximo de 3 aproximaciones), mirando fijamente al lente.
- **Resolución**:
  - Su tiempo de vida es de 35 segundos (`event_duration = 35.0`). Una vez cumplido el plazo, se desvanece en silencio sin dejar rastro.

---

### 4. Intruso en el Perímetro (`cctv_intruder`)
- **Archivos**:
  - Script: [`scripts/anomalies/cctv/CCTVIntruderAnomaly.gd`](../scripts/anomalies/cctv/CCTVIntruderAnomaly.gd)
  - Escena: `scenes/anomalies/CCTVIntruder.tscn`
  - Recurso: `resources/anomalies/cctv_intruder.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 2.
  - Peso probabilístico: `6.0` (Tier RARE).
  - Canales: Cualquier zona con cámara (Frente o Patio).
- **¿Qué hace?**:
  1. Una silueta con tonos rojizos aparece caminando de un lado a otro (patrullando un tramo de 3 metros) en el área monitoreada.
  2. Si el jugador sintoniza ese canal y mantiene la vista en la cámara durante más de 2 segundos consecutivos, el intruso interrumpe bruscamente su caminata, se detiene y gira su cuerpo hacia la cámara para devolverle la mirada al jugador.
- **Resolución**:
  - Desaparece pacíficamente al expirar su duración de 35 segundos.

---

### 5. Fallo Eléctrico (`cctv_power_failure`)
- **Archivos**:
  - Script: [`scripts/anomalies/cctv/CCTVPowerFailureAnomaly.gd`](../scripts/anomalies/cctv/CCTVPowerFailureAnomaly.gd)
  - Escena: `scenes/anomalies/CCTVPowerFailure.tscn`
  - Recurso: `resources/anomalies/cctv_power_failure.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 1.
  - Peso probabilístico: `6.0` (Tier COMMON).
- **¿Qué hace?**:
  1. Aparece una caja de fusibles en un poste en la zona vigilada, con arcos eléctricos brillantes y emisión de chispas intermitentes.
  2. Se registra en el grupo `cctv_feed_modifiers` e inyecta interferencia estática (35% base) en la transmisión de esa cámara en particular.
  3. Genera microcortes aleatorios (45% de probabilidad por segundo) donde la pantalla del monitor se vuelve completamente negra con el letrero `"SIN SEÑAL"`.
  4. Los otros canales no sufren interferencia, forzando al jugador a depender de los demás ángulos o perder visibilidad temporal de esa zona.
- **Resolución**:
  - El cortocircuito se extingue por sí solo tras 35 segundos, restaurando la nitidez de la señal de video.

---

### 6. Presencia en la Vereda (`cctv_night_entity`)
- **Archivos**:
  - Script: [`scripts/anomalies/cctv/CCTVNightEntityAnomaly.gd`](../scripts/anomalies/cctv/CCTVNightEntityAnomaly.gd)
  - Escena: `scenes/anomalies/CCTVNightEntity.tscn`
  - Recurso: `resources/anomalies/cctv_night_entity.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 1.
  - Canal: Exclusivamente CAM 01 (`frente`).
  - Peso probabilístico: `7.0` (Tier RARE).
- **¿Qué hace?**:
  1. Una entidad humanoide pálida y esbelta con cuencas oscuras empieza a caminar desde el extremo exterior de la vereda rumbo a la ventana del local (tarda 40 segundos en llegar).
  2. **Mecánica de Visión Nocturna**: No se ve en la imagen normal de la CAM 01 (solo produce una levísima interferencia del 12%). **Únicamente se revela si el jugador activa la visión nocturna pulsando `[F]` en el monitor**.
  3. Si alcanza la ventana del mostrador y la persiana está abierta:
     - Sacude la ventana, golpea el cristal violentamente y **sustrae $4.000 directamente de la caja registradora**.
- **Defensa y Resolución**:
  - **Bajar la persiana del mostrador**: Al detectar la persiana cerrada, la entidad frena en seco, retrocede de espaldas hacia la oscuridad y se desvanece sin robar dinero ni atacar.

---

### 7. Ladrón del Patio (`cctv_patio_thief`)
- **Archivos**:
  - Script: [`scripts/anomalies/cctv/CCTVPatioThiefAnomaly.gd`](../scripts/anomalies/cctv/CCTVPatioThiefAnomaly.gd)
  - Escena: `scenes/anomalies/CCTVPatioThief.tscn`
  - Recurso: `resources/anomalies/cctv_patio_thief.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 2.
  - Canal: Exclusivamente CAM 02 (`patio`).
  - Peso probabilístico: `6.0` (Tier RARE).
- **¿Qué hace?**:
  1. Un intruso vestido con sudadera oscura y gorro de lana rojo entra por el fondo del patio trasero.
  2. **Entidad Física en el Mundo**: A diferencia de otras anomalías de CCTV, este ladrón existe en la capa del mundo real: se le puede ver mirando por la ventana trasera o acudiendo a la puerta.
  3. Fases del ataque:
     - **Aproximación**: Cruza el patio hacia la puerta trasera.
     - **Forcejeo (4 segundos)**: Llega a la puerta de servicio y empieza a forzar la cerradura (hace ruidos metálicos y la puerta se sacude visiblemente).
     - **Puerta Abierta y Espera (6 segundos)**: La puerta se abre de par en par. El ladrón permanece afuera vigilando antes de dar el paso.
     - **Infiltración y Robo**: Si nadie lo detiene, entra a la cocina, llega hasta la caja y **roba $5.000**, escapando corriendo a gran velocidad (`flee_speed = 3.8 m/s`).
- **Defensa y Resolución**:
  - Al escuchar el forcejeo o verlo en la CAM 02, el jugador debe correr a la puerta trasera y **cerrar la puerta (`[E]`)** mientras el ladrón sigue afuera. Al encontrar la puerta cerrada, el ladrón aborta la misión y escapa inmediatamente sin llevarse dinero.

---

### 8. El Acompañante Oculto (`cctv_shadow_companion`)
- **Archivos**:
  - Script: [`scripts/anomalies/cctv/CCTVShadowCompanionAnomaly.gd`](../scripts/anomalies/cctv/CCTVShadowCompanionAnomaly.gd)
  - Escena: `scenes/anomalies/CCTVShadowCompanion.tscn`
  - Recurso: `resources/anomalies/cctv_shadow_companion.tres`
- **Condiciones de Activación**:
  - Días: Desde el Día 1.
  - Canal: CAM 01 (`frente`).
  - Peso probabilístico: `50.0` (Tier RARE).
- **¿Qué hace?**:
  1. Llega al mostrador un cliente aparentemente inofensivo y normal pidiendo un pedido común (empanadas, completo, etc.).
  2. En persona, el cliente no muestra nada fuera de lo común. Sin embargo, al revisar la cámara exterior (CAM 01) con la **visión nocturna activada `[F]`**, se revela un **doppelgänger oscuro** (una copia exacta con el mismo cuerpo, textura y ropa) parado a escasos centímetros detrás de él, con ojos blancos penetrantes clavados en la cámara.
  3. **Regla Fundamental de Juego**: **¡LAS ANOMALÍAS NUNCA SE DEBEN ATENDER!**
  4. Consecuencias si se le atiende (entrega de cualquier comida o ítem):
     - **Primer Strike (Advertencia Siniestra)**: La cámara del jugador sufre un fuerte temblor, se reproducen acordes de tensión y furia (`play_alien_suspense`), las paredes de la casa se tiñen de un color rojo burdeo corrupto (`apply_wall_corruption`), y el cliente ríe con voz distorsionada advirtiendo: *"La casa se corrompe... ¡Al próximo error no sobrevivirás!"*. La anomalía se retira provisionalmente.
     - **Segundo Strike (Ataque Letal)**: Si el jugador comete un segundo error atendiendo a una anomalía, el doppelgänger ejecuta un jumpscare a máxima velocidad sobre el jugador, suena un disparo fatal, el jugador colapsa al suelo y se desencadena un **Game Over definitivo**.
  5. Si el jugador se queda paralizado y no hace nada hasta que se agota el tiempo de paciencia del cliente, la presencia mete la mano por la ventanilla y **sustrae $3.000** de la caja.
- **Defensa y Resolución**:
  - **Bajar la persiana del mostrador**: Al detectar la anomalía en las cámaras, el jugador debe bajar inmediatamente la persiana en la cara del cliente. La persiana emite un estruendo metálico (`*¡CLANG!*`), el doppelgänger se desintegra en la oscuridad y el cliente original se marcha pacíficamente, salvando la vida del jugador y manteniendo intacta la cordura y el negocio.

---

## 🛠️ Herramientas de Depuración y Pruebas Rápidas

Para probar cualquier anomalía en tiempo de ejecución sin esperar a que salga por probabilidad:
1. En Godot, con el juego corriendo, ir al árbol de escenas **Remote**.
2. Seleccionar el nodo `root/Main/AnomaliesManagement`.
3. En el Inspector:
   - En el campo **`debug_force_anomaly`**, escribir el ID de la anomalía deseada (ej. `cctv_shadow_companion`, `cctv_patio_thief`, `cctv_night_entity`, `glitch_sprite`, `aware`, `cctv_lurker`, `cctv_intruder`, `cctv_power_failure`).
   - Activar la casilla **`debug_trigger_now`** para forzar su aparición de inmediato.
