# Referencias de generación y dirección de arte

Fuentes visuales de Kenoma: conceptos de dirección de arte, imágenes de referencia y salidas
crudas de generación 3D (Meshy). Son el punto de partida, no el asset final.

Viven **fuera de `godot/`** a propósito: el preset de exportación usa
`export_filter="all_resources"` sin exclusiones, así que todo lo que esté dentro de
`res://` se importa en Godot y acaba en la build. Aquí nunca ocurre eso y aun así
queda en git.

## Estructura

```text
references/
  art-direction/
    base-exterior.png              # Biblia visual exterior (voladizo, hora azul, garaje, snowcat)
    base-interior-signal-room.png  # Biblia visual interior (sala de mando, luz cálida, pasillo amplio)
  <maquina>/
    <maquina>-ref.png              # Imagen objetivo y prompt
    <maquina>-meshy.glb            # Salida cruda de Meshy, tal cual se descargó
```

## Flujo (de `godot/docs/ASSETS.md`)

1. Generar o validar la referencia visual (PBR semi-realista estilizado: *Firewatch* + *Pacific Drive* + *Signalis*).
2. En Blender (OpenCode + Blender MCP o manual): modelar o limpiar topología, escala en metros (**1 u = 1 m**), **origen en la base**, ejes Y arriba / −Z adelante, corregir normales y aplicar transformaciones.
3. Separar las partes móviles (perillas, interruptores, botones, puertas, orugas) en piezas aparte: las pantallas vivas usan `SubViewport` en Godot.
4. Colisiones con **cajas simples**, nunca con la malla completa.
5. Exportar GLB a `godot/assets/models/` y **registrar** en `godot/docs/ASSETS.md` (nombre, fuente, prompt, tris, autoría/licencia).

## Git

- Las referencias se commitean: el registro de assets exige prompt y fuente.
- Si un crudo supera ~50 MB, conviene comprimir texturas o revisarlo antes de commitear.
