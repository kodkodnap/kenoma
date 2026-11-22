// RNG determinista y serializable. Toda la aleatoriedad del juego pasa por aquí:
// así una partida guardada reproduce exactamente los mismos eventos.

export class Rng {
  private s: number;

  constructor(seed = Date.now()) {
    this.s = seed >>> 0;
  }

  get state(): number {
    return this.s;
  }

  set state(v: number) {
    this.s = v >>> 0;
  }

  /** [0, 1) */
  next(): number {
    this.s = (this.s + 0x6d2b79f5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  /** [min, max) */
  range(min: number, max: number): number {
    return min + this.next() * (max - min);
  }

  /** entero en [min, max] */
  int(min: number, max: number): number {
    return Math.floor(this.range(min, max + 1));
  }

  chance(p: number): boolean {
    return this.next() < p;
  }

  pick<T>(arr: readonly T[]): T {
    if (arr.length === 0) throw new Error('Rng.pick: array vacío');
    return arr[Math.floor(this.next() * arr.length)]!;
  }

  /** Elige por peso; devuelve null si todos los pesos son 0. */
  weighted<T>(items: readonly { item: T; weight: number }[]): T | null {
    const total = items.reduce((a, b) => a + Math.max(0, b.weight), 0);
    if (total <= 0) return null;
    let r = this.next() * total;
    for (const entry of items) {
      r -= Math.max(0, entry.weight);
      if (r <= 0) return entry.item;
    }
    return items[items.length - 1]?.item ?? null;
  }

  shuffle<T>(arr: T[]): T[] {
    for (let i = arr.length - 1; i > 0; i--) {
      const j = Math.floor(this.next() * (i + 1));
      [arr[i], arr[j]] = [arr[j]!, arr[i]!];
    }
    return arr;
  }
}

export function hashString(text: string): number {
  let h = 2166136261;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}
