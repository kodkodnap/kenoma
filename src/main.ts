import './styles.css';
import * as THREE from 'three';

import { AudioEngine } from './audio/audio';
import {
  activeCaptures,
  archiveCapture,
  buyUpgrade,
  capacity,
  coffeeGain,
  level,
  sellCapture,
  tradeCapture,
  tradeOffer,
} from './core/economy';
import {
  breakMachine,
  buyPart,
  calibrate as calibrateMachine,
  machineBroken,
  machineDef,
  repairWithPart,
  type MachineId,
} from './core/faults';
import { recordRoutine } from './core/routine';
import type { DecisionPrompt, EndingId, ShiftSummary } from './core/sim';
import { REPEATER_DAY, Sim } from './core/sim';
import {
  bearingBetween,
  bearingQuality,
  intersectBearings,
  planarDistance,
  stationWorld,
  TRI_LOCK,
  TRI_STATIONS,
  triTarget,
  type Bearing,
} from './core/triangulation';
import { makeWeather, weatherLabel, weatherNoise, WEATHER_INFO, type WeatherKind } from './core/weather';
import type { EventHost } from './core/events';
import type { EntityKind } from './core/events';
import { Rng } from './core/rng';
import {
  CLASS_INFO,
  STAGE,
  generateSources,
  isolateBand,
  makeCapture,
  signalStrength,
  syntheticSource,
  demodulate as demodSignal,
  tryDecode,
} from './core/signals';
import type { Capture, Cipher, Modulation, SignalClass, SignalSource } from './core/signals';
import {
  addStress,
  clearSave,
  createNewState,
  dayBriefing,
  loadGame,
  log,
  markTaskProgress,
  saveGame,
  GameState,
} from './core/state';
import { clockLabel } from './core/time';
import { Hud } from './ui/hud';
import { Panels } from './ui/panels';
import type {
  ActionResult,
  DishTelemetry,
  GameApi,
  SkyBlip,
  ToastKind,
  TradeView,
  TravelDest,
  TravelOption,
  TriTelemetry,
} from './ui/types';
import { EntityManager } from './world/entities';
import type { Entity } from './world/entities';
import { Level, REPEATER_CENTER, type ZoneName } from './world/level';
import { Player } from './world/player';
import { WorldScene } from './world/scene';

const SWEEP_SPEED = 8;
const RECORD_SECONDS = 12;
const LOCK_STRENGTH = 45;
/** Segundos reales de cada trayecto en motonieve. */
const TRAVEL_SECONDS = 14;

/** Punto de llegada de la motonieve, según el emplazamiento. */
function arrivalFor(dest: TravelDest, originX: number, originZ: number): { x: number; z: number } {
  switch (dest) {
    case 'kestrel':
      return { x: 11.8, z: 10.4 };
    case 'repetidor':
      return { x: REPEATER_CENTER.x + 8.4, z: REPEATER_CENTER.z + 4.6 };
    case 'origen':
      return { x: originX + 6.6, z: originZ + 5.6 };
  }
}

class Game implements GameApi {
  state: GameState;
  sim!: Sim;
  readonly dish: DishTelemetry = {
    az: 200,
    el: 40,
    strength: 0,
    sourceLabel: null,
    locked: false,
    recording: false,
    progress: 0,
    sweeping: false,
    noise: 0,
  };
  sources: SignalSource[] = [];
  /** Medida de rumbo de cada mástil del repetidor. */
  masts = TRI_STATIONS.map(() => ({ aim: 0, quality: 0, locked: false }));
  /** Origen localizado por triangulación, si lo hay. */
  triFixed: {
    x: number;
    z: number;
    spread: number;
    distance: number;
    name: string;
    klass: SignalClass;
    /** Distancia entre la medida y el emisor real: mide la puntería. */
    error: number;
  } | null = null;

  private world: WorldScene;
  private level: Level;
  private player: Player;
  private entities: EntityManager;
  private audio = new AudioEngine();
  private hud: Hud;
  private panels!: Panels;
  private simHooks = {
    onNewShift: (day: number) => this.onNewShift(day),
    onShiftSummary: (summary: ShiftSummary) => this.onShiftSummary(summary),
    onEnding: (ending: EndingId) => this.onEnding(ending),
    onDecision: (prompt: DecisionPrompt) => this.onDecision(prompt),
  };
  private trip: { dest: TravelDest; t: number; duration: number; label: string } | null = null;
  private routineTimer = 0;
  private weatherKey = '';
  private selectedId: string | null = null;
  private recording: { source: SignalSource; elapsed: number; sum: number; samples: number } | null = null;
  private scanning: { entity: Entity; t: number } | null = null;
  private scanCheck = 0;
  private scanFocus: Entity | null = null;
  private appliedQuality: string | null = null;
  private fps = 60;
  private elapsed = 0;
  private started = false;
  private introShown = false;
  private pendingSave: boolean;

  constructor() {
    const canvas = document.getElementById('view') as HTMLCanvasElement;
    const saved = loadGame(localStorage);
    this.pendingSave = saved !== null;
    this.state = saved ?? createNewState();

    this.world = new WorldScene(canvas);
    this.level = new Level(this.world.scene);
    this.player = new Player(canvas, this.world.camera, this.level);
    this.world.scene.add(this.world.camera);
    this.entities = new EntityManager(this.world.scene, this.level, this.world.camera);

    const savedAz = Number(this.state.flags['dish_az']);
    const savedEl = Number(this.state.flags['dish_el']);
    if (Number.isFinite(savedAz) && Number.isFinite(savedEl) && savedAz > 0) {
      this.dish.az = savedAz;
      this.dish.el = savedEl;
    }
    this.level.setDish(this.dish.az, this.dish.el);

    this.hud = new Hud();
    this.panels = new Panels(this.hud.panelLayer, this, this.hud);
    this.sim = new Sim(this.state, this.createHost(), this.simHooks);

    this.entities.onContact = (entity, how) => this.onEntityContact(entity, how);
    this.entities.onSpawn = () => this.audio.play('breath');

    this.player.onStep = (surface) => this.audio.step(surface);
    this.player.onFocus = (target) => {
      if (this.panels.isOpen || this.hud.screenOpen) return;
      if (target) this.hud.setPrompt(`<b>[E]</b> ${target.label}<span class="hint">${target.hint}</span>`);
      else this.updateScanPrompt();
    };
    this.player.onLockChange = (locked) => {
      if (!locked && !this.panels.isOpen && !this.hud.screenOpen && this.started) {
        // El usuario ha salido del puntero: mostrar pausa solo con Esc.
      }
    };

    this.bindKeys();
    this.boot();
    this.loop();
  }

  // ---------- arranque ----------

  private boot(): void {
    const status = document.getElementById('boot-status')!;
    const fill = document.getElementById('boot-fill')!;
    const steps = ['iniciando consola…', 'montando escena…', 'nivel kestrel cargado…', 'antena calibrada…'];
    let i = 0;
    const tick = () => {
      status.textContent = steps[i] ?? 'listo.';
      fill.style.width = `${Math.min(100, ((i + 1) / steps.length) * 100)}%`;
      i++;
      if (i < steps.length) window.setTimeout(tick, 140);
      else this.showMenu();
    };
    window.setTimeout(tick, 220);
  }

  private showMenu(): void {
    const boot = document.getElementById('boot')!;
    const status = document.getElementById('boot-status')!;
    const inner = boot.querySelector('.boot-inner')!;
    status.textContent = this.pendingSave ? 'partida guardada detectada' : 'sin partida previa';
    const existing = inner.querySelector('.menu');
    existing?.remove();
    const menu = document.createElement('div');
    menu.className = 'menu';
    menu.innerHTML = `
      ${this.pendingSave ? '<button class="primary" data-continue>Continuar turno</button>' : ''}
      <button class="${this.pendingSave ? 'ghost' : 'primary'}" data-new>${this.pendingSave ? 'Nuevo turno' : 'Entrar en la estación'}</button>
    `;
    inner.appendChild(menu);
    const startLabel = inner.querySelector('#boot-start') as HTMLElement | null;
    startLabel?.remove();
    menu.querySelector('[data-continue]')?.addEventListener('click', () => {
      this.audio.start();
      this.beginSession();
    });
    menu.querySelector('[data-new]')?.addEventListener('click', () => {
      this.audio.start();
      clearSave(localStorage);
      this.state = createNewState();
      this.sim = new Sim(this.state, this.createHost(), this.simHooks);
      this.sources = generateSources(1, new Rng(this.state.seed + 7919));
      this.dish.az = 200;
      this.dish.el = 40;
      this.level.setDish(200, 40);
      this.player.teleport(0, 0, 11);
      this.player.setLook(0, 0);
      this.state.position = [0, 0, 11];
      this.beginSession();
    });
  }

  private beginSession(): void {
    if (this.started) return;
    this.started = true;
    document.getElementById('boot')!.classList.add('hide');
    this.world.applyQuality(this.state.quality);
    this.appliedQuality = this.state.quality;
    this.level.setPower(this.state.power);
    this.audio.setPower(this.state.power);
    if (this.sources.length === 0) this.regenerateSources();

    const saved = this.state.position;
    if (saved && this.level.isWalkable(saved[0], saved[2])) {
      this.player.teleport(saved[0], saved[1], saved[2]);
      // La motonieve espera donde la dejaste (salvo el origen, que no se guarda).
      const zone = this.level.zoneAt(this.player.position);
      if (zone !== 'origen') this.level.placeMoto(zone);
    } else {
      this.player.teleport(0, 0, 11);
      this.state.position = [0, 0, 11];
      this.player.setLook(0, 0);
    }
    this.level.clearOrigin();
    this.triFixed = null;
    this.resetMasts();
    this.weatherKey = '';
    this.level.aimDish(this.dish.az, this.dish.el);
    this.sim.paused = false;
    if (!this.introShown) {
      this.introShown = true;
      const brief = dayBriefing(this.state.day)[0] ?? '';
      this.hud.toast(brief, 'info');
      this.logMsg('Turno iniciado. La estación está en línea.', 'info');
    }
    if (this.state.ending) {
      // Partida cerrada: se muestra el final en lugar de devolver al turno.
      this.sim.paused = true;
      this.player.setEnabled(false);
      this.hud.showEnding(this.state.ending as EndingId, this.state, () => {
        clearSave(localStorage);
        window.location.reload();
      });
      this.hud.update(this.state, 60);
      return;
    }
    this.player.setEnabled(true);
    this.player.requestLock();
    this.hud.update(this.state, 60);
  }

  // ---------- bucle ----------

  private loop = (): void => {
    const clock = new THREE.Clock();
    const frame = () => {
      const rawDt = clock.getDelta();
      // La física usa un paso corto; el reloj y las máquinas usan tiempo real
      // (con un techo) para que un equipo lento no congele la partida.
      const dt = Math.min(rawDt, 0.1);
      const worldDt = Math.min(rawDt, 0.5);
      this.elapsed += dt;
      this.fps += (1 / Math.max(rawDt, 0.0001) - this.fps) * 0.06;

      if (this.started) {
        this.applyWeather();
        this.sim.tick(worldDt);
        this.updateDish(worldDt);
        this.entities.activeZone = this.level.zoneAt(this.player.position);
        this.entities.update(worldDt, this.player.position);
        this.updateScan(worldDt);
        this.updateTravel(worldDt);
        this.recordRoutineTick(worldDt);
        this.sim.setContext(
          !this.level.isInside(this.player.position),
          this.level.isNearLight(this.player.position),
        );
        if (this.state.quality !== this.appliedQuality) this.applyQuality();
        this.persistPosition();
      }

      this.player.update(dt);
      this.level.update(dt, this.state.power);
      this.level.setMachineFaults({
        spectrum: machineBroken(this.state, 'spectrum'),
        demod: machineBroken(this.state, 'demod'),
        decoder: machineBroken(this.state, 'decoder'),
      });
      this.level.setMachineDisplays(this.state);
      this.world.update(dt, this.world.camera);
      this.panels.tick();
      this.hud.update(this.state, this.fps);
      this.audio.setStress(this.state.stress);
      this.audio.setOutside(!this.level.isInside(this.player.position));
      this.world.adapt(dt);
      this.world.render();
      requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  };

  private persistPosition(): void {
    this.state.position = [this.player.position.x, this.player.position.y, this.player.position.z];
    this.state.flags['dish_az'] = this.dish.az;
    this.state.flags['dish_el'] = this.dish.el;
  }

  /** Clima del valle: solo se toca la escena cuando cambia de verdad. */
  private applyWeather(): void {
    const w = this.state.weather;
    const key = `${w.kind}:${w.intensity.toFixed(2)}`;
    if (key === this.weatherKey) return;
    this.weatherKey = key;
    this.world.setWeather(w.kind, w.intensity);
    this.dish.noise = weatherNoise(this.state);
  }

  /** Viaje en motonieve: el reloj sigue corriendo y el jugador va de paquete. */
  private updateTravel(dt: number): void {
    const trip = this.trip;
    if (!trip) return;
    trip.t += dt;
    if (trip.t < trip.duration) return;
    this.trip = null;
    const spot = arrivalFor(trip.dest, this.triFixed?.x ?? 0, this.triFixed?.z ?? 0);
    this.player.teleport(spot.x, 0, spot.z);
    this.player.setLook(trip.dest === 'kestrel' ? 2.4 : 0.4, 0);
    this.state.position = [spot.x, 0, spot.z];
    this.level.placeMoto(trip.dest);
    this.entities.clear();
    this.player.setEnabled(true);
    this.player.requestLock();
    if (trip.dest !== 'kestrel') this.state.stats.trips += 1;
    addStress(this.state, 4);
    this.audio.play('motor');
    this.hud.toast(`Has llegado: ${this.zoneName(trip.dest)}.`, 'info');
    this.logMsg(`Motonieve: llegada a ${this.zoneName(trip.dest)}. El motor queda caliente.`, 'info');
    if (this.panels.current === 'travel') this.panels.open('travel');
    this.saveNow(false);
  }

  private zoneName(zone: ZoneName): string {
    if (zone === 'repetidor') return 'el repetidor (900 m)';
    if (zone === 'origen') return 'el origen localizado';
    return 'Kestrel';
  }

  /** El juego aprende dónde sueles estar en cada tramo de la noche. */
  private recordRoutineTick(dt: number): void {
    if (this.sim.paused || this.trip) return;
    this.routineTimer -= dt;
    if (this.routineTimer > 0) return;
    this.routineTimer = 1.5;
    recordRoutine(this.state, this.state.clock, this.player.position.x, this.player.position.z);
  }

  private updateDish(dt: number): void {
    const s = this.state;
    if (s.power && this.dish.sweeping && !this.dish.recording) {
      this.dish.az = (this.dish.az + SWEEP_SPEED * dt) % 360;
    }
    const gain = level(s, 'plato');
    const interference = s.power ? s.stress * 0.22 + this.dish.noise : 100;
    let best: SignalSource | null = null;
    let bestStrength = 0;
    for (const src of this.sources) {
      const strength = signalStrength(this.dish.az, this.dish.el, src, gain, interference);
      if (strength > bestStrength) {
        bestStrength = strength;
        best = src;
      }
    }
    const previousLock = this.dish.locked;
    this.dish.strength = bestStrength;
    this.dish.locked = bestStrength >= LOCK_STRENGTH;
    this.dish.sourceLabel = this.dish.locked && best ? 'FUENTE SIN CATALOGAR' : null;
    this.dish.progress = this.recording ? Math.min(1, this.recording.elapsed / RECORD_SECONDS) : 0;
    if (this.dish.locked && !previousLock) this.audio.dishLock();

    this.level.aimDish(this.dish.az, this.dish.el);

    if (this.recording) {
      if (!s.power) {
        this.cancelRecording();
        this.hud.toast('Grabación abortada: sin corriente.', 'bad');
        return;
      }
      if (!this.dish.locked || best?.id !== this.recording.source.id) {
        this.cancelRecording();
        this.hud.toast('Grabación abortada: la fuente se ha perdido.', 'warn');
        return;
      }
      this.recording.elapsed += dt;
      this.recording.sum += bestStrength;
      this.recording.samples += 1;
      if (this.recording.elapsed >= RECORD_SECONDS) this.finishRecording();
    }
  }

  private finishRecording(): void {
    const rec = this.recording;
    if (!rec) return;
    this.recording = null;
    this.dish.recording = false;
    const avg = rec.samples > 0 ? rec.sum / rec.samples : 0;
    const quality = Math.max(
      15,
      Math.min(
        100,
        avg * 0.92 + level(this.state, 'plato') * 3.5 - this.state.stress * 0.12 + (Math.random() - 0.5) * 5,
      ),
    );
    const capture = makeCapture(rec.source, quality, this.state.day, this.state.clock, new Rng(Date.now() >>> 0), 'antena');
    this.state.captures.push(capture);
    this.selectedId = capture.id;
    this.logMsg(`Captura almacenada (${capture.band.toFixed(1)} MHz, integridad ${Math.round(quality)}%).`, 'info');
    this.hud.toast('Captura almacenada. Llévala al analizador de espectro.', 'good');
    this.audio.beep(720);
    this.saveNow(false);
  }

  private updateScan(dt: number): void {
    if (this.scanning) {
      this.scanning.t += dt / 1.35;
      this.hud.setScan(this.scanning.t);
      if (this.scanning.entity.stage === 'gone') {
        this.scanning = null;
        this.hud.setScan(null);
        return;
      }
      if (this.scanning.t >= 1) {
        const entity = this.scanning.entity;
        this.scanning = null;
        this.hud.setScan(null);
        this.entities.scan(entity);
        this.onEntityContact(entity, 'scanned');
        this.audio.scanDone();
      }
      return;
    }
    // Prompt de escaneo: no hace falta cada frame.
    this.scanCheck -= dt;
    if (this.scanCheck > 0) return;
    this.scanCheck = 0.2;
    if (this.panels.isOpen || this.hud.screenOpen || !this.player.locked) return;
    if (this.player.currentFocus) return;
    const target = this.entities.scanTarget();
    if (target !== this.scanFocus) {
      this.scanFocus = target;
      if (target) this.hud.setPrompt('<b>[Q]</b> Escáner de campo<span class="hint">tomar una lectura</span>');
      else this.hud.setPrompt(null);
    }
  }

  private updateScanPrompt(): void {
    if (this.scanning) return;
    this.scanFocus = this.entities.scanTarget();
    if (this.scanFocus) {
      this.hud.setPrompt('<b>[Q]</b> Escáner de campo<span class="hint">tomar una lectura</span>');
    } else {
      this.hud.setPrompt(null);
    }
  }

  // ---------- entradas ----------

  private bindKeys(): void {
    window.addEventListener('keydown', (e) => {
      if (!this.started) return;
      if (e.code === 'Tab') {
        e.preventDefault();
        if (this.hud.screenOpen) return;
        if (this.panels.isOpen) this.panels.close();
        else this.openPanel('pc', 'registro');
        return;
      }
      if (e.code === 'Escape') {
        e.preventDefault();
        if (this.panels.isOpen) {
          this.panels.close();
          return;
        }
        if (this.hud.screenOpen) return;
        this.togglePause();
        return;
      }
      if (this.hud.screenOpen || this.panels.isOpen) return;
      if (e.code === 'KeyE') {
        const focus = this.player.currentFocus;
        if (!focus) return;
        this.interact(focus.id);
      }
      if (e.code === 'KeyQ') {
        if (!this.scanning) {
          const target = this.entities.scanTarget();
          if (!target) {
            this.audio.beep(420);
            this.hud.toast('Escáner: sin retorno. Nada que leer en esa dirección.', 'warn');
            return;
          }
          this.scanning = { entity: target, t: 0 };
          this.audio.scanStart();
          this.hud.setScan(0);
        }
      }
    });
  }

  private interact(id: string): void {
    switch (id) {
      case 'terminal':
        this.openPanel('dish');
        break;
      case 'spectrum':
        this.openPanel('spectrum');
        break;
      case 'spectrum-dial':
        this.level.nudgeSpectrumControl(10);
        this.openPanel('spectrum');
        break;
      case 'spectrum-isolate': {
        this.level.pressSpectrumButton();
        const result = this.isolate(this.level.getSpectrumControl());
        this.hud.toast(result.message, result.ok ? 'good' : 'warn');
        if (result.ok) this.openPanel('demod');
        else this.openPanel('spectrum');
        break;
      }
      case 'demod':
        this.openPanel('demod');
        break;
      case 'demod-selector':
        this.level.cycleDemodulation();
        this.openPanel('demod');
        break;
      case 'demod-confirm': {
        this.level.pressDemodButton();
        const result = this.demod(this.level.getDemodulation());
        this.hud.toast(result.message, result.ok ? 'good' : 'warn');
        if (result.ok) this.openPanel('decoder');
        else this.openPanel('demod');
        break;
      }
      case 'decoder-selector':
        this.level.cycleCipher();
        this.openPanel('decoder');
        break;
      case 'decoder-confirm': {
        this.level.pressDecoderButton();
        const result = this.decode(this.level.getCipher());
        this.hud.toast(result.message, result.ok ? 'good' : 'warn');
        this.openPanel('decoder');
        break;
      }
      case 'decoder':
        this.openPanel('decoder');
        break;
      case 'pc':
        this.openPanel('pc');
        break;
      case 'coffee':
        this.drinkCoffee();
        break;
      case 'breaker':
        this.useBreaker();
        break;
      case 'bed':
        this.hud.showConfirm('CERRAR TURNO', 'Dormir hasta mañana. El parte se envía sin ti.', () => {
          this.sim.sleep();
        });
        break;
      case 'tape':
        this.playTape();
        break;
      case 'moto':
        this.openPanel('travel');
        break;
      case 'repeater':
        this.openPanel('tri');
        break;
      case 'trueque':
        this.openPanel('trade');
        break;
      case 'origen':
        this.inspectOrigin();
        break;
      default:
        break;
    }
  }

  private openPanel(
    id: 'dish' | 'spectrum' | 'demod' | 'decoder' | 'pc' | 'tri' | 'travel' | 'trade',
    tab?: 'registro',
  ): void {
    if (this.hud.screenOpen) return;
    // El refugio del repetidor tiene su propia corriente: la consola de
    // triangulación funciona aunque Kestrel esté a oscuras.
    if (!this.state.power && (id === 'dish' || id === 'spectrum' || id === 'demod' || id === 'decoder')) {
      this.hud.toast('Esa máquina no tiene corriente. Reinicia el cuadro del generador.', 'warn');
      return;
    }
    this.player.setEnabled(false);
    this.player.releaseLock();
    this.hud.setPrompt(null);
    this.panels.open(tab ? 'log' : id);
  }

  private togglePause(): void {
    if (this.hud.screenOpen) return;
    this.sim.paused = true;
    this.player.setEnabled(false);
    this.player.releaseLock();
    this.openPause();
  }

  private openPause(): void {
    this.hud.showPause(this.state, {
      resume: () => {
        this.sim.paused = false;
        this.player.setEnabled(true);
        this.player.requestLock();
      },
      quality: () => {
        const order: ('alta' | 'media' | 'baja')[] = ['alta', 'media', 'baja'];
        const next = order[(order.indexOf(this.state.quality) + 1) % order.length]!;
        this.setQuality(next);
        this.openPause();
      },
      mute: () => {
        this.audio.toggleMute();
        this.openPause();
      },
      abandon: () => this.abandon(),
    });
  }

  private abandon(): void {
    this.hud.showConfirm('ABANDONAR ESTACIÓN', 'Se borrará el progreso guardado de esta partida.', () => {
      clearSave(localStorage);
      window.location.reload();
    });
  }

  // ---------- acciones de juego ----------

  setDish(az: number, el: number): void {
    this.dish.az = ((az % 360) + 360) % 360;
    this.dish.el = Math.max(5, Math.min(85, el));
    this.level.aimDish(this.dish.az, this.dish.el);
  }

  setSpectrumControl(center: number): void {
    this.level.setSpectrumControl(center);
  }

  getSpectrumControl(): number {
    return this.level.getSpectrumControl();
  }

  getDemodulation(): Modulation {
    return this.level.getDemodulation();
  }

  setDemodulation(modulation: Modulation): void {
    this.level.setDemodulation(modulation);
  }

  getCipher(): Cipher {
    return this.level.getCipher();
  }

  setCipher(cipher: Cipher): void {
    this.level.setCipher(cipher);
  }

  toggleSweep(): void {
    this.dish.sweeping = !this.dish.sweeping;
  }

  startRecording(): void {
    const s = this.state;
    if (!s.power) {
      this.hud.toast('Sin corriente no hay receptor.', 'warn');
      return;
    }
    if (this.recording) return;
    if (activeCaptures(s) >= capacity(s)) {
      this.hud.toast('Archivador lleno. Vende o archiva capturas antes de grabar.', 'warn');
      return;
    }
    if (!this.dish.locked) {
      this.hud.toast('Enlace inestable. Afina el apuntado antes de grabar.', 'warn');
      return;
    }
    const gain = level(s, 'plato');
    const interference = s.stress * 0.22 + this.dish.noise;
    let best: SignalSource | null = null;
    let bestStrength = 0;
    for (const src of this.sources) {
      const strength = signalStrength(this.dish.az, this.dish.el, src, gain, interference);
      if (strength > bestStrength) {
        bestStrength = strength;
        best = src;
      }
    }
    if (!best) return;
    this.dish.sweeping = false;
    this.recording = { source: best, elapsed: 0, sum: 0, samples: 0 };
    this.dish.recording = true;
    this.audio.beep(520);
    this.logMsg('Grabación iniciada: 12 segundos de señal.', 'info');
  }

  cancelRecording(): void {
    if (!this.recording) return;
    this.recording = null;
    this.dish.recording = false;
    this.dish.progress = 0;
    this.audio.error();
    this.logMsg('Grabación cancelada.', 'warn');
  }

  selectedCapture(): Capture | null {
    if (!this.selectedId) return this.state.captures.find((c) => !c.sold) ?? null;
    return this.state.captures.find((c) => c.id === this.selectedId) ?? null;
  }

  selectCapture(id: string): void {
    this.selectedId = id;
  }

  isolate(center: number): ActionResult {
    const cap = this.currentForStage(STAGE.CRUDA);
    if (!cap) return { ok: false, message: 'No hay captura en bruto seleccionada.' };
    if (!this.state.power) return { ok: false, message: 'Sin corriente.' };
    if (machineBroken(this.state, 'spectrum')) {
      return { ok: false, message: 'El analizador está averiado: calíbralo o cambia la pieza.' };
    }
    const result = isolateBand(cap, center, level(this.state, 'filtro'));
    cap.quality = Math.max(4, cap.quality + result.qualityDelta);
    cap.corruption = Math.max(0, cap.corruption + result.corruptionDelta);
    if (result.ok) {
      cap.stage = STAGE.AISLADA;
      this.audio.beep(880);
      this.logMsg(`Portadora aislada en ${cap.band.toFixed(1)} MHz.`, 'info');
      this.saveNow(false);
    } else {
      addStress(this.state, 2.5);
      this.audio.error();
    }
    return { ok: result.ok, message: result.message };
  }

  demod(mod: Modulation): ActionResult {
    const cap = this.currentForStage(STAGE.AISLADA);
    if (!cap) return { ok: false, message: 'No hay captura con portadora aislada.' };
    if (!this.state.power) return { ok: false, message: 'Sin corriente.' };
    if (machineBroken(this.state, 'demod')) {
      return { ok: false, message: 'El demodulador está averiado: calíbralo o cambia la pieza.' };
    }
    const result = demodSignal(cap, mod, level(this.state, 'demod'));
    cap.quality = Math.max(4, cap.quality + result.qualityDelta);
    cap.corruption = Math.max(0, cap.corruption + result.corruptionDelta);
    if (result.ok) {
      cap.stage = STAGE.DEMODULADA;
      this.audio.beep(980);
      this.logMsg('Trama demodulada. El decodificador puede leer la firma.', 'info');
      this.saveNow(false);
    } else {
      cap.failedAttempts += 1;
      addStress(this.state, 2);
      this.audio.error();
    }
    return { ok: result.ok, message: result.message };
  }

  decode(cipher: Cipher): ActionResult {
    const cap = this.currentForStage(STAGE.DEMODULADA);
    if (!cap) return { ok: false, message: 'No hay captura demodulada.' };
    if (!this.state.power) return { ok: false, message: 'Sin corriente.' };
    if (machineBroken(this.state, 'decoder')) {
      return { ok: false, message: 'El decodificador está averiado: calíbralo o cambia la pieza.' };
    }
    const result = tryDecode(cap, cipher, this.state.glyphTable, level(this.state, 'demod'));
    cap.quality = Math.max(2, cap.quality + result.qualityDelta);
    cap.corruption = Math.max(0, cap.corruption + result.corruptionDelta);
    if (result.ok) {
      cap.stage = STAGE.DECODIFICADA;
      cap.text = result.text ?? cap.text;
      this.state.stats.decoded += 1;
      markTaskProgress(this.state, 'decode');
      if (cap.klass === 'VOZ') {
        this.state.stats.voz += 1;
        markTaskProgress(this.state, 'voz');
        this.audio.play('voice');
      }
      if (cap.klass === 'ANOMALO') {
        this.state.stats.anomalo += 1;
        markTaskProgress(this.state, 'anomalo');
        addStress(this.state, 8);
        this.audio.play('breath');
        this.spawnScriptedContact();
      }
      const frags = CLASS_INFO[cap.klass].fragments;
      if (frags > 0) this.addFragments(frags);
      if (cap.klass === 'VACIO') {
        addStress(this.state, 12);
        this.hud.flash(0.5);
        this.audio.play('voice');
        this.logMsg('El mensaje del vacío se ha reconstruido. No había emisor.', 'bad');
      }
      this.logMsg(`Señal decodificada: ${CLASS_INFO[cap.klass].label} · ${cap.name}.`, 'good');
      this.hud.toast(`Decodificada: ${CLASS_INFO[cap.klass].label}`, 'good');
      this.saveNow(false);
      return { ok: true, message: result.message };
    }
    cap.failedAttempts += 1;
    addStress(this.state, 1.5);
    if (cap.quality <= 12 || cap.corruption > 82) {
      cap.klass = 'RUIDO';
      cap.stage = STAGE.DECODIFICADA;
      cap.text = '—';
      this.audio.error();
      this.logMsg('La captura se ha degradado a ruido.', 'bad');
      return { ok: false, message: 'La trama se ha degradado a ruido. Esta captura ya no vale nada.' };
    }
    this.audio.error();
    return { ok: false, message: result.message };
  }

  sell(id: string): void {
    const res = sellCapture(this.state, id);
    if (!res.ok) {
      this.hud.toast(res.message, 'warn');
      return;
    }
    if (res.value > 0) {
      this.audio.sell();
      this.hud.toast(`${res.message} Cuota ${this.state.quota.earned}/${this.state.quota.target}.`, 'good');
      this.logMsg(res.message, 'good');
    } else {
      this.hud.toast('Sin valor de mercado. Archivada.', 'info');
    }
    this.saveNow(false);
  }

  archive(id: string): void {
    archiveCapture(this.state, id);
    this.audio.click();
    this.hud.toast('Captura archivada.', 'info');
  }

  buy(id: string): void {
    const res = buyUpgrade(this.state, id);
    this.hud.toast(res.message, res.ok ? 'good' : 'warn');
    if (res.ok) {
      this.audio.sell();
      this.logMsg(res.message, 'good');
      this.saveNow(false);
    } else {
      this.audio.error();
    }
  }

  // ---------- fase 2: averías, triangulación, motonieve y trueque ----------

  buyPart(): ActionResult {
    const res = buyPart(this.state);
    if (res.ok) {
      this.audio.sell();
      this.logMsg(res.message, 'good');
      this.saveNow(false);
    } else {
      this.audio.error();
    }
    return res;
  }

  calibrate(machine: MachineId): ActionResult {
    const res = calibrateMachine(this.state, new Rng(Date.now() >>> 0), machine);
    if (res.ok) {
      this.audio.scanDone();
      this.hud.toast(`${machineDef(machine).short} calibrada.`, 'good');
      this.saveNow(false);
    } else {
      this.audio.error();
    }
    return res;
  }

  repair(machine: MachineId): ActionResult {
    const res = repairWithPart(this.state, machine);
    if (res.ok) {
      this.audio.sell();
      this.hud.toast(`${machineDef(machine).short} reparada.`, 'good');
      this.saveNow(false);
    } else {
      this.audio.error();
    }
    return res;
  }

  /** Emisor del día: fijo, determinista y fuera de la estación. */
  private triangulationTarget() {
    return triTarget(this.state.seed, this.state.day, REPEATER_CENTER.x, REPEATER_CENTER.z);
  }

  private trueBearing(index: number): number {
    const station = TRI_STATIONS[index];
    if (!station) return 0;
    const from = stationWorld(station, REPEATER_CENTER.x, REPEATER_CENTER.z);
    const target = this.triangulationTarget();
    return bearingBetween(from.x, from.z, target.x, target.z);
  }

  triTelemetry(): TriTelemetry {
    return {
      masts: TRI_STATIONS.map((station, i) => {
        const world = stationWorld(station, REPEATER_CENTER.x, REPEATER_CENTER.z);
        const measure = this.masts[i] ?? { aim: 0, quality: 0, locked: false };
        return {
          id: station.id,
          label: station.label,
          aim: measure.aim,
          quality: measure.quality,
          locked: measure.locked,
          x: world.x,
          z: world.z,
        };
      }),
      locked: this.masts.filter((m) => m.locked).length,
      strengths: TRI_STATIONS.map((_, i) => bearingQuality(this.masts[i]?.aim ?? 0, this.trueBearing(i)) * 100),
      fixed: this.triFixed ? { ...this.triFixed } : null,
      visited: this.state.flags['origen_visitado'] === this.state.day,
    };
  }

  aimMast(index: number, az: number): void {
    const measure = this.masts[index];
    if (!measure) return;
    measure.aim = ((az % 360) + 360) % 360;
    measure.locked = false;
    measure.quality = 0;
  }

  lockMast(index: number): ActionResult {
    const measure = this.masts[index];
    if (!measure) return { ok: false, message: 'Mástil desconocido.' };
    const quality = bearingQuality(measure.aim, this.trueBearing(index));
    if (quality < TRI_LOCK) {
      measure.locked = false;
      measure.quality = quality;
      this.audio.error();
      return {
        ok: false,
        message: `Aguja al ${Math.round(quality * 100)} % (umbral ${Math.round(TRI_LOCK * 100)} %). El rumbo no es fiable: sigue girando.`,
      };
    }
    measure.locked = true;
    measure.quality = quality;
    this.audio.dishLock();
    this.logMsg(`Mástil ${TRI_STATIONS[index]!.label}: rumbo fijado a ${measure.aim.toFixed(1)}°.`, 'info');
    return { ok: true, message: `Rumbo fijado · calidad ${Math.round(quality * 100)} %.` };
  }

  resetMasts(): void {
    this.masts = TRI_STATIONS.map(() => ({ aim: 0, quality: 0, locked: false }));
    this.audio.click();
  }

  triangulate(): ActionResult {
    if (this.masts.filter((m) => m.locked).length < TRI_STATIONS.length) {
      return {
        ok: false,
        message: `Faltan rumbos: ${this.masts.filter((m) => m.locked).length}/${TRI_STATIONS.length} fijados.`,
      };
    }
    const readings: Bearing[] = TRI_STATIONS.map((station, i) => {
      const world = stationWorld(station, REPEATER_CENTER.x, REPEATER_CENTER.z);
      return { x: world.x, z: world.z, bearing: this.masts[i]!.aim };
    });
    const fix = intersectBearings(readings);
    if (!fix.ok) {
      this.audio.error();
      this.logMsg('Los tres rumbos no convergen. Repite alguna medida.', 'warn');
      return { ok: false, message: `Las medidas no convergen (dispersión ${fix.spread.toFixed(0)} m). Repite un rumbo.` };
    }

    const target = this.triangulationTarget();
    const error = planarDistance(fix.x, fix.z, target.x, target.z);
    this.triFixed = {
      x: fix.x,
      z: fix.z,
      spread: fix.spread,
      distance: Math.hypot(fix.x - REPEATER_CENTER.x, fix.z - REPEATER_CENTER.z),
      name: target.name,
      klass: target.klass,
      error,
    };
    this.state.stats.triangulations += 1;
    markTaskProgress(this.state, 'triangular');
    this.level.setOrigin(fix.x, fix.z);
    const fragments = CLASS_INFO[target.klass].fragments;
    this.addFragments(fragments);
    addStress(this.state, 10);
    this.audio.scanDone();
    this.audio.play('morse');
    this.hud.toast(`ORIGEN LOCALIZADO · ${target.name}`, 'bad');
    this.logMsg(
      `Triangulación cerrada: el emisor está en ${target.name}, a ${Math.round(this.triFixed.distance)} m del repetidor. Dispersión ${fix.spread.toFixed(1)} m.`,
      'bad',
    );
    this.saveNow(false);
    return {
      ok: true,
      message: `Origen localizado a ${Math.round(this.triFixed.distance)} m · ${target.name}. +${fragments} fragmento(s).`,
    };
  }

  travelOptions(): TravelOption[] {
    const zone = this.level.zoneAt(this.player.position);
    const origin = this.triFixed;
    return [
      {
        dest: 'kestrel',
        label: 'Kestrel · estación principal',
        detail: 'Vuelta por la pista de la cresta. Al llegar tienes la cadena de decodificación y la consola.',
        enabled: zone !== 'kestrel',
      },
      {
        dest: 'repetidor',
        label: `Repetidor · 900 m al sur`,
        detail: this.state.flags['repetidor_abierto']
          ? 'Refugio con tres mástiles de medida y consola de triangulación. Su propia corriente.'
          : `La pista está cerrada por nieve. La baliza no despierta antes del día ${REPEATER_DAY}.`,
        enabled: zone !== 'repetidor' && !!this.state.flags['repetidor_abierto'],
      },
      {
        dest: 'origen',
        label: 'Origen triangulado',
        detail: origin
          ? `${origin.name} · ${Math.round(origin.distance)} m del repetidor según tu medida (dispersión ${origin.spread.toFixed(1)} m).`
          : 'Sin coordenadas. Triangula primero desde la consola del repetidor.',
        enabled: zone !== 'origen' && !!origin && this.level.hasOriginZone(),
      },
    ];
  }

  travel(dest: TravelDest): ActionResult {
    if (this.trip) return { ok: false, message: 'Ya estás de camino.' };
    const option = this.travelOptions().find((o) => o.dest === dest);
    if (!option) return { ok: false, message: 'Destino desconocido.' };
    if (!option.enabled) return { ok: false, message: `${option.label}: ahora mismo no puedes salir hacia ahí.` };

    const duration =
      dest === 'origen' ? Math.max(6, Math.min(16, (this.triFixed?.distance ?? 400) / 60)) : TRAVEL_SECONDS;
    this.trip = {
      dest,
      t: 0,
      duration,
      label:
        dest === 'kestrel'
          ? 'Kestrel · pista de la cresta'
          : dest === 'repetidor'
            ? 'Repetidor · 900 m al sur'
            : 'Origen triangulado · campo abierto',
    };
    this.player.setEnabled(false);
    this.player.releaseLock();
    this.dish.sweeping = false;
    this.hud.toast('Motonieve en marcha. Mantente en el camino.', 'info');
    this.logMsg(`Sales en motonieve hacia ${this.zoneName(dest)}.`, 'info');
    this.audio.play('motor');
    return { ok: true, message: `En ruta hacia ${this.zoneName(dest)}.` };
  }

  traveling(): { active: boolean; progress: number; label: string } {
    if (!this.trip) return { active: false, progress: 0, label: '' };
    return {
      active: true,
      progress: Math.min(1, this.trip.t / this.trip.duration),
      label: this.trip.label,
    };
  }

  tradeView(): TradeView {
    const offer = tradeOffer(this.state);
    const active = !!this.state.flags['comerciante_activo'];
    const candidates = active
      ? this.state.captures.filter(
          (c) => !c.sold && c.stage >= STAGE.DECODIFICADA && (!offer.wantsKlass || c.klass === offer.wantsKlass),
        )
      : [];
    return {
      active,
      wantsLabel: offer.wantsLabel,
      wantsKlass: offer.wantsKlass,
      reward: offer.reward,
      fragments: offer.fragments,
      parts: offer.parts,
      flavor: offer.flavor,
      candidates,
    };
  }

  trade(captureId: string): ActionResult {
    const res = tradeCapture(this.state, captureId);
    if (!res.ok) {
      this.audio.error();
      return res;
    }
    delete this.state.flags['comerciante_activo'];
    this.level.hideOffer();
    this.addFragments(0);
    this.audio.play('trade');
    this.hud.toast('Trueque cerrado. El cajón se ha cerrado solo.', 'good');
    this.logMsg(res.message, 'good');
    this.saveNow(false);
    return res;
  }

  weatherLabel(): string {
    return weatherLabel(this.state);
  }

  weatherKind(): WeatherKind {
    return this.state.weather.kind;
  }

  /** Registrar los restos del emisor: cierra el bucle de la triangulación. */
  private inspectOrigin(): void {
    const fixed = this.triFixed;
    if (!fixed) {
      this.hud.toast('Aquí no hay nada señalado.', 'warn');
      return;
    }
    if (this.state.flags['origen_visitado'] === this.state.day) {
      this.hud.toast('Los restos ya están registrados. No queda nada más.', 'info');
      this.audio.beep(300);
      return;
    }
    this.state.flags['origen_visitado'] = this.state.day;
    this.audio.scanDone();
    if (fixed.error <= 45) {
      const source = syntheticSource(fixed.klass, new Rng(Date.now() >>> 0));
      const cap = makeCapture(source, 78, this.state.day, this.state.clock, new Rng(Date.now() >>> 0), 'evento');
      this.state.captures.push(cap);
      this.selectedId = cap.id;
      const fragments = CLASS_INFO[fixed.klass].fragments;
      this.addFragments(fragments);
      addStress(this.state, 12);
      this.hud.flash(0.4);
      this.audio.play('voice');
      this.logMsg(
        `Origen registrado en ${fixed.name}: el emisor estaba aquí. La nieve de dentro está removida y el aire no está frío.`,
        'bad',
      );
      this.hud.toast(`Origen registrado · +${fragments} fragmento(s) y una captura`, 'bad');
    } else {
      this.addFragments(1);
      addStress(this.state, 6);
      this.logMsg(
        `En ${fixed.name} no hay nada: solo hielo removido y una marca en la nieve que no has hecho tú. La medida estaba ${Math.round(fixed.error)} m desviada.`,
        'warn',
      );
      this.hud.toast('Origen desviado: aquí no hay emisor', 'warn');
    }
    this.saveNow(false);
  }

  drinkCoffee(): void {
    if (this.state.flags['cafe_dia'] === this.state.shiftId) {
      this.hud.toast('La cafetera está vacía hasta el próximo turno.', 'info');
      return;
    }
    this.state.flags['cafe_dia'] = this.state.shiftId;
    const gain = coffeeGain(this.state);
    addStress(this.state, -gain);
    this.audio.beep(300);
    this.hud.toast(`Café. Estrés −${gain}.`, 'good');
    this.logMsg('Pausa de café. El edificio cruje mientras la taza se enfría.', 'info');
  }

  sleep(): void {
    this.sim.sleep();
  }

  transmit(): void {
    const res = this.sim.transmit();
    this.hud.toast(res.message, res.ok ? 'bad' : 'warn');
    if (res.ok) {
      addStress(this.state, 4);
      this.logMsg('Transmisión enviada en la banda de la última captura.', 'warn');
      this.saveNow(false);
    }
  }

  finish(ending: EndingId): void {
    this.sim.finish(ending);
  }

  skyBlips(): SkyBlip[] {
    const gain = level(this.state, 'plato');
    return this.sources.map((s) => ({
      az: s.az,
      el: s.el,
      strength: signalStrength(this.dish.az, this.dish.el, s, gain, this.state.stress * 0.22),
    }));
  }

  toast(text: string, kind: ToastKind = 'info'): void {
    this.hud.toast(text, kind);
  }

  sfx(id: string): void {
    this.audio.play(id);
  }

  closePanel(): void {
    if (this.hud.screenOpen) return;
    // A mitad de trayecto no se baja nadie: el panel vuelve a abrirse.
    if (this.trip) {
      this.openPanel('travel');
      return;
    }
    this.player.setEnabled(true);
    this.player.requestLock();
    this.hud.setPrompt(null);
  }

  storageLabel(): string {
    return 'almacenamiento local del navegador';
  }

  saveNow(notify = true): void {
    const ok = saveGame(this.state, localStorage);
    if (!ok) this.hud.toast('No se pudo guardar la partida.', 'bad');
    else if (notify) this.hud.toast('Partida guardada.', 'good');
  }

  setQuality(q: 'alta' | 'media' | 'baja'): void {
    this.state.quality = q;
    this.applyQuality();
    this.hud.toast(`Calidad gráfica: ${q}.`, 'info');
  }

  private applyQuality(): void {
    this.appliedQuality = this.state.quality;
    this.world.applyQuality(this.state.quality);
  }

  private grantEventCapture(kind: SignalClass, origin: 'microfono' | 'evento'): void {
    const rng = new Rng(Date.now() >>> 0);
    const src = syntheticSource(kind, rng);
    const cap = makeCapture(src, 74, this.state.day, this.state.clock, rng, origin);
    this.state.captures.push(cap);
    this.selectedId = cap.id;
    this.hud.toast('Nueva captura en el archivador.', 'info');
    this.logMsg(`Captura obtenida por ${origin}.`, 'info');
  }

  private addFragments(n: number): void {
    if (n > 0) this.state.fragments += n;
    if (!this.state.glyphTable && this.state.fragments >= 4) {
      this.state.glyphTable = true;
      this.logMsg('La tabla de glifos encaja con las lecturas de campo. Ya puedes traducir el vacío.', 'good');
      this.hud.toast('TABLA DE GLIFOS RECUPERADA', 'good');
    }
  }

  private currentForStage(stage: number): Capture | null {
    const selected = this.selectedCapture();
    if (selected && !selected.sold && selected.stage === stage) return selected;
    const found = this.state.captures.find((c) => !c.sold && c.stage === stage);
    if (found) {
      this.selectedId = found.id;
      return found;
    }
    return null;
  }

  private logMsg(text: string, kind: 'info' | 'warn' | 'bad' | 'good' | 'voice' = 'info'): void {
    log(this.state, text, kind, clockLabel(this.state.clock));
  }

  private regenerateSources(): void {
    this.sources = generateSources(this.state.day, new Rng(this.state.seed + this.state.day * 7919));
  }

  // ---------- eventos e interacciones del mundo ----------

  private useBreaker(): void {
    if (this.state.power) {
      this.hud.toast('La corriente está estable.', 'info');
      return;
    }
    this.sim.resetPower();
    this.audio.breaker();
    this.hud.toast('Cuadro reiniciado. Arranque en unos segundos.', 'warn');
  }

  private playTape(): void {
    const voices = this.state.captures.filter((c) => c.stage >= STAGE.DECODIFICADA && c.klass === 'VOZ');
    if (voices.length === 0) {
      this.hud.toast('No hay cintas de voz en el archivador.', 'info');
      this.audio.beep(300);
      return;
    }
    const last = voices[voices.length - 1]!;
    this.audio.play('voice');
    this.hud.toast(`CINTA: "${last.text}"`, 'info');
    this.logMsg(`Reproducción de cinta: ${last.text}`, 'voice');
    addStress(this.state, 3);
  }

  private spawnScriptedContact(): void {
    this.entities.spawn('figura', 'treeline');
    this.hud.toast('Algo se ha detenido en el linde.', 'bad');
  }

  private onEntityContact(entity: Entity, how: 'observed' | 'scanned' | 'approached' | 'left'): void {
    const kindLabel: Record<EntityKind, string> = {
      figura: 'la figura del linde',
      doble: 'tu silueta',
      perro: 'lo que respiraba en la valla',
      coro: 'el coro',
      imitador: 'el que copia tus pasos',
      comerciante: 'el que comercia',
      aprendiz: 'el que aprendió tu rutina',
    };
    if (how === 'scanned') {
      this.sim.registerContact();
      this.addFragments(entity.kind === 'coro' ? 2 : 1);
      markTaskProgress(this.state, 'scan');
      this.sim.registerScan();
      addStress(this.state, 6);
      this.audio.scanDone();
      this.hud.toast(`Lectura de campo: ${kindLabel[entity.kind]}. Fragmento de coherencia recuperado.`, 'good');
      this.logMsg(`Escáner: ${kindLabel[entity.kind]} registrada. La lectura no coincide con ningún patrón biológico conocido.`, 'good');
      this.saveNow(false);
      return;
    }
    this.sim.registerContact();
    if (how === 'observed') {
      this.addFragments(1);
      addStress(this.state, 9);
      this.audio.play('voice');
      this.hud.toast(`Sostuviste la mirada: ${kindLabel[entity.kind]}.`, 'bad');
      this.logMsg(`Observación sostenida: ${kindLabel[entity.kind]} se retiró sin moverse.`, 'bad');
    } else if (how === 'approached') {
      addStress(this.state, 16);
      this.player.addShake(0.8);
      this.hud.flash(0.35);
      this.audio.play('breath');
      this.hud.toast('Estaba a menos de tres metros. Ya no está.', 'bad');
      this.logMsg(`Contacto cercano: ${kindLabel[entity.kind]}. No quedan huellas.`, 'bad');
    }
    this.saveNow(false);
  }

  private createHost(): EventHost {
    return {
      toast: (text, kind) => this.hud.toast(text, kind),
      log: (text, kind) => this.logMsg(text, kind),
      stress: (delta) => addStress(this.state, delta),
      powerOut: (seconds) => {
        this.state.power = false;
        this.state.powerOutTimer = seconds;
        this.state.stats.blackouts += 1;
        this.state.flags['apagon_pendiente'] = true;
        this.level.setPower(false);
        this.audio.setPower(false);
        this.audio.breaker();
        this.hud.flash(0.25);
      },
      sound: (id) => this.audio.play(id),
      spawnEntity: (kind, at) => {
        this.entities.spawn(kind, at);
      },
      spawnEntityAt: (kind, x, z) => {
        this.entities.spawnAt(kind, x, z);
      },
      weather: (kind, intensity, minutes) => {
        this.state.weather = makeWeather(kind, intensity ?? 0.7, minutes ?? 150);
        this.weatherKey = '';
        this.logMsg(
          `Clima: ${WEATHER_INFO[kind].label.toLowerCase()}. ${WEATHER_INFO[kind].desc}`,
          kind === 'clara' ? 'info' : 'warn',
        );
      },
      breakMachine: (id, sabotageFlavor) => {
        breakMachine(this.state, id, sabotageFlavor ? 0.8 : 0.5, sabotageFlavor);
        this.audio.play('fault');
      },
      trader: (active) => {
        if (active) {
          this.state.flags['comerciante_activo'] = true;
          this.level.showOffer(this.level.zoneAt(this.player.position));
        } else {
          delete this.state.flags['comerciante_activo'];
          this.level.hideOffer();
        }
      },
      grantCapture: (kind, origin) => this.grantEventCapture(kind, origin),
      fragment: (n) => this.addFragments(n),
      flash: (intensity) => this.hud.flash(intensity ?? 1),
      shake: (amount) => this.player.addShake(amount),
      moveDish: () => {
        const target = this.sources[Math.floor(Math.random() * this.sources.length)];
        if (!target) return;
        this.dish.sweeping = false;
        this.level.aimDish(target.az, target.el);
        this.dish.az = target.az;
        this.dish.el = target.el;
        this.logMsg('El plato se ha orientado solo a una fuente que no estaba en la carta.', 'warn');
      },
      radio: (text) => {
        this.hud.toast(text, 'info');
        this.logMsg(`RADIO · CONTROL: ${text}`, 'info');
        this.audio.beep(420);
      },
      save: () => this.saveNow(false),
    };
  }

  private onNewShift(day: number): void {
    this.regenerateSources();
    this.entities.clear();
    this.recording = null;
    this.dish.recording = false;
    this.dish.sweeping = false;
    this.selectedId = null;
    this.scanning = null;
    this.hud.setScan(null);
    this.level.setPower(this.state.power);
    this.audio.setPower(this.state.power);
    // El turno nuevo devuelve la motonieve a Kestrel y borra las medidas de ayer.
    this.resetMasts();
    this.triFixed = null;
    this.trip = null;
    this.level.clearOrigin();
    this.level.hideOffer();
    this.level.placeMoto('kestrel');
    this.weatherKey = '';
    this.player.teleport(6.4, 0, 3.6);
    this.player.setLook(2.4, 0);
    this.state.position = [6.4, 0, 3.6];
    const brief = dayBriefing(day)[0] ?? `Turno ${day}.`;
    this.hud.toast(brief, 'info');
  }

  /** Decisión del acto II: la UI pregunta y el resultado queda en el registro. */
  private onDecision(prompt: DecisionPrompt): void {
    if (this.panels.isOpen) this.panels.close();
    this.sim.paused = true;
    this.player.setEnabled(false);
    this.player.releaseLock();
    this.hud.showDecision(prompt, (optionId) => {
      const res = this.sim.resolveDecision(optionId);
      this.hud.toast(res.message, res.ok ? 'info' : 'warn');
      this.sim.paused = false;
      this.player.setEnabled(true);
      this.player.requestLock();
      this.saveNow(false);
    });
  }

  private onShiftSummary(summary: ShiftSummary): void {
    if (this.panels.isOpen) this.panels.close();
    this.sim.paused = true;
    this.player.setEnabled(false);
    this.player.releaseLock();
    this.hud.showSummary(summary, dayBriefing(summary.day + 1)[0] ?? '', () => {
      this.sim.paused = false;
      this.player.setEnabled(true);
      this.player.requestLock();
      this.saveNow(false);
    });
  }

  private onEnding(ending: EndingId): void {
    if (this.panels.isOpen) this.panels.close();
    this.sim.paused = true;
    this.player.setEnabled(false);
    this.player.releaseLock();
    this.audio.play('silence');
    this.hud.showEnding(ending, this.state, () => {
      clearSave(localStorage);
      window.location.reload();
    });
  }

  // ---------- depuración / verificación ----------

  debugOpenPanel(
    id: 'dish' | 'spectrum' | 'demod' | 'decoder' | 'pc' | 'tri' | 'travel' | 'trade' | 'log',
  ): void {
    this.openPanel(id === 'log' ? 'pc' : id, id === 'log' ? 'registro' : undefined);
  }

  debugGrantCapture(kind: SignalClass = 'BALIZA'): void {
    this.grantEventCapture(kind, 'evento');
  }

  /** Salto directo a un emplazamiento, sin esperar el trayecto. */
  debugTeleport(zone: ZoneName): void {
    const spot = arrivalFor(zone, this.triFixed?.x ?? 0, this.triFixed?.z ?? 0);
    this.trip = null;
    this.player.teleport(spot.x, 0, spot.z);
    this.level.placeMoto(zone);
    this.state.position = [spot.x, 0, spot.z];
  }

  debugFault(machine: MachineId = 'demod'): void {
    breakMachine(this.state, machine, 0.6, false);
  }

  debugWeather(kind: WeatherKind, intensity = 1): void {
    this.state.weather = makeWeather(kind, intensity, 200);
    this.weatherKey = '';
  }

  debugUnlockRepeater(): void {
    this.state.flags['repetidor_abierto'] = true;
  }

  debugSpawnOffer(): void {
    this.state.flags['comerciante_activo'] = true;
    this.level.showOffer(this.level.zoneAt(this.player.position));
  }

  /** Puntería perfecta en los tres mástiles y triangulación, para el smoke. */
  debugAutoTriangulate(): ActionResult {
    TRI_STATIONS.forEach((_, i) => {
      this.aimMast(i, this.trueBearing(i));
    });
    TRI_STATIONS.forEach((_, i) => this.lockMast(i));
    return this.triangulate();
  }

  debugSnapshot(): Record<string, unknown> {
    return {
      day: this.state.day,
      clock: clockLabel(this.state.clock),
      points: this.state.points,
      captures: this.state.captures.length,
      sources: this.sources.length,
      strength: this.dish.strength,
      panel: this.panels.current,
      started: this.started,
      entities: this.entities.entities.length,
      stress: Math.round(this.state.stress),
      weather: this.state.weather.kind,
      faults: Object.keys(this.state.faults).length,
      parts: this.state.parts,
      zone: this.level.zoneAt(this.player.position),
      tri: this.masts.filter((m) => m.locked).length,
      triFixed: this.triFixed ? { x: Math.round(this.triFixed.x), z: Math.round(this.triFixed.z), error: Math.round(this.triFixed.error) } : null,
      travel: this.trip ? this.trip.dest : null,
      decisions: this.state.decisions.length,
      trade: !!this.state.flags['comerciante_activo'],
    };
  }
}

declare global {
  interface Window {
    __estatica?: Game;
  }
}

const game = new Game();
window.__estatica = game;

window.addEventListener('beforeunload', () => {
  try {
    saveGame(game.state, localStorage);
  } catch {
    /* sin almacenamiento disponible */
  }
});

// Atajos de arranque para pruebas automatizadas (no visibles en la UI).
window.addEventListener('keydown', (e) => {
  if (e.ctrlKey && e.code === 'F9') {
    e.preventDefault();
    game.toast(JSON.stringify(game.debugSnapshot()), 'info');
  }
});
