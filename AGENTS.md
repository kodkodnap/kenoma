# ESTÁTICA (web, Three.js) — DEPRECATED

> **La versión web de ESTATICA está deprecada.** El juego se desarrolla exclusivamente en
> Godot, dentro de `godot/` (**Kenoma**, Godot 4.7.2, Forward+, GDScript tipado).
> La memoria viva del proyecto, los hitos y las skills obligatorias están en
> [`godot/AGENTS.md`](godot/AGENTS.md); la visión y el diseño, en
> [`godot/docs/DESIGN.md`](godot/docs/DESIGN.md).
>
> La raíz de este repo (código en `src/` y `test/`, Three.js + TypeScript + Vite,
> `index.html`, `vite.config.ts`) queda **congelada como archivo histórico**: no se
> desarrolla, no se añaden sistemas ni dependencias y no se mezcla con el trabajo de Godot.
> Nada de lo que hubo aquí es válido para el desarrollo actual.
>
> Este documento se conserva solo para que un humano entienda el archivo; la historia
> original vive en git (`git log --oneline -- AGENTS.md`).

## Skills obligatorias

Ninguna para el desarrollo activo; la tabla válida es la de `godot/AGENTS.md`. Se listan
las del archivo congelado para que el router de skills siga alineado:

- `vitest` — solo si algún día se retoma `test/` del archivo web.
- `systematic-debugging` — cualquier fallo reproducible en el archivo.

Las skills `threejs-*` se retiraron del manifiesto (`.agents/skills/manifest.json`): el
código web ya no se toca.

## Para inspeccionar el archivo (sin desarrollarlo)

```bash
npm install
npm run dev        # http://localhost:5180
npm run verify     # skills:check + typecheck + vitest
npm run build
```

El README describe el archivo congelado; el estado actual del juego está en
`godot/docs/TASKS.md`.
