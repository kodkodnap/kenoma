# Tareas — Ruido de Fondo

> Hoja de ruta viva. Un hito solo se marca **hecho** cuando pasa el smoke, se puede probar jugando y la
> documentación está al día. El usuario revisa el backlog (`IDEAS.md`) después de cada hito.
>
> Referencia de contenido: [`ORIGINAL_FEATURES.md`](ORIGINAL_FEATURES.md). Diseño: [`DESIGN.md`](DESIGN.md).
> Arquitectura: [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Estado

| # | Hito | Estado | Verificación |
|---:|---|---|---|
| 0 | Investigación, catálogo y documentación | **hecho** | Docs revisados y commit |
| 1 | Proyecto base y jugador | **hecho** | Smoke (51 checks) + captura Forward+ |
| 2 | Framework de interacción e inventario | pendiente | Smoke |
| 3 | Alpha Root Base en placeholders | pendiente | Smoke + recorrido |
| 4 | Energía | pendiente | Smoke + apagón jugable |
| 5 | Estación de señales | pendiente | Smoke + cadena completa |
| 6 | Ciclo diario y dron | pendiente | Smoke + día completo |
| 7 | Mapa exterior a escala | pendiente | Smoke + recorrido |
| 8 | Servidores, consola y hashcodes | pendiente | Smoke |
| 9 | Estadísticas y dificultad | pendiente | Smoke |
| 10 | Entidades y radar | pendiente | Smoke + noche |
| 11 | Tier 2 | pendiente | Smoke |
| 12 | Modelos definitivos | pendiente | Revisión visual + presupuesto |
| 13 | Tier 3 | pendiente | Smoke |
| 14 | Tier 4 | pendiente | Smoke |
| 15 | Guardado, menús y pulido | pendiente | Smoke + partida completa |

---

## Hito 0 — Investigación, catálogo y documentación

**Estado: hecho (2026-10-30).**

### Entregado

- `docs/ORIGINAL_FEATURES.md` con 21 secciones y prioridades T1–T4.
- `docs/DESIGN.md` reescrito como réplica fiel de sistemas, no de contenido.
- `docs/ARCHITECTURE.md` con capas, clases objetivo, señales, datos, colisiones y rendimiento.
- `docs/TASKS.md` con los 15 hitos.
- `docs/IDEAS.md`, `docs/ASSETS.md`, `AGENTS.md` y `README.md` actualizados.
- El juego web ESTATICA de la raíz queda intacto.

### Criterio de aceptación

- [x] La wiki oficial está consultada y citada.
- [x] El catálogo cubre todos los sistemas del prompt.
- [x] Los 15 hitos están definidos con criterios de aceptación.
- [x] No se ha implementado código de juego nuevo.
- [x] Commit del hito 0.

---

## Hito 1 — Proyecto base y jugador

**Estado: hecho (2026-10-30).**

**Objetivo:** un jugador en primera persona que se mueva como el original y tenga stamina, linterna,
cámara y debug. Sin máquinas todavía.

### Entregables

- `Player` con velocidades **4 m/s andando, 8 m/s corriendo, 1,5 m/s agachado**.
- Sprint con stamina; agotado no se corre.
- Cámara con mirada limitada, cabeza estable, FOV configurable.
- Linterna existente: se conserva; ya tiene batería y toggle. Se añade lectura en HUD.
- Salto, gravedad, colisión de cápsula.
- `GameBalance` actualizado; valores en `data/balance.tres`.
- Vitales mínimos en `Player`: stamina y batería (`PlayerStats` se separa en el hito 9).
- HUD mínimo: stamina, batería y prompt; el reloj llega con `GameClock` en el hito 6.
- Escena de debug con FPS, draw calls, primitivas, memoria y nodos.
- Eliminar o archivar la `TestMachine` del prototipo anterior si estorba.

### Criterio de aceptación

- [x] Velocidades medidas: andar ~4 m/s, correr ~8 m/s y agachado ~1,5 m/s (smoke).
- [x] La stamina baja al correr, se recupera al parar y bloquea el sprint por debajo de 15.
- [x] La linterna ilumina, se apaga con F y se apaga al quedarse sin batería.
- [x] El jugador no atraviesa la pared ni cae del suelo del prototipo.
- [x] F3 muestra el overlay y los valores son reales.
- [x] `--headless --import` limpio.
- [x] Smoke completo en verde (51 comprobaciones).

### Prueba manual

1. Ejecutar `godot/` con Forward+.
2. Medir 100 m con el cronómetro del overlay o una caja de referencia.
3. Correr hasta agotar stamina y comprobar el bloqueo.
4. Apagar la linterna y esperar el drenaje.
5. Mirar al techo/suelo y comprobar el clamp.

### Notas de implementación

- `stamina` y `battery` viven en `Player` por ahora; `PlayerStats` se separa en el hito 9.
- El reloj del HUD se pospone al hito 6, cuando exista `GameClock`; no se inventa un reloj falso.
- `TestMachine` se conserva para la prueba de integración del hito 2.
- Pendiente: comprobar techo al levantarse; se añadirá con los conductos del hito 3.
- Captura Forward+ verificada: HUD `Stamina 100% / Linterna 100%`, linterna y sala visibles.

---

## Hito 2 — Framework de interacción e inventario

**Estado: hecho (2026-10-30).**

**Objetivo:** una base reutilizable para todo lo que se toca, se agarra o se opera.

### Entregables

- `Interactable` con prompt, hold, enabled, foco y señales.
- `Grabbable` con física, rotación, distancia y suelta.
- `ItemContainer` e `Inventory` por volumen.
- `Machine`/`MachineDef` con estados y controles físicos: botón, interruptor, perilla, palanca.
- `ScreenPanel` base con `SubViewport` (el nombre `Panel` choca con el Control nativo).
- `ItemDef` y un ítem de prueba.
- `EntityDef`/`Entity` base vacía, sin IA todavía.
- `EventDef`/`EventDirector` base, sin eventos.
- HUD de inventario y prompt.
- Prueba de integración con una máquina y un ítem.

### Criterio de aceptación

- [x] Se puede apuntar, mantener E y activar un control.
- [x] Se puede coger, rotar, soltar y lanzar un objeto.
- [x] El inventario rechaza un ítem si no cabe.
- [x] Un panel se abre, se opera y se cierra sin pausar el mundo.
- [x] La máquina de prueba enciende, se calienta, se apaga y se reinicia.
- [x] Smoke en verde con las nuevas comprobaciones (85).

### Prueba manual

1. Ejecutar `godot/` con Forward+.
2. Apuntar a la caja de prueba, pulsar E para cogerla, mover el ratón con el botón derecho para rotarla.
3. Pulsar clic izquierdo para lanzarla o G para soltarla.
4. Pulsar Tab para abrir el panel de prueba, pulsar `Probar` y `Cerrar`.
5. Comprobar el HUD `Mochila` y la máquina de prueba.

### Notas de implementación

- `Grabbable` está congelado mientras se sostiene; no comprueba paredes al mover el objeto (shortcut para el hito 3).
- `E` coge; clic izquierdo lanza; `G` suelta; botón derecho + ratón rota.
- El panel de prueba es un overlay con `SubViewport`; las pantallas 3D de las máquinas llegan en el hito 5.
- Los controles físicos siguen embebidos en `TestMachine`; se extraerán a clases reutilizables cuando haya una segunda máquina.
- `Hud` conecta `Inventory.changed` para refrescar la mochila, sin recalcular reglas.

---

## Hito 3 — Alpha Root Base en placeholders

**Objetivo:** una base completa, recorrible y con la distribución del original, hecha con CSG/primitivas.

### Entregables

- Exteriores norte/este/sur/oeste y entrada principal.
- Loading bay, pasillo, recepción/administración, garaje, break room, utility closet.
- Signal Processing & Research con cuatro paneles y radar.
- Server Network Room con 30 servidores placeholder.
- Sótano con breaker, transformadores, crematorio y taquillas.
- Planta superior: dormitorio, baño, almacén, balcón, techo, conductos.
- Puertas, luces, carteles, notas y colisiones.
- 24 platos, 3 transformadores, 3 radares, 4 turbinas y torre como placeholders exteriores.
- LightmapGI o luces horneadas en interiores.
- Punto de spawn y recorrido de prueba.

### Criterio de aceptación

- [ ] Se recorre toda la base sin atascos ni huecos.
- [ ] Todas las zonas tienen luz y se distinguen.
- [ ] Los 30 servidores y los cuatro paneles son accesibles.
- [ ] El sótano tiene una única ruta clara al breaker.
- [ ] El presupuesto de la escena no supera 150k triángulos / 250 draw calls.
- [ ] Smoke en verde.

---

## Hito 4 — Energía

**Objetivo:** que la base dependa de tres transformadores y un breaker de cinco circuitos.

### Entregables

- `Transformer` con estabilidad, daño, reinicio de dos pulsaciones y apagón.
- `BreakerPanel` con Calculations, Downloading, Coordinates, Playing, Utilities.
- `PowerSystem` con consumo, redistribución y eficiencia.
- Luces, puertas y máquinas conectadas a circuitos.
- HUD de estabilidad y avisos.
- Módulo de control remoto (30 s → 1 s).
- Apagón jugable y recuperación.

### Criterio de aceptación

- [ ] Apagar Calculations libera energía y acelera los circuitos restantes.
- [ ] A estabilidad 0 se corta toda la base.
- [ ] El botón rojo exige dos pulsaciones para reiniciar.
- [ ] Un transformador dañado impide el reinicio hasta repararlo.
- [ ] El control remoto tarda 30 s y se puede mejorar.
- [ ] Smoke en verde.

---

## Hito 5 — Estación de señales

**Objetivo:** la cadena completa de señal, con las cuatro pantallas y los discos.

### Entregables

- Panel de Coordinates con cursor, quick scan, tres radares y ping.
- Panel de Downloads con seis perillas, dirección de polaridad, toggles y detector.
- Panel de Playback con lista, reproducción y exportación.
- Panel de Processing con tres niveles y Start/Stop.
- Discos, caja de discos, zip drive y base de datos.
- Primeras 8–12 señales de prueba con audio e imagen originales.
- Fallos: satélite caído, señal débil, tormenta, objeto inválido.
- Venta al dron y valor según calidad/nivel.

### Criterio de aceptación

- [ ] Se encuentra una señal con los tres radares.
- [ ] Se descarga ajustando polaridad y frecuencia.
- [ ] Se reproduce y se guarda en la base de datos.
- [ ] Se procesa a nivel 1, 2 y 3.
- [ ] Se exporta a disco y se vende.
- [ ] Una copia vale 0.
- [ ] Smoke en verde.

---

## Hito 6 — Ciclo diario, dron y tienda

**Objetivo:** el bucle de 24 horas con tareas, pedidos y puntos.

### Entregables

- `GameClock` con día, hora, velocidad por dificultad y dormir.
- Correo de tarea a medianoche y dron a las 06:00.
- `DailyTask` con señales, hashcodes y cintas.
- Saco del dron, caja de discos, zip drive y caja de cintas.
- Tienda con categorías, pedidos y favoritos.
- Puntos, bonus semanal, multas y ventas.
- Estación de bobinas y cintas A/B.
- Guardado provisional en memoria para probar el ciclo.

### Criterio de aceptación

- [ ] Un día completo dura 75 min en Normal (se puede acelerar para probar).
- [ ] La tarea llega a medianoche y se puede entregar.
- [ ] El dron trae el pedido y un disco vacío.
- [ ] La tienda cobra y entrega.
- [ ] El bonus y la multa se aplican.
- [ ] Smoke en verde.

---

## Hito 7 — Mapa exterior a escala

**Objetivo:** un bosque continuo de ~1,4 km con la infraestructura del original.

### Entregables

- Terreno, colinas, río, lago, caminos y vallas.
- Bosque con MultiMesh, LOD y occlusion culling.
- 24 platos B–Y con base, plato, pasarela, sala y consola.
- 3 transformadores, 3 radares, 4 turbinas y torre de radio en el mundo.
- POIs prioritarios: Security Booth, Alpha Hideout, The Lake, Abandoned Shack, The Cave, The Well, Graves.
- Mapa digital y brújula.
- Carga por distancia y límites del mundo.
- Prueba de recorrido a pie y en ATV.

### Criterio de aceptación

- [ ] Se llega a los 24 platos sin pantallas de carga.
- [ ] El bosque mantiene 60 FPS en hardware objetivo.
- [ ] Los POIs se encuentran sin waypoints.
- [ ] El mapa digital coincide con el mundo.
- [ ] Presupuesto < 250 draw calls y < 150k triángulos.
- [ ] Smoke en verde.

---

## Hito 8 — Servidores, consola y hashcodes

**Objetivo:** mantenimiento real de la red y extracción de datos de los satélites.

### Entregables

- `ServerSystem` con 54 servidores y estados.
- Minijuego de reparación (uno primero; el resto después).
- Kits, disquete azul y mejoras de servidor.
- Consola con comandos: `sv.ping`, `sv.target`, `sv.reset`, `sd.calch`, `sd.cal`, `sd.calall`, `sv.request`, `sv.eject`, `tr.check`, `tw.check`, `time`.
- Hashcode: disquete → satélite → request → eject → Viewer → zip drive.
- Calibración de platos y precisión.
- Luces verdes/rojas y avisos.

### Criterio de aceptación

- [ ] Se repara un servidor con el minijuego.
- [ ] Un servidor caído bloquea la calibración del plato.
- [ ] Se obtiene un hashcode completo.
- [ ] El Viewer mueve bloques entre disquete, buffer y zip drive.
- [ ] Los comandos muestran información correcta.
- [ ] Smoke en verde.

---

## Hito 9 — Estadísticas, dificultad y ajustes

**Objetivo:** hambre, stamina, salud, sueño, paranoia y reglas de partida.

### Entregables

- `PlayerStats` completo con umbrales 20/15/0.
- Comida, tolerancia, sabor y putrefacción.
- Salud sin barra, viñeta, sangrado, cáncer y medicinas.
- Sueño, insomnio y sueños.
- Meta Paranoia y bloqueo de pausa/guardado.
- Reputación oculta.
- Dificultades Easy++ a Hard++ con sus duraciones.
- Reglas de partida configurables.
- Menú de ajustes inicial.

### Criterio de aceptación

- [ ] Con hambre <20 no se corre ni se repara.
- [ ] Con stamina <15 no se corre ni se escala.
- [ ] La comida se pudre fuera de la nevera.
- [ ] La salud solo se comunica por viñeta y sonido.
- [ ] Cambiar dificultad cambia tarea y duración del día.
- [ ] Smoke en verde.

---

## Hito 10 — Entidades, radar y noche

**Objetivo:** que el bosque deje de estar vacío.

### Entregables

- `Entity` con IA base: idle, observar, acercarse, huir, atacar, desaparecer.
- `EntityDirector` con spawns por hora, evento, stat y radar.
- Primeras 6 entidades originales: una inofensiva, una que observa, una que persigue, una que roba,
  una que apaga luces y una que solo aparece en grabaciones.
- Radar con historial, colores, alarma y radio.
- Linterna y visión como factores.
- Meta Paranoia en al menos un evento.
- Audio de pasos, respiración y presencia.

### Criterio de aceptación

- [ ] Una entidad aparece de noche y se puede detectar en el radar.
- [ ] La linterna la ahuyenta o la atrae según su tipo.
- [ ] Una entidad puede apagar luces o cortar energía.
- [ ] El jugador puede esconderse o huir.
- [ ] El evento bloquea pausa/guardado cuando toca.
- [ ] Smoke en verde.

---

## Hito 11 — Tier 2

**Objetivo:** profundidad y libertad.

### Entregables

- Inventario completo y contenedores.
- Cocina, nevera, microondas y recetas.
- Workbench, blueprints y crafting.
- Agricultura, pesca y excavación.
- Construcción básica.
- Cámaras, fotos y Media.
- ATV con gasolina, daño y upgrades.
- Módulos físicos y sus 12 + 4 ranuras.
- Más POIs y objetos únicos.

### Criterio de aceptación

- [ ] Se cocina una comida y se conserva en la nevera.
- [ ] Se fabrica una herramienta con blueprint.
- [ ] Se pesca y se excava al menos un objeto.
- [ ] Se conduce el ATV y se reposta.
- [ ] Se instala un módulo con la estación apagada.
- [ ] Smoke en verde.

---

## Hito 12 — Modelos definitivos

**Objetivo:** sustituir placeholders por arte original y coherente.

### Entregables

- Modelos de base, máquinas, controles, ítems y vegetación.
- Pipeline documentado en `ASSETS.md`.
- LODs, colisiones y orígenes corregidos.
- Materiales y texturas propias.
- Revisión de escala y presupuesto.
- Capturas de referencia.

### Criterio de aceptación

- [ ] No queda ningún placeholder visible en la base.
- [ ] Todos los modelos respetan el presupuesto.
- [ ] Las partes móviles están separadas.
- [ ] El origen y la escala son correctos.
- [ ] `ASSETS.md` registra nombre, prompt, tris y autoría.
- [ ] Smoke y recorrido visual en verde.

---

## Hito 13 — Tier 3

**Objetivo:** narrativa, facciones y progresión.

### Entregables

- Arco de 7 semanas con eventos originales.
- Facciones y reputación.
- Sueños y alucinaciones.
- Logros y advancements.
- Personajes y emails.
- Finales originales.
- Torres, radares y transformadores degradables.

### Criterio de aceptación

- [ ] La semana 1 se juega completa.
- [ ] Una facción reacciona a la reputación.
- [ ] Un sueño cambia el día siguiente.
- [ ] Un logro desbloquea un ítem.
- [ ] Un final se puede alcanzar.
- [ ] Smoke en verde.

---

## Hito 14 — Tier 4

**Objetivo:** secretos, contenido meta y caos opcional.

### Entregables

- Ítems ocultos y coleccionables.
- Comandos y rituales.
- Secretos del mapa.
- Entidades Forbidden.
- Entidades de chiste y regla Funny.
- Dimensiones.
- Contenido estacional.
- Modo Sandbox y vuelo.

### Criterio de aceptación

- [ ] Todo el contenido T4 es opcional y desactivable.
- [ ] Un secreto se puede descubrir sin guía.
- [ ] Una dimensión se puede visitar y abandonar.
- [ ] La regla Funny no afecta al modo Story por defecto.
- [ ] Smoke en verde.

---

## Hito 15 — Guardado, menús y pulido

**Objetivo:** un juego terminable y estable.

### Entregables

- Guardado/carga versionado con migraciones.
- Menú principal, nueva partida, continuar, opciones.
- Dificultad y reglas de partida.
- Accesibilidad: subtítulos, FOV, sensibilidad, volumen, reducir sustos.
- Segunda pasada de rendimiento.
- Corrección de bugs y balance.
- Build exportada.

### Criterio de aceptación

- [ ] Se guarda y se reanuda una partida completa.
- [ ] Se puede terminar el arco principal.
- [ ] Los ajustes persisten.
- [ ] 60 FPS estables en hardware objetivo.
- [ ] Smoke completo en verde.
- [ ] Build ejecutable sin errores.

---

## Protocolo después de cada hito

1. Ejecutar `--headless --import` y el smoke.
2. Probar a mano lo descrito en el hito.
3. Actualizar `TASKS.md` (estado y notas), `DESIGN.md` si cambió una decisión, `ARCHITECTURE.md` si
   cambió una clase o señal, y `ASSETS.md` si hay modelos.
4. Commit pequeño con mensaje `hito N: ...`.
5. Preguntar al usuario si quiere incorporar ideas del backlog antes del siguiente hito.

## Comandos

```bash
GODOT="C:/Users/ibane/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"

"$GODOT" --headless --path godot --import
"$GODOT" --headless --path godot --script res://tests/smoke.gd
```

## Riesgos abiertos

| Riesgo | Mitigación |
|---|---|
| El mapa de 1,4 km no rinde | MultiMesh, LOD, occlusion, carga por distancia; medir en hito 7 |
| La cadena de señal es demasiado lenta | Atajos, módulos, autoguardado; medir en hito 5 |
| Los minijuegos de servidor cansan | Empezar con uno; el resto como variantes opcionales |
| La IA de entidades es cara | Límite de activas, LOD de IA, spawns por zona |
| El alcance de 15 hitos es grande | Hitos pequeños, smoke y revisión del usuario |
