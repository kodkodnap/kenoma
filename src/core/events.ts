// Eventos de la noche. Son funciones que piden cosas al anfitrión (mundo, audio,
// UI) a través de EventHost: así la lógica se testea sin Three.js.

import type { MachineId } from './faults';
import { healthyMachines, machineDef } from './faults';
import { Rng } from './rng';
import { knowsRoutine, routineSpot } from './routine';
import { GameState, LogKind } from './state';
import { dangerCurve } from './time';
import type { WeatherKind } from './weather';

export type EntityKind = 'figura' | 'doble' | 'perro' | 'coro' | 'imitador' | 'comerciante' | 'aprendiz';
export type SpawnPoint = 'treeline' | 'fence' | 'window' | 'door' | 'inside';

export interface EventHost {
  toast(text: string, kind?: 'info' | 'warn' | 'bad' | 'good'): void;
  log(text: string, kind?: LogKind): void;
  stress(delta: number): void;
  powerOut(seconds: number): void;
  sound(id: string): void;
  spawnEntity(kind: EntityKind, at: SpawnPoint): void;
  /** Coloca una entidad en una coordenada exacta (rutina del jugador, origen fijo). */
  spawnEntityAt(kind: EntityKind, x: number, z: number): void;
  /** Deja una captura sin pasar por el plato (micrófono, grabadora, llamada). */
  grantCapture(kind: 'VOZ' | 'ANOMALO' | 'VACIO' | 'BALIZA', origin: 'microfono' | 'evento'): void;
  fragment(n: number): void;
  flash(intensity?: number): void;
  shake(amount: number): void;
  moveDish(): void;
  radio(text: string): void;
  save(): void;
  /** Fuerza el clima. La tormenta puede además tirar la corriente. */
  weather(kind: WeatherKind, intensity?: number, minutes?: number): void;
  /** Deja una máquina fuera de servicio. Con `sabotage`, el panel aparece abierto. */
  breakMachine(id: MachineId, sabotage: boolean): void;
  /** Activa o retira el puesto de trueque del comerciante. */
  trader(active: boolean): void;
}

export interface EventDef {
  id: string;
  title: string;
  minDay: number;
  weight: (state: GameState) => number;
  /** Solo puede ocurrir una vez por partida. */
  once?: boolean;
  run: (host: EventHost, state: GameState, rng: Rng) => void;
}

export const EVENTS: EventDef[] = [
  {
    id: 'apagon',
    title: 'Apagón',
    minDay: 1,
    weight: (s) => (s.stress > 55 ? 18 : 10) * (s.weather.kind === 'tormenta' ? 1.6 : 1),
    run: (host, state, rng) => {
      host.flash(0.4);
      host.sound('breaker');
      host.powerOut(Math.round(rng.range(22, 40) - (state.upgrades['generador'] ?? 0) * 5));
      host.stress(5);
      host.log('El grupo electrógeno se ha parado. Reinicia el cuadro en la caseta.', 'warn');
      host.toast('APAGÓN · busca el cuadro del generador', 'bad');
      state.flags['apagon_pendiente'] = true;
      if (rng.chance(0.45)) host.spawnEntity('figura', 'treeline');
      host.save();
    },
  },
  {
    id: 'figura_linde',
    title: 'La figura del linde',
    minDay: 1,
    weight: () => 15,
    run: (host, state) => {
      host.sound('breath');
      host.spawnEntity('figura', 'treeline');
      host.stress(7);
      host.log('Hay una silueta entre los abetos. No se mueve. Tiene tu altura.', 'bad');
      host.toast('Algo te observa desde el linde', 'warn');
      state.flags['contactos'] = Number(state.flags['contactos'] ?? 0) + 1;
    },
  },
  {
    id: 'golpes',
    title: 'Tres golpes',
    minDay: 2,
    weight: () => 10,
    run: (host, state) => {
      host.sound('knock');
      host.stress(6);
      host.log('Tres golpes en la puerta principal. No hay nadie en el porche.', 'warn');
      host.toast('Llaman a la puerta', 'warn');
      state.flags['golpes'] = Number(state.flags['golpes'] ?? 0) + 1;
      if (Number(state.flags['golpes'] ?? 0) >= 3) {
        host.log('Tercera llamada. La nota del manual decía que a la tercera no se abre.', 'bad');
        host.spawnEntity('doble', 'window');
      }
    },
  },
  {
    id: 'antena_movida',
    title: 'La antena se mueve sola',
    minDay: 2,
    weight: () => 9,
    run: (host, state) => {
      host.sound('motor');
      host.moveDish();
      host.stress(4);
      host.log('Los motores del plato han arrancado. No hay orden en la consola.', 'warn');
      host.toast('El plato se está moviendo', 'warn');
      state.flags['antena_libre'] = true;
    },
  },
  {
    id: 'cancion_servidor',
    title: 'La canción del servidor',
    minDay: 2,
    weight: () => 8,
    run: (host, state) => {
      host.sound('melody');
      host.grantCapture('BALIZA', 'microfono');
      host.log('El rack de servidores emite una secuencia tonal. La grabadora la ha captado.', 'warn');
      host.toast('Captura de micrófono añadida al archivador', 'info');
      state.flags['cancion'] = true;
    },
  },
  {
    id: 'doble',
    title: 'Tu silueta',
    minDay: 3,
    weight: () => 7,
    once: true,
    run: (host, state) => {
      host.spawnEntity('doble', 'window');
      host.stress(11);
      host.sound('breath');
      host.log('En el reflejo del ventanal hay alguien de espaldas. Lleva tu chaqueta.', 'bad');
      host.toast('No estás solo en el edificio', 'bad');
      state.flags['doble_visto'] = true;
    },
  },
  {
    id: 'perro',
    title: 'Algo herido en la valla',
    minDay: 2,
    weight: () => 6,
    once: true,
    run: (host, state) => {
      host.spawnEntity('perro', 'fence');
      host.stress(3);
      host.log('Algo respira junto a la valla. Suena a un animal grande, pero no lo es.', 'warn');
      host.toast('Algo herido junto a la valla', 'warn');
      state.flags['perro'] = true;
    },
  },
  {
    id: 'radio_hq',
    title: 'Control',
    minDay: 1,
    weight: () => 9,
    run: (host, state) => {
      const left = Math.max(0, state.quota.target - state.quota.earned);
      if (left > 0) host.radio(`Kestrel, aquí Control. Os faltan ${left} créditos para la cuota. No hay prórroga.`);
      else host.radio('Kestrel, cuota cubierta. Podéis cerrar el turno cuando queráis.');
      host.log('Llamada de Control recibida.', 'info');
      if (state.stress > 70) {
        host.radio('Kestrel, vuestra voz suena alterada. ¿Ocurre algo ahí dentro?');
        host.stress(-4);
      }
      const relaciones = state.decisions.includes('archivo_operador:entregar');
      if (relaciones && state.day >= 8) {
        host.radio('Kestrel, sobre la carpeta que entregó: el operador anterior no tiene expediente. Ni alta ni baja.');
      }
    },
  },
  {
    id: 'voz_altavoz',
    title: 'El altavoz',
    minDay: 3,
    weight: () => 7,
    run: (host, state) => {
      const last = state.log[0]?.text ?? 'No hay nadie en la estación.';
      host.sound('voice');
      host.log(`El altavoz del pasillo repite tu última frase: "${last}"`, 'bad');
      host.stress(12);
      host.flash(0.25);
      host.toast('Algo ha hablado con tu voz', 'bad');
      state.flags['voz_altavoz'] = true;
    },
  },
  {
    id: 'huellas',
    title: 'Huellas',
    minDay: 2,
    weight: (s) => (s.weather.kind === 'ventisca' ? 0 : 8),
    run: (host, state) => {
      host.stress(4);
      host.log('Hay un anillo de huellas alrededor del edificio. Empiezan y acaban en la nada.', 'warn');
      host.toast('Huellas alrededor del edificio', 'warn');
      state.flags['huellas'] = true;
      host.sound('snowstep');
    },
  },
  {
    id: 'respuesta',
    title: 'Respuesta',
    minDay: 1,
    weight: (s) => (Number(s.stats.answered) > 0 ? 20 : 0),
    run: (host, state) => {
      host.sound('voice');
      host.spawnEntity('figura', 'fence');
      host.fragment(1);
      host.stress(14);
      host.log('Algo ha respondido a tu transmisión. Usa la misma cadencia que tú.', 'bad');
      host.toast('Te han respondido', 'bad');
      state.flags['respuesta'] = Number(state.flags['respuesta'] ?? 0) + 1;
    },
  },
  {
    id: 'silencio',
    title: 'Silencio',
    minDay: 4,
    weight: () => 6,
    run: (host, state) => {
      host.sound('silence');
      host.stress(9);
      host.log('El viento se ha detenido. El generador también. Solo se oye tu respiración.', 'bad');
      host.toast('Silencio absoluto', 'bad');
      host.spawnEntity('coro', 'treeline');
      state.flags['silencio'] = true;
    },
  },

  // ---------- fase 2: clima, averías y arquetipos nuevos ----------

  {
    id: 'tormenta',
    title: 'La tormenta',
    minDay: 3,
    weight: (s) => (s.weather.kind === 'tormenta' ? 4 : 9),
    run: (host, state, rng) => {
      host.weather('tormenta', rng.range(0.6, 1), 180);
      host.sound('thunder');
      host.flash(0.5);
      host.stress(5);
      host.log('La tormenta entra por el valle: descargas sobre la cordillera y estática en toda la banda.', 'warn');
      host.toast('TORMENTA · ruido de banda ancha', 'warn');
      state.flags['tormenta'] = Number(state.flags['tormenta'] ?? 0) + 1;
    },
  },
  {
    id: 'ventisca',
    title: 'Ventisca',
    minDay: 5,
    weight: (s) => (s.weather.kind === 'ventisca' ? 3 : 8),
    run: (host, state, rng) => {
      host.weather('ventisca', rng.range(0.7, 1), 200);
      host.sound('wind');
      host.stress(7);
      delete state.flags['huellas'];
      host.log('El viento borra el rastro del recinto. Las huellas de esta noche han desaparecido.', 'warn');
      host.toast('VENTISCA · visibilidad mínima', 'warn');
      state.flags['ventisca'] = Number(state.flags['ventisca'] ?? 0) + 1;
    },
  },
  {
    id: 'niebla',
    title: 'Niebla',
    minDay: 4,
    weight: (s) => (s.weather.kind === 'niebla' ? 4 : 7),
    run: (host, state, rng) => {
      host.weather('niebla', rng.range(0.5, 0.95), 170);
      host.stress(6);
      host.log('El valle se cierra en niebla. El linde desaparece a diez metros de la valla.', 'warn');
      host.toast('NIEBLA · el linde queda a oscuras', 'warn');
      state.flags['niebla'] = Number(state.flags['niebla'] ?? 0) + 1;
    },
  },
  {
    id: 'sabotaje',
    title: 'Sabotaje',
    minDay: 5,
    weight: (s) => (s.stress > 45 ? 12 : 7),
    run: (host, state, rng) => {
      const healthy = healthyMachines(state);
      if (healthy.length === 0) {
        host.toast('No queda nada entero que romper.', 'warn');
        return;
      }
      const victim: MachineId = rng.pick(healthy);
      host.breakMachine(victim, true);
      host.sound('fault');
      host.stress(10);
      host.log(`El panel de ${machineDef(victim).label} está abierto y el tornillo de calibración no está.`, 'bad');
      host.toast(`SABOTAJE · ${machineDef(victim).short}`, 'bad');
      if (rng.chance(0.4)) host.spawnEntity('figura', 'inside');
      state.flags['sabotaje'] = Number(state.flags['sabotaje'] ?? 0) + 1;
    },
  },
  {
    id: 'imitador',
    title: 'Alguien copia tus pasos',
    minDay: 6,
    weight: (s) => (knowsRoutine(s, s.clock) ? 12 : 7),
    run: (host, state) => {
      host.sound('snowstep');
      host.spawnEntity('imitador', 'treeline');
      host.stress(9);
      host.log('Fuera, alguien camina con tu misma cadencia, cuatro pasos por detrás de donde tú estabas.', 'bad');
      host.toast('Hay pasos con tu cadencia', 'warn');
      state.flags['imitador'] = Number(state.flags['imitador'] ?? 0) + 1;
    },
  },
  {
    id: 'comerciante',
    title: 'El que comercia',
    minDay: 7,
    weight: (s) => (s.day >= 7 ? 9 : 0),
    run: (host, state) => {
      host.spawnEntity('comerciante', 'fence');
      host.trader(true);
      host.stress(5);
      host.sound('trade');
      host.log('Alguien ha dejado un cajón en el porche con una lista dentro: pide una captura y deja algo a cambio.', 'warn');
      host.toast('Puesto de trueque abierto en el porche', 'bad');
      state.flags['comerciante'] = Number(state.flags['comerciante'] ?? 0) + 1;
    },
  },
  {
    id: 'aprendiz',
    title: 'El que aprende tu rutina',
    minDay: 9,
    weight: () => 8,
    once: true,
    run: (host, state) => {
      const spot = routineSpot(state, state.clock);
      host.sound('breath');
      if (spot) host.spawnEntityAt('aprendiz', spot.x, spot.z);
      else host.spawnEntity('aprendiz', 'inside');
      host.stress(13);
      host.log('El registro tiene una entrada nueva escrita con tu letra: "he subido a la antena a las 02:14 y he vuelto a bajar".', 'bad');
      host.log('Tú no has subido a la antena esta noche.', 'bad');
      host.toast('Alguien conoce tu rutina', 'bad');
      state.flags['aprendiz'] = true;
    },
  },
  {
    id: 'repetidor_llama',
    title: 'El repetidor llama',
    minDay: 8,
    weight: (s) => (s.day >= 8 && s.flags['repetidor_abierto'] ? 14 : 0),
    run: (host, state) => {
      host.radio('REPETIDOR 900 m: portadora estable, sin operador. La puerta estaba abierta al llegar.');
      host.sound('morse');
      host.stress(8);
      host.log('El repetidor repite tu propio parte de turno, con doce horas de antelación.', 'bad');
      host.toast('El repetidor repite tu parte', 'warn');
      state.flags['repetidor'] = Number(state.flags['repetidor'] ?? 0) + 1;
    },
  },
  {
    id: 'registro_futuro',
    title: 'El registro va por delante',
    minDay: 10,
    weight: () => 7,
    run: (host, state) => {
      host.stress(8);
      host.log('En el registro hay una entrada con la hora de mañana: "cuota cubierta, sin incidencias".', 'bad');
      host.toast('El registro ya sabe cómo acaba el turno', 'warn');
      state.flags['registro_futuro'] = Number(state.flags['registro_futuro'] ?? 0) + 1;
    },
  },
  {
    id: 'operador_anterior',
    title: 'La voz del operador anterior',
    minDay: 7,
    weight: (s) => (s.flags['acto2_archivo'] ? 10 : 4),
    once: true,
    run: (host, state) => {
      host.sound('voice');
      host.grantCapture('VOZ', 'evento');
      host.fragment(1);
      host.stress(12);
      host.log('Una grabación sin fecha explica el protocolo de la tercera llamada. La voz conoce tu nombre de pila.', 'bad');
      host.toast('Grabación del operador anterior', 'warn');
      state.flags['operador_anterior'] = true;
    },
  },
];

export function eventById(id: string): EventDef | undefined {
  return EVENTS.find((e) => e.id === id);
}

export function availableEvents(state: GameState): EventDef[] {
  return EVENTS.filter((e) => {
    if (state.day < e.minDay) return false;
    if (e.once && state.flags[`ev_${e.id}`]) return false;
    return e.weight(state) > 0;
  });
}

/** Elige un evento; marca los "una vez" y sube el contador de eventos. */
export function pickEvent(state: GameState, rng: Rng): EventDef | null {
  const pool = availableEvents(state);
  const chosen = rng.weighted(pool.map((e) => ({ item: e, weight: e.weight(state) })));
  return chosen;
}

export function runEvent(event: EventDef, host: EventHost, state: GameState, rng: Rng): void {
  state.stats.events += 1;
  if (event.once) state.flags[`ev_${event.id}`] = true;
  event.run(host, state, rng);
}

/** Siguiente hueco de evento, en minutos de juego. Más eventos según avanza la noche. */
export function nextEventGap(clock: number, rng: Rng): number {
  const danger = dangerCurve(clock);
  const base = rng.range(38, 62);
  return Math.max(16, base / danger);
}
