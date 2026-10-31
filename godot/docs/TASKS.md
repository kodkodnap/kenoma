# Tareas

## Hito 0 — Proyecto base ✅ (2026-10-30)

- [x] Proyecto Godot 4.7.2 en `godot/`, Forward+, GDScript tipado.
- [x] Estructura de carpetas y `.gitignore` (`.godot/`).
- [x] Jugador primera persona: WASD, sprint, mirada con ratón, gravedad, colisión.
- [x] Linterna con batería (F), se apaga al agotarse.
- [x] Sala de pruebas con suelo, paredes y cajas para medir escala.
- [x] Overlay de rendimiento (F3): FPS, draw calls, primitivas, memoria, nodos.
- [x] `GameBalance` + `data/balance.tres`.
- [x] Smoke test headless con movimiento real.
- [x] Documentos de diseño, arquitectura, tareas, ideas y assets.

**Cómo probar:** abrir `godot/project.godot` en Godot 4.7.2, F5. WASD para moverte, ratón para mirar, Shift para correr, F para la linterna, F3 para métricas, Esc para liberar el ratón (clic para recapturarlo).

**Verificación automática:**

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/smoke.gd
```

Resultado esperado: `SMOKE OK: hito 0` y código de salida 0.

## Hito 1 — Interacción y máquina de prueba ✅ (2026-10-30)

- [x] `Interactable` con raycast desde la cámara y foco visible.
- [x] Verbo `E`/clic con mantener para acciones largas y barra de progreso.
- [x] `MachineDef` en `.tres` y `Machine` base con estados.
- [x] Máquina de prueba: interruptor, botón de reinicio y perilla de ganancia.
- [x] `PowerConsumer` y `PowerGrid` mínima con corte por capacidad.
- [x] HUD de foco, prompt, progreso y estado (calor, modo, carga).
- [x] Feedback visual: lámpara de estado, palanca, pulsación y giro de perilla.
- [x] Smoke: enfocar, mantener, sobrecalentar, reiniciar, cambiar modo, cortar energía y sobrecargar la red.

**Cómo probar:** abre `godot/project.godot` y pulsa F5. Camina hasta la máquina y mira uno de sus controles.

- **Interruptor (izquierda):** mantén `E` 1,2 s para encender o apagar. La palanca y la lámpara responden.
- **Perilla (derecha):** `E` cicla BAJA → MEDIA → ALTA. Cada modo calienta y consume más.
- **Sobrecalentamiento:** en MEDIA/ALTA la máquina se apaga al 100% de calor. Espera a que baje del 30% y pulsa el botón central para reiniciar.
- **Energía:** `PowerGrid` tiene 1500 W; si la carga la supera, corta toda la red. Al volver, la máquina queda apagada.
- **HUD:** arriba a la derecha se ven estado, calor, modo y carga de la red.

**Verificación automática:**

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/smoke.gd
```

Resultado esperado: `SMOKE OK: hitos 0 y 1` y código de salida 0.

## Hito 2 — Base principal en placeholders

- [ ] Interiores, puertas, energía, ciclo día/noche, iluminación y ambiente.
- [ ] Audio ambiental y clics de máquina sintetizados.

## Hito 3 — Terreno y bosque

- [ ] Escala objetivo, MultiMesh, LOD y medición de rendimiento.

## Hito 4 — Núcleo de señales

- [ ] Recepción, decodificación y triangulación en computadoras con SubViewport.

## Hito 5 — Amenazas nocturnas

- [ ] IA básica, ruido, escondites y consecuencias.

## Hito 6 — Modelos generados

- [ ] Sustituir placeholders uno a uno, registrar en `ASSETS.md`.

## Hito 7 — Guardado, menús y pulido

- [ ] Serialización versionada, menús, accesibilidad y segunda pasada de rendimiento.

## Registro

- 2026-10-30 — Hito 0 completado. Smoke en verde con Godot 4.7.2. Siguiente: interacción.
- 2026-10-30 — Hito 1 completado. Interacción, máquina de prueba y red mínima; smoke en verde. Siguiente: base principal.
