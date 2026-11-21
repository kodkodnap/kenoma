# Arquitectura — Kenoma

> Documento vivo. Explica cómo se conectan los sistemas, no cómo se juega. El diseño está en
> [`DESIGN.md`](DESIGN.md); el catálogo del original, en [`ORIGINAL_FEATURES.md`](ORIGINAL_FEATURES.md).

## 1. Principios

1. **Lógica fuera de escenas.** `scripts/core/` no conoce nodos, cámaras ni UI; se prueba con `smoke.gd`.
2. **Datos fuera de scripts.** Máquinas, señales, ítems, entidades, eventos y balance son Resources.
3. **Señales, no referencias cruzadas.** Un sistema emite; otro escucha. Quitar un sistema no debe romper
   el resto.
4. **Una responsabilidad por clase.** Nada de scripts de 1.000 líneas.
5. **Estado serializable.** El guardado reconstruye desde datos, nunca desde el árbol de escena.
6. **Presupuesto medido.** Cada hito actualiza `perf_overlay` y la escena de debug.

## 2. Estructura de carpetas

```
godot/
  project.godot
  scenes/
    main.tscn
    player/player.tscn
    world/                  # nivel, base, bosque, POIs
    machines/               # máquinas y paneles
    ui/                     # HUD, pantallas, SubViewports
    entities/               # entidades y spawners
    debug/                  # overlay y escena de rendimiento
  scripts/
    core/                   # lógica pura: balance, estado, energía, señales, eventos
    player/                 # movimiento, cámara, interacción, stats
    interaction/            # Interactable, Grabbable, Container
    machines/               # Machine, paneles, servidores, transformadores
    ui/                     # HUD y pantallas
    world/                  # level, puertas, spawns
    entities/               # IA base y comportamientos
    audio/                  # buses y síntesis
    debug/                  # overlay
  data/
    balance.tres
    signals/                # SignalDef
    machines/               # MachineDef
    items/                  # ItemDef
    entities/               # EntityDef
    events/                 # EventDef
    store/                  # StoreItemDef, UpgradeDef
    locations/              # LocationDef
  assets/
    models/                 # GLB
    audio/                  # OGG/WAV originales
    textures/               # PNG generados o propios
  docs/
    ORIGINAL_FEATURES.md
    DESIGN.md
    ARCHITECTURE.md
    TASKS.md
    IDEAS.md
    ASSETS.md
  tests/
    smoke.gd
```

## 3. Capas y dependencias

```
UI / escenas
   ↓ señales
Player / World / Machines / Entities
   ↓ llamadas puras
Core (GameState, SignalSystem, PowerSystem, EventDirector, Economy, SaveSystem)
   ↑
Data (Resources)
```

- `core` no importa `scenes/` ni `ui/`.
- `ui` no modifica el estado directamente; llama a la API del sistema y se refresca por señales.
- `world` y `machines` leen `data/` y escriben en `GameState` a través de sus sistemas.
- `player` solo conoce interacción, movimiento y stats; no conoce la economía.

## 4. Clases objetivo

### 4.1 Núcleo

| Clase | Responsabilidad | Estado |
|---|---|---|
| `GameBalance` | Valores globales: velocidades, día, stamina, energía, dificultad. | hecho (hito 1) |
| `GameState` | Estado serializable de la partida. | pendiente |
| `GameClock` | Día, hora, velocidad, dormir, eventos de medianoche/06:00. | hecho (hito 6) |
| `SignalDef` | Datos de señal: condición, rumbo, perillas, calidad, precio, imagen y audio. | hecho (hito 5) |
| `SignalSystem` | Cadena Coordinates → Download → Playback → Processing → disco y venta; `decode_tuning`/`decode_stability()` alimentan el CRT. | hecho (hito 5.5-D) |
| `PowerSystem` | Transformadores, breakers, consumo, estabilidad, apagón y rearme. | hecho (hito 4) |
| `ServerSystem` | 54 servidores, estados, reparación, mejoras, hashcodes. | pendiente |
| `Economy` | Puntos, tienda, pedidos, multas y bonus semanal. | hecho (hito 6) |
| `EventDirector` | Eventos por día, peso, cooldown y flags. | base hecha (hito 2) |
| `SaveSystem` | Serialización versionada y migraciones. | pendiente |
| `DailyTask` | Tarea del día: señales (hashcodes/cintas en hitos 8 y 11), recompensa y multa. | hecho (hito 6) |
| `DailyCycle` | Director puro: reloj + tarea + economía + dron y guardado provisional. | hecho (hito 6) |
| `Inventory` | Volumen, contenedores, equipo, apilar. | hecho (hito 2) |

### 4.2 Jugador

| Clase | Responsabilidad | Estado |
|---|---|---|
| `Player` | Movimiento, cámara, linterna, raycast, interacción, stamina y agacharse. | hecho (hito 1) |
| `PlayerStats` | Hambre, stamina, salud, sueño, paranoia, sangrado. | pendiente (hito 9; por ahora `Player` expone `stamina` y `battery`) |
| `Flashlight` | Batería, recarga, haces, parpadeo. | hecho (hito 1: toggle y drenaje; recarga en hito 11) |
| `InteractionRay` | Foco, hold, prompts. | prototipo |

### 4.3 Interacción y máquinas

| Clase | Responsabilidad | Estado |
|---|---|---|
| `Interactable` | Área con prompt, hold, enabled, foco. | hecho (hito 2) |
| `Grabbable` | Objeto físico agarrable, lanzable, colocable. | hecho (hito 2) |
| `ItemContainer` | Inventario de contenedor. | hecho (hito 2) |
| `MachineDef` | Datos de máquina: nombre, estados, calor, consumo. | prototipo |
| `Machine` | Estados OFF/ON/OVERHEATED/NO_POWER, calor, modo. | prototipo |
| `PowerConsumer` | Consumo y estado de energía; lo enchufa `PowerSystem`. | hecho (hito 4) |
| `ScreenPanel` | Base de paneles con SubViewport y controles. | hecho (hito 2) |
| `RotaryKnob` / `ToggleSwitch` / `Lever` | Controles físicos reutilizables con placa, escala, guarda y señal propia. | hecho (hito 5.5-A) |
| `DownloadsPanel` | Consola física de descargas: chasis, cubierta, CRT, vúmetro, 6 perillas, detector y palanca. | hecho (hito 5.5-A) |
| `CrtScreen` | `Control` que dibuja rejilla, traza de fósforo, barrido y viñeta del CRT. | hecho (hito 5.5-A) |
| `ProcessingPanel` | Consola física de Procesado: GLB horneado, CRT vivo, perilla FASE y pulsador CONFIRMAR invisibles, LED LOCK. | hecho (hito 5.5-D) |
| `MachineMaterials` | Materiales y texturas procedurales: pintura, acero, baquelita, vidrio, escalas. | hecho (hito 5.5-A) |
| `MachineMesh` | Primitivas, tubos, tornillos y rejillas; lotes por material con `begin_batch`. | hecho (hito 5.5-A) |
| `MachineBatch` | Fusiona geometría estática por material y la vuelca como un `MeshInstance3D`. | hecho (hito 5.5-A) |
| `PowerTransformer` | Estabilidad, daño y reparación manual con mantener E. | hecho (hito 4) |
| `BreakerPanel` | Cinco breakers, botón rojo de dos pulsaciones y avisos. | hecho (hito 4) |
| `Server` | Estado, reparación, mejoras. | pendiente |
| `SatelliteDish` | Precisión, calibración, consola, hashcode. | pendiente |
| `RadarTower` | Fusibles, salud, ping. | pendiente |
| `MainComputer` | Nueve pestañas. | pendiente |
| `SignalStation` | Cuatro paneles y módulos. | pendiente |

### 4.4 Mundo, entidades y UI

| Clase | Responsabilidad | Estado |
|---|---|---|
| `Level` | Geometría, zonas, spawns, POIs. | prototipo |
| `BaseLayout` | Plano puro de Alpha Root Base: 22 salas, puertas, plataformas, sin escena. | hecho (hito 3) |
| `BaseBuilder` | Construye la base: MultiMesh por material, colisiones en un `StaticBody3D`, luces y props. | hecho (hito 3) |
| `Door` | Puertas, cerraduras, breaker de Utilities. | pendiente |
| `WeatherSystem` | Lluvia, niebla, tormenta, nieve, rayos. | pendiente |
| `EntityDef` | Datos de entidad. | hecho (hito 2) |
| `Entity` | Base activar/desactivar; IA en hito 10. | hecho (hito 2) |
| `EntityDirector` | Spawns por evento, hora, stat o radar. | pendiente |
| `Hud` | Vitales (stamina/linterna), foco, hold, estado de máquina y red; reloj en hito 6. | hecho (hito 4) |
| `SignalConsole` | Terminal con una pestaña (Reproducción); los paneles 1, 2 y 4 son máquinas físicas. | hecho (hito 5.5-D) |
| `SignalArt` / `SignalAudio` | Imagen 64×64 generada y audio sintetizado por señal. | hecho (hito 5) |
| `ComputerScreen` | SubViewport y UI de terminal. | pendiente |
| `PerfOverlay` | FPS, draw calls, primitivas, memoria. | hecho |

## 5. Señales principales

| Emisor | Señal | Consumidor |
|---|---|---|
| `Player` | `focus_changed(interactable)` | HUD |
| `Player` | `hold_changed(progress)` | HUD |
| `Interactable` | `activated(source)` | Máquina / puerta / panel |
| `Machine` | `state_changed(state)` | HUD, panel, audio |
| `Machine` | `heat_changed(value)` | Panel, audio |
| `PowerSystem` | `power_changed(on)` | Máquinas, luces, puertas |
| `PowerSystem` | `circuit_changed(circuit, powered)` | Consumidores, HUD |
| `PowerSystem` | `stability_changed(value)` | HUD, transformador |
| `PowerSystem` | `blackout_started` / `power_restored` | HUD, eventos |
| `PowerSystem` | `warning_changed(text)` | HUD, breaker |
| `SignalSystem` | `download_progress(value)` | Consola |
| `SignalSystem` | `download_completed(copy)` | Consola |
| `SignalSystem` | `playback_changed(playing)` | Consola, audio |
| `SignalSystem` | `credits_changed(value)` | Consola |
| `GameClock` | `midnight_reached(day)` / `drone_hour_reached(day)` | DailyCycle |
| `DailyCycle` | `task_ready` / `task_delivered` / `task_missed` | Terminal |
| `DailyCycle` | `drone_arrived(gifts)` | Terminal, jugador |
| `RotaryKnob` | `value_changed(value)` | DownloadsPanel |
| `ToggleSwitch` | `toggled(on)` | DownloadsPanel |
| `Lever` | `pulled(on)` | DownloadsPanel |
| `GameClock` | `day_changed(day)` | Tareas, eventos, guardado |
| `GameClock` | `hour_changed(hour)` | Luces, eventos, dron |
| `SignalSystem` | `signal_found(def)` | Database, tareas |
| `SignalSystem` | `download_completed(def)` | DB, eventos |
| `ServerSystem` | `server_state_changed(id, state)` | Panel, HUD |
| `EventDirector` | `event_started(id)` | UI, audio, mundo |
| `EventDirector` | `event_finished(id)` | UI, guardado |
| `Inventory` | `changed()` | HUD, paneles |
| `Economy` | `points_changed(value)` | HUD, tienda |

Regla: una señal no transporta nodos si se puede transportar un id o un dato serializable.

## 6. Datos

### 6.1 `GameBalance`

Valores globales, todos exportados:

- Movimiento: `walk_speed 4.0`, `sprint_speed 8.0`, `crouch_speed 1.5`, aceleración, gravedad, salto.
- Stamina: drenaje, recuperación, coste de escalar, umbral 15, máximo al dormir 80.
- Hambre: drenaje, umbrales 20/15/0, putrefacción, tolerancia.
- Salud: daño, sangrado, regeneración, cáncer.
- Linterna: drenaje, recarga, energía.
- Tiempo: duración del día por dificultad, horas de correo/dron.
- Energía: capacidad, estabilidad, consumo por componente, tiempo de reinicio.
- Procesado: `decode_stability_threshold 0.78`, `decode_sensitivity 2.5`.
- Dificultad: multiplicadores de tarea, minijuegos y eventos.

### 6.2 Recursos

| Recurso | Campos mínimos |
|---|---|
| `SignalDef` | id, nombre, tipo, calidad, nivel, precio_base, audio, imagen, evento, flags |
| `MachineDef` | id, nombre, estados, calor, consumo, modos, piezas |
| `ItemDef` | id, nombre, categoría, precio, volumen, modelo, flags, receta |
| `EntityDef` | id, nombre, categoría, IA, velocidad, daño, spawn, radar, miedo |
| `EventDef` | id, nombre, condiciones, peso, cooldown, duración, acciones |
| `StoreItemDef` | id, precio, categoría, stock, desbloqueo |
| `UpgradeDef` | id, categoría, niveles, precio, efecto |
| `LocationDef` | id, posición, radio, POI, spawns, música/ambiente |

### 6.3 Guardado

`GameState` contiene:

```
version, seed, mode, difficulty, day, hour, minutes
player: {position, rotation, stats, inventory, flashlight}
base: {power, breakers, transformers, servers, doors, machines}
signals: {discovered, downloaded, processed, sold, database}
tasks: {daily, completed, reward, deadline}
economy: {points, purchases, upgrades}
events: {flags, active, cooldowns}
decisions: {id: option}
```

- `SAVE_VERSION` se sube con cambios incompatibles.
- `deserialize` rellena defaults; nunca falla por un campo ausente.
- No se guardan nodos, texturas ni referencias a escena.

## 7. Capas de colisión

| Capa | Nombre | Uso |
|---:|---|---|
| 1 | world | Suelo, paredes, props estáticos |
| 2 | interactable | Áreas de interacción |
| 3 | item | Objetos agarrables |
| 4 | player | Cápsula del jugador |
| 5 | entity | Entidades |
| 6 | vehicle | ATV |
| 7 | trigger | Zonas de evento, POIs |
| 8 | camera_block | Oclusión de cámaras |

El raycast de interacción usa la máscara 2; el de agarre, 3; el de disparo/uso, 1|2|3|5.

## 8. UI y SubViewports

- Cada pantalla de computadora es una escena con `SubViewport` y su propio `Control`.
- La textura del `SubViewport` se aplica a la pantalla 3D; el jugador puede acercarse y hacer clic.
- La UI no pausa el mundo; el jugador sigue expuesto a eventos.
- El HUD solo presenta: no calcula reglas.
- Las pantallas se refrescan por señales, no cada frame.

## 9. Rendimiento

| Presupuesto | Límite |
|---|---|
| Draw calls | < 250 |
| Triángulos visibles | < 150k |
| Props pequeños | < 2k |
| Props medianos | < 8k |
| Máquinas | < 15k |
| Luces con sombra | ≤ 4 |
| Cuerpos físicos activos | ≤ 64 |

Técnicas: MultiMesh para árboles/arbustos, LOD, occlusion culling, LightmapGI, luces horneadas,
`VisibleOnScreenNotifier3D`, carga por distancia, pooling de partículas y objetos.

Medido (hito 3): 11.7k triángulos / 78 draw calls con la Alpha Root Base completa.
Medido (2026-11-01, consola de Descargas): 30.1k primitivas / 205 draw calls con jugador, base y
consola en pantalla. La consola aporta 102 mallas; el batido estático por material deja 24. Las
perillas, la aguja del vúmetro y la palanca conservan sus nodos porque se mueven.
Medido (2026-11-21, consola de Procesado): 12 mallas / ~2.960 tris + CRT 460 tris; el GLB se fusiona
por material para no añadir más de ~12 draws, con el escenario por debajo de 250.

Regla: la geometría fija de una máquina se construye dentro de `MachineMesh.begin_batch(parent)` y
`end_batch(parent)`. Las piezas que animan un pivote no entran en el lote.

## 10. Verificación

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

El smoke debe cubrir, como mínimo:

- Arranque de `main.tscn` y ausencia de errores de runtime.
- Jugador, cámara, linterna, movimiento y stamina.
- Interacción, hold, foco y prompts.
- Máquina: encendido, sobrecalentamiento, reinicio, modos.
- Energía: consumo, apagón, breaker.
- Señal: coordenadas, descarga, procesado, venta.
- Tarea diaria, dron y guardado.
- Entidades y eventos críticos.
- Presupuesto de escena.

Cada hito añade sus comprobaciones al smoke antes de implementar (TDD).

## 11. Estado actual del código

| Sistema | Estado | Nota |
|---|---|---|
| Proyecto Godot | hecho | 4.7.2, Forward+, 1280×720 |
| Jugador | hecho | 4/8/1,5 m/s; stamina, agacharse, salto, colisión y agarre; 85 checks |
| Linterna | hecho | Toggle F y drenaje de batería; recarga en hito 11 |
| Interactable | hecho | Área, prompt, hold, foco; capa 2 |
| Grabbable | hecho | Física, rotación, soltar y lanzar; capa 3 |
| Inventory / ItemContainer | hecho | Volumen, rechazo, contenedor |
| ItemDef | hecho | `data/items/test_item.tres` |
| Machine / TestMachine | prototipo | OFF/ON/OVERHEATED/NO_POWER; se reutiliza la base |
| ScreenPanel | hecho | Overlay con SubViewport; pantallas 3D en hito 5 |
| Entity / EventDirector | base | Sin IA ni eventos reales; hitos 10/13 |
| PowerSystem | hecho | 3 × 1200 W, 5 circuitos, estabilidad, apagón y rearme; PowerGrid eliminado |
| Alpha Root Base | hecho | 22 salas + props; 11.7k tris / 78 draws; recorridos y rampas verificados |
| HUD | hecho | Stamina, batería, foco, hold, inventario, estado y red |
| PerfOverlay | hecho | F3 |
| SignalSystem / SignalConsole | hecho | 8 señales, catálogo JSON, cadena y venta; terminal reducida a Reproducción |
| DailyCycle / CycleConsole | hecho | 75 min/día, tarea, tienda, dron, multa y bonus; snapshot en memoria |
| Estación física (fases A, B y D) | hecho | Descargas, Coordinates y Procesado como consolas físicas; Procesado con FASE→LOCK→CONFIRMAR; terminal de una pestaña; 273 checks |
| Servidores, consola y guardado | pendiente | Hitos 8 y 15 |

## 12. Cómo añadir un sistema

1. Define su recurso en `data/` y su clase pura en `scripts/core/`.
2. Escribe la prueba en `tests/smoke.gd` y védla fallar.
3. Implementa la lógica mínima.
4. Conecta la escena por señales; no metas reglas en el nodo.
5. Añade la comprobación de rendimiento si crea geometría o luces.
6. Actualiza `DESIGN.md`, `ARCHITECTURE.md`, `TASKS.md` y `ASSETS.md` si aplica.
7. Commit pequeño.
