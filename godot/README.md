# Kenoma

Juego de terror sistémico y simulación en primera persona en Godot 4, inspirado en los pilares
y flujo multi-máquina de *Voices of the Void*, ambientado en una estación brutalista de los años 80
en un valle alpino nevado.

- **Estilo visual:** PBR semi-realista estilizado (*Firewatch* + *Pacific Drive* + *Signalis*),
  contraste entre interior cálido acogedor y exterior frío en hora azul.
- **Referencias visuales maestras:** [`references/art-direction/base-exterior.png`](../references/art-direction/base-exterior.png)
  y [`references/art-direction/base-interior-signal-room.png`](../references/art-direction/base-interior-signal-room.png).
- **Estado:** base sistémica construida (jugador, interacción física, energía, cadena parcial de
  señales, ciclo diario — 334 checks en `tests/smoke.gd`). Próximo paso: **Hito 7** (nueva base
  amplia en voladizo, cierre de estación física con Playback + impresora matricial).

> La versión web antigua (`src/`, raíz del repo) está descartada y congelada; el juego real vive
> exclusivamente en `godot/`.

## Requisitos y ejecución

- **Godot 4.7.2 stable** (Forward+).
- Abrir `godot/project.godot` y ejecutar con `F5` (`scenes/main.tscn`).

## Verificación headless

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

## Documentación principal

| Documento | Contenido |
|---|---|
| [`docs/DESIGN.md`](docs/DESIGN.md) | Visión, pilares, diseño de la base en voladizo, snowcat, paleta y anti-objetivos |
| [`docs/ASSETS.md`](docs/ASSETS.md) | Biblia visual PBR estilizada y fichas técnicas de modelos para OpenCode + Blender MCP |
| [`docs/TASKS.md`](docs/TASKS.md) | Hoja de ruta limpia en línea recta desde el Hito 7 en adelante |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Capas técnicas, señales, recursos, colisiones y presupuesto |
| [`docs/IDEAS.md`](docs/IDEAS.md) | Decisiones cerradas, backlog y descartes |
| [`docs/ORIGINAL_FEATURES.md`](docs/ORIGINAL_FEATURES.md) | Catálogo sistémico de referencia |
