# Diseño — Kenoma

> Nombre definitivo: **Kenoma**. Repo: <https://github.com/kodkodnap/kenoma>.
>
> **Referencia de fidelidad:** *Voices of the Void* (VotV). Es una **inspiración al 100% en pilares,
> flujo multi-máquina, escala y bucle sistémico**, pero con **identidad visual, arquitectura, nombres,
> contenido y giro propios**. No se copian assets, código, textos, audio ni interfaces literales del
> original. El catálogo sistémico base está en [`ORIGINAL_FEATURES.md`](ORIGINAL_FEATURES.md).
>
> **Dirección visual maestra:** [`../../references/art-direction/base-exterior.png`](../../references/art-direction/base-exterior.png)
> y [`../../references/art-direction/base-interior-signal-room.png`](../../references/art-direction/base-interior-signal-room.png).

## 1. Visión

Eres el operador aislado de una estación brutalista de los años 80 incrustada en la ladera nevada
de un valle alpino enorme. Cada día recibes una tarea: buscar señales, descargarlas, procesarlas en
distintas máquinas físicas, recorrer el valle con tu **snowcat** para calibrar platos y mantener
transformadores, imprimir reportes y entregar tu trabajo.

**Identidad emocional (cálido vs. frío, cero claustrofobia):**
- **Refugio amplio y cálido por dentro:** La base tiene espacios grandes y respirables iluminados con
  luz cálida de tungsteno, madera, alfombras gastadas y pantallas de fósforo. Debe sentirse como un
  lugar acogedor donde te sientes a gusto trabajando, no como un cubículo apretado.
- **Tensión sistémica, nunca estilo FNAF:** El miedo no viene de esperar a ciegas un jumpscare en la
  oscuridad ni de defender puertas sin pistas. La tensión nace de la **escala del valle**, el
  **silencio**, el **contraste con los pasillos largos en penumbra y el exterior en hora azul**, y
  **eventos aleatorios con indicios reales** (lecturas raras, ruidos, sombras lejanas vistas desde el
  ventanal elevado, fallos eléctricos, huellas en la nieve).

## 2. Contrato de fidelidad

| Se replica / inspira (de VotV) | Giro propio de Kenoma |
|---|---|
| Bucle diario, tareas, entregas, puntos y multas | Estación alpina nevada en voladizo (brutalismo años 80) |
| Flujo multi-máquina separado (no todo en un solo PC) | Estilo PBR semi-realista estilizado (*Firewatch* + *Pacific Drive* + *Signalis*) |
| Energía, breakers, transformadores y servidores | **Snowcat con orugas** para un valle nevado enorme (en vez de ATV) |
| Estadísticas, dificultad y reglas de partida | **Impresora matricial física** para hashcodes, alertas y reportes |
| Mapa continuo grande con platos y POIs | Espacios amplios, luz cálida interior y terror con indicios reales (anti-FNAF) |
| Máquinas físicas con perillas, botones, discos y pantallas | Contenido, historia, señales, entidades, texto y audio 100% originales |

## 3. Pilares

1. **La señal manda.** Todo el turno gira en torno a localizar, descargar, reproducir, procesar y entregar señales.
2. **Flujo distribuido en máquinas físicas.** Nunca concentrar todo en una sola computadora: cada paso del flujo tiene su consola física (Coordenadas, Descargas, Reproducción, Procesado, Terminal de Gestión, Impresora Matricial).
3. **Espacios amplios y refugio cálido.** Nada de salas claustrofóbicas ni pasillos angostos: techos altos, buena circulación, luz cálida en las zonas de trabajo y descanso.
4. **Tensión justa y con pistas.** Eventos aleatorios y entidades que se anuncian por indicios en el mundo o en los instrumentos, nunca ataques gratuitos sin aviso.
5. **Escala real que exige vehículo.** El valle es suficientemente grande como para que caminar a las zonas lejanas tome 1–2 días de juego; el **snowcat** es indispensable.
6. **Mundo continuo y data-driven.** Base, valle nevado, platos y POIs sin pantallas de carga; contenido en `data/` fuera de los scripts.
7. **Rendimiento medido.** 60 FPS en hardware modesto; presupuesto controlado en cada hito.

## 4. Bucle de juego

```text
00:00  Correo con la tarea del día + eventos nocturnos
06:00  Entrega / recogida de suministros y pedidos (plataforma / zonas definidas)
       Coordenadas → Descargas → Reproducción → Procesado (FASE → LOCK) → Disco físico
       Impresora matricial → hashcodes / reportes / alertas físicas en papel
       Recorrer el valle en Snowcat → calibrar platos, reparar servidores y transformadores
       Gestionar energía, descansar, comer, vender y comprar
       Entregar la caja/discos antes de medianoche
```

## 5. Mapa y escala

| Zona | Contenido | Escala / Concepto |
|---|---|---|
| Estación principal | Ala de mando en voladizo, pasillos de 3 m, salas amplias, garaje y sótano | Edificio en ladera sin vallas metálicas alrededor |
| Claro frontal y pista | Salida del garaje, aparcamiento del snowcat, postes de madera, bosque de pinos | Abierto y visible desde el ventanal elevado |
| Valle alpino nevado | Platos satelitales, transformadores, torres, radares y futuras estructuras/POIs | Mapa grande (~2–3+ km efectivos); ir a pie a zonas lejanas cuesta 1–2 días |
| Pico lejano | Domo radar / antena con baliza roja parpadeante | Referencia visual constante desde el ventanal |

- **1 unidad = 1 metro.** Origen en el suelo, ejes Y arriba, −Z adelante.
- **Sin vallas de eslabones (`chain-link fences`)** rodeando el claro principal: aislamiento abierto en la nieve y pinos oscuros.
- Carga continua por distancia, LODs y vegetación con `MultiMesh`.

## 6. Estación Kenoma (Base principal)

La distribución anterior de 22 salas cuadradas (`Alpha Root Base` placeholder) se sustituye por una arquitectura diseñada a partir de las dos referencias visuales:

### 6.1 Volumetría exterior
- **Ladera de montaña:** el edificio nace incrustado en la roca y nieve.
- **Ala de mando en voladizo (Planta Alta):** sobresale dramáticamente hacia el claro sobre pilares robustos de acero y hormigón, con **ventanal panorámico inclinado** y antena parabólica en la azotea.
- **Nivel de suelo (Planta Baja):** bajo el voladizo se abre el **garaje amplio** con portón enrollable para el **snowcat**, iluminado con luz cálida sobre la entrada.
- **Plataforma de entregas:** ubicada en el mismo edificio (terraza/plataforma de carga o acceso exterior); se contempla además aleatorizar o habilitar entregas en puerta exterior u otras zonas según evolucione el sistema de entregas.

### 6.2 Distribución interior (espaciosa, sin agobio)
| Nivel | Zona | Rol y atmósfera |
|---|---|---|
| **Planta Alta (Voladizo)** | **Sala de Control de Señales** | Techo alto con vigas y bandejas portacables, gran ventanal panorámico hacia el claro y monte del radar, consolas curvas (Coordenadas, Descargas, Reproducción, Procesado), impresora matricial, mesa cálida de madera sobre alfombra gastada con lámpara de escritorio y desnivel amplio de acceso. |
| **Planta Alta (Cuerpo interior)** | **Pasillo principal (3 m de ancho)** | Parte desde la derecha de la sala de mando con iluminación tenue y caída progresiva a sombra; ancho y despejado para no resultar claustrofóbico. |
| **Planta Alta (Alas)** | **Sala de Servidores** | Estancia amplia para racks con LEDs verde/rojo y consola de diagnóstico/hashcodes. |
| **Planta Alta (Alas)** | **Zona de Descanso / Dormitorio y Cocina** | Espacio amplio y cálido (cama, cafetera, nevera, microondas, mesa) — verdadero refugio personal. |
| **Conexión vertical** | **Núcleo de escalera / montacargas amplio** | Conecta cómodamente Planta Alta, Planta Baja y Sótano. |
| **Planta Baja** | **Garaje del Snowcat & Carga** | Estancia grande para aparcar/revisar el snowcat, workbench y recepción de entregas. |
| **Planta Baja** | **Acceso / Vestíbulo frío** | Transición exterior-interior con taquillas/equipo de campo. |
| **Sótano** | **Cuarto de Energía y Breaker** | Subsuelo técnico amplio con el cuadro de breakers y generador auxiliar (zona fría/industrial, no laberíntica). |

### 6.3 Reglas arquitectónicas de la base
- **Espacio generoso:** pasillos de ≥ 3 m de ancho, techos altos (≥ 3,5–4 m en salas principales), ningún botón ni consola obliga a agacharse o meterse en huecos apretados.
- **Luz cálida como ancla:** en las zonas de trabajo y vida hay luz tungsteno/ámbar acogedora; la tensión viene de la escala del edificio, los pasillos largos hacia zonas técnicas y el exterior frío visible por los cristales.

## 7. Sistemas principales

### 7.1 Cadena de Señales (multi-máquina)
- **Coordenadas** (`CoordinatesPanel`): radar/PPI, azimut, elevación y ping.
- **Descargas** (`DownloadsPanel`): sintonía de frecuencia, polaridad, detector y descarga a memoria.
- **Reproducción y Base de Datos** (futura máquina física en lugar de overlay): escucha, guardado e inventario de señales.
- **Procesado** (`ProcessingPanel`): ajuste de fase sobre CRT hasta `LOCK` y exportación a disco físico (`DiskMedia`).
- **Impresora Matricial (nuevo aparato físico):** imprime en papel continuo hashcodes, reportes diarios, avisos de sistema y alertas anómalas.
- **Terminal de Gestión / Tienda / Correo:** panel separado para tareas diarias, pedidos y compras.

### 7.2 Transporte y Entregas
- **Snowcat de orugas:** vehículo físico principal en el garaje; imprescindible para recorrer el valle nevado, cargar cajas/discos o llegar a platos y estructuras lejanas.
- **Entregas / Dron:** aterrizaje en plataforma del edificio, con posibilidad futura de entregas en puerta exterior u otras zonas del recinto/valle.

### 7.3 Energía, Servidores, Stats y Eventos
- **Energía (`PowerSystem`):** 3 transformadores en el valle, breaker de 5 circuitos en sótano, redistribución de carga y apagones reparables.
- **Servidores y Satélites:** mantenimiento en la sala de servidores y en los platos exteriores; comandos e impresión de hashcodes.
- **Estadísticas (`PlayerStats`):** hambre, stamina, salud (comunicada por viñeta/audio, sin barra invasiva), sueño y paranoia/estrés.
- **Eventos y Entidades (anti-FNAF):** eventos aleatorios con señales de aviso previas (en instrumentos, audio lejano, entorno nevado o desde el ventanal elevado), nunca un ataque injusto sin pistas.

## 8. Dirección de arte y audio

- **Estilo:** **PBR semi-realista estilizado** — un paso por encima de *Firewatch* en limpieza de formas y legibilidad, con la atmósfera volumétrica y materialidad retro-industrial de *Pacific Drive* y la tensión espacial de *Signalis*. **No fotorrealismo**, y tampoco low-poly plano sin materialidad.
- **Materiales:** hormigón brutalista con juntas y desgaste, acero oscuro estructural, metal pintado envejecido de los 80, madera cálida en mobiliario personal, vidrio amplio con reflejo sutil, nieve con volumen y escarcha/carámbanos.
- **Paleta oficial:**
  - **Exterior (Hora azul / Noche lunar):** azul crepuscular (`#1B2B40` – `#3B5878`), nieve en sombra azulada, bosque de pinos verde-negro desaturado, niebla fría y **único acento rojo lejano** en el domo radar del pico.
  - **Interior habitable (Refugio):** tungsteno/ámbar cálido (`#FFB454` – `#E88B38`), madera natural, alfombras gastadas en tonos tierra/rojo apagado.
  - **Instrumentación:** consolas gris pizarra/beige industrial, CRTs en fósforo verde (`#63F29B`) y ámbar (`#FFAD42`).
  - **Pasillos y áreas técnicas:** hormigón gris frío bajo luz tenue escasa hacia sombra profunda (`#0B0E13`).
- **Audio:** zumbidos eléctricos, viento alpino, nieve bajo pasos y orugas del snowcat, impresora matricial, relés mecánicos y silencios largos. Sin música continua.

## 9. Rendimiento y arquitectura técnica

- **Godot 4.7.2 stable · Forward+ · GDScript tipado estático.**
- Presupuesto objetivo: `< 250` draw calls, `< 150k` triángulos visibles, `60 FPS` en hardware modesto (GTX 1050).
- Lógica pura desacoplada en `scripts/core/`, datos en `data/`, verificación con `tests/smoke.gd`.
- **Pipeline de modelos:** prototipado con placeholders dimensionados en Godot + fichas técnicas en `docs/ASSETS.md` para generar los modelos definitivos en **OpenCode + Blender MCP** cuando corresponda.

## 10. Anti-objetivos

- No copiar assets, código, textos, audio ni interfaces literales de VotV.
- No hacer pasillos ni habitaciones claustrofóbicas/apretadas.
- No hacer terror tipo FNAF (esperar sustos sin pistas mientras miras una pantalla).
- No meter todo en una sola computadora ni poner minimapa/waypoints permanentes.
- No mezclar estilos visuales (ni low-poly plano ni fotorrealismo sucio).
