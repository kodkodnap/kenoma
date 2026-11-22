// Averías y sabotaje (fase 2). Lógica pura: qué máquina falla, cómo se
// calibra, cuánto desajusta un intento fallido y para qué sirven las piezas
// de repuesto. La UI solo lee estado y llama acciones.

import { Rng } from './rng';
import { addPoints, addStress, GameState, log, type FaultState } from './state';
import { clockLabel } from './time';

export type MachineId = 'spectrum' | 'demod' | 'decoder';

export interface MachineDef {
  id: MachineId;
  label: string;
  short: string;
}

export const MACHINES: MachineDef[] = [
  { id: 'spectrum', label: 'Analizador de espectro SA-9', short: 'ESPECTRO' },
  { id: 'demod', label: 'Demodulador DM-4', short: 'DEMOD' },
  { id: 'decoder', label: 'Decodificador de patrones PD-2', short: 'PATRÓN' },
];

export const PART_COST = 60;

export function machineDef(id: MachineId): MachineDef {
  return MACHINES.find((m) => m.id === id) ?? MACHINES[0]!;
}

function blankFault(): FaultState {
  return { broken: false, severity: 0, attempt: 0, since: -1 };
}

export function faultOf(state: GameState, id: MachineId): FaultState {
  return state.faults[id] ?? blankFault();
}

export function machineBroken(state: GameState, id: MachineId): boolean {
  return faultOf(state, id).broken;
}

export function brokenMachines(state: GameState): MachineId[] {
  return MACHINES.filter((m) => machineBroken(state, m.id)).map((m) => m.id);
}

/** Probabilidad de avería espontánea por segundo: sube con el día y el estrés. */
export function faultChancePerSecond(state: GameState): number {
  const day = 1 + state.day * 0.09;
  const stress = 1 + state.stress / 130;
  const weather = state.weather.kind === 'tormenta' ? 1.7 : state.weather.kind === 'ventisca' ? 1.3 : 1;
  return 0.00035 * day * stress * weather;
}

function pickVictim(state: GameState, rng: Rng): MachineId | null {
  const healthy = healthyMachines(state);
  if (healthy.length === 0) return null;
  return rng.pick(healthy);
}

export function healthyMachines(state: GameState): MachineId[] {
  return MACHINES.filter((m) => !machineBroken(state, m.id)).map((m) => m.id);
}

export function breakMachine(state: GameState, id: MachineId, severity: number, sabotageFlavor: boolean): void {
  const fault = blankFault();
  fault.broken = true;
  fault.severity = Math.max(0.2, Math.min(1, severity));
  fault.since = state.clock;
  state.faults[id] = fault;
  if (sabotageFlavor) state.stats.sabotages += 1;
  const def = machineDef(id);
  log(
    state,
    sabotageFlavor
      ? `${def.label}: el panel está abierto y el tornillo de calibración no está. Alguien lo ha soltado.`
      : `${def.label}: la aguja se ha ido a fondo de escala. Necesita calibración.`,
    sabotageFlavor ? 'bad' : 'warn',
    clockLabel(state.clock),
  );
}

/** Avería natural. Solo rompe una máquina sana, y nunca dos a la vez. */
export function maybeFault(state: GameState, rng: Rng, dt: number): MachineId | null {
  if (brokenMachines(state).length > 0) return null;
  if (!rng.chance(faultChancePerSecond(state) * dt)) return null;
  const victim = pickVictim(state, rng);
  if (!victim) return null;
  breakMachine(state, victim, rng.range(0.25, 0.7), false);
  return victim;
}

/** Sabotaje: siempre deja una máquina fuera de servicio, con la calibración forzada. */
export function sabotage(state: GameState, rng: Rng): MachineId | null {
  const victim = pickVictim(state, rng);
  if (!victim) return null;
  breakMachine(state, victim, rng.range(0.6, 1), true);
  return victim;
}

export interface CalibrationResult {
  ok: boolean;
  message: string;
}

/**
 * Calibrar a mano: barato, lento y no garantizado. Cada intento fallido
 * desajusta un poco más la máquina, así que conviene no insistir a ciegas.
 */
export function calibrate(state: GameState, rng: Rng, id: MachineId): CalibrationResult {
  const fault = faultOf(state, id);
  const def = machineDef(id);
  if (!fault.broken) return { ok: false, message: `${def.short}: la unidad ya está en servicio.` };

  const chance = Math.max(0.06, Math.min(0.95, 0.42 + fault.attempt * 0.26 - fault.severity * 0.34));
  addStress(state, 3);
  if (rng.chance(chance)) {
    delete state.faults[id];
    state.stats.repairs += 1;
    log(state, `${def.label}: calibrada. El tornillo vuelve a su sitio y la aguja responde.`, 'good', clockLabel(state.clock));
    return { ok: true, message: `${def.short} calibrada. Unidad en servicio.` };
  }
  fault.attempt += 1;
  fault.severity = Math.min(1, fault.severity + 0.07);
  addStress(state, 2);
  log(state, `${def.label}: el ajuste no encaja. El desajuste ha crecido un poco más.`, 'warn', clockLabel(state.clock));
  return {
    ok: false,
    message: `${def.short} sigue fuera de servicio. Intento ${fault.attempt}. El desajuste aumenta con cada prueba.`,
  };
}

/** Repuesto: repara al instante y sin riesgo. Consume una pieza. */
export function repairWithPart(state: GameState, id: MachineId): CalibrationResult {
  const fault = faultOf(state, id);
  const def = machineDef(id);
  if (!fault.broken) return { ok: false, message: `${def.short}: la unidad ya está en servicio.` };
  if (state.parts <= 0) return { ok: false, message: 'No quedan piezas de repuesto. Cómpralas en la consola.' };
  state.parts -= 1;
  delete state.faults[id];
  state.stats.repairs += 1;
  log(state, `${def.label}: pieza sustituida. Vuelve a arrancar en el primer intento.`, 'good', clockLabel(state.clock));
  return { ok: true, message: `${def.short} reparada. Quedan ${state.parts} piezas.` };
}

export function buyPart(state: GameState): { ok: boolean; message: string } {
  if (state.points < PART_COST) return { ok: false, message: `Faltan ${PART_COST - state.points} créditos para una pieza.` };
  addPoints(state, -PART_COST);
  state.parts += 1;
  return { ok: true, message: `Pieza de repuesto adquirida. Tienes ${state.parts}.` };
}

/** Aviso para el HUD: lista legible de lo que está roto. */
export function faultLabel(state: GameState): string | null {
  const broken = brokenMachines(state);
  if (broken.length === 0) return null;
  return broken.map((id) => machineDef(id).short).join(' · ');
}
