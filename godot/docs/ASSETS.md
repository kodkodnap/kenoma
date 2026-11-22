# Assets — Kenoma

> Todo el arte es original. La dirección visual oficial está fijada en las dos imágenes de
> referencia en `references/art-direction/`:
> - [`../../references/art-direction/base-exterior.png`](../../references/art-direction/base-exterior.png)
> - [`../../references/art-direction/base-interior-signal-room.png`](../../references/art-direction/base-interior-signal-room.png)
>
> **Flujo con OpenCode + Blender MCP:** En fases de arquitectura y mecánicas se usan placeholders
> limpios en Godot con medidas y cotas reales. Cada objeto definitivo pendiente tiene abajo su
> **Ficha para OpenCode / Blender MCP** para modelarlo en local manteniendo una sola línea visual.

## 1. Dirección de arte (Biblia Visual)

- **Estilo:** **PBR semi-realista estilizado** (*Firewatch* en legibilidad de siluetas + *Pacific Drive* en iluminación volumétrica y materialidad retro-industrial de los 80 + *Signalis* en composición y contraste). **Sin fotorrealismo** ni low-poly plano.
- **Arquitectura:** brutalismo de hormigón vertido de los 80, pilares/vigas de acero oscuro, bandejas portacables vistas, ventanales panorámicos inclinados, nieve y carámbanos en cornisas. Sin vallas de eslabones (*chain-link fences*).
- **Paleta oficial:**
  - **Exterior (Hora azul / Noche):** azul pizarra y noche alpina (`#1B2B40`, `#3B5878`), nieve fría, pinos verde-negro desaturado, acento rojo lejano (`#E04646`) en domo radar.
  - **Interior habitable (Cálido):** luz tungsteno/ámbar (`#FFB454`, `#E88B38`), madera cálida, alfombras gastadas en tonos tierra/rojo apagado.
  - **Consolas e industria:** gris pizarra / beige industrial envejecido, fósforo verde (`#63F29B`) y ámbar (`#FFAD42`) en CRTs, acero oscuro.
  - **Pasillos/técnico:** hormigón gris neutro degradando a sombra (`#0B0E13`).
- **Iluminación:** fuerte contraste cálido-vs-frío. Dentro de la base manda la luz cálida acogedora; la tensión nace de pasillos anchos en penumbra y del exterior frío más allá del cristal.

## 2. Presupuesto de rendimiento

| Tipo | Triángulos | Draw calls | Notas |
|---|---:|---:|---|
| Prop pequeño | < 2.000 | 1 | Tazas, papeles, discos, herramientas |
| Prop mediano | < 8.000 | 1–2 | Mesa, impresora matricial, sillas, cajas |
| Máquina principal | < 15.000 | 2–4 | Consolas de señales, servidores, transformadores |
| Vehículo (Snowcat) | < 20.000 | 3–6 | Orugas, cabina, faros, zona de carga |
| Edificio modular | < 45.000 | 8–16 | Base principal en voladizo + garaje |
| Vegetación | < 600 por variante | MultiMesh | Pinos nevados (3–4 variantes + LOD) |
| Entidad | < 12.000 | 1–3 | Rig simple si se anima |

Presupuesto objetivo de escena: **< 150k triángulos visibles, < 250 draw calls, 60 FPS** en GTX 1050.

## 3. Convenciones técnicas para Blender → Godot

- **Escala:** `1 unidad = 1 metro`. Exportar en metros, sin escalar en Godot.
- **Origen:** en la base (`y = 0` del suelo o pivote de giro en partes móviles).
- **Ejes:** Y arriba, −Z adelante, X derecha (al exportar glTF con +Y Up).
- **Partes móviles:** separadas como nodos independientes con pivote correcto (perillas, botones, palancas, puertas, portón de garaje, orugas/faros del snowcat, cabezal de impresora).
- **Pantallas vivas:** nunca usar textura horneada fija para lo que cambia; dejar un bisel/plano guía limpio para montar `SubViewport` (`CrtScreen`) en Godot.
- **Colisiones:** cajas simples en Godot o sufijos `-col` sencillos; nunca usar mallas complejas como collider.
- **Texturas PBR:** albedo, roughness y metallic estilizados (máx. 2048×2048 en héroes/edificio; 512–1024 en props).

## 4. Pipeline y Prompt estándar para OpenCode + Blender MCP / Meshy

### Prompt base consistente (estilo Kenoma)
> *"Stylized semi-realistic PBR 3D asset (Firewatch meets Pacific Drive), 1980s retro-industrial brutalist mountain research equipment, clean readable silhouette, subtle worn painted metal / concrete textures, no photorealism, no logos, game-ready topology, neutral lighting."*

### Pasos
1. Definir medidas y partes móviles en la tabla de especificaciones (Sección 6).
2. Dejar placeholder en Godot a escala real para validar jugabilidad y distancia.
3. Modelar/generar en local con **OpenCode + Blender MCP** (o refinar Meshy en Blender).
4. Exportar `.glb` a `godot/assets/models/` y guardar referencia cruda si aplica en `references/<nombre>/`.
5. Registrar tris, fuente y notas en este archivo.

## 5. Assets ya integrados / en prototipo

| Asset | Archivo | Tris aprox. | Estado | Nota |
|---|---|---:|---|---|
| Consola de Descargas | `scripts/machines/downloads_panel.gd` | < 15k | prototipo funcional | Procedural en código: chasis, CRT, vúmetro, lámpara, 6 controles |
| Consola de Coordinates | `assets/models/coordinates-console.glb` | 13.000 | integrado (revisar estilo PBR final) | 1,24×1,58×1,13 m; CRT curvo vivo en `SubViewport` + controles invisibles |
| Consola de Procesado | `assets/models/signal-processing-console.glb` | 2.960 + CRT | integrado (revisar estilo PBR final) | 1,20×0,62×0,79 m; `CrtScreen` vivo + FASE/CONFIRMAR/LED LOCK |
| Disco de señal | `scenes/items/disk_media.tscn` | < 100 | hecho | 0,24×0,02×0,16 m; placa `Label3D` + LED |
| Bandeja de discos | `scripts/interaction/disk_dock.gd` | 0 | hecho | Ranura física de inserción |
| Prototipos heredados (`TestMachine`, `TestItem`) | `scenes/machines/test_machine.tscn`, `scenes/items/test_item.tscn` | < 500 | **a retirar** | Se eliminan al rehacer la base y actualizar el smoke |

## 6. Fichas de modelos pendientes para OpenCode + Blender MCP

*(Estas fichas definen qué necesita el juego para que OpenCode pueda modelarlo en Blender con medidas reales y coherentes con las 2 imágenes de referencia).*

| ID | Asset | Medidas aprox. (m) | Partes móviles / nodos requeridos | Prioridad |
|---|---|---|---|---|
| `A-01` | **Base modular (Voladizo + Garaje + Pilares)** | Ala mando ~18×12×4,5 m (a y=4,5 m); garaje ~10×12×4 m abajo; pasillo ancho 3 m | Ventanal panorámico inclinado 3 paños, portón enrollable animado del garaje, puertas interiores, plataforma de entregas | **Alta (tras validar bloqueo en Godot)** |
| `A-02` | **Snowcat de orugas** | ~4,2 × 2,4 × 2,5 m | Orugas izq/der, faros delanteros (luz cálida), puerta cabina, caja/portaequipajes trasero para cajas/discos | **Alta (Hito mapa/vehículo)** |
| `A-03` | **Impresora Matricial de Consola** | ~0,75 × 0,55 × 0,45 m (sobre mesa/módulo derecho) | Tira de papel continuo saliendo (`paper_feed`), LED de estado, botón de corte/recoger hoja | **Alta (cierre sala señales)** |
| `A-04` | **Consola de Reproducción (Playback)** | ~1,30 × 1,40 × 0,95 m | Pantalla CRT/espectro (`SubViewport`), dial de volumen/scrub, botón play/stop/guardar, ranura de disco | **Alta (cierre sala señales)** |
| `A-05` | **Mobiliario cálido Sala de Mando** | Mesa 2,2×1,1×0,78 m; lámpara; alfombra 3,5×2,5 m; sillas | Lámpara orientable con foco cálido real | Media |
| `A-06` | **Antena parabólica de azotea y Platos del valle** | Azotea ~4,5 m diámetro; Platos del valle ~8 m sobre base de hormigón | Pedestal fijo + plato giratorio (azimut) + brazo de elevación | Media |
| `A-07` | **Pico lejano con Domo Radar** | Montaña distante + radomo cúpula | Baliza roja superior parpadeante | Media |
| `A-08` | **Pinos nevados y rocas alpinas (kit)** | Pinos 8–16 m; rocas 1–4 m | Estáticos en `MultiMesh` + LOD1/LOD2 | Media |
| `A-09` | **Racks de servidores y Transformadores** | Rack 0,8×2,1×0,9 m; Transformador 3,2×2,6×2,4 m | Puerta/panel frontal, LEDs verde/rojo, palanca de reparación | Media |

## 7. Audio

- Todo el audio es original o sintetizado (sin assets del juego original ni WAV literales de `blender/sounds/` que contienen nombres de VotV).
- Capas clave: viento alpino, nieve bajo pasos, motor diésel y orugas del snowcat, zumbido de transformadores, impresora matricial, relés mecánicos, estática y voz/anomalías sutiles.
