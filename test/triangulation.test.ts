import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/rng';
import {
  bearingBetween,
  bearingDelta,
  bearingQuality,
  intersectBearings,
  planarDistance,
  stationWorld,
  TRI_LOCK,
  TRI_STATIONS,
  triTarget,
  type Bearing,
} from '../src/core/triangulation';

const ORIGIN = { x: -900, z: 0 };

describe('rumbos', () => {
  it('el rumbo apunta a los puntos cardinales', () => {
    expect(bearingBetween(0, 0, 0, 10)).toBeCloseTo(0, 5);
    expect(bearingBetween(0, 0, 10, 0)).toBeCloseTo(90, 5);
    expect(bearingBetween(0, 0, 0, -10)).toBeCloseTo(180, 5);
    expect(bearingBetween(0, 0, -10, 0)).toBeCloseTo(270, 5);
  });

  it('la diferencia angular es la más corta', () => {
    expect(bearingDelta(350, 10)).toBeCloseTo(20, 5);
    expect(bearingDelta(10, 350)).toBeCloseTo(20, 5);
    expect(bearingDelta(0, 180)).toBeCloseTo(180, 5);
    expect(bearingDelta(359, 1)).toBeCloseTo(2, 5);
  });

  it('la calidad cae con el error de apuntado', () => {
    expect(bearingQuality(100, 100)).toBeCloseTo(1, 5);
    expect(bearingQuality(100, 110)).toBeLessThan(TRI_LOCK);
    expect(bearingQuality(100, 175)).toBeLessThan(0.01);
  });

  it('los mástiles se colocan en torno al origen del emplazamiento', () => {
    const a = stationWorld(TRI_STATIONS[0]!, ORIGIN.x, ORIGIN.z);
    expect(a.x).toBeCloseTo(ORIGIN.x + TRI_STATIONS[0]!.offset[0], 5);
    expect(planarDistance(a.x, a.z, ORIGIN.x, ORIGIN.z)).toBeGreaterThan(5);
  });
});

describe('intersección de rumbos', () => {
  const target = { x: -400, z: 220 };

  function readingsFrom(errorDeg = 0, jitter = 0): Bearing[] {
    const rng = new Rng(4);
    return TRI_STATIONS.map((station) => {
      const from = stationWorld(station, ORIGIN.x, ORIGIN.z);
      const exact = bearingBetween(from.x, from.z, target.x, target.z);
      const bearing = (exact + (errorDeg ? (rng.next() - 0.5) * 2 * jitter : 0) + 360) % 360;
      return { x: from.x, z: from.z, bearing };
    });
  }

  it('tres rumbos exactos dan el emisor con dispersión casi nula', () => {
    const fix = intersectBearings(readingsFrom());
    expect(fix.ok).toBe(true);
    expect(fix.x).toBeCloseTo(target.x, 1);
    expect(fix.z).toBeCloseTo(target.z, 1);
    expect(fix.spread).toBeLessThan(1);
  });

  it('las medidas con ruido siguen convergiendo, con más dispersión', () => {
    const fix = intersectBearings(readingsFrom(1, 0.4));
    expect(fix.ok).toBe(true);
    expect(fix.spread).toBeGreaterThan(0);
    // Con tres rumbos que convergen, el punto cae cerca del emisor.
    expect(planarDistance(fix.x, fix.z, target.x, target.z)).toBeLessThan(150);
  });

  it('dos rumbos paralelos no localizan nada', () => {
    const fix = intersectBearings([
      { x: 0, z: 0, bearing: 90 },
      { x: 0, z: 10, bearing: 90 },
      { x: 0, z: 20, bearing: 90 },
    ]);
    expect(fix.ok).toBe(false);
  });

  it('una sola medida no basta', () => {
    expect(intersectBearings([{ x: 0, z: 0, bearing: 10 }]).ok).toBe(false);
  });
});

describe('emisor del día', () => {
  it('es determinista y cae entre 260 y 620 m del repetidor', () => {
    const a = triTarget(1234, 8, ORIGIN.x, ORIGIN.z);
    const b = triTarget(1234, 8, ORIGIN.x, ORIGIN.z);
    expect(a).toEqual(b);
    expect(a.distance).toBeGreaterThanOrEqual(260);
    expect(a.distance).toBeLessThanOrEqual(620);
    expect(['ANOMALO', 'VACIO']).toContain(a.klass);
  });

  it('cambia de un día para otro', () => {
    const monday = triTarget(1234, 8, ORIGIN.x, ORIGIN.z);
    const tuesday = triTarget(1234, 9, ORIGIN.x, ORIGIN.z);
    expect(planarDistance(monday.x, monday.z, tuesday.x, tuesday.z)).toBeGreaterThan(1);
  });
});
