// Economía: mejoras de la estación, venta de capturas decodificadas y el
// trueque del comerciante (fase 2).

import { Rng } from './rng';
import { addPoints, GameState, markTaskProgress } from './state';
import { CLASS_INFO, STAGE, saleValue, type SignalClass } from './signals';

export interface UpgradeDef {
  id: string;
  name: string;
  desc: string;
  max: number;
  baseCost: number;
  growth: number;
}

export const UPGRADES: UpgradeDef[] = [
  {
    id: 'plato',
    name: 'Ganancia del plato',
    desc: 'Amplía la huella de recepción: fija fuentes débiles y mejora la integridad de la captura.',
    max: 4,
    baseCost: 140,
    growth: 1.85,
  },
  {
    id: 'filtro',
    name: 'Filtro de banda',
    desc: 'Ventana del analizador más tolerante. Menos pérdida al aislar la portadora.',
    max: 4,
    baseCost: 120,
    growth: 1.9,
  },
  {
    id: 'demod',
    name: 'Demodulador',
    desc: 'Recupera integridad al acertar la modulación y reduce el daño de un fallo.',
    max: 3,
    baseCost: 180,
    growth: 2.0,
  },
  {
    id: 'generador',
    name: 'Grupo electrógeno',
    desc: 'Arranque automático: apagones más raros y más cortos.',
    max: 3,
    baseCost: 130,
    growth: 2.0,
  },
  {
    id: 'luz',
    name: 'Torretas de luz',
    desc: 'Iluminación exterior estable: baja el estrés cerca de los focos y molesta a lo que observa.',
    max: 3,
    baseCost: 110,
    growth: 1.9,
  },
  {
    id: 'cafe',
    name: 'Cafetera',
    desc: 'Una taza decente. Recupera más estrés por uso.',
    max: 3,
    baseCost: 90,
    growth: 1.8,
  },
  {
    id: 'traje',
    name: 'Traje térmico',
    desc: 'El frío y el contacto con lo desconocido te afectan menos.',
    max: 3,
    baseCost: 160,
    growth: 2.1,
  },
];

export function level(state: GameState, id: string): number {
  return state.upgrades[id] ?? 0;
}

export function upgradeDef(id: string): UpgradeDef | undefined {
  return UPGRADES.find((u) => u.id === id);
}

export function upgradeCost(state: GameState, id: string): number {
  const def = upgradeDef(id);
  if (!def) return Infinity;
  const lvl = level(state, id);
  return Math.round(def.baseCost * Math.pow(def.growth, lvl));
}

export interface Purchase {
  ok: boolean;
  message: string;
}

export function buyUpgrade(state: GameState, id: string): Purchase {
  const def = upgradeDef(id);
  if (!def) return { ok: false, message: 'Mejora desconocida.' };
  const lvl = level(state, id);
  if (lvl >= def.max) return { ok: false, message: `${def.name} ya está al máximo.` };
  const cost = upgradeCost(state, id);
  if (state.points < cost) return { ok: false, message: `Faltan ${cost - state.points} créditos.` };
  addPoints(state, -cost);
  state.upgrades[id] = lvl + 1;
  return { ok: true, message: `${def.name} → nivel ${lvl + 1}.` };
}

export interface Sale {
  ok: boolean;
  value: number;
  message: string;
}

export function sellCapture(state: GameState, captureId: string): Sale {
  const cap = state.captures.find((c) => c.id === captureId);
  if (!cap) return { ok: false, value: 0, message: 'Captura no encontrada.' };
  if (cap.sold) return { ok: false, value: 0, message: 'Ya se vendió.' };
  if (cap.stage < 3) return { ok: false, value: 0, message: 'Falta terminarla de decodificar.' };
  const value = saleValue(cap);
  cap.sold = true;
  addPoints(state, value);
  state.quota.earned += value;
  state.stats.sold += 1;
  markTaskProgress(state, 'sell', 1);
  return {
    ok: true,
    value,
    message: value > 0 ? `Transferencia completada: +${value} créditos.` : 'Archivada. Sin valor de mercado.',
  };
}

/** Archiva sin vender (las señales de valor 0). */
export function archiveCapture(state: GameState, captureId: string): void {
  const cap = state.captures.find((c) => c.id === captureId);
  if (cap) cap.sold = true;
}

export function coffeeGain(state: GameState): number {
  return 12 + level(state, 'cafe') * 7;
}

export function activeCaptures(state: GameState): number {
  return state.captures.filter((c) => !c.sold).length;
}

/** Huecos de trabajo en el archivador. Se amplía con mejoras futuras. */
export function capacity(state: GameState): number {
  return 8 + level(state, 'demod') * 2;
}

// ---------- trueque del comerciante ----------

export interface TradeOffer {
  id: string;
  /** Clase que pide, o null si acepta cualquier captura decodificada. */
  wantsKlass: SignalClass | null;
  wantsLabel: string;
  reward: number;
  fragments: number;
  parts: number;
  flavor: string;
}

/** La oferta del día: determinista, para que el guardado la reproduzca. */
export function tradeOffer(state: GameState): TradeOffer {
  const rng = new Rng((state.seed ^ (state.day * 7919)) >>> 0);
  const klass = rng.pick<SignalClass>(['VOZ', 'ANOMALO', 'BALIZA', 'TELEMETRIA']);
  const reward = 110 + state.day * 24 + rng.int(0, 40);
  return {
    id: `trueque-${state.day}`,
    wantsKlass: klass,
    wantsLabel: `una captura de ${CLASS_INFO[klass].label.toLowerCase()} ya decodificada`,
    reward,
    fragments: klass === 'ANOMALO' ? 2 : 1,
    parts: rng.chance(0.55) ? 1 : 0,
    flavor: rng.pick([
      'La lista está escrita con una letra que ya has visto en el registro.',
      'El cajón tiene una tapa de madera y ningún cierre. Dentro espera una cinta vacía.',
      'Junto a la lista hay una piedra pulida, del tamaño de un puño.',
    ]),
  };
}

export interface TradeResult {
  ok: boolean;
  message: string;
}

/**
 * Entrega una captura a cambio de lo que ofrece el cajón. No suma a la cuota:
 * el trueque es dinero de bolsillo, no cuenta de Control.
 */
export function tradeCapture(state: GameState, captureId: string): TradeResult {
  if (!state.flags['comerciante_activo']) {
    return { ok: false, message: 'No hay ningún cajón pendiente en el porche.' };
  }
  const cap = state.captures.find((c) => c.id === captureId);
  if (!cap) return { ok: false, message: 'Captura no encontrada.' };
  if (cap.sold) return { ok: false, message: 'Esa captura ya no está en el archivador.' };
  if (cap.stage < STAGE.DECODIFICADA) return { ok: false, message: 'El cajón solo acepta capturas terminadas de decodificar.' };
  const offer = tradeOffer(state);
  if (offer.wantsKlass && cap.klass !== offer.wantsKlass) {
    return { ok: false, message: `El cajón ha pedido ${offer.wantsLabel}.` };
  }

  cap.sold = true;
  addPoints(state, offer.reward);
  state.fragments += offer.fragments;
  state.parts += offer.parts;
  state.stats.barters += 1;
  const extra = [offer.parts > 0 ? '+1 pieza' : '', offer.fragments > 0 ? `+${offer.fragments} fragmento(s)` : ''].filter(Boolean).join(' · ');
  return {
    ok: true,
    message: `Trueque cerrado: +${offer.reward} créditos, ${extra}. El cajón se cierra solo.`,
  };
}
