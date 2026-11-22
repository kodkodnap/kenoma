import { describe, expect, it, vi } from 'vitest';
import {
  EVENTS,
  availableEvents,
  eventById,
  nextEventGap,
  pickEvent,
  runEvent,
  type EventHost,
} from '../src/core/events';
import { Rng } from '../src/core/rng';
import { createNewState } from '../src/core/state';

function host(): EventHost {
  return {
    toast: vi.fn(),
    log: vi.fn(),
    stress: vi.fn(),
    powerOut: vi.fn(),
    sound: vi.fn(),
    spawnEntity: vi.fn(),
    spawnEntityAt: vi.fn(),
    grantCapture: vi.fn(),
    fragment: vi.fn(),
    flash: vi.fn(),
    shake: vi.fn(),
    moveDish: vi.fn(),
    radio: vi.fn(),
    save: vi.fn(),
    weather: vi.fn(),
    breakMachine: vi.fn(),
    trader: vi.fn(),
  };
}

describe('catálogo de eventos', () => {
  it('los ids no se repiten', () => {
    const ids = EVENTS.map((e) => e.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('filtra por día mínimo', () => {
    const state = createNewState(1);
    state.day = 1;
    const day1 = availableEvents(state).map((e) => e.id);
    expect(day1).toContain('apagon');
    expect(day1).not.toContain('doble');
    expect(day1).not.toContain('silencio');
  });

  it('la respuesta solo aparece tras transmitir', () => {
    const state = createNewState(2);
    state.day = 5;
    expect(availableEvents(state).some((e) => e.id === 'respuesta')).toBe(false);
    state.stats.answered = 1;
    expect(availableEvents(state).some((e) => e.id === 'respuesta')).toBe(true);
  });

  it('los eventos de una sola vez se gastan', () => {
    const state = createNewState(3);
    state.day = 6;
    const ev = eventById('doble')!;
    const h = host();
    runEvent(ev, h, state, new Rng(1));
    expect(state.flags['ev_doble']).toBe(true);
    expect(availableEvents(state).some((e) => e.id === 'doble')).toBe(false);
  });

  it('el apagón corta la corriente y programa su duración', () => {
    const state = createNewState(4);
    const h = host();
    runEvent(eventById('apagon')!, h, state, new Rng(2));
    expect(h.powerOut).toHaveBeenCalled();
    expect(state.flags['apagon_pendiente']).toBe(true);
  });

  it('la figura del linde genera un contacto observable', () => {
    const state = createNewState(5);
    const h = host();
    runEvent(eventById('figura_linde')!, h, state, new Rng(3));
    expect(h.spawnEntity).toHaveBeenCalledWith('figura', 'treeline');
    expect(h.stress).toHaveBeenCalled();
  });

  it('la canción del servidor deja una captura de micrófono', () => {
    const state = createNewState(6);
    const h = host();
    runEvent(eventById('cancion_servidor')!, h, state, new Rng(4));
    expect(h.grantCapture).toHaveBeenCalledWith('BALIZA', 'microfono');
  });
});

describe('eventos de fase 2', () => {
  it('la tormenta fuerza el clima y suena a descarga', () => {
    const state = createNewState(11);
    state.day = 6;
    const h = host();
    runEvent(eventById('tormenta')!, h, state, new Rng(2));
    expect(h.weather).toHaveBeenCalledWith('tormenta', expect.any(Number), expect.any(Number));
    expect(h.sound).toHaveBeenCalledWith('thunder');
  });

  it('la ventisca borra las huellas de la noche', () => {
    const state = createNewState(12);
    state.day = 7;
    state.flags['huellas'] = true;
    runEvent(eventById('ventisca')!, host(), state, new Rng(3));
    expect(state.flags['huellas']).toBeUndefined();
  });

  it('el sabotaje deja una máquina fuera de servicio', () => {
    const state = createNewState(13);
    state.day = 8;
    const h = host();
    runEvent(eventById('sabotaje')!, h, state, new Rng(4));
    expect(h.breakMachine).toHaveBeenCalledTimes(1);
    expect(h.breakMachine).toHaveBeenCalledWith(expect.any(String), true);
    expect(state.flags['sabotaje']).toBe(1);
  });

  it('el comerciante abre el cajón del trueque', () => {
    const state = createNewState(14);
    state.day = 8;
    const h = host();
    runEvent(eventById('comerciante')!, h, state, new Rng(5));
    expect(h.spawnEntity).toHaveBeenCalledWith('comerciante', 'fence');
    expect(h.trader).toHaveBeenCalledWith(true);
  });

  it('el repetidor solo llama si ya está abierto', () => {
    const state = createNewState(15);
    state.day = 9;
    expect(availableEvents(state).some((e) => e.id === 'repetidor_llama')).toBe(false);
    state.flags['repetidor_abierto'] = true;
    expect(availableEvents(state).some((e) => e.id === 'repetidor_llama')).toBe(true);
  });

  it('el que aprende tu rutina aparece donde sueles estar', () => {
    const state = createNewState(16);
    state.day = 9;
    state.clock = 200;
    state.routine[1] = { x: 14, z: -3, weight: 80 };
    const h = host();
    runEvent(eventById('aprendiz')!, h, state, new Rng(6));
    expect(h.spawnEntityAt).toHaveBeenCalledWith('aprendiz', 14, -3);
  });
});

describe('programación', () => {
  it('pickEvent devuelve un evento disponible', () => {
    const state = createNewState(7);
    state.day = 5;
    const picked = pickEvent(state, new Rng(9));
    expect(picked).not.toBeNull();
    expect(availableEvents(state).some((e) => e.id === picked!.id)).toBe(true);
  });

  it('el hueco entre eventos es mayor al principio de la noche', () => {
    const rng = new Rng(123);
    const early = nextEventGap(60, rng);
    const deep = nextEventGap(320, rng);
    expect(early).toBeGreaterThan(12);
    expect(deep).toBeGreaterThanOrEqual(16);
    expect(early).toBeGreaterThan(deep);
  });

  it('runEvent incrementa el contador de encuentros', () => {
    const state = createNewState(8);
    const before = state.stats.events;
    runEvent(eventById('huellas')!, host(), state, new Rng(5));
    expect(state.stats.events).toBe(before + 1);
  });
});
