# Diseño — Ruido de Fondo (título provisional)

Juego de terror y simulación en primera persona. Proyecto personal de aprendizaje, original e independiente: no usa assets, código, nombres ni texturas de *Voices of the Void*.

## Visión

Eres un radioastrónomo aislado en una base en medio de un bosque. Trabajas en computadoras, recibes señales del espacio, las decodificas, ubicas su origen y gestionas la base. De noche el ambiente se vuelve peligroso. La primera versión debe ser fiel a ese espíritu; las ideas nuevas se acumulan en `IDEAS.md` y se integran por hitos.

## Pilares

1. **Máquinas físicas.** Cada máquina se opera apuntando y usando botones, interruptores, perillas, palancas y pantallas. Los estados importan: encendida, apagada, sobrecalentada, sin energía.
2. **Soledad y temor constante.** Silencio incómodo, sonido ambiental, oscuridad real, linterna con batería, ruidos lejanos. Sin música épica ni sustos baratos.
3. **Dificultad moderada-alta.** Recursos limitados, errores con consecuencias, sin tutoriales que lleven de la mano.
4. **Mundo continuo.** Base, terreno amplio, bosque y puntos de interés a distancia caminable, sin pantallas de carga.
5. **Rendimiento primero.** 60 FPS en hardware modesto; el original no es la referencia técnica.

## Anti-objetivos

- Copiar contenido, nombres o estética del juego de referencia.
- Combate heroico o power fantasy.
- Pantallas de carga entre zonas.
- Lógica de juego dentro de escenas o scripts gigantes.
- Añadir sistemas antes de que el hito actual sea jugable y medido.

## Decisiones

| Fecha | Decisión | Motivo |
|---|---|---|
| 2026-10-30 | Godot 4.7.2 stable, renderer **Forward+** | Escritorio; mejor calidad de luz horneada y sombras para interiores. Si el presupuesto no llega a 60 FPS, se evalúa Mobile con la misma escena. |
| 2026-10-30 | GDScript con tipado estático | Iteración rápida y suficiente para el alcance. |
| 2026-10-30 | 1 unidad = 1 metro | Coherencia con modelos, física y escala. |
| 2026-10-30 | Proyecto en `godot/` dentro del repo | El repo ya contiene el juego web ESTÁTICA (Three.js) con su propio `scripts/`; mezclarlos rompería ambos. Es reversible. |
| 2026-10-30 | Datos en Resources (`.tres`) | Cambiar balance y definiciones sin tocar código. |
| 2026-10-30 | Nada de assets del original | Requisito legal y de aprendizaje. |

## Estructura

```
godot/
  scenes/      escenas jugables (main, player, debug, ui)
  scripts/     GDScript por dominio (core, player, debug...)
  data/        Resources y configuración (balance.tres)
  assets/      models/ audio/ textures/ (vacío hasta el hito 6)
  docs/        diseño, arquitectura, tareas, ideas, assets
  tests/       smoke tests headless
```

## Parámetros de balance

Todos viven en `data/balance.tres` (`GameBalance`). Los scripts leen de ahí; no se codifican velocidades, consumos ni duraciones.

## Protocolo de ideas

- Cada idea nueva se anota en `docs/IDEAS.md` con fecha, descripción y estado.
- Si contradice el diseño, se avisa en una línea, se propone la integración y se actualiza este documento antes de implementar.
- Si falta una decisión, se proponen dos opciones cortas con recomendación y se sigue la recomendada.

## Estado

Hito 0 completado: estructura, jugador en primera persona (WASD, sprint, mirada con ratón, linterna con batería), sala de pruebas y overlay de rendimiento (F3). Ver `TASKS.md`.

## Decisiones abiertas

- **Nombre definitivo.** "Ruido de Fondo" es provisional.
- **Renderer definitivo.** Forward+ por ahora; se mide en hardware modesto en el hito 2.
- **Escala del mapa.** Se fija en el hito 3 (objetivo inicial: base ~60×40 m, radio jugable ~600 m).
