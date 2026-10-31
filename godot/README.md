# Ruido de Fondo

Juego de terror y simulación en primera persona: radioastrónomo aislado en una base en el bosque. Proyecto original de aprendizaje en **Godot 4.7.2** (Forward+, GDScript tipado).

Estado actual: **hito 0** — estructura, jugador en primera persona con linterna y sala de pruebas.

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
| Linterna | F |
| Métricas de rendimiento | F3 |
| Liberar el ratón | Esc (clic para recapturar) |

## Verificación

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/smoke.gd
```

El smoke comprueba que la escena carga, el jugador se mueve de verdad, la cámara y la linterna existen y el suelo tiene colisión.

## Documentación

- `docs/DESIGN.md` — visión, pilares y decisiones.
- `docs/ARCHITECTURE.md` — sistemas, clases y rendimiento.
- `docs/TASKS.md` — hitos y estado.
- `docs/IDEAS.md` — backlog de ideas.
- `docs/ASSETS.md` — estilo, presupuestos y registro de modelos.
