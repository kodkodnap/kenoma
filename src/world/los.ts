// Línea de visión en planta: evita que las entidades te "vean" a través de
// paredes (y que tú las congeles mirando una pared). Lógica pura y testeable.

export interface RectCollider {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  height: number;
}

/** Recorte de segmento contra rectángulo (Liang–Barsky). */
export function segmentIntersectsRect(
  x0: number,
  z0: number,
  x1: number,
  z1: number,
  rect: RectCollider,
): boolean {
  let t0 = 0;
  let t1 = 1;
  const dx = x1 - x0;
  const dz = z1 - z0;
  const p = [-dx, dx, -dz, dz];
  const q = [x0 - rect.minX, rect.maxX - x0, z0 - rect.minZ, rect.maxZ - z0];

  for (let i = 0; i < 4; i++) {
    if (Math.abs(p[i]!) < 1e-9) {
      if (q[i]! < 0) return false;
      continue;
    }
    const r = q[i]! / p[i]!;
    if (p[i]! < 0) {
      if (r > t1) return false;
      if (r > t0) t0 = r;
    } else {
      if (r < t0) return false;
      if (r < t1) t1 = r;
    }
  }
  return t0 <= t1;
}

/**
 * ¿Hay un obstáculo sólido entre dos puntos? Se ignoran los colliders bajos
 * (cajas, barriles) porque no tapan la silueta de una entidad de dos metros.
 */
export function segmentBlocked(
  x0: number,
  z0: number,
  x1: number,
  z1: number,
  colliders: readonly RectCollider[],
  minHeight = 1.4,
): boolean {
  for (const c of colliders) {
    if (c.height < minHeight) continue;
    if (segmentIntersectsRect(x0, z0, x1, z1, c)) return true;
  }
  return false;
}
