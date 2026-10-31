# Notas para agentes — Ruido de Fondo

Proyecto Godot 4.7.2 dentro de `godot/` (el resto del repo es el juego web ESTÁTICA; no mezclar).

## Al empezar una sesión

Leer, en este orden: `docs/DESIGN.md`, `docs/ARCHITECTURE.md`, `docs/TASKS.md`, `docs/IDEAS.md`, `docs/ASSETS.md`. No se recuerdan conversaciones anteriores.

## Reglas

- GDScript con tipado estático; sin scripts gigantes.
- 1 unidad = 1 metro.
- Valores de balance en `data/balance.tres`; definiciones de contenido en Resources, no en código.
- Sistemas por señales; sin referencias cruzadas entre máquinas.
- Lógica fuera de las escenas.
- Nada de assets del juego de referencia. Todo original.
- Hitos pequeños: terminar, probar, medir y documentar antes de seguir.
- Cada idea nueva va a `docs/IDEAS.md`; cada decisión a `docs/DESIGN.md`.

## Verificación obligatoria

```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/smoke.gd
```

En este equipo, el binario es:

`C:\Users\ibane\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`

No dar un hito por terminado sin smoke en verde y una prueba jugable.
