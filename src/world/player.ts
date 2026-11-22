// Controlador en primera persona: puntero, movimiento con colisiones AABB,
// linterna y detección de interactuables por raycast.

import * as THREE from 'three';
import { AABB, Interactable, Level } from './level';

const EYE = 1.68;
const RADIUS = 0.34;
const WALK = 4.1;
const SPRINT = 6.6;
const ACCEL = 52;
const DAMP = 11;

export class Player {
  readonly camera: THREE.PerspectiveCamera;
  readonly position = new THREE.Vector3(0, 0, 12);
  readonly flashlight: THREE.SpotLight;
  onStep?: (surface: 'snow' | 'floor') => void;
  onFocus?: (target: Interactable | null) => void;
  onLockChange?: (locked: boolean) => void;

  enabled = true;
  locked = false;
  flashlightOn = true;

  private level: Level;
  private canvas: HTMLCanvasElement;
  private yaw = Math.PI;
  private pitch = 0;
  private velocity = new THREE.Vector3();
  private keys = new Set<string>();
  private stepDist = 0;
  private bob = 0;
  private bobAmp = 0;
  private shake = 0;
  private focus: Interactable | null = null;
  private raycaster = new THREE.Raycaster();
  private tmp = new THREE.Vector3();

  constructor(canvas: HTMLCanvasElement, camera: THREE.PerspectiveCamera, level: Level) {
    this.canvas = canvas;
    this.camera = camera;
    this.level = level;
    this.position.set(0, 0, 12);

    this.flashlight = new THREE.SpotLight(0xfff2d6, 28, 34, 0.48, 0.55, 1.4);
    this.flashlight.position.set(0.12, -0.1, 0);
    const target = new THREE.Object3D();
    target.position.set(0, 0, -1);
    this.camera.add(target);
    this.flashlight.target = target;
    this.camera.add(this.flashlight);
    this.camera.position.copy(this.position).setY(EYE);

    canvas.addEventListener('click', () => {
      if (this.enabled && !this.locked) this.requestLock();
    });
    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === this.canvas;
      this.onLockChange?.(this.locked);
      if (!this.locked) this.keys.clear();
    });
    document.addEventListener('mousemove', (e) => {
      if (!this.locked || !this.enabled) return;
      this.yaw -= e.movementX * 0.0022;
      this.pitch -= e.movementY * 0.0022;
      this.pitch = Math.max(-1.45, Math.min(1.45, this.pitch));
    });
    window.addEventListener('keydown', (e) => {
      if (e.code === 'KeyF' && this.enabled) {
        this.flashlightOn = !this.flashlightOn;
        this.flashlight.visible = this.flashlightOn;
      }
      this.keys.add(e.code);
    });
    window.addEventListener('keyup', (e) => this.keys.delete(e.code));
    window.addEventListener('blur', () => this.keys.clear());

    this.raycaster.far = 3.4;
  }

  requestLock(): void {
    try {
      const result = this.canvas.requestPointerLock() as unknown;
      if (result instanceof Promise) result.catch(() => undefined);
    } catch {
      /* si el navegador lo bloquea, la UI sigue siendo usable */
    }
  }

  releaseLock(): void {
    if (document.pointerLockElement) document.exitPointerLock();
    this.keys.clear();
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (!enabled) {
      this.releaseLock();
      this.velocity.set(0, 0, 0);
    }
  }

  teleport(x: number, y: number, z: number): void {
    this.position.set(x, y, z);
    this.velocity.set(0, 0, 0);
    this.camera.position.set(x, y + EYE, z);
  }

  setLook(yaw: number, pitch: number): void {
    this.yaw = yaw;
    this.pitch = pitch;
  }

  addShake(amount: number): void {
    this.shake = Math.min(1.2, this.shake + amount);
  }

  get isMoving(): boolean {
    return this.velocity.lengthSq() > 0.6;
  }

  get currentFocus(): Interactable | null {
    return this.focus;
  }

  update(dt: number): void {
    const d = Math.min(dt, 0.05);

    if (this.enabled && this.locked) {
      const forward = new THREE.Vector3(-Math.sin(this.yaw), 0, -Math.cos(this.yaw));
      const right = new THREE.Vector3(Math.cos(this.yaw), 0, -Math.sin(this.yaw));
      const input = new THREE.Vector3();
      if (this.keys.has('KeyW') || this.keys.has('ArrowUp')) input.add(forward);
      if (this.keys.has('KeyS') || this.keys.has('ArrowDown')) input.sub(forward);
      if (this.keys.has('KeyD') || this.keys.has('ArrowRight')) input.add(right);
      if (this.keys.has('KeyA') || this.keys.has('ArrowLeft')) input.sub(right);
      if (input.lengthSq() > 0) input.normalize();

      const sprint = this.keys.has('ShiftLeft') || this.keys.has('ShiftRight');
      const max = sprint ? SPRINT : WALK;
      this.velocity.addScaledVector(input, ACCEL * d);
      const speed = this.velocity.length();
      if (speed > max) this.velocity.multiplyScalar(max / speed);

      this.camera.fov += ((sprint && input.lengthSq() > 0 ? 76 : 72) - this.camera.fov) * Math.min(1, d * 6);
      this.camera.updateProjectionMatrix();
    }

    // Rozamiento
    this.velocity.multiplyScalar(Math.max(0, 1 - DAMP * d));
    if (this.velocity.lengthSq() < 0.0004) this.velocity.set(0, 0, 0);

    this.moveWithCollisions(this.velocity.x * d, this.velocity.z * d);

    // Pasos y balanceo
    const speed = this.velocity.length();
    this.stepDist += speed * d;
    const stride = speed > 5.4 ? 1.55 : 1.9;
    if (this.stepDist > stride) {
      this.stepDist = 0;
      this.onStep?.(this.level.isInside(this.position) ? 'floor' : 'snow');
    }
    this.bobAmp += ((speed > 0.4 ? 1 : 0) - this.bobAmp) * Math.min(1, d * 6);
    this.bob += d * speed * 2.3;

    this.shake = Math.max(0, this.shake - d * 1.4);
    const shakeX = (Math.random() - 0.5) * this.shake * 0.05;
    const shakeY = (Math.random() - 0.5) * this.shake * 0.05;

    this.camera.position.set(
      this.position.x,
      EYE + Math.sin(this.bob) * 0.035 * this.bobAmp + shakeY,
      this.position.z,
    );
    this.camera.rotation.set(
      this.pitch + Math.sin(this.bob * 0.5) * 0.004 * this.bobAmp,
      this.yaw,
      Math.sin(this.bob) * 0.006 * this.bobAmp + shakeX,
      'YXZ',
    );
    this.flashlight.visible = this.flashlightOn;

    this.updateFocus();
  }

  private moveWithCollisions(dx: number, dz: number): void {
    const tryMove = (nx: number, nz: number): boolean => {
      // Se puede andar por cualquier emplazamiento (recinto, repetidor, origen).
      if (!this.level.isWalkable(nx, nz)) return false;
      for (const c of this.level.colliders) {
        if (this.blocked(c, nx, nz)) return false;
      }
      return true;
    };

    if (tryMove(this.position.x + dx, this.position.z)) this.position.x += dx;
    if (tryMove(this.position.x, this.position.z + dz)) this.position.z += dz;
  }

  private blocked(c: AABB, x: number, z: number): boolean {
    if (c.height < 0.25) return false;
    return (
      x > c.minX - RADIUS &&
      x < c.maxX + RADIUS &&
      z > c.minZ - RADIUS &&
      z < c.maxZ + RADIUS
    );
  }

  private updateFocus(): void {
    this.raycaster.setFromCamera(new THREE.Vector2(0, 0), this.camera);
    const hits = this.raycaster.intersectObjects(this.level.interactGroup.children, true);
    let found: Interactable | null = null;
    for (const hit of hits) {
      let obj: THREE.Object3D | null = hit.object;
      let id: string | undefined;
      while (obj && !id) {
        id = obj.userData['interact'] as string | undefined;
        obj = obj.parent;
      }
      if (!id) continue;
      const candidate = this.level.interactableAt(id);
      if (!candidate) continue;
      if (candidate.position.distanceTo(this.tmp.set(this.position.x, candidate.position.y, this.position.z)) > candidate.radius + 1.2) {
        continue;
      }
      found = candidate;
      break;
    }
    if (found?.id !== this.focus?.id) {
      this.focus = found;
      this.onFocus?.(found);
    }
  }
}
