# Assets — Ruido de Fondo

> Todo el arte es original. No se importan modelos, texturas, audio ni animaciones del juego de
> referencia. La estética se define aquí y se aplica a todos los modelos generados o comprados con
> licencia compatible.

## 1. Dirección de arte

- **Estilo:** low-poly estilizado, formas legibles, superficies planas y desgaste pintado, no fotorrealismo.
- **Paleta base:** beige industrial, verde oliva, gris hormigón, naranja de seguridad, azul noche.
- **Iluminación:** interiores cálidos y fluorescentes; exterior azul, niebla y sodio.
- **Silueta:** las máquinas deben reconocerse a 10 m; los controles, a 2 m.
- **Coherencia:** un solo set de materiales; nada de estilos mezclados sin motivo.

## 2. Presupuesto

| Tipo | Triángulos | Draw calls | Notas |
|---|---:|---:|---|
| Prop pequeño | < 2.000 | 1 | Latas, herramientas, comida |
| Prop mediano | < 8.000 | 1–2 | Cajas, sillas, monitores |
| Máquina principal | < 15.000 | 2–4 | Paneles, servidores, transformadores |
| Edificio modular | < 30.000 | 4–8 | Base y platos |
| Vegetación | < 500 por variante | MultiMesh | 3–4 variantes + LOD |
| Entidad | < 12.000 | 1–3 | Rig simple si se anima |

Presupuesto de escena: **< 150k triángulos visibles, < 250 draw calls, 60 FPS** en GTX 1050.

## 3. Convenciones

- 1 unidad = 1 metro. Exportar en metros, sin escalar en Godot.
- Origen en el punto de apoyo o en el eje de rotación; nunca en el centro de la geometría si el objeto
  se apoya en el suelo.
- Ejes: Y arriba, −Z adelante, X derecha.
- Colisión incluida o generada con `-col`; las partes móviles van separadas y con su propio origen.
- Nombres: `sm_` estático, `sm_` con `_lod1`, `_lod2`; `sk_` esqueleto; `ui_` pantalla.
- Materiales PBR simples: albedo, roughness, metallic; emisión solo en pantallas y LEDs.
- Sin texturas mayores de 2048×2048; los props pequeños usan 512 o color plano.

## 4. Pipeline

1. **Placeholder** con CSG o primitivas para que el sistema sea jugable.
2. **Bloqueo** de escala y colisión en Godot.
3. **Búsqueda** en Poly Haven / Poly Pizza / assets con licencia compatible.
4. **Generación** con Blender MCP o Hyper3D solo si no hay un asset adecuado.
5. **Limpieza:** reducir polígonos, corregir normales, aplicar transformaciones, separar partes móviles.
6. **Exportar GLB** a `assets/models/`.
7. **Importar** en Godot, generar LOD y colisión.
8. **Registrar** en este documento: nombre, fuente, prompt, tris, autoría/licencia.
9. **Revisar** en el juego a escala real y con la iluminación final.

### 4.1 Reglas de generación

- Un prompt = un objeto, no una escena completa.
- Prompt consistente: “low-poly stylized [objeto], muted industrial palette, clean topology, game-ready,
  no text, no logos, neutral pose”.
- Si la topología está rota, la escala es absurda o el origen es inútil, se regenera.
- Los objetos con botones, palancas o puertas necesitan piezas separadas.
- No se usa IA generativa para copiar el diseño de un asset existente.

## 5. Registro de assets

### 5.1 Placeholders actuales

| Asset | Archivo | Tris aprox. | Estado | Nota |
|---|---|---:|---|---|
| Suelo de prueba | `scenes/main.tscn` | < 100 | placeholder | 40×40 m |
| Paredes de prueba | `scenes/main.tscn` | < 200 | placeholder | 4 paredes |
| Cajas | `scenes/main.tscn` | < 100 | placeholder | 3 cajas |
| Jugador | `scenes/player/player.tscn` | 0 | provisional | Cápsula invisible |
| Máquina de prueba | `scenes/machines/test_machine.tscn` | < 500 | prototipo | Se rehace en hito 2/3 |

### 5.2 Assets objetivo

| Asset | Hito | Fuente | Tris | Estado |
|---|---:|---|---:|---|
| Base modular (paredes, puertas, ventanas) | 3 | Propio / Poly Haven | < 30k | pendiente |
| Panel de señal (4 variantes) | 5 | Propio | < 15k | pendiente |
| Servidor (30 + 24) | 3/8 | Propio | < 8k | pendiente |
| Transformador | 4 | Propio | < 15k | pendiente |
| Breaker | 4 | Propio | < 8k | pendiente |
| Plato satelital | 7 | Propio | < 30k | pendiente |
| Radar | 7 | Propio | < 15k | pendiente |
| Torre de radio | 7 | Propio | < 30k | pendiente |
| ATV | 11 | Propio | < 15k | pendiente |
| Entidades (6–12) | 10 | Propio | < 12k | pendiente |
| Vegetación (3–4) | 7 | Poly Haven / Poly Pizza | < 500 | pendiente |
| Ítems (comida, herramientas) | 11 | Poly Pizza / Propio | < 2k | pendiente |

## 6. Audio

- Todo el audio es original o de bancos con licencia compatible.
- Ambiente por capas: viento, hojas, pájaros, agua, zumbido eléctrico, fluorescencia, metal.
- Sin música continua; solo stingers y radios.
- Formato: OGG para música/ambiente, WAV para efectos cortos.
- Nombres: `amb_`, `sfx_`, `ui_`, `vo_`.
- El audio se sintetiza cuando sea posible para ahorrar peso.

## 7. Pantallas y UI

- Las pantallas de computadora usan `SubViewport` con UI propia.
- Texturas de pantalla en 1024×768 o 1280×720; nada de fuentes ilegibles.
- Los controles físicos (perillas, botones) son mallas separadas con animación.
- El HUD es diegético siempre que se pueda: LEDs, notas, etiquetas.

## 8. Licencias y autoría

| Fuente | Licencia | Uso |
|---|---|---|
| Propio | — | Todos los assets principales |
| Poly Haven | CC0 | Modelos y texturas |
| Poly Pizza | CC0 / CC-BY según asset | Props y vegetación |
| Hyper3D / Meshy | Según plan | Solo modelos originales generados |
| Kenney | CC0 | UI y placeholders |

Cada asset de terceros se registra con autor, URL y licencia. Si la licencia no está clara, no se usa.

## 9. Verificación

- [ ] El modelo se ve bien a escala 1:1.
- [ ] El origen y la colisión son correctos.
- [ ] No supera el presupuesto.
- [ ] Las partes móviles están separadas.
- [ ] El material funciona con la iluminación del juego.
- [ ] Está registrado aquí.
- [ ] No hay assets del original.
