# Diseño — Kenoma

> Nombre definitivo: **Kenoma**. Repo: <https://github.com/kodkodnap/kenoma>.
>
> **Referencia de fidelidad:** *Voices of the Void* (VotV). Es una **inspiración muy cercana**, no un
> clon: se toman los sistemas, la escala, el ritmo y la sensación, con variaciones propias en contenido,
> nombres, reglas y soluciones. No se copian assets, código, textos, audio ni interfaces. El catálogo
> completo está en [`ORIGINAL_FEATURES.md`](ORIGINAL_FEATURES.md).
>
> Estado: **hitos 0–6 y 5.6 cerrados**. La Alpha Root Base es recorrible y la estación de señales
> tiene consolas físicas, discos y sala propia. Los hitos 7–15 siguen en el backlog.

## 1. Visión

Eres un radioastrónomo aislado en una base brutalista en un bosque alpino. Cada día recibes una tarea:
encontrar señales, descargarlas, procesarlas, localizar satélites y entregar el trabajo al dron. La base
se mantiene con tres transformadores, un breaker y 54 servidores. Fuera hay 24 platos, tres radares, una
torre de radio y un bosque que de noche deja de estar vacío.

El juego no te lleva de la mano. Te da máquinas físicas, un mapa grande, información incompleta y
consecuencias. La tensión nace de la logística, el silencio y la sospecha, no de una banda sonora épica.

## 2. Contrato de fidelidad

| Se replica | No se copia |
|---|---|
| Bucle diario, tareas, dron, puntos y multas | Modelos, texturas, materiales y animaciones |
| Cadena de señal completa y sus fallos | Código, escenas, recursos y nombres de archivo |
| Energía, breakers, transformadores y servidores | Textos, emails, señales y audio |
| Estadísticas, dificultad y reglas de partida | Personajes y lore literales |
| Escala del mapa y distribución de infraestructura | Interfaz pixel a pixel |
| Máquinas físicas con perillas, botones y pantallas | Contenido de chiste o secretos copiados |
| Terror sistémico, atmósfera y soledad | Assets de terceros con licencia incompatible |

**Nombres:** se usan los del original solo como referencia de diseño. Todos viven en `data/` para poder
renombrarlos sin tocar código. Los textos definitivos serán originales.

**Alcance:** inspiración muy cercana con variaciones. No es un clon 1:1 de contenido: se conserva la
estructura y la dificultad, pero se cambian nombres, textos, señales, entidades, eventos y detalles de
implementación. Si un prototipo existente ya cumple una función, se conserva y se ajusta en vez de
rehacerlo por reflejo.

## 3. Pilares

1. **La señal manda.** Todo el día gira alrededor de encontrar, descargar, procesar y vender señales.
2. **Máquinas físicas.** Se apunta, se hace clic, se mantiene, se gira. El estado importa: encendida,
   apagada, sobrecalentada, sin energía, dañada.
3. **Soledad y rutina.** La base es un lugar de trabajo real. El horror aparece en lo cotidiano.
4. **Dificultad sin tutorial.** El jugador aprende leyendo paneles, correos y notas; los errores cuestan.
5. **Mundo continuo.** Base, bosque, platos y POIs sin pantallas de carga.
6. **Rendimiento desde el día 1.** 60 FPS en hardware modesto; presupuesto medido en cada hito.
7. **Todo es datos.** Máquinas, señales, ítems, entidades, eventos y balance se editan fuera de los scripts.

## 4. Bucle de juego

```
00:00  Correo con la tarea del día
06:00  El dron trae el pedido y un disco vacío
       Coordenadas → Descarga → Reproducción/Guardado → Procesado (FASE → LOCK → CONFIRMAR) → Disco
       Hashcodes de satélites → consola → zip drive
       Cintas de datos → estación de bobinas → caja
       Reparar servidores, calibrar platos, mantener energía
       Vender, comprar, mejorar, dormir
       Entregar en el saco del dron antes de medianoche
```

- La tarea exige una cantidad de señales de niveles concretos, hashcodes y dos cintas.
- El jugador puede ignorar la tarea, pero pierde puntos y reputación.
- El dron se llama desde el panel del garaje; no hay teletransporte.
- Dormir avanza el tiempo y recupera stamina, pero no se puede empezar por encima de 80.

## 5. Mapa y escala

| Zona | Contenido | Referencia |
|---|---|---|
| Base principal | Interiores, sótano, planta superior, radomo, loading bay, garaje | ~80×60 m |
| Explanada | 24 platos satelitales, 3 transformadores, 3 radares, 4 turbinas, torre | ~500×500 m |
| Bosque | Senderos, POIs, vallas, lago, río, cuevas | ~1,4×1,4 km |
| Exterior lejano | POIs secretos, dimensiones, límites | Se amplía en hitos 7 y 14 |

- 1 unidad = 1 metro. Origen en el suelo, ejes Y arriba, −Z adelante.
- La base está en el centro; los platos se ven desde lejos y obligan a caminar o usar el ATV.
- Sin pantallas de carga. Carga por distancia y vegetación con MultiMesh.
- El mapa exacto se valida en el hito 7 con una prueba de recorrido a pie y en ATV.

## 6. Base principal

### 6.1 Interiores

| Zona | Uso | Hito |
|---|---|---|
| Entrada y recepción | Primer contacto, terminal de administración, notas | 3 |
| Loading bay | Dron, saco de entregas, cajas | 3 |
| Garaje | ATV, workbench, panel del dron | 3 |
| Break room / cocina | Comida, nevera, microondas, café | 3 |
| Signal Processing & Research | 4 paneles, radar, mapa, ducha de emergencia | 3/5 |
| Server Network Room | 30 servidores, consola, disquetes | 3/8 |
| Sótano | Breaker, transformadores, crematorio, taquillas | 3/4 |
| Planta superior | Dormitorio, baño, almacén, balcón, techo, conductos | 3 |
| Radomo | Estructura exterior, antena, mantenimiento | 3 |

### 6.2 Reglas de la base

- Las luces interiores se hornean con LightmapGI; las dinámicas se reservan para linterna, pantallas y
  emergencia.
- Las puertas de seguridad dependen del breaker de Utilities.
- El sótano es la única ruta al breaker; no hay control remoto hasta comprar el módulo.
- Los servidores y paneles deben ser accesibles sin atravesar geometría; el jugador no se agacha para
  llegar a un botón.

## 7. Sistemas

### 7.1 Señales

- Catálogo data-driven con tipos, calidad, nivel, precio base, audio, imagen y eventos.
- Cadena de cuatro etapas con estado persistente por señal.
- Coordinates: cursor, quick scan, tres radares y ping; los fallos son información, no castigos aleatorios.
- Downloads: seis perillas con sensibilidad distinta, tres direcciones de polaridad, detector y tormentas.
- Playback: escuchar, guardar en database y exportar a disco.
- Procesado: gira la perilla FASE hasta que la traza del CRT pierde jitter; al pasar el umbral se
  enciende LOCK y CONFIRMAR sube de nivel la última copia guardada y habilita exportarla a disco.
  Los niveles siguen `PROCESS_THRESHOLDS`. Los textos del `.blend` no se importan: las etiquetas y el
  CRT se regeneran como contenido original de Kenoma.
- Venta: caja de discos al dron; copias y señales ya vendidas valen cero.
- Los diales se operan por arrastre angular: E agarra y suelta, el ratón los gira en ambos sentidos con
  la cámara bloqueada, la rueda hace ajuste fino y cada uno muestra su propósito en el prompt.
- El disco exportado es un objeto físico con placa visible (señal, nivel, valor): se coge, se inserta
  en la bandeja de Procesado para trabajar y en la ranura de la terminal para vender; placa y progreso
  siguen al disco insertado.

Los valores exactos están en `ORIGINAL_FEATURES.md` §2 y se implementan en `data/signals/`.

### 7.2 Computadora principal

Nueve pestañas: Upgrades, Database, Email, Store, Advancements, Cameras, Media, Components, Viewer.
La computadora es un `SubViewport` con UI propia; el mundo sigue simulando mientras se usa.

### 7.3 Energía

- Tres transformadores con estabilidad; el consumo baja la estabilidad y un apagón corta todo.
- Cinco breakers: Calculations, Downloading, Coordinates, Playing, Utilities.
- Apagar componentes redistribuye la energía y acelera los restantes.
- El reinicio exige dos pulsaciones del botón rojo y reparar el transformador dañado.
- Los módulos se instalan con la estación apagada; si no, explota.

### 7.4 Servidores y satélites

- 30 servidores en la base, 24 en los platos; luces verde/roja.
- Reparación manual con minijuego, kit o robot; hasta tres mejoras por servidor.
- 24 platos B–Y con precisión y calibración; un servidor caído bloquea la calibración.
- Hashcodes: disquete en la consola del plato, `request`, esperar, `eject`, Viewer, zip drive.

### 7.5 Estadísticas

Comida, tolerancia, sabor, putrefacción, stamina, salud, sangrado, cáncer, sueño, paranoia y reputación.
La UI solo muestra lo que el jugador puede percibir: no hay barra de salud, solo viñeta y sonido.

### 7.6 Economía

Puntos por tareas, venta, minijuegos y logros; bonus semanal; multas opcionales. La tienda usa el dron.
La venta normal es la mitad del precio de compra.

### 7.7 Ítems, inventario y crafting

Inventario por volumen, agarrar/lanzar, contenedores, workbench, blueprints, cocina, agricultura, pesca,
excavación, construcción, cámaras y fotos. Todo ítem es un `ItemDef` con precio, volumen, categoría,
modelo y flags.

### 7.8 Entidades y eventos

- `EntityDef` + IA base con estados: idle, observar, acercarse, huir, atacar, desaparecer.
- El radar detecta, colorea y alarma según módulos.
- `EventDef` con condiciones, peso, cooldown, duración y acciones.
- Los eventos de historia van por día/hora; los aleatorios por peso y flags.
- Meta Paranoia bloquea pausa, guardado y sueño durante ciertos eventos.

### 7.9 Guardado

Un `GameState` serializable, versionado. Guarda día, hora, stats, inventario, base, energía, servidores,
señales, tareas, flags, decisiones y semilla. Nunca guarda el árbol de escena.

## 8. Controles e interacción

| Acción | Tecla | Regla |
|---|---|---|
| Mover | WASD | 4 m/s andando, 8 m/s corriendo, 1,5 m/s agachado |
| Correr | Shift | Consume stamina; <15 no se puede |
| Saltar | Space | Altura moderada; cae con gravedad |
| Agacharse | Ctrl | Cambia cápsula y velocidad |
| Mirar | Ratón | Sensibilidad configurable |
| Interactuar | E / clic izquierdo | Raycast 2,4 m; mantener para acciones largas |
| Perilla (dial) | E + ratón / rueda | E agarra y suelta; el arrastre circular gira en ambos sentidos con la cámara bloqueada, la rueda es ajuste fino; Esc suelta |
| Agarrar / soltar | E / clic derecho | Objetos físicos; rueda para distancia |
| Linterna | F | Batería limitada; la recarga llega con los ítems del hito 11. |
| Inventario | Tab | Rejilla/volumen |
| Panel / terminal | E | SubViewport; Escape cierra |
| Debug | F3 | FPS, draw calls, primitivas, memoria |

La interacción debe ser física: perillas que giran, botones que se hunden, palancas que se mueven y
pantallas que cambian. El jugador no usa menús abstractos para operar una máquina.

## 9. Dificultad y balance

- Referencia: **Normal**, 75 min reales por día, 3 hashcodes y 2–3 señales.
- Velocidades: 4/8/1,5 m/s. ATV 20/40. Terminal 40.
- La stamina limita correr, escalar y reparar; el hambre limita correr y reparar.
- Los errores de descarga cuestan tiempo, no vidas; los errores de energía pueden costar la noche.
- No hay autosave por defecto; el guardado manual es parte del riesgo.
- Todo valor editable vive en `data/balance.tres` y en Resources de sistema.

## 10. Dirección de arte y audio

- **Estilo:** low-poly estilizado, original, coherente; nada de copiar la estética del original.
- **Paleta:** interiores beige/verde industrial; exterior azul noche, niebla y luces de sodio.
- **Audio:** sintetizado y samples originales; viento, pájaros, zumbido de fluorescencia, pasos, metal,
  radio. Sin música continua; la música solo aparece en momentos concretos.
- **Terror:** oscuridad real, linterna con batería, ruidos lejanos, silencios largos, eventos sutiles.
- **UI:** diegética siempre que se pueda; pantallas CRT, etiquetas, notas y LEDs.

## 11. Rendimiento

| Objetivo | Valor |
|---|---|
| FPS | 60 en GTX 1050 / hardware modesto |
| Draw calls | < 250 |
| Props pequeños | < 2k tris |
| Props medianos | < 8k tris |
| Máquinas | < 15k tris |
| Luces dinámicas | ≤ 4 con sombra en interiores |
| Física | Cuerpos dormidos; límite de objetos activos |

Se mide con F3 y una escena de debug. Cada hito debe dejar el presupuesto estable.

## 12. Arquitectura de contenido

- `data/balance.tres`: único lugar para valores globales.
- `data/signals/*.tres`: señales.
- `data/machines/*.tres`: máquinas y estados.
- `data/items/*.tres`: ítems, comidas, herramientas.
- `data/entities/*.tres`: entidades.
- `data/events/*.tres`: eventos.
- `data/store/*.tres`: tienda y upgrades.
- `data/locations/*.tres`: POIs y spawns.

Los sistemas se comunican por señales; quitar un sistema no debe romper los demás. La lógica de juego
vive fuera de las escenas, en `scripts/core/`, y se prueba sin render.

## 13. Hitos

| # | Hito | Estado |
|---|---|---|
| 0 | Investigación, catálogo y documentación | **cerrado** |
| 1 | Proyecto base: jugador 4/8/1,5 m/s, stamina, linterna, debug | **cerrado** |
| 2 | Framework Interactable/Grabbable/Machine/Panel/Item/Entity/Event + inventario | **cerrado** |
| 3 | Alpha Root Base en placeholders | **cerrado** |
| 4 | Energía: transformadores, breaker, apagones | **cerrado** |
| 5 | Estación de señales completa | **cerrado** |
| 6 | Ciclo diario, dron, cintas, tienda | **cerrado** |
| 5.6 | Sala de señales, mandos reales y disco físico | **cerrado** |
| 7 | Mapa exterior a escala, 24 platos, radares, torre | pendiente |
| 8 | Servidores, consola, hashcodes, reparación | pendiente |
| 9 | Estadísticas, dificultad y ajustes | pendiente |
| 10 | Entidades básicas, radar y noche | pendiente |
| 11 | Tier 2: ítems, cocina, crafting, ATV, cámaras | pendiente |
| 12 | Modelos definitivos | pendiente |
| 13 | Tier 3: eventos, facciones, sueños, logros | pendiente |
| 14 | Tier 4: secretos, Forbiddens, chistes, dimensiones | pendiente |
| 15 | Guardado, menús, accesibilidad y pulido | pendiente |

Detalle y criterios de aceptación en [`TASKS.md`](TASKS.md).

## 14. Decisiones tomadas

1. Godot 4.7.2, Forward+, GDScript tipado.
2. El proyecto vive en `godot/`; la versión web (Three.js) de la raíz está deprecada y no se modifica.
3. 1 unidad = 1 metro; Y arriba; −Z adelante.
4. Contenido data-driven; los nombres van en `data/`.
5. Nada de assets, código, textos ni audio del original.
6. Modo Normal como referencia de balance.
7. Sin pantallas de carga; mapa continuo de ~1,4 km.
8. El prototipo del hito 1 anterior se ajusta, no se rehace por reflejo: la linterna actual se conserva
   porque ya cumple; el movimiento y la stamina sí se rehacen.
9. La primera versión del mapa usa placeholders; los modelos llegan en el hito 12.
10. El guardado se implementa al final, pero el estado se diseña serializable desde el hito 2.

## 15. Decisiones abiertas

| Tema | Opciones | Recomendación |
|---|---|---|
| Nombre definitivo | **Kenoma** | Decidido el 2026-10-31; repo `kodkodnap/kenoma` |
| Renderer | Forward+ / Mobile | Forward+ para interiores y luces; revisar en hardware mínimo |
| Estilo visual | Low-poly limpio / low-poly sucio | Low-poly sucio coherente con la base |
| Tutorial | Sin tutorial / tutorial opcional | Tutorial opcional de 10 min, saltable |
| Historia | Réplica de arcos / arco propio | Arco propio con la misma estructura |
| Voces | Sin voces / textos | Sin voces; emails y notas |
| Idioma | ES / EN / ambos | ES primero; claves i18n desde el hito 2 |

Cada decisión se actualiza aquí antes de implementarla.

## 16. Protocolo de ideas

1. Toda idea nueva se anota en [`IDEAS.md`](IDEAS.md) con fecha, descripción y estado.
2. Si contradice el diseño o el original, se avisa en una línea y se propone la integración.
3. Si falta una decisión, se proponen dos opciones cortas con recomendación y se sigue la recomendada.
4. El cambio se refleja en `DESIGN.md` antes de tocar código.
5. Las ideas descartadas se quedan con su motivo.

## 17. Anti-objetivos

- No copiar assets, código, textos, audio ni interfaces del original.
- No convertir el juego en un shooter o en un walking simulator sin sistemas.
- No añadir minimapa permanente, waypoints ni misiones que lleven de la mano.
- No usar música épica ni jumpscares baratos como base del terror.
- No crear scripts gigantes ni lógica de juego dentro de las escenas.
- No superar el presupuesto de rendimiento por acumulación.

## 18. Definición de “hecho”

Un hito está hecho cuando:

- `--headless --import` termina sin errores.
- `--headless --script res://tests/smoke.gd` pasa entero.
- La función se puede probar jugando y está descrita en `TASKS.md`.
- El rendimiento no empeora el presupuesto.
- La documentación (`DESIGN`, `ARCHITECTURE`, `TASKS`, `ASSETS`) está al día.
- El commit contiene solo `godot/` y un mensaje claro.
