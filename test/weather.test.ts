import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/rng';
import { createNewState } from '../src/core/state';
import {
  advanceWeather,
  makeWeather,
  rollWeather,
  weatherDanger,
  weatherLabel,
  weatherNoise,
  weatherStressRate,
  weatherVisibility,
} from '../src/core/weather';

describe('clima', () => {
  it('el primer día no hay ventisca', () => {
    for (let seed = 0; seed < 80; seed++) {
      const weather = rollWeather(1, new Rng(seed));
      expect(['clara', 'niebla', 'tormenta']).toContain(weather.kind);
    }
  });

  it('a partir del día 6 la ventisca entra en el reparto', () => {
    const kinds = new Set<string>();
    for (let seed = 0; seed < 120; seed++) kinds.add(rollWeather(9, new Rng(seed + 500)).kind);
    expect(kinds.has('ventisca')).toBe(true);
  });

  it('el mismo día y la misma semilla dan el mismo clima', () => {
    expect(rollWeather(7, new Rng(42))).toEqual(rollWeather(7, new Rng(42)));
  });

  it('el temporizador baja y al agotarse rueda a otro clima', () => {
    const state = createNewState(3);
    state.weather = makeWeather('niebla', 0.8, 5);
    const rng = new Rng(7);
    let changed = false;
    for (let i = 0; i < 40; i++) {
      const tick = advanceWeather(state, 0.5, rng);
      if (tick.change === 'cambio') changed = true;
    }
    expect(changed).toBe(true);
    expect(state.weather.timer).toBeGreaterThan(0);
  });

  it('la tormenta acaba tirando la corriente', () => {
    const state = createNewState(4);
    state.weather = makeWeather('tormenta', 1, 400);
    const rng = new Rng(11);
    let outages = 0;
    for (let i = 0; i < 500; i++) {
      const tick = advanceWeather(state, 0.5, rng);
      if (tick.outageSeconds > 0) outages += 1;
    }
    expect(outages).toBeGreaterThan(0);
  });

  it('la ventisca borra las huellas al entrar', () => {
    // Se busca una semilla que dé ventisca al rodar para comprobar el efecto.
    const state = createNewState(5);
    state.day = 9;
    state.flags['huellas'] = true;
    let sawBlizzard = false;
    for (let seed = 0; seed < 200 && !sawBlizzard; seed++) {
      state.weather = { kind: 'clara', intensity: 0.3, timer: 0.01 };
      state.flags['huellas'] = true;
      advanceWeather(state, 0.5, new Rng(seed));
      if (state.weather.kind === 'ventisca') {
        sawBlizzard = true;
        expect(state.flags['huellas']).toBeUndefined();
      }
    }
    expect(sawBlizzard).toBe(true);
  });

  it('el ruido del clima escala con la intensidad y la ventisca mete más que la niebla', () => {
    const state = createNewState(6);
    state.weather = makeWeather('niebla', 1, 100);
    const fog = weatherNoise(state);
    state.weather = makeWeather('ventisca', 1, 100);
    const blizzard = weatherNoise(state);
    state.weather = makeWeather('ventisca', 0.4, 100);
    expect(blizzard).toBeGreaterThan(fog);
    expect(weatherNoise(state)).toBeLessThan(blizzard);
  });

  it('la visibilidad cae con la ventisca y el estrés sube fuera', () => {
    const state = createNewState(7);
    state.weather = makeWeather('ventisca', 1, 100);
    expect(weatherVisibility(state)).toBeLessThan(0.3);
    expect(weatherStressRate(state)).toBeGreaterThan(0);
    expect(weatherDanger(state)).toBeGreaterThan(1);
  });

  it('la etiqueta incluye el porcentaje en climas duros', () => {
    const state = createNewState(8);
    state.weather = makeWeather('tormenta', 0.6, 100);
    expect(weatherLabel(state)).toMatch(/60\s?%/);
  });
});
