# Arquitectura

## Capas

| Capa | Contenido | Regla |
|---|---|---|
| `scripts/core` | Lógica de dominio: balance, energía, estado, señales, economía | Sin dependencias de escenas concretas. Testeable headless. |
| `data` | Resources `.tres`: balance, definiciones de máquinas, señales, amenazas | Todo valor ajustable vive aquí. |
| `scenes/world` | Nivel, terreno, vegetación, iluminación | Sin lógica de juego. |
| `scenes/machines` + `scripts/machines` | Máquinas y su operación física | Heredan de una clase base con estados. |
| `scripts/player` | Movimiento, cámara, linterna, interacción | Solo entrada y presentación. |
| `scenes/ui` | HUD, pantallas diegéticas | SubViewport para pantallas de computadora. |
| `scripts/audio` | Ambiente y efectos | Sin archivos hasta tener assets propios. |

## Clases previstas

| Clase | Base | Responsabilidad |
|---|---|---|
| `GameBalance` | `Resource` | Todos los parámetros de balance. **Implementada.** |
| `Player` | `CharacterBody3D` | Movimiento, mirada, linterna, raycast de foco y mantener. **Implementada.** |
| `Interactable` | `Area3D` | Foco por raycast, prompt, `hold_time`, señal `activated`. **Implementada.** |
| `PowerConsumer` | `Node` | Carga de una máquina, `draw_w` y `powered` con señales. **Implementada.** |
| `PowerGrid` | `Node` | Capacidad, registro de consumidores y corte todo-o-nada. **Implementada.** |
| `MachineDef` | `Resource` | Nombre, calor, reinicio, consumo y modos de una máquina. **Implementada.** |
| `Machine` | `Node3D` | Estados `OFF/ON/OVERHEATED/NO_POWER`, calor y modo. **Implementada.** |
| `TestMachine` | `Machine` | Presentación y controles de la máquina de prueba. **Implementada.** |
| `Hud` | `CanvasLayer` | Mira, prompt, progreso de mantener y estado de la máquina. **Implementada.** |
| `SignalSource` | `Resource` | Definición de señal: banda, cifrado, fuerza, origen. **Pendiente (hito 4).** |

Las clases se añaden cuando un hito las necesita; no antes.

## Comunicación

- `Interactable.activated` → subclase de `Machine`; `focus_changed` y `hold_changed` → `Hud`.
- `PowerConsumer.power_changed/draw_changed` ↔ `PowerGrid`; la máquina escucha `power_changed`.
- `Machine.state_changed/heat_changed/mode_changed` → presentación y HUD.
- Un único estado de partida (`GameState`) cuando exista guardado; los sistemas lo leen, no lo duplican.
- Sin referencias cruzadas entre máquinas: se comunican por señales o por la red de energía.

## Capas de colisión

| Capa | Uso |
|---|---|
| 1 | Mundo, jugador y cuerpos sólidos |
| 2 | `Interactable` (áreas de control) |

El jugador colisiona con la capa 1; su raycast de interacción usa solo la capa 2. Así los cuerpos de las máquinas no tapan los controles.

## Datos

- `data/balance.tres` es la única fuente de valores de balance.
- `data/test_machine.tres` define la máquina de prueba (calor, reinicio, consumo y nombres de modo).
- Las definiciones de máquinas y señales son Resources con `@export`; las escenas solo presentan.
- Nada de constantes de gameplay dentro de `_process` o `_physics_process`.

## Añadir una máquina

1. Crear un `MachineDef` en `data/` con calor, consumo y modos.
2. Crear una escena cuya raíz use una subclase de `Machine`; añadir `Body` sólido y un `Area3D` con `Interactable` por control.
3. Conectar `activated` a métodos de la subclase; no meter lógica en el HUD.
4. Registrar `consumer` en la `PowerGrid` desde `main.gd`.
5. Añadir sus comprobaciones al smoke antes de considerarla terminada.

## Pantallas de computadora

`SubViewport` con su propia UI 2D, textura aplicada a la pantalla del modelo. La lógica de la máquina vive fuera del viewport; el viewport solo presenta estado y emite acciones.

## Rendimiento

| Presupuesto | Límite |
|---|---|
| Props pequeños | < 2k tris |
| Props medianos | < 8k tris |
| Máquinas principales | < 15k tris |
| Draw calls visibles | objetivo < 250 |
| FPS | 60 en hardware modesto |

Medidas: `F3` muestra FPS, draw calls, primitivas, memoria y nodos. Se mide al cerrar cada hito.

Técnicas previstas: LOD, occlusion culling, MultiMesh para vegetación, LightmapGI en interiores, pocas luces dinámicas con sombra, cuerpos dormidos y pooling.

## Guardado

Se implementa en el hito 7. Estado serializable en Resources/JSON con versión; nunca se guarda el árbol de escena.

## Verificación

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/smoke.gd
```

El smoke comprueba carga de escena, jugador, cámara, linterna, movimiento real con `Input.action_press`, colisión del suelo, overlay, raycast de foco, mantener E, sobrecalentamiento, reinicio bloqueado/desbloqueado, perilla, corte de energía y sobrecarga de la red.
