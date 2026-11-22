import { describe, expect, it } from 'vitest';
import { Rng } from '../src/core/rng';
import {
  STAGE,
  angularDistance,
  decodeText,
  demodulate,
  encodeForCipher,
  generateSources,
  isolateBand,
  makeCapture,
  previewText,
  saleValue,
  signalStrength,
  tryDecode,
  type SignalSource,
} from '../src/core/signals';

const src: SignalSource = {
  id: 's1',
  name: 'TEST',
  az: 180,
  el: 45,
  band: 1420.4,
  modulation: 'FM',
  cipher: 'ARMONICO',
  klass: 'VOZ',
  text: 'HOLA MUNDO',
  base: 168,
  sharpness: 6,
};

describe('apuntado', () => {
  it('distancia angular es 0 contra sí misma y 180 en el opuesto', () => {
    expect(angularDistance(10, 20, 10, 20)).toBeCloseTo(0, 5);
    expect(angularDistance(0, 0, 180, 0)).toBeCloseTo(180, 5);
  });

  it('la señal es máxima en el cenit de la fuente y decae al desviarse', () => {
    const center = signalStrength(180, 45, src, 0);
    const near = signalStrength(184, 47, src, 0);
    const far = signalStrength(240, 45, src, 0);
    expect(center).toBeCloseTo(100, 0);
    expect(near).toBeLessThan(center);
    expect(far).toBeLessThan(10);
  });

  it('la ganancia del plato amplía la huella', () => {
    const base = signalStrength(190, 45, src, 0);
    const upgraded = signalStrength(190, 45, src, 4);
    expect(upgraded).toBeGreaterThan(base);
  });

  it('la interferencia reduce la lectura', () => {
    expect(signalStrength(180, 45, src, 0, 40)).toBeLessThan(signalStrength(180, 45, src, 0, 0));
  });
});

describe('cadena de decodificación', () => {
  const cap = makeCapture(src, 80, 1, 100, new Rng(1));

  it('empieza en crudo y sin valor', () => {
    expect(cap.stage).toBe(STAGE.CRUDA);
    expect(saleValue(cap)).toBe(0);
  });

  it('aislar la portadora falla fuera de tolerancia y acierta cerca', () => {
    const miss = isolateBand(cap, 1500, 0);
    expect(miss.ok).toBe(false);
    expect(miss.corruptionDelta).toBeGreaterThan(0);

    const hit = isolateBand(cap, 1421, 0);
    expect(hit.ok).toBe(true);
    expect(hit.qualityDelta).toBeLessThanOrEqual(0);
  });

  it('el filtro comprado amplía la tolerancia', () => {
    expect(isolateBand(cap, 1427, 0).ok).toBe(false);
    expect(isolateBand(cap, 1427, 4).ok).toBe(true);
  });

  it('la modulación correcta avanza y la incorrecta degrada', () => {
    expect(demodulate(cap, 'AM', 0).ok).toBe(false);
    const ok = demodulate(cap, 'FM', 0);
    expect(ok.ok).toBe(true);
    expect(ok.corruptionDelta).toBe(0);
  });

  it('el cifrado correcto devuelve el mensaje original', () => {
    const res = tryDecode(cap, 'ARMONICO', true, 0);
    expect(res.ok).toBe(true);
    expect(res.text).toBe('HOLA MUNDO');
  });

  it('el cifrado incorrecto degrada y no devuelve texto', () => {
    const res = tryDecode(cap, 'BASE', true, 0);
    expect(res.ok).toBe(false);
    expect(res.text).toBeNull();
  });

  it('vacio requiere tabla de glifos', () => {
    const vacio = makeCapture(
      { ...src, cipher: 'VACIO', klass: 'VACIO', text: 'NO HAY EMISOR' },
      70,
      1,
      0,
      new Rng(2),
    );
    expect(tryDecode(vacio, 'VACIO', false, 0).ok).toBe(false);
    expect(tryDecode(vacio, 'VACIO', true, 0).text).toBe('NO HAY EMISOR');
  });

  it('la vista previa conserva la longitud y enmascara parte del texto', () => {
    const preview = previewText(cap);
    expect(preview.length).toBe(encodeForCipher(cap.text, cap.cipher).length);
    expect(preview).toContain('·');
  });

  it('la decodificación sube el valor de venta', () => {
    const copy = { ...cap, stage: STAGE.DECODIFICADA };
    expect(saleValue(copy)).toBeGreaterThan(0);
    const grotty = { ...copy, quality: 20, corruption: 40 };
    expect(saleValue(grotty)).toBeLessThan(saleValue(copy));
  });
});

describe('generación de fuentes', () => {
  it('es determinista por semilla', () => {
    const a = generateSources(3, new Rng(99));
    const b = generateSources(3, new Rng(99));
    expect(a.map((s) => s.az)).toEqual(b.map((s) => s.az));
    expect(a.length).toBe(b.length);
  });

  it('el día 1 garantiza una fuente fácil y no incluye vacío', () => {
    const list = generateSources(1, new Rng(7));
    expect(list[0]?.klass).toBe('TELEMETRIA');
    expect(list.some((s) => s.klass === 'VACIO')).toBe(false);
  });

  it('las fuentes no se solapan en el cielo', () => {
    const list = generateSources(6, new Rng(42));
    for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const d = angularDistance(list[i]!.az, list[i]!.el, list[j]!.az, list[j]!.el);
        expect(d).toBeGreaterThan(7);
      }
    }
  });
});

describe('cifrados', () => {
  it('base es identidad', () => {
    expect(decodeText({ ...makeCapture(src, 50, 1, 0, new Rng(3)), text: 'ABC' }, false)).toBe('ABC');
  });

  it('armónico desplaza y se deshace', () => {
    const cap = makeCapture({ ...src, cipher: 'ARMONICO', text: 'ABC XYZ' }, 50, 1, 0, new Rng(4));
    expect(decodeText(cap, false)).toBe('ABC XYZ');
  });

  it('recursivo invierte y se deshace', () => {
    const cap = makeCapture({ ...src, cipher: 'RECURSIVO', text: 'ALGO' }, 50, 1, 0, new Rng(5));
    expect(decodeText(cap, false)).toBe('ALGO');
  });
});
