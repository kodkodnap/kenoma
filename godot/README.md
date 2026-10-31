# Ruido de Fondo

Juego de terror y simulación en primera persona inspirado en los **sistemas** de *Voices of the Void*.
Eres un radioastrónomo aislado en una base alpina: encuentras señales, las descargas, las procesas,
localizas satélites y mantienes la energía. Todo el arte, el código, los textos y el audio son originales.

> **Estado:** hito 0 (documentación) y hito 1 (jugador, stamina y agacharse) cerrados. Siguiente:
> hito 2, framework de interacción e inventario.
>
> El juego web ESTATICA de la raíz es un proyecto aparte; este vive en `godot/`.

## Requisitos

- Godot **4.7.2 stable** (Forward+).
- Windows, Linux o macOS con Vulkan.
- Para el smoke, el binario de consola de Godot.

## Ejecutar

1. Abrir `godot/project.godot` con Godot 4.7.2.
2. Ejecutar `scenes/main.tscn` con F6 o el proyecto con F5.
3. El ratón se captura al iniciar; `Escape` lo libera y un clic lo recupera.

## Controles actuales (prototipo)

| Acción | Tecla |
|---|---|
| Mover | WASD |
| Correr | Shift |
| Saltar | Space |
| Agacharse | Ctrl |
| Mirar | Ratón |
| Interactuar / mantener | E o clic izquierdo |
| Linterna | F |
| Overlay de rendimiento | F3 |
| Liberar ratón | Escape |

El HUD muestra stamina y batería de la linterna. Correr consume stamina y por debajo de 15 no se
puede esprintar. La linterna es la del prototipo: se conserva, con batería y toggle.

## Verificación

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

El smoke comprueba arranque, jugador, cámara, linterna, colisión, overlay y las mecánicas del prototipo,
incluidas las 51 comprobaciones del hito 1. Cada hito añade sus pruebas.

## Documentación

| Documento | Contenido |
|---|---|
| [`docs/ORIGINAL_FEATURES.md`](docs/ORIGINAL_FEATURES.md) | Catálogo del original por sistemas y prioridades. |
| [`docs/DESIGN.md`](docs/DESIGN.md) | Visión, decisiones, alcance, dificultad y arte. |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Clases, capas, señales, datos y rendimiento. |
| [`docs/TASKS.md`](docs/TASKS.md) | Los 15 hitos y criterios de aceptación. |
| [`docs/IDEAS.md`](docs/IDEAS.md) | Backlog de ideas. |
| [`docs/ASSETS.md`](docs/ASSETS.md) | Pipeline y registro de assets. |

## Estructura

```
godot/
  scenes/       escenas jugables
  scripts/      lógica y controladores
  data/         Resources de contenido y balance
  assets/       modelos, audio y texturas
  docs/         diseño y catálogo
  tests/        smoke
```

## Roadmap

Hito 0: documentación. Hito 1: jugador. Hito 2: interacción e inventario. Hito 3: base. Hito 4:
energía. Hito 5: señales. Hito 6: ciclo diario. Hito 7: mapa. Hito 8: servidores. Hito 9: stats.
Hito 10: entidades. Hitos 11–14: Tier 2–4. Hito 15: guardado, menús y pulido.

Detalle en [`docs/TASKS.md`](docs/TASKS.md).
