import { describe, expect, it } from 'vitest';
import { segmentBlocked, segmentIntersectsRect } from '../src/world/los';

const wall = { minX: -1, maxX: 1, minZ: -3, maxZ: 3, height: 3 };
const lowCrate = { minX: -1, maxX: 1, minZ: -3, maxZ: 3, height: 0.9 };

describe('línea de visión', () => {
  it('detecta un cruce frontal con el rectángulo', () => {
    expect(segmentIntersectsRect(-5, 0, 5, 0, wall)).toBe(true);
  });

  it('no detecta un segmento que pasa de largo', () => {
    expect(segmentIntersectsRect(-5, 5, 5, 5, wall)).toBe(false);
  });

  it('acepta el segmento que empieza dentro', () => {
    expect(segmentIntersectsRect(0, 0, 8, 0, wall)).toBe(true);
  });

  it('no bloquea si el obstáculo es bajo', () => {
    expect(segmentBlocked(-5, 0, 5, 0, [wall])).toBe(true);
    expect(segmentBlocked(-5, 0, 5, 0, [lowCrate])).toBe(false);
  });

  it('deja pasar la vista por un lado de la pared', () => {
    expect(segmentBlocked(-5, 8, 5, 8, [wall])).toBe(false);
  });

  it('una pared en diagonal también bloquea', () => {
    expect(segmentBlocked(-4, -4, 4, 4, [wall])).toBe(true);
  });

  it('sin colliders nunca bloquea', () => {
    expect(segmentBlocked(0, 0, 10, 10, [])).toBe(false);
  });
});
