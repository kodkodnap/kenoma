// Modelo puro de señales: fuentes en el cielo, captura y cadena de decodificación.
// Nada aquí toca el DOM ni Three.js: es lógica testeable.

import { Rng, hashString } from './rng';

export type Modulation = 'AM' | 'FM' | 'PULSO' | 'COHERENTE';
export type Cipher = 'BASE' | 'ARMONICO' | 'RECURSIVO' | 'VACIO';
export type SignalClass = 'RUIDO' | 'TELEMETRIA' | 'BALIZA' | 'VOZ' | 'ANOMALO' | 'VACIO';

/** Etapa del pipeline. */
export const STAGE = {
  CRUDA: 0,
  AISLADA: 1,
  DEMODULADA: 2,
  DECODIFICADA: 3,
} as const;

export interface SignalSource {
  id: string;
  /** Nombre real; solo se revela al decodificar. */
  name: string;
  az: number; // 0..360
  el: number; // 5..85
  band: number; // MHz
  modulation: Modulation;
  cipher: Cipher;
  klass: SignalClass;
  text: string;
  /** Valor base antes de multiplicar por calidad. */
  base: number;
  /** Tamaño aparente (grados). Fuentes más pequeñas cuestan más de fijar. */
  sharpness: number;
}

export interface Capture {
  id: string;
  sourceId: string;
  name: string;
  klass: SignalClass;
  band: number;
  modulation: Modulation;
  cipher: Cipher;
  quality: number;
  corruption: number;
  stage: number;
  createdDay: number;
  createdClock: number;
  text: string;
  /** Ya vendida/archivada: no ocupa hueco de trabajo. */
  sold: boolean;
  failedAttempts: number;
  /** Método por el que se obtuvo: antena, micrófono, evento. */
  origin: 'antena' | 'microfono' | 'evento';
}

export const MODULATIONS: Modulation[] = ['AM', 'FM', 'PULSO', 'COHERENTE'];
export const CIPHERS: Cipher[] = ['BASE', 'ARMONICO', 'RECURSIVO', 'VACIO'];

export const CIPHER_INFO: Record<Cipher, { name: string; signature: string; hint: string }> = {
  BASE: {
    name: 'Lenguaje directo',
    signature: 'Sintaxis natural intacta. Sin desplazamiento ni inversión.',
    hint: 'No hay transformación: el texto ya está en claro.',
  },
  ARMONICO: {
    name: 'Desplazamiento armónico',
    signature: 'Sintaxis natural con desfase constante en cada símbolo del alfabeto.',
    hint: 'Cada letra está desplazada un número fijo de posiciones.',
  },
  RECURSIVO: {
    name: 'Lectura recursiva',
    signature: 'El final y el principio se continúan; el orden interno está invertido.',
    hint: 'El mensaje está escrito del final hacia el principio.',
  },
  VACIO: {
    name: 'Glifos del vacío',
    signature: 'Los símbolos no pertenecen a ningún alfabeto registrado.',
    hint: 'Necesitas la tabla de glifos recuperada en campo para traducirlo entero.',
  },
};

export const CLASS_INFO: Record<
  SignalClass,
  { label: string; color: string; fragments: number; glyph: string }
> = {
  RUIDO: { label: 'Ruido', color: '#5f6b66', fragments: 0, glyph: '≈' },
  TELEMETRIA: { label: 'Telemetría', color: '#7fd1c7', fragments: 0, glyph: '⌁' },
  BALIZA: { label: 'Baliza', color: '#e0c368', fragments: 1, glyph: '✳' },
  VOZ: { label: 'Voz', color: '#e08f6a', fragments: 1, glyph: '◍' },
  ANOMALO: { label: 'Anómalo', color: '#d2647a', fragments: 2, glyph: '⌖' },
  VACIO: { label: 'Vacío', color: '#b58cff', fragments: 3, glyph: '∅' },
};

const TEXT_POOL: Record<SignalClass, string[]> = {
  RUIDO: ['—', '···', ''],
  TELEMETRIA: [
    'SONDA 41-A · ESTADO NOMINAL · COMBUSTIBLE 12% · ÚLTIMO CONTACTO HACE 9 AÑOS · REPETIDOR ACTIVO',
    'PAQUETE 88 · 46.551N 8.071E · PROFUNDIDAD 214 M · TEMPERATURA -3.1 · SIN OPERADOR',
    'BALIZA 771 · CICLO DE ESCUCHA 40 S · MENSAJE INTERNO: NO ENVIAR MÁS',
    'REGISTRO DE MANTENIMIENTO · UNIDAD 3 · REEMPLAZADA · MOTIVO: EL OPERADOR NO RESPONDIÓ',
  ],
  BALIZA: [
    'AQUÍ. AQUÍ. AQUÍ. AQUÍ. AQUÍ. AQUÍ.',
    'ESCUCHA A TU ESPALDA.',
    'SI RECIBES ESTO, LA PUERTA YA ESTÁ ABIERTA.',
    'DOCE. DOCE. DOCE. DOCE. DOCE. DOCE.',
  ],
  VOZ: [
    'ME LLAMO... NO RECUERDO. ESTOY EN LA NIEVE. HAY UNA LUZ ENCIMA DE MÍ.',
    'EL OPERADOR ANTERIOR DEJÓ LA ANTENA APUNTANDO AQUÍ. NO LA MOVÁIS.',
    'LLEVAMOS CUARENTA AÑOS ESCUCHANDO. VOSOTROS TAMBIÉN.',
    'NO ABRÁIS LA PUERTA A LA TERCERA LLAMADA. LA TERCERA NO ES QUIEN DICE SER.',
    'HABÉIS ESTADO SOLOS TODA LA NOCHE. NO ES CIERTO.',
  ],
  ANOMALO: [
    'NO ES UNA SEÑAL. ES UNA POSICIÓN.',
    'ESTE MENSAJE LLEGA DESDE DENTRO DEL EDIFICIO.',
    'LA FIGURA DEL LINDE TIENE TU ALTURA.',
    'NO REPRODUZCAS ESTA GRABACIÓN OTRA VEZ.',
    'CUANDO TERMINES DE LEER ESTO, ESTARÁ MÁS CERCA.',
  ],
  VACIO: [
    'NO HAY EMISOR DETRÁS DE ESTE MENSAJE.',
    'LA ESTACIÓN ES EL MENSAJE.',
    'NOSOTROS SOMOS LO QUE QUEDA CUANDO DEJAS DE ESCUCHAR.',
    'TU NOMBRE ESTABA EN LA LISTA ANTES DE QUE NACIERAS.',
  ],
};

const NAMES = [
  'CVn-29',
  'KEPLER-186',
  'GLIESE 581',
  'TRAPPIST-1e',
  'WOLF 359',
  'ROSS 128',
  'TAU CETI',
  'LHS 1140',
  'PROXIMA b',
  'BARNARD 2',
  'HD 40307',
  'KAPPA CETI',
];

const GLYPHS = '░▒▓█▚▞◍⌖∅※⏃⌇⎅◈⋔';

const ROT = 2;

function rot(text: string, n: number): string {
  return text.replace(/[A-Za-zÁÉÍÓÚÜÑ]/g, (ch) => {
    const upper = ch.toUpperCase();
    const isLower = ch !== upper;
    let base = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ';
    // Las tildes se pliegan a su vocal base antes de rotar.
    const fold: Record<string, string> = {
      'Á': 'A', 'É': 'E', 'Í': 'I', 'Ó': 'O', 'Ú': 'U', 'Ü': 'U',
    };
    const folded = fold[upper] ?? upper;
    const idx = base.indexOf(folded);
    if (idx < 0) return ch;
    const out = base[(idx + (n % base.length) + base.length) % base.length]!;
    return isLower ? out.toLowerCase() : out;
  });
}

function toGlyphs(text: string): string {
  let out = '';
  for (let i = 0; i < text.length; i++) {
    const code = text.charCodeAt(i);
    if (text[i] === ' ') out += ' ';
    else if (code < 32) out += text[i];
    else out += GLYPHS[code % GLYPHS.length];
  }
  return out;
}

/** Texto tal y como lo ve el jugador en la máquina: cifrado, no en claro. */
export function encodeForCipher(text: string, cipher: Cipher): string {
  switch (cipher) {
    case 'BASE':
      return text;
    case 'ARMONICO':
      return rot(text, ROT);
    case 'RECURSIVO':
      return [...text].reverse().join('');
    case 'VACIO':
      return toGlyphs(text);
  }
}

/** Aplica la inversa. BASE sobre un mensaje BASE devuelve el texto. */
export function decodeWithCipher(text: string, cipher: Cipher, hasGlyphTable: boolean): string | null {
  switch (cipher) {
    case 'BASE':
      return text;
    case 'ARMONICO':
      return rot(text, -ROT);
    case 'RECURSIVO':
      return [...text].reverse().join('');
    case 'VACIO':
      // Los glifos no conservan el carácter original: solo la tabla recuperada
      // permite reconstruir el mensaje (ver decodeText).
      return hasGlyphTable ? text : null;
  }
}

/**
 * Texto parcial que se muestra antes de decodificar: se enmascaran algunos
 * símbolos, pero la estructura (inversión, desfase, glifos) queda visible.
 */
export function previewText(capture: Capture, hasGlyphTable = false): string {
  const base = encodeForCipher(capture.text, capture.cipher);
  const seed = hashString(capture.id + capture.cipher);
  const visible = 0.62;
  let out = '';
  let h = seed;
  for (let i = 0; i < base.length; i++) {
    h = (Math.imul(h, 1664525) + 1013904223) >>> 0;
    const r = (h >>> 8) / 16777216;
    const ch = base[i]!;
    out += r < visible || ch === ' ' ? ch : '·';
  }
  if (capture.cipher === 'VACIO' && !hasGlyphTable) {
    return `${out}\n[símbolos no catalogados: tabla de glifos ausente]`;
  }
  return out;
}

export function decodeText(capture: Capture, hasGlyphTable: boolean): string | null {
  if (capture.cipher === 'VACIO') {
    // Con la tabla, el mensaje se reconstruye; sin ella solo se intuye.
    return hasGlyphTable ? capture.text : null;
  }
  return decodeWithCipher(encodeForCipher(capture.text, capture.cipher), capture.cipher, hasGlyphTable);
}

/** Distancia angular en grados entre dos posiciones del cielo. */
export function angularDistance(az1: number, el1: number, az2: number, el2: number): number {
  const rad = Math.PI / 180;
  const a1 = az1 * rad;
  const e1 = el1 * rad;
  const a2 = az2 * rad;
  const e2 = el2 * rad;
  const dot = Math.sin(e1) * Math.sin(e2) + Math.cos(e1) * Math.cos(e2) * Math.cos(a1 - a2);
  return (Math.acos(Math.max(-1, Math.min(1, dot))) * 180) / Math.PI;
}

/** Fuerza de señal 0..100 según apuntado, tamaño de fuente y ganancia del plato. */
export function signalStrength(
  dishAz: number,
  dishEl: number,
  source: Pick<SignalSource, 'az' | 'el' | 'sharpness'>,
  gainLevel: number,
  interference = 0,
): number {
  const dist = angularDistance(dishAz, dishEl, source.az, source.el);
  const sigma = Math.max(2.2, source.sharpness) + gainLevel * 1.6;
  const gauss = Math.exp(-Math.pow(dist / sigma, 2));
  const gain = 1 + gainLevel * 0.08;
  return Math.max(0, Math.min(100, gauss * 100 * gain - interference));
}

export function makeCapture(
  source: SignalSource,
  quality: number,
  day: number,
  clock: number,
  rng: Rng,
  origin: Capture['origin'] = 'antena',
): Capture {
  return {
    id: `c${day}-${Math.floor(clock)}-${rng.int(1000, 9999)}`,
    sourceId: source.id,
    name: source.name,
    klass: source.klass,
    band: source.band,
    modulation: source.modulation,
    cipher: source.cipher,
    quality: Math.round(Math.max(5, Math.min(100, quality))),
    corruption: 0,
    stage: STAGE.CRUDA,
    createdDay: day,
    createdClock: clock,
    text: source.text,
    sold: false,
    failedAttempts: 0,
    origin,
  };
}

const CLASS_WEIGHTS_BY_DAY: Record<SignalClass, (day: number) => number> = {
  TELEMETRIA: (d) => Math.max(6, 34 - d * 2),
  BALIZA: () => 26,
  VOZ: (d) => (d < 2 ? 0 : 10 + d * 2.5),
  ANOMALO: (d) => (d < 3 ? 0 : 6 + (d - 2) * 5),
  VACIO: (d) => (d < 4 ? 0 : 3 + (d - 3) * 4),
  RUIDO: () => 0,
};

function pickClass(day: number, rng: Rng): SignalClass {
  const classes: SignalClass[] = ['TELEMETRIA', 'BALIZA', 'VOZ', 'ANOMALO', 'VACIO'];
  return (
    rng.weighted(classes.map((c) => ({ item: c, weight: CLASS_WEIGHTS_BY_DAY[c](day) }))) ??
    'TELEMETRIA'
  );
}

function makeSource(day: number, rng: Rng, index: number, klass?: SignalClass): SignalSource {
  const k = klass ?? pickClass(day, rng);
  const mod = rng.pick(MODULATIONS);
  const cipher: Cipher =
    k === 'TELEMETRIA'
      ? rng.chance(0.65)
        ? 'BASE'
        : 'ARMONICO'
      : k === 'BALIZA'
        ? rng.pick<Cipher>(['ARMONICO', 'RECURSIVO', 'BASE'])
        : k === 'VOZ'
          ? rng.pick<Cipher>(['BASE', 'ARMONICO', 'RECURSIVO'])
          : k === 'VACIO'
            ? 'VACIO'
            : rng.pick<Cipher>(['RECURSIVO', 'ARMONICO', 'BASE']);

  return {
    id: `s${day}-${index}-${rng.int(100, 999)}`,
    name: k === 'ANOMALO' || k === 'VACIO' ? 'NO CATALOGADA' : rng.pick(NAMES),
    az: Math.round(rng.range(0, 360) * 10) / 10,
    el: Math.round(rng.range(12, 82) * 10) / 10,
    band: Math.round(rng.range(1250, 1680) * 10) / 10,
    modulation: mod,
    cipher,
    klass: k,
    text: rng.pick(TEXT_POOL[k]),
    base: saleBase(k),
    sharpness: k === 'ANOMALO' || k === 'VACIO' ? rng.range(2.4, 4.2) : rng.range(4.5, 9),
  };
}

export function saleBase(klass: SignalClass): number {
  switch (klass) {
    case 'RUIDO':
      return 4;
    case 'TELEMETRIA':
      return 52;
    case 'BALIZA':
      return 104;
    case 'VOZ':
      return 168;
    case 'ANOMALO':
      return 280;
    case 'VACIO':
      return 0;
  }
}

/** Fuentes visibles en un turno. La primera siempre es fácil (onboarding). */
export function generateSources(day: number, rng: Rng): SignalSource[] {
  const count = 6 + Math.min(3, Math.floor(day / 3));
  const list: SignalSource[] = [];
  list.push(makeSource(day, rng, 0, day === 1 ? 'TELEMETRIA' : undefined));
  list.push(makeSource(day, rng, 1, day === 1 ? 'BALIZA' : undefined));
  for (let i = 2; i < count; i++) {
    const s = makeSource(day, rng, i);
    // Evita dos fuentes pegadas: sería imposible distinguirlas en el plato.
    const tooClose = list.some(
      (o) => angularDistance(o.az, o.el, s.az, s.el) < 9,
    );
    if (tooClose) {
      s.az = (s.az + 47) % 360;
      s.el = Math.min(82, Math.max(12, s.el + 9));
    }
    list.push(s);
  }
  return list;
}

/** Fuente creada por un evento (grabación de micrófono, llamada, etc.). */
export function syntheticSource(klass: SignalClass, rng: Rng): SignalSource {
  const cipher: Cipher =
    klass === 'VACIO' ? 'VACIO' : klass === 'BALIZA' ? rng.pick(['ARMONICO', 'RECURSIVO', 'BASE']) : rng.pick(CIPHERS);
  return {
    id: `ev-${rng.int(10000, 99999)}`,
    name: 'NO CATALOGADA',
    az: 0,
    el: 0,
    band: Math.round(rng.range(1250, 1680) * 10) / 10,
    modulation: rng.pick(MODULATIONS),
    cipher,
    klass,
    text: rng.pick(TEXT_POOL[klass]),
    base: saleBase(klass),
    sharpness: 4,
  };
}

export interface BandResult {
  ok: boolean;
  qualityDelta: number;
  corruptionDelta: number;
  message: string;
}

/**
 * Etapa 1: aislar la portadora moviendo la ventana del analizador.
 * La tolerancia depende del filtro comprado.
 */
export function isolateBand(capture: Capture, windowCenter: number, filterLevel: number): BandResult {
  const tolerance = 3.2 + filterLevel * 1.7;
  const delta = Math.abs(windowCenter - capture.band);
  if (delta <= tolerance) {
    const penalty = (delta / tolerance) * 8;
    return {
      ok: true,
      qualityDelta: -penalty,
      corruptionDelta: 0,
      message: `Portadora aislada · ${capture.band.toFixed(1)} MHz`,
    };
  }
  return {
    ok: false,
    qualityDelta: -16,
    corruptionDelta: 9,
    message:
      delta > tolerance * 2.4
        ? 'Ventana fuera de banda: solo ruido térmico.'
        : 'Portadora parcialmente recortada. Vuelve a intentarlo.',
  };
}

export interface DemodResult {
  ok: boolean;
  qualityDelta: number;
  corruptionDelta: number;
  message: string;
}

export function demodulate(capture: Capture, guess: Modulation, demodLevel: number): DemodResult {
  const ok = guess === capture.modulation;
  if (ok) {
    return {
      ok: true,
      qualityDelta: demodLevel * 2,
      corruptionDelta: 0,
      message: 'Trama demodulada. Se detecta estructura interna.',
    };
  }
  return {
    ok: false,
    qualityDelta: -18,
    corruptionDelta: 12,
    message: 'Sincronía perdida: la trama se rompe en bloques de ruido.',
  };
}

export interface DecodeAttempt {
  ok: boolean;
  text: string | null;
  qualityDelta: number;
  corruptionDelta: number;
  message: string;
}

export function tryDecode(
  capture: Capture,
  guess: Cipher,
  hasGlyphTable: boolean,
  decoderLevel: number,
): DecodeAttempt {
  const correct = guess === capture.cipher;
  if (!correct) {
    return {
      ok: false,
      text: null,
      qualityDelta: -14,
      corruptionDelta: 11,
      message: 'La firma no encaja. El mensaje se degrada un poco más.',
    };
  }
  if (guess === 'VACIO' && !hasGlyphTable) {
    return {
      ok: false,
      text: null,
      qualityDelta: -6,
      corruptionDelta: 4,
      message: 'Reconoces los glifos, pero no el alfabeto. Falta la tabla.',
    };
  }
  const text = decodeText(capture, hasGlyphTable) ?? '';
  return {
    ok: true,
    text,
    qualityDelta: decoderLevel * 2,
    corruptionDelta: 0,
    message: 'Mensaje reconstruido.',
  };
}

export function saleValue(capture: Capture): number {
  if (capture.stage < STAGE.DECODIFICADA) return 0;
  const base = saleBase(capture.klass);
  const integrity = Math.max(0.2, capture.quality / 100) * (1 - capture.corruption / 160);
  return Math.round(base * integrity);
}

export function classFromLabel(label: string): SignalClass | null {
  const found = (Object.keys(CLASS_INFO) as SignalClass[]).find(
    (k) => CLASS_INFO[k].label.toLowerCase() === label.toLowerCase(),
  );
  return found ?? null;
}

/** Descripción de la firma que lee el jugador en la máquina de patrones. */
export function cipherSignature(cipher: Cipher): string {
  return CIPHER_INFO[cipher].signature;
}
