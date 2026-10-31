# Ruido de Fondo

Juego de terror y simulación en primera persona: radioastrónomo aislado en una base en el bosque. Proyecto original de aprendizaje en **Godot 4.7.2** (Forward+, GDScript tipado).

Estado actual: **hito 1** — jugador en primera persona, linterna, interacción física y máquina de prueba con energía, calor y estados.

## Ejecutar

Desde esta carpeta (`godot/`):

```bash
# Godot en PATH
godot --path .

# Instalación portátil de este equipo
& "C:\Users\ibane\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path .
```

También puedes abrir `project.godot` desde el gestor de proyectos y pulsar **F5**.

## Controles

| Acción | Tecla |
|---|---|
| Mover | WASD |
| Correr | Shift |
| Mirar | Ratón |
| Interactuar | `E` o clic izquierdo (mantener si el prompt lo pide) |
| Linterna | F |
| Métricas de rendimiento | F3 |
| Liberar el ratón | Esc (clic para recapturar) |

## Verificación

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/smoke.gd
```

El smoke comprueba que la escena carga, el jugador se mueve de verdad, la cámara y la linterna existen, el suelo tiene colisión y la máquina responde a foco, mantener, sobrecalentamiento, reinicio, perilla, corte de energía y sobrecarga.

## Documentación

- `docs/DESIGN.md` — visión, pilares y decisiones.
- `docs/ARCHITECTURE.md` — sistemas, clases y rendimiento.
- `docs/TASKS.md` — hitos y estado.
- `docs/IDEAS.md` — backlog de ideas.
- `docs/ASSETS.md` — estilo, presupuestos y registro de modelos.
