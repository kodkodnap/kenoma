# Assets

## Estilo

Low-poly estilizado, original, coherente en todo el juego: formas simples, paleta desaturada, materiales rugosos, poca textura y detalle donde importa (máquinas y pantallas). Nada de assets, nombres ni texturas del juego de referencia.

## Presupuestos

| Tipo | Tris máximos |
|---|---|
| Props pequeños | 2 000 |
| Props medianos | 8 000 |
| Máquinas principales | 15 000 |
| Vegetación (por variante) | 300 |

## Convenciones

- Formato de intercambio: **GLB** en `assets/models/`.
- 1 unidad = 1 metro, escala aplicada, rotación aplicada.
- Origen en la base del objeto (apoyado en el suelo), eje +Y arriba.
- Colisión incluida o generada en Godot (`-col` / `-colonly`), nunca malla de colisión compleja para props.
- Partes móviles (botones, palancas, puertas, perillas) como nodos separados.
- Un objeto = un archivo; nombres en `snake_case`.

## Registro

| Asset | Archivo | Tris | Prompt / origen | Estado |
|---|---|---|---|---|
| Suelo de sala | primitiva `BoxMesh` | 12 | Placeholder | provisional |
| Paredes | primitiva `BoxMesh` | 12 | Placeholder | provisional |
| Cajas | primitiva `BoxMesh` | 12 | Placeholder | provisional |
| Jugador | cápsula + cámara | — | Placeholder | provisional |

## Pipeline

1. Placeholder jugable (CSG o primitivas).
2. Modelo generado con Blender MCP o Hyper3D, con el mismo prompt de estilo.
3. Revisión: topología, escala, origen, polígonos. Si sale mal, se regenera.
4. Exportar GLB a `assets/models/`, registrar aquí nombre, prompt y tris.
5. Medir draw calls y FPS antes de dar el asset por bueno.

## Herramientas conectadas

- **Blender MCP** (`localhost:9876`): modelado y exportación directa desde Blender 5.2.
- **Hyper3D MCP**: generación de modelos desde texto o imagen (puede consumir créditos).
- Ambos son opcionales; el juego debe funcionar con placeholders.
