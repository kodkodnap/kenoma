import { describe, expect, it } from 'vitest';
import { ensureRoutine, knowsRoutine, phaseBucket, recordRoutine, resetRoutine, routineSpot } from '../src/core/routine';
import { tradeCapture, tradeOffer } from '../src/core/economy';
import { Rng } from '../src/core/rng';
import { makeCapture, syntheticSource, STAGE } from '../src/core/signals';
import { createNewState } from '../src/core/state';

describe('rutina del operador', () => {
  it('cada tramo de la noche tiene su cubo', () => {
    expect(phaseBucket(10)).toBe(0);
    expect(phaseBucket(200)).toBe(1);
    expect(phaseBucket(400)).toBe(2);
    expect(phaseBucket(560)).toBe(3);
  });

  it('una sola muestra no basta para que el juego te conozca', () => {
    const state = createNewState(1);
    recordRoutine(state, 200, 4, 2);
    expect(routineSpot(state, 200)).toBeNull();
    expect(knowsRoutine(state, 200)).toBe(false);
  });

  it('la media converge al sitio donde pasas el rato', () => {
    const state = createNewState(2);
    for (let i = 0; i < 60; i++) recordRoutine(state, 200, 12 + i * 0.1, -6 + i * 0.05);
    const spot = routineSpot(state, 200);
    expect(spot).not.toBeNull();
    expect(spot!.x).toBeGreaterThan(12);
    expect(spot!.x).toBeLessThan(19);
    expect(spot!.weight).toBe(60);
  });

  it('el peso no crece sin límite y la rutina se puede olvidar', () => {
    const state = createNewState(3);
    for (let i = 0; i < 400; i++) recordRoutine(state, 200, 5, 5);
    expect(ensureRoutine(state)[1]!.weight).toBe(400);
    resetRoutine(state);
    expect(routineSpot(state, 200)).toBeNull();
  });

  it('un tramo aprendido no contamina a los demás', () => {
    const state = createNewState(4);
    for (let i = 0; i < 60; i++) recordRoutine(state, 200, 20, 20);
    expect(knowsRoutine(state, 200)).toBe(true);
    expect(knowsRoutine(state, 560)).toBe(false);
  });
});

describe('trueque del comerciante', () => {
  it('la oferta del día es determinista', () => {
    const state = createNewState(77);
    expect(tradeOffer(state)).toEqual(tradeOffer(state));
  });

  it('sin cajón abierto no hay trueque', () => {
    const state = createNewState(78);
    const cap = makeCapture(syntheticSource('VOZ', new Rng(1)), 80, 1, 30, new Rng(2));
    cap.stage = STAGE.DECODIFICADA;
    state.captures.push(cap);
    expect(tradeCapture(state, cap.id).ok).toBe(false);
  });

  it('acepta la captura pedida y no suma a la cuota', () => {
    const state = createNewState(79);
    state.flags['comerciante_activo'] = true;
    const offer = tradeOffer(state);
    const cap = makeCapture(syntheticSource(offer.wantsKlass ?? 'VOZ', new Rng(5)), 85, 1, 30, new Rng(6));
    cap.stage = STAGE.DECODIFICADA;
    cap.klass = offer.wantsKlass ?? cap.klass;
    state.captures.push(cap);
    const before = state.points;
    const res = tradeCapture(state, cap.id);
    expect(res.ok).toBe(true);
    expect(state.points).toBe(before + offer.reward);
    expect(state.fragments).toBe(offer.fragments);
    expect(state.parts).toBe(offer.parts);
    expect(state.quota.earned).toBe(0);
    expect(state.stats.barters).toBe(1);
    expect(state.captures[0]!.sold).toBe(true);
  });

  it('rechaza capturas sin decodificar', () => {
    const state = createNewState(80);
    state.flags['comerciante_activo'] = true;
    const cap = makeCapture(syntheticSource('BALIZA', new Rng(7)), 60, 1, 10, new Rng(8));
    state.captures.push(cap);
    expect(tradeCapture(state, cap.id).ok).toBe(false);
  });
});
