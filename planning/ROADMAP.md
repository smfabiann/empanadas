# Roadmap del Proyecto - Empanadas (Retail Retro 3D)

## 🎯 Visión General
Prototipo y juego 3D con estética retro PSX/low-poly desarrollado en Godot 4.x. El jugador atiende un local de comida rápida chilena (empanadas, sopaipillas, completos, bebidas) desde una perspectiva fija en primera persona tras el mostrador, atendiendo a clientes que llegan con pedidos aleatorios.

---

## 🗺️ Fases del Desarrollo

### ✅ Fase 1: Prototipo Core Retail (Completada)
- [x] Estructura base de datos para ítems (`ItemData.gd`, recursos `.tres`).
- [x] Lógica base de objetos interactuables (`Interactable.gd`, físicas capa 2).
- [x] Controlador del jugador en primera persona (`Player.gd`, RayCast3D, HoldPoint).
- [x] Comportamiento de NPCs (`NPC.gd`, Spawner, máquina de estados).
- [x] Ciclo principal de juego (`GameManager.gd` con vidas, puntaje y Game Over).
- [x] HUD básico (`UI.gd`, puntaje, vidas, retícula).

---

### 🚀 Fase 2: Menús, Navegación y Experiencia de Usuario (En Curso)
- [-] **Menú Principal Pulido y Funcional:** Interfaz visual atractiva, controles, high score, arranque limpio.
- [ ] **Menú de Pausa y Opciones:** Ajuste de volumen básico y retorno seguro al menú.
- [ ] **Pantalla de Game Over Mejorada:** Estadísticas de la partida y botón de revancha rápida.

---

### 🎨 Fase 3: Audio, Feedback y Atmósfera Retro
- [ ] **Efectos de Sonido (SFX):** Recoger/soltar ítems, entrega correcta (chime), entrega fallida (buzzer), pasos de NPC.
- [ ] **Música de Fondo (BGM):** Pista retro / lo-fi en bucle.
- [ ] **Efectos Visuales (VFX):** Partículas de satisfacción al entregar correctamente, popups de texto flotante.

---

### 🍔 Fase 4: Variedad de Pedidos y Mecánicas de Cocina
- [ ] **Nuevos Ítems y Recetas:** Incorporación de completos dinámicos o salsas.
- [ ] **Paciencia / Temporizador de NPC:** Barra de paciencia antes de que el cliente se enoje y se vaya.
- [ ] **Dificultad Progresiva:** NPCs llegan más rápido y con pedidos más complejos a mayor puntuación.

---

### 💾 Fase 5: Economía, Progresión y Ajustes
- [ ] Sistema de propinas y dinero acumulable.
- [ ] Mejoras del mostrador / tienda.
- [ ] Guardado persistente de récords y configuraciones.
