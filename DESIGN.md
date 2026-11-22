> **DEPRECATED.** Documento de diseño de la versión web (Three.js), congelada.
> El diseño vigente del juego vive en [`godot/docs/DESIGN.md`](godot/docs/DESIGN.md) (Kenoma).

# ESTÁTICA — Diseño

## 1. Concepto

Eres el operador nocturno de **Kestrel**, una estación de escucha en un valle alpino. Nadie más está despierto. Durante doce turnos recibes señales, las procesas con máquinas distintas y las vendes. Algunas señales no deberían existir. Algunas noches tampoco.

Inspirado en *Voices of the Void*, pero con contenido y assets originales y una intención opuesta al alpha infinito: **cerrar el juego**, quitar grind y hacer que el horror venga de lo que haces, no de una cinemática.

### Pilares

1. **Mecánica, no tutorial.** El juego explica lo mínimo. La cadena de decodificación se aprende leyendo la señal, no un popup. Nada de "pulsa para continuar".
2. **Contacto, no susto.** Las entidades observan, imitan, se acercan cuando no miras y reaccionan al escáner. No hay jumpscares de pasillo: hay consecuencias.
3. **Tensión sin castigo.** El estrés degrada tu equipo y tu percepción, pero no te mata. Fallar una cuota tiene coste, no game over.
4. **Final real, no lineal.** El día 12 se cierra la partida con una decisión que depende de lo que hiciste: transmitir, observar, cortar. Tres desenlaces, no un botón único al final de un pasillo.
5. **Rendimiento como diseño.** Geometría low-poly, instancing, sin shadow maps, audio sintetizado, arranque en segundos.

## 2. Estructura

| Acto | Días | Contenido |
| --- | --- | --- |
| I | 1–5 | Aprendizaje del loop, primeros contactos, hitos de las noches 3 y 5. Implementado. |
| II | 6–12 | Implementado: repetidor a 900 m y motonieve, triangulación, clima, averías/sabotaje, trueque, arquetipos nuevos y arco del operador anterior con decisiones persistentes. |
| Final | 12 | Tres decisiones en la consola, con epílogos distintos. |

El paso de acto no reinicia nada. Los hitos son **escenas cortas**, no una cadena de misiones: el resto del tiempo lo llena el sistema de eventos.

## 3. Turno

- 19:00 → 05:00. 600 minutos de juego, ≈1,15 s reales por minuto (≈11,5 min por turno).
- Cuota diaria: `80 + 45 × día` créditos (125 el día 1, 620 el día 12).
- Dos tareas opcionales por día (decodificar, escanear, vender, no sufrir apagones).
- Autoguardado cada 40 s y al cerrar turno. El reloj corre también con los paneles abiertos: estar en la consola no te protege.

Las cuotas cubiertas pagan una prima del 15 %. Las fallidas aplican una deducción y suman estrés. Tres fallos no expulsan al jugador: Control solo se pone más hostil en la radio.

## 4. Señales

### Captura

Una fuente del cielo tiene azimut, elevación, banda, modulación, cifrado y clase. El plato se apunta a mano (o con barrido automático a 8°/s). La fuerza de recepción es una gaussiana sobre la distancia angular, ampliada por la mejora del plato y reducida por el estrés y los apagones.

Grabar tarda 12 s y promedia la señal. La integridad final combina apuntado, mejora del plato y estrés:

```
calidad = media_señal × 0,92 + nivel_plato × 3,5 − estrés × 0,12 ± 2,5
```

### Clases

| Clase | Valor base | Fragmentos | Papel |
| --- | --- | --- | --- |
| Ruido | 4 | 0 | Fallo / degradación |
| Telemetría | 52 | 0 | Dinero constante |
| Baliza | 104 | 1 | Señal repetidora, primera pista de que algo contesta |
| Voz | 168 | 1 | Mensajes, pistas narrativas, cintas |
| Anómalo | 280 | 2 | Dispara contacto y estrés |
| Vacío | 0 | 3 | No tiene emisor; solo se entiende con la tabla de glifos |

Pesos por día: la telemetría baja, la voz sube desde el día 2, lo anómalo desde el 3 y el vacío desde el 4. Cada día tiene 6–9 fuentes, nunca a menos de 9° entre sí.

### Cadena de máquinas

1. **Espectro (SA-9).** Se mueve una ventana sobre 1250–1680 MHz. Tolerancia `3,2 + 1,7 × nivel_filtro`. Acertar cuesta integridad proporcional al desvío; fallar cuesta 16 de integridad y 9 de corrupción.
2. **Demodulador (DM-4).** Hay que leer la onda: AM (envolvente), FM (frecuencia), PULSO (tramos), COHERENTE (fase pura). Fallar cuesta 18 de integridad y 12 de corrupción.
3. **Patrón (PD-2).** Se muestra el texto parcial cifrado. La firma revela la transformación:
   - **Lenguaje directo**: sintaxis intacta.
   - **Armónico**: desfase constante en el alfabeto.
   - **Recursivo**: el mensaje está invertido.
   - **Glifos del vacío**: alfabeto desconocido; requiere la tabla (4 fragmentos).
   
   Fallar cuesta 14 de integridad y 11 de corrupción. Con integridad ≤12 o corrupción >82 la captura se convierte en ruido.

El texto se reconstruye de verdad: se aplica la inversa del cifrado, no una animación. Un jugador puede resolverlo leyendo.

### Valor

```
valor = base × (calidad / 100) × (1 − corrupción / 160)
```

Las capturas decodificadas se venden en la consola o en el propio decodificador. Vender suma a la cuota; archivar no.

## 5. Progresión

7 mejoras, sin árbol: cada una cambia una fórmula del bucle.

| Mejora | Efecto | Niveles | Coste base |
| --- | --- | --- | --- |
| Ganancia del plato | Huella de recepción y calidad | 4 | 140 |
| Filtro de banda | Tolerancia del espectro | 4 | 120 |
| Demodulador | Integridad al acertar | 3 | 180 |
| Grupo electrógeno | Apagones más cortos | 3 | 130 |
| Torretas de luz | Menos estrés cerca de luz | 3 | 110 |
| Cafetera | Recuperación de estrés | 3 | 90 |
| Traje térmico | Menos estrés por frío/contacto | 3 | 160 |

Cada nivel multiplica el coste ×1,8–2,1. No hay mejoras de "daño" ni combate: el progreso es de información y control.

## 6. Eventos

Un evento cada 38–62 minutos de juego dividido por la curva de peligro (más frecuentes a mitad de la noche), con 3–5 por turno. Peso modificado por día, estrés y si has transmitido.

| Evento | Desde | Efecto | Peso |
| --- | --- | --- | --- |
| Apagón | 1 | Corta corriente; hay que bajar a la caseta. Puede dejar una figura en el linde | 10–18 |
| Figura del linde | 1 | Silueta que solo avanza cuando no la miras | 15 |
| Tres golpes | 2 | Llaman a la puerta; a la tercera aparece tu doble en el ventanal | 10 |
| La antena se mueve sola | 2 | El plato apunta a una fuente que no está en la carta | 9 |
| Canción del servidor | 2 | Captura de micrófono sin pasar por el plato | 8 |
| Tu silueta | 3 | Figura con tu ropa dentro del edificio | 7 (única) |
| Algo herido en la valla | 2 | Contacto que se puede escanear o asustar | 6 (única) |
| Control | 1 | Radio: cuota, aviso si tu voz suena mal | 9 |
| El altavoz | 3 | Repite tu última frase del registro con tu voz | 7 |
| Huellas | 2 | Anillo de pisadas alrededor del edificio | 8 |
| Respuesta | 1+ | Solo si has transmitido; deja fragmento | 20 |
| Silencio | 4 | Se apaga el ambiente; tres figuras en el linde | 6 |

Hitos guionizados: el acto I tiene dos escenas (día 3 a las 03:00, señal plena sin fuente; día 5, la puerta de la antena abierta y contacto en el ventanal). El acto II añade ocho hitos (días 6–12): parte repetido, archivo del operador, apertura del repetidor, código de la puerta, cinta del operador anterior, registro firmado, preparación de la señal final y la decisión del día 12.

La fase 2 añade diez eventos más: tormenta (3), niebla (4), ventisca (5), sabotaje (5), imitador (6), comerciante (7), operador anterior (7), repetidor llama (8, solo si está abierto), aprendiz (9) y registro futuro (10).

## 7. Contacto y entidades

Siete tipos, todos siluetas negras sin cara:

- **Figura**: se congela si la miras, avanza 0,95 m/s si no. A 3,2 m desaparece y sube el estrés. Mirarla 3,4 s sin apartar la vista la retira y deja un fragmento.
- **Doble**: aparece en el ventanal; desaparece si la miras de frente y reaparece más cerca al apartar la vista.
- **Perro**: respira junto a la valla. Escanearlo da datos; acercarse demasiado lo espanta.
- **Coro**: tres siluetas lejanas que se balancean. Escanear una da dos fragmentos.
- **Imitador**: recorre tu rastro con unos segundos de retardo. Mirarlo 3 s lo retira; si te alcanza, se va y sube el estrés.
- **Comerciante**: espera junto al cajón del porche y gira la cabeza para seguirte. Si te acercas demasiado se marcha; el trato se hace en el cajón, no hablando con él.
- **Aprendiz**: aparece en tu posición habitual del tramo (la rutina se aprende tras 40 muestras) y se queda mirando. Observarlo 3,2 s lo retira.

Reglas:

- Observar exige **línea de visión real** contra los colliders: las paredes bloquean la mirada en ambos sentidos.
- El **escáner de campo** (Q) tarda 1,35 s con la entidad encuadrada. Convierte el contacto en datos, fragmentos y estrés.
- Huir no da nada. Observar da poco. Escanear da más y te expone.
- La tabla de glifos se desbloquea con 4 fragmentos.

## 8. Estrés y corriente

- Sube por estar fuera (0,055/s), de noche (0,013/s) y con los contactos. Baja en interiores iluminados, con café (una vez por turno, 12–26) y durmiendo (26 al cerrar turno).
- Efectos mecánicos: interfiere en la recepción (`estrés × 0,22`), tiñe la viñeta, sube el ruido del audio, acelera el pulso.
- Apagones: las máquinas no abren, la grabación se aborta, la luz interior cae. El cuadro del generador está en la caseta, fuera del edificio. Reiniciarlo deja 6 s de arranque. La mejora del generador acorta apagones.

### Clima

Cuatro estados deterministas: **clara**, **niebla**, **tormenta** y **ventisca**. Cada uno tiene ruido de recepción, estrés extra al estar fuera y multiplicador de visibilidad (0 / 6 / 26 / 34 de ruido; 1 / 0,45 / 0,5 / 0,22 de visibilidad, escalados por intensidad). A partir del día 6 el valle empeora y la ventisca entra en la tabla.

La tormenta puede tirar el grupo electrógeno (descarga de 14–36 s, acortada por la mejora del generador). La ventisca borra `flags['huellas']` al entrar. El clima se guarda en `state.weather` y se reproduce desde `rngState`.

### Averías

Las tres máquinas (espectro, demodulador, patrón) pueden fallar solas o por sabotaje. Una máquina rota no abre panel ni decodifica. Repararla con una pieza de repuesto (60 créditos) es instantáneo; calibrar a mano es gratis pero arriesgado: el primer intento parte de ~42 % y cada fallo sube el desajuste 0,07. El sabotaje siempre deja la máquina fuera de servicio y suma a `stats.sabotages`.

## 9. Final

Condición: día ≥ 12 y 12 fragmentos. En la consola aparece la decisión:

- **Cortar la señal**: apagar el receptor. Final de huida; la estación sigue escuchando.
- **Responder**: transmitir tu nombre. Final de suplantación; algo aprende a ocupar tu turno.
- **Dejar de escuchar**: apagar todo. Final de disolución; el silencio tiene textura.

Los epílogos no cambian las mecánicas, pero sí lo que el registro dice de ti. El estado guarda `ending` y muestra el final al reanudar. El epílogo incluye también las tres decisiones del acto II (archivo del operador, código de la baliza y registro firmado), guardadas en `state.decisions`.

## 10. Mundo

- Recinto de 62×50 m: laboratorio (sala de máquinas, racks, litera), plato de 8,4 m sobre pedestal de 3,2 m, caseta del generador, torre de radio, valla, cuatro torretas (dos con luz real), bosque instanciado y cordillera.
- Repetidor a 900 m al oeste, con tres mástiles de escucha. La motonieve (14 s reales por trayecto) conecta Kestrel, el repetidor y el origen triangulado.
- Terreno plano en el recinto y ondulado fuera; los props se colocan con la misma función de altura para no flotar.
- Nieve y estrellas como partículas; cielo con shader de degradado y banda tenue; niebla exponencial.
- Sin assets: todo es geometría y canvas.

### Repetidor y triangulación

Cada mástil mide un rumbo al emisor desconocido. La calidad de la medida es una gaussiana sobre el error de apuntado (`TRI_SIGMA = 7,5°`); por debajo de `TRI_LOCK = 0,55` el rumbo no se fija. Con dos o tres rumbos, `intersectBearings` resuelve la posición por mínimos cuadrados y descarta la medida si la dispersión supera 90 m.

El objetivo del día es determinista a partir de semilla y día: entre 260 y 620 m del repetidor, con 55 % de clase anómala y nombre propio (PUNTO CIEGO, POZO 14, LADERA SUR, AGUJA DE HIELO, CORRAL VACÍO). Al fijarlo se abre una zona transitable en el origen; registrar los restos da fragmentos y una captura. La desviación entre la medida y el emisor real se guarda como `error` y decide si el origen estaba donde creías.

## 11. Rendimiento

Presupuesto: **< 150k triángulos** y **< 250 draw calls**. Medido: ~27,5k triángulos y ~138 draw calls.

Técnicas: instancing para árboles, rocas, postes y valla; geometría fusionada/Compartida; 2 spotlights reales; sin shadow maps; sin postprocesado (viñeta, grano y scanlines son CSS); pixel ratio limitado a 1,5 y bajada automática a 1,1/0,8 si el frame medio cae por debajo de 55/48 fps; reloj y máquinas usan tiempo real con techo de 0,5 s para que un equipo lento no congele la partida.

En headless con SwiftShader (sin GPU) el juego va a 2–9 fps: es rasterizado por CPU y no representa el rendimiento real. La verificación automática comprueba el presupuesto de escena, no los fps de software.

## 12. Arquitectura

```
src/
  core/      lógica pura, sin DOM ni Three.js
    signals.ts       fuentes, captura, cadena, cifrados, valor
    sim.ts           reloj, eventos, cuota, turnos, acto II, final
    events.ts        catálogo de eventos y programador
    state.ts         estado, tareas, guardado versionado
    economy.ts       mejoras y venta
    triangulation.ts rumbos, intersección y objetivo del origen
    weather.ts       clima, ruido, visibilidad y descargas
    faults.ts        averías, calibración y piezas
    routine.ts       rutina del jugador por tramo
    time.ts          reloj y curvas de peligro
    rng.ts           mulberry32 serializable
  world/
    scene.ts     renderer, cielo, nieve, clima visual, calidad adaptativa
    level.ts     geometría, colliders, zonas (Kestrel/repetidor/origen), motonieve
    player.ts    FPS, colisiones, linterna, raycast
    entities.ts  comportamientos de contacto
    los.ts       línea de visión (puro)
  ui/
    hud.ts       HUD, pantallas, decisiones y epílogo
    panels.ts    máquinas, consola, triangulación, viaje y trueque
    types.ts     contrato entre UI y juego
  audio/audio.ts audio procedural
  main.ts        integración, host de eventos, clima, viaje, decisiones, bucle
test/            lógica pura (vitest)
scripts/smoke.mjs verificación e2e (Edge headless)
```

Regla: todo el balance y las reglas viven en `core/`; el mundo y la UI solo leen estado y llaman acciones. Los eventos piden efectos al `EventHost` para poder testearse sin navegador.

## 13. Fases

### Fase 1 — hecha

Loop completo, acto I, eventos, entidades, escáner, corriente, estrés, economía, guardado, final alcanzable, tests y smoke.

### Fase 2 — hecha (días 6–12)

- **Estación repetidora** a 900 m: motonieve, triangulación con tres antenas para localizar el origen de una señal y emplazamiento transitable.
- **Más arquetipos de contacto**: el imitador que recorre tu rastro con retardo, el comerciante del cajón de trueque y el aprendiz que aparece en tu rutina.
- **Averías y sabotaje**: máquinas que fallan, calibración arriesgada, piezas de repuesto.
- **Clima**: tormentas que suben el ruido y cortan la luz, niebla que cierra la visibilidad y ventisca que borra huellas.
- **Acto II**: arco del operador anterior, 8 hitos y 3 decisiones persistentes que aparecen en el epílogo.

Verificada con 117 tests unitarios y smoke e2e de 77 comprobaciones contra dev y preview.

### Fase 3 — cierre

- Epílogos ampliados por desenlace, con variantes según contactos/transmisiones.
- Archivo persistente entre partidas (metaprogresión ligera, no obligatoria).
- Empaquetado de escritorio (Tauri/Electron), mando, accesibilidad (subtítulos, daltonismo, sensibilidad), localización ES/EN.
- Modo "sin sustos" opcional que sustituye apariciones por audio y texto.

## 14. Límites conocidos

- Tres emplazamientos (Kestrel, repetidor y origen), pero el exterior es pequeño a propósito; repetidor y origen no tienen interiores.
- Sin oclusión vertical en la línea de visión (solo planta); suficiente porque no hay plantas altas ni pisos.
- El equilibrio de cuotas se calculó sobre partidas cortas; todavía no hay telemetría real.
- En navegadores sin pointer lock (móvil), el juego no es jugable todavía; no es objetivo hasta la fase 3.
