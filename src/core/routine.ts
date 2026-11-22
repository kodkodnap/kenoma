// Rutina del operador (fase 2). El juego recuerda dónde sueles estar en cada
// tramo de la noche para que "algo" pueda imitarte. Puro y serializable.

import type { GameState } from './state';
import { shiftPhase } from './time';

export const ROUTINE_BUCKETS = 4;

export interface RoutineSpot {
  x: number;
  z: number;
  /** Cuántas muestras ha acumulado el tramo. Bajo = dato poco fiable. */
  weight: number;
}

export function phaseBucket(clock: number): number {
  switch (shiftPhase(clock)) {
    case 'atardecer':
      return 0;
    case 'noche':
      return 1;
    case 'madrugada':
      return 2;
    case 'amanecer':
      return 3;
  }
}

function emptyRoutine(): (RoutineSpot | null)[] {
  return new Array<RoutineSpot | null>(ROUTINE_BUCKETS).fill(null);
}

export function ensureRoutine(state: GameState): (RoutineSpot | null)[] {
  if (!Array.isArray(state.routine) || state.routine.length !== ROUTINE_BUCKETS) {
    state.routine = emptyRoutine();
  }
  return state.routine;
}

/**
 * Acumula una muestra de posición. La media es móvil: cuanto más tiempo pasas
 * en un sitio, más peso tiene, así que la rutina converge a tus costumbres.
 */
export function recordRoutine(state: GameState, clock: number, x: number, z: number): void {
  const routine = ensureRoutine(state);
  const bucket = phaseBucket(clock);
  const prev = routine[bucket];
  if (!prev) {
    routine[bucket] = { x, z, weight: 1 };
    return;
  }
  const w = Math.min(240, prev.weight);
  routine[bucket] = {
    x: (prev.x * w + x) / (w + 1),
    z: (prev.z * w + z) / (w + 1),
    weight: prev.weight + 1,
  };
}

/** Posición habitual del tramo actual, si hay datos suficientes. */
export function routineSpot(state: GameState, clock: number): RoutineSpot | null {
  const routine = ensureRoutine(state);
  const spot = routine[phaseBucket(clock)];
  if (!spot || spot.weight < 40) return null;
  return spot;
}

/** ¿Conoce el juego tu rutina de este tramo? Lo usa el arquetipo "aprendiz". */
export function knowsRoutine(state: GameState, clock: number): boolean {
  return routineSpot(state, clock) !== null;
}

export function resetRoutine(state: GameState): void {
  state.routine = emptyRoutine();
}
