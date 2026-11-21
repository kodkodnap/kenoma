# AGENTS — Kenoma

> Proyecto Godot 4 dentro de `godot/`. La versión web (Three.js) de ESTATICA, en la raíz, está **deprecada**: no se desarrolla ni se modifica.
>
> **Nombre:** Kenoma. **Repo:** <https://github.com/kodkodnap/kenoma>.
>
> Este archivo es la memoria de sesión. Leer al empezar, en este orden:
> `docs/ORIGINAL_FEATURES.md` → `docs/DESIGN.md` → `docs/ARCHITECTURE.md` → `docs/TASKS.md` →
> `docs/IDEAS.md` → `docs/ASSETS.md`.

## Skills obligatorias

Antes de tocar `godot/`, carga la skill que corresponda con la herramienta `skill`. Viven en
`~/.agents/skills` (fuera del repo) y el cargador las expone por nombre; si no aparecen en la
sesión, lee su `SKILL.md` con `read_files`. Son estas:

| Si tocas… | Carga antes |
| --- | --- |
| Cualquier `.gd`: ciclo de vida, tipado, señales, `await` | `godot-gdscript` |
| `scripts/core/**`: estado, máquinas de estado, patrones | `godot-gdscript-patterns` |
| `scenes/**/*.tscn`, instanciación, autoloads | `godot-nodes-scenes` |
| `scripts/ui/**`: HUD, paneles, themes, foco | `godot-ui-control` |

Reglas: mínimo una skill por tarea, cargada antes de la primera edición; al cerrar, di cuáles usaste
y qué decisión cambiaron. Si mueves rutas, actualiza `.agents/skills/manifest.json` (raíz): el gate
`npm run skills:check` comprueba que esta tabla, los globs y las skills instaladas sigan cuadrando.

## Prompt vigente (2026-10-30)

El usuario aclaró que la referencia es una **inspiración muy cercana**, no un clon literal: mismos
pilares, sistemas, escala y sensación, con variaciones propias en contenido, nombres, reglas y soluciones.
No se copian assets, código, texturas, audio, textos ni nombres de archivo del original. Si un prototipo
ya cumple (por ejemplo la linterna), se conserva y se ajusta. Los nombres pueden coincidir, pero deben
vivir en `data/` para poder renombrarlos. La fuente de verdad es <https://voicesofthevoid.wiki.gg>,
resumida en `docs/ORIGINAL_FEATURES.md`.

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
3. Alpha Root Base en placeholders: señales, 30 servidores, sótano, garaje, cocina. **Hecho.**
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
- **Hito 1 cerrado:** jugador a 4/8/1,5 m/s, stamina, agacharse, salto, HUD de vitales y captura
  Forward+. La linterna del prototipo se conserva.
- **Hito 2 cerrado:** `Grabbable`, `Inventory`/`ItemContainer`, `ItemDef`, `ScreenPanel` con
  SubViewport, bases `Entity`/`EntityDef` y `EventDef`/`EventDirector`, HUD de mochila y panel de
  prueba con Tab. Smoke con 85 comprobaciones.
- **Hito 3 cerrado:** Alpha Root Base recorrible en placeholders. `BaseLayout` (22 salas +
  plataformas) y `BaseBuilder` (geometría por `MultiMesh`, colisiones, luces y props). 30 servidores,
  4 paneles, 24 platos, 3 transformadores, 3 radares, 4 turbinas y torre; sótano con breaker,
  crematorio y taquillas; two ramps (subida/bajada) y techo. Smoke 89 checks; capturas Forward+ de 8
  puntos. Presupuesto 11.7k triángulos / 78 draw calls.
- **Hito 4 cerrado:** energía con `PowerSystem` puro en `scripts/core/power_system.gd` (3 × 1200 W,
  5 circuitos, estabilidad, sobrecarga, apagón y control remoto), `BreakerPanel` en el sótano y
  `PowerTransformer` reparables en los tres transformadores exteriores. Utilities apaga las luces de
  zona. `PowerGrid` eliminado. HUD con estabilidad, carga y aviso. Smoke 153 checks.
- **Hito 5 cerrado:** `SignalSystem` puro (catálogo JSON de 8 señales, ping con 3 radares, seis
  perillas, descarga con calidad, fallos de señal, base de datos, niveles 1–3, discos, copias a 0 y
  venta), `SignalConsole` con 4 paneles en `SubViewport`, imagen 64×64 generada y audio sintetizado.
  Los cuatro paneles físicos de Signal Processing abren su pestaña con E. Smoke 191 checks.
- **Hito 6 cerrado:** `GameClock` (75 min reales/día, ×1/×10/×60, dormir), `DailyTask`, `Economy`
  (5 artículos, 3 categorías, pedidos, multa, bonus) y `DailyCycle` (renueva tarea a medianoche,
  dron a las 06:00, snapshot en memoria), con `CycleConsole` de 4 pestañas en la consola central.
  Smoke 221 checks.
- **Hito 5.5 (fase A) hecho:** `DownloadsPanel` es una consola completa de ~2 m con chasis
  atornillado, zócalo trasero, cubierta inclinada, CRT de fósforo (`CrtScreen` sobre `SubViewport`),
  vúmetro, LEDs, lámpara de cuello de ganso y cables. Controles variados, no un muro de perillas: una
  perilla de frecuencia, selector de polaridad de tres posiciones (`SelectorSwitch`), detector,
  pulsador de guardado (`PushButton`) y palanca de descarga. La geometría se deriva de cotas
  compartidas (`CABINET_TOP`, `RISER_TOP`, `DECK_BACK_Z`…): la cubierta muere en la arista frontal
  del chasis y arranca en la arista del zócalo, donde se apoya el cabezal; el smoke comprueba ese
  encaje (`deck_front_edge`, `deck_back_edge`, `head_front_bottom`). Materiales y piezas 100%
  procedurales (`MachineMaterials`, `MachineMesh`); `MachineBatch` fusiona lo estático por material.
  Descargas ya no abre la terminal; quedan 3 pestañas. Smoke 242 checks. Las fases B y D se cerraron
  después: hoy los paneles 1, 2 y 4 son físicos, la terminal tiene una pestaña y el smoke acumula
  281 checks; quedan pendientes la fase C (Playback) y la E (retirada del overlay).
- **Hito 5.5 (fases B y D) hecho:** Coordinates y Procesado son consolas físicas en sus marcadores.
  Procesado usa `signal-processing-console.glb` (12 mallas, ~3,4k tris), `CrtScreen` vivo y controles
  invisibles FASE/CONFIRMAR: girar FASE cambia la estabilidad de la onda en tiempo real, LOCK se
  enciende al confirmar y se habilita exportar la copia. No se importan textos ni audio del `.blend`.
- `TestMachine` sigue como prototipo de la base de máquina.
- La versión web (Three.js) de ESTATICA, en la raíz, está deprecada: no se desarrolla ni se modifica.
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
