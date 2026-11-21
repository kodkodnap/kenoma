# Signal Processing Console (hito 5.5 fase D) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convertir `SignalPanel4` en la máquina física de Procesado: girar una perilla estabiliza la onda del CRT en tiempo real y el botón confirma el copiado al siguiente nivel, con geometría exportada desde `blender/signal_console.blend` y contenido original de Kenoma.

**Architecture:** Se exporta un GLB limpio de Blender (sin planos de CRT ni textos literales) y se instancia en un `ProcessingPanel` construido en código, siguiendo el patrón de `CoordinatesPanel`: `CrtScreen` dentro de un `SubViewport` y controles `visible=false` alineados a la perilla/ranura horneadas. La lógica de decodificación va en `SignalSystem` (puro, sin nodos) y alimenta `CrtScreen.stability`, que ya tiene el jitter `lerpf(0.16,0.01,...)`; no se escribe un nuevo dibujante.

**Tech Stack:** Godot 4.7.2 Forward+, GDScript tipado, glTF 2.0, Blender 5.2.3 (`bpy.ops.export_scene.gltf`), smoke `SceneTree`.

**Spec:** `docs/superpowers/specs/2026-11-21-signal-processing-console-design.md`

## Global Constraints

- Kenoma: VotV es **inspiración muy cercana, no clon**. No copiar assets, código, texturas, audio, textos ni nombres de archivo originales; regenerar todo el contenido literal del `.blend`.
- 1 unidad = 1 m, Y arriba, -Z al frente, origen en la base; `Forward+`; GDScript tipado.
- Todo ajuste numérico vive en `data/balance.tres` / `data/signals/catalog.json`; nada de números mágicos en `processing_panel.gd`.
- Smoke checks **antes** del código que los satisface; verificación con:
  - `$GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"`
  - `"$GODOT" --headless --path godot --import`
  - `"$GODOT" --headless --path godot --script res://tests/smoke.gd`
- Skills obligatorias antes de tocar `godot/`: `godot-gdscript` (cualquier `.gd`), `godot-gdscript-patterns` (`scripts/core/**`), `godot-nodes-scenes` (`scenes/**`, instanciación), `godot-ui-control` (`scripts/ui/**`).
- Decisiones cerradas del spec: procesar **la última copia guardada**; `decode_target` como campo de `catalog.json`; "avanzar" = habilitar exportación a disco y encender LED LOCK, sin transición de escena; confirmar ejecuta `copy_level+1` respetando `PROCESS_THRESHOLDS`.
- Commits solo de `godot/`, mensaje `hito 5.5: ...`.

## Review Focus

- **Sin copia guardada:** pulsar Confirmar con `saved_count()==0` no debe crashar; `confirm_decode()` devuelve `false` y el LED sigue apagado. → Task 2 smoke.
- **Perilla lejos del objetivo:** `decode_stability()` debe ser 0 con `abs(decode_tuning-decode_target)` grande; no debe encenderse LOCK por estar cerca del rango. → Task 2 smoke.
- **Calidad insuficiente:** con estabilidad alta pero `quality < PROCESS_THRESHOLDS[level-1]`, `process_copy` falla y no se incrementa `level`. → Task 2 smoke.
- **Nombres del GLB distintos:** `find_child("SIG_dial_freq", ...)` puede fallar si el exportador renombra; los controles invisibles deben caer a constantes medidas y el smoke debe detectar el caso. → Task 1 + Task 3 smoke.
- **Terminal con una pestaña:** reducir a 1 no debe romper el acceso a Reproducción desde la máquina física; `open_tab(0)` sigue funcionando. → Task 4 smoke.

---

### Task 1: Exportar el GLB limpio desde Blender

**Files:**
- Create: `assets/models/signal-processing-console.glb` (+ `.import` generado por Godot)
- Create: `tools/export_processing_console.py` (script de exportación, dentro de `godot/tools` o junto al `.blend`; el spec permite guardarlo en `blender/`)
- Modify: `docs/ASSETS.md` (alta del modelo)

**Interfaces:**
- Consumes: `blender/signal_console.blend`, objects `SIG_dial_freq`, `SIG_jog_tune`, `SIG_slot_housing`, `SIG_crt_bezel`, `SIG_socket*`.
- Produces: GLB con la rueda central y la ranura como nodos localizables por nombre; sin `SIG_crt_screen*`, sin objetos `FONT` (textos literales).

- [ ] **Step 1: Escribir el script de exportación**

`export_processing_console.py` (ejecutarse con `blender --background blender/signal_console.blend --python <script>`): borrar `SIG_crt_screen`, `SIG_crt_screen_dim`, `SIG_crt_screen_bright` y todos los objetos tipo `FONT`; exportar el resto con `bpy.ops.export_scene.gltf(filepath=..., export_format='GLB', use_selection=False)`. Imprimir por stdout la lista de nodos `SIG_dial_freq`, `SIG_jog_tune`, `SIG_slot_housing` y sus `matrix_world.translation` para documentar el alineamiento.

- [ ] **Step 2: Ejecutar la exportación y el import de Godot**

Run: `blender --background blender/signal_console.blend --python blender/export_processing_console.py` y después el `--import` de Godot de Global Constraints.
Expected: existe `assets/models/signal-processing-console.glb` y su `.import`; el log lista los tres nodos.

- [ ] **Step 3: Añadir el smoke que fija el contrato del GLB**

En `tests/smoke.gd`, bloque nuevo: cargar `load("res://assets/models/signal-processing-console.glb") as PackedScene`, instanciar, `_check(inst != null, ...)`, `_check(inst.find_child("SIG_dial_freq", true, false) != null, "rueda central exportada", ...)`, `_check(inst.find_child("SIG_slot_housing", true, false) != null, "ranura exportada", ...)`, `_check(inst.find_child("SIG_crt_screen", true, false) == null, "sin CRT literal", ...)`.

- [ ] **Step 4: Verificar que falla y que luego pasa**

Run: smoke de Global Constraints.
Expected: primero FAIL (recurso no existe); tras Task 1 Step 2, PASS.

- [ ] **Step 5: Commit**

`git add godot/assets/models godot/tools godot/docs/ASSETS.md godot/tests/smoke.gd && git commit -m "hito 5.5: exportar GLB de Procesado y fijar contrato en smoke"`

---

### Task 2: Lógica pura de decodificación + tests

**Files:**
- Modify: `scripts/core/signal_system.gd` (~L143, cerca de `alignment()`), `scripts/core/signal_def.gd` (L5-33), `data/signals/catalog.json` (8 entradas), `scripts/core/game_balance.gd` (nuevo `@export_group("Procesado")`)
- Test: `tests/smoke.gd` (bloque nuevo tras el de fase B, ~L748)

**Interfaces:**
- Consumes: `SignalDef`, `PROCESS_THRESHOLDS`, copies en `downloads[]` con claves `def/id/quality/level/saved`.
- Produces:
  - `SignalSystem.decode_tuning: float` (0..1,edefault 0.0)
  - `SignalSystem.decode_sensitivity: float` y `SignalSystem.decode_ready_stability: float` (inyectados desde `GameBalance`)
  - `SignalSystem.configure_balance(balance: GameBalance) -> void`
  - `SignalSystem.set_decode_tuning(value: float) -> void`
  - `SignalSystem.decode_stability() -> float` = `clampf(1.0 - absf(decode_tuning - selected_def.decode_target) * decode_sensitivity, 0.0, 1.0)` (0 si `selected_def == null`)
  - `SignalSystem.last_saved_index() -> int` (índice de la última copia con `saved==true`, o -1)
  - `SignalSystem.confirm_decode() -> bool` (false si no hay copia, estabilidad < umbral o `process_copy` falla; si no, `process_copy(idx, copy_level(idx)+1)`)
  - `SignalDef.decode_target: float` leído por `from_dict()` con `data.get("decode_target", 0.5)`
  - `GameBalance.decode_stability_threshold: float = 0.78`, `GameBalance.decode_sensitivity: float = 2.5`

- [ ] **Step 1: Escribir los smoke checks (deben fallar)**

Bloque: `_check(system.decode_stability() >= 0.0, ...)`, con `system.select_def(def_de_target_0_5)` y `set_decode_tuning(0.5)` → `_check(is_equal_approx(system.decode_stability(), 1.0), ...)`, con tuning 0.0 → `_check(system.decode_stability() == 0.0, ...)`, `_check(system.last_saved_index() == -1, ...)` antes de guardar, y `_check(system.confirm_decode() == false, ...)`. Añadir target `decode_target` a todas las entradas de `catalog.json` (valores 0.25..0.85, distintos entre sí).

- [ ] **Step 2: Ejecutar el smoke y confirmar FAIL**

Run: smoke de Global Constraints. Expected: FAIL en `decode_stability` / `last_saved_index` no definidos.

- [ ] **Step 3: Implementar la lógica**

Añadir los campos y métodos de Interfaces en los archivos indicados. `configure_balance` asigna los dos floats; `main.gd` lo llamará en Task 4. No crear señales nuevas: el panel consulta `decode_stability()` cada frame.

- [ ] **Step 4: Ampliar los checks de caso límite y pasar**

Añadir: guardar una copia con `quality >= PROCESS_THRESHOLDS[0]`, tuning en el target, `_check(system.confirm_decode() == true, ...)`, `_check(system.copy_level(idx) == 1, ...)`; luego bajar `quality` por debajo del umbral y `_check(system.confirm_decode() == false, ...)`. Run smoke. Expected: PASS, 245 + N checks verdes.

- [ ] **Step 5: Commit**

`git add godot/scripts/core godot/data/signals/catalog.json godot/data/balance.tres godot/tests/smoke.gd && git commit -m "hito 5.5: decodificacion pura y smoke de estabilidad"`

---

### Task 3: ProcessingPanel físico (GLB + CRT + controles invisibles)

**Files:**
- Create: `scripts/machines/processing_panel.gd`
- Modify: `docs/ASSETS.md` (registro del panel)
- Test: `tests/smoke.gd` (bloque de panel)

**Interfaces:**
- Consumes: Task 1 GLB; Task 2 `SignalSystem` API; `CrtScreen` (`stability`, `signal_level`, `powered`); `RotaryKnob` (`value_changed(float)`, exports `min_value/max_value/step/label_text`), `PushButton` (`pressed`), `MachineBatch`/`MachineMaterials` (ya existentes).
- Produces: `class_name ProcessingPanel extends Node3D`, con `setup(system: SignalSystem) -> void`, `get_decode_knob() -> RotaryKnob`, `get_confirm_button() -> PushButton`, `get_crt() -> CrtScreen`, `is_locked() -> bool`.

- [ ] **Step 1: Smoke del panel (falla)**

Bloque: instanciar `ProcessingPanel.new()`, añadirlo a un `Node3D` del smoke, `setup(system)`; checks: `panel != null`, `panel.get_decode_knob() != null`, `panel.get_decode_knob().visible == false`, `panel.get_confirm_button().visible == false`, `panel.get_crt() != null`, `panel.is_locked() == false`.

- [ ] **Step 2: Verificar FAIL** con el smoke.

- [ ] **Step 3: Implementar el panel**

Seguir `coordinates_panel.gd` L80-201: `const CONSOLE_MODEL := preload("res://assets/models/signal-processing-console.glb")`; instanciar GLB; `SubViewport` + `CrtScreen` + malla curva con textura del viewport; crear `RotaryKnob` con `min_value=0.0, max_value=1.0, step=0.005, label_text="FASE"` y `PushButton` con `label_text="CONFIRMAR"`, ambos `visible=false`, posicionados desde `find_child("SIG_dial_freq"/"SIG_slot_housing")` (constantes de respaldo medidas en Task 1). Conectar `value_changed → system.set_decode_tuning`, `pressed → _on_confirm` (usa `system.confirm_decode()`). Cada frame: `crt.stability = system.decode_stability()`, `crt.signal_level = 1.0`, y LED LOCK = `system.decode_stability() >= system.decode_ready_stability` (emisión de `MachineMaterials.led(Color.GREEN)` o malla propia). Decorativos (diales laterales, switches, EMF) se fusionan con `MachineBatch` como en fase A; no añadir textos ni sonidos literales.

- [ ] **Step 4: Verificar PASS** con el smoke. Añadir check de interacción simulada: `knob.sync_value(0.5)` → `_check(is_equal_approx(system.decode_tuning, 0.5), ...)`; `_on_confirm` vía `confirm_button.activate()` → `_check(panel.is_locked() == true, ...)` cuando haya copia guardada y calidad suficiente.

- [ ] **Step 5: Commit**

`git add godot/scripts/machines/processing_panel.gd godot/tests/smoke.gd godot/docs/ASSETS.md && git commit -m "hito 5.5: panel de Procesado con CRT y controles invisibles"`

---

### Task 4: Cableado en main.gd y reducción de la terminal

**Files:**
- Modify: `scripts/core/main.gd` (L35, L116-149), `scripts/world/base_builder.gd` (L326-334), `scripts/ui/signal_console.gd` (L6, L134-138, L185-221), `tests/smoke.gd` (L630 y bloque de panel en escena)

**Interfaces:**
- Consumes: Task 3 `ProcessingPanel`; `GameBalance` cargado desde `res://data/balance.tres`.
- Produces: `SignalPanel4` contiene un nodo `ProcessingPanel`; `signal_console.tab_count() == 1`.

- [ ] **Step 1: Smoke de cableado (falla)**

Cambiar L630 a `_check(console.tab_count() == 1, "una sola pestaña en terminal", failures)`. Añadir: `var processing := (panels[3] as Node3D).get_node_or_null("ProcessingPanel") as ProcessingPanel`; `_check(processing != null, "panel de Procesado físico", failures)`; `_check((panels[3] as Node3D).get_node_or_null("SignalPanelInteract") == null, "sin overlay en Procesado", failures)`; `_check(console.open_tab(0) == true or console.current_tab() == 0, ...)`.

- [ ] **Step 2: Verificar FAIL**.

- [ ] **Step 3: Implementar**

En `main.gd`: tras `signals.setup(...)`, `signals.configure_balance(load("res://data/balance.tres") as GameBalance)`; en `_wire_signal_panels()`: quitar el `Interactable` de `i==3`, crear `ProcessingPanel.new()`, `marker.add_child(processing)`, `processing.setup(signals)`; dejar `tabs=[-1,-1,-1,0]` (o equivalente que elimine la pestaña de Procesado). En `base_builder.gd`: no crear caja rellena para el panel 4. En `signal_console.gd`: `TAB_NAMES := ["REPRODUCCIÓN"]`, quitar rama muerta `_build_processing`.

- [ ] **Step 4: Verificar PASS** con el smoke completo (debe seguir en verde el resto de hitos).

- [ ] **Step 5: Commit**

`git add godot/scripts/core/main.gd godot/scripts/world/base_builder.gd godot/scripts/ui/signal_console.gd godot/tests/smoke.gd && git commit -m "hito 5.5: conectar Procesado al marcador 4 y terminal de una pestaña"`

---

### Task 5: Documentación, captura Forward+ y cierre

**Files:**
- Modify: `docs/DESIGN.md` (L59, L96, L113-123), `docs/ASSETS.md` (L64-79), `docs/TASKS.md` (L20, L303, L322, L346+, L375-378), `docs/ARCHITECTURE.md` (L84-99), `AGENTS.md` (estado hito 5.5 y cuenta del smoke), `docs/superpowers/specs/2026-11-21-signal-processing-console-design.md` (marcar criterios de aceptación)

**Interfaces:**
- Consumes: Tasks 1-4 terminados y smoke verde.
- Produces: documentación actualizada y una captura de la máquina en edición.
- [ ] **Step 1: Actualizar docs** con la decisión de que los textos/audio del `.blend` se regeneraron como contenido original de Kenoma, el inventario del GLB y el nuevo flujo de sesión: escanear → descargar → guardar → afinar FASE hasta LOCK → CONFIRMAR → exportar disco.
- [ ] **Step 2: Verificación final**: `--import`, smoke completo y conteo de `_check` igual al documentado; comprobar en el editor que `SignalPanel4` muestra el CRT con onda inestable/estable al girar la perilla.
- [ ] **Step 3: Captura Forward+**: abrir `main.tscn`, situar la cámara frente a `SignalPanel4`, captura PNG en `docs/captures/` (o ruta que ya use el proyecto).
- [ ] **Step 4: Commit**

`git add godot/docs godot/AGENTS.md && git commit -m "hito 5.5: documentar Procesado, captura y cierre"`

## Self-review

- Spec coverage: los 6 criterios del design doc están repartidos en Tasks 1-5; las 4 decisiones cerradas aparecen en Global Constraints y se aplican en Task 2 (última copia, target en catálogo, LOCK+exportación, `copy_level+1`).
- Cada smoke se escribe antes del código que lo satisface (AGENTS.md).
- Tipos consistentes:`decode_tuning: float`, `decode_stability() -> float`, `confirm_decode() -> bool`, `setup(system: SignalSystem)` se usan igual en Task 2, 3 y 4.
- Review Focus cubierto en Tasks 1-4 con checks explícitos.
- Riesgo residual: el exportador glTF puede renombrar nodos; Task 1 imprime los nombres y Task 3 prevé constantes de respaldo.
