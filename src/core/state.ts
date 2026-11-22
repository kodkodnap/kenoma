// Estado del juego + guardado. Sin dependencias del render: se puede testear
// y serializar tal cual.

import { Rng } from './rng';
import type { RoutineSpot } from './routine';
import { Capture } from './signals';
import type { WeatherState } from './weather';

export const SAVE_KEY = 'estatica.save.v1';
export const SAVE_VERSION = 1;

export type LogKind = 'info' | 'warn' | 'bad' | 'good' | 'voice';

export interface LogEntry {
  time: string;
  day: number;
  text: string;
  kind: LogKind;
}

export type TaskKind =
  | 'decode'
  | 'sell'
  | 'scan'
  | 'voz'
  | 'anomalo'
  | 'no_blackout'
  | 'triangular'
  | 'no_averia';

export interface Task {
  id: string;
  text: string;
  kind: TaskKind;
  target: number;
  progress: number;
  reward: number;
  done: boolean;
  /** Valor del contador global al empezar el día. */
  base: number;
}

export interface Quota {
  target: number;
  earned: number;
  failedDays: number;
}

export type Quality = 'alta' | 'media' | 'baja';

/** Estado de una máquina de la cadena. Si `broken`, no se puede usar. */
export interface FaultState {
  broken: boolean;
  /** 0..1: cuánto cuesta calibrarla. Sube con cada intento fallido. */
  severity: number;
  attempt: number;
  /** Minutos de juego en los que falló. */
  since: number;
}

export interface GameState {
  version: number;
  seed: number;
  rngState: number;
  day: number;
  /** Minutos desde el inicio del turno (19:00). */
  clock: number;
  points: number;
  stress: number;
  power: boolean;
  /** Segundos de apagón restantes. */
  powerOutTimer: number;
  captures: Capture[];
  fragments: number;
  glyphTable: boolean;
  upgrades: Record<string, number>;
  quota: Quota;
  tasks: Task[];
  log: LogEntry[];
  flags: Record<string, number | boolean | string>;
  ending: string | null;
  stats: {
    decoded: number;
    sold: number;
    events: number;
    scans: number;
    contacts: number;
    answered: number;
    blackouts: number;
    walked: number;
    voz: number;
    anomalo: number;
    /** Averías sufridas por sabotaje. */
    sabotages: number;
    /** Máquinas devueltas a servicio (calibradas o reparadas). */
    repairs: number;
    /** Objetos aceptados en un trueque. */
    barters: number;
    /** Emisores localizados por triangulación. */
    triangulations: number;
    /** Veces que has salido en motonieve al repetidor. */
    trips: number;
  };
  position: [number, number, number] | null;
  quality: Quality;
  totalSeconds: number;
  /** Se incrementa al empezar un turno nuevo: la UI y el mundo lo usan. */
  shiftId: number;
  /** Clima del valle (fase 2). */
  weather: WeatherState;
  /** Máquinas averiadas o saboteadas, por id de máquina. */
  faults: Record<string, FaultState>;
  /** Piezas de repuesto en el almacén. */
  parts: number;
  /** Decisiones persistentes del acto II, en orden. */
  decisions: string[];
  /** Rutina del operador por tramo de la noche (4 tramos). */
  routine: (RoutineSpot | null)[];
}

export function quotaForDay(day: number): number {
  return 80 + day * 45;
}

const TASK_POOL: { kind: TaskKind; text: string; target: number; reward: number }[] = [
  { kind: 'voz', text: 'Decodifica una señal de voz completa', target: 1, reward: 70 },
  { kind: 'anomalo', text: 'Decodifica una señal anómala', target: 1, reward: 110 },
  { kind: 'decode', text: 'Completa la cadena de decodificación 3 veces', target: 3, reward: 60 },
  { kind: 'scan', text: 'Escanea 4 veces el perímetro con el escáner de campo', target: 4, reward: 55 },
  { kind: 'sell', text: 'Vende 2 capturas decodificadas', target: 2, reward: 60 },
  { kind: 'no_blackout', text: 'Termina el turno sin apagones', target: 0, reward: 90 },
  { kind: 'triangular', text: 'Triangula un emisor desde el repetidor', target: 1, reward: 130 },
  { kind: 'no_averia', text: 'Termina el turno sin averías en la cadena', target: 0, reward: 80 },
];

export function createTasks(day: number, rng: Rng, stats: GameState['stats']): Task[] {
  const pool = rng.shuffle([...TASK_POOL]);
  const tasks: Task[] = [];
  for (const def of pool.slice(0, 2)) {
    tasks.push({
      id: `t${day}-${def.kind}`,
      text: def.text,
      kind: def.kind,
      target: def.target,
      progress: 0,
      reward: def.reward,
      done: false,
      base: counterFor(def.kind, stats),
    });
  }
  return tasks;
}

export function counterFor(kind: TaskKind, stats: GameState['stats']): number {
  switch (kind) {
    case 'decode':
      return stats.decoded;
    case 'sell':
      return stats.sold;
    case 'scan':
      return stats.scans;
    case 'voz':
      return stats.voz;
    case 'anomalo':
      return stats.anomalo;
    case 'no_blackout':
      return stats.blackouts;
    case 'triangular':
      return stats.triangulations;
    case 'no_averia':
      return stats.sabotages + stats.repairs;
  }
}

export function createNewState(seed = Math.floor(Math.random() * 1e9)): GameState {
  const stats: GameState['stats'] = {
    decoded: 0,
    sold: 0,
    events: 0,
    scans: 0,
    contacts: 0,
    answered: 0,
    blackouts: 0,
    walked: 0,
    voz: 0,
    anomalo: 0,
    sabotages: 0,
    repairs: 0,
    barters: 0,
    triangulations: 0,
    trips: 0,
  };
  return {
    version: SAVE_VERSION,
    seed,
    rngState: seed,
    day: 1,
    clock: 0,
    points: 0,
    stress: 14,
    power: true,
    powerOutTimer: 0,
    captures: [],
    fragments: 0,
    glyphTable: false,
    upgrades: {},
    quota: { target: quotaForDay(1), earned: 0, failedDays: 0 },
    tasks: createTasks(1, new Rng(seed + 1), stats),
    log: [],
    flags: {},
    ending: null,
    stats,
    position: null,
    quality: 'alta',
    totalSeconds: 0,
    shiftId: 1,
    weather: { kind: 'clara', intensity: 0.3, timer: 240 },
    faults: {},
    parts: 0,
    decisions: [],
    routine: new Array<RoutineSpot | null>(4).fill(null),
  };
}

export function log(state: GameState, text: string, kind: LogKind, time: string): void {
  state.log.unshift({ time, day: state.day, text, kind });
  if (state.log.length > 80) state.log.length = 80;
}

export function addStress(state: GameState, delta: number): void {
  state.stress = Math.max(0, Math.min(100, state.stress + delta));
}

export function addPoints(state: GameState, delta: number): void {
  state.points = Math.max(0, state.points + delta);
}

export function markTaskProgress(state: GameState, kind: TaskKind, amount = 1): void {
  if (kind === 'no_blackout' || kind === 'no_averia') return;
  for (const t of state.tasks) {
    if (t.kind !== kind || t.done) continue;
    t.progress += amount;
    if (t.progress >= t.target) {
      t.done = true;
      addPoints(state, t.reward);
    }
  }
}

export function resetTaskProgress(state: GameState): void {
  for (const t of state.tasks) {
    t.base = counterFor(t.kind, state.stats);
    t.progress = 0;
  }
}

export interface StorageLike {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export function serialize(state: GameState): string {
  return JSON.stringify(state);
}

/** Acepta JSON viejo o corrupto sin reventar la partida. */
export function deserialize(raw: string | null): GameState | null {
  if (!raw) return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (!parsed || typeof parsed !== 'object') return null;
  const data = parsed as Partial<GameState>;
  if (typeof data.day !== 'number' || !Array.isArray(data.captures)) return null;

  const fallback = createNewState(typeof data.seed === 'number' ? data.seed : 12345);
  const state: GameState = {
    ...fallback,
    ...data,
    version: SAVE_VERSION,
    upgrades: { ...fallback.upgrades, ...(data.upgrades ?? {}) },
    stats: { ...fallback.stats, ...(data.stats ?? {}) },
    quota: { ...fallback.quota, ...(data.quota ?? {}) },
    flags: { ...fallback.flags, ...(data.flags ?? {}) },
    tasks: Array.isArray(data.tasks) ? data.tasks : fallback.tasks,
    log: Array.isArray(data.log) ? data.log.slice(0, 80) : [],
    faults: { ...(data.faults ?? {}) },
    decisions: Array.isArray(data.decisions) ? data.decisions : [],
    routine: Array.isArray(data.routine) && data.routine.length === 4 ? data.routine : fallback.routine,
    weather: { ...fallback.weather, ...(data.weather ?? {}) },
  };
  state.parts = Math.max(0, Math.round(state.parts || 0));
  state.stress = clamp(state.stress, 0, 100);
  state.points = Math.max(0, Math.round(state.points || 0));
  return state;
}

function clamp(v: number, min: number, max: number): number {
  return Math.max(min, Math.min(max, Number.isFinite(v) ? v : min));
}

export function saveGame(state: GameState, storage: StorageLike): boolean {
  try {
    storage.setItem(SAVE_KEY, serialize(state));
    return true;
  } catch {
    return false;
  }
}

export function loadGame(storage: StorageLike): GameState | null {
  try {
    return deserialize(storage.getItem(SAVE_KEY));
  } catch {
    return null;
  }
}

export function hasSave(storage: StorageLike): boolean {
  try {
    return storage.getItem(SAVE_KEY) !== null;
  } catch {
    return false;
  }
}

export function clearSave(storage: StorageLike): void {
  try {
    storage.removeItem(SAVE_KEY);
  } catch {
    /* almacenamiento no disponible: la partida sigue en memoria */
  }
}

/** Resumen del día para la pantalla de cambio de turno. */
export function dayBriefing(day: number): string[] {
  const briefs = [
    'Turno 1. La estación lleva cuatro meses sin operador. El manual sigue encima de la mesa.',
    'Turno 2. Han cambiado la cerradura del almacén. Nadie te ha dado la llave nueva.',
    'Turno 3. Hay una nota en el registro: "no apuntes al sur antes de las 03:00".',
    'Turno 4. El generador arranca solo dos minutos cada hora. No lo has encendido tú.',
    'Turno 5. La puerta de la antena estaba abierta. La nieve de dentro está pisada.',
    'Turno 6. El parte meteorológico repite la misma frase desde ayer.',
    'Turno 7. Alguien ha marcado tu altura en el marco de la puerta. Dos veces.',
    'Turno 8. La emisora de radio solo emite portadora. Lleva así nueve horas.',
    'Turno 9. El registro de la antena suma cuarenta horas de escucha que no existen.',
    'Turno 10. En el mapa de estrellas falta una constelación entera.',
    'Turno 11. El turno anterior a ti no aparece en ningún registro.',
    'Turno 12. Anoche alguien respondió a tu transmisión antes de que la enviaras.',
  ];
  return [briefs[(day - 1) % briefs.length]!];
}
