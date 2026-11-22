// Reloj del turno. El jugador cubre de 19:00 a 05:00 (600 minutos de juego).
// 1 minuto de juego ≈ 1.15 s reales => un turno completo dura ~11,5 min.

export const SHIFT_START_MIN = 19 * 60; // 1140
export const SHIFT_LENGTH_MIN = 600;
export const SECONDS_PER_GAME_MIN = 1.15;
export const GAME_MIN_PER_SECOND = 1 / SECONDS_PER_GAME_MIN;

export function clockMinutes(clock: number): number {
  return (SHIFT_START_MIN + Math.max(0, clock)) % 1440;
}

export function clockLabel(clock: number, withSeconds = false): string {
  const total = clockMinutes(clock);
  const h = Math.floor(total / 60);
  const m = Math.floor(total % 60);
  const base = `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
  if (!withSeconds) return base;
  const s = Math.floor((Math.max(0, clock) % 1) * 60);
  return `${base}:${String(s).padStart(2, '0')}`;
}

export type ShiftPhase = 'atardecer' | 'noche' | 'madrugada' | 'amanecer';

export function shiftPhase(clock: number): ShiftPhase {
  if (clock < 90) return 'atardecer';
  if (clock < 330) return 'noche';
  if (clock < 540) return 'madrugada';
  return 'amanecer';
}

/** 0 al empezar, 1 al terminar. Sirve para escalar tensión y oscuridad. */
export function shiftProgress(clock: number): number {
  return Math.min(1, Math.max(0, clock / SHIFT_LENGTH_MIN));
}

export function isShiftOver(clock: number): boolean {
  return clock >= SHIFT_LENGTH_MIN;
}

/** Eventos más probables en el tramo profundo de la noche. */
export function dangerCurve(clock: number): number {
  const p = shiftProgress(clock);
  return 0.35 + Math.sin(p * Math.PI) * 0.95 + p * 0.4;
}
