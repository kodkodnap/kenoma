// Nivel: estación Kestrel. Geometría low-poly construida por código,
// colliders AABB y objetos interactuables para el raycast del jugador.

import * as THREE from 'three';
import type { SpawnPoint } from '../core/events';
import { TRI_STATIONS, type Station } from '../core/triangulation';
import { createMechanicalPart, type MechanicalPart } from './mechanical';
import type { Cipher, Modulation } from '../core/signals';
import type { GameState } from '../core/state';

export type ZoneName = 'kestrel' | 'repetidor' | 'origen';

export interface Zone {
  name: ZoneName;
  boundary: { minX: number; maxX: number; minZ: number; maxZ: number };
  /** Rectángulo del refugio, si lo hay: dentro se está a cubierto. */
  shelter?: { minX: number; maxX: number; minZ: number; maxZ: number };
  /** Punto de aparcamiento de la motonieve. */
  moto: { x: number; z: number };
  /** Centro del emplazamiento. */
  center: { x: number; z: number };
}

/** El repetidor está a 900 m de Kestrel, cuesta arriba. */
export const REPEATER_CENTER = { x: -900, z: 0 };
/** Radio de la zona que se abre en el origen triangulado. */
export const ORIGIN_ZONE_RADIUS = 26;

export interface AABB {
  minX: number;
  maxX: number;
  minZ: number;
  maxZ: number;
  height: number;
}

export interface Interactable {
  id: string;
  label: string;
  hint: string;
  position: THREE.Vector3;
  radius: number;
}

const PALETTE = {
  snow: 0xd3dfe6,
  snowShadow: 0xb9c8d2,
  concrete: 0x555c5f,
  wall: 0x394246,
  wallDark: 0x232a2d,
  floor: 0x272c2e,
  metal: 0x717a7e,
  darkMetal: 0x2b3235,
  rust: 0x6a4f3d,
  glass: 0x0d1a20,
  screen: 0x63e2b4,
  warning: 0xd9823f,
};

function canvasTexture(lines: string[], color = '#7dffcf', bg = '#04120d'): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 256;
  canvas.height = 128;
  const ctx = canvas.getContext('2d')!;
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.strokeRect(3, 3, canvas.width - 6, canvas.height - 6);
  ctx.fillStyle = color;
  ctx.font = '600 15px "IBM Plex Mono", monospace';
  ctx.textBaseline = 'top';
  lines.forEach((line, i) => ctx.fillText(line, 12, 12 + i * 18));
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

function updateCanvasTexture(texture: THREE.CanvasTexture, lines: string[], color: string): void {
  const canvas = texture.image as HTMLCanvasElement;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.fillStyle = '#04120d';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.strokeStyle = color;
  ctx.lineWidth = 2;
  ctx.strokeRect(3, 3, canvas.width - 6, canvas.height - 6);
  ctx.fillStyle = color;
  ctx.font = '600 15px "IBM Plex Mono", monospace';
  ctx.textBaseline = 'top';
  lines.forEach((line, i) => ctx.fillText(line, 12, 12 + i * 18));
  texture.needsUpdate = true;
}

export class Level {
  readonly group = new THREE.Group();
  readonly interactGroup = new THREE.Group();
  readonly colliders: AABB[] = [];
  readonly interactables: Interactable[] = [];
  readonly boundary = { minX: -31, maxX: 31, minZ: -25, maxZ: 25 };
  readonly spawnPoints: Record<SpawnPoint, THREE.Vector3> = {
    treeline: new THREE.Vector3(11, 0, -35),
    fence: new THREE.Vector3(-21, 0, 21),
    window: new THREE.Vector3(2.4, 0, 10.2),
    door: new THREE.Vector3(0, 0, 9.2),
    inside: new THREE.Vector3(5.4, 0, 1.2),
  };
  /** Emplazamientos transitables: el recinto, el repetidor y, si se triangula, el origen. */
  readonly zones: Zone[] = [];
  /** Mástiles del repetidor, accesibles desde su consola. */
  readonly masts: Station[] = TRI_STATIONS;

  private dishYaw = new THREE.Group();
  private dishTilt = new THREE.Group();
  private targetAz = 200;
  private targetEl = 40;
  private interiorLights: THREE.PointLight[] = [];
  private exteriorLights: THREE.SpotLight[] = [];
  private beacon: THREE.Mesh;
  private screenMats: THREE.MeshBasicMaterial[] = [];
  private machineScreens: Partial<Record<'spectrum' | 'demod' | 'decoder', THREE.CanvasTexture>> = {};
  private powered = true;
  private time = 0;
  private moto: THREE.Group | null = null;
  private motoProxy: THREE.Mesh | null = null;
  private offerProxy: THREE.Mesh | null = null;
  private offerCrate: THREE.Group | null = null;
  private originGroup: THREE.Group | null = null;
  private repeaterBeacon: THREE.Mesh | null = null;
  private spectrumDial: MechanicalPart | null = null;
  private spectrumButton: MechanicalPart | null = null;
  private demodSelector: MechanicalPart | null = null;
  private demodButton: MechanicalPart | null = null;
  private decoderSelector: MechanicalPart | null = null;
  private decoderButton: MechanicalPart | null = null;
  private machineStatusLights: Partial<Record<'spectrum' | 'demod' | 'decoder', THREE.MeshBasicMaterial>> = {};

  constructor(scene: THREE.Scene) {
    this.group.add(this.interactGroup);
    scene.add(this.group);
    this.buildGround();
    this.buildMountains();
    this.buildBuilding();
    this.buildDish();
    this.buildShed();
    this.buildTower();
    this.buildFence();
    this.buildFloodlights();
    this.buildProps();
    this.buildForest();
    this.beacon = this.buildBeacon();
    this.zones.push({
      name: 'kestrel',
      boundary: this.boundary,
      shelter: { minX: -8.8, maxX: 8.8, minZ: -6.8, maxZ: 6.8 },
      moto: { x: 10.5, z: 8.6 },
      center: { x: 0, z: 0 },
    });
    this.buildRepeaterSite();
    this.buildMoto();
    this.setDish(200, 40);
  }

  // ---------- utilidades ----------

  private mat(color: number, opts: THREE.MeshStandardMaterialParameters = {}): THREE.MeshStandardMaterial {
    return new THREE.MeshStandardMaterial({
      color,
      roughness: 0.9,
      metalness: 0.05,
      flatShading: true,
      ...opts,
    });
  }

  private box(
    w: number,
    h: number,
    d: number,
    material: THREE.Material,
    x: number,
    y: number,
    z: number,
    collide = true,
  ): THREE.Mesh {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), material);
    mesh.position.set(x, y, z);
    this.group.add(mesh);
    if (collide) {
      this.colliders.push({
        minX: x - w / 2,
        maxX: x + w / 2,
        minZ: z - d / 2,
        maxZ: z + d / 2,
        height: h,
      });
    }
    return mesh;
  }

  private addInteractable(
    id: string,
    label: string,
    hint: string,
    mesh: THREE.Object3D,
    position: THREE.Vector3,
    radius = 1.6,
  ): void {
    const proxy = new THREE.Mesh(
      new THREE.BoxGeometry(0.9, 0.9, 0.9),
      new THREE.MeshBasicMaterial({ visible: false }),
    );
    proxy.position.copy(position);
    proxy.userData['interact'] = id;
    this.interactGroup.add(proxy);
    if (mesh !== proxy) mesh.userData['interact'] = id;
    this.interactables.push({ id, label, hint, position: position.clone(), radius });
  }

  private screen(text: string[], w = 0.9, h = 0.5, color = '#7dffcf'): THREE.Mesh {
    const mat = new THREE.MeshBasicMaterial({ map: canvasTexture(text, color) });
    this.screenMats.push(mat);
    const mesh = new THREE.Mesh(new THREE.PlaneGeometry(w, h), mat);
    return mesh;
  }

  // ---------- terreno ----------

  /** Altura del terreno: plana en el recinto, ondulada fuera. */
  private groundHeight(x: number, z: number): number {
    const r = Math.hypot(x, z);
    if (r <= 38) return 0;
    const t = Math.min(1, (r - 38) / 55);
    return (Math.sin(x * 0.09) * Math.cos(z * 0.07) * 2.2 + Math.sin(x * 0.03 + z * 0.05) * 3.4) * t;
  }

  private buildGround(): void {
    const geo = new THREE.PlaneGeometry(340, 340, 72, 72);
    geo.rotateX(-Math.PI / 2);
    const pos = geo.getAttribute('position') as THREE.BufferAttribute;
    const colors: number[] = [];
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);
      pos.setY(i, this.groundHeight(x, z));
      const tint = 0.86 + Math.random() * 0.12;
      colors.push(tint, tint + 0.02, tint + 0.05);
    }
    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.computeVertexNormals();
    const mat = new THREE.MeshStandardMaterial({
      vertexColors: true,
      roughness: 0.97,
      metalness: 0,
      flatShading: false,
    });
    const ground = new THREE.Mesh(geo, mat);
    ground.receiveShadow = false;
    this.group.add(ground);

    // Pista pisada entre edificio, plato y caseta.
    const pathMat = this.mat(PALETTE.snowShadow, { roughness: 1 });
    const p1 = new THREE.Mesh(new THREE.PlaneGeometry(3.2, 13), pathMat);
    p1.rotation.x = -Math.PI / 2;
    p1.position.set(14.5, 0.02, -0.5);
    p1.rotation.z = -0.42;
    this.group.add(p1);
    const p2 = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 12), pathMat);
    p2.rotation.x = -Math.PI / 2;
    p2.rotation.z = 1.1;
    p2.position.set(-9, 0.02, -11);
    this.group.add(p2);

    // Ventisqueros.
    const driftMat = this.mat(PALETTE.snow, { roughness: 1, flatShading: true });
    for (let i = 0; i < 14; i++) {
      const a = (i / 14) * Math.PI * 2 + Math.random() * 0.3;
      const r = 36 + Math.random() * 20;
      const dx = Math.cos(a) * r;
      const dz = Math.sin(a) * r;
      const drift = new THREE.Mesh(new THREE.SphereGeometry(3 + Math.random() * 4, 7, 4), driftMat);
      drift.position.set(dx, this.groundHeight(dx, dz) - 0.6, dz);
      drift.scale.set(1.8, 0.35, 1.1);
      this.group.add(drift);
    }
  }

  private buildMountains(): void {
    const mat = this.mat(0x0b1418, { roughness: 1, flatShading: true });
    for (let i = 0; i < 14; i++) {
      const a = (i / 14) * Math.PI * 2 + 0.2;
      const r = 124 + (i % 3) * 16;
      const h = 48 + (i % 5) * 14;
      const mx = Math.cos(a) * r;
      const mz = Math.sin(a) * r;
      const m = new THREE.Mesh(new THREE.ConeGeometry(38 + (i % 4) * 10, h, 5), mat);
      m.position.set(mx, this.groundHeight(mx, mz) + h / 2 - 8, mz);
      m.rotation.y = i;
      this.group.add(m);
    }
  }

  // ---------- edificio ----------

  private buildBuilding(): void {
    const wall = this.mat(PALETTE.wall, { roughness: 0.78, metalness: 0.25 });
    const wallDark = this.mat(PALETTE.wallDark, { roughness: 0.85 });
    const floorMat = this.mat(PALETTE.floor, { roughness: 0.95 });
    const concrete = this.mat(PALETTE.concrete, { roughness: 0.95 });
    const glassMat = new THREE.MeshStandardMaterial({
      color: PALETTE.glass,
      emissive: 0x10262c,
      emissiveIntensity: 0.55,
      roughness: 0.22,
      metalness: 0.5,
      transparent: true,
      opacity: 0.82,
    });

    const W = 18;
    const D = 14;
    const H = 3.3;

    const floor = new THREE.Mesh(new THREE.PlaneGeometry(W - 0.4, D - 0.4), floorMat);
    floor.rotation.x = -Math.PI / 2;
    floor.position.y = 0.04;
    this.group.add(floor);

    // Cimientos
    this.box(W + 0.6, 0.35, D + 0.6, concrete, 0, 0.12, 0, false);

    // Muros perimetrales (con hueco de entrada al sur)
    this.box(W, H, 0.3, wall, 0, H / 2, -D / 2);
    this.box(0.3, H, D, wall, -W / 2, H / 2, 0);
    this.box(0.3, H, D, wall, W / 2, H / 2, 0);
    const doorHalf = 1.25;
    const segW = (W - doorHalf * 2) / 2;
    this.box(segW, H, 0.3, wall, -doorHalf - segW / 2, H / 2, D / 2);
    this.box(segW, H, 0.3, wall, doorHalf + segW / 2, H / 2, D / 2);
    // Dintel sobre la puerta
    this.box(doorHalf * 2, 0.7, 0.3, wallDark, 0, H - 0.35, D / 2, false);

    // Tabique interior con paso
    this.box(0.22, H, 9.5, wallDark, 1.2, H / 2, -2.25);
    this.box(0.22, H, 2.6, wallDark, 1.2, H / 2, 5.7);

    // Ventanales
    const winA = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 1.6), glassMat);
    winA.position.set(-5.6, 1.9, D / 2 - 0.18);
    this.group.add(winA);
    const winB = new THREE.Mesh(new THREE.PlaneGeometry(3.6, 1.6), glassMat);
    winB.position.set(5.6, 1.9, D / 2 - 0.18);
    this.group.add(winB);
    const winC = new THREE.Mesh(new THREE.PlaneGeometry(4.4, 1.5), glassMat);
    winC.position.set(W / 2 - 0.18, 1.95, 2.4);
    winC.rotation.y = -Math.PI / 2;
    this.group.add(winC);

    // Marcos de ventana
    const frameMat = this.mat(PALETTE.darkMetal, { metalness: 0.5, roughness: 0.5 });
    for (const x of [-5.6, 5.6]) {
      this.box(3.8, 0.12, 0.12, frameMat, x, 2.72, D / 2 + 0.02, false);
      this.box(3.8, 0.12, 0.12, frameMat, x, 1.08, D / 2 + 0.02, false);
    }

    // Techo y nieve
    this.box(W + 1, 0.3, D + 1, wallDark, 0, H + 0.15, 0, false);
    this.box(W + 1.4, 0.14, D + 1.4, this.mat(PALETTE.snow, { roughness: 1 }), 0, H + 0.37, 0, false);

    // Conductos y detalles exteriores
    const duct = this.mat(PALETTE.metal, { metalness: 0.6, roughness: 0.5 });
    this.box(0.5, 0.5, 6, duct, -6.4, H + 0.7, 1, false);
    this.box(0.5, 0.5, 0.5, duct, -6.4, H + 0.7, -2, false);
    this.box(0.35, 2.6, 0.35, duct, W / 2 + 0.2, 1.3, -4.6, false);

    // Candados y placa
    const plate = this.screen(['ESTACIÓN KESTREL', 'ACCESO RESTRINGIDO'], 1.5, 0.4, '#e0c368');
    plate.position.set(-2.6, 2.2, D / 2 + 0.16);
    this.group.add(plate);

    // Lámparas de techo
    for (const [x, z] of [
      [-4.4, -3],
      [4.8, -1.5],
      [-4.4, 3.4],
    ] as const) {
      this.box(0.5, 0.12, 0.5, this.mat(0xbfc8c4), x, H - 0.25, z, false);
      const light = new THREE.PointLight(0xffd9a8, 9, 11, 1.8);
      light.position.set(x, H - 0.45, z);
      this.interiorLights.push(light);
      this.group.add(light);
    }

    // ---------- mobiliario y máquinas ----------
    const machineBody = this.mat(0x3d4a4d, { metalness: 0.4, roughness: 0.6 });
    const machineTrim = this.mat(0x22292b, { metalness: 0.3, roughness: 0.7 });

    const machines: { id: string; label: string; hint: string; x: number; screen: string[]; color: string }[] = [
      {
        id: 'spectrum',
        label: 'Analizador de espectro',
        hint: 'Aislar la portadora',
        x: -6.9,
        screen: ['ESPECTRO', 'BANDA 1250-1680', 'ventana: —'],
        color: '#7dffcf',
      },
      {
        id: 'demod',
        label: 'Demodulador',
        hint: 'Elegir modulación',
        x: -4.2,
        screen: ['DEMOD', 'AM FM PULSO COH', 'trama: —'],
        color: '#8fd6ff',
      },
      {
        id: 'decoder',
        label: 'Decodificador de patrones',
        hint: 'Reconstruir el mensaje',
        x: -1.5,
        screen: ['PATRÓN', 'firma: —', 'glifos: ?'],
        color: '#e9b46a',
      },
    ];

    for (const m of machines) {
      const z = -6.4;
      this.box(1.4, 1.5, 0.8, machineBody, m.x, 0.75, z);
      this.box(1.5, 0.1, 0.9, machineTrim, m.x, 1.55, z, false);
      const screen = this.screen(m.screen, 0.95, 0.5, m.color);
      const screenMaterial = screen.material as THREE.MeshBasicMaterial;
      if (screenMaterial.map instanceof THREE.CanvasTexture) {
        this.machineScreens[m.id as 'spectrum' | 'demod' | 'decoder'] = screenMaterial.map;
      }
      screen.position.set(m.x, 1.12, z + 0.42);
      this.group.add(screen);
      // Teclado
      this.box(0.9, 0.06, 0.3, machineTrim, m.x, 0.86, z + 0.55, false);
      this.addInteractable(m.id, m.label, m.hint, screen, new THREE.Vector3(m.x, 1.1, z + 0.5), 1.9);
      const status = new THREE.Mesh(
        new THREE.SphereGeometry(0.055, 8, 6),
        new THREE.MeshBasicMaterial({ color: 0x6fe08a }),
      );
      status.position.set(m.x + 0.58, 1.34, z + 0.4);
      this.group.add(status);
      this.machineStatusLights[m.id as 'spectrum' | 'demod' | 'decoder'] = status.material as THREE.MeshBasicMaterial;

      if (m.id === 'spectrum') {
        const dial = new THREE.Mesh(
          new THREE.CylinderGeometry(0.16, 0.16, 0.08, 12),
          this.mat(0x687579, { metalness: 0.7, roughness: 0.38 }),
        );
        dial.rotation.x = Math.PI / 2;
        dial.position.set(m.x - 0.42, 0.99, z + 0.48);
        dial.userData['restY'] = dial.position.y;
        this.group.add(dial);
        this.spectrumDial = createMechanicalPart({
          id: 'spectrum-dial',
          object: dial,
          kind: 'dial',
          min: 1255,
          max: 1675,
          value: 1420,
        });
        this.addInteractable(
          'spectrum-dial',
          'Dial de frecuencia',
          'Abrir el analizador y ajustar la ventana',
          dial,
          dial.position,
          1.25,
        );
        const button = new THREE.Mesh(
          new THREE.CylinderGeometry(0.1, 0.1, 0.06, 10),
          this.mat(PALETTE.warning, { metalness: 0.35, roughness: 0.5 }),
        );
        button.position.set(m.x + 0.42, 0.99, z + 0.48);
        button.userData['restY'] = button.position.y;
        this.group.add(button);
        this.spectrumButton = createMechanicalPart({
          id: 'spectrum-isolate',
          object: button,
          kind: 'button',
          min: 0,
          max: 1,
          value: 0,
        });
        this.addInteractable(
          'spectrum-isolate',
          'Botón de aislamiento',
          'Aislar la portadora actual',
          button,
          button.position,
          1.1,
        );
      }
      if (m.id === 'demod') {
        const selector = new THREE.Mesh(
          new THREE.CylinderGeometry(0.14, 0.14, 0.08, 12),
          this.mat(0x68849a, { metalness: 0.65, roughness: 0.4 }),
        );
        selector.rotation.x = Math.PI / 2;
        selector.position.set(m.x - 0.42, 0.99, z + 0.48);
        this.group.add(selector);
        this.demodSelector = createMechanicalPart({
          id: 'demod-selector',
          object: selector,
          kind: 'switch',
          min: 0,
          max: 3,
          value: 0,
        });
        this.addInteractable(
          'demod-selector',
          'Selector de modulación',
          'Cambiar AM, FM, PULSO o COHERENTE',
          selector,
          selector.position,
          1.2,
        );
        const confirm = new THREE.Mesh(
          new THREE.CylinderGeometry(0.1, 0.1, 0.06, 10),
          this.mat(0x7dffcf, { metalness: 0.35, roughness: 0.5 }),
        );
        confirm.position.set(m.x + 0.42, 0.99, z + 0.48);
        confirm.userData['restY'] = confirm.position.y;
        this.group.add(confirm);
        this.demodButton = createMechanicalPart({
          id: 'demod-confirm',
          object: confirm,
          kind: 'button',
          min: 0,
          max: 1,
          value: 0,
        });
        this.addInteractable(
          'demod-confirm',
          'Confirmar demodulación',
          'Aplicar el modo seleccionado',
          confirm,
          confirm.position,
          1.1,
        );
      }
      if (m.id === 'decoder') {
        const selector = new THREE.Mesh(
          new THREE.CylinderGeometry(0.14, 0.14, 0.08, 12),
          this.mat(0xa48663, { metalness: 0.65, roughness: 0.4 }),
        );
        selector.rotation.x = Math.PI / 2;
        selector.position.set(m.x - 0.42, 0.99, z + 0.48);
        this.group.add(selector);
        this.decoderSelector = createMechanicalPart({
          id: 'decoder-selector',
          object: selector,
          kind: 'dial',
          min: 0,
          max: 3,
          value: 0,
        });
        this.addInteractable(
          'decoder-selector',
          'Selector de firma',
          'Cambiar BASE, ARMÓNICO, RECURSIVO o VACÍO',
          selector,
          selector.position,
          1.2,
        );
        const confirm = new THREE.Mesh(
          new THREE.CylinderGeometry(0.1, 0.1, 0.06, 10),
          this.mat(0xe0c368, { metalness: 0.35, roughness: 0.5 }),
        );
        confirm.position.set(m.x + 0.42, 0.99, z + 0.48);
        confirm.userData['restY'] = confirm.position.y;
        this.group.add(confirm);
        this.decoderButton = createMechanicalPart({
          id: 'decoder-confirm',
          object: confirm,
          kind: 'button',
          min: 0,
          max: 1,
          value: 0,
        });
        this.addInteractable(
          'decoder-confirm',
          'Confirmar decodificación',
          'Aplicar la firma seleccionada',
          confirm,
          confirm.position,
          1.1,
        );
      }
    }

    // Consola principal (PC)
    this.box(1.9, 0.75, 0.9, machineTrim, 5.2, 0.38, -6.2);
    this.box(1.7, 0.06, 0.7, machineBody, 5.2, 0.78, -6.2, false);
    const pcScreen = this.screen(['CONSOLA', '> kestrel.ops', 'cuota · archivo'], 1.1, 0.55, '#9ee6c9');
    pcScreen.position.set(5.2, 1.25, -6.65);
    pcScreen.rotation.x = -0.12;
    this.group.add(pcScreen);
    this.addInteractable('pc', 'Consola principal', 'Archivo, tienda y Control', pcScreen, new THREE.Vector3(5.2, 1.1, -6.2), 2.2);

    // Racks de servidores
    for (let i = 0; i < 3; i++) {
      const x = 8.1;
      const z = -4.6 + i * 1.4;
      this.box(1.1, 2.1, 1.05, machineTrim, x, 1.05, z);
      for (let led = 0; led < 4; led++) {
        const lamp = new THREE.Mesh(
          new THREE.BoxGeometry(0.06, 0.03, 0.02),
          new THREE.MeshBasicMaterial({ color: led % 2 ? 0x6fe08a : 0xe0b95a }),
        );
        lamp.position.set(x - 0.35 + led * 0.22, 1.3 + (led % 3) * 0.22, z + 0.54);
        this.group.add(lamp);
      }

    }

    // Mesa junto a la entrada
    this.box(1.6, 0.08, 0.8, this.mat(PALETTE.rust), 3.1, 0.82, 1.4);
    this.box(0.1, 0.8, 0.1, machineTrim, 2.4, 0.4, 1.1, false);
    this.box(0.1, 0.8, 0.1, machineTrim, 3.8, 0.4, 1.1, false);
    this.box(0.1, 0.8, 0.1, machineTrim, 2.4, 0.4, 1.7, false);
    this.box(0.1, 0.8, 0.1, machineTrim, 3.8, 0.4, 1.7, false);
    this.addInteractable('tape', 'Grabadora', 'Reproducir cintas', this.box(0.44, 0.16, 0.3, machineTrim, 3.2, 0.94, 1.4, false), new THREE.Vector3(3.2, 0.95, 1.4), 1.5);

    // Cafetera
    this.addInteractable(
      'coffee',
      'Cafetera',
      'Una taza (baja el estrés)',
      this.box(0.4, 0.55, 0.4, machineTrim, 2.0, 1.1, 2.2, false),
      new THREE.Vector3(2.0, 1.1, 2.2),
      1.5,
    );

    // Litera
    this.box(2.0, 0.35, 0.95, machineTrim, 6.7, 0.3, 4.9);
    this.box(1.9, 0.18, 0.85, this.mat(0x4b5a63), 6.7, 0.56, 4.9, false);
    this.box(0.7, 0.12, 0.8, this.mat(0x8a939a), 6.0, 0.68, 4.9, false);
    this.addInteractable('bed', 'Litera', 'Cerrar el turno', this.box(2.0, 0.1, 0.9, this.mat(0x39434a), 6.7, 0.7, 4.9, false), new THREE.Vector3(6.7, 0.8, 4.9), 1.8);

    // Taquillas
    for (let i = 0; i < 3; i++) {
      this.box(0.6, 2.0, 0.6, this.mat(0x46535a, { metalness: 0.4 }), 8.2, 1.0, 2.4 + i * 0.7);
    }

    // Poste de luz interior (para sombras baratas de esquina)
    this.box(2.2, 0.05, 1.2, this.mat(0x1d2326), -8.1, 0.06, 4.2, false);
  }

  setSpectrumControl(center: number): void {
    this.spectrumDial?.update(center);
  }

  getSpectrumControl(): number {
    return this.spectrumDial?.state.value ?? 1420;
  }

  nudgeSpectrumControl(delta: number): number {
    const next = this.getSpectrumControl() + delta;
    this.setSpectrumControl(next);
    return this.getSpectrumControl();
  }

  pressSpectrumButton(): void {
    this.spectrumButton?.update(1);
    this.spectrumButton?.update(0);
  }

  getDemodulation(): Modulation {
    return ['AM', 'FM', 'PULSO', 'COHERENTE'][Math.round(this.demodSelector?.state.value ?? 0)] as Modulation;
  }

  cycleDemodulation(): Modulation {
    const next = (Math.round(this.demodSelector?.state.value ?? 0) + 1) % 4;
    this.demodSelector?.update(next);
    return this.getDemodulation();
  }

  setDemodulation(modulation: Modulation): void {
    const index = ['AM', 'FM', 'PULSO', 'COHERENTE'].indexOf(modulation);
    if (index >= 0) this.demodSelector?.update(index);
  }

  pressDemodButton(): void {
    this.demodButton?.update(1);
    this.demodButton?.update(0);
  }

  getCipher(): Cipher {
    return ['BASE', 'ARMONICO', 'RECURSIVO', 'VACIO'][Math.round(this.decoderSelector?.state.value ?? 0)] as Cipher;
  }

  cycleCipher(): Cipher {
    const next = (Math.round(this.decoderSelector?.state.value ?? 0) + 1) % 4;
    this.decoderSelector?.update(next);
    return this.getCipher();
  }

  setCipher(cipher: Cipher): void {
    const index = ['BASE', 'ARMONICO', 'RECURSIVO', 'VACIO'].indexOf(cipher);
    if (index >= 0) this.decoderSelector?.update(index);
  }

  pressDecoderButton(): void {
    this.decoderButton?.update(1);
    this.decoderButton?.update(0);
  }

  // ---------- plato ----------

  private buildDish(): void {
    const pad = new THREE.Mesh(new THREE.CylinderGeometry(4.4, 4.4, 0.25, 20), this.mat(PALETTE.concrete));
    pad.position.set(18, 0.12, -13);
    this.group.add(pad);

    const steel = this.mat(PALETTE.metal, { metalness: 0.75, roughness: 0.32 });
    const dark = this.mat(PALETTE.darkMetal, { metalness: 0.4, roughness: 0.6 });

    // Pedestal alto: con elevaciones bajas el borde del plato no debe tocar la nieve.
    this.box(2.2, 3.2, 2.2, dark, 18, 1.6, -13);

    this.dishYaw = new THREE.Group();
    this.dishYaw.position.set(18, 3.6, -13);
    this.group.add(this.dishYaw);

    const yoke = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.9, 0.7), dark);
    yoke.position.y = 0.45;
    this.dishYaw.add(yoke);

    this.dishTilt = new THREE.Group();
    this.dishTilt.position.y = 1.15;
    this.dishYaw.add(this.dishTilt);

    // Casquete esférico: parábola aproximada orientada hacia +Y (concavidad arriba).
    const bowlGeo = new THREE.SphereGeometry(4.2, 28, 14, 0, Math.PI * 2, 0, 0.92);
    const bowl = new THREE.Mesh(bowlGeo, new THREE.MeshStandardMaterial({
      color: 0x9aa6a9,
      metalness: 0.65,
      roughness: 0.38,
      side: THREE.DoubleSide,
      flatShading: false,
    }));
    bowl.scale.set(1, 0.55, 1);
    this.dishTilt.add(bowl);

    // Bordes y costillas
    for (let i = 0; i < 8; i++) {
      const rib = new THREE.Mesh(new THREE.BoxGeometry(0.08, 0.18, 4.0), dark);
      const a = (i / 8) * Math.PI * 2;
      rib.position.set(Math.sin(a) * 2.1, 0.62, Math.cos(a) * 2.1);
      rib.rotation.y = a;
      rib.rotation.x = -0.32;
      this.dishTilt.add(rib);
    }

    const feed = new THREE.Mesh(new THREE.ConeGeometry(0.28, 0.85, 8), steel);
    feed.position.y = 2.1;
    feed.rotation.x = Math.PI;
    this.dishTilt.add(feed);

    for (const a of [0, 2.1, 4.2]) {
      const strut = new THREE.Mesh(new THREE.CylinderGeometry(0.035, 0.035, 2.2, 5), steel);
      strut.position.set(Math.sin(a) * 0.9, 1.2, Math.cos(a) * 0.9);
      strut.rotation.z = Math.sin(a) * 0.35;
      strut.rotation.x = Math.cos(a) * 0.35;
      this.dishTilt.add(strut);
    }

    // Terminal del plato
    const terminalBody = this.box(1.1, 1.05, 0.7, dark, 18, 0.55, -7.8);
    const termScreen = this.screen(['PLATO', 'AZ ——  EL ——', 'señal ———'], 0.8, 0.42, '#9ee6c9');
    termScreen.position.set(18, 1.12, -7.42);
    this.group.add(termScreen);
    this.box(0.9, 0.06, 0.28, this.mat(PALETTE.metal), 18, 0.78, -7.2, false);
    this.addInteractable('terminal', 'Terminal del plato', 'Apuntar y grabar', terminalBody, new THREE.Vector3(18, 1.0, -7.5), 2.0);

    // Cable enterrado hacia el edificio
    this.box(0.18, 0.06, 12, this.mat(0x151a1c), 16.2, 0.03, -4.5, false);
  }

  // ---------- caseta del generador ----------

  private buildShed(): void {
    const wall = this.mat(PALETTE.rust, { roughness: 0.95 });
    const dark = this.mat(PALETTE.wallDark);
    const x = -18;
    const z = -12;

    this.box(4.6, 2.6, 0.3, wall, x, 1.3, z - 1.7);
    this.box(0.3, 2.6, 3.4, wall, x - 2.3, 1.3, z);
    this.box(0.3, 2.6, 3.4, wall, x + 2.3, 1.3, z);
    this.box(4.8, 0.22, 3.6, dark, x, 2.7, z, false);
    this.box(4.9, 0.12, 3.7, this.mat(PALETTE.snow), x, 2.85, z, false);

    // Generador
    this.box(2.4, 1.1, 1.3, this.mat(0x3b4a3e, { metalness: 0.35 }), x - 0.4, 0.6, z - 0.2);
    const exhaust = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.09, 2.6, 6), this.mat(PALETTE.darkMetal));
    exhaust.position.set(x + 1.1, 1.7, z - 0.9);
    this.group.add(exhaust);

    // Panel del cuadro
    const panel = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.9, 0.7), dark);
    panel.position.set(x + 2.45, 1.35, z);
    this.group.add(panel);
    const lights = this.screen(['220V', 'GEN · OFF'], 0.5, 0.28, '#e0c368');
    lights.position.set(x + 2.53, 1.45, z);
    lights.rotation.y = Math.PI / 2;
    this.group.add(lights);

    this.addInteractable(
      'breaker',
      'Cuadro del generador',
      'Reiniciar corriente',
      panel,
      new THREE.Vector3(x + 2.7, 1.3, z),
      2.0,
    );
  }

  // ---------- torre de radio ----------

  private buildTower(): void {
    const steel = this.mat(0x4a5457, { metalness: 0.6, roughness: 0.45 });
    const x = -25;
    const z = 17;
    const h = 16;
    const legs: [number, number][] = [
      [-1, -1],
      [1, -1],
      [-1, 1],
      [1, 1],
    ];
    const legGeoms: THREE.BufferGeometry[] = [];
    for (const [lx, lz] of legs) {
      const a = new THREE.Vector3(x + lx * 1.1, 0, z + lz * 1.1);
      const b = new THREE.Vector3(x + lx * 0.35, h, z + lz * 0.35);
      const geo = new THREE.CylinderGeometry(0.06, 0.06, a.distanceTo(b), 4);
      geo.applyMatrix4(
        new THREE.Matrix4().makeRotationFromQuaternion(
          new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize()),
        ),
      );
      geo.translate((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);
      legGeoms.push(geo);
    }
    // Celosía
    for (let i = 0; i < 8; i++) {
      const y0 = (i / 8) * h;
      const y1 = ((i + 1) / 8) * h;
      for (const [lx, lz] of legs) {
        const a = new THREE.Vector3(x + lx * (1.1 - (y0 / h) * 0.75), y0, z + lz * (1.1 - (y0 / h) * 0.75));
        const b = new THREE.Vector3(x + lx * (1.1 - (y1 / h) * 0.75), y1, z + lz * (1.1 - (y1 / h) * 0.75));
        const geo = new THREE.CylinderGeometry(0.03, 0.03, a.distanceTo(b), 3);
        geo.applyMatrix4(
          new THREE.Matrix4().makeRotationFromQuaternion(
            new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), b.clone().sub(a).normalize()),
          ),
        );
        geo.translate((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2);
        legGeoms.push(geo);
      }
    }
    for (const geo of legGeoms) {
      this.group.add(new THREE.Mesh(geo, steel));
    }
    // Antenas de la torre
    for (let i = 0; i < 3; i++) {
      const dish = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, 0.12, 10), steel);
      dish.rotation.x = Math.PI / 2;
      dish.position.set(x + 0.9, 8 + i * 2.4, z);
      this.group.add(dish);
    }
    this.colliders.push({ minX: x - 1.4, maxX: x + 1.4, minZ: z - 1.4, maxZ: z + 1.4, height: h });
  }

  private buildBeacon(): THREE.Mesh {
    const beacon = new THREE.Mesh(
      new THREE.SphereGeometry(0.18, 8, 6),
      new THREE.MeshBasicMaterial({ color: 0xff4a3a }),
    );
    beacon.position.set(-25, 16.2, 17);
    this.group.add(beacon);
    return beacon;
  }

  // ---------- valla ----------

  private buildFence(): void {
    const postGeo = new THREE.CylinderGeometry(0.06, 0.06, 1.9, 5);
    const postMat = this.mat(0x555d5f, { metalness: 0.5, roughness: 0.6 });
    const positions: THREE.Vector3[] = [];
    const step = 4;
    for (let x = this.boundary.minX; x <= this.boundary.maxX; x += step) {
      positions.push(new THREE.Vector3(x, 0.95, this.boundary.minZ));
      positions.push(new THREE.Vector3(x, 0.95, this.boundary.maxZ));
    }
    for (let z = this.boundary.minZ + step; z < this.boundary.maxZ; z += step) {
      positions.push(new THREE.Vector3(this.boundary.minX, 0.95, z));
      positions.push(new THREE.Vector3(this.boundary.maxX, 0.95, z));
    }
    const posts = new THREE.InstancedMesh(postGeo, postMat, positions.length);
    const m = new THREE.Matrix4();
    positions.forEach((p, i) => {
      m.makeTranslation(p.x, p.y, p.z);
      posts.setMatrixAt(i, m);
    });
    posts.instanceMatrix.needsUpdate = true;
    this.group.add(posts);

    // Alambre: líneas baratas.
    const wirePoints: number[] = [];
    const rect = this.boundary;
    for (const y of [0.7, 1.35]) {
      wirePoints.push(rect.minX, y, rect.minZ, rect.maxX, y, rect.minZ);
      wirePoints.push(rect.maxX, y, rect.minZ, rect.maxX, y, rect.maxZ);
      wirePoints.push(rect.maxX, y, rect.maxZ, rect.minX, y, rect.maxZ);
      wirePoints.push(rect.minX, y, rect.maxZ, rect.minX, y, rect.minZ);
    }
    const wireGeo = new THREE.BufferGeometry();
    wireGeo.setAttribute('position', new THREE.Float32BufferAttribute(wirePoints, 3));
    this.group.add(new THREE.LineSegments(wireGeo, new THREE.LineBasicMaterial({ color: 0x394144 })));
  }

  // ---------- iluminación exterior ----------

  private buildFloodlights(): void {
    const poleMat = this.mat(0x3b4447, { metalness: 0.5 });
    const spots: [number, number, number, number][] = [
      [-13.5, 12.5, 1, -1],
      [13.5, 12.5, -1, -1],
      [-13.5, -20, 1, 1],
      [23, -4, -1, 0],
    ];
    spots.forEach(([x, z, dx, dz], index) => {
      const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.09, 0.12, 7, 6), poleMat);
      pole.position.set(x, 3.5, z);
      this.group.add(pole);
      const head = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.4, 0.5), poleMat);
      head.position.set(x, 7.1, z);
      head.rotation.y = Math.atan2(dx, dz);
      this.group.add(head);
      const bulb = new THREE.Mesh(
        new THREE.BoxGeometry(0.5, 0.2, 0.06),
        new THREE.MeshBasicMaterial({ color: 0xffe0b0 }),
      );
      bulb.position.set(x + dx * 0.28, 7.0, z + dz * 0.28);
      bulb.rotation.y = Math.atan2(dx, dz);
      this.group.add(bulb);
      this.colliders.push({ minX: x - 0.2, maxX: x + 0.2, minZ: z - 0.2, maxZ: z + 0.2, height: 7 });

      // Solo dos focos proyectan luz real (coste de fragmentos); las otras
      // torretas mantienen su lámpara emisiva como decoración.
      if (index < 2) {
        const spot = new THREE.SpotLight(0xffd7a0, 55, 42, 0.62, 0.75, 1.6);
        spot.position.set(x, 7.0, z);
        const target = new THREE.Object3D();
        target.position.set(x + dx * -14, 0, z + dz * -14);
        this.group.add(target);
        spot.target = target;
        this.exteriorLights.push(spot);
        this.group.add(spot);
      }
    });
  }

  // ---------- props ----------

  private buildProps(): void {
    const crate = this.mat(0x5a4733, { roughness: 0.95 });
    const metal = this.mat(PALETTE.darkMetal, { metalness: 0.4 });
    const positions: [number, number, number][] = [
      [-12.5, 0.45, -8.2],
      [-11.6, 0.45, -7.4],
      [-12.1, 1.1, -7.9],
      [0.8, 0.45, 10.6],
      [12.8, 0.45, 8.4],
    ];
    for (const [x, y, z] of positions) {
      const c = this.box(0.9, 0.9, 0.9, crate, x, y, z);
      c.rotation.y = Math.random() * 0.6;
    }
    // Bobinas de cable
    for (const [x, z] of [
      [8.5, -10.5],
      [9.6, -9.6],
      [-6.5, 9.8],
    ] as const) {
      const reel = new THREE.Mesh(new THREE.CylinderGeometry(0.55, 0.55, 0.35, 10), metal);
      reel.rotation.x = Math.PI / 2;
      reel.position.set(x, 0.55, z);
      this.group.add(reel);
      this.colliders.push({ minX: x - 0.55, maxX: x + 0.55, minZ: z - 0.25, maxZ: z + 0.25, height: 1.1 });
    }
    // Barriles
    for (const [x, z] of [
      [-15.4, -9.4],
      [-15.2, -8.6],
      [17.5, -20.4],
    ] as const) {
      const barrel = new THREE.Mesh(new THREE.CylinderGeometry(0.32, 0.32, 0.95, 8), metal);
      barrel.position.set(x, 0.47, z);
      this.group.add(barrel);
    }
    // Postes naranjas del camino
    const poleGeo = new THREE.CylinderGeometry(0.04, 0.04, 1.6, 5);
    const poleMat = this.mat(0xd8d0c0);
    const topMat = new THREE.MeshBasicMaterial({ color: 0xd96a2f });
    const tops: THREE.Vector3[] = [];
    const poles: THREE.Vector3[] = [];
    for (let i = 6; i < 22; i++) {
      const t = i / 22;
      poles.push(new THREE.Vector3(4 + t * 12, 0.8, 6 - t * 19));
      tops.push(new THREE.Vector3(4 + t * 12, 1.58, 6 - t * 19));
    }
    const poleMesh = new THREE.InstancedMesh(poleGeo, poleMat, poles.length);
    const topMesh = new THREE.InstancedMesh(
      new THREE.BoxGeometry(0.09, 0.22, 0.09),
      topMat,
      tops.length,
    );
    const m = new THREE.Matrix4();
    poles.forEach((p, i) => {
      m.makeTranslation(p.x, p.y, p.z);
      poleMesh.setMatrixAt(i, m);
      m.makeTranslation(tops[i]!.x, tops[i]!.y, tops[i]!.z);
      topMesh.setMatrixAt(i, m);
    });
    this.group.add(poleMesh, topMesh);
  }

  private buildForest(): void {
    const trunkGeo = new THREE.CylinderGeometry(0.16, 0.24, 2.6, 5);
    trunkGeo.translate(0, 1.3, 0);
    const trunkMat = this.mat(0x241d18, { roughness: 1 });

    const layers = [
      { r: 1.8, h: 3.4, y: 3.6 },
      { r: 1.35, h: 2.9, y: 5.2 },
      { r: 0.9, h: 2.3, y: 6.5 },
    ];
    const coneGeos = layers.map((l) => {
      const g = new THREE.ConeGeometry(l.r, l.h, 6);
      g.translate(0, l.y, 0);
      return g;
    });
    const foliageMat = this.mat(0x16211f, { roughness: 1 });

    const count = 190;
    const trunks = new THREE.InstancedMesh(trunkGeo, trunkMat, count);
    const cones = coneGeos.map((g) => new THREE.InstancedMesh(g, foliageMat, count));
    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const s = new THREE.Vector3();
    const p = new THREE.Vector3();
    let placed = 0;
    let guard = 0;
    while (placed < count && guard < 4000) {
      guard++;
      const a = Math.random() * Math.PI * 2;
      const r = 40 + Math.random() * 70;
      const x = Math.cos(a) * r;
      const z = Math.sin(a) * r;
      if (x > -30 && x < 30 && z > -26 && z < 26) continue;
      p.set(x, this.groundHeight(x, z), z);
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.random() * Math.PI);
      const scale = 0.7 + Math.random() * 0.9;
      s.set(scale, scale * (0.85 + Math.random() * 0.4), scale);
      m.compose(p, q, s);
      trunks.setMatrixAt(placed, m);
      cones.forEach((c) => c.setMatrixAt(placed, m));
      placed++;
    }
    trunks.count = placed;
    cones.forEach((c) => {
      c.count = placed;
      c.instanceMatrix.needsUpdate = true;
    });
    trunks.instanceMatrix.needsUpdate = true;
    this.group.add(trunks, ...cones);

    // Rocas
    const rockGeo = new THREE.DodecahedronGeometry(0.9, 0);
    const rocks = new THREE.InstancedMesh(rockGeo, this.mat(0x3a4244, { roughness: 1 }), 45);
    for (let i = 0; i < 45; i++) {
      const a = Math.random() * Math.PI * 2;
      const r = 34 + Math.random() * 55;
      const rx = Math.cos(a) * r;
      const rz = Math.sin(a) * r;
      p.set(rx, this.groundHeight(rx, rz) + 0.2, rz);
      q.setFromEuler(new THREE.Euler(Math.random(), Math.random(), Math.random()));
      const sc = 0.5 + Math.random() * 1.6;
      s.set(sc, sc * 0.6, sc);
      m.compose(p, q, s);
      rocks.setMatrixAt(i, m);
    }
    rocks.instanceMatrix.needsUpdate = true;
    this.group.add(rocks);
  }

  // ---------- repetidor de los 900 m (fase 2) ----------

  private repeaterGroundHeight(x: number, z: number): number {
    const r = Math.hypot(x - REPEATER_CENTER.x, z - REPEATER_CENTER.z);
    if (r <= 52) return 0;
    const t = Math.min(1, (r - 52) / 48);
    return (Math.sin(x * 0.11) * Math.cos(z * 0.09) * 3.1 + Math.sin(x * 0.037 + z * 0.061) * 4.4) * t;
  }

  private treeGeos() {
    const trunkGeo = new THREE.CylinderGeometry(0.16, 0.24, 2.6, 5);
    trunkGeo.translate(0, 1.3, 0);
    const layers = [
      { r: 1.8, h: 3.4, y: 3.6 },
      { r: 1.35, h: 2.9, y: 5.2 },
      { r: 0.9, h: 2.3, y: 6.5 },
    ];
    return {
      trunkGeo,
      coneGeos: layers.map((l) => {
        const g = new THREE.ConeGeometry(l.r, l.h, 6);
        g.translate(0, l.y, 0);
        return g;
      }),
    };
  }

  private terrainPatch(
    cx: number,
    cz: number,
    size: number,
    segments: number,
    height: (x: number, z: number) => number,
  ): void {
    const geo = new THREE.PlaneGeometry(size, size, segments, segments);
    geo.rotateX(-Math.PI / 2);
    geo.translate(cx, 0, cz);
    const pos = geo.getAttribute('position') as THREE.BufferAttribute;
    const colors: number[] = [];
    for (let i = 0; i < pos.count; i++) {
      const x = pos.getX(i);
      const z = pos.getZ(i);
      pos.setY(i, height(x, z));
      const tint = 0.85 + Math.random() * 0.11;
      colors.push(tint, tint + 0.02, tint + 0.05);
    }
    geo.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));
    geo.computeVertexNormals();
    const mesh = new THREE.Mesh(
      geo,
      new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.97, metalness: 0, flatShading: false }),
    );
    this.group.add(mesh);
  }

  private buildRepeaterSite(): void {
    const cx = REPEATER_CENTER.x;
    const cz = REPEATER_CENTER.z;
    this.terrainPatch(cx, cz, 230, 40, (x, z) => this.repeaterGroundHeight(x, z));

    // Cordillera local: sin ella el repetidor queda flotando en la niebla.
    const rock = this.mat(0x0b1418, { roughness: 1, flatShading: true });
    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * Math.PI * 2 + 0.35;
      const r = 150 + (i % 3) * 22;
      const mx = cx + Math.cos(a) * r;
      const mz = cz + Math.sin(a) * r;
      const h = 52 + (i % 4) * 16;
      const cone = new THREE.Mesh(new THREE.ConeGeometry(40 + (i % 3) * 12, h, 5), rock);
      cone.position.set(mx, this.repeaterGroundHeight(mx, mz) + h / 2 - 9, mz);
      cone.rotation.y = i * 0.7;
      this.group.add(cone);
    }

    // Refugio del repetidor.
    const hutX = cx;
    const hutZ = cz - 12;
    const wall = this.mat(PALETTE.rust, { roughness: 0.92 });
    const dark = this.mat(PALETTE.wallDark);
    const W = 7;
    const D = 4.6;
    const H = 2.7;
    this.box(W, H, 0.28, wall, hutX, H / 2, hutZ - D / 2);
    this.box(0.28, H, D, wall, hutX - W / 2, H / 2, hutZ);
    this.box(0.28, H, D, wall, hutX + W / 2, H / 2, hutZ);
    const doorHalf = 1.05;
    const segW = (W - doorHalf * 2) / 2;
    this.box(segW, H, 0.28, wall, hutX - doorHalf - segW / 2, H / 2, hutZ + D / 2);
    this.box(segW, H, 0.28, wall, hutX + doorHalf + segW / 2, H / 2, hutZ + D / 2);
    this.box(W + 0.4, 0.2, D + 0.4, dark, hutX, H + 0.1, hutZ, false);
    this.box(W + 0.6, 0.12, D + 0.6, this.mat(PALETTE.snow), hutX, H + 0.26, hutZ, false);

    // El refugio tiene su propio grupo: la corriente de Kestrel no llega aquí.
    const lamp = new THREE.PointLight(0xffd2a0, 7, 10, 1.9);
    lamp.position.set(hutX, H - 0.5, hutZ);
    this.group.add(lamp);

    // Consola de triangulación, dentro del refugio.
    const consoleBody = this.box(1.6, 0.95, 0.85, this.mat(0x35434a, { metalness: 0.4 }), hutX, 0.5, hutZ - 1.4);
    this.box(1.7, 0.08, 0.95, dark, hutX, 1.0, hutZ - 1.4, false);
    const scr = this.screen(['TRIANGULACIÓN', 'mástil A —', 'máxtil B —', 'mástil C —'], 0.95, 0.55, '#9ec7ff');
    scr.position.set(hutX, 1.45, hutZ - 1.0);
    this.group.add(scr);
    this.addInteractable('repeater', 'Consola del repetidor', 'Triangular el emisor', consoleBody, new THREE.Vector3(hutX, 1.0, hutZ - 1.1), 2.2);

    // Mástiles de medida.
    const steel = this.mat(0x586164, { metalness: 0.6, roughness: 0.45 });
    for (const st of TRI_STATIONS) {
      const mx = cx + st.offset[0];
      const mz = cz + st.offset[1];
      const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.18, 9.5, 6), steel);
      mast.position.set(mx, 4.75, mz);
      this.group.add(mast);
      const ring = new THREE.Mesh(new THREE.TorusGeometry(0.5, 0.06, 5, 10), steel);
      ring.rotation.x = Math.PI / 2;
      ring.position.set(mx, 9.1, mz);
      this.group.add(ring);
      const ant = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.34, 0.14, 10), steel);
      ant.rotation.x = Math.PI / 2;
      ant.position.set(mx, 8.4, mz + 0.3);
      this.group.add(ant);
      for (const [sx, sz] of [
        [-1.6, -1.6],
        [1.6, -1.6],
        [-1.6, 1.6],
      ] as const) {
        const stay = new THREE.Mesh(new THREE.CylinderGeometry(0.03, 0.03, 6.4, 3), steel);
        const top = new THREE.Vector3(mx, 7.4, mz);
        const base = new THREE.Vector3(mx + sx, 0.1, mz + sz);
        stay.position.copy(base.clone().add(top).multiplyScalar(0.5));
        stay.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), top.clone().sub(base).normalize());
        const len = base.distanceTo(top);
        stay.scale.set(1, len / 6.4, 1);
        this.group.add(stay);
      }
      this.colliders.push({ minX: mx - 0.3, maxX: mx + 0.3, minZ: mz - 0.3, maxZ: mz + 0.3, height: 9.5 });
    }

    // Baliza del repetidor: emite portadora, así que parpadea siempre.
    const beacon = new THREE.Mesh(
      new THREE.SphereGeometry(0.22, 8, 6),
      new THREE.MeshBasicMaterial({ color: 0xff6a4a }),
    );
    beacon.position.set(cx + TRI_STATIONS[0]!.offset[0], 9.9, cz + TRI_STATIONS[0]!.offset[1]);
    this.group.add(beacon);
    this.repeaterBeacon = beacon;

    // Combustible y trastos.
    for (const [dx, dz] of [
      [-4.2, -3.4],
      [-4.0, -2.2],
      [4.6, -1.2],
    ] as const) {
      const drum = new THREE.Mesh(new THREE.CylinderGeometry(0.34, 0.34, 1, 8), this.mat(0x3f4a44, { metalness: 0.5 }));
      drum.position.set(cx + dx, 0.5, cz + dz);
      this.group.add(drum);
      this.colliders.push({ minX: cx + dx - 0.34, maxX: cx + dx + 0.34, minZ: cz + dz - 0.34, maxZ: cz + dz + 0.34, height: 1 });
    }

    // Bosque y rocas del entorno.
    const { trunkGeo, coneGeos } = this.treeGeos();
    const count = 110;
    const trunks = new THREE.InstancedMesh(trunkGeo, this.mat(0x241d18, { roughness: 1 }), count);
    const foliage = this.mat(0x16211f, { roughness: 1 });
    const cones = coneGeos.map((g) => new THREE.InstancedMesh(g, foliage, count));
    const m = new THREE.Matrix4();
    const q = new THREE.Quaternion();
    const sc = new THREE.Vector3();
    const p = new THREE.Vector3();
    let placed = 0;
    let guard = 0;
    while (placed < count && guard < 2000) {
      guard++;
      const a = Math.random() * Math.PI * 2;
      const r = 46 + Math.random() * 80;
      const x = cx + Math.cos(a) * r;
      const z = cz + Math.sin(a) * r;
      p.set(x, this.repeaterGroundHeight(x, z), z);
      q.setFromAxisAngle(new THREE.Vector3(0, 1, 0), Math.random() * Math.PI);
      const s = 0.65 + Math.random() * 0.85;
      sc.set(s, s * (0.85 + Math.random() * 0.4), s);
      m.compose(p, q, sc);
      trunks.setMatrixAt(placed, m);
      cones.forEach((c) => c.setMatrixAt(placed, m));
      placed++;
    }
    trunks.count = placed;
    cones.forEach((c) => {
      c.count = placed;
      c.instanceMatrix.needsUpdate = true;
    });
    trunks.instanceMatrix.needsUpdate = true;
    this.group.add(trunks, ...cones);

    this.zones.push({
      name: 'repetidor',
      boundary: { minX: cx - 42, maxX: cx + 42, minZ: cz - 36, maxZ: cz + 36 },
      shelter: { minX: hutX - 3.2, maxX: hutX + 3.2, minZ: hutZ - 2.3, maxZ: hutZ + 2.3 },
      moto: { x: cx + 7, z: cz + 3 },
      center: { x: cx, z: cz },
    });
  }

  private buildMoto(): void {
    const g = new THREE.Group();
    const body = new THREE.Mesh(new THREE.BoxGeometry(0.85, 0.45, 2.3), this.mat(0x8e3223, { roughness: 0.65 }));
    body.position.y = 0.55;
    g.add(body);
    const seat = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.18, 0.95), this.mat(0x1d2225));
    seat.position.set(0, 0.82, -0.3);
    g.add(seat);
    const wind = new THREE.Mesh(
      new THREE.BoxGeometry(0.72, 0.52, 0.05),
      new THREE.MeshStandardMaterial({ color: 0x9fc6d6, transparent: true, opacity: 0.32, roughness: 0.2, metalness: 0.3 }),
    );
    wind.position.set(0, 1.02, 0.72);
    wind.rotation.x = -0.26;
    g.add(wind);
    const track = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.32, 1.25), this.mat(0x14181a));
    track.position.set(0, 0.3, -0.9);
    g.add(track);
    for (const s of [-1, 1]) {
      const ski = new THREE.Mesh(new THREE.BoxGeometry(0.22, 0.09, 1.15), this.mat(0x2b3235));
      ski.position.set(s * 0.3, 0.14, 1);
      g.add(ski);
    }
    const lamp = new THREE.Mesh(new THREE.BoxGeometry(0.26, 0.16, 0.07), new THREE.MeshBasicMaterial({ color: 0xffe9c0 }));
    lamp.position.set(0, 0.85, 1.18);
    g.add(lamp);
    this.group.add(g);
    this.moto = g;

    const proxy = new THREE.Mesh(new THREE.BoxGeometry(1.6, 1.3, 2.6), new THREE.MeshBasicMaterial({ visible: false }));
    proxy.userData['interact'] = 'moto';
    this.interactGroup.add(proxy);
    this.motoProxy = proxy;
    this.interactables.push({
      id: 'moto',
      label: 'Motonieve',
      hint: 'Salir del recinto',
      position: new THREE.Vector3(),
      radius: 2.6,
    });
    this.placeMoto('kestrel');
  }

  /** Aparca la motonieve en el emplazamiento indicado (mueve malla e interactuable). */
  placeMoto(zone: ZoneName): void {
    const z = this.zones.find((zz) => zz.name === zone) ?? this.zones[0]!;
    const mx = z.moto.x;
    const mz = z.moto.z;
    if (this.moto) {
      this.moto.position.set(mx, 0, mz);
      this.moto.rotation.y = zone === 'kestrel' ? -0.55 : 2.15;
    }
    if (this.motoProxy) this.motoProxy.position.set(mx, 0.7, mz);
    const def = this.interactables.find((i) => i.id === 'moto');
    if (def) {
      def.position.set(mx, 0.7, mz);
      def.hint = zone === 'kestrel' ? 'Salir del recinto' : 'Volver a Kestrel';
    }
  }

  /** Abre la zona del origen triangulado y deja los restos que hay que registrar. */
  setOrigin(x: number, z: number): void {
    this.clearOrigin();
    const g = new THREE.Group();
    const crater = new THREE.Mesh(
      new THREE.ConeGeometry(5.4, 1.6, 9, 1, true),
      this.mat(0x1a2126, { roughness: 1, flatShading: true }),
    );
    crater.position.y = -0.55;
    crater.rotation.y = 0.4;
    g.add(crater);
    const ash = new THREE.Mesh(new THREE.CircleGeometry(5.2, 16), this.mat(0x0e1418, { roughness: 1 }));
    ash.rotation.x = -Math.PI / 2;
    ash.position.y = 0.02;
    g.add(ash);
    for (let i = 0; i < 3; i++) {
      const a = (i / 3) * Math.PI * 2 + 0.6;
      const stone = new THREE.Mesh(new THREE.DodecahedronGeometry(0.7, 0), this.mat(0x3a4244, { roughness: 1 }));
      stone.position.set(Math.cos(a) * 4.4, 0.3, Math.sin(a) * 4.4);
      stone.scale.set(1, 1.6, 0.8);
      g.add(stone);
    }
    const stake = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.06, 2.1, 5), this.mat(0x6a4f3d));
    stake.position.set(0, 1.05, 0);
    g.add(stake);
    const marker = new THREE.Mesh(new THREE.SphereGeometry(0.14, 8, 6), new THREE.MeshBasicMaterial({ color: 0xff5a44 }));
    marker.position.set(0, 2.15, 0);
    g.add(marker);
    g.position.set(x, 0, z);
    this.group.add(g);
    this.originGroup = g;

    this.terrainPatch(x, z, 110, 20, () => 0);

    const probe = this.box(0.9, 0.6, 0.9, this.mat(0x2f383c, { metalness: 0.35 }), x + 2.2, 0.3, z - 1.6);
    this.addInteractable('origen', 'Restos del emisor', 'Registrar el origen', probe, new THREE.Vector3(x + 2.2, 0.7, z - 1.6), 2.4);

    this.zones.push({
      name: 'origen',
      boundary: {
        minX: x - ORIGIN_ZONE_RADIUS,
        maxX: x + ORIGIN_ZONE_RADIUS,
        minZ: z - ORIGIN_ZONE_RADIUS,
        maxZ: z + ORIGIN_ZONE_RADIUS,
      },
      moto: { x: x + 8, z: z + 4 },
      center: { x, z },
    });
  }

  clearOrigin(): void {
    if (this.originGroup) {
      this.group.remove(this.originGroup);
      this.originGroup = null;
    }
    const index = this.zones.findIndex((z) => z.name === 'origen');
    if (index >= 0) this.zones.splice(index, 1);
    const probeIndex = this.interactables.findIndex((i) => i.id === 'origen');
    if (probeIndex >= 0) {
      this.interactables.splice(probeIndex, 1);
      for (let i = this.interactGroup.children.length - 1; i >= 0; i--) {
        const child = this.interactGroup.children[i]!;
        if (child.userData['interact'] === 'origen') this.interactGroup.remove(child);
      }
    }
  }

  hasOriginZone(): boolean {
    return this.zones.some((z) => z.name === 'origen');
  }

  /** Cajón de trueque del comerciante, en el porche del emplazamiento activo. */
  showOffer(zone: ZoneName): void {
    this.hideOffer();
    const z = this.zones.find((zz) => zz.name === zone) ?? this.zones[0]!;
    const spot =
      zone === 'kestrel'
        ? { x: 0, z: 10.6 }
        : zone === 'repetidor'
          ? { x: z.center.x, z: z.center.z - 8.4 }
          : { x: z.center.x + 7, z: z.center.z + 5 };

    const g = new THREE.Group();
    const crate = new THREE.Mesh(new THREE.BoxGeometry(0.56, 0.5, 0.46), this.mat(0x5a4733, { roughness: 0.95 }));
    crate.position.y = 0.26;
    g.add(crate);
    const sheet = new THREE.Mesh(new THREE.PlaneGeometry(0.3, 0.22), new THREE.MeshBasicMaterial({ color: 0xd9d2c0 }));
    sheet.rotation.x = -Math.PI / 2;
    sheet.position.y = 0.52;
    g.add(sheet);
    const lamp = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.06, 0.1), new THREE.MeshBasicMaterial({ color: 0xff6a4a }));
    lamp.position.set(0.2, 0.56, 0.14);
    g.add(lamp);
    g.position.set(spot.x, 0, spot.z);
    this.group.add(g);
    this.offerCrate = g;

    const proxy = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1, 1.2), new THREE.MeshBasicMaterial({ visible: false }));
    proxy.position.set(spot.x, 0.5, spot.z);
    proxy.userData['interact'] = 'trueque';
    this.interactGroup.add(proxy);
    this.offerProxy = proxy;
    this.interactables.push({
      id: 'trueque',
      label: 'Cajón del trueque',
      hint: 'Cambiar una captura',
      position: new THREE.Vector3(spot.x, 0.6, spot.z),
      radius: 2.4,
    });
  }

  hideOffer(): void {
    if (this.offerCrate) {
      this.group.remove(this.offerCrate);
      this.offerCrate = null;
    }
    if (this.offerProxy) {
      this.interactGroup.remove(this.offerProxy);
      this.offerProxy = null;
    }
    const index = this.interactables.findIndex((i) => i.id === 'trueque');
    if (index >= 0) this.interactables.splice(index, 1);
  }

  /** Zona en la que está el jugador: la que contiene el punto o la más cercana. */
  zoneAt(pos: THREE.Vector3): ZoneName {
    for (const z of this.zones) {
      const b = z.boundary;
      if (pos.x > b.minX - 6 && pos.x < b.maxX + 6 && pos.z > b.minZ - 6 && pos.z < b.maxZ + 6) return z.name;
    }
    let best: ZoneName = 'kestrel';
    let bestDist = Infinity;
    for (const z of this.zones) {
      const d = Math.hypot(pos.x - z.center.x, pos.z - z.center.z);
      if (d < bestDist) {
        bestDist = d;
        best = z.name;
      }
    }
    return best;
  }

  /** ¿Es caminable el punto? Vale cualquier emplazamiento. */
  isWalkable(x: number, z: number): boolean {
    for (const zone of this.zones) {
      const b = zone.boundary;
      if (x > b.minX + 0.6 && x < b.maxX - 0.6 && z > b.minZ + 0.6 && z < b.maxZ - 0.6) return true;
    }
    return false;
  }

  /** Puntos de aparición de contactos, relativos al emplazamiento activo. */
  spawnPointsFor(zone: ZoneName): Record<SpawnPoint, THREE.Vector3> {
    const z = this.zones.find((zz) => zz.name === zone);
    if (!z || zone === 'kestrel') return this.spawnPoints;
    const cx = z.center.x;
    const cz = z.center.z;
    return {
      treeline: new THREE.Vector3(cx + 30, 0, cz + 24),
      fence: new THREE.Vector3(cx - 26, 0, cz + 14),
      window: new THREE.Vector3(cx + 2.6, 0, cz - 8.6),
      door: new THREE.Vector3(cx, 0, cz - 9.2),
      inside: new THREE.Vector3(cx + 0.8, 0, cz - 12),
    };
  }

  /** Posición de un mástil de medida, en coordenadas de mundo. */
  mastPosition(index: number): THREE.Vector3 {
    const st = TRI_STATIONS[Math.max(0, Math.min(TRI_STATIONS.length - 1, index))]!;
    return new THREE.Vector3(REPEATER_CENTER.x + st.offset[0], 0, REPEATER_CENTER.z + st.offset[1]);
  }

  // ---------- API ----------

  setDish(az: number, el: number): void {
    this.targetAz = az;
    this.targetEl = Math.max(0, Math.min(88, el));
    this.dishYaw.rotation.y = THREE.MathUtils.degToRad(this.targetAz);
    this.dishTilt.rotation.x = THREE.MathUtils.degToRad(90 - this.targetEl);
  }

  /** Movimiento suave hacia el objetivo (para los motores del evento). */
  aimDish(az: number, el: number): void {
    this.targetAz = az;
    this.targetEl = Math.max(0, Math.min(88, el));
  }

  update(dt: number, power: boolean): void {
    this.time += dt;
    if (power !== this.powered) this.setPower(power);

    // Los motores girman suave hacia el objetivo.
    const currentYaw = THREE.MathUtils.radToDeg(this.dishYaw.rotation.y);
    const diff = ((this.targetAz - currentYaw + 540) % 360) - 180;
    if (Math.abs(diff) > 0.05) {
      this.dishYaw.rotation.y += THREE.MathUtils.degToRad(diff) * Math.min(1, dt * 1.8);
    }
    const targetTilt = THREE.MathUtils.degToRad(90 - this.targetEl);
    this.dishTilt.rotation.x += (targetTilt - this.dishTilt.rotation.x) * Math.min(1, dt * 1.6);

    this.beacon.visible = power && Math.sin(this.time * 2.4) > 0;
    if (this.repeaterBeacon) this.repeaterBeacon.visible = Math.sin(this.time * 1.6) > -0.2;
    for (let i = 0; i < this.screenMats.length; i++) {
      const mat = this.screenMats[i]!;
      const flicker = power ? 1 : 0.08;
      mat.color.setScalar(0.55 + 0.45 * flicker * (0.9 + Math.sin(this.time * 3 + i) * 0.1));
    }
    this.updateMachineStatus(power);
  }

  setMachineFaults(faults: Partial<Record<'spectrum' | 'demod' | 'decoder', boolean>>): void {
    for (const id of ['spectrum', 'demod', 'decoder'] as const) {
      const material = this.machineStatusLights[id];
      if (material) material.userData['fault'] = faults[id] === true;
    }
  }

  setMachineDisplays(state: GameState): void {
    const raw = state.captures.filter((capture) => !capture.sold && capture.stage === 0).length;
    const isolated = state.captures.filter((capture) => !capture.sold && capture.stage === 1).length;
    const demodulated = state.captures.filter((capture) => !capture.sold && capture.stage === 2).length;
    updateCanvasTexture(this.machineScreens.spectrum!, [
      'ESPECTRO',
      this.powered ? `CRUDA: ${raw}` : 'SIN CORRIENTE',
      this.powered ? 'VENTANA: ACTIVA' : 'SA-9 · OFF',
    ], '#7dffcf');
    updateCanvasTexture(this.machineScreens.demod!, [
      'DEMOD',
      this.powered ? `AISLADA: ${isolated}` : 'SIN CORRIENTE',
      this.powered ? 'MODO: LISTO' : 'DM-4 · OFF',
    ], '#8fd6ff');
    updateCanvasTexture(this.machineScreens.decoder!, [
      'PATRÓN',
      this.powered ? `DEMOD: ${demodulated}` : 'SIN CORRIENTE',
      this.powered ? 'FIRMA: ESPERA' : 'PD-2 · OFF',
    ], '#e9b46a');
  }

  private updateMachineStatus(power: boolean): void {
    for (const id of ['spectrum', 'demod', 'decoder'] as const) {
      const material = this.machineStatusLights[id];
      if (!material) continue;
      const fault = material.userData['fault'] === true;
      if (!power) {
        material.color.setHex(0x26302d);
      } else if (fault) {
        material.color.setHex(Math.sin(this.time * 7) > 0 ? 0xff4b3e : 0x4b1715);
      } else {
        material.color.setHex(0x6fe08a);
      }
    }
  }

  setPower(on: boolean): void {
    this.powered = on;
    for (const l of this.interiorLights) l.intensity = on ? 9 : 0.5;
    for (const s of this.exteriorLights) s.intensity = on ? 55 : 0;
  }

  isInside(pos: THREE.Vector3): boolean {
    for (const zone of this.zones) {
      const s = zone.shelter;
      if (!s) continue;
      if (pos.x > s.minX && pos.x < s.maxX && pos.z > s.minZ && pos.z < s.maxZ) return true;
    }
    return false;
  }

  isNearLight(pos: THREE.Vector3): boolean {
    if (this.isInside(pos)) return this.powered;
    for (const spot of this.exteriorLights) {
      if (!this.powered) return false;
      if (spot.position.distanceTo(pos) < 15) return true;
    }
    return false;
  }

  interactableAt(id: string): Interactable | undefined {
    return this.interactables.find((i) => i.id === id);
  }
}
