import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/rng';
import {
  SAVE_KEY,
  clearSave,
  createNewState,
  deserialize,
  hasSave,
  loadGame,
  markTaskProgress,
  saveGame,
  serialize,
  type StorageLike,
} from '../src/core/state';
import { makeCapture, syntheticSource } from '../src/core/signals';

function memoryStorage(): StorageLike & { data: Map<string, string> } {
  const data = new Map<string, string>();
  return {
    data,
    getItem: (k) => data.get(k) ?? null,
    setItem: (k, v) => void data.set(k, v),
    removeItem: (k) => void data.delete(k),
  };
}

describe('guardado', () => {
  it('roundtrip conserva el estado', () => {
    const storage = memoryStorage();
    const state = createNewState(123);
    state.points = 400;
    state.day = 3;
    state.fragments = 5;
    state.upgrades['plato'] = 2;
    state.captures.push(
      makeCapture(syntheticSource('VOZ', new Rng(1)), 71, 3, 40, new Rng(2)),
    );
    expect(saveGame(state, storage)).toBe(true);
    const loaded = loadGame(storage);
    expect(loaded).not.toBeNull();
    expect(loaded!.points).toBe(400);
    expect(loaded!.day).toBe(3);
    expect(loaded!.upgrades['plato']).toBe(2);
    expect(loaded!.captures).toHaveLength(1);
    expect(loaded!.captures[0]!.klass).toBe('VOZ');
  });

  it('rechaza JSON corrupto y claves vacías', () => {
    expect(deserialize('{no soy json')).toBeNull();
    expect(deserialize(null)).toBeNull();
    expect(deserialize('"texto"')).toBeNull();
    expect(deserialize('{"day":"tres"}')).toBeNull();
  });

  it('rellena campos que falten de versiones anteriores', () => {
    const partial = JSON.stringify({ day: 4, captures: [], points: 10 });
    const state = deserialize(partial);
    expect(state).not.toBeNull();
    expect(state!.day).toBe(4);
    expect(state!.stress).toBe(14);
    expect(state!.stats.decoded).toBe(0);
    expect(state!.quota.target).toBeGreaterThan(0);
  });

  it('sanea valores fuera de rango', () => {
    const raw = JSON.stringify({ day: 2, captures: [], stress: 500, points: -50 });
    const state = deserialize(raw)!;
    expect(state.stress).toBe(100);
    expect(state.points).toBe(0);
  });

  it('clearSave y hasSave funcionan sobre el almacenamiento', () => {
    const storage = memoryStorage();
    expect(hasSave(storage)).toBe(false);
    saveGame(createNewState(1), storage);
    expect(hasSave(storage)).toBe(true);
    clearSave(storage);
    expect(hasSave(storage)).toBe(false);
    expect(storage.data.has(SAVE_KEY)).toBe(false);
  });

  it('no revienta si el almacenamiento lanza errores', () => {
    const broken: StorageLike = {
      getItem: () => {
        throw new Error('bloqueado');
      },
      setItem: () => {
        throw new Error('lleno');
      },
      removeItem: () => {
        throw new Error('bloqueado');
      },
    };
    expect(saveGame(createNewState(1), broken)).toBe(false);
    expect(loadGame(broken)).toBeNull();
    expect(hasSave(broken)).toBe(false);
    expect(() => clearSave(broken)).not.toThrow();
  });

  it('serializa sin perder el RNG', () => {
    const state = createNewState(7);
    state.rngState = 123456;
    expect(deserialize(serialize(state))!.rngState).toBe(123456);
  });
});

describe('tareas', () => {
  it('marcar progreso paga la recompensa una sola vez', () => {
    const state = createNewState(10);
    state.tasks = [
      { id: 't', text: 'Decodifica 2', kind: 'decode', target: 2, progress: 0, reward: 50, done: false, base: 0 },
    ];
    markTaskProgress(state, 'decode');
    expect(state.points).toBe(0);
    markTaskProgress(state, 'decode');
    expect(state.points).toBe(50);
    expect(state.tasks[0]!.done).toBe(true);
  });
});
