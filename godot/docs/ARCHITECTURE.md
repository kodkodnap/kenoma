# Arquitectura

## Capas

| Capa | Contenido | Regla |
|---|---|---|
| `scripts/core` | Lógica pura: balance, estado, señales, economía | Sin dependencias de escena. Testeable headless. |
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
| `Player` | `CharacterBody3D` | Movimiento, mirada, linterna. **Implementada.** |
| `Interactable` | `Area3D` o `Node3D` | Foco por raycast, verbo de interacción, señal `interacted`. |
| `PowerConsumer` | `Node` | Consumo, prioridad y apagado por falta de energía. |
| `Machine` | `Node3D` | Estados (`off`, `on`, `overheated`, `broken`), señales de cambio. |
| `SignalSource` | `Resource` | Definición de señal: banda, cifrado, fuerza, origen. |

Las clases se añaden cuando un hito las necesita; no antes.

## Comunicación

- Señales de Godot para eventos entre sistemas (`power_changed`, `machine_state_changed`, `signal_decoded`).
- Un único estado de partida (`GameState`) cuando exista guardado; los sistemas lo leen, no lo duplican.
- Sin referencias cruzadas entre máquinas: se comunican por señales o por el bus de energía.

## Datos

- `data/balance.tres` es la única fuente de valores de balance.
- Las definiciones de máquinas y señales serán Resources con `@export` y se instanciarán desde escenas genéricas.
- Nada de constantes de gameplay dentro de `_process` o `_physics_process`.

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

El smoke comprueba carga de escena, jugador, cámara, linterna, movimiento real con `Input.action_press`, colisión del suelo y overlay.
