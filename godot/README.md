# Kenoma

Juego de terror y simulación en primera persona inspirado en los **sistemas** de *Voices of the Void*.
Eres un radioastrónomo aislado en una base alpina: encuentras señales, las descargas, las procesas,
localizas satélites y mantienes la energía. Todo el arte, el código, los textos y el audio son originales.

> **Estado:** hitos 0–6 cerrados y fase A de la estación física: documentación, jugador, interacción
> e inventario, Alpha Root Base, energía, estación de señales, ciclo diario (reloj de 75 min, tarea a
> medianoche, tienda, dron a las 06:00, multas y bonus) y la consola de Descargas: chasis, CRT de
> fósforo, vúmetro, lámpara y controles físicos. Siguiente: fases B–E de la estación física o hito 7.
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
| Coger / soltar objeto | E / G |
| Rotar objeto sostenido | Botón derecho + ratón |
| Lanzar objeto | Clic izquierdo sosteniéndolo |
| Linterna | F |
| Panel de prueba | Tab |
| Overlay de rendimiento | F3 |
| Liberar ratón | Escape |

El HUD muestra stamina, batería de la linterna y el volumen de la mochila. Correr consume stamina y
por debajo de 15 no se puede esprintar. La linterna es la del prototipo: se conserva, con batería y
toggle. El spawn está en el lobby; la máquina de prueba está en el utility closet, a la derecha del
pasillo, y el panel de prueba es un overlay con `SubViewport` que no pausa el mundo.

## Verificación

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

El smoke comprueba arranque, jugador, cámara, linterna, colisión, overlay, la máquina de prueba,
inventario por volumen, agarre/rotación/tiro, panel con `SubViewport`, bases de entidad/evento, la
Alpha Root Base (zonas con luz, 30 servidores, 4 paneles, props, rampas, recorridos y presupuesto),
la energía (capacidad, eficiencia, avería, apagón, doble rearme, control remoto y luces), la estación
de señales (radares, alineación, descarga, fallos, procesado, copias y venta), el ciclo diario (reloj,
tarea, tienda, dron, multa, bonus y snapshot), la consola física de Descargas (chasis fusionado, CRT,
vúmetro, seis perillas por raycast, rueda, detector y palanca) y las 234 comprobaciones acumuladas.
Cada hito añade sus pruebas.

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

Hitos 0–2: documentación, jugador e interacción/inventario. Hitos 3–6: base, energía, estación de
señales y ciclo diario. Hito 7: mapa exterior. Hito 6: ciclo diario. Hito 7: mapa. Hito 8: servidores. Hito 9: stats. Hito 10: entidades.
Hitos 11–14: Tier 2–4. Hito 15: guardado, menús y pulido.

Detalle en [`docs/TASKS.md`](docs/TASKS.md).
