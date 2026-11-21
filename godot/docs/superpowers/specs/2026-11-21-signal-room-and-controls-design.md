# Especificación: sala principal de señales, mandos reales y disco físico

> Estado: aprobada por el usuario (2026-11-21). Inspiración: Voices of the Void, **no clon**.

## 1. Intento y porqué

El usuario no entiende el funcionamiento de la consola de Procesado: pulsar E apenas mueve el dial de 0.0 a 0.1 (`RotaryKnob.activate()` suma `step = 0.005`), los diales no tienen un propósito legible y la sala se siente «cuadrada y sin vida». Quiere:

1. Mandos con funcionamiento real e inmediato.
2. La sala principal de señales armada «bien», con un **ventanal gigante** que se mantiene.
3. Un disco físico que lleve la señal y el progreso, que se inserte y se saque de las máquinas, como en el juego original.

## 2. Alcance

Dentro:
- Todos los `RotaryKnob` del juego ganan control por arrastre angular y rueda; el sensor de la cámara se desactiva mientras se manipula un dial.
- Cada dial existente lleva una etiqueta visible de su propósito en el prompt/HUD.
- La consola de Procesado muestra progreso visual real (barra/LED/estado) y fallos con motivo.
- Disco físico `Grabbable` con el contenido visible (señal, nivel, valor), bandeja de discos y ranuras de inserción en Procesado y en la terminal.
- Sala `signal`: ventanal gigante en la pared sur (z=-18), consolas en arco, tarima baja, radar de pared, mesa de discos, cableado, papeles, iluminación cálida/fría contrastada.

Fuera:
- Reconstruir toda la base (sólo sala `signal`).
- Fase C (Playback físico completo) y fase E (quitar overlay) del hito anterior.
- Copiar textos, audio, modelos o nombres literales de Voices of the Void.
- Cambiar el mapa de marcadores `SignalPanel1..4` (smoke y `main.gd` dependen del orden).

## 3. Decisiones cerradas

1. **Dial:** modo A. Al enfocar y pulsar E se «agarra»: `Input.set_mouse_mode(VISIBLE)`, se proyecta el centro del dial a pantalla, se mide el ángulo del cursor alrededor de ese centro y el delta angular mueve `value` de forma continua y en ambos sentidos. E otra vez o Esc suelta y recaptura. La rueda sigue siendo ajuste fino (`step`). La cámara no gira mientras el dial está agarrado porque el mouse look exige `MOUSE_MODE_CAPTURED`.
2. **Propósito de cada dial:** se muestra en el prompt (`label_text`) y en el estado del panel; no se añaden diales nuevos salvo el necesarios para la ranura.
3. **Disco:** se reutiliza `Grabbable` + `ItemDef` + el patrón de `test_item.tscn`. El disco lleva `disk_index` y una placa `Label3D` con `def_id`, nivel y valor; un LED parpadea si tiene señal. Se guarda en una bandeja de la sala; se inserta en la ranura de Procesado para trabajar y en la de la terminal para vender.
4. **Característica del disco:** el disco se crea cuando `export_copy()` tiene éxito; el objeto físico es la fuente de verdad visible del disco exportado. Si se inserta en Procesado, el dial FASE y CONFIRMAR operan sobre `disks[disk_index]`, no sobre la última copia guardada.
5. **Sala:** se mantiene la huella de la sala (x=-14,z=-18,w=28,d=16) y los marcadores; el ventanal se abre en la pared sur y se rellena con cristal semitransparente de `MachineMaterials.glass()`, marcos metálicos y una vista fría detrás. Consolas en arco suave alrededor del ventanal sin mover sus marcadores más de lo que permita el raycast del smoke.
6. **Estilo:** original Kenoma — gris/verde desgastado, ámbar cálido en interiores, azul frío del exterior, etiquetas propias en español, nada de texto/audio de VotV.

## 4. Criterios de aceptación

- [x] Con E se agarra un dial y el movimiento circular del ratón lo gira en ambos sentidos, de 0 a max, sin spamear E. Evidencia: smoke «E captura el dial», «el arrastre angular mueve el dial», «el arrastre no salta al cruzar el eje -X».
- [x] La cámara no gira mientras se manipula un dial; E/Esc sueltan y devuelven el control. Evidencia: smoke «arrastrar el dial no gira la cámara», «release() suelta el dial», «ui_cancel» y `_can_recapture_mouse()`.
- [x] La rueda ajusta fino y el prompt dice qué hace cada dial. Evidencia: smoke «la rueda gira la perilla» y `RotaryKnob.purpose` en el prompt.
- [x] Procesado muestra barra/LED/estado del progreso y motivos de fallo. Evidencia: smoke «el progreso del disco avanza al procesar», `progress()`, `status_text()` y LED LOCK.
- [x] Existe un disco físico con placa visible; se puede coger, insertar y retirar. Evidencia: smoke «la etiqueta del disco muestra id, nivel y valor», «insert guarda el disco», «eject devuelve el disco».
- [x] Procesar y exportar escriben en el disco insertado; el terminal lo acepta para vender. Evidencia: smoke «la placa del disco refleja el nivel procesado», «activar la ranura inserta el disco sostenido», «vender en la terminal paga créditos».
- [x] La sala tiene ventanal gigante visible y al menos 6 detalles nuevos (tarima, arco, radar, mesa, papeles, cableado). Evidencia: smoke «ventanal de señales de al menos 8 m en z=-18», «detalle de la sala de señales con al menos 6 nodos» (9 `Marker3D`) y captura `docs/captures/06_sala_senales.png`.
- [x] Smoke ≥ 281 checks, 0 fallos; draws < 250 y tris < 150000; captura Forward+ nueva. Evidencia: `OK=334`, `FALLO=0`, `ERRORS=0`, `EXIT=0`; 244 draws y 52266 tris; captura Forward+ a 1280×720.

## 5. Riesgos

- El ratón visible puede quedar visible si el jugador sale del juego con un dial agarrado → release explícito en `focus_changed(false)` y en `ui_cancel`.
- Reordenar marcadores rompe el smoke → no reordenar.
- El cristal puede exponer el vacío exterior → mantener suelo/techo y poner un fondo frío detrás.
- Más mallas pueden subir draws → usar `MachineBatch`/`MultiMesh` y verificar presupuesto.

## 6. Verificación

```powershell
$GODOT = "C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
& $GODOT --headless --path godot --import
& $GODOT --headless --path godot --script res://tests/smoke.gd
python C:/Users/ibane/.agents/skills/godot-nodes-scenes/scripts/check_godot_project.py godot
```

## 7. Cierre (Task 6, 2026-11-21)

Los ocho criterios quedan verificados con `OK=334`, `FALLO=0`, `ERRORS=0`, `EXIT=0` en HEAD `083d41b`
(`--headless --path godot --script res://tests/smoke.gd`), con presupuesto de 244 draws y 52266
triángulos, por debajo de los límites de 250 y 150000. Las pruebas de lógica y de entrada se ejecutan
en headless; la **verificación visual real** se documenta con la captura
`docs/captures/06_sala_senales.png`: render Forward+ (Vulkan, GTX 1050) a 1280×720 donde se ven el
ventanal de 10 m, las consolas en arco y los detalles de la sala. El modo de ratón y el giro de cámara
en una partida real no son observables en headless y quedan comprobados por el código y la captura.
Los hallazgos Minor diferidos están registrados en el ledger del SDD.
