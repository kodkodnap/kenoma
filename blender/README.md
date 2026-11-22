# VotV — Signal Reception / Processing Console (`SIG_`)

Recreación de **una** máquina del flujo de señales de *Voices of the Void*
(UE4.27, terror analógico soviético): un pupitre de recepción y procesamiento
de señales con CRT de fósforo verde, panel de transformador, lector de
hashcodes y un medidor EMF `comp_emf` como aparato secundario.

Todo está reconstruido desde la descripción, sin extraer nada del `.pak`.
Sin addons, sin texturas externas (todo procedural) y sin descargas.

## Archivos

| Archivo | Contenido |
|---|---|
| `signal_console.blend` | Escena, acción `SignalFlow_12s` (1–288 = 0–12 s a 24 fps), sonidos embebidos en el VSE |
| `signal_console.py` | Script completo de construcción (ejecutable con `blender -b -P signal_console.py`) |
| `sounds/generate_sounds.py` | Generador WAV (solo `wave`/`math`/`random`) |
| `sounds/*.wav` | 7 efectos procedurales |
| `renders/01_power_on.png` | Fotograma 28 — encendido |
| `renders/02_lock.png` | Fotograma 168 — bloqueo y hashcode |
| `renders/03_alert.png` | Fotograma 215 — alerta roja |
| `renders/04_emf_meter.png` | Fotograma 168 — ambos aparatos |

## Verificación

- Bounding box del pupitre: **1.200 × 0.619 × 0.788 m**, apoyado en `z=0`.
- Escena completa (con el medidor EMF): 1.680 × 0.619 × 0.788 m.
- Animación: fotogramas **1–288** a **24 fps** = 12 s exactos.
- 112 objetos, todos con prefijo `SIG_`, repartidos en las colecciones
  `SIG_MESH`, `SIG_SCREENS`, `SIG_UI_OVERLAYS`, `SIG_LIGHTS`, `SIG_SOUND`,
  `SIG_RIG`.
- Acción única `SignalFlow_12s` con 41 slots (objetos, materiales y nodos).

## Estructura de la escena

| Colección | Contenido |
|---|---|
| `SIG_MESH` | Chasis, frontal, rejillas, óxido, diales, interruptores, cables, carcasas |
| `SIG_SCREENS` | CRT (tres variantes de brillo mutuamente exclusivas), gráfico sinusoidal, barra de nivel |
| `SIG_UI_OVERLAYS` | Textos emisivos: mensajes de estado, hashcode, alertas |
| `SIG_LIGHTS` | Iluminación fría de relleno, resplandor del CRT, luz roja de alerta |
| `SIG_SOUND` | Yunes vacíos con custom properties que documentan cada disparador de sonido |
| `SIG_RIG` | Cámaras, root del deck inclinado, root del medidor EMF |

## Mecánica → objeto → sonido → fotogramas

| # | Estado / mecánica | Fotogramas (s) | Objetos principales | Sonido (VSE) |
|---|---|---|---|---|
| 1 | **Apagado → encendido.** El CRT parpadea (variantes dim/normal/bright), el zumbido sube. | 1–48 (0–2) | `SIG_switch_power`, `SIG_crt_screen*`, `SIG_led_power`, `SIG_light_crt_glow` | `sig_relay_click.wav` @2, `sig_transformer_hum.wav` @1, `sig_crt_whine.wav` @1 |
| 2 | **Sintonía.** Gira `SIG_dial_freq` y `SIG_jog_tune`; sube el ruido, la aguja vibra y la onda se agita. Mensaje `It is not the time` / `No hashcodes found: try again next day`. | 48–144 (2–6) | `SIG_dial_freq`, `SIG_jog_tune`, `SIG_mat_crt_green` (W del ruido), `SIG_mat_sine_graph`, `SIG_emf_needle` | `sig_static_filtered.wav` @48–144 |
| 3 | **Bloqueo.** LED verde LOCK, ranura y CRT muestran el hashcode `482913`. | 144–192 (6–8) | `SIG_led_lock`, `SIG_ui_hash_crt`, `SIG_ui_hash_lock`, `SIG_slot_housing` | `sig_relay_click.wav` @145, `sig_beep_880.wav` @145 |
| 4 | **Alerta.** Luz roja intermitente y alarma; `!!!Automatic Alert System!!!` → `Invalid entity group` → `The Creature is currently active`. | 192–240 (8–10) | `SIG_led_alert`, `SIG_light_alert_red`, `SIG_switch_alert`, `SIG_ui_alert_*` | `sig_relay_click.wav` @193, `sig_alarm_two_tone.wav` @193–240 |
| 5 | **Apagado.** La imagen del CRT se colapsa a un punto (`scale` → 0.008) y se corta la corriente. | 240–288 (10–12) | `SIG_switch_power`, `SIG_crt_screen*`, `SIG_led_power` | `sig_relay_click.wav` @241, `sig_station_turnoff.wav` @241–274 |
| EXTRA | **Medidor EMF** (`comp_emf`). Aguja proporcional a la cercanía de la entidad; pitidos cada 12 fotogramas. | 60–240 (2.5–10) | `SIG_emf_needle`, `SIG_emf_led`, `SIG_emf_body` | `sig_beep_880.wav` @60,72,…,228 |

### Tabla de señales

El hashcode de ejemplo `482913` representa una entrada de `main/datatables/list_signals`.
El rango 2–6 s recorre frecuencias de esa tabla; al acercarse a una frecuencia
válida baja el ruido y la onda se vuelve limpia (fotograma 144).

### Custom properties de disparo

Los objetos llevan propiedades que indican qué sonido disparan:

- `SIG_cabinet_body`: `sound_trigger = sig_transformer_hum.wav`, `sound_start_frame = 1`, `sound_end_frame = 240`.
- `SIG_crt_screen`: `sound_trigger = sig_crt_whine.wav`, 1–240.
- `SIG_dial_freq`: `sound_trigger = sig_static_filtered.wav`, 48–144.
- `SIG_led_lock`: `sound_trigger = sig_beep_880.wav`, desde 145.
- `SIG_led_alert`: `sound_trigger = sig_alarm_two_tone.wav`, 193–240.
- `SIG_switch_power`: `sound_trigger_on = sig_relay_click.wav`, `sound_trigger_off = sig_station_turnoff.wav`.
- `SIG_emf_meter_root`: `sound_trigger = sig_beep_880.wav`, 60–240.

Los nodos vacíos de `SIG_SOUND` (`SIG_sfx_*`) repiten la misma información con
`description` legible.

## Sonidos

Generados con `python sounds/generate_sounds.py` (stdlib puro, 44.1 kHz,
mono, 16 bit):

| WAV | Descripción |
|---|---|
| `sig_static_filtered.wav` | Estática filtrada (paso bajo + realce), envolvente irregular |
| `sig_transformer_hum.wav` | Zumbido 50 Hz + armónicos 100/150/250 Hz con oscilación lenta |
| `sig_crt_whine.wav` | Agudo ~15.7 kHz del CRT a bajo volumen (`volume = 0.30` en el VSE) |
| `sig_relay_click.wav` | Clic de relé: doble transitorio con anillo metálico |
| `sig_beep_880.wav` | Beep 880 Hz con armónico 1760 Hz |
| `sig_alarm_two_tone.wav` | Alarma two-tone 600/900 Hz, 8 segmentos de 0.25 s |
| `sig_station_turnoff.wav` | Descendente exponencial de 1200 Hz a ~38 Hz + ruido |

Todos están cargados en el VSE (`scene.sequence_editor.strips.new_sound()`)
en canales separados y alineados a los fotogramas indicados.

## Nota técnica sobre el parpadeo

En este Blender 5.2 las curvas de animación de *sockets de material* se
guardan en la acción pero no se evalúan al cambiar de fotograma. Para que el
parpadeo se vea, el CRT usa tres planos emisivos (`SIG_crt_screen`, `_dim`,
`_bright`) con `hide_render` animado de forma mutuamente exclusiva: en cada
fotograma hay exactamente **un** plano visible. Los LEDs y las luces usan
animación de objetos, que sí se evalúa. Las curvas de emisión de material
permanecen en `SignalFlow_12s` como registro de la intención.

## Regenerar

```bash
python blender/sounds/generate_sounds.py
blender -b -P blender/signal_console.py
```

O, con el MCP de Blender activo en el puerto 9876, ejecutar el contenido de
`signal_console.py` mediante `execute_blender_code`. El script recrea la
escena desde cero, renderiza los cuatro PNG y guarda el `.blend`.
