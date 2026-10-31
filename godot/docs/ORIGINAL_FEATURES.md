# Catálogo del original — Voices of the Void

> **Uso:** documento de referencia para replicar sistemas y sensación, **no** para copiar contenido.
> No se copian assets, código, texturas, audio, textos ni nombres de archivo del original. Los nombres
> de sistemas y entidades se conservan solo como referencia de diseño y vivirán en `data/` para poder
> renombrarlos sin tocar código.
>
> **Fuente principal:** wiki oficial de Voices of the Void, <https://voicesofthevoid.wiki.gg>.
> Consulta: 2026-10-30. Versión estable documentada: **0.9.0n**. La wiki sigue viva; este catálogo
> registra lo investigado, no pretende ser una copia literal de cada artículo.

## Leyenda

### Prioridad

| Tier | Significado | Criterio |
|---|---|---|
| **T1** | Núcleo | Sin esto el juego no se siente como el original: bucle diario, señales, energía, servidores, mapa, stats y amenazas básicas. |
| **T2** | Profundidad | Alarga la vida del juego y da libertad: ítems, crafting, vehículo, cámaras, módulos, cocina, pesca, excavación, construcción. |
| **T3** | Narrativa | Eventos guionizados, facciones, personajes, sueños, logros y arcos. |
| **T4** | Secretos y caos | Contenido meta, chistes, entidades prohibidas, dimensiones, reglas especiales. |

### Estado

| Estado | Significado |
|---|---|
| `investigado` | Documentado aquí; todavía no hay diseño detallado ni código. |
| `prototipo` | Existe una versión jugable heredada del hito 0/1, pendiente de rehacer. |
| `diseñado` | Está en `DESIGN.md` y `ARCHITECTURE.md`, listo para implementar. |
| `hecho` | Implementado y verificado con smoke. |
| `descartado` | Se decidió no hacerlo; queda el motivo. |

---

## 1. Núcleo: bucle diario

| Elemento | Reglas del original | Prioridad | Estado |
|---|---|---|---|
| Día de juego | Cada día dura entre 60 y 96 minutos reales según dificultad. El día avanza aunque el jugador no haga la tarea. | T1 | investigado |
| Correo de tarea | A medianoche llega un correo de Dr. Bao con: N señales de niveles concretos, N hashcodes de satélites y 2 cintas de datos. | T1 | investigado |
| Entrega | La caja de discos, el zip drive y la caja de cintas se meten en el saco del dron. El dron se llama desde el panel del garaje y se despide desde el mismo panel. | T1 | investigado |
| Recompensa | Puntos por tarea, bonus semanal creciente hasta 800, venta de discos e ítems, minijuegos y logros. | T1 | investigado |
| Castigo | Multa por tarea fallida, desactivable en las reglas de partida. | T2 | investigado |
| Horario | El dron trae el pedido diario y una unidad de disco vacía a las 06:00. El correo de tarea llega a las 00:00. | T1 | investigado |
| Descanso | Dormir acelera el tiempo hasta que el jugador despierta o la stamina llega a 100; no se puede empezar a dormir por encima de 80. | T1 | investigado |
| Ritmo | El jugador decide cuándo trabajar, dormir, explorar o reparar. No hay pantallas de carga ni misiones encadenadas fuera de los eventos. | T1 | investigado |

### Dificultad

| Modo | Hashcodes/día | Señales/día | Día real |
|---|---:|---:|---:|
| Easy++ | 1 | 1 | 96 min |
| Easy | 2 | 1–2 | 80 min |
| Normal | 3 | 2–3 | 75 min |
| Hard | 4 | 3–4 | 67,2 min |
| Hard++ | 5 | 4–5 | 60 min |

La dificultad también altera el drenaje de comida/stamina, la dificultad de los minijuegos y algunas
propiedades de entidades. **Normal** es la referencia de diseño y balance.

---

## 2. Señales

### 2.1 Catálogo

| Dato | Valor |
|---|---|
| Señales totales | 269 (44 no obtenibles en Story Mode) |
| Tipos | planetas, exoplanetas, gigantes gaseosos, planetas enanos, asteroides, cometas, estrellas, agujeros negros, objetos, desconocidos |
| Variantes | enanas rojas, enanas marrones, enanas blancas, estrellas de neutrones |
| Contenido | texto, audio, imagen del detector, “looker” con feed en vivo, señales únicas, de historia, de evento y de sandbox |
| Copias | una copia o un ID ya vendido valen 0 puntos; se marca con luz amarilla |
| Procesado | sube el nivel de la señal y su multiplicador de precio; también puede revelar o eliminar datos |

### 2.2 Precio

```
precio = precio_base × multiplicador_calidad × multiplicador_nivel
```

| Nivel | Multiplicador |
|---|---:|
| 0 | 0,4 |
| 1 | 0,6 |
| 2 | 0,8 |
| 3 | 1,0 |

| Calidad | Multiplicador |
|---|---:|
| very_low | 0,4 |
| low | 0,8 |
| normal / good | 1,0 |
| great | 1,2 |
| high | 1,6 |
| very_high | 1,8 |
| unknown | 0,5–2,0 aleatorio |

### 2.3 Cadena de la señal

```
Coordinates → Downloads → Playback → Processing → Drive → venta / tarea
```

| Etapa | Qué hace el jugador | Reglas y fallos | Prioridad |
|---|---|---|---|
| **Coordinates** | Mueve un cursor por el cielo, hace quick scan y triangula con 3 radares. | WASD; Shift = quick scan; 1/2/3 = mover radar automático; Alt = control manual; Enter = ping. Puede fallar por satélites activos, señal débil, objeto inválido o error de sensor. | T1 |
| **Downloads** | Ajusta frecuencia y polaridad con 6 perillas y espera. | Perillas de polaridad 1/5/15 sobre 0–360; frecuencia 1/10/100 sobre 0–1000; 3 posiciones de dirección de polaridad; toggles; el detector sube a 100%; tormentas desestabilizan; guardar con 100% de descarga y detector. | T1 |
| **Playback** | Escucha la señal, la guarda en la base de datos o la exporta a un disco. | No es obligatorio “escuchar” para avanzar; el disco se puede vender o procesar. | T1 |
| **Processing** | Procesa por niveles 1, 2 y 3. | Requiere mejora `processing_level`; cada nivel necesita pulsar Start otra vez salvo módulo automático; el valor de venta sube. | T1 |
| **Venta** | Caja de discos al dron o venta directa. | La caja guarda 8 discos; el dron paga al llegar a HQ. | T1 |

### 2.4 Eventos de señal

Se disparan al descargar, reproducir o procesar ciertas señales. Ejemplos documentados:

`Kerfur-Omega Sleep Scare`, `Magnet Skeleton`, `Pink Beam & Rozital Engine Awakening`,
`Shitting Duende`, `Shorts Ariral Teleport`, `Tardis`, `TriFO`, `Virus`, `Zombie Deer`,
`The Evil`, `SKELEO N APPEARS`.

Algunos exigen la regla “Funny”. El caso `evil` es un final: si se procesa a nivel 3 y no se borran
todas las copias en 12 minutos reales, termina la partida.

### 2.5 Señales únicas y de historia

Hay señales que solo aparecen una vez, señales con audio/imagen fija, señales que cambian el mundo y
señales que forman parte del arco narrativo. El catálogo completo no se copia: se generará uno propio
con la misma estructura de datos y una tabla de señales original.

---

## 3. Estación de señales (4 paneles)

| Panel | Controles | Upgrades | Módulos físicos |
|---|---|---|---|
| Coordinates | cursor, quick scan, 3 radares, ping | cursor_speed, cursor_drift, ping_speed, ping_cooldown, coordinate_speed, ping_strength (16 niveles) | triangle visualise |
| Downloads | 6 perillas, 2 toggles, dirección de polaridad, detector, guardar/borrar | download_speed, filter_size, detector_sensitivity, detector_frequency, detector_quality | automatic polarity, autosave, storm filter |
| Playback | lista, play/pause, volumen, exportar, guardar | — | spectrogram |
| Processing | importar, Start/Stop, nivel máximo | processing_speed, processing_level | automatic processing |

- Los paneles se conectan por **discos**: cada uno tiene ranura y botón Import/Export.
- La estación tiene **12 ranuras de módulos** detrás de los paneles; el panel 3 no se puede abrir
  (en el original hay un corazón humano dentro, guiño que no se copia).
- Instalar un módulo con la estación energizada **explota**. Hay que apagar Calculations, Downloading,
  Coordinates y Playing desde el breaker.
- El radar tiene **4 ranuras** y 5 módulos compatibles; no caben todos.

---

## 4. Computadora principal

| Pestaña | Función | Prioridad |
|---|---|---|
| Upgrades | Mejoras digitales de Coordinates, Signal Processing, Detector, Radar y Misc. | T1 |
| Database | Señales guardadas; previsualizar, copiar (copia no vendible hasta procesar). | T2 |
| Email | Tareas, bonus, ventas, avisos de torre y eventos. | T1 |
| Store | Essentials, Food, Tools, Machines, Storage, Deco, Misc, Upgrades, Favorites. | T1 |
| Advancements | Progreso por partida. | T3 |
| Cameras | Ver cámaras, rotar, zoom, linterna, IR, control remoto de drones/Kerfur. | T2 |
| Media | Fotos y vídeos; borrar, exportar, imprimir. | T2 |
| Components | Breaker remoto; 30 s por defecto, hasta 1 s con mejora. | T1 |
| Viewer | Mover bloques de datos entre disquete, buffer interno y zip drive. | T1 |

### 4.1 Upgrades

| Categoría | Upgrades | Coste total |
|---|---|---:|
| Coordinates | cursor_speed, cursor_drift, ping_speed, ping_cooldown, coordinate_speed, ping_strength | 3.090 |
| Signal Processing | processing_level, processing_speed, download_speed | 1.560 |
| Detector | detector_strength, detector_update_frequency, detector_quality | 1.545 |
| Radar | radar_history, radar_speed | 747 |
| Misc | Remote_breaker_control_time | 360 |
| **Total** | | **7.302** |

El precio sube linealmente por nivel; se puede reembolsar la mayor parte. Varias mejoras antiguas
pasaron a ser **módulos físicos** en 0.9.0.

### 4.2 Módulos físicos

| Módulo | Efecto | Precio |
|---|---|---:|
| Automatic polarity adjustment | Elige la dirección de polaridad correcta. | 120 |
| Autosave signal to database | Guarda la señal al descargarla. | 60 |
| Automatic signal processing | Procesa hasta el nivel elegido sin pulsar Start cada vez. | 135 |
| Remote keyboard | Controla cámaras, drones y Kerfur con teclado. | 300 |
| Global alert | Aviso por servidor, radar o torre dañados. | 75 |
| Spectrogram | Vista de espectrograma en Playback. | 75 |
| Storm filter | Elimina la interferencia de tormenta al descargar. | 225 |
| Log tapes compression | Acelera las cintas de datos. | 400 |
| Lightning prediction | Redirige rayos a pararrayos en 50 m. | 350 |
| Coordinate triangle visualise | Dibuja el triángulo de los 3 radares. | 150 |
| Radar colors | Colorea entidades por tipo. | 100 |
| Radar alarm | Alarma cuando aparece una entidad. | 100 |
| Radar radius | Radar de 1400×1400 m en vez de círculo de 1400 m. | 200 |
| Radar path tracking | Dibuja la trayectoria de las entidades. | 250 |
| Radar radial search | Escaneo radial expansivo. | 200 |

---

## 5. Energía e infraestructura

| Elemento | Reglas | Prioridad |
|---|---|---|
| Transformadores | 3 en el mapa. La estabilidad baja según el consumo. A 0 se corta toda la base. Se reinicia con el botón rojo dos veces (encender y resetear a 100). Se puede dañar a golpes o explosiones. | T1 |
| Breaker | Panel en el sótano con 5 switches: Calculations, Downloading, Coordinates, Playing, Utilities. | T1 |
| Cálculos | Procesamiento, consolas y los 30 servidores de la base. | T1 |
| Downloading | Solo el panel de descarga. | T1 |
| Coordinates | Solo el panel de coordenadas. | T1 |
| Playing | Solo el panel de playback. | T1 |
| Utilities | Computadora principal, luces, enchufes y puertas de seguridad. | T1 |
| Redistribución | Apagar componentes reduce la pérdida de estabilidad y acelera los restantes. Con todo apagado la pérdida puede bajar al 6%; con uno activo, al 26,6–40%. | T1 |
| Control remoto | Components tarda 30 s por defecto; la mejora lo baja a 1 s. | T1 |
| Apagón | Todos los breakers pasan a off; hay que reparar el transformador caído antes de resetear. | T1 |
| Torre de radio | Se degrada; si se cae, el dron no llega. Se repara con minijuego de luces. | T1 |
| Radares de coordenadas | 3 torres, 8 fusibles cada una como salud. Si se rompen, minijuego. | T1 |
| Turbinas eólicas | 4 en el mapa; parte de la infraestructura y del paisaje. | T2 |
| Pararrayos | Protegen la base de rayos; módulo de predicción. | T2 |
| Lluvia/tormenta | Afecta descarga, ruido y electricidad; el filtro de tormenta lo elimina. | T2 |

### 5.1 Servidores

| Dato | Valor |
|---|---|
| Servidores totales | 54 |
| En la base | 30, en el Server Network Room; aceleran Processing |
| En satélites | 24, uno por plato; aceleran Downloads y guardan hashcodes |
| Estado | Luz verde intermitente = sano; roja = caído |
| Reparación | Minijuego manual (5 puntos, +15 por récord), kit instantáneo, Kerfur u Omega |
| Protección | Disquete azul con 4 bloques de reparación |
| Mejora | Hasta 3 Server Upgrades por servidor, reducen errores de `sv.request` |

Minijuegos documentados: **Math, Wires, Hacking, Slider, Maze, Pipes, Simon Says, Bit Fit, Fix**.
Hay variantes troll y **Critical Error**. El original permite desactivarlos por reglas de partida.

### 5.2 Platos satelitales

| Dato | Valor |
|---|---|
| Cantidad | 24 (designaciones B–Y) |
| Estructura | Base de hormigón, plato móvil, pasarela, sala de servidor y consola |
| Precisión | Cada plato tiene precisión; afecta a la velocidad de descarga |
| Calibración | `sd.calch` lista, `sd.cal [nombre]` calibra uno, `sd.calall` todos |
| Bloqueo | Un plato con servidor caído no se puede calibrar |
| Hashcode | Disquete en el servidor + `sv.request`; luego `sv.eject` |

---

## 6. Estadísticas del jugador

| Stat | Rango | Reglas | Prioridad |
|---|---|---|---|
| Comida | 0–100 | <20 no correr ni reparar servidores; ≤15 alucinaciones de comida y ragdoll; 0 daño. | T1 |
| Tolerancia | oculta | Comer lo mismo cansa; se restaura durmiendo; <10 come cualquier cosa; desactivable. | T2 |
| Sabor | oculto | Alimentos sanos tienen mejor sabor; solo importa con tolerancia activa. | T2 |
| Putrefacción | — | La comida se pudre fuera de contenedor/inventario/nevera; la podrida ragdolliza y daña. | T2 |
| Stamina | 0–100 | Baja con el tiempo; escalar cuesta 0,5; dormir recupera; no se empieza a dormir >80; <15 no correr/escalar/reparar; 0 colapso. | T1 |
| Insomniac | ~10–20 | Entidad que aparece con poca stamina, persigue y fuerza un sueño; desaparece a 20. | T3 |
| Salud | 0–100 | Sin barra; viñeta. Daño por ahogo, radiación, fuego, caída, intoxicación, explosión o entidad. | T1 |
| Cáncer | — | Baja la salud máxima; fumar o radiación; tos. | T2 |
| Sangrado | — | Daño específico; desactivable. | T2 |
| Meta Paranoia | — | Durante un evento no se puede pausar, guardar ni dormir; textos glitch. | T2 |
| Reputación | oculta | Determina eventos de facciones; Arirals es la única implementada. | T3 |

---

## 7. Economía, tienda e ítems

- La tienda se abre desde la computadora principal. Los pedidos llegan por dron.
- La venta normal es **mitad del precio de compra**; algunos ítems valen 1 o 0.
- El dron tiene inventario infinito y se puede quitar el saco para transportarlo.
- El `Sell Gun` convierte objetos en monedas.
- Los puntos se gastan en tienda, upgrades y módulos; las multas son opcionales.

### 7.1 Categorías y ejemplos

| Categoría | Ítems documentados (nombres de referencia) |
|---|---|
| **Essentials** | Drive, Drive Box, Battery, Gas Can, Cameras, Notepad, Paper Sheet, Sleeping Bags, Syrup Bottle, Pills Bottle, Pill Box, Sleep Pills, Heavy Meds, First Aid Medkit, Toilet Paper Roll, Car Keys, Cooking Book, Compass, Flashlight, Glasses, Crank Flashlight, Bandage, Big Flashlight, Data Tapes, Data Tape Case, Floppy Discs, Zip Drive, Floppy Box, Fuse |
| **Food** | Burger, Food Box, MRE, Shrimps Pack, Coffee Chocolate Bar, Cake, Cookie, Pizzas, Taco, Meatball, Toblerone, Pumpkin, Chicken Nugget, Bun, Banana, Popcorn Bag, Cheese, Bread, Cucumber, Lemon, Mango, Orange, Pineapple, Tomato, Watermelon, Beer, Baguette, Hotdog, Steak, Flour Bag, Rolling Pin, Bread Mold, Baking Tray, Milk Bottle, Sugar Bag, Mittens |
| **Tools** | Crowbar, Digital Map, Rock, Beacon, Toolbox, Digital Camera, Hook, Metal Detector, Password Changer, Hammer, Roach Repellent, Lighter, Fire Extinguisher, Thermometer, Ball of Red String, Pencil, Meter Ruler, Measuring Tape, Workbench, Pin Box, Can Opener, Kitchen Knife, Wall Builder, Wall Fixer, Swatter, Nailgun, Sell Gun, Pressure Washer, TV Remote, Hacksaw, Rake, Printer Camera |
| **Machines** | Coffee machine, Arcade machine, TV, Plasma TV, Medium TV, Erie head TV, Radio, Fax/Printer, Microwave, Portable hot plate, Battery charger, 3D Printer, Smoke Detector, Broomba, Remote drone, Kerfur, Woodchipper, Frame, Portable Mini TV, UV Light, Mini Oven, Portable PC, Car Battery Charger |
| **Storage** | Barrel, Crate, Backpack, Drive Rack, Bedside Tables, Disc Box, Cardboard Boxes, Bookshelf, Drawer, Wardrobe, Minifridge, Plastic Crate, Fanny Pack, Scrap Box |
| **Deco** | Clocks, Curtains, Wooden Pallet, Cacti, Vase, Soccer Ball, Wooden Chairs, Pet Rock, Rugs, Spotlight, plushies, Glowsticks, Pictures, Shelf, Basketball Hoop, Alien Figure, Balloon Pack, Planks, Metal Sheet, Flags, Traffic Cone, Wet Floor Sign, Desk Lamp, Couch, Sticker Pack, Posters, Mannequin, Cork Board, tables, chairs, Salt Lamp, Kallaks, Plates, Bowls, Wall Lights, Floor Lamp, Wastebasket, Alarm Clock, Neon Signs, Globe, Whiteboard, Cubicle, Soundproofing Foam |
| **Misc** | Cup, Coffee Bag, Sponge, Soap, Bucket, Nail, Axle Nail, Hazmat Suit, Garbage Bag, Garbage Bag Roll, Ultrabait Boxes, Mop, Mop Bucket, Broom, Farm Pot, Rechargeable Battery, Brick Stack, GPU Board, Ramp, BBQ Grill, Scuba Mask, Bike Helmet, Cig Pack, Fire Protection Suit, Plunger, Cigar, AGL Rocket, Omega AI Module, Ball Joint, Limb Joint, Glue Bottle, Trampoline, Cutting Board, Garden Hose, Sprinkler, Faucet, Compost Bucket, Krampus Hat, Clean Jar, Maid Outfit, Seed Packs, Cement, Headphones |
| **Upgrades** | Blueprints de EMF, Geiger, Beehive y metal detector; módulos físicos; mejoras de ATV |

### 7.2 Sistemas de ítems

| Sistema | Reglas | Prioridad |
|---|---|---|
| Inventario | Mochila y contenedores; volumen y peso; soltar, lanzar, arrastrar y apilar. | T1 |
| Agarrar | LMB para coger, RMB para usar/rotar, rueda para distancia; objetos físicos. | T1 |
| Contenedores | Cajas, armarios, nevera, caja de discos, caja de cintas, saco del dron. | T2 |
| Crafteo | Workbench, recetas, blueprints, componentes; Kerfur-Omega es el gran proyecto. | T2 |
| Cocina | Microondas, hornilla, nevera, comida cruda/cocida, quemada y podrida. | T2 |
| Agricultura | Semillas, macetas, cosecha; parte del sistema de comida. | T2 |
| Pesca | Caña, carnada, peces, basura y objetos únicos. | T2 |
| Excavación | Pala, detector de metales, objetos enterrados y fósiles. | T2 |
| Construcción | Paredes, clavos, martillo, pintura, muebles; el original permite construir bases. | T2 |
| Fotos | Cámara digital, cámara impresora, fax, galería y exportación. | T2 |
| TV/radio | Contenido personalizado en el original; se puede posponer. | T4 |

---

## 8. Vehículo y movilidad

| Elemento | Reglas | Prioridad |
|---|---|---|
| ATV | 100 de salud, dos faros, manillar, freno de mano, aceleración y turbo. | T2 |
| Velocidad | 20 m/s normal, 40 m/s con turbo; el original usa 20/40. | T2 |
| Controles | Use para montar, Escape para bajar, Space freno, Shift turbo, F luces, Ctrl dirección con ratón, Alt bocina. | T2 |
| Combustible | Gasolina; bidón de 100 unidades; se puede repostar. | T2 |
| Daño | Se repara con toolbox; puede explotar. | T2 |
| Upgrades | Luces grandes, parachoques, correa, panel solar, contenedor, flotadores, mapa, radio, control aéreo, motor sobrecargado, alternador. | T2 |
| Restricciones | No se puede pausar ni guardar montado. | T1 |

---

## 9. Mundo y localizaciones

| Elemento | Datos | Prioridad |
|---|---|---|
| Escenario | Bosque de Dunkeltaler, Alpes suizos; base central, lago, río, montañas, bosque y vallas. | T1 |
| Escala | El radar mejorado cubre 1400×1400 m; la zona jugable ronda 1,4 km de lado. Confirmar en el hito 7. | T1 |
| Infraestructura | 24 platos, 3 transformadores, 3 radares de coordenadas, 4 turbinas eólicas, 1 torre de comunicaciones, base principal. | T1 |
| Base | Estilo brutalista con radomo; exterior norte/este/sur/oeste; entrada, loading bay, pasillo, recepción/admin, garaje, break room, utility closet, Signal Processing & Research, Server Network Room, escalera, planta superior, dormitorio, baño, balcón, techo, conductos y sótano. | T1 |
| Sótano | Breaker, crematorio, taquillas, túneles y secretos. | T2 |
| Puntos de interés | Security Booth, Alpha Hideout, Wind Turbines, Lightning Rods, The Lake, Abandoned Shack, Trailer Park, The Hole, The Cave, The Well, Green Cabinet, Swing, Graves, Erie Zone, Rock Candles, Sewer Opening, Foxtrot Depths, Underwater Barrels, Underwater Car, Fence Tree, Restricted Areas, Green Hatch, Stonehenge, Abandoned Village, Beyond the Fence, “Them”, Out of Bounds, Lambert Ritual Zone, Gay Baby Jail, Firewatch Towers, Checkerboard Benches, Lone Tree, Blood Pit, Floating Cottage, Zulu, Parkour Area. | T2/T3 |
| Dimensiones | Well Pit, Goop Dimension, Poo Dimension, Hell, White Void, The Labyrinth, gm_construct, Checkerboard Pillar. | T4 |
| Sandbox | Mapas de pruebas y construcción; no forman parte del modo historia. | T4 |

La base debe ser recorrible sin cargas y con interiores iluminados por LightmapGI. El bosque se
resuelve con MultiMesh, LOD, occlusion culling y carga por distancia.

---

## 10. Entidades

### 10.1 Categorías

| Categoría | Entidades documentadas | Comportamiento general | Prioridad |
|---|---|---|---|
| **Extraterrestres** | Arirals, Rozitals, Grays, Geoms, The Evil, “The Tumor”, Balls UFO, Dart UFO, Joel's UFO, “Thunder Wisp”, Midas UFO, Pill UFO, TriFO, Sky Jellyfish | Facciones, naves, visitas, señales y eventos; algunas son pacíficas, otras hostiles. | T3 |
| **Demonios** | Abandoned Kerfur, Furfur, Krampus | Entidades demoníacas, rituales y eventos; Furfur tiene presencia recurrente. | T3 |
| **Anómalas** | Bad Sun, Basalt Pillar, “Ghost Log”, Gore Slither, Killer Birch, “Living Mannequin”, Mimic, Mushroom Duende, Nisse, Prying Eyes, The Puddle, “Red Void Orb”, Rorschach Test, Shadow Figura, Sheet Ghost, Skerfuro, Tanneul, Telephone Booth, “The Body”, Walking Tree, William the Protector, Wolfgang, Zombie, Zombie Deer | Manifestaciones extrañas, algunas con Paranoia; pueden observar, perseguir o matar. | T2/T3 |
| **Wisps** | Black, Blue, Cyan, Green, Orange, Pink, Purple, Red, White, Killer | Luces flotantes; algunas inofensivas, otras persiguen. La negra cierra el juego al tocarte. | T2 |
| **Alucinaciones** | Burger Roaches, Hallucination Food, The Insomniac | Aparecen con hambre o sueño bajos; el Insomniac fuerza sueños. | T2 |
| **Fauna** | Deer, Fish, Cockroaches, Cockroach Nests, Fireflies, Flies, Bees, Wasps | Fauna normal, pero puede volverse hostil o parte de eventos. | T2 |
| **Forbiddens** | The Looker, “Corpsewalker”/Dark Figura, Chime Guy, The Fridge, “Friends from the Past”, Teleporting Shadows, Black Sphere, The White Door, The Cognition, Window Bat, Red Skeleton, Censor Guy, The Walker, “The Exit Door”, Mountain People, Siren Pole, The Bone Man, “Shadow Spider”, “Poolwalker”, The Head, “False Kel”, The Eight Great Figures | No canónicas; aparecen en condiciones muy concretas, a menudo solo visibles en grabaciones. | T4 |
| **Chistes** | Rufus, Thiccfus, Live Erie Plush, Angry Erie, Spider Argemia, Shitting Duende | Contenido no canónico detrás de la regla Funny o comandos secretos. | T4 |

### 10.2 Radar y comportamiento

- El radar de la base detecta entidades en el bosque y guarda historial de columnas.
- Los módulos de radar añaden colores, alarma, radio, trayectorias y búsqueda radial.
- Las entidades pueden spawnear por evento, por señal, por hora, por nivel de stat o al azar.
- La línea de visión, el ruido, la luz y el estado de las puertas importan.
- Algunas entidades activan **Meta Paranoia**; otras solo observan.
- Las entidades deben ser data-driven (`EntityDef`) y reutilizar una IA base con estados.

---

## 11. Eventos

### 11.1 Story Mode (semanas 1–7)

| Semana | Eventos documentados |
|---|---|
| 1 | Meteor Shower, Power Outage, Vent Crawler, Ariral “Peace” Signal |
| 2 | Ariral Picnic, No More Birds, Wormhole Signal, Arirals “Talk” Signal, Arirals Eating Shrimp, Vent Knocker, Ariral “Cringe Comp” Signal, Email Spam & Ariral Visit, Pink Wisp Swarm |
| 3 | Sushi Gift Delivery, Flickering Lantern Prank, Ariral Treehouse, Anti-Gravity Prank, Croissant Delivery, Radio Tower Ariral Ship |
| 4 | Dropped Ariral Gun, Brownie Trail, Warning Obelisk, Ariral Satellite Signals, Black Hole Sun, Looker Signals |
| 5 | Piramid Signal, Piramid Arrival, Rozital Scouts, Garage Soltomia |
| 6 | Peeping UFO, Rozital Mothership, Hole Repair, Gray Drops Corpse, Gray Drops Corpse Near Window, Gray Drops Jeep |
| 7 | Grays at Transformer, Gray Firetank, Gray Invasion |

### 11.2 Otros grupos

| Grupo | Ejemplos | Prioridad |
|---|---|---|
| Reputación Ariral | Alien Cart, Alien Catapult, ATV Explodes, ATV Joyride, Base Graffiti, Bed Relocation, Blue Lights Prank, Bomb Present, Console Breach, Cookies, Drives Gift, Fake Drives, Food Gift, Medkit Gift, Poisoned Food, Reactor Restart, Sleep-Feeding, Tacks, Treehouse Kidnapping, Vaccine, Vent Assault | T3 |
| Aleatorios | “Ariral Troll Drive”, Bad Sun, Black Fog, Cursed Church, The Dialogue, Earth-Shaking Roar, Empty Base, “Eye Moon”, Fossilhound vs Boar War, Gears, Geom Ovoid, Goat Skull Locker, Gore Locker, Gray Cloaking Panel, Kerfur-Omega Scary Face, Lake Event, Light Switches Off, Mannequins at Uniform, Meat Locker Thief/Thumper, Meat Rain, Possessed Kerfur, “Press Shift to Run”, Red Phone, Red Sky, Rubber Duck, “Salt Heart”, Satellites Move On Their Own, Shooting Star, Skerfuro, Sky UFO, Sky Jellyfish, Stolen Radio Tower, Super Fog, “Toyota Corolla”, Tree Debris | T2/T3 |
| Sueños | Base, Boulder, Burger, Climbing, Flooding, Furfur, Hallway, Mannequin, Parkour, Shed, Work | T3 |
| Activados por jugador | Howling Grass, Howling Hoofprints, Invalid Email, Meat Locker Knocker, Mystery Footprints, Restocker, Skeleton in Chair, Gay Baby Jail, “I Know What You Are” | T3 |
| Tiempo real | Bad Sun, Teleporting Shadows, Screaming Corpses, April Fools, Halloween, Christmas, Easter | T3/T4 |
| Tiempo de juego | Satellite Graffiti, Green Fire, Teleporter Logs, 3AM Events, Abandoned Shack Portal, Bunker Elevator Camera, Furfur Toilet Jumpscare, Porta Potty Poop Dimension, Meat Locker Glows Red, The White Door Opens, Foxtrot Depths, Romeo Cries, Bridge Sob, Blinking Lights, Grave Zombies, Server Critical Error, Hallway White Door | T3/T4 |
| Finales | The Evil (procesar `evil` a nivel 3 y no borrarlo en 12 min), Bad Sun (morir por luz solar durante el evento) | T3 |

### 11.3 Reglas de eventos

- Un evento puede pausar el sim, bloquear guardado/pausa/sueño y escribir flags persistentes.
- El director de eventos debe ser data-driven: `EventDef` con condiciones, peso, cooldown, duración y
  acciones. Los eventos de historia usan día/hora fijos; los aleatorios usan pesos.
- Los eventos deben poder quitarse o reemplazarse sin romper el resto.

---

## 12. Personajes y facciones

| Grupo | Personajes |
|---|---|
| **ASO** | Dr. Kel (operador actual), Dr. Dee (anterior/MIA), Dr. Bao (astrónomo jefe), Prof. Lea (supervisora), Dr. Ena, Dr. Max, Dr. Ken, Dr. Ula, Dr. Ler, Dr. Noa, G. Soloman (fundador) |
| **Robots ASO** | Kerfur (reparación autónoma), Kerfur-Omega (autómata de propósito general) |
| **Demonios** | Furfur, Stolas |
| **Arirals** | Argemia Armuntela (líder), Shorts Dictator, Esraniki, civiles altos |
| **Rozitals** | Diefthyntis (líder supremo), Igetis (segundo) |
| **Grays** | Líder supremo (muerto), soldados e invasores |

La narrativa del original es críptica y se cuenta por emails, señales, notas, carteles y eventos. La
réplica debe mantener ese tono: información incompleta, humor seco y horror cotidiano. Los textos serán
originales.

---

## 13. Modos de juego, ajustes y progresión

### 13.1 Modos

| Modo | Reglas | Prioridad |
|---|---|---|
| Tutorial | Nivel aparte que enseña controles e interacción; desbloquea Story, Infinite y Ambience. | T2 |
| Story | Modo por defecto; eventos guionizados por día; tras el final implementado se comporta como Infinite. | T1 |
| Infinite | Sin eventos de historia; resto de contenido. | T2 |
| Ambience | Sin tareas ni amenazas; solo clima, paisaje y ambiente. | T4 |
| Sandbox | Spawn menu, vuelo, construcción y mapas de prueba; se desbloquea al día 31. | T4 |
| Solar | Variante especial; se desbloquea con progreso. | T4 |

### 13.2 Reglas de partida (save slot)

- Dificultad, daño físico, multa por tarea.
- Estaciones, clima permanente, velocidad del día.
- Putrefacción, fatiga de comida, eventos físicos, escenario secreto.
- Decaimiento de torre/radares/transformadores, minijuegos, eventos estacionales, sangrado,
  pesadillas, “Cold Swap”.
- Minijuegos de servidor activos (Math, Wires, Hack, Slider, Maze, Pipe, Simon, BitFit).
- Contenido personalizado, combate extremo, regla Funny, experimental, “Touch Grass”.

### 13.3 Logros y avance

- **Achievements** son globales de la cuenta; **Advancements** son por partida.
- El tutorial desbloquea modos; el día 31 desbloquea Sandbox; el día 48 desbloquea contenido de
  Alpha y el final del arco actual.
- Los logros dan puntos y desbloquean objetos (Kerfur-Omega, maid outfit, plushies, etc.).
- La réplica debe tener una lista propia de logros, no copiar los del original.

---

## 14. Secretos y contenido meta

| Grupo | Ejemplos | Prioridad |
|---|---|---|
| Ítems ocultos | herramientas, plushies de Argemia, coleccionables | T4 |
| Activados por jugador | comandos de consola, rituales, combinaciones | T4 |
| Secretos del mapa | Meat Locker, catacumbas, wine cellar, “Evil Corner”, conductos, túnel subterráneo, Maxwell, Stone Maxwell, Green Hatch, The Protector | T4 |
| Regla Funny | contenido no canónico, Maxwell/Argemwell, entidades chiste, comandos | T4 |
| Dimensiones | Well Pit, Goop, Poo, Hell, White Void, Labyrinth, gm_construct | T4 |

Los secretos deben ser **opcionales**, no bloquear el bucle principal y estar aislados para que se
puedan desactivar con una regla de partida.

---

## 15. Controles, UI y sensación

| Elemento | Reglas | Prioridad |
|---|---|---|
| Primera persona | Cámara física, cabeza con balanceo sutil, manos/inventario diegético. | T1 |
| Movimiento | Andar 4 m/s, correr 8 m/s, agachado 1,5 m/s; stamina limita correr. | T1 |
| Interacción | Raycast, prompt contextual, E/clic, mantener para acciones largas, rueda para perillas. | T1 |
| Agarrar | Objetos físicos, lanzar, colocar, apilar, abrir contenedores. | T2 |
| Inventario | Rejilla/volumen, equipo, bolsillos, mochila, contenedores. | T1 |
| Terminales | SubViewport con UI propia, teclado físico y botones; el mundo sigue simulando. | T1 |
| HUD | Mínimo: stats, reloj, misión, mensajes; nada de minimapa permanente salvo el digital map. | T1 |
| Audio | Ambiente por capas, viento, pájaros, crujidos, zumbidos, pasos; sin música épica. | T1 |
| Terror | Oscuridad real, linterna con batería, silencios largos, ruidos lejanos, eventos sutiles. | T1 |
| Accesibilidad | Subtítulos, sensibilidad, FOV, volumen, opción de reducir sustos; se define en el hito 15. | T3 |

---

## 16. Guardado y sesión

| Elemento | Reglas | Prioridad |
|---|---|---|
| Guardado | Manual desde la cama/PC; no se puede guardar durante eventos, montado en ATV o en algunas acciones. | T1 |
| Datos | Día, hora, stats, inventario, estado de base, energía, servidores, señales, tareas, flags de eventos, decisiones, semilla del RNG. | T1 |
| Versión | Esquema versionado y migraciones; nunca guardar el árbol de escena. | T1 |
| Reanudación | Al cargar, reconstruir entidades y máquinas desde datos, no desde el estado de los nodos. | T1 |

---

## 17. Rendimiento y referencia técnica

| Objetivo | Valor |
|---|---|
| FPS objetivo | 60 en hardware modesto (GTX 1050 / similar) |
| Draw calls | < 250 visibles |
| Props pequeños | < 2k tris |
| Props medianos | < 8k tris |
| Máquinas | < 15k tris |
| Vegetación | MultiMesh + LOD + occlusion culling |
| Interiores | LightmapGI; pocas luces dinámicas con sombra |
| Física | Cuerpos dormidos, colisiones simples, límite de objetos activos |
| Carga | Por distancia, sin pantallas de carga |

El original tiene fama de rendir mal; la réplica debe superarlo. La medición se hace con el overlay
F3 y una escena de debug con FPS, draw calls, primitivas, memoria y nodos.

---

## 18. Matriz de implementación

| Hito | Sistemas del catálogo que cubre |
|---|---|
| 0 | Este documento, diseño, arquitectura, tareas, ideas, assets. |
| 1 | Proyecto base, jugador 4/8/1,5 m/s, stamina, linterna, debug. |
| 2 | Framework Interactable/Grabbable/Machine/Panel/Item/Entity/Event, inventario. |
| 3 | Alpha Root Base en placeholders, estación de señales, 30 servidores, sótano, garaje, cocina. |
| 4 | Transformadores, breaker, apagones, consumo, control remoto. |
| 5 | Estación de señales completa, discos, caja, base de datos, cadena de señal. |
| 6 | Ciclo diario, email, dron, cintas, puntos, tienda, mejoras. |
| 7 | Mapa exterior a escala, 24 platos, 3 transformadores, 3 radares, torre, POIs. |
| 8 | Servidores, consola, hashcodes, reparación, calibración. |
| 9 | Hambre, stamina, salud, sueño, paranoia, dificultad y ajustes. |
| 10 | Entidades básicas, radar, noche, IA y eventos. |
| 11 | Tier 2: ítems, cocina, crafting, construcción, cámaras, fotos, pesca, excavación, ATV, módulos. |
| 12 | Modelos definitivos y sustitución de placeholders. |
| 13 | Tier 3: eventos de historia, facciones, sueños, logros. |
| 14 | Tier 4: secretos, Forbiddens, chistes, dimensiones. |
| 15 | Guardado, menús, accesibilidad, pulido y segunda pasada de rendimiento. |

---

## 19. Decisiones de fidelidad

1. **Sistemas y cifras primero, con variaciones.** Se toman reglas, ritmo, escala y dificultad como
   inspiración muy cercana; no se copian textos, modelos, sonidos ni interfaces pixel a pixel. El juego
   debe parecerse mucho, no ser el mismo juego.
2. **Nombres centralizados.** Los nombres del original se usan como referencia, pero viven en `data/`
   y se pueden cambiar sin tocar código.
3. **Contenido original.** Señales, lore, personajes, eventos y textos se escribirán desde cero.
4. **Normal como referencia.** El balance base usa Normal (75 min/día, 3 hashcodes, 2–3 señales).
5. **Mapa ~1,4 km.** Se confirma y ajusta en el hito 7; la base debe sentirse lejos de los platos.
6. **Sin pantallas de carga.** Viaje a pie o ATV; el dron y los eventos no bloquean el mundo.
7. **Rendimiento desde el día 1.** Cada hito se mide; no se acumula deuda técnica.
8. **Reutilizar lo que cumple.** Un prototipo que ya funciona se conserva y se ajusta; no se rehace solo
   por imitar el original. La linterna actual es el primer caso.

---

## 20. Fuentes consultadas

- <https://voicesofthevoid.wiki.gg/wiki/Signals>
- <https://voicesofthevoid.wiki.gg/wiki/Guides/Gameplay>
- <https://voicesofthevoid.wiki.gg/wiki/Guides/Main_Computer>
- <https://voicesofthevoid.wiki.gg/wiki/Guides/Computer_Table>
- <https://voicesofthevoid.wiki.gg/wiki/Physical_Modules>
- <https://voicesofthevoid.wiki.gg/wiki/Breakers>
- <https://voicesofthevoid.wiki.gg/wiki/Transformer>
- <https://voicesofthevoid.wiki.gg/wiki/Servers>
- <https://voicesofthevoid.wiki.gg/wiki/Satellite_Dish>
- <https://voicesofthevoid.wiki.gg/wiki/Coordinate_Radar>
- <https://voicesofthevoid.wiki.gg/wiki/Console>
- <https://voicesofthevoid.wiki.gg/wiki/Items>
- <https://voicesofthevoid.wiki.gg/wiki/Entities>
- <https://voicesofthevoid.wiki.gg/wiki/Events>
- <https://voicesofthevoid.wiki.gg/wiki/Locations>
- <https://voicesofthevoid.wiki.gg/wiki/Characters>
- <https://voicesofthevoid.wiki.gg/wiki/Secrets>
- <https://voicesofthevoid.wiki.gg/wiki/Gamemodes>
- <https://voicesofthevoid.wiki.gg/wiki/Guides/Settings>
- <https://voicesofthevoid.wiki.gg/wiki/Guides/Achievements>

## 21. Pendiente de verificar

- Tamaño exacto y topografía de la versión 0.9.0 del mapa.
- Lista completa y precios de todos los ítems (las tablas de la wiki siguen en WIP).
- Condiciones exactas de spawn de varias entidades y eventos.
- Fórmulas internas de estabilidad de transformadores y consumo por componente.
- Lista completa de señales con audio, texto y condiciones.
- Contenido de las semanas 8+ de Story Mode, aún no implementado en el original.

Se actualizará este documento cuando el hito correspondiente necesite el dato exacto.
