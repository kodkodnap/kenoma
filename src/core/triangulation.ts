// Triangulación con tres mástiles (fase 2). Geometría pura y determinista:
// cada mástil mide un rumbo al emisor desconocido y la intersección de los tres
// rumbos localiza el origen. El error de cada medida depende de cómo de fino
// se haya apuntado, así que una lectura mala desplaza el punto.

import { Rng } from './rng';

export interface Station {
  id: string;
  label: string;
  /** Desplazamiento respecto al origen del emplazamiento del repetidor. */
  offset: [number, number];
}

export const TRI_STATIONS: Station[] = [
  { id: 'mastil_a', label: 'Mástil A', offset: [-15, -7] },
  { id: 'mastil_b', label: 'Mástil B', offset: [17, -5] },
  { id: 'mastil_c', label: 'Mástil C', offset: [1, 15] },
];

/** Anchura angular de la aguja de cada mástil: mejor apuntado, mejor rumbo. */
export const TRI_SIGMA = 7.5;
/** Umbral de calidad para dar un rumbo por bueno. */
export const TRI_LOCK = 0.55;

export function stationWorld(station: Station, originX: number, originZ: number): { x: number; z: number } {
  return { x: originX + station.offset[0], z: originZ + station.offset[1] };
}

/** Rumbo en grados (0 = +Z, sentido horario) desde un punto hasta otro. */
export function bearingBetween(fx: number, fz: number, tx: number, tz: number): number {
  const deg = (Math.atan2(tx - fx, tz - fz) * 180) / Math.PI;
  return (deg + 360) % 360;
}

/** Diferencia angular mínima entre dos rumbos, en grados (0..180). */
export function bearingDelta(a: number, b: number): number {
  return Math.abs(((a - b + 540) % 360) - 180);
}

/** Calidad 0..1 de una medida de rumbo: gaussiana sobre el error de apuntado. */
export function bearingQuality(aimed: number, trueBearing: number): number {
  const err = bearingDelta(aimed, trueBearing);
  return Math.max(0, Math.exp(-Math.pow(err / TRI_SIGMA, 2)));
}

export interface Bearing {
  x: number;
  z: number;
  /** Rumbo medido, en grados. */
  bearing: number;
}

export interface Fix {
  ok: boolean;
  x: number;
  z: number;
  /** Dispersión en metros entre los tres rumbos. Baja = convergen. */
  spread: number;
}

/**
 * Mínimos cuadrados sobre las rectas de los rumbos. Con tres rumbos que no
 * convergen (spread alto) la posición no es fiable y se marca como fallo.
 */
export function intersectBearings(readings: readonly Bearing[]): Fix {
  if (readings.length < 2) return { ok: false, x: 0, z: 0, spread: Infinity };
  let a11 = 0;
  let a12 = 0;
  let a22 = 0;
  let b1 = 0;
  let b2 = 0;
  for (const r of readings) {
    const rad = (r.bearing * Math.PI) / 180;
    // Normal de la recta: (cos b, -sin b)
    const nx = Math.cos(rad);
    const nz = -Math.sin(rad);
    const rhs = r.x * nx + r.z * nz;
    a11 += nx * nx;
    a12 += nx * nz;
    a22 += nz * nz;
    b1 += nx * rhs;
    b2 += nz * rhs;
  }
  const det = a11 * a22 - a12 * a12;
  if (Math.abs(det) < 1e-6) return { ok: false, x: 0, z: 0, spread: Infinity };
  const x = (b1 * a22 - b2 * a12) / det;
  const z = (a11 * b2 - a12 * b1) / det;

  let sum = 0;
  for (const r of readings) {
    const rad = (r.bearing * Math.PI) / 180;
    const nx = Math.cos(rad);
    const nz = -Math.sin(rad);
    const residual = (x - r.x) * nx + (z - r.z) * nz;
    sum += residual * residual;
  }
  const spread = Math.sqrt(sum / readings.length);
  return { ok: spread <= 90, x, z, spread };
}

export interface TriTarget {
  x: number;
  z: number;
  klass: 'ANOMALO' | 'VACIO';
  /** Distancia al emplazamiento del repetidor, para la ficha. */
  distance: number;
  name: string;
}

const TARGET_NAMES = ['PUNTO CIEGO', 'POZO 14', 'LADERA SUR', 'AGUJA DE HIELO', 'CORRAL VACÍO'];

/**
 * El emisor del día: un punto fijo del valle, a entre 260 y 620 m del
 * repetidor. Determinista a partir de semilla y día, para que el guardado lo
 * reproduzca sin almacenarlo.
 */
export function triTarget(seed: number, day: number, originX: number, originZ: number): TriTarget {
  const rng = new Rng((seed ^ (day * 104729)) >>> 0);
  const angle = rng.range(0, Math.PI * 2);
  const distance = rng.range(260, 620);
  return {
    x: originX + Math.sin(angle) * distance,
    z: originZ + Math.cos(angle) * distance,
    klass: rng.chance(0.55) ? 'ANOMALO' : 'VACIO',
    distance,
    name: rng.pick(TARGET_NAMES),
  };
}

/** Distancia en planta. */
export function planarDistance(ax: number, az: number, bx: number, bz: number): number {
  return Math.hypot(ax - bx, az - bz);
}
