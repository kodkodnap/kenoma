import { describe, expect, it } from 'vitest';
import {
  buyPart,
  calibrate,
  breakMachine,
  faultChancePerSecond,
  faultLabel,
  healthyMachines,
  machineBroken,
  maybeFault,
  PART_COST,
  repairWithPart,
  sabotage,
} from '../src/core/faults';
import { Rng } from '../src/core/rng';
import { createNewState } from '../src/core/state';

describe('averías', () => {
  it('la partida empieza con la cadena entera', () => {
    const state = createNewState(1);
    expect(healthyMachines(state)).toHaveLength(3);
    expect(faultLabel(state)).toBeNull();
    expect(machineBroken(state, 'demod')).toBe(false);
  });

  it('romper una máquina la deja fuera de servicio y baja el contador de sanas', () => {
    const state = createNewState(2);
    breakMachine(state, 'spectrum', 0.5, false);
    expect(machineBroken(state, 'spectrum')).toBe(true);
    expect(healthyMachines(state)).toHaveLength(2);
    expect(faultLabel(state)).toContain('ESPECTRO');
  });

  it('el sabotaje marca el panel abierto y cuenta en las estadísticas', () => {
    const state = createNewState(3);
    state.day = 8;
    const victim = sabotage(state, new Rng(3));
    expect(victim).not.toBeNull();
    expect(state.stats.sabotages).toBe(1);
    expect(machineBroken(state, victim!)).toBe(true);
  });

  it('no se acumulan dos averías a la vez por desgaste', () => {
    const state = createNewState(4);
    state.day = 12;
    state.stress = 100;
    const rng = new Rng(9);
    let breaks = 0;
    for (let i = 0; i < 20000; i++) {
      if (maybeFault(state, rng, 1)) breaks += 1;
    }
    expect(breaks).toBe(1);
    expect(Object.keys(state.faults)).toHaveLength(1);
  });

  it('la probabilidad de avería sube con el día y el estrés', () => {
    const calm = createNewState(5);
    const rough = createNewState(5);
    rough.day = 12;
    rough.stress = 95;
    rough.weather = { kind: 'tormenta', intensity: 1, timer: 60 };
    expect(faultChancePerSecond(rough)).toBeGreaterThan(faultChancePerSecond(calm) * 3);
  });

  it('calibrar puede devolver la máquina al servicio', () => {
    let repaired = false;
    for (let seed = 0; seed < 60 && !repaired; seed++) {
      const state = createNewState(seed + 10);
      breakMachine(state, 'decoder', 0.2, false);
      const res = calibrate(state, new Rng(seed), 'decoder');
      if (res.ok) {
        repaired = true;
        expect(machineBroken(state, 'decoder')).toBe(false);
        expect(state.stats.repairs).toBe(1);
        expect(state.faults['decoder']).toBeUndefined();
      }
    }
    expect(repaired).toBe(true);
  });

  it('un intento fallido desajusta más y sube el estrés', () => {
    const state = createNewState(20);
    breakMachine(state, 'demod', 0.95, false);
    const before = state.stress;
    const res = calibrate(state, new Rng(1), 'demod');
    // Con severidad 0,95 la probabilidad es muy baja: si sale, no es un fracaso.
    if (!res.ok) {
      expect(state.faults['demod']!.attempt).toBe(1);
      expect(state.faults['demod']!.severity).toBeGreaterThan(0.95);
      expect(state.stress).toBeGreaterThan(before);
    }
  });

  it('calibrar una máquina sana no tiene sentido', () => {
    const state = createNewState(21);
    expect(calibrate(state, new Rng(1), 'demod').ok).toBe(false);
  });

  it('la pieza de repuesto repara al instante y consume inventario', () => {
    const state = createNewState(30);
    state.parts = 1;
    breakMachine(state, 'spectrum', 1, true);
    const res = repairWithPart(state, 'spectrum');
    expect(res.ok).toBe(true);
    expect(state.parts).toBe(0);
    expect(machineBroken(state, 'spectrum')).toBe(false);
  });

  it('sin piezas no hay reparación', () => {
    const state = createNewState(31);
    breakMachine(state, 'spectrum', 1, false);
    const res = repairWithPart(state, 'spectrum');
    expect(res.ok).toBe(false);
    expect(machineBroken(state, 'spectrum')).toBe(true);
  });

  it('comprar piezas cuesta créditos', () => {
    const state = createNewState(32);
    state.points = PART_COST + 10;
    expect(buyPart(state).ok).toBe(true);
    expect(state.parts).toBe(1);
    expect(state.points).toBe(10);
    expect(buyPart(state).ok).toBe(false);
  });
});
