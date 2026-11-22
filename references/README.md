# Referencias de generación

Fuentes sin procesar de las máquinas de Kenoma: imágenes de Nano Banana y la salida
cruda de Meshy. Son el punto de partida, no el asset final.

Viven **fuera de `godot/`** a propósito: el preset de exportación usa
`export_filter="all_resources"` sin exclusiones, así que todo lo que esté dentro de
`res://` se importa en Godot y acaba en la build. Aquí nunca ocurre eso y aun así
queda en git.

## Estructura

Una carpeta por máquina, en kebab-case:

```text
references/<maquina>/
  <maquina>-ref.png      # imagen Nano Banana: objetivo visual y prompt
  <maquina>-meshy.glb    # salida cruda de Meshy, tal cual se descargó
```

Saca **los dos**: la imagen es el "cómo se ve bien" y sirve para regenerar si el mesh
sale mal; el GLB crudo es el cuerpo del gabinete.

## Flujo (de `godot/docs/ASSETS.md`)

1. Generar la imagen (Nano Banana) y de ella el modelo (Meshy, un prompt = un objeto).
2. En Blender: reducir polígonos, escala en metros, **origen en la base**, ejes
   Y arriba / −Z adelante, corregir normales, aplicar transformaciones.
3. Separar las partes móviles (perillas, interruptores, botones) en piezas aparte:
   la pantalla es un `SubViewport` sobre una malla aparte, no parte del mesh de Meshy.
4. Colisiones con **cajas**, nunca con la malla completa.
5. Exportar GLB a `godot/assets/models/` y **registrar** en `godot/docs/ASSETS.md`
   (nombre, fuente, prompt, tris, autoría/licencia).

## Git

- Las referencias se commitean: el registro de assets exige prompt y fuente.
- Si un crudo supera ~50 MB, avísame antes de commitearlo (no conviene reventar el repo
  con texturas 4K hormigonadas).
