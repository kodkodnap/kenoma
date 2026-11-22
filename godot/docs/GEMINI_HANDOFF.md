# Handoff visual para Gemini 4 Hydrogen

## Contexto

Kenoma es un juego en **Godot 4.7.2 stable, Forward+, GDScript tipado**, dentro de `godot/`. La versión web en la raíz está deprecada: no se toca. La visión, reglas y lecturas obligatorias están en `godot/AGENTS.md`; el diseño en `godot/docs/DESIGN.md` y `godot/docs/ASSETS.md`.

La base en voladizo ya existe y pasa los 334 checks de `tests/smoke.gd`. El problema es de **acabado visual**: las capturas actuales se leen como prototipo (bloques cúbicos, consolas simples, voladizo ligero) frente a las referencias de `references/art-direction/`.

## Referencias maestras

- `base-exterior.png`: base maciza en voladizo, atardecer, luz cálida dentro, nieve cayendo.
- `base-interior-signal-room.png`: sala de señales nocturna, consolas muy detalladas, ventanal panorámico.
- `base-cutaway-3d.png`: sección de la base; masas, forjados y soportes.
- `base-floorplan-2d.png`: distribución y pasillos amplios.

Son inspiración: **no copiar** assets, textos, UI ni código de otros juegos.

## Restricciones duras (romper cualquiera invalida el trabajo)

1. **No tocar `godot/project.godot`.** Tiene un cambio local del usuario (reformateo de floats) que no debe versionarse.
2. **Presupuesto:** `< 250` draw calls (ahora 246, margen 3) y `< 150k` triángulos visibles. Cualquier detalle nuevo debe fusionarse en mallas existentes o usar instanciación sin subir draws.
3. **No deshacer estos arreglos ya verificados:**
   - `base_builder.gd`: `surface_offset := Vector3(0.0, -mesh.size.y * 0.5, 0.0)` en `_make_ramp` (rampas al ras del suelo).
   - `base_builder.gd`: `var z_off: float = side_sign * width * 0.5` (el bucle con `Variant` no infiere con `:=`).
   - `base_builder.gd`: `printer.add_to_group("printer_placeholder")`.
   - `terrain_builder.gd`: `cast_shadow = SHADOW_CASTING_SETTING_OFF` en el terreno (proyectar sombras sobre sí mismo rayaba la nieve).
   - `_build_ring(..., split_quads: bool)`: Inner con 4 cuadrantes, Mid y Outer en una sola malla cada uno (12 mallas daban 252 draws).
4. **Espacios amplios**: pasillos ≥ 3,5 m; el diseño debe seguir siendo válido para **co-op online** (no asumir un único `Player` global). Escala `1 unidad = 1 metro`.
5. Sin dependencias nuevas. GDScript tipado; respetar la estructura de archivos existente.
6. Trabajar en rama propia o worktree; **no hacer push a `master`**. Entregar diffs pequeños y capturas antes/después.

## Objetivos visuales (en orden de impacto)

1. **Voladizo macizo.** Sustituir los pilares finos y el aspecto de cajas apiladas por un forjado grueso de hormigón y soportes inclinados / ménsicas, como en `base-exterior.png` y `base-cutaway-3d.png`. Mantener el ventanal de 18 m y las cotas de la sala (`y = 6.0`).
2. **Terreno y vegetación menos cúbicos.** Los ~16 bloques `rock` y los árboles simples de `base_builder.gd` son el rasgo más prototípico. Darles forma irregular y variedad sin añadir draws (fusionar geometría por material).
3. **Sala de señales detallada.** Consolas con diales, pantallas, papeles, sillas y la impresora matricial; nada de cuadrados emisivos grandes (ya se bajó la emisión del material `screen`). La consola debe leerse como equipo, no como placeholder.
4. **Atmósfera.** Ya hay cielo crepuscular, niebla y luz fría fuera / cálida dentro (`main.tscn`). Añadir nieve cayendo ligera y mejorar la luz interior sin romper el presupuesto. Evitar sombras duras sobre la nieve.
5. **Pasillos legibles.** El pasillo superior sale demasiado oscuro y los rótulos son diminutos: subir la luz ambiental interior y el tamaño/contraste de la señalización.

## Verificación obligatoria

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
"$GODOT" --headless --path godot --import          # exit 0, sin errores
"$GODOT" --headless --path godot --script res://tests/smoke.gd   # SMOKE OK, exit 0
```

Además, todo cambio visual debe comprobarse en **Forward+ real**. Para capturas: un script `SceneTree` temporal con `--path godot --script res://tests/_capture.gd --windowed --resolution 1280x720` y `root.get_texture().get_image().save_png(...)`. **`--headless` no sirve para capturas**: la textura vuelve `null`. Borrar el script temporal antes de entregar.

## Entrega

- Commits pequeños y atómicos, cada uno verificado con import + smoke.
- Un párrafo por cambio explicando qué mejoró y en qué captura se ve.
- Si algo no se puede hacer dentro del presupuesto de draws, explicarlo en vez de romper el límite.
- La integración y la verificación final las hace OpenCode; no pushear a `master`.
