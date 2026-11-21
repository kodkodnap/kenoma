# Diseño — Consola física de Procesado de Señales (hito 5.5, fase D)

> Fecha: 2026-11-21. Estado: **aprobado e implementado (hito 5.5, fase D)**.
> Predecesores: [`DESIGN.md`](../../DESIGN.md), [`TASKS.md`](../../TASKS.md) hito 5.5,
> [`ARCHITECTURE.md`](../../ARCHITECTURE.md), [`ASSETS.md`](../../ASSETS.md).

## 1. Intención y por qué

El usuario quiere una sala principal de señales **muy inspirada** en Voices of the Void pero no
idéntica, y hoy su bloqueo está en dos sitios a la vez: los modelos de las máquinas y sus
funcionamientos reales. La cadena ya tiene dos estaciones físicas (Descargas, fase A; Coordinates,
fase B) y las otras dos siguen siendo una caja placeholder más una pestaña del terminal.

Este hito convierte **Procesado** en la tercera máquina física y le da un funcionamiento real:
girar la perilla de sintonía cambia la onda del CRT en tiempo real, de ruido desordenado a una
traza equilibrada; solo al estabilizarla se puede procesar la copia y avanzar al siguiente panel.
Es un corte vertical completo: modelo importado, control físico, simulación, audio y prueba.

## 2. Lo que se hace y lo que no

### Se hace

- Exportar `blender/signal_console.blend` a `godot/assets/models/signal-processing-console.glb`
  (mismo patrón que `coordinates-console.glb`: geometría horneada, origen en la base, frente hacia
  +Z en Godot).
- Instanciarlo en el marcador `SignalPanel4` de Signal Processing, sustituyendo la caja placeholder.
- Un `RotaryKnob` invisible alineado con la rueda central horneada, y un `PushButton` invisible
  sobre la ranura de hashcode para confirmar el procesado.
- Un CRT vivo sobre `SubViewport` que tape el cristal horneado, reutilizando `CrtScreen`.
- Lógica pura nueva en `SignalSystem`: un valor de corrección de sintonía que produce una
  estabilidad de onda en 0..1, con umbral editable en `data/balance.tres`. Al superarlo se llama a
  `process_copy(index, level)`, que ya existe.
- Textos, etiquetas y audio **originales de Kenoma**, no los literales del `.blend`.
- Comprobaciones de smoke **antes** de implementar, import limpio, captura Forward+, docs al día.

### No se hace

- Rediseñar ni revestir la sala: los holders de los paneles 1–4 y el resto de la base quedan como
  están. La visión de la sala inspirada en VotV es el marco, no este hito.
- Tocar Descargas ni Coordinates, ni mover sus marcadores.
- La fase E (quitar el overlay `SignalConsole`): el terminal conserva la pestaña de Reproducción.
- Hashcodes, servidores ni entidades: pertenecen a los hitos 8 y 10.
- Copiar assets, textos, audio ni nombres de archivo del original.

## 3. Decisiones (tomadas aquí, salvo que el usuario diga lo contrario)

1. **Modelo.** Se conserve la geometría del `.blend` tal cual (1,20 × 0,62 × 0,79 m, 112 objetos),
   pero se exporta sin los tres planos de CRT (`SIG_crt_screen*`) y sin los textos literales; el
   cristal y las etiquetas se regeneran dentro de Godot. Si el exportador glTF no respeta los
   materiales procedurales de Blender, se remapean a `MachineMaterials` como en la fase A.
2. **Controles.** La rueda central es el único control de simulación; la ranura de hashcode es el
   confirmar. Los otros tres diales, los interruptores y el medidor EMF quedan de decoración, con
   `MachineBatch` fusionando lo estático por material. Misma técnica que la fase B: áreas
   invisibles con `visible = false` y `CollisionShape3D` exactamente sobre el mando horneado.
3. **Simulación.** Se añade a `SignalSystem` un estado puro `decode_tuning: float` y una función
   `decode_stability() -> float` derivada de la distancia al valor objetivo de la copia seleccionada.
   El ruido de la onda se alimenta de ese valor, no de un temporizador: girar la perilla cambia la
   traza en el mismo frame. El umbral y la sensibilidad van en `data/balance.tres` (regla del proyecto:
   todo balance en un solo sitio).
4. **CRT.** `CrtScreen` ya tiene `stability` con jitter `lerpf(0.16, 0.01, stability)` en
   `_draw_trace()`. Se reutiliza ese canal en modo Procesado en vez de crear otro dibujante.
5. **Contenido.** Los mensajes del `.blend` («It is not the time», «Invalid entity group», etc.) se
   sustituyen por textos propios. El audio se regenera con `SignalAudio` o nuevos WAV originales; no
   se importan los del `blender/sounds/`. Se anota en `DESIGN.md` y `ASSETS.md` antes de programar.
6. **Tamaño del hito.** Cortes pequeños y verificables, en este orden: GLB → panel sin lógica →
   lógica pura + smoke → CRT/control/audio → docs y captura. Cada corte deja el smoke en verde.

## 4. Criterios de aceptación

- [x] `godot/assets/models/signal-processing-console.glb` importa sin errores y mide ~1,2 m de ancho,
      apoyado en el suelo, con el frente hacia el jugador.
- [x] `SignalPanel4` ya no abre el overlay de Procesado: instancia la máquina física. El terminal
      queda con una pestaña (Reproducción) y el smoke lo comprueba.
- [x] Al girar el dial invisible, `decode_stability()` cambia y la onda del CRT pierde jitter en tiempo
      real, sin esperar a un tick ni a una señal de UI.
- [x] Por debajo del umbral, confirmar no procesa y muestra un aviso propio; por encima, se consume la
      copia seleccionada con `process_copy` y se habilita el avance al siguiente panel.
- [x] Se añaden comprobaciones de smoke antes del código, y `--headless --script res://tests/smoke.gd`
      pasa entero.
- [x] Captura Forward+ real: se ve la consola, la CRT y la perilla enfocada; sin errores
      (`docs/captures/05_procesado.png`).
- [x] Presupuesto: 12 mallas / ~3,4k tris, por debajo de 15k y del límite global de 250 draws. El
      objetivo de ~5 draws netos se relaja porque el GLB horneado llega en 12 materiales.
- [x] `DESIGN.md`, `TASKS.md`, `ARCHITECTURE.md` y `ASSETS.md` quedan actualizados.

Nota: no se importan los WAV del `.blend` y este corte no añade audio propio de Procesado; los textos
visibles se regeneran en Godot como contenido original de Kenoma.

## 5. Riesgos y mitigaciones

| Riesgo | Mitigación |
|---|---|
| El GLB de Blender llega con demasiada geometría o materiales incompatibles | Revisar tris tras importar; remapear a `MachineMaterials` y fusionar con `MachineBatch`. |
| Los planos de CRT horneados tapan el `SubViewport` | Excluirlos del GLB por nombre y comprobar el orden de capas con captura Forward+, como en la fase B. |
| La rueda invisible no coincide con la rueda dibujada | Alinear por cotas compartidas y añadir una comprobación de smoke sobre la posición del control. |
| El valor de sintonía no tenga objetivo claro para una copia sin seleccionar | Definir objetivo por `selected_def` y devolver estabilidad 0 cuando no haya copia; cubrirlo en el smoke. |
| Los textos horneados del `.blend` cuele contenido del original | Exportar sin objetos de texto y regenerar `Label3D` propios desde `data/`. |

## 6. Pendiente que el constructor debe resolver sin volver a preguntar

- La rueda nueva no debe contradictor el significado del dial de Descargas: es una corrección de fase
  local de Procesado, no la frecuencia de la portadora. Se nombra `decode_tuning` en el código.
- El avance a «la siguiente máquina» se resuelve como desbloqueo del marcador/estación siguiente ya
  existente, no como una nueva escena de transición.
- Si el GLB no permite separar la ranura, el confirmar se coloca en el lateral de la cubierta con la
  misma cota Y que la rueda; se documenta como decisión propia en `ASSETS.md`.

## 7. Decisiones cerradas por el builder-check (2026-11-21)

Propuestas con dos opciones y recomendación, según la regla de `AGENTS.md`. Salvo indicación contraria
del usuario, se sigue la recomendación:

1. **Copia a procesar:** última copia guardada. Alternativa descartada: selector físico adicional.
2. **Objetivo de `decode_tuning`:** campo `decode_target` en `data/signals/catalog.json`, derivado de
   la señal. Alternativa descartada: valor global en `balance.tres`.
3. **«Siguiente máquina»:** al procesar con éxito se habilita exportar esa copia a disco y se enciende
   el LED LOCK. No se crea escena de transición ni se bloquean marcadores. Alternativa descartada:
   bloquear/desbloquear marcadores.
4. **Nivel del confirmar:** `copy_level + 1`, respetando `PROCESS_THRESHOLDS`. Alternativa descartada:
   nivel 1 fijo.

Además, el builder-check confirmó que no hacen falta dibujantes nuevos: asignar
`CrtScreen.stability = decode_stability()` y `signal_level = 1` ya produce el efecto de onda.
