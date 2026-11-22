// Escena base: renderer, cámara, cielo, estrellas, nieve y ajuste de calidad.
// Objetivo: arranque rápido y 60 fps estables (sin shadow maps, pocas luces).

import * as THREE from 'three';
import { WEATHER_INFO, type WeatherKind } from '../core/weather';

export type Quality = 'alta' | 'media' | 'baja';

const BASE_FOG = 0.0105;
const MOON_OFFSET = new THREE.Vector3(115, 96, -170);

const SKY_VERT = /* glsl */ `
  varying vec3 vDir;
  void main() {
    vDir = normalize(position);
    vec4 mv = modelViewMatrix * vec4(position, 1.0);
    gl_Position = projectionMatrix * mv;
  }
`;

const SKY_FRAG = /* glsl */ `
  precision mediump float;
  varying vec3 vDir;
  uniform vec3 uTop;
  uniform vec3 uHorizon;
  uniform vec3 uGlow;
  uniform float uTime;

  float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
  }

  void main() {
    float h = clamp(vDir.y * 1.15 + 0.12, 0.0, 1.0);
    vec3 col = mix(uHorizon, uTop, pow(h, 0.62));

    // Banda tenue sobre la cordillera, como aire cargado.
    float band = exp(-pow((vDir.y - 0.06) * 5.5, 2.0));
    float ripple = 0.55 + 0.45 * sin(vDir.x * 6.0 + uTime * 0.05) * sin(vDir.z * 4.0 - uTime * 0.03);
    col += uGlow * band * ripple * 0.20;

    // Grano muy leve para que el degradado no se vea por bandas.
    col += (hash(gl_FragCoord.xy) - 0.5) * 0.012;
    gl_FragColor = vec4(col, 1.0);
  }
`;

function snowTexture(): THREE.Texture {
  const size = 32;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  const g = ctx.createRadialGradient(size / 2, size / 2, 0, size / 2, size / 2, size / 2);
  g.addColorStop(0, 'rgba(255,255,255,1)');
  g.addColorStop(0.45, 'rgba(230,245,255,0.75)');
  g.addColorStop(1, 'rgba(255,255,255,0)');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const tex = new THREE.CanvasTexture(canvas);
  tex.colorSpace = THREE.SRGBColorSpace;
  return tex;
}

export class WorldScene {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene: THREE.Scene;
  readonly camera: THREE.PerspectiveCamera;
  readonly moonLight: THREE.DirectionalLight;
  readonly hemi: THREE.HemisphereLight;
  private skyMat: THREE.ShaderMaterial;
  private stars: THREE.Points;
  private snow: THREE.Points;
  private snowPositions: Float32Array;
  private snowVel: Float32Array;
  private snowTexture: THREE.Texture;
  private skyMesh: THREE.Mesh;
  private moonMesh: THREE.Mesh;
  private snowMat: THREE.PointsMaterial;
  private starMat: THREE.PointsMaterial;
  private basePixelRatio: number;
  private quality: Quality = 'alta';
  private frameTimes: number[] = [];
  private cooldown = 0;
  private elapsed = 0;
  private weather: WeatherKind = 'clara';
  private weatherAmount = 0;
  private snowSpeed = 1;
  private windDrift = 1;
  private flashBoost = 0;
  private nextBolt = 0;

  constructor(canvas: HTMLCanvasElement) {
    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      powerPreference: 'high-performance',
      stencil: false,
    });
    this.renderer.setClearColor(0x070c10, 1);
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping;
    this.renderer.toneMappingExposure = 1.15;

    this.scene = new THREE.Scene();
    this.scene.fog = new THREE.FogExp2(0x0a141a, 0.0105);

    this.camera = new THREE.PerspectiveCamera(72, 1, 0.08, 420);
    this.camera.position.set(0, 1.7, 12);

    this.hemi = new THREE.HemisphereLight(0x5a7f9c, 0x0b1116, 0.42);
    this.scene.add(this.hemi);

    this.moonLight = new THREE.DirectionalLight(0xa8c6ff, 0.85);
    this.moonLight.position.set(-60, 90, -40);
    this.scene.add(this.moonLight);

    // Cielo
    this.skyMat = new THREE.ShaderMaterial({
      vertexShader: SKY_VERT,
      fragmentShader: SKY_FRAG,
      side: THREE.BackSide,
      depthWrite: false,
      fog: false,
      uniforms: {
        uTop: { value: new THREE.Color(0x04070d) },
        uHorizon: { value: new THREE.Color(0x18262c) },
        uGlow: { value: new THREE.Color(0x3c7d72) },
        uTime: { value: 0 },
      },
    });
    this.skyMesh = new THREE.Mesh(new THREE.SphereGeometry(320, 24, 16), this.skyMat);
    this.scene.add(this.skyMesh);

    // Luna
    this.moonMesh = new THREE.Mesh(
      new THREE.CircleGeometry(7.5, 32),
      new THREE.MeshBasicMaterial({ color: 0xdbe8f5, fog: false }),
    );
    this.moonMesh.position.copy(MOON_OFFSET);
    this.moonMesh.lookAt(0, 0, 0);
    this.scene.add(this.moonMesh);

    // Estrellas
    const starGeo = new THREE.BufferGeometry();
    const starCount = 2200;
    const starPos = new Float32Array(starCount * 3);
    for (let i = 0; i < starCount; i++) {
      const v = new THREE.Vector3().randomDirection().multiplyScalar(300);
      v.y = Math.abs(v.y) * 0.85 + 18;
      starPos.set([v.x, v.y, v.z], i * 3);
    }
    starGeo.setAttribute('position', new THREE.BufferAttribute(starPos, 3));
    this.starMat = new THREE.PointsMaterial({
      color: 0xc9dcff,
      size: 1.5,
      sizeAttenuation: false,
      transparent: true,
      opacity: 0.85,
      depthWrite: false,
      fog: false,
    });
    this.stars = new THREE.Points(starGeo, this.starMat);
    this.scene.add(this.stars);

    // Nieve: se recicla alrededor de la cámara.
    this.snowTexture = snowTexture();
    const snowCount = 2200;
    this.snowPositions = new Float32Array(snowCount * 3);
    this.snowVel = new Float32Array(snowCount * 2);
    for (let i = 0; i < snowCount; i++) {
      this.snowPositions.set(
        [THREE.MathUtils.randFloatSpread(70), THREE.MathUtils.randFloat(0, 26), THREE.MathUtils.randFloatSpread(70)],
        i * 3,
      );
      this.snowVel.set([THREE.MathUtils.randFloat(0.5, 1.8), THREE.MathUtils.randFloat(0.2, 1.1)], i * 2);
    }
    const snowGeo = new THREE.BufferGeometry();
    snowGeo.setAttribute('position', new THREE.BufferAttribute(this.snowPositions, 3));
    this.snowMat = new THREE.PointsMaterial({
      map: this.snowTexture,
      color: 0xd9ecff,
      size: 0.13,
      transparent: true,
      opacity: 0.75,
      depthWrite: false,
      sizeAttenuation: true,
    });
    this.snow = new THREE.Points(snowGeo, this.snowMat);
    this.snow.frustumCulled = false;
    this.scene.add(this.snow);

    this.basePixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);
    this.resize();
    window.addEventListener('resize', () => this.resize());
  }

  applyQuality(q: Quality): void {
    this.quality = q;
    const ratio = q === 'alta' ? 1.5 : q === 'media' ? 1.1 : 0.8;
    this.basePixelRatio = Math.min(window.devicePixelRatio || 1, ratio);
    this.renderer.setPixelRatio(this.basePixelRatio);
    this.snow.visible = q !== 'baja';
    this.applyLighting();
    this.resize();
  }

  /** Luz base según calidad y clima (la niebla tapada obliga a subir el hemi). */
  private applyLighting(): void {
    const base = this.quality === 'baja' ? 0.5 : 0.42;
    const dim = 1 - 0.28 * this.weatherAmount;
    this.hemi.intensity = base * dim + this.flashBoost * 1.6;
    this.moonLight.intensity = 0.85 * dim + this.flashBoost * 2.2;
  }

  /**
   * Clima del valle: niebla, densidad de nieve, viento y descargas. La ventisca
   * reduce la visibilidad a un puñado de metros; la tormenta añade relámpagos.
   */
  setWeather(kind: WeatherKind, intensity: number): void {
    this.weather = kind;
    this.weatherAmount = Math.max(0, Math.min(1, intensity));
    const info = WEATHER_INFO[kind];
    const t = this.weatherAmount;
    const fog = this.scene.fog as THREE.FogExp2 | null;
    if (fog) fog.density = BASE_FOG * (1 + (1 - info.visibility) * 2.1 * t);
    this.snowSpeed = info.snow * (0.55 + t * 0.85);
    this.windDrift = info.wind * (0.4 + t);
    this.snowMat.opacity = Math.min(0.95, 0.4 + info.snow * 0.28 * (0.6 + t));
    this.snowMat.size = 0.11 + info.snow * 0.035 * t;
    if (this.starMat) this.starMat.opacity = 0.85 * (1 - 0.8 * t * (1 - info.visibility));
    this.applyLighting();
  }

  resize(): void {
    const w = window.innerWidth;
    const h = window.innerHeight;
    this.renderer.setSize(w, h, false);
    this.camera.aspect = w / Math.max(1, h);
    this.camera.updateProjectionMatrix();
  }

  /** Baja resolución si el equipo no sostiene 60 fps. Nunca sube de golpe. */
  adapt(dt: number): void {
    this.frameTimes.push(dt);
    if (this.frameTimes.length > 90) this.frameTimes.shift();
    this.cooldown -= dt;
    if (this.cooldown > 0 || this.frameTimes.length < 45) return;
    const avg = this.frameTimes.reduce((a, b) => a + b, 0) / this.frameTimes.length;
    if (avg > 1 / 48 && this.quality !== 'baja') {
      this.applyQuality('baja');
      this.cooldown = 12;
    } else if (avg > 1 / 55 && this.quality === 'alta') {
      this.applyQuality('media');
      this.cooldown = 8;
    }
  }

  update(dt: number, camera: THREE.Camera): void {
    this.elapsed += dt;
    this.skyMat.uniforms['uTime']!.value = this.elapsed;
    this.stars.rotation.y += dt * 0.0025;

    // El cielo, la luna y las estrellas siguen a la cámara: el mundo pasa de
    // 62 m a 900 m sin cambiar la esfera del firmamento.
    this.skyMesh.position.copy(camera.position);
    this.stars.position.copy(camera.position);
    this.moonMesh.position.copy(camera.position).add(MOON_OFFSET);
    this.moonMesh.lookAt(camera.position);

    // Relámpagos de tormenta: luz puntual muy breve, sin coste de geometría.
    if (this.flashBoost > 0) {
      this.flashBoost = Math.max(0, this.flashBoost - dt * 4);
      this.applyLighting();
    } else if (this.weather === 'tormenta') {
      this.nextBolt -= dt;
      if (this.nextBolt <= 0) {
        this.nextBolt = 6 + Math.random() * 22;
        this.flashBoost = 0.35 + this.weatherAmount * 0.5;
        this.applyLighting();
      }
    }

    const positions = this.snow.geometry.getAttribute('position') as THREE.BufferAttribute;
    const arr = positions.array as Float32Array;
    const cx = camera.position.x;
    const cz = camera.position.z;
    for (let i = 0; i < arr.length; i += 3) {
      const vi = (i / 3) * 2;
      arr[i + 1]! -= this.snowVel[vi]! * dt * 1.6 * this.snowSpeed;
      arr[i]! += Math.sin(this.elapsed * 0.4 + i) * dt * 0.35 + this.snowVel[vi + 1]! * dt * 0.4 + this.windDrift * dt * 0.55;
      arr[i + 2]! -= dt * 0.25 * this.snowSpeed;
      if (arr[i + 1]! < -0.5) {
        arr[i] = cx + THREE.MathUtils.randFloatSpread(70);
        arr[i + 1] = 24;
        arr[i + 2] = cz + THREE.MathUtils.randFloatSpread(70);
      }
      // Reencuadre horizontal para que la nieve siga al jugador.
      if (arr[i]! - cx > 35) arr[i]! -= 70;
      if (arr[i]! - cx < -35) arr[i]! += 70;
      if (arr[i + 2]! - cz > 35) arr[i + 2]! -= 70;
      if (arr[i + 2]! - cz < -35) arr[i + 2]! += 70;
    }
    positions.needsUpdate = true;
  }

  render(): void {
    this.renderer.render(this.scene, this.camera);
  }
}
