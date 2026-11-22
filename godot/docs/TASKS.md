# Tareas — Kenoma

> Hoja de ruta limpia y en línea recta.
>
> **Regla:** un hito solo se marca **hecho** cuando pasa `--headless --import`, pasa
> `tests/smoke.gd` entero, se verifica visualmente en Forward+ y la documentación queda al día.

## Estado actual (Base técnica ya construida — 334 checks en verde)

Los hitos iniciales construyeron la base sistémica pura en `scripts/core/` y los primeros
prototipos jugables. Se **conserva toda la lógica pura y la interacción física** que ya funciona:

| Bloque ya construido | Qué aporta hoy | Notas para la nueva dirección |
|---|---|---|
| **Jugador & Interacción** | Movimiento 4/8/1,5 m/s, stamina, linterna, `Interactable`, `Grabbable`, `Inventory`, diales con arrastre angular (`RotaryKnob`) y `DiskMedia`/`DiskDock` | Se conserva íntegro |
| **Energía (`PowerSystem`)** | 3 transformadores, breaker de 5 circuitos, sobrecarga, apagones y luces por zona | Se adapta al nuevo plano de base y sótano |
| **Señales (`SignalSystem`)** | Catálogo JSON, ping, alineación, descarga, procesado (`FASE → LOCK`), exportación a disco y venta | Falta cerrar Playback físico, quitar overlay de señal e integrar Impresora Matricial |
| **Ciclo diario (`DailyCycle`)** | Reloj (`GameClock`), tareas diarias, economía, tienda y entregas | Adaptar entregas a plataforma del edificio / zonas alternativas |
| **Base v1 (`BaseLayout`/`BaseBuilder`)** | 22 salas cuadradas estilo Alpha Root Base placeholder | **Se sustituye en el Hito 7** por la nueva Estación Kenoma en voladizo |
| **Prototipos (`TestMachine`, `TestItem`, `TestPanel`)** | Escenas de prueba iniciales de los hitos 1–2 | **Retirar** en el Hito 7 al actualizar el smoke |

---

## Hoja de ruta en línea recta

| # | Hito | Objetivo principal | Estado |
|---:|---|---|---|
| **0–6** | Fundación sistémica (prototipo v1) | Jugador, interacción, energía, cadena de señal parcial, ciclo diario (334 checks) | **hecho (base conservada)** |
| **7** | **Nueva Base en Voladizo + Estación de Señales Completa** | Rehacer `BaseLayout`/`BaseBuilder` con la arquitectura amplia de las 2 referencias (ala en voladizo, luz cálida, pasillo 3 m, garaje abajo, sin vallas), cerrar Playback físico + Impresora Matricial, retirar overlay de señales y `TestMachine`/`TestItem`/`TestPanel` | **siguiente** |
| **8** | **Valle Alpino Grande + Snowcat** | Mapa exterior grande nevado (hora azul, pinos, claro frontal, pico lejano con domo radar rojo), **Snowcat de orugas** con física/carga, 24 platos, 3 transformadores, 3 radares y entregas en plataforma | pendiente |
| **9** | **Servidores, Consola y Hashcodes** | `ServerSystem` en sala amplia de servidores, minijuego de reparación, calibración de platos e impresión física de hashcodes en la impresora matricial | pendiente |
| **10** | **Supervivencia y Atmósfera (Stats & Clima)** | `PlayerStats` (hambre, salud sin barra invasiva, sueño, paranoia/estrés), clima alpino (ventisca/niebla/tormenta) afectando nieve, visibilidad y snowcat | pendiente |
| **11** | **Entidades, Radar y Tensión con Indicios (Anti-FNAF)** | Eventos aleatorios y entidades con pistas reales en el mundo/instrumentos/ventanal; cero jumpscares gratuitos ni mecánicas claustrofóbicas de puertas | pendiente |
| **12** | **Modelos Definitivos (OpenCode + Blender MCP)** | Sustituir placeholders por modelos PBR semi-realistas estilizados según las fichas de `ASSETS.md` (`A-01`..`A-09`), LightmapGI e iluminación cálida/fría final | pendiente |
| **13** | **Profundidad (Tier 2): Crafting, Cocina, Cámaras, Módulos** | Cocina/descanso completo, workbench, fotografía, mejoras del snowcat, módulos de estación y POIs del valle | pendiente |
| **14** | **Narrativa y Eventos Avanzados (Tier 3–4)** | Arco semanal, facciones, sueños, secretos del mapa y finales propios | pendiente |
| **15** | **Guardado, Menús, Accesibilidad y Pulido** | `SaveSystem` en disco, menú principal, opciones, subtítulos/accesibilidad, optimización final y build exportada | pendiente |

---

## Detalle del siguiente paso: Hito 7 — Nueva Base en Voladizo y Estación Completa

**Objetivo:** alinear el espacio jugable 1:1 con `references/art-direction/base-exterior.png` y
`references/art-direction/base-interior-signal-room.png`, cerrando el flujo multi-máquina sin
overlays sobrantes.

### Entregables
- **Nuevo `BaseLayout` + `BaseBuilder` (bloqueo jugable amplio, cero claustrofobia, apto para co-op):**
  - Planta Alta en voladizo sobre pilares (`y ≈ 4,5 m`) con **Sala de Control de Señales** espaciosa de techo alto (≥ 4 m), ventanal panorámico inclinado de 3 paños mirando al claro nevado + visibilidad lateral hacia la terraza del dron, mesa cálida con lámpara y consolas distribuidas sin apretar.
  - **Pasillo principal real de ≥ 3,5 m de ancho × 12–16 m de largo** hacia el ala trasera con luz tenue graduada (transición psicológica sin agobio).
  - **Sala de Servidores** amplia y **cerrada con puerta + ventanuco** (para aislar el zumbido de racks).
  - **Zona de Descanso / Dormitorio (litera) y Cocina** cálida con puerta propia + **Baño** adyacente.
  - **Terraza exterior del Dron** sobre el garaje con barandilla, conectada al nivel superior.
  - **Núcleo amplio abierto de escaleras** con barandillas (permite asomarse antes de bajar) conectando **Azotea** (parabólica), Planta Alta, Planta Baja y Sótano (y hueco reservado para posible montacargas/ascensor futuro).
  - **Planta Baja:** Garaje amplio bajo el voladizo con portón enrollable hacia la nieve + **Vestíbulo de Entrada** amplio con taquillas y **Almacén amplio** de suministros + zona alternativa exterior de carga.
  - **Sótano técnico:** único nivel sin ventanas, amplio, con Breaker y Generador auxiliar.
  - **Entorno inmediato:** claro nevado abierto delante de la base y ladera trasera, **sin vallas metálicas**, con iluminación inicial en hora azul / noche lunar fuera y tungsteno cálido dentro.
- **Cierre de máquinas en la Sala de Señales:**
  - **Playback físico:** máquina dedicada con ranura de disco/reproducción y guardado en base de datos, retirando por completo el overlay `SignalConsole`.
  - **Impresora Matricial (primer prototipo funcional):** conectada a señales/sistema para imprimir en papel continuo alertas, estado o hashcodes provisionales.
- **Limpieza de prototipos obsoletos:**
  - Retirar `TestMachine`, `TestItem` y `TestPanel` de `main.tscn`, `main.gd` y `tests/smoke.gd`.

### Criterio de aceptación del Hito 7
- [ ] El jugador aparece en una base con **ala de mando en voladizo** y vista real desde el ventanal hacia el claro nevado y hacia la salida del garaje abajo.
- [ ] Todas las salas y pasillos son amplios (pasillos ≥ 3 m, techos ≥ 3,5 m) y tienen contraste claro entre interior cálido e exterior frío.
- [ ] Las 4 máquinas de la cadena de señal (Coordinates, Descargas, Playback, Procesado) son físicas en la sala + Impresora Matricial activa; `SignalConsole` overlay eliminado.
- [ ] Presupuesto estable: `< 250` draw calls y `< 150k` triángulos visibles.
- [ ] `--headless --import` limpio y `tests/smoke.gd` actualizado en verde.
- [ ] Captura Forward+ exterior e interior verificada visualmente.

---

## Comandos de verificación (local)

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```
