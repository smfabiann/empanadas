# Mapa de árbol del repositorio

Raíz analizada: `/home/runner/work/empanadas/empanadas`

## Árbol funcional (resumen)

```text
/home/runner/work/empanadas/empanadas
├── project.godot                      # Configuración principal Godot (escena inicial, autoloads, input, capas)
├── changelog.md                       # Historial narrativo de cambios
├── icon.svg / icon.svg.import         # Icono del proyecto y metadato de importación
├── resources/
│   └── items/
│       ├── bebida.tres                # ItemData de bebida
│       ├── completo.tres              # ItemData de completo
│       ├── empanada.tres              # ItemData de empanada
│       └── sopaipilla.tres            # ItemData de sopaipilla
├── scenes/
│   ├── Main.tscn                      # Escena de juego principal
│   ├── Player.tscn                    # Jugador FPS
│   ├── NPC.tscn                       # Cliente base
│   ├── RobberNPC.tscn                 # NPC especial ladrón
│   ├── UI.tscn                        # HUD + game over + fin de jornada + pausa
│   ├── items/
│   │   ├── Completo.tscn              # Ítem completo modular
│   │   ├── Drink.tscn                 # Ítem bebida
│   │   ├── Empanada.tscn              # Ítem empanada
│   │   ├── Sopaipilla.tscn            # Ítem sopaipilla
│   │   └── Gun.tscn                   # Modelo simple de arma del ladrón
│   ├── map/
│   │   ├── shop.tscn                  # Geometría del local + persiana + puerta + botón interactivo
│   │   ├── shelf.tscn                 # Malla de repisa
│   │   ├── KitchenStations.tscn       # Estaciones de pan/ingredientes/basurero
│   │   └── IngredientStation.tscn     # Escena base de estación individual
│   └── ui/
│       ├── MainMenu.tscn              # Menú principal
│       ├── PauseMenu.tscn             # Menú de pausa
│       └── FloatingText.tscn          # Texto flotante reutilizable
├── scripts/
│   ├── GameManager.gd                 # Estado global del juego (autoload)
│   ├── SFXManager.gd                  # Audio procedural (autoload)
│   ├── Player.gd                      # Movimiento/interacción del jugador
│   ├── NPC.gd                         # Lógica del cliente base
│   ├── NPCSpawner.gd                  # Spawn de clientes + integración de eventos
│   ├── IngredientStation.gd           # Lógica de estaciones de cocina
│   ├── Interactable.gd                # Base de ítems recogibles
│   ├── CompletoItem.gd                # Completo modular (ingredientes/validación)
│   ├── ItemData.gd                    # Recurso de datos de ítem
│   ├── ItemSpawner.gd                 # Spawner de ítems (actualmente no instanciado en Main)
│   ├── events/
│   │   ├── NPCEvent.gd                # Clase base de evento
│   │   ├── NPCEventManager.gd         # Catálogo/selección de eventos
│   │   ├── BigHeadEvent.gd            # Evento aleatorio cabeza gigante
│   │   ├── fastNPC.gd                 # Evento aleatorio cliente acelerado
│   │   ├── README.md                  # Guía de sistema de eventos
│   │   └── static/
│   │       ├── StaticNPCEvent.gd      # Base de evento estático
│   │       ├── RobberEvent.gd         # Trigger estático del ladrón
│   │       └── RobberNPC.gd           # Comportamiento del ladrón
│   └── ui/
│       ├── UI.gd                      # Control de HUD/fin de jornada/game over
│       ├── MainMenu.gd                # Flujo de menú principal
│       ├── PauseMenu.gd               # Flujo de pausa
│       └── FloatingText.gd            # Animación de texto flotante
└── planning/                          # Documentación técnica/proyecto
```

## Qué se omite y por qué

- `.git/`: metadatos internos de Git, no parte del juego.
- `*.gd.uid`: metadatos generados por Godot para scripts.
- Archivos ignorados por `.gitignore` (`.godot/`, `export/`, `android/`, `.vscode/`, etc.): cachés/config local/generados.
