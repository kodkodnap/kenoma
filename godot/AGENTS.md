# AGENTS — Ruido de Fondo

> Proyecto Godot 4 dentro de `godot/`. El juego web ESTATICA de la raíz es otro proyecto y **no se toca**.
>
> Este archivo es la memoria de sesión. Leer al empezar, en este orden:
> `docs/ORIGINAL_FEATURES.md` → `docs/DESIGN.md` → `docs/ARCHITECTURE.md` → `docs/TASKS.md` →
> `docs/IDEAS.md` → `docs/ASSETS.md`.

## Prompt vigente (2026-10-30)

El usuario sustituyó la visión inicial por una **réplica fiel de los sistemas de *Voices of the Void***:
mismos sistemas, mecánicas, contenido, escala y sensación, **sin assets, código, texturas, audio, textos
ni nombres de archivo del original**. Los nombres pueden coincidir, pero deben vivir en `data/` para
poder renombrarlos. La fuente de verdad es <https://voicesofthevoid.wiki.gg>, resumida en
`docs/ORIGINAL_FEATURES.md`.

### Reglas del prompt

- No copiar assets, código, texturas, audio, texto ni interfaces del original.
- Mantener `docs/IDEAS.md` como backlog con fecha, descripción y estado.
- Si una idea contradice el diseño o el original, avisar en una línea, proponer integración y actualizar
  `DESIGN.md` antes de implementar.
- Si falta una decisión, proponer 2 opciones cortas con recomendación y seguir la recomendada.
- Diseño modular y data-driven: máquinas, señales, ítems, entidades, eventos y balance en
  `data/*.tres` / JSON, no dentro de scripts.
- Sistemas por señales; quitar uno no debe romper los demás.
- Todos los parámetros de balance en un solo lugar (`data/balance.tres`).
- Hitos pequeños y verificables; no generar todo de una vez.
- Al terminar cada hito: qué se hizo, cómo probarlo y qué sigue.
- Commits pequeños con mensajes claros; no reescribir archivos completos si basta un cambio puntual.

### Los 15 hitos

0. Investigación, catálogo y documentación. **Hecho.**
1. Proyecto base: jugador 4/8/1,5 m/s, stamina, linterna, debug.
2. Framework Interactable/Grabbable/Machine/Panel/Item/Entity/Event + inventario.
3. Alpha Root Base en placeholders: señales, 30 servidores, sótano, garaje, cocina.
4. Energía: 3 transformadores, breaker, apagones.
5. Estación de señales completa: 4 paneles, discos, caja, base de datos.
6. Ciclo diario, email, dron, cintas, puntos, tienda, mejoras.
7. Mapa exterior a escala: 24 platos, transformadores, radares, torre.
8. Servidores, consola, hashcodes, reparación y calibración.
9. Estadísticas: hambre, stamina, salud, sueño, paranoia, dificultad y ajustes.
10. Entidades básicas, radar y noche.
11. Tier 2: ítems, cocina, crafting, construcción, cámaras, fotos, pesca, excavación, ATV, módulos.
12. Modelos definitivos.
13. Tier 3: eventos de historia, facciones, sueños, logros.
14. Tier 4: secretos, Forbiddens, chistes, dimensiones.
15. Guardado, menús, accesibilidad y pulido.

## Stack y reglas

- Godot **4.7.2 stable**, renderer **Forward+**, GDScript con tipado estático.
- Carpetas: `scenes/`, `scripts/`, `data/`, `assets/models/`, `assets/audio/`, `assets/textures/`,
  `docs/`.
- 1 unidad = 1 metro; Y arriba; −Z adelante; orígenes en la base.
- Clases reutilizables: `Interactable`, `Grabbable`, `PowerConsumer`, `Machine`, `Panel`, `ItemDef`,
  `Entity`, `EventDef`, `SignalDef`. Nada de scripts gigantes.
- Las pantallas de computadora usan `SubViewport` con UI propia.
- La lógica de juego vive en `scripts/core/`, fuera de las escenas; se prueba sin render.
- El estado debe ser serializable desde el hito 2, aunque el guardado llegue en el 15.
- Rendimiento desde el día 1: medir con F3 y presupuesto en `ARCHITECTURE.md`.

## Estado actual

- **Hito 0 cerrado:** catálogo, diseño, arquitectura, tareas, ideas, assets y README.
- Existe un prototipo heredado del hito 1 anterior: jugador a 3,2/5,6 m/s, `TestMachine`, `PowerGrid`
  todo-o-nada. **No es el diseño final**; el hito 1 nuevo lo rehace con 4/8/1,5 m/s y stamina.
- El juego web ESTATICA de la raíz sigue sin trackear y no debe modificarse.
- Repositorio: `C:\Users\ibane\Documents\proyecto_personal\estatica`; proyecto Godot en `godot/`.

## Verificación obligatoria

Binario portátil:

```text
C:\Users\ibane\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe
```

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

- `--headless --import` debe terminar sin errores.
- El smoke debe pasar entero; cada sistema nuevo añade su comprobación **antes** de implementarse.
- Si se toca UI o mundo, probar también en Forward+ real.
- No usar `waitForTimeout` para esperar estados de juego; esperar frames o señales.

## Documentación

| Archivo | Uso |
|---|---|
| `docs/ORIGINAL_FEATURES.md` | Catálogo del original por sistemas, T1–T4, estado. |
| `docs/DESIGN.md` | Visión, decisiones, alcance, dificultad, arte. |
| `docs/ARCHITECTURE.md` | Capas, clases, señales, datos, colisiones, rendimiento. |
| `docs/TASKS.md` | Los 15 hitos y criterios de aceptación. |
| `docs/IDEAS.md` | Backlog del usuario y decisiones descartadas. |
| `docs/ASSETS.md` | Estilo, presupuesto, pipeline y registro de modelos. |

Al terminar un hito, actualizar el documento que corresponda y dejar el estado en `TASKS.md`.

## Commits

- Mensaje: `hito N: descripción breve`.
- Incluir solo `godot/`; no commitear el juego web ni archivos temporales.
- No reescribir la historia ni borrar progreso sin avisar.
