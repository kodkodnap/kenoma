// Clima del valle (fase 2). Puro: no conoce DOM ni Three.js.
// La tormenta sube el ruido de banda ancha y tira la corriente; la ventisca
// borra huellas y contactos del exterior. Todo determinista vía Rng.

import { Rng } from './rng';
import type { GameState } from './state';
import { GAME_MIN_PER_SECOND } from './time';

export type WeatherKind = 'clara' | 'niebla' | 'tormenta' | 'ventisca';

export interface WeatherState {
  kind: WeatherKind;
  /** 0..1: cuánto aprieta. Escala ruido, nieve y penalizaciones. */
  intensity: number;
  /** Minutos de juego que quedan con este clima. */
  timer: number;
}

export interface WeatherInfo {
  label: string;
  desc: string;
  /** Ruido añadido a la recepción, en unidades de fuerza. */
  noise: number;
  /** Estrés extra por segundo al estar fuera. */
  stress: number;
  /** Multiplicador de visibilidad (niebla del mundo). */
  visibility: number;
  /** Densidad relativa de nieve y viento para la escena y el audio. */
  snow: number;
  wind: number;
}

export const WEATHER_INFO: Record<WeatherKind, WeatherInfo> = {
  clara: {
    label: 'Cielo abierto',
    desc: 'Sin precipitación. El cielo está limpio y la banda, silenciosa.',
    noise: 0,
    stress: 0,
    visibility: 1,
    snow: 0.55,
    wind: 0.5,
  },
  niebla: {
    label: 'Niebla',
    desc: 'El valle se cierra. La recepción pierde definición y el linde queda a oscuras.',
    noise: 6,
    stress: 0.01,
    visibility: 0.45,
    snow: 0.7,
    wind: 0.28,
  },
  tormenta: {
    label: 'Tormenta',
    desc: 'Descargas: ruido de banda ancha, estática en el demodulador y cortes de luz.',
    noise: 26,
    stress: 0.02,
    visibility: 0.5,
    snow: 1.15,
    wind: 1.35,
  },
  ventisca: {
    label: 'Ventisca',
    desc: 'El viento borra las huellas, tapa el linde y clava la aguja en el fondo de escala.',
    noise: 34,
    stress: 0.03,
    visibility: 0.22,
    snow: 1.7,
    wind: 1.85,
  },
};

export type WeatherChange = 'cambio' | 'descarga' | null;

export function makeWeather(kind: WeatherKind, intensity: number, duration: number): WeatherState {
  return { kind, intensity: Math.max(0.15, Math.min(1, intensity)), timer: Math.max(4, duration) };
}

/**
 * Elige el clima del tramo. A partir del día 6 el valle empeora: niebla y
 * tormenta ganan peso y la ventisca aparece. Puro y reproducible.
 */
export function rollWeather(day: number, rng: Rng, previous?: WeatherKind): WeatherState {
  const weights: { item: WeatherKind; weight: number }[] = [
    { item: 'clara', weight: day < 6 ? 40 : Math.max(10, 34 - (day - 5) * 3) },
    { item: 'niebla', weight: day < 3 ? 8 : 16 + (day - 2) * 1.6 },
    { item: 'tormenta', weight: day < 6 ? 6 : 12 + (day - 5) * 2.4 },
    { item: 'ventisca', weight: day < 6 ? 0 : 6 + (day - 6) * 2.6 },
  ];
  const kind = rng.weighted(weights) ?? 'clara';
  // Repetir el mismo clima seguido aburre: si toca otra vez, se acorta.
  const duration =
    kind === previous ? rng.range(40, 70) : kind === 'clara' ? rng.range(120, 210) : rng.range(70, 160);
  return makeWeather(kind, kind === 'clara' ? 0.3 : rng.range(0.45, 1), duration);
}

export interface WeatherTick {
  change: WeatherChange;
  /** Si el clima pide un corte de corriente en este tramo. */
  outageSeconds: number;
}

/**
 * Avanza el clima del turno. La tormenta tira el grupo electrógeno de vez en
 * cuando (coste en la estación, no en el reloj) y la ventisca borra huellas.
 */
export function advanceWeather(state: GameState, dt: number, rng: Rng): WeatherTick {
  const w = state.weather;
  const elapsedMin = dt * GAME_MIN_PER_SECOND;
  w.timer -= elapsedMin;
  let change: WeatherChange = null;
  if (w.timer <= 0) {
    const next = rollWeather(state.day, rng, w.kind);
    state.weather = next;
    change = 'cambio';
    if (next.kind === 'ventisca') {
      // La ventisca borra el rastro del exterior: huellas y pasos del linde.
      delete state.flags['huellas'];
      state.flags['ventisca_borro_huellas'] = true;
    }
  }

  let outageSeconds = 0;
  if (w.kind === 'tormenta' && rng.chance(dt * 0.012 * (0.5 + w.intensity))) {
    outageSeconds = Math.round(14 + w.intensity * 22 - (state.upgrades['generador'] ?? 0) * 5);
    change = change ?? 'descarga';
  }
  return { change, outageSeconds };
}

/** Ruido que el clima añade a la fuerza de señal (resta, por tanto). */
export function weatherNoise(state: GameState): number {
  const info = WEATHER_INFO[state.weather.kind];
  return info.noise * state.weather.intensity;
}

/** Estrés extra por segundo cuando el jugador está fuera. */
export function weatherStressRate(state: GameState): number {
  return WEATHER_INFO[state.weather.kind].stress * state.weather.intensity;
}

/** Multiplicador de niebla para la escena. */
export function weatherVisibility(state: GameState): number {
  const info = WEATHER_INFO[state.weather.kind];
  return 1 - (1 - info.visibility) * state.weather.intensity;
}

/** Etiqueta corta para el HUD. */
export function weatherLabel(state: GameState): string {
  const info = WEATHER_INFO[state.weather.kind];
  return state.weather.kind === 'clara' ? info.label : `${info.label} ${Math.round(state.weather.intensity * 100)}%`;
}

/** Índice de peligro del clima: alimenta los pesos de los eventos. */
export function weatherDanger(state: GameState): number {
  switch (state.weather.kind) {
    case 'clara':
      return 1;
    case 'niebla':
      return 1.15;
    case 'tormenta':
      return 1.4;
    case 'ventisca':
      return 1.6;
  }
}
