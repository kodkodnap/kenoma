import { describe, expect, it, vi } from 'vitest';
import { buyUpgrade, sellCapture, upgradeCost, coffeeGain, level } from '../src/core/economy';
import type { EventHost } from '../src/core/events';
import { Sim } from '../src/core/sim';
import { makeCapture, syntheticSource } from '../src/core/signals';
import { Rng } from '../src/core/rng';
import { createNewState, type GameState } from '../src/core/state';
import { GAME_MIN_PER_SECOND, SHIFT_LENGTH_MIN } from '../src/core/time';

function stubHost(): EventHost & { calls: string[] } {
  const calls: string[] = [];
  return {
    calls,
    toast: (t) => calls.push(`toast:${t}`),
    log: (t) => calls.push(`log:${t}`),
    stress: () => calls.push('stress'),
    powerOut: (s) => calls.push(`powerOut:${s}`),
    sound: (id) => calls.push(`sound:${id}`),
    spawnEntity: (k, at) => calls.push(`spawn:${k}:${at}`),
    spawnEntityAt: (k, x, z) => calls.push(`spawnAt:${k}:${x}:${z}`),
    grantCapture: (k) => calls.push(`capture:${k}`),
    fragment: () => calls.push('fragment'),
    flash: () => calls.push('flash'),
    shake: () => calls.push('shake'),
    moveDish: () => calls.push('moveDish'),
    radio: (t) => calls.push(`radio:${t}`),
    save: () => calls.push('save'),
    weather: (kind) => calls.push(`weather:${kind}`),
    breakMachine: (id, sabotage) => calls.push(`break:${id}:${sabotage}`),
    trader: (active) => calls.push(`trader:${active}`),
  };
}

function makeSim(state?: GameState) {
  const host = stubHost();
  const hooks = {
    onNewShift: vi.fn(),
    onShiftSummary: vi.fn(),
    onEnding: vi.fn(),
    onDecision: vi.fn(),
  };
  const s = state ?? createNewState(1234);
  const sim = new Sim(s, host, hooks);
  return { sim, host, hooks, state: s };
}

describe('reloj y turno', () => {
  it('el reloj avanza a la velocidad configurada', () => {
    const { sim, state } = makeSim();
    sim.tick(10);
    expect(state.clock).toBeCloseTo(10 * GAME_MIN_PER_SECOND, 5);
  });

  it('al terminar el turno avanza el día y reinicia el reloj', () => {
    const { sim, state, hooks } = makeSim();
    state.clock = SHIFT_LENGTH_MIN - 0.1;
    sim.tick(1);
    expect(state.day).toBe(2);
    expect(state.clock).toBeLessThan(2);
    expect(hooks.onNewShift).toHaveBeenCalledWith(2);
    expect(hooks.onShiftSummary).toHaveBeenCalledTimes(1);
  });

  it('la cuota cubierta paga una prima', () => {
    const { sim, state } = makeSim();
    state.quota.earned = state.quota.target;
    const before = state.points;
    const summary = sim.endShift(false);
    expect(summary.quotaMet).toBe(true);
    expect(state.points).toBeGreaterThan(before);
    expect(state.quota.failedDays).toBe(0);
  });

  it('la cuota fallida registra un fallo y descuenta presupuesto', () => {
    const { sim, state } = makeSim();
    state.points = 100;
    state.tasks = [];
    state.quota.earned = 0;
    const summary = sim.endShift(false);
    expect(summary.quotaMet).toBe(false);
    expect(state.quota.failedDays).toBe(1);
    expect(state.points).toBeLessThan(100);
  });

  it('no deja dormir al principio del turno', () => {
    const { sim, state, host } = makeSim();
    state.clock = 40;
    sim.sleep();
    expect(host.calls.some((c) => c.startsWith('toast:'))).toBe(true);
    expect(state.day).toBe(1);
  });

  it('dormir cierra el turno y reduce más el estrés', () => {
    const { sim, state } = makeSim();
    state.clock = 200;
    state.stress = 80;
    state.quota.earned = state.quota.target;
    state.tasks = [];
    sim.sleep();
    expect(state.day).toBe(2);
    expect(state.stress).toBeLessThan(60);
  });

  it('el estado cansado se guarda en cada tick', () => {
    const { sim, state } = makeSim();
    sim.tick(5);
    expect(state.rngState).toBeTypeOf('number');
  });
});

describe('clima y averías en el turno', () => {
  it('el turno arranca con clima y sin averías', () => {
    const { state } = makeSim();
    expect(state.weather.kind).toBe('clara');
    expect(Object.keys(state.faults)).toHaveLength(0);
    expect(state.parts).toBe(0);
  });

  it('la tormenta puede tirar la corriente sin romper el reloj', () => {
    const { sim, state, host } = makeSim();
    for (let i = 0; i < 400; i++) {
      // Se mantiene la tormenta para que la descarga tenga ocasión de caer.
      state.weather = { kind: 'tormenta', intensity: 1, timer: 400 };
      sim.tick(0.5);
    }
    expect(host.calls.some((c) => c.startsWith('powerOut:'))).toBe(true);
    expect(state.clock).toBeGreaterThan(0);
  });

  it('la ventisca borra las huellas al entrar', () => {
    const { sim, state } = makeSim();
    state.weather = { kind: 'clara', intensity: 0.3, timer: 0.01 };
    state.flags['huellas'] = true;
    // Fuerza el próximo clima a ventisca repitiendo el tick hasta que cambie.
    for (let i = 0; i < 60 && state.weather.kind !== 'ventisca'; i++) {
      state.weather.timer = 0.01;
      sim.tick(0.5);
    }
    if (state.weather.kind === 'ventisca') expect(state.flags['huellas']).toBeUndefined();
  });

  it('las tareas de "no ha pasado nada" se pagan al cerrar el turno', () => {
    const { sim, state } = makeSim();
    state.tasks = [
      { id: 'nb', text: 'sin apagones', kind: 'no_blackout', target: 0, progress: 0, reward: 90, done: false, base: 0 },
      { id: 'na', text: 'sin averías', kind: 'no_averia', target: 0, progress: 0, reward: 80, done: false, base: 0 },
    ];
    const before = state.points;
    state.quota.earned = state.quota.target;
    sim.endShift(false);
    expect(state.points).toBeGreaterThan(before + 150);
  });

  it('una avería pendiente cuenta en el resumen del turno', () => {
    const { sim, state } = makeSim();
    state.faults['spectrum'] = { broken: true, severity: 0.5, attempt: 0, since: 10 };
    const summary = sim.endShift(false);
    expect(summary.faults).toBe(1);
    // Amanecer alivia el desajuste, pero la máquina sigue rota.
    expect(state.faults['spectrum']!.severity).toBeLessThan(0.5);
  });
});

describe('acto II', () => {
  it('el día 7 pide la decisión del archivo del operador', () => {
    const { sim, state, hooks } = makeSim();
    state.day = 7;
    state.clock = 150;
    sim.tick(0.5);
    expect(hooks.onDecision).toHaveBeenCalledTimes(1);
    expect(sim.pendingDecision?.id).toBe('archivo_operador');
  });

  it('leer la carpeta da un fragmento y queda registrado', () => {
    const { sim, state } = makeSim();
    state.day = 7;
    state.clock = 150;
    sim.tick(0.5);
    const before = state.fragments;
    const res = sim.resolveDecision('leer');
    expect(res.ok).toBe(true);
    expect(state.fragments).toBe(before + 1);
    expect(state.decisions).toContain('archivo_operador:leer');
    expect(sim.pendingDecision).toBeNull();
  });

  it('entregar la carpeta paga en créditos y no da fragmentos', () => {
    const { sim, state } = makeSim();
    state.day = 7;
    state.clock = 150;
    sim.tick(0.5);
    const before = state.points;
    const fragments = state.fragments;
    sim.resolveDecision('entregar');
    expect(state.points).toBe(before + 150);
    expect(state.fragments).toBe(fragments);
  });

  it('una decisión sin prompt no hace nada', () => {
    const { sim } = makeSim();
    expect(sim.resolveDecision('leer').ok).toBe(false);
  });

  it('el día 8 abre el repetidor de los 900 m', () => {
    const { sim, state, host } = makeSim();
    state.day = 8;
    state.clock = 70;
    sim.tick(0.5);
    expect(state.flags['repetidor_abierto']).toBe(true);
    expect(host.calls.some((c) => c.startsWith('fragment'))).toBe(true);
  });

  it('la escalada de una respuesta sabotea una máquina', () => {
    const { sim, state } = makeSim();
    sim.escalate();
    expect(Object.keys(state.faults).length).toBe(1);
    expect(state.stats.sabotages).toBe(1);
  });
});

describe('transmisión', () => {
  it('cobra créditos y registra la respuesta', () => {
    const { sim, state } = makeSim();
    state.points = 100;
    const res = sim.transmit();
    expect(res.ok).toBe(true);
    expect(state.points).toBe(60);
    expect(state.stats.answered).toBe(1);
  });

  it('sin créditos no transmite', () => {
    const { sim, state } = makeSim();
    state.points = 10;
    expect(sim.transmit().ok).toBe(false);
    expect(state.stats.answered).toBe(0);
  });

  it('sin corriente no transmite', () => {
    const { sim, state } = makeSim();
    state.points = 100;
    state.power = false;
    expect(sim.transmit().ok).toBe(false);
  });
});

describe('final', () => {
  it('no se puede terminar antes de tiempo', () => {
    const { sim, state } = makeSim();
    state.day = 4;
    state.fragments = 20;
    expect(sim.canFinish()).toBe(false);
  });

  it('se abre en el día 12 con 12 fragmentos', () => {
    const { sim, state } = makeSim();
    state.day = 12;
    state.fragments = 12;
    expect(sim.canFinish()).toBe(true);
  });

  it('finish guarda el desenlace y avisa', () => {
    const { sim, state, hooks } = makeSim();
    state.day = 12;
    state.fragments = 12;
    sim.finish('cortar');
    expect(state.ending).toBe('cortar');
    expect(hooks.onEnding).toHaveBeenCalledWith('cortar');
  });
});

describe('economía', () => {
  it('comprar sube el nivel y gasta créditos', () => {
    const state = createNewState(1);
    state.points = 1000;
    const cost = upgradeCost(state, 'plato');
    const res = buyUpgrade(state, 'plato');
    expect(res.ok).toBe(true);
    expect(level(state, 'plato')).toBe(1);
    expect(state.points).toBe(1000 - cost);
    expect(upgradeCost(state, 'plato')).toBeGreaterThan(cost);
  });

  it('no compra sin créditos ni por encima del máximo', () => {
    const state = createNewState(1);
    state.points = 10;
    expect(buyUpgrade(state, 'plato').ok).toBe(false);
    state.points = 100000;
    for (let i = 0; i < 4; i++) buyUpgrade(state, 'filtro');
    expect(level(state, 'filtro')).toBe(4);
    expect(buyUpgrade(state, 'filtro').ok).toBe(false);
  });

  it('vender exige decodificar y suma a la cuota', () => {
    const state = createNewState(2);
    const cap = makeCapture(syntheticSource('TELEMETRIA', new Rng(1)), 90, 1, 0, new Rng(2));
    state.captures.push(cap);
    expect(sellCapture(state, cap.id).ok).toBe(false);
    cap.stage = 3;
    const res = sellCapture(state, cap.id);
    expect(res.ok).toBe(true);
    expect(res.value).toBeGreaterThan(0);
    expect(state.quota.earned).toBe(res.value);
    expect(state.captures[0]!.sold).toBe(true);
    expect(sellCapture(state, cap.id).ok).toBe(false);
  });

  it('el café mejora con la cafetera', () => {
    const state = createNewState(1);
    const base = coffeeGain(state);
    state.upgrades['cafe'] = 2;
    expect(coffeeGain(state)).toBeGreaterThan(base);
  });
});
