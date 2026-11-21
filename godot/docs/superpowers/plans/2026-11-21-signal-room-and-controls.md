# Signal Room, Real Dials and Physical Disk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make every dial respond to real mouse control, add a visible physical disk that carries signal progress between machines, and dress the signal room with a giant window and lived-in detail.

**Architecture:** `RotaryKnob` becomes the shared manipulation surface; the player suppresses look while a knob is grabbed. `DiskMedia`/`DiskDock` wrap the existing `export_copy`/`sell_disk` data with a physical object. `base_builder.gd` adds the window and props as batched meshes inside the existing signal room footprint.

**Tech Stack:** Godot 4.7.2 Forward+, typed GDScript, `SceneTree` smoke, `MachineMaterials`/`MachineMesh`/`MachineBatch`.

**Spec:** `godot/docs/superpowers/specs/2026-11-21-signal-room-and-controls-design.md`

## Global Constraints

- Godot 4.7.2, Forward+, GDScript tipado, 1 unidad = 1 m, Y arriba, -Z al frente.
- Kenoma es inspiración cercana de Voices of the Void, **no clon**: no copiar assets, texto, audio ni nombres del juego original.
- Values de balance en `data/`; nada de números mágicos de gameplay en código nuevo sin constante `@export`.
- Smoke checks se escriben ANTES del código y se ejecutan con:
  `& "C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --script res://tests/smoke.gd`
- Verificación adicional: `--headless --path godot --import` y `python C:/Users/ibane/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py godot`.
- Commits **sólo** bajo `godot/`, mensaje `hito 5.6: ...`. No tocar el archivo web congelado ni los archivos sin trackear de fase B.
- No reordenar ni renombrar `SignalPanel1..4`; `main.gd` y el smoke dependen del orden lexicográfico.
- Presupuesto: `draws < 250`, `triangles < 150000`.
- Subagentes: usar `model: "opencode/hy4-flash-free"` salvo revisión final, que puede usar un modelo más capaz. Sin worktree: gobernado por Ruling previo (trabajo sin commitear en master).

## Review Focus

- Soltar el dial al perder foco o salir con Esc: dial no debe quedar agarrado ni el cursor visible — Task 1.
- Un disco insertado dos veces o retirado sin insertar: no duplicar ni perder el disco — Task 2.
- Cámara girando mientras se arrastra un dial: rompe la precisión — Task 1.
- Procesar/exportar sin disco insertado: debe fallar con motivo visible — Task 3.
- Ventanal o props rompiendo marcadores o presupuesto de draws — Task 5.

---

### Task 1: Mandos reales compartidos

**Files:**
- Modify: `godot/scripts/machines/controls/rotary_knob.gd`
- Modify: `godot/scripts/player/player.gd`
- Test: `godot/tests/smoke.gd`

**Interfaces:**
- Consumes: `Interactable.focus_changed`, `player.current_interactable`, `InputEventMouseMotion`.
- Produces: `RotaryKnob.grabbed: bool`, `grab()`, `release()`, `turn_by_angle(delta: float) -> void`; `Player._mouse_look_blocked() -> bool`.

- [ ] **Step 1: Write failing tests**
  Añadir checks: enfocar dial y `activate()` → `grabbed == true` y `Input.get_mouse_mode() == MOUSE_MODE_VISIBLE`; enviar dos `InputEventMouseMotion` con `position` a lados opuestos del centro proyectado del dial → `value` cambia > 0.25; `player` con mismo evento no rota (`rotation.y` igual); `release()` → `grabbed == false` y mouse capturado.

- [ ] **Step 2: Run smoke, verify RED**
  Expected: 4 checks nuevos fallan por `grabbed`/métodos ausentes.

- [ ] **Step 3: Implement**
  En `RotaryKnob`: `@export var purpose: String`, `grabbed`, `grab()`, `release()`, `turn_by_angle()`; en `_unhandled_input`, si `grabbed`, usar `event.position` contra `get_viewport().get_camera_3d().unproject_position(global_position)`, aplicar delta angular a `value` y `set_input_as_handled`; rueda = `step`. `activate()` alterna grab/release. Conectar `focus_changed(false)` a `release()`. En `player.gd`: `_mouse_look_blocked()` consulta `current_interactable.get("grabbed", false)`; `ui_cancel` también llama `release()` al dial agarrado.

- [ ] **Step 4: Run smoke, verify GREEN**
  Expected: 0 fallos; checks previos de rueda y raycast siguen pasando.

- [ ] **Step 5: Commit**
  `git add godot/scripts/machines/controls/rotary_knob.gd godot/scripts/player/player.gd godot/tests/smoke.gd && git commit -m "hito 5.6: mandos de dial con arrastre angular"`

### Task 2: Disco físico y bandeja

**Files:**
- Create: `godot/scripts/items/disk_media.gd`, `godot/scenes/items/disk_media.tscn`
- Create: `godot/scripts/interaction/disk_dock.gd`
- Modify: `godot/tests/smoke.gd`, `godot/docs/ASSETS.md`

**Interfaces:**
- Consumes: `Grabbable`, `ItemDef`, `SignalSystem.disks`, `export_copy()`.
- Produces: `DiskMedia.setup(signals: SignalSystem, disk_index: int)`, `refresh_label()`, `disk_index`; `DiskDock.signal disk_inserted(DiskMedia)`, `disk_ejected(DiskMedia)`, `insert(disk)`, `eject() -> DiskMedia`, `disk`.

- [ ] **Step 1: Write failing tests**
  Checks: instanciar `DiskMedia`, `setup()` con un disco exportado → `label.text` contiene `def_id`, `NIVEL` y valor; `DiskDock.insert(disk)` → `dock.disk == disk` y `disk.visible == false`; `eject()` devuelve el mismo disco y `dock.disk == null`; doble `insert` no duplica.

- [ ] **Step 2: Run smoke, verify RED**

- [ ] **Step 3: Implement**
  `DiskMedia extends Grabbable`: `RigidBody3D` con malla de disco (caja 0.24×0.02×0.16 + ranura + LED), `Label3D` con placa, `@export var disk_index`. `DiskDock extends Interactable`: Area3D con shapes, guarda `disk`, emite señales, `activate()` → si tiene disco, `eject()`, si no, busca `DiskMedia` enfocado y lo inserta. Registrar en ASSETS.md.

- [ ] **Step 4: Run smoke, verify GREEN**

- [ ] **Step 5: Commit**
  `git add godot/scripts/items/disk_media.gd godot/scenes/items/disk_media.tscn godot/scripts/interaction/disk_dock.gd godot/tests/smoke.gd godot/docs/ASSETS.md && git commit -m "hito 5.6: disco fisico y bandeja de señales"`

### Task 3: Procesado con disco insertado y progreso visible

**Files:**
- Modify: `godot/scripts/machines/processing_panel.gd`
- Test: `godot/tests/smoke.gd`

**Interfaces:**
- Consumes: `DiskDock`, `DiskMedia`, `SignalSystem.confirm_decode()`, `export_copy()`.
- Produces: `ProcessingPanel.disk_dock: DiskDock`, `progress() -> float`, `status_text() -> String`.

- [ ] **Step 1: Write failing tests**
  Checks: crear panel con sistema y disco insertado en `disk_dock`; sin disco → confirm falla y estado contiene `DISCO`; con disco y fase exacta → confirm sube nivel, emite disco físico nuevo, barra/progreso > 0; retirar disco → panel vuelve a estado sin disco.

- [ ] **Step 2: Run smoke, verify RED**

- [ ] **Step 3: Implement**
  Añadir dock como hijo del panel, reutilizar slot existente. `_on_confirm()` exige `disk_dock.disk != null`; usa `disk_index` para `process_copy`/`export_copy` y actualiza la placa del disco. Añadir barra `Panel`/`ColorRect` en el SubViewport y LED LOCK; estados con texto propio Kenoma. No tocar `decode_stability()` salvo para pasar el índice del disco.

- [ ] **Step 4: Run smoke, verify GREEN**

- [ ] **Step 5: Commit**
  `git add godot/scripts/machines/processing_panel.gd godot/tests/smoke.gd && git commit -m "hito 5.6: Procesado con disco y progreso visible"`

### Task 4: Ranura de venta en la terminal

**Files:**
- Modify: `godot/scripts/core/main.gd`
- Test: `godot/tests/smoke.gd`

**Interfaces:**
- Consumes: `DiskDock.disk_inserted`, `SignalSystem.sell_disk`.
- Produces: `terminal_sell_dock: DiskDock` en el marcador[2].

- [ ] **Step 1: Write failing tests**
  Checks: existe `terminal_sell_dock`; insertar disco → créditos aumentan y `disk.sold == true`; insertar disco ya vendido no aumenta créditos.

- [ ] **Step 2: Run smoke, verify RED**

- [ ] **Step 3: Implement**
  En `_wire_signal_panels`, para markers[2] crear `DiskDock` junto al `SignalPanelInteract`, conectar `disk_inserted` a un `_on_terminal_disk` que busque `disk_index` en `signals.disks`, llame `sell_disk` y haga `eject()`.

- [ ] **Step 4: Run smoke, verify GREEN**

- [ ] **Step 5: Commit**
  `git add godot/scripts/core/main.gd godot/tests/smoke.gd && git commit -m "hito 5.6: ranura de disco en la terminal"`

### Task 5: Sala de señales con ventanal y vida

**Files:**
- Modify: `godot/scripts/world/base_layout.gd`
- Modify: `godot/scripts/world/base_builder.gd`
- Test: `godot/tests/smoke.gd`

**Interfaces:**
- Consumes: `BaseLayout.collect_walls()`, `_box()`, `MachineMaterials`, `MachineBatch`.
- Produces: `SignalWindow` Marker3D, grupo `signal_room_detail` con ≥ 6 nodos.

- [ ] **Step 1: Write failing tests**
  Checks: existe `SignalWindow` con ancho ≥ 8 m en z ≈ -18; `signal_room_detail` ≥ 6; `signal_panel == 4`; draws < 250, tris < 150000.

- [ ] **Step 2: Run smoke, verify RED**

- [ ] **Step 3: Implement**
  Añadir hueco de ventana a la pared sur de `signal` y cristal + marcos con `_box(..., collide=false)` y un fondo frío. Añadir tarima baja, arco de consolas (sin mover marcadores), radar de pared, mesa de discos, papeles, cableado, lámparas ámbar/azul; agrupar en `signal_room_detail` y usar batches.

- [ ] **Step 4: Run smoke, verify GREEN**

- [ ] **Step 5: Commit**
  `git add godot/scripts/world/base_layout.gd godot/scripts/world/base_builder.gd godot/tests/smoke.gd && git commit -m "hito 5.6: sala de señales con ventanal"`

### Task 6: Documentación, captura y cierre

**Files:**
- Modify: `godot/docs/DESIGN.md`, `godot/docs/ASSETS.md`, `godot/docs/TASKS.md`, `godot/docs/ARCHITECTURE.md`, `godot/AGENTS.md`, spec.
- Create: `godot/docs/captures/06_sala_señales.png`, `.import`

**Interfaces:** Consumes: all above.

- [ ] **Step 1: Write failing check**
  Spec acceptance marks only after evidence: smoke count, capture exists, docs mention dial/disk/window.

- [ ] **Step 2: Run verification**
  `--import`, smoke, `check_godot_project.py`, `git diff --check`.

- [ ] **Step 3: Capture**
  Godot windowed Forward+ camera desde (0,4,-6) mirando al ventanal; guardar PNG 1280×720.

- [ ] **Step 4: Commit**
  `git add godot/docs godot/AGENTS.md && git commit -m "hito 5.6: documentar sala, mandos y disco"`

## Final Review

Run review-package from `9a0e260..HEAD` equivalent BASE=`79c8502`, dispatch a fresh reviewer; address Critical/Important in ONE fix pass; collect rulings and deferred minors; delete workspace.
