// Entidades del exterior. No son decorado: se mueven solo cuando no las miras,
// reaccionan al escáner y dejan datos si las observas en vez de huir.

import * as THREE from 'three';
import type { EntityKind, SpawnPoint } from '../core/events';
import { Level, type ZoneName } from './level';
import { segmentBlocked } from './los';

export interface Entity {
  kind: EntityKind;
  group: THREE.Group;
  position: THREE.Vector3;
  ttl: number;
  stage: 'idle' | 'approach' | 'leaving' | 'gone';
  observedFor: number;
  scanned: boolean;
  registered: boolean;
  bob: number;
  fade: number;
  /** Retardo de imitación, en segundos (solo para el imitador). */
  delay: number;
}

interface TrailPoint {
  x: number;
  z: number;
  t: number;
}

const BLACK = new THREE.MeshBasicMaterial({ color: 0x04070a, fog: true });
/** Eco translúcido del imitador: material propio para no tocar el BLACK común. */
const GHOST = new THREE.MeshBasicMaterial({ color: 0x04070a, fog: true, transparent: true, opacity: 0.5 });

function silhouette(height = 2.15, shoulders = 0.22): THREE.Group {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.CylinderGeometry(shoulders * 0.72, shoulders, height * 0.78, 7), BLACK);
  body.position.y = height * 0.39;
  g.add(body);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.15, 8, 6), BLACK);
  head.position.y = height * 0.86;
  head.scale.set(0.9, 1.15, 0.9);
  g.add(head);
  const armL = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.04, height * 0.62, 5), BLACK);
  armL.position.set(-shoulders * 0.95, height * 0.38, 0);
  armL.rotation.z = 0.06;
  g.add(armL);
  const armR = armL.clone();
  armR.position.x = shoulders * 0.95;
  armR.rotation.z = -0.06;
  g.add(armR);
  return g;
}

/** Silueta con farol: el que comercia se anuncia para que lo veas llegar. */
function traderFigure(): THREE.Group {
  const g = silhouette(2.05, 0.26);
  const crate = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.55, 0.5), new THREE.MeshBasicMaterial({ color: 0x04070a }));
  crate.position.set(0.55, 0.28, 0.1);
  g.add(crate);
  const lamp = new THREE.Mesh(
    new THREE.SphereGeometry(0.09, 6, 5),
    new THREE.MeshBasicMaterial({ color: 0xffb066 }),
  );
  lamp.position.set(0.55, 0.62, 0.1);
  g.add(lamp);
  return g;
}

/** Silueta con mochila: el que aprende tu rutina lleva tu equipo. */
function learnerFigure(): THREE.Group {
  const g = silhouette(2.1, 0.2);
  const pack = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.5, 0.24), new THREE.MeshBasicMaterial({ color: 0x04070a }));
  pack.position.set(0, 1.15, -0.24);
  g.add(pack);
  return g;
}

function quadruped(): THREE.Group {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.45, 0.4), BLACK);
  body.position.y = 0.55;
  g.add(body);
  const head = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.3, 0.28), BLACK);
  head.position.set(0.62, 0.72, 0);
  g.add(head);
  for (const [x, z] of [
    [0.32, 0.14],
    [0.32, -0.14],
    [-0.34, 0.14],
    [-0.34, -0.14],
  ] as const) {
    const leg = new THREE.Mesh(new THREE.CylinderGeometry(0.055, 0.045, 0.55, 4), BLACK);
    leg.position.set(x, 0.27, z);
    leg.rotation.z = x > 0 ? 0.18 : -0.18;
    g.add(leg);
  }
  return g;
}

export class EntityManager {
  readonly entities: Entity[] = [];
  onContact?: (entity: Entity, how: 'observed' | 'scanned' | 'approached' | 'left') => void;
  onSpawn?: (entity: Entity) => void;

  private group = new THREE.Group();
  private level: Level;
  private camera: THREE.PerspectiveCamera;
  private tmp = new THREE.Vector3();
  private tmp2 = new THREE.Vector3();
  /** Emplazamiento activo: los contactos aparecen donde está el jugador. */
  activeZone: ZoneName = 'kestrel';
  /** Rastro del jugador: es lo que imita el arquetipo "imitador". */
  private trail: TrailPoint[] = [];
  private time = 0;

  constructor(scene: THREE.Scene, level: Level, camera: THREE.PerspectiveCamera) {
    this.level = level;
    this.camera = camera;
    scene.add(this.group);
  }

  private buildGroup(kind: EntityKind): THREE.Group {
    if (kind === 'perro') return quadruped();
    if (kind === 'coro') {
      const g = new THREE.Group();
      for (let i = 0; i < 3; i++) {
        const fig = silhouette(1.9 + i * 0.12, 0.2);
        fig.position.set((i - 1) * 2.2 + Math.random(), 0, Math.random() * 1.5);
        fig.rotation.y = Math.random() * 1.2;
        g.add(fig);
      }
      return g;
    }
    if (kind === 'comerciante') return traderFigure();
    if (kind === 'aprendiz') return learnerFigure();
    if (kind === 'imitador') {
      const g = new THREE.Group();
      const main = silhouette(2.16, 0.19);
      g.add(main);
      const echo = silhouette(2.1, 0.18);
      echo.traverse((o) => {
        if (o instanceof THREE.Mesh) o.material = GHOST;
      });
      echo.position.set(0.45, 0, -0.35);
      echo.rotation.y = 0.12;
      g.add(echo);
      return g;
    }
    return silhouette(kind === 'doble' ? 1.86 : 2.16, kind === 'doble' ? 0.25 : 0.19);
  }

  spawn(kind: EntityKind, at: SpawnPoint): Entity {
    const base = this.level.spawnPointsFor(this.activeZone)[at].clone();
    const jitter = kind === 'coro' ? 6 : 2.4;
    base.x += (Math.random() - 0.5) * jitter;
    base.z += (Math.random() - 0.5) * jitter;
    return this.register(kind, base.x, base.z);
  }

  /** Aparición en una coordenada exacta (rutina del jugador, origen fijo). */
  spawnAt(kind: EntityKind, x: number, z: number): Entity {
    return this.register(kind, x, z);
  }

  private register(kind: EntityKind, x: number, z: number): Entity {
    const group = this.buildGroup(kind);
    group.position.set(x, 0, z);
    group.rotation.y = Math.atan2(-x, -z);
    this.group.add(group);

    const ttl =
      kind === 'doble'
        ? 55
        : kind === 'coro'
          ? 70
          : kind === 'comerciante'
            ? 190
            : kind === 'aprendiz'
              ? 150
              : kind === 'imitador'
                ? 160
                : 130;
    const entity: Entity = {
      kind,
      group,
      position: new THREE.Vector3(x, 0, z),
      ttl,
      stage: 'idle',
      observedFor: 0,
      scanned: false,
      registered: false,
      bob: Math.random() * 10,
      fade: 1,
      delay: 4 + Math.random() * 1.5,
    };
    this.entities.push(entity);
    this.onSpawn?.(entity);
    return entity;
  }

  /** Punto del rastro de hace `delay` segundos. */
  private trailAt(delay: number): TrailPoint | null {
    for (let i = this.trail.length - 1; i >= 0; i--) {
      const p = this.trail[i]!;
      if (this.time - p.t >= delay) return p;
    }
    return null;
  }

  clear(): void {
    for (const e of this.entities) this.group.remove(e.group);
    this.entities.length = 0;
    this.trail.length = 0;
  }

  /** Devuelve la entidad bajo la mira, si está a tiro de escáner. */
  scanTarget(): Entity | null {
    const dir = this.camera.getWorldDirection(this.tmp).normalize();
    let best: Entity | null = null;
    let bestDot = 0.982;
    for (const e of this.entities) {
      if (e.stage === 'gone') continue;
      const to = this.tmp2.copy(e.position).setY(1.1).sub(this.camera.position);
      const dist = to.length();
      if (dist > 55) continue;
      const dot = dir.dot(to.normalize());
      if (dot > bestDot && dist > 2.2 && !segmentBlocked(
        this.camera.position.x,
        this.camera.position.z,
        e.position.x,
        e.position.z,
        this.level.colliders,
      )) {
        bestDot = dot;
        best = e;
      }
    }
    return best;
  }

  isObserved(e: Entity): { observed: boolean; dist: number } {
    const dist = e.position.distanceTo(this.camera.position);
    const dir = this.camera.getWorldDirection(this.tmp).normalize();
    const to = this.tmp2.copy(e.position).setY(1.15).sub(this.camera.position).normalize();
    const inView = dir.dot(to) > 0.955 && dist < 70;
    const clear = inView && !segmentBlocked(
      this.camera.position.x,
      this.camera.position.z,
      e.position.x,
      e.position.z,
      this.level.colliders,
    );
    return { observed: clear, dist };
  }

  update(dt: number, playerPos: THREE.Vector3): void {
    this.time += dt;
    this.recordTrail(playerPos);
    for (const e of this.entities) {
      if (e.stage === 'gone') continue;
      e.ttl -= dt;
      e.bob += dt;
      const { observed } = this.isObserved(e);
      const toward = this.tmp.copy(playerPos).sub(e.position).setY(0);
      const gap = toward.length();
      if (gap > 0.001) toward.normalize();

      switch (e.kind) {
        case 'figura': {
          if (observed) {
            e.observedFor += dt;
            if (e.observedFor > 3.4 && !e.registered) {
              e.registered = true;
              this.onContact?.(e, 'observed');
              this.vanish(e, 0.4);
              break;
            }
          } else {
            e.observedFor = Math.max(0, e.observedFor - dt * 0.6);
            // Avanza solo cuando nadie mira.
            if (gap > 4.5) e.position.addScaledVector(toward, dt * 0.95);
          }
          if (gap < 3.2) {
            this.onContact?.(e, 'approached');
            this.vanish(e, 1.8);
          }
          break;
        }
        case 'doble': {
          if (observed) {
            // Desaparece si lo miras de frente; reaparece más cerca al apartar la vista.
            e.fade -= dt * 4;
            if (e.fade <= 0) {
              e.fade = 0;
              e.position.addScaledVector(toward, Math.min(7, gap * 0.5));
              e.group.position.copy(e.position);
              e.stage = 'approach';
              if (!e.registered && gap < 14) {
                e.registered = true;
                this.onContact?.(e, 'observed');
              }
            }
          } else {
            e.fade = Math.min(1, e.fade + dt * 1.2);
            if (gap > 6) e.position.addScaledVector(toward, dt * 1.6);
          }
          e.group.visible = e.fade > 0.03;
          break;
        }
        case 'perro': {
          if (gap < 2.6 && !e.registered) {
            e.registered = true;
            this.onContact?.(e, 'approached');
            this.vanish(e, 2);
          }
          e.group.position.y = Math.sin(e.bob * 1.4) * 0.03;
          break;
        }
        case 'coro': {
          for (const child of e.group.children) {
            child.position.y = Math.sin(e.bob + child.position.x) * 0.02;
          }
          break;
        }
        case 'imitador': {
          // Anda exactamente donde anduviste, con unos segundos de retardo.
          if (observed) {
            e.observedFor += dt;
            if (e.observedFor > 3 && !e.registered) {
              e.registered = true;
              this.onContact?.(e, 'observed');
              this.vanish(e, 0.3);
              break;
            }
          } else {
            e.observedFor = Math.max(0, e.observedFor - dt * 0.5);
            const past = this.trailAt(e.delay);
            if (past) {
              const step = this.tmp2.set(past.x - e.position.x, 0, past.z - e.position.z);
              const dist = step.length();
              if (dist > 0.05) {
                step.multiplyScalar(1 / dist);
                e.position.addScaledVector(step, Math.min(dist, dt * 1.05));
              }
            }
          }
          if (gap < 3.2) {
            this.onContact?.(e, 'approached');
            this.vanish(e, 1.6);
          }
          break;
        }
        case 'comerciante': {
          e.group.rotation.y = Math.atan2(-toward.x, -toward.z);
          if (gap < 3.4 && !e.registered) {
            e.registered = true;
            this.onContact?.(e, 'approached');
            this.vanish(e, 2.4);
          }
          break;
        }
        case 'aprendiz': {
          // No avanza: se queda en tu sitio habitual y te mira.
          e.group.rotation.y = Math.atan2(-toward.x, -toward.z);
          if (observed) {
            e.observedFor += dt;
            if (e.observedFor > 3.2 && !e.registered) {
              e.registered = true;
              this.onContact?.(e, 'observed');
              this.vanish(e, 0.5);
              break;
            }
          } else {
            e.observedFor = Math.max(0, e.observedFor - dt * 0.7);
          }
          break;
        }
      }

      e.group.position.set(e.position.x, e.group.position.y, e.position.z);
      e.group.rotation.y += Math.sin(e.bob * 0.7) * dt * 0.12;

      if (e.ttl <= 0) this.vanish(e, 0);
    }
    // Limpieza
    for (let i = this.entities.length - 1; i >= 0; i--) {
      if (this.entities[i]!.stage === 'gone') this.entities.splice(i, 1);
    }
  }

  /** El rastro guarda solo los tramos recorridos, no cada fotograma. */
  private recordTrail(playerPos: THREE.Vector3): void {
    const last = this.trail[this.trail.length - 1];
    if (!last || Math.hypot(playerPos.x - last.x, playerPos.z - last.z) > 0.45) {
      this.trail.push({ x: playerPos.x, z: playerPos.z, t: this.time });
      if (this.trail.length > 400) this.trail.shift();
      return;
    }
    // Sin movimiento: se refresca la marca para que el rastro no se alargue solo.
    last.t = Math.max(last.t, this.time);
    const cutoff = this.time - 40;
    while (this.trail.length > 2 && this.trail[0]!.t < cutoff) this.trail.shift();
  }

  /** El escáner de campo convierte una entidad en datos y la expulsa. */
  scan(e: Entity): void {
    e.scanned = true;
    this.onContact?.(e, 'scanned');
    this.vanish(e, 1.2);
  }

  vanish(e: Entity, delay: number): void {
    e.stage = 'gone';
    e.ttl = Math.max(0.05, delay);
    this.group.remove(e.group);
  }
}
