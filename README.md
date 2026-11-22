> **DEPRECATED.** Esta es la versión web (Three.js), congelada como archivo histórico.
> El desarrollo activo del juego es en Godot: ver [`godot/`](godot/) y
> [`godot/AGENTS.md`](godot/AGENTS.md). Los comandos y el estado descritos abajo
> corresponden solo al archivo y ya no se actualizan.

# ESTÁTICA

Juego de horror y señales en primera persona. Eres el operador nocturno de la estación Kestrel, una antena de escucha en los Alpes suizos. Recibes señales, las pasas por una cadena de máquinas hasta decodificarlas, las vendes a Control y sobrevives al turno.

Es un homenaje a *Voices of the Void* con contenido original: ni assets, ni textos, ni nombres del juego original. El objetivo es distinto: **cerrar el juego** (con un final real) y quitar el relleno, no rehacer el alpha.

> Estado: **fase 1 y fase 2 jugables y verificables** (días 1–12 completos, tres desenlaces). La fase 3 (más variantes de epílogo, accesibilidad, escritorio) sigue pendiente.

## Ejecutar

```bash
npm install
npm run dev        # http://localhost:5180
```

Otros comandos:

```bash
npm run typecheck  # TypeScript estricto
npm test           # lógica pura (señales, guardado, eventos, simulación)
npm run build      # build de producción
npm run preview    # sirve el build en http://localhost:4173
npm run smoke      # verificación e2e en Edge headless (requiere dev o preview arriba)
```

## Modelos 3D

Los modelos definitivos se modelan en Blender y se exportan a `public/assets/`. La fuente y el
generador viven en el repo: no hay assets de terceros.

| Archivo | Qué es |
| --- | --- |
| `blender/sa9-spectrum.blend` | Escena de origen de la SA-9 (analizador de espectro). |
| `public/assets/machines/sa9-spectrum.glb` | Export del juego: 1.708 triángulos, 4 materiales. |
| `scripts/blender-sa9.py` | Reconstruye la máquina y reexporta el GLB; idempotente. |
| `scripts/blender_mcp.py` | Cliente del addon BlenderMCP (`localhost:9876`). |
| `scripts/glb-stats.mjs` | Nodos, materiales, triángulos y caja envolvente en metros. |

Con Blender abierto y el addon MCP escuchando en el 9876:

```bash
python scripts/blender_mcp.py execute_code "exec(open(r'<repo>/scripts/blender-sa9.py', encoding='utf-8').read())"
node scripts/glb-stats.mjs public/assets/machines/sa9-spectrum.glb
```

Convenciones: 1 unidad = 1 m, origen en el suelo y centro de la huella, frente a −Z en glTF. Las
piezas móviles van separadas y con los nombres que espera `src/world/mechanical.ts`:
`knob_frequency` (eje Z, gira con `rotation.z`), `button_isolate` (baja en `position.y`) y
`display_spectrum` (pantalla emisiva). El GLB está exportado pero todavía no se instancia en el
nivel: la escena sigue usando los volúmenes procedurales de `level.ts`.

## Controles

| Tecla | Acción |
| --- | --- |
| WASD / flechas | Mover |
| Ratón | Mirar |
| Shift | Correr |
| E | Interactuar |
| F | Linterna |
| Q | Escáner de campo |
| Tab | Consola (registro) |
| Esc | Cerrar panel / pausa |

## Loop

1. **Plato**: barre azimut y elevación hasta fijar una fuente (>45 % de señal) y graba 12 s.
2. **Analizador de espectro**: mueve la ventana del filtro hasta aislar la portadora.
3. **Demodulador**: deduce la modulación por la forma de onda (AM / FM / PULSO / COHERENTE).
4. **Decodificador de patrones**: reconoce la firma del cifrado y reconstruye el mensaje.
5. **Consola**: vende la captura, cubre la cuota, compra mejoras y cierra el turno.

El turno va de 19:00 a 05:00 (≈11,5 minutos reales). Cada noche tiene cuota, tareas y eventos aleatorios. Apagones, entidades en el linde, transmisiones que responden, silencios que no deberían existir.

Desde el día 6 el valle empeora y se abre el acto II: el repetidor a 900 m permite triangular el origen de una señal con tres mástiles y la motonieve conecta Kestrel, el repetidor y el punto fijado. El clima y las averías condicionan la cadena; el comerciante trueca capturas y tus decisiones (archivo, baliza, registro) quedan en el epílogo.

## Qué hay implementado

- Mundo 3D procedural (laboratorio, antena, caseta del generador, torre, valla, bosque, cordillera), sin assets externos.
- Cadena de decodificación real de cuatro etapas con calidad, corrupción y pistas legibles.
- 6 clases de señal, 4 modulaciones, 4 cifrados, 5 tipos de fuente por día.
- 22 eventos aleatorios + hitos guionizados de acto I y acto II.
- 7 tipos de contacto (figura, doble, perro, coro, imitador, comerciante y aprendiz), con escáner de campo y línea de visión real.
- Estrés con consecuencias mecánicas (interferencia, ruido, viñeta), corriente y reinicio del cuadro eléctrico.
- Clima determinista (clara, niebla, tormenta y ventisca): ruido, visibilidad, estrés, apagones y borrado de huellas.
- Averías, sabotaje, calibración arriesgada y piezas de repuesto para las tres máquinas.
- Repetidor a 900 m, motonieve, triangulación con tres mástiles y emplazamiento del origen transitable.
- Acto II (días 6–12): arco del operador anterior, 8 hitos, 3 decisiones persistentes, trueque y tres desenlaces.
- Economía con 7 mejoras, cuota diaria, tareas y finales múltiples (día 12, 12 fragmentos).
- Guardado versionado en `localStorage` con autoguardado, resumen de turno y reanudación.
- Audio sintetizado en WebAudio (viento, zumbido, pasos, voces, motores), sin archivos.
- Calidad gráfica adaptativa; presupuesto de escena vigilado en el smoke test (27k triángulos, ~140 draw calls).
- Primer modelo original de Blender: la SA-9, exportada a `public/assets/machines/` con sus tres piezas móviles separadas.
- 117 tests unitarios y smoke e2e de 77 comprobaciones (dev y preview).

## Diseño y fases

Ver [`DESIGN.md`](DESIGN.md) para sistemas, balance y el estado de las fases (fase 3 pendiente).
Ver [`AGENTS.md`](AGENTS.md) para trabajar en el código sin romper la verificación.
