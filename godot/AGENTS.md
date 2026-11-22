# AGENTS — Kenoma

> Proyecto Godot 4 dentro de `godot/`. La versión web (Three.js) en la raíz está **deprecada y descartada**: no se desarrolla ni se mezcla con Godot.
>
> **Nombre:** Kenoma. **Repo:** <https://github.com/kodkodnap/kenoma>.
>
> Leer al empezar cada sesión:
> `docs/DESIGN.md` → `docs/ASSETS.md` → `docs/TASKS.md` → `docs/ARCHITECTURE.md` → `docs/IDEAS.md`.
> Referencias visuales maestras: `references/art-direction/base-exterior.png` y
> `references/art-direction/base-interior-signal-room.png`.

## Skills obligatorias

Antes de tocar `godot/`, cargar las skills correspondientes si están disponibles en el entorno:

| Si tocas… | Skill |
|---|---|
| Cualquier `.gd`: ciclo de vida, tipado, señales, `await` | `godot-gdscript` |
| `scripts/core/**`: estado, máquinas de estado, patrones | `godot-gdscript-patterns` |
| `scenes/**/*.tscn`, instanciación, autoloads | `godot-nodes-scenes` |
| `scripts/ui/**`: HUD, paneles, themes, foco | `godot-ui-control` |

## Visión y reglas vigentes (2026-11-21)

- **Inspiración:** 100% inspirado en los pilares, bucle y flujo multi-máquina de *Voices of the Void*, con giro, estética, contenido y mundo propios. No copiar assets, código, textos, audio ni UI literales.
- **Estilo visual oficial:** **PBR semi-realista estilizado** (*Firewatch* + *Pacific Drive* + *Signalis*), brutalismo hormigón/metal de los 80 en montaña nevada (hora azul fuera, luz cálida tungsteno dentro). Nada de low-poly plano ni fotorrealismo sucio.
- **Diseño espacial:** **espacios amplios y respirables** (pasillos ≥ 3 m, techos altos, luz cálida acogedora dentro). La tensión nace de eventos aleatorios e indicios reales, **nunca** de claustrofobia ni mecánicas estilo FNAF sin pistas.
- **Base:** ala de mando elevada **en voladizo** con gran ventanal panorámico hacia el claro nevado (sin vallas metálicas), garaje abajo con **snowcat de orugas** y sótano técnico.
- **Flujo multi-máquina:** no meter todo en un solo PC; mantener estaciones separadas e incluir **impresora matricial física** para salidas en papel.
- **Mapa grande:** valle alpino nevado donde el **snowcat** es obligatorio para recorrer distancias largas.
- **Modelado con OpenCode + Blender MCP:** en Godot se prototipa con placeholders a escala real (`1 u = 1 m`) y las especificaciones para modelado definitivo se mantienen actualizadas en `docs/ASSETS.md` §6.
- **Arquitectura técnica:** Godot **4.7.2 stable**, **Forward+**, GDScript con tipado estático; lógica pura en `scripts/core/`, datos en `data/`, UI en `SubViewport`, presupuesto `< 250` draw calls y `< 150k` triángulos visibles.

## Estado actual del código

- **Construido y verificado (334 checks en `tests/smoke.gd`):**
  - Jugador (`4/8/1,5 m/s`, stamina, linterna), interacción física (`Interactable`, `Grabbable`, `Inventory`, diales angulares `RotaryKnob`, `DiskMedia`/`DiskDock`).
  - Energía pura (`PowerSystem`, 3 transformadores, breaker de 5 circuitos).
  - Señales puras (`SignalSystem`, catálogo JSON) + consolas físicas de Coordinates, Descargas y Procesado (falta Playback físico, Impresora Matricial y quitar overlay).
  - Ciclo diario (`GameClock`, `DailyTask`, `Economy`, `DailyCycle`).
- **Siguiente paso en línea recta (Hito 7):**
  - Reemplazar la base placeholder v1 (`BaseLayout`/`BaseBuilder` de 22 salas cuadradas) por la **nueva Estación Kenoma en voladizo y espacios amplios**.
  - Completar Playback físico + Impresora Matricial, retirar el overlay `SignalConsole` y limpiar prototipos viejos (`TestMachine`, `TestItem`, `TestPanel`).

## Verificación obligatoria (en local con Godot)

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

- `--headless --import` debe terminar sin errores.
- `smoke.gd` debe pasar al 100%; cada sistema nuevo añade sus checks antes o junto al código.
- Cambios visuales/espaciales deben comprobarse además en Forward+ real.
