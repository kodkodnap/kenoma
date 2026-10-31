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

## Hito 1 — Interacción y máquina de prueba (siguiente)

- [ ] `Interactable` con raycast desde la cámara y foco visible.
- [ ] Verbo `E` con mantener para acciones largas.
- [ ] Máquina de prueba: botón, interruptor y perilla con estados.
- [ ] `PowerConsumer` mínimo y señal de energía.
- [ ] Sonido/feedback de accionamiento (aunque sea sintetizado).
- [ ] Smoke: enfocar, accionar y comprobar cambio de estado.

## Hito 2 — Base principal en placeholders

- [ ] Interiores, puertas, energía, ciclo día/noche, iluminación y ambiente.

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
