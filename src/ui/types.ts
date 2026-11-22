import type { MachineId } from '../core/faults';
import type { Cipher, Capture, Modulation, SignalClass, SignalSource } from '../core/signals';
import type { EndingId, Sim } from '../core/sim';
import type { GameState, Quality } from '../core/state';
import type { WeatherKind } from '../core/weather';

export type ToastKind = 'info' | 'warn' | 'bad' | 'good';

export interface ActionResult {
  ok: boolean;
  message: string;
}

export interface DishTelemetry {
  az: number;
  el: number;
  strength: number;
  sourceLabel: string | null;
  locked: boolean;
  recording: boolean;
  progress: number;
  sweeping: boolean;
  /** Ruido que el clima añade a la banda, en unidades de fuerza. */
  noise: number;
}

export interface SkyBlip {
  az: number;
  el: number;
  strength: number;
}

export type TravelDest = 'kestrel' | 'repetidor' | 'origen';

export interface TravelOption {
  dest: TravelDest;
  label: string;
  detail: string;
  enabled: boolean;
}

export interface MastTelemetry {
  id: string;
  label: string;
  /** Apuntado actual, en grados. */
  aim: number;
  /** Calidad de la medida fijada (0 si no hay ninguna). */
  quality: number;
  locked: boolean;
  /** Intersección de los tres rumbos, si ya se ha resuelto. */
  x: number;
  z: number;
}

export interface TriTelemetry {
  masts: MastTelemetry[];
  /** Rumbos por encima del umbral. */
  locked: number;
  /** Fuerza de la aguja del mástil con el apuntado actual. */
  strengths: number[];
  /** Origen localizado (si se ha triangulado). */
  fixed: { x: number; z: number; spread: number; distance: number; name: string; klass: SignalClass } | null;
  /** ¿Se ha registrado ya el origen esta partida? */
  visited: boolean;
}

export interface TradeView {
  active: boolean;
  wantsLabel: string;
  wantsKlass: SignalClass | null;
  reward: number;
  fragments: number;
  parts: number;
  flavor: string;
  /** Capturas del archivador que el cajón aceptaría. */
  candidates: Capture[];
}

export interface GameApi {
  readonly state: GameState;
  readonly sim: Sim;
  readonly dish: DishTelemetry;
  readonly sources: SignalSource[];

  setDish(az: number, el: number): void;
  setSpectrumControl(center: number): void;
  getSpectrumControl(): number;
  getDemodulation(): Modulation;
  setDemodulation(modulation: Modulation): void;
  getCipher(): Cipher;
  setCipher(cipher: Cipher): void;
  toggleSweep(): void;
  startRecording(): void;
  cancelRecording(): void;

  selectedCapture(): Capture | null;
  selectCapture(id: string): void;
  isolate(center: number): ActionResult;
  demod(mod: Modulation): ActionResult;
  decode(cipher: Cipher): ActionResult;
  sell(id: string): void;
  archive(id: string): void;

  buy(id: string): void;
  buyPart(): ActionResult;
  calibrate(machine: MachineId): ActionResult;
  repair(machine: MachineId): ActionResult;
  drinkCoffee(): void;
  sleep(): void;
  transmit(): void;
  finish(ending: EndingId): void;

  /** Triangulación desde la consola del repetidor. */
  triTelemetry(): TriTelemetry;
  aimMast(index: number, az: number): void;
  lockMast(index: number): ActionResult;
  resetMasts(): void;
  triangulate(): ActionResult;

  /** Motonieve: desplazamiento entre emplazamientos. */
  travelOptions(): TravelOption[];
  travel(dest: TravelDest): ActionResult;
  traveling(): { active: boolean; progress: number; label: string };

  /** Trueque del comerciante. */
  tradeView(): TradeView;
  trade(captureId: string): ActionResult;

  weatherLabel(): string;
  weatherKind(): WeatherKind;

  skyBlips(): SkyBlip[];
  toast(text: string, kind?: ToastKind): void;
  sfx(id: string): void;
  closePanel(): void;
  storageLabel(): string;
  saveNow(): void;
  setQuality(q: Quality): void;
}
