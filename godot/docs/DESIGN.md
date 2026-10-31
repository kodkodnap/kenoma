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
| 2026-10-30 | Interacción por raycast de cámara contra `Area3D` (capa 2), E o clic; `hold_time` para acciones largas | Permite varias partes móviles por máquina sin un script de interacción por objeto. |
| 2026-10-30 | Red de energía todo-o-nada por capacidad | Primera versión legible: si la carga supera la capacidad, se corta toda la red. Prioridades y sectores llegan con la base. |
| 2026-10-30 | Máquina base con estados `OFF/ON/OVERHEATED/NO_POWER` | El sobrecalentamiento es el primer fallo con consecuencia; `broken` se pospone. |
| 2026-10-30 | El consumo de una máquina es el de su modo, incluso apagada | Consumo de reposo simplificado; se revisará al construir la energía de la base. |

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

## Interacción y máquinas (hito 1)

- Alcance de 2,4 m desde la cámara; solo la capa 2. La mira pasa a ámbar con foco y a rojo si el control está bloqueado.
- `E` o clic izquierdo. Si `hold_time > 0`, hay que mantener; soltar o cambiar de foco cancela el progreso.
- `Interactable` solo emite `activated`; no conoce la máquina. Cada parte móvil es un `Area3D` independiente.
- `Machine` concentra energía, calor, modo y estado; las subclases solo presentan y traducen controles a llamadas.
- Estados: `OFF`, `ON`, `OVERHEATED`, `NO_POWER`. Al 100% de calor pasa a `OVERHEATED`; no se puede reiniciar hasta bajar del 30%. Sin energía pasa a `NO_POWER` y al volver queda `OFF` (no se auto-enciende).
- La perilla cambia entre BAJA/MEDIA/ALTA; cada modo define calor y consumo en el `.tres`.
- La red de prueba tiene 1500 W y corta toda la carga si se excede la capacidad.

## Protocolo de ideas

- Cada idea nueva se anota en `docs/IDEAS.md` con fecha, descripción y estado.
- Si contradice el diseño, se avisa en una línea, se propone la integración y se actualiza este documento antes de implementar.
- Si falta una decisión, se proponen dos opciones cortas con recomendación y se sigue la recomendada.

## Estado

Hito 0 completado: estructura, jugador en primera persona (WASD, sprint, mirada con ratón, linterna con batería), sala de pruebas y overlay de rendimiento (F3).

Hito 1 completado: interacción por raycast, HUD de foco/progreso, máquina de prueba con interruptor (mantener 1,2 s), botón de reinicio, perilla de ganancia, estados, sobrecalentamiento y red de energía mínima. Ver `TASKS.md`.

## Decisiones abiertas

- **Nombre definitivo.** "Ruido de Fondo" es provisional.
- **Renderer definitivo.** Forward+ por ahora; se mide en hardware modesto en el hito 2.
- **Escala del mapa.** Se fija en el hito 3 (objetivo inicial: base ~60×40 m, radio jugable ~600 m).
