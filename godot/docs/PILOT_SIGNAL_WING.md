# Plan Piloto — Ala de Señales y Fachada del Voladizo (`A-01 / A-03 / A-04 / A-05`)

> **Objetivo único:** sustituir la geometría de bloques solo en el **exterior del voladizo** y la **Sala de Control de Señales (`y = 6.0`)** hasta igualar la lectura visual de `references/art-direction/base-exterior.png` y `base-interior-signal-room.png`, validando con capturas fijas en Forward+ antes de extender el kit al resto de la base.

---

## 1. Reglas de ejecución (para Blender MCP + OpenCode)

1. **Prohibido parchear silueta con colores/ruido en GDScript.** Si en la captura un muro, marco o mueble parece un cubo liso, se sustituye por una pieza `.glb` o un prop CC0 estilizado.
2. **Separación lógica vs. visual:** `BaseLayout` y `BaseBuilder._collision` siguen dando las colisiones exactas y los `Marker3D` (`SignalPanel1..4`, `PrinterPlaceholder`, `MesaDiscos`, `MainComputerMarker`). La geometría bonita se carga como escenas `.tscn` / `.glb` visuales encima sin tocar la jugabilidad ni `godot/project.godot`.
3. **Escala e integración (`ASSETS.md §3`):** `1 unidad = 1 metro`, origen en la base (`y = 0`), ejes glTF `+Y` arriba / `-Z` adelante.
4. **Presupuesto del piloto:** mantener escena total **< 250 draw calls** y **< 150.000 triángulos visibles** (el recorte LOD del bosque deja margen libre para el kit sin sacrificar árboles).

---

## 2. Kit Brutalista Modular (`godot/assets/models/kit/` — 8 piezas)

Todas las piezas usan la paleta de `ASSETS.md §1`: hormigón vertido gris neutro (`roughness ~0.88`), acero oscuro estructural (`#1B2026`, `metallic 0.65`) y madera cálida envejecida (`#5A3B24`).

| Pieza `.glb` | Medidas (m) | Detalle geométrico obligatorio (anti-cubo) | Límite tris | Instanciado en |
|---|---|---|---:|---|
| `wall_brutalist_4m.glb` | `4.0 × 4.2 × 0.28` | Biseles en aristas, zócalo metálico inferior (`0.18 m`), cornisa superior y junta vertical de encofrado cada `2.0 m` | < 220 | `MultiMeshInstance3D` muros de Señales |
| `wall_corner_pilaster.glb` | `0.55 × 4.2 × 0.55` | Pilastra achaflanada con pletina atornillada abajo y arriba | < 140 | 4 esquinas del voladizo y juntas |
| `cantilever_pier_v.glb` | `1.4 × 6.2 × 4.8` | Zapata de hormigón biselada + 2 tornapuntas en V de acero en I con cartelas y pernos | < 750 | 3 pórticos bajo el voladizo (`x = -16.8, -8.5, -0.2`) |
| `window_bay_sloped_3m.glb` | `3.0 × 2.8 × 0.55` | Ventanal **inclinado ~10° hacia fuera arriba** como en `base-exterior.png`, parteluces gruesos exteriores, vierteaguas inclinado e interior hondo (`0.35 m`) | < 420 | 6 módulos en el ventanal de `18 m` (`z = -29.0`) |
| `door_bulkhead_heavy.glb` | `2.8 × 3.1 × 0.36` | Marco metálico hundido `12 cm`, hoja con ventana ojo de buey, barra antipánico y placa de umbral | < 650 | Puerta este hacia Terraza del Dron |
| `ceiling_beam_tray.glb` | `4.0 × 0.55 × 0.90` | Viga de hormigón + bandeja portacables perforada + tubo de ventilación lateral | < 380 | Techo de Sala de Señales (3 vanos transversales) |
| `cable_catenary_run.glb` | `4.0 × 0.6 × 0.35` | Mazo de 3 cables colgando con curva suave desde las bandejas hasta las consolas traseras | < 480 | Techo → consolas + pasillo sur |
| `fascia_parapet_4m.glb` | `4.0 × 1.15 × 0.60` | Cenefa gruesa del voladizo con goterón metálico y ribete de nieve acumulada arriba | < 260 | Borde perimetral del voladizo |

**Total del kit modular completo:** ~3.300 tris base instanciados → **< 16.000 triángulos** y **8 draw calls** para toda la envolvente del piloto.

---

## 3. Héroes, Mobiliario y Cableado de la Sala de Señales (`SignalRoomDecor.tscn`)

Se monta como escena dedicada en `godot/scenes/base/signal_room_decor.tscn` para poder iterar visualmente en el editor sin tocar código de mecánicas:

| Elemento | Origen recomendado | Requisito visual clave | Límite tris |
|---|---|---|---:|
| **Bancada curva frente al ventanal (`4` puestos)** | Blender MCP (`A-01 / A-04`) | Consolas con frente inclinado `18°`, reposamanos de madera/acero, faldón trasero cerrado con cables enchufados | < 8.000 |
| **Consola `Playback` (`A-04`)** | Blender MCP (sustituye `SignalPanelInteract`) | Chasis retro años 80, carrete/ranura de disco física, dial de volumen, CRT vivo en `SubViewport` | < 6.000 |
| **Impresora Matricial (`A-03`)** | Blender MCP (sobre `PrinterPlaceholder`) | Cabezal con rieles, tira de papel continuo cayendo en arco al suelo, bandeja de papel | < 3.500 |
| **Mesa cálida + sillas + lámpara (`A-05`)** | Base CC0 (Poly Pizza / Poly Haven) + pase de paleta en Blender | Mesa de roble gastado, 3–4 sillas giratorias con ruedas de los 80, lámpara articulada con pantalla de latón emitindo luz cálida real sobre mapas/tazas | < 6.000 |
| **Alfombra gastada + desorden vivo** | `Decal` + props CC0 unificados | Alfombra con bordes deshilachados y mancha central, 2–3 tazas, cuadernos, lápices, archivadores, tablón de corcho con notas y cables enrollados | < 4.000 |
| **Pinos del claro frontal (`A-08`)** | Librería CC0 o Blender (3 variantes con tarjetas de ramas + LOD) | Reemplazan solo visualmente a los árboles alrededor del claro visible desde el ventanal | ~450–600 c/u |

---

## 4. Orden estricto de ejecución (sin atajos)

1. **Hito P1 — Envolvente del Voladizo:** Modelar y validar en Blender MCP `cantilever_pier_v`, `window_bay_sloped_3m`, `wall_brutalist_4m` y `fascia_parapet_4m`. Integrar sustituyendo los muros/ventanal/pórticos del bloque `signal` en `BaseBuilder`.
2. **Hito P2 — Techo, Vigas y Cables:** Añadir `ceiling_beam_tray`, `cable_catenary_run` y `door_bulkhead_heavy` + luminarias colgantes físicas bajo los focos `SignalTableSpot` y `SignalConsoleSpot`.
3. **Hito P3 — Consolas y Sala Habitable:** Sustituir `DownloadsPanel` (chasis visual), cerrar `A-04` (`Playback`) y `A-03` (`Printer`), y montar `SignalRoomDecor.tscn` con mesa, sillas, lámpara, tazas y papeles.
4. **Hito P4 — Pinos reales en el claro frontal:** Cambiar los árboles de primer plano (`dist < 140 m`) por variantes con tarjetas de ramas y corteza desde Blender.

---

## 5. Checklist auditable con capturas fijas (criterio "Listo para jugar")

No se aprueba ningún hito sin **4 capturas Forward+ en 1280×720** desde posiciones fijas comparadas lado a lado con `base-exterior.png` y `base-interior-signal-room.png`:

1. **`CAP_01_EXT_CANTILEVER` (`pos: (-28, 3.5, -48)` mirando a `(-6, 6.5, -24)`):**
   - [ ] El ventanal tiene **inclinación real** y parteluces profundos (no plano como pared).
   - [ ] Los 3 pórticos en V muestran **biseles, zapatas y cartelas**, bañados por los focos inferiores del voladizo.
   - [ ] La cenefa del voladizo y cornisas tienen junta/goterón y nieve encima; nada parece "cajas grises pegadas".
2. **`CAP_02_INT_PANORAMIC` (`pos: (-8.5, 7.6, -15.0)` mirando hacia `-Z`):**
   - [ ] Contraste claro: **pozo cálido** en mesa y consolas vs. esquinas del techo en penumbra (`SSAO` visible en zócalos).
   - [ ] Vigas del techo, bandejas y mazos de cables curvos conectan el techo con las consolas.
   - [ ] Desde dentro se lee la silueta del claro nevado, los pinos y la baliza roja lejana a través del cristal inclinado.
3. **`CAP_03_INT_CONSOLE_CLOSE` (`pos: (-12.5, 7.5, -25.2)` mirando a las consolas):**
   - [ ] Las 4 estaciones (`Coordinates`, `Downloads`, `Playback`, `Processing`) comparten línea retro años 80 sin caras planas vacías ni cuadrados emisivos enormes.
   - [ ] Hay **micro-desorden** creíble (cables, papeles, notas, tazas, impresora con tira de papel).
4. **`CAP_04_INT_LIVING_CORNER` (`pos: (-15.0, 7.5, -24.0)` mirando a mesa central y puerta este):**
   - [ ] Zócalos en todas las paredes, puerta hundida `12 cm` con marco pesado, alfombra y mesa cálida con sillas reales (cero cubos de madera).
   - [ ] Presupuesto tras todos los cambios: **`draws < 250`**, **`triangles < 150.000`** y `tests/smoke.gd` en verde (`SMOKE OK`).
