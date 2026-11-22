// Paneles de las máquinas y la consola. Cada panel es una "pantalla" diegética
// que se reconstruye tras cada acción, con canvas para espectro y onda.

import { CIPHER_INFO, CLASS_INFO, CIPHERS, MODULATIONS, STAGE, saleValue, previewText } from '../core/signals';
import type { Capture, Cipher, Modulation } from '../core/signals';
import { UPGRADES, capacity, level, upgradeCost } from '../core/economy';
import { MACHINES, PART_COST, faultOf, machineDef, type MachineId } from '../core/faults';
import { clockLabel } from '../core/time';
import type { GameApi } from './types';
import type { Hud } from './hud';

type PanelId = 'dish' | 'spectrum' | 'demod' | 'decoder' | 'pc' | 'tri' | 'travel' | 'trade';

const STAGE_LABEL = ['CRUDA', 'AISLADA', 'DEMODULADA', 'DECODIFICADA'];

export class Panels {
  private api: GameApi;
  private hud: Hud;
  private layer: HTMLElement;
  private openId: PanelId | null = null;
  private pcTab: 'archivo' | 'tienda' | 'registro' | 'control' = 'archivo';
  private spectrumCenter = 1420;
  private refs: Record<string, HTMLElement | HTMLCanvasElement | null> = {};
  private lastRecording = false;
  private lastRefresh = 0;
  private lastKey = '';

  constructor(layer: HTMLElement, api: GameApi, hud: Hud) {
    this.layer = layer;
    this.api = api;
    this.hud = hud;
    // Escape lo gestiona Game: aquí solo se abre/cierra por botones.
  }

  get isOpen(): boolean {
    return this.openId !== null;
  }

  get current(): PanelId | null {
    return this.openId;
  }

  open(id: PanelId | 'log'): void {
    const panelId: PanelId = id === 'log' ? 'pc' : id;
    if (id === 'log') this.pcTab = 'registro';
    if (panelId === 'spectrum') {
      const cap = this.pickCapture(STAGE.CRUDA);
      const physical = this.api.getSpectrumControl();
      this.spectrumCenter = physical || (cap
        ? Math.round((cap.band + (Math.random() - 0.5) * 90) * 10) / 10
        : 1420);
    }
    if (panelId !== this.openId) this.refs = {};
    this.openId = panelId;
    this.layer.classList.add('open');
    this.render();
  }

  close(): void {
    this.openId = null;
    this.layer.classList.remove('open');
    this.layer.innerHTML = '';
    this.api.closePanel();
  }

  private pickCapture(stage: number): Capture | null {
    const selected = this.api.selectedCapture();
    if (selected && !selected.sold && selected.stage === stage) return selected;
    return this.api.state.captures.find((c) => !c.sold && c.stage === stage) ?? null;
  }

  private shell(title: string, sub: string, body: string): HTMLElement {
    const s = this.api.state;
    this.layer.innerHTML = `
      <div class="panel fade-in">
        <div class="panel-head">
          <div>
            <h2>${title}</h2>
            <div class="sub">${sub}</div>
          </div>
          <div class="status-chips">
            <span>${clockLabel(s.clock)}</span>
            <span>DÍA ${s.day}</span>
            <span>ESTRÉS <b>${Math.round(s.stress)}</b></span>
            <span>${this.api.weatherLabel()}</span>
            <span>REPUESTOS <b>${s.parts}</b></span>
            <span><span class="dot ${s.power ? '' : 'off'}"></span> ${s.power ? 'RED' : 'SIN LUZ'}</span>
          </div>
          <button class="ghost small" data-close>ESC · CERRAR</button>
        </div>
        <div class="panel-body">${body}</div>
      </div>
    `;
    this.layer.querySelector('[data-close]')?.addEventListener('click', () => this.close());
    return this.layer.querySelector('.panel') as HTMLElement;
  }

  private captureStrip(captures: Capture[], activeId?: string): string {
    if (captures.length === 0) {
      return `<div class="mono-box"><span class="ghost">Archivador vacío.</span></div>`;
    }
    return `<div class="capture-list">${captures
      .map((c) => {
        const info = CLASS_INFO[c.stage >= STAGE.DECODIFICADA ? c.klass : 'RUIDO'];
        const label = c.stage >= STAGE.DECODIFICADA ? c.name : c.stage >= STAGE.DEMODULADA ? 'SEÑAL SIN IDENTIFICAR' : 'CAPTURA';
        const value = c.stage >= STAGE.DECODIFICADA ? `${saleValue(c)} cr` : '—';
        return `<button class="capture-row ${c.id === activeId ? 'active' : ''}" data-cap="${c.id}">
          <span class="glyph">${c.stage >= STAGE.DECODIFICADA ? info.glyph : '▤'}</span>
          <span>${label}<br /><span class="meta">${c.band.toFixed(1)} MHz · ${STAGE_LABEL[c.stage]} · INT ${Math.round(c.quality)}%</span></span>
          <span class="value">${value}</span>
          <span class="meta">${c.sold ? 'ARCHIVADA' : ''}</span>
        </button>`;
      })
      .join('')}</div>`;
  }

  private bars(cap: Capture): string {
    const q = Math.max(0, Math.min(100, cap.quality));
    const cor = Math.max(0, Math.min(100, cap.corruption));
    const qClass = q < 35 ? 'low' : q < 65 ? 'mid' : '';
    return `
      <div class="bar-row"><span>INTEGRIDAD</span><div class="track"><i class="${qClass}" style="width:${q}%"></i></div><span>${Math.round(q)}%</span></div>
      <div class="bar-row"><span>CORRUPCIÓN</span><div class="track"><i class="low" style="width:${cor}%"></i></div><span>${Math.round(cor)}%</span></div>
    `;
  }

  // ---------- render ----------

  private render(): void {
    const id = this.openId;
    if (!id) return;
    switch (id) {
      case 'dish':
        this.renderDish();
        break;
      case 'spectrum':
        this.renderSpectrum();
        break;
      case 'demod':
        this.renderDemod();
        break;
      case 'decoder':
        this.renderDecoder();
        break;
      case 'pc':
        this.renderPc();
        break;
      case 'tri':
        this.renderTri();
        break;
      case 'travel':
        this.renderTravel();
        break;
      case 'trade':
        this.renderTrade();
        break;
    }
  }

  /**
   * Aviso de avería: ninguna máquina de la cadena funciona rota. Devuelve true
   * si ha pintado la pantalla de avería en lugar de la máquina.
   */
  private faultScreen(id: MachineId, sub: string): boolean {
    const s = this.api.state;
    const fault = faultOf(s, id);
    if (!fault.broken) return false;
    const def = machineDef(id);
    const body = `
      <div class="grid-2">
        <div class="stack">
          <div class="notice bad">
            <b>${def.short} · FUERA DE SERVICIO</b><br />
            Desajuste ${Math.round(fault.severity * 100)}% · intentos de calibración ${fault.attempt}<br />
            ${fault.severity > 0.7
              ? 'La aguja no responde: el tornillo está casi suelto. Calibrar a mano será difícil.'
              : 'La unidad admite una calibración a mano antes de tocar nada más.'}
          </div>
          <div class="row">
            <button class="primary small" data-calib>CALIBRAR A MANO</button>
            <button class="small" data-repair ${s.parts > 0 ? '' : 'disabled'}>SUSTITUIR PIEZA</button>
          </div>
          <div class="mono-box" data-fault-msg><span class="ghost">Las otras máquinas de la cadena siguen operativas. Puedes seguir la cadena con otra captura o esperar a mañana.</span></div>
          <span class="legend">Calibrar es gratis pero no siempre sale: cada intento fallido desajusta más la unidad. Una pieza de repuesto la devuelve al servicio al instante.</span>
        </div>
        <div class="stack tight">
          <p class="label">Piezas de repuesto</p>
          <div class="readout">${s.parts}<small>uds</small></div>
          <button class="small" data-buy-part ${s.points >= PART_COST ? '' : 'disabled'}>COMPRAR PIEZA (${PART_COST} CR)</button>
          <p class="label">Herramienta</p>
          <div class="mono-box" style="min-height:0">Llave de calibración: presentes\nDestornillador de precisión: presentes\nPiezas de repuesto: ${s.parts}</div>
        </div>
      </div>
    `;
    const panel = this.shell(`${def.label}`, sub, body);
    const msg = panel.querySelector('[data-fault-msg]') as HTMLElement;
    panel.querySelector('[data-calib]')?.addEventListener('click', () => {
      const res = this.api.calibrate(id);
      msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
      if (res.ok) window.setTimeout(() => this.render(), 450);
      else this.render();
    });
    panel.querySelector('[data-repair]')?.addEventListener('click', () => {
      const res = this.api.repair(id);
      msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
      this.render();
    });
    panel.querySelector('[data-buy-part]')?.addEventListener('click', () => {
      const res = this.api.buyPart();
      this.hud.toast(res.message, res.ok ? 'good' : 'warn');
      this.render();
    });
    return true;
  }

  // ---------- plato ----------

  private renderDish(): void {
    const d = this.api.dish;
    const s = this.api.state;
    const rec = d.recording;
    const body = `
      <div class="grid-2">
        <div class="stack">
          <div>
            <p class="label">Carta del cielo · azimut / elevación</p>
            <canvas class="machine" data-dish-canvas></canvas>
          </div>
          <div class="grid-2" style="gap:16px">
            <div>
              <p class="label">Azimut</p>
              <div class="readout" data-az>${d.az.toFixed(1)}<small>°</small></div>
              <input type="range" min="0" max="360" step="0.5" value="${d.az}" data-az-range />
            </div>
            <div>
              <p class="label">Elevación</p>
              <div class="readout" data-el>${d.el.toFixed(1)}<small>°</small></div>
              <input type="range" min="5" max="85" step="0.5" value="${d.el}" data-el-range />
            </div>
          </div>
          <div class="row">
            <button class="small" data-nudge="az:-10">AZ −10</button>
            <button class="small" data-nudge="az:-1">AZ −1</button>
            <button class="small" data-nudge="az:1">AZ +1</button>
            <button class="small" data-nudge="az:10">AZ +10</button>
            <span class="spacer"></span>
            <button class="small" data-nudge="el:-5">EL −5</button>
            <button class="small" data-nudge="el:5">EL +5</button>
          </div>
          <div class="row">
            <button class="ghost small" data-sweep>${d.sweeping ? 'DETENER BARRIDO' : 'BARRIDO AUTOMÁTICO'}</button>
            <span class="legend">El barrido gira el plato 8°/s. La señal se oye antes de verse.</span>
          </div>
        </div>
        <div class="stack">
          <div>
            <p class="label">Recepción</p>
            <div class="readout" data-strength>${Math.round(d.strength)}<small>%</small></div>
            <div class="bar-row" style="grid-template-columns:60px 1fr 44px">
              <span>SEÑAL</span>
              <div class="track"><i data-strength-bar style="width:${Math.round(d.strength)}%"></i></div>
              <span data-lock>${d.locked ? 'LOCK' : '—'}</span>
            </div>
          </div>
          <div class="mono-box" data-dish-readout>${this.dishReadout()}</div>
          <div class="stack tight">
            ${
              rec
                ? `<div class="bar-row"><span>GRABANDO</span><div class="track"><i data-rec-bar style="width:${Math.round(d.progress * 100)}%"></i></div><span data-rec-pct>${Math.round(d.progress * 100)}%</span></div>
                   <button class="danger" data-cancel-rec>CANCELAR GRABACIÓN</button>`
                : `<button class="primary" data-record ${d.locked && s.power ? '' : 'disabled'}>GRABAR SEÑAL (12 s)</button>
                   <span class="legend" data-record-hint>${d.locked ? 'Enlace estable: la captura conservará la integridad del apuntado.' : 'Ajusta azimut y elevación hasta superar el 45 % de señal.'}</span>`
            }
          </div>
          <div>
            <p class="label">Archivador · ${s.captures.filter((c) => !c.sold).length}/${capacity(s)}</p>
            ${this.captureStrip(s.captures.filter((c) => !c.sold), this.api.selectedCapture()?.id)}
          </div>
        </div>
      </div>
    `;
    const panel = this.shell('Terminal del plato', 'Kestrel · antena principal 4,2 m · montaje azimutal', body);

    const azRange = panel.querySelector('[data-az-range]') as HTMLInputElement;
    const elRange = panel.querySelector('[data-el-range]') as HTMLInputElement;
    azRange.addEventListener('input', () => this.api.setDish(Number(azRange.value), this.api.dish.el));
    elRange.addEventListener('input', () => this.api.setDish(this.api.dish.az, Number(elRange.value)));
    panel.querySelectorAll<HTMLElement>('[data-nudge]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const [axis, raw] = (btn.dataset['nudge'] ?? '').split(':');
        const delta = Number(raw);
        const d2 = this.api.dish;
        if (axis === 'az') this.api.setDish((d2.az + delta + 360) % 360, d2.el);
        else this.api.setDish(d2.az, Math.max(5, Math.min(85, d2.el + delta)));
        this.renderDish();
      });
    });
    panel.querySelector('[data-sweep]')?.addEventListener('click', () => {
      this.api.toggleSweep();
      this.renderDish();
    });
    panel.querySelector('[data-record]')?.addEventListener('click', () => {
      this.api.startRecording();
      this.renderDish();
    });
    panel.querySelector('[data-cancel-rec]')?.addEventListener('click', () => {
      this.api.cancelRecording();
      this.renderDish();
    });
    panel.querySelectorAll<HTMLElement>('[data-cap]').forEach((row) => {
      row.addEventListener('click', () => {
        this.api.selectCapture(row.dataset['cap']!);
        this.renderDish();
      });
    });

    this.refs['dishCanvas'] = panel.querySelector('[data-dish-canvas]') as HTMLCanvasElement;
    this.refs['az'] = panel.querySelector('[data-az]') as HTMLElement;
    this.refs['el'] = panel.querySelector('[data-el]') as HTMLElement;
    this.refs['azRange'] = azRange;
    this.refs['elRange'] = elRange;
    this.refs['dishReadout'] = panel.querySelector('[data-dish-readout]') as HTMLElement;
    this.refs['strength'] = panel.querySelector('[data-strength]') as HTMLElement;
    this.refs['strengthBar'] = panel.querySelector('[data-strength-bar]') as HTMLElement;
    this.refs['lock'] = panel.querySelector('[data-lock]') as HTMLElement;
    this.refs['recordBtn'] = panel.querySelector('[data-record]') as HTMLButtonElement | null;
    this.refs['recordHint'] = panel.querySelector('[data-record-hint]') as HTMLElement | null;
    this.refs['recBar'] = panel.querySelector('[data-rec-bar]') as HTMLElement | null;
    this.refs['recPct'] = panel.querySelector('[data-rec-pct]') as HTMLElement | null;
    this.drawDish();
  }

  private dishReadout(): string {
    const d = this.api.dish;
    const s = this.api.state;
    if (!s.power) return `<span class="bad">SIN CORRIENTE</span>\nEl plato mantiene la posición. Los motores no responden.`;
    if (d.recording) return `<span class="hot">GRABANDO</span>\nIntegridad estimada: ${Math.round(45 + d.strength * 0.5)}%\nNo abras la puerta: el ruido entra en la banda.`;
    if (d.locked) return `<span class="hot">ENLACE ESTABLE</span>\nFuente sin catalogar.\nPulsa GRABAR para almacenar 12 segundos de señal.`;
    if (d.strength > 18) return `<span class="warn">PORTADORA DÉBIL</span>\nSigue barriendo. La aguja sube al acercarte al cénit de la fuente.`;
    return `<span class="ghost">RUIDO DE FONDO</span>\nSin portadora. Revisa azimut y elevación.`;
  }

  private drawDish(): void {
    const canvas = this.refs['dishCanvas'] as HTMLCanvasElement | undefined;
    if (!canvas) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth || 520;
    const h = canvas.clientHeight || 210;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    const d = this.api.dish;
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const pad = 20;
    const plotW = w - pad * 2;
    const plotH = h - pad * 2;
    const xOfAz = (az: number) => pad + (az / 360) * plotW;
    const yOfEl = (el: number) => pad + plotH - (el / 90) * plotH;

    // rejilla
    ctx.strokeStyle = 'rgba(125,255,207,0.12)';
    ctx.lineWidth = 1;
    for (let az = 0; az <= 360; az += 45) {
      ctx.beginPath();
      ctx.moveTo(xOfAz(az), pad);
      ctx.lineTo(xOfAz(az), pad + plotH);
      ctx.stroke();
    }
    for (let el = 0; el <= 90; el += 15) {
      ctx.beginPath();
      ctx.moveTo(pad, yOfEl(el));
      ctx.lineTo(pad + plotW, yOfEl(el));
      ctx.stroke();
    }

    ctx.fillStyle = 'rgba(110,135,129,0.75)';
    ctx.font = '9px "IBM Plex Mono", monospace';
    for (let az = 0; az <= 360; az += 90) ctx.fillText(`${az}`, xOfAz(az) + 3, h - 6);
    for (let el = 0; el <= 90; el += 30) ctx.fillText(`${el}°`, 4, yOfEl(el) - 2);

    // picos: se muestran difusos hasta acercarse
    for (const blip of this.api.skyBlips()) {
      if (blip.strength < 12) continue;
      const error = Math.max(0.6, (100 - blip.strength) / 7);
      const az = (blip.az + (Math.random() - 0.5) * error + 360) % 360;
      const el = Math.max(2, Math.min(88, blip.el + (Math.random() - 0.5) * error));
      const r = 2 + (blip.strength / 100) * 4;
      ctx.beginPath();
      ctx.arc(xOfAz(az), yOfEl(el), r, 0, Math.PI * 2);
      ctx.fillStyle = blip.strength > 45 ? 'rgba(125,255,207,0.85)' : 'rgba(125,255,207,0.35)';
      ctx.fill();
      if (blip.strength > 45) {
        ctx.strokeStyle = 'rgba(125,255,207,0.25)';
        ctx.beginPath();
        ctx.arc(xOfAz(az), yOfEl(el), r + 6, 0, Math.PI * 2);
        ctx.stroke();
      }
    }

    // retícula actual
    const x = xOfAz(d.az);
    const y = yOfEl(d.el);
    ctx.strokeStyle = d.locked ? '#7dffcf' : 'rgba(233,196,106,0.9)';
    ctx.lineWidth = 1.4;
    ctx.beginPath();
    ctx.moveTo(x - 10, y);
    ctx.lineTo(x + 10, y);
    ctx.moveTo(x, y - 10);
    ctx.lineTo(x, y + 10);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(x, y, 16, 0, Math.PI * 2);
    ctx.strokeStyle = d.locked ? 'rgba(125,255,207,0.5)' : 'rgba(233,196,106,0.35)';
    ctx.stroke();
  }

  // ---------- espectro ----------

  private renderSpectrum(): void {
    if (this.faultScreen('spectrum', 'Modelo SA-9 · barrido 1250–1680 MHz')) return;
    this.api.setSpectrumControl(this.spectrumCenter);
    const cap = this.pickCapture(STAGE.CRUDA);
    if (!cap) {
      this.shell(
        'Analizador de espectro',
        'Modelo SA-9 · barrido 1250–1680 MHz',
        `<div class="notice">No hay capturas en bruto. Graba una señal desde el terminal del plato.</div>
         <div class="row end" style="margin-top:20px"><button data-goto-dish>IR AL PLATO</button></div>`,
      );
      this.layer.querySelector('[data-goto-dish]')?.addEventListener('click', () => this.open('dish'));
      return;
    }
    this.api.selectCapture(cap.id);
    this.api.setDemodulation(cap.modulation);
    const tol = 3.2 + level(this.api.state, 'filtro') * 1.7;
    const body = `
      <div class="stack">
        <div class="row between">
          <div>
            <p class="label">Captura ${cap.id} · ${cap.origin.toUpperCase()} · DÍA ${cap.createdDay}</p>
            <div class="readout">${cap.band.toFixed(1)}<small>MHz (portadora sin aislar)</small></div>
          </div>
          <div class="legend"><span>PICO = PORTADORA</span><span>TOLERANCIA ±${tol.toFixed(1)} MHz</span></div>
        </div>
        <canvas class="machine" data-spec></canvas>
        <div class="grid-2" style="gap:20px">
          <div class="stack tight">
            <p class="label" data-window-label>Ventana del filtro · ${this.spectrumCenter.toFixed(1)} MHz</p>
            <input type="range" min="1255" max="1675" step="0.5" value="${this.spectrumCenter}" data-spec-range />
            <div class="row">
              <button class="small" data-spec-step="-1">−1</button>
              <button class="small" data-spec-step="-0.1">−0,1</button>
              <button class="small" data-spec-step="0.1">+0,1</button>
              <button class="small" data-spec-step="1">+1</button>
            </div>
            <span class="legend">Arrastra sobre el gráfico para mover la ventana.</span>
          </div>
          <div class="stack tight">
            ${this.bars(cap)}
            <button class="primary" data-isolate ${this.api.state.power ? '' : 'disabled'}>AISLAR PORTADORA</button>
            <div class="mono-box" data-spec-msg><span class="ghost">Selecciona la ventana que contiene el pico más estrecho y pulsa aislar.</span></div>
          </div>
        </div>
        <div>
          <p class="label">Otras capturas sin analizar</p>
          ${this.captureStrip(this.api.state.captures.filter((c) => !c.sold), cap.id)}
        </div>
      </div>
    `;
    const panel = this.shell('Analizador de espectro', 'Modelo SA-9 · barrido 1250–1680 MHz', body);
    const range = panel.querySelector('[data-spec-range]') as HTMLInputElement;
    const msg = panel.querySelector('[data-spec-msg]') as HTMLElement;
    const canvas = panel.querySelector('[data-spec]') as HTMLCanvasElement;
    const redraw = () => this.drawSpectrum(canvas, cap);
    redraw();

    range.addEventListener('input', () => {
      this.spectrumCenter = Number(range.value);
      const label = panel.querySelector('[data-window-label]')!;
      label.textContent = `Ventana del filtro · ${this.spectrumCenter.toFixed(1)} MHz`;
      redraw();
    });
    panel.querySelectorAll<HTMLElement>('[data-spec-step]').forEach((b) => {
      b.addEventListener('click', () => {
        this.spectrumCenter = Math.max(1255, Math.min(1675, this.spectrumCenter + Number(b.dataset['specStep'])));
        range.value = String(this.spectrumCenter);
        redraw();
        this.renderSpectrum();
      });
    });
    panel.querySelector('[data-isolate]')?.addEventListener('click', () => {
      const res = this.api.isolate(this.spectrumCenter);
      msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
      if (res.ok) {
        window.setTimeout(() => this.open('demod'), 650);
      } else {
        redraw();
      }
    });

    let dragging = false;
    const move = (e: PointerEvent) => {
      if (!dragging) return;
      const rect = canvas.getBoundingClientRect();
      const t = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
      this.spectrumCenter = Math.round((1255 + t * 420) * 2) / 2;
      range.value = String(this.spectrumCenter);
      redraw();
    };
    canvas.addEventListener('pointerdown', (e) => {
      dragging = true;
      canvas.setPointerCapture(e.pointerId);
      move(e);
    });
    canvas.addEventListener('pointermove', move);
    canvas.addEventListener('pointerup', () => {
      dragging = false;
      this.renderSpectrum();
    });
    panel.querySelectorAll<HTMLElement>('[data-cap]').forEach((row) => {
      row.addEventListener('click', () => {
        this.api.selectCapture(row.dataset['cap']!);
        this.renderSpectrum();
      });
    });
  }

  private drawSpectrum(canvas: HTMLCanvasElement, cap: Capture): void {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth || 720;
    const h = canvas.clientHeight || 210;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const padL = 34;
    const padB = 18;
    const padT = 10;
    const plotW = w - padL - 10;
    const plotH = h - padB - padT;
    const lo = 1250;
    const hi = 1680;
    const xOf = (mhz: number) => padL + ((mhz - lo) / (hi - lo)) * plotW;
    const yOf = (v: number) => padT + plotH - v * plotH;

    // Rejilla
    ctx.strokeStyle = 'rgba(125,255,207,0.1)';
    ctx.fillStyle = 'rgba(110,135,129,0.8)';
    ctx.font = '9px "IBM Plex Mono", monospace';
    for (let f = 1250; f <= 1680; f += 50) {
      ctx.beginPath();
      ctx.moveTo(xOf(f), padT);
      ctx.lineTo(xOf(f), padT + plotH);
      ctx.stroke();
      ctx.fillText(String(f), xOf(f) - 10, h - 5);
    }
    for (let v = 0; v <= 1; v += 0.25) {
      ctx.beginPath();
      ctx.moveTo(padL, yOf(v));
      ctx.lineTo(padL + plotW, yOf(v));
      ctx.stroke();
    }

    // Ventana seleccionada
    const tol = 3.2 + level(this.api.state, 'filtro') * 1.7;
    const left = xOf(this.spectrumCenter - tol);
    const right = xOf(this.spectrumCenter + tol);
    const inside = Math.abs(this.spectrumCenter - cap.band) <= tol;
    ctx.fillStyle = inside ? 'rgba(125,255,207,0.16)' : 'rgba(233,196,106,0.1)';
    ctx.fillRect(left, padT, right - left, plotH);
    ctx.strokeStyle = inside ? 'rgba(125,255,207,0.7)' : 'rgba(233,196,106,0.5)';
    ctx.beginPath();
    ctx.moveTo(left, padT);
    ctx.lineTo(left, padT + plotH);
    ctx.moveTo(right, padT);
    ctx.lineTo(right, padT + plotH);
    ctx.stroke();

    // Traza
    ctx.beginPath();
    for (let px = 0; px <= plotW; px += 2) {
      const mhz = lo + (px / plotW) * (hi - lo);
      let v = 0.05 + Math.random() * 0.07;
      const d = mhz - cap.band;
      const amp = 0.45 + (cap.quality / 100) * 0.35;
      v += amp * Math.exp(-Math.pow(d / 0.55, 2));
      v += amp * 0.35 * Math.exp(-Math.pow((d - 7.1) / 0.7, 2));
      v += amp * 0.28 * Math.exp(-Math.pow((d + 9.4) / 0.8, 2));
      v += 0.05 * Math.sin(mhz * 3.1) * Math.random();
      const y = yOf(Math.min(1, v));
      if (px === 0) ctx.moveTo(padL + px, y);
      else ctx.lineTo(padL + px, y);
    }
    ctx.strokeStyle = inside ? '#7dffcf' : '#9ec7bd';
    ctx.lineWidth = 1.2;
    ctx.stroke();

    ctx.fillStyle = 'rgba(125,255,207,0.5)';
    ctx.fillText('dB', 8, padT + 8);
  }

  // ---------- demodulador ----------

  private renderDemod(): void {
    if (this.faultScreen('demod', 'Unidad DM-4 · AM / FM / PULSO / COHERENTE')) return;
    const cap = this.pickCapture(STAGE.AISLADA);
    if (!cap) {
      this.shell(
        'Demodulador',
        'Unidad DM-4 · AM / FM / PULSO / COHERENTE',
        `<div class="notice">Necesitas una captura con la portadora aislada. Pasa antes por el analizador de espectro.</div>
         <div class="row end" style="margin-top:20px"><button data-goto-spec>IR AL ANALIZADOR</button></div>`,
      );
      this.layer.querySelector('[data-goto-spec]')?.addEventListener('click', () => this.open('spectrum'));
      return;
    }
    this.api.selectCapture(cap.id);
    const body = `
      <div class="grid-2">
        <div class="stack">
          <p class="label">Trama recibida · ${cap.band.toFixed(1)} MHz</p>
          <canvas class="machine" data-wave></canvas>
          <div class="mono-box" data-demod-msg><span class="ghost">Observa la envolvente y la densidad de flancos, y elige la modulación.</span></div>
          ${this.bars(cap)}
        </div>
        <div class="stack">
          <p class="label">Selecciona la demodulación</p>
          <div class="grid-2" style="grid-template-columns:1fr 1fr;gap:8px">
            ${MODULATIONS.map(
              (m) =>
                `<button data-mod="${m}" class="small" style="padding:16px 10px">${m}<br /><span style="color:var(--dim);font-size:8px">${MOD_DESC[m]}</span></button>`,
            ).join('')}
          </div>
          <div class="legend">
            <span>AM · amplitud variable</span>
            <span>FM · frecuencia variable</span>
            <span>PULSO · tramas encendidas y apagadas</span>
            <span>COHERENTE · fase estable, casi pura</span>
          </div>
          <div>
            <p class="label">Capturas con portadora aislada</p>
            ${this.captureStrip(this.api.state.captures.filter((c) => !c.sold), cap.id)}
          </div>
        </div>
      </div>
    `;
    const panel = this.shell('Demodulador', 'Unidad DM-4 · AM / FM / PULSO / COHERENTE', body);
    const canvas = panel.querySelector('[data-wave]') as HTMLCanvasElement;
    this.drawWave(canvas, cap.modulation);
    const msg = panel.querySelector('[data-demod-msg]') as HTMLElement;
    panel.querySelectorAll<HTMLElement>('[data-mod]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const modulation = btn.dataset['mod'] as Modulation;
        this.api.setDemodulation(modulation);
        const res = this.api.demod(modulation);
        msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
        if (res.ok) window.setTimeout(() => this.open('decoder'), 650);
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-cap]').forEach((row) => {
      row.addEventListener('click', () => {
        this.api.selectCapture(row.dataset['cap']!);
        this.renderDemod();
      });
    });
  }

  private drawWave(canvas: HTMLCanvasElement, mod: Modulation): void {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth || 480;
    const h = canvas.clientHeight || 210;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    ctx.strokeStyle = 'rgba(125,255,207,0.1)';
    for (let y = 0; y < 5; y++) {
      ctx.beginPath();
      ctx.moveTo(0, (h / 4) * y);
      ctx.lineTo(w, (h / 4) * y);
      ctx.stroke();
    }
    ctx.beginPath();
    const mid = h / 2;
    for (let px = 0; px < w; px += 1) {
      const t = (px / w) * 26;
      let v = 0;
      switch (mod) {
        case 'AM':
          v = Math.sin(t * 9) * (0.5 + 0.38 * Math.sin(t * 0.55)) * 0.85;
          break;
        case 'FM':
          v = Math.sin(t * 9 + 2.6 * Math.sin(t * 0.8)) * 0.72;
          break;
        case 'PULSO':
          v = (Math.sin(t * 2.2) > 0.1 ? (Math.sin(t * 24) > 0 ? 0.7 : -0.7) : 0) + (Math.random() - 0.5) * 0.03;
          break;
        case 'COHERENTE':
          v = Math.sin(t * 11.5) * 0.62 + (Math.random() - 0.5) * 0.03;
          break;
      }
      const y = mid - v * (h * 0.34);
      if (px === 0) ctx.moveTo(0, y);
      else ctx.lineTo(px, y);
    }
    ctx.strokeStyle = '#8fd6ff';
    ctx.lineWidth = 1.1;
    ctx.stroke();
  }

  // ---------- decodificador ----------

  private renderDecoder(): void {
    if (this.faultScreen('decoder', 'Unidad PD-2 · reconstrucción de trama')) return;
    const cap = this.pickCapture(STAGE.DEMODULADA);
    if (!cap) {
      this.shell(
        'Decodificador de patrones',
        'Unidad PD-2 · reconstrucción de trama',
        `<div class="notice">Necesitas una captura demodulada. La cadena es: plato → espectro → demodulador → patrón.</div>
         <div class="row end" style="margin-top:20px"><button data-goto-demod>IR AL DEMODULADOR</button></div>`,
      );
      this.layer.querySelector('[data-goto-demod]')?.addEventListener('click', () => this.open('demod'));
      return;
    }
    this.api.selectCapture(cap.id);
    const hasTable = this.api.state.glyphTable;
    this.api.setCipher(cap.cipher);
    const preview = previewText(cap, hasTable);
    const body = `
      <div class="grid-2">
        <div class="stack">
          <p class="label">Trama parcial · integridad ${Math.round(cap.quality)}%</p>
          <div class="mono-box tall" data-pattern>${escapeHtml(preview)}</div>
          ${this.bars(cap)}
          <div class="mono-box" data-decode-msg><span class="ghost">La firma del patrón está en la estructura del texto. Elige el cifrado correcto.</span></div>
        </div>
        <div class="stack">
          <p class="label">Firma detectada</p>
          <div class="mono-box" style="min-height:0">${escapeHtml(CIPHER_INFO[cap.cipher].signature)}</div>
          <div class="stack tight">
            ${CIPHERS.map(
              (c) => `<button data-cipher="${c}" class="small" style="text-align:left">
                ${CIPHER_INFO[c].name.toUpperCase()}
                <br /><span style="color:var(--dim);font-size:9px;letter-spacing:0.02em">${c === 'VACIO' && !hasTable ? 'requiere tabla de glifos' : CIPHER_INFO[c].hint}</span>
              </button>`,
            ).join('')}
          </div>
          <span class="legend">Fallar degrada la captura. Puedes reintentar hasta que se convierta en ruido.</span>
        </div>
      </div>
    `;
    const panel = this.shell('Decodificador de patrones', 'Unidad PD-2 · reconstrucción de trama', body);
    const msg = panel.querySelector('[data-decode-msg]') as HTMLElement;
    panel.querySelectorAll<HTMLElement>('[data-cipher]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const cipher = btn.dataset['cipher'] as Cipher;
        this.api.setCipher(cipher);
        const res = this.api.decode(cipher);
        msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
        if (res.ok) {
          window.setTimeout(() => this.renderDecoder(), 400);
        } else {
          const pattern = panel.querySelector('[data-pattern]') as HTMLElement;
          const c2 = this.pickCapture(STAGE.DEMODULADA);
          if (c2) pattern.textContent = previewText(c2, hasTable);
        }
      });
    });
  }

  // ---------- triangulación (repetidor) ----------

  private renderTri(): void {
    const t = this.api.triTelemetry();
    const s = this.api.state;
    const body = `
      <div class="grid-2">
        <div class="stack">
          <div>
            <p class="label">Carta del valle · 900 m al sur de Kestrel</p>
            <canvas class="machine" data-tri-map></canvas>
          </div>
          <div class="mono-box" data-tri-msg><span class="ghost">Gira cada mástil hasta el máximo de aguja y fija su rumbo. Con los tres rumbos fijados, la intersección es el origen.</span></div>
          ${
            t.fixed
              ? `<div class="card">
                  <div class="row between"><h4>ORIGEN LOCALIZADO · ${t.fixed.name}</h4><span class="cost">${CLASS_INFO[t.fixed.klass].label.toUpperCase()}</span></div>
                  <p>Intersección a ${t.fixed.distance.toFixed(0)} m del repetidor · dispersión ${t.fixed.spread.toFixed(1)} m · día ${s.day}</p>
                  <div class="row">
                    <button class="small" data-tri-repeat>REPETIR MEDIDA</button>
                    ${t.visited ? '<span class="legend">Los restos del emisor ya están registrados.</span>' : '<button class="small primary" data-tri-go>IR AL ORIGEN EN MOTONIEVE</button>'}
                  </div>
                </div>`
              : ''
          }
        </div>
        <div class="stack tight">
          ${t.masts
            .map(
              (m, i) => `
            <div class="card">
              <div class="row between"><h4>${m.label.toUpperCase()}</h4><span class="cost">${m.locked ? `FIJADO ${m.aim.toFixed(0)}°` : 'SIN MEDIR'}</span></div>
              <p>Apuntado ${m.aim.toFixed(1)}° · calidad de la medida ${Math.round(m.quality * 100)}%</p>
              <input type="range" min="0" max="359.5" step="0.5" value="${m.aim}" data-mast-range="${i}" />
              <div class="bar-row"><span>AGUJA</span><div class="track"><i data-mast-bar="${i}" style="width:${Math.round(t.strengths[i]! * 100)}%"></i></div><span data-mast-pct="${i}">${Math.round(t.strengths[i]! * 100)}%</span></div>
              <div class="row">
                <button class="small" data-mast-fix="${i}">FIJAR RUMBO</button>
                <span class="spacer"></span>
                <span class="legend" data-mast-hint="${i}">${m.locked ? (m.quality >= 0.55 ? 'rumbo válido' : 'rumbo flojo') : 'gira hasta el máximo'}</span>
              </div>
            </div>`,
            )
            .join('')}
          <button class="primary" data-tri-fix ${t.locked === 3 ? '' : 'disabled'}>TRIANGULAR (${t.locked}/3)</button>
        </div>
      </div>
    `;
    const panel = this.shell('Consola del repetidor', 'Kestrel remota · tres mástiles de medida · sin operador', body);
    const msg = panel.querySelector('[data-tri-msg]') as HTMLElement;
    const canvas = panel.querySelector('[data-tri-map]') as HTMLCanvasElement;
    this.drawTriMap(canvas);

    panel.querySelectorAll<HTMLInputElement>('[data-mast-range]').forEach((range) => {
      const index = Number(range.dataset['mastRange']);
      range.addEventListener('input', () => {
        this.api.aimMast(index, Number(range.value));
        const t2 = this.api.triTelemetry();
        const bar = panel.querySelector(`[data-mast-bar="${index}"]`) as HTMLElement | null;
        const pct = panel.querySelector(`[data-mast-pct="${index}"]`) as HTMLElement | null;
        if (bar) bar.style.width = `${Math.round(t2.strengths[index]! * 100)}%`;
        if (pct) pct.textContent = `${Math.round(t2.strengths[index]! * 100)}%`;
        this.drawTriMap(canvas);
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-mast-fix]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const res = this.api.lockMast(Number(btn.dataset['mastFix']));
        msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
        this.renderTri();
      });
    });
    panel.querySelector('[data-tri-fix]')?.addEventListener('click', () => {
      const res = this.api.triangulate();
      msg.innerHTML = res.ok ? `<span class="hot">${res.message}</span>` : `<span class="warn">${res.message}</span>`;
      this.renderTri();
    });
    panel.querySelector('[data-tri-repeat]')?.addEventListener('click', () => {
      this.api.resetMasts();
      this.renderTri();
    });
    panel.querySelector('[data-tri-go]')?.addEventListener('click', () => {
      const res = this.api.travel('origen');
      this.hud.toast(res.message, res.ok ? 'info' : 'warn');
      if (res.ok) this.close();
    });
  }

  private drawTriMap(canvas: HTMLCanvasElement): void {
    const t = this.api.triTelemetry();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = canvas.clientWidth || 560;
    const h = canvas.clientHeight || 220;
    canvas.width = Math.round(w * dpr);
    canvas.height = Math.round(h * dpr);
    const ctx = canvas.getContext('2d')!;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);

    const pad = 18;
    const xs = t.masts.map((m) => m.x);
    const zs = t.masts.map((m) => m.z);
    if (t.fixed) {
      xs.push(t.fixed.x);
      zs.push(t.fixed.z);
    }
    let minX = Math.min(...xs) - 60;
    let maxX = Math.max(...xs) + 60;
    let minZ = Math.min(...zs) - 60;
    let maxZ = Math.max(...zs) + 60;
    if (!t.fixed) maxZ = minZ + Math.max(160, maxZ - minZ);
    const spanX = Math.max(1, maxX - minX);
    const spanZ = Math.max(1, maxZ - minZ);
    const scale = Math.min((w - pad * 2) / spanX, (h - pad * 2) / spanZ);
    const ox = pad + ((w - pad * 2) - spanX * scale) / 2;
    const oy = pad + ((h - pad * 2) - spanZ * scale) / 2;
    const px = (x: number) => ox + (x - minX) * scale;
    const py = (z: number) => oy + (z - minZ) * scale;

    ctx.strokeStyle = 'rgba(125,255,207,0.1)';
    for (let g = 0; g <= 6; g++) {
      const gx = pad + ((w - pad * 2) / 6) * g;
      const gy = pad + ((h - pad * 2) / 6) * g;
      ctx.beginPath();
      ctx.moveTo(gx, pad);
      ctx.lineTo(gx, h - pad);
      ctx.moveTo(pad, gy);
      ctx.lineTo(w - pad, gy);
      ctx.stroke();
    }

    // Rumbos medidos: rectas infinitas recortadas al recuadro.
    const diag = Math.hypot(w, h) / scale;
    t.masts.forEach((m, i) => {
      const rad = (m.aim * Math.PI) / 180;
      const dx = Math.sin(rad);
      const dz = Math.cos(rad);
      ctx.strokeStyle = m.locked ? 'rgba(125,255,207,0.55)' : 'rgba(233,196,106,0.35)';
      ctx.beginPath();
      ctx.moveTo(px(m.x), py(m.z));
      ctx.lineTo(px(m.x + dx * diag * 2), py(m.z + dz * diag * 2));
      ctx.stroke();

      ctx.fillStyle = m.locked ? '#7dffcf' : '#e9c46a';
      ctx.beginPath();
      ctx.arc(px(m.x), py(m.z), 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.font = '9px "IBM Plex Mono", monospace';
      ctx.fillText(String.fromCharCode(65 + i), px(m.x) + 6, py(m.z) - 6);
    });

    if (t.fixed) {
      const fx = px(t.fixed.x);
      const fy = py(t.fixed.z);
      ctx.strokeStyle = 'rgba(226,103,122,0.9)';
      ctx.lineWidth = 1.4;
      ctx.beginPath();
      ctx.arc(fx, fy, Math.max(3, t.fixed.spread * scale), 0, Math.PI * 2);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(fx - 8, fy);
      ctx.lineTo(fx + 8, fy);
      ctx.moveTo(fx, fy - 8);
      ctx.lineTo(fx, fy + 8);
      ctx.stroke();
      ctx.fillStyle = 'rgba(226,103,122,0.85)';
      ctx.fillText(t.fixed.name, fx + 10, fy + 12);
      ctx.fillStyle = 'rgba(110,135,129,0.8)';
      ctx.fillText('≈', ox, h - 5);
    }
  }

  // ---------- motonieve ----------

  private renderTravel(): void {
    const opts = this.api.travelOptions();
    const travel = this.api.traveling();
    if (travel.active) {
      const body = `
        <div class="stack">
          <div class="notice"><b>EN RUTA</b><br />${travel.label}</div>
          <div class="bar-row"><span>CAMINO</span><div class="track"><i style="width:${Math.round(travel.progress * 100)}%"></i></div><span>${Math.round(travel.progress * 100)}%</span></div>
          <span class="legend">El faro de la motonieve abre un cono de nieve de treinta metros. Detrás, la oscuridad se cierra a la misma velocidad.</span>
        </div>
      `;
      this.shell('Motonieve', 'Kestrel · ruta de invierno', body);
      return;
    }
    const body = `
      <div class="stack">
        <div class="notice">El depósito tiene para lo que tiene. Cada viaje cuesta tiempo de turno y un tramo de frío a la intemperie.</div>
        ${opts
          .map(
            (o) => `<div class="card">
              <div class="row between"><h4>${o.label.toUpperCase()}</h4><span class="cost">${o.enabled ? 'DISPONIBLE' : 'BLOQUEADO'}</span></div>
              <p>${o.detail}</p>
              <button class="small ${o.enabled ? 'primary' : ''}" data-travel="${o.dest}" ${o.enabled ? '' : 'disabled'}>${o.dest === 'kestrel' ? 'VOLVER A KESTREL' : o.dest === 'repetidor' ? 'SALIR AL REPETIDOR' : 'IR AL ORIGEN'}</button>
            </div>`,
          )
          .join('')}
      </div>
    `;
    const panel = this.shell('Motonieve', 'Kestrel · ruta de invierno', body);
    panel.querySelectorAll<HTMLElement>('[data-travel]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const res = this.api.travel(btn.dataset['travel'] as 'kestrel' | 'repetidor' | 'origen');
        this.hud.toast(res.message, res.ok ? 'info' : 'warn');
        this.renderTravel();
      });
    });
  }

  // ---------- trueque ----------

  private renderTrade(): void {
    const v = this.api.tradeView();
    if (!v.active) {
      this.shell(
        'Trueque',
        'Cajón del porche',
        `<div class="notice">No hay ningún cajón en el porche. Cuando algo deje una lista, aparecerá aquí.</div>`,
      );
      return;
    }
    const body = `
      <div class="grid-2">
        <div class="stack">
          <div class="notice bad">
            <b>EL CAJÓN PIDE</b><br />${v.wantsLabel}<br />
            Deja a cambio: ${v.reward} créditos${v.fragments > 0 ? ` · +${v.fragments} fragmento(s)` : ''}${v.parts > 0 ? ' · +1 pieza de repuesto' : ''}
          </div>
          <p class="quote">${v.flavor}</p>
          <span class="legend">Lo que entrega el cajón no pasa por Control: no cuenta para la cuota del turno.</span>
        </div>
        <div class="stack">
          <p class="label">Capturas que aceptaría</p>
          ${
            v.candidates.length === 0
              ? `<div class="mono-box"><span class="ghost">Ninguna captura del archivador encaja con la lista.</span></div>`
              : v.candidates
                  .map(
                    (c) => `<div class="card">
                      <div class="row between"><h4>${CLASS_INFO[c.klass].glyph} ${c.name}</h4><span class="cost">${CLASS_INFO[c.klass].label}</span></div>
                      <p>${c.band.toFixed(1)} MHz · integridad ${Math.round(c.quality)}% · valor de mercado ${saleValue(c)} cr</p>
                      <button class="small primary" data-deliver="${c.id}">ENTREGAR AL CAJÓN</button>
                    </div>`,
                  )
                  .join('')
          }
        </div>
      </div>
    `;
    const panel = this.shell('Trueque', 'Cajón del porche · trueque del comerciante', body);
    panel.querySelectorAll<HTMLElement>('[data-deliver]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const res = this.api.trade(btn.dataset['deliver']!);
        this.hud.toast(res.message, res.ok ? 'good' : 'warn');
        this.renderTrade();
      });
    });
  }

  // ---------- consola ----------

  private renderPc(): void {
    const s = this.api.state;
    const tab = this.pcTab;
    const tabs = (['archivo', 'tienda', 'registro', 'control'] as const)
      .map(
        (t) =>
          `<button class="tab ${tab === t ? 'active' : ''}" data-tab="${t}">${t.toUpperCase()}</button>`,
      )
      .join('');

    let content = '';
    if (tab === 'archivo') content = this.pcArchive();
    else if (tab === 'tienda') content = this.pcShop();
    else if (tab === 'registro') content = this.pcLog();
    else content = this.pcControl();

    const panel = this.shell(
      'Consola principal',
      `kestrel.ops · turno ${s.day} · ${clockLabel(s.clock)}`,
      `<div class="tabs">${tabs}</div>${content}`,
    );

    panel.querySelectorAll<HTMLElement>('[data-tab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.pcTab = btn.dataset['tab'] as typeof this.pcTab;
        this.renderPc();
      });
    });

    panel.querySelectorAll<HTMLElement>('[data-open-cap]').forEach((row) => {
      row.addEventListener('click', () => {
        this.api.selectCapture(row.dataset['openCap']!);
        const cap = this.api.selectedCapture();
        if (!cap) return;
        if (cap.stage === STAGE.CRUDA) this.open('spectrum');
        else if (cap.stage === STAGE.AISLADA) this.open('demod');
        else if (cap.stage === STAGE.DEMODULADA) this.open('decoder');
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-sell]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.api.sell(btn.dataset['sell']!);
        this.renderPc();
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-archive]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.api.archive(btn.dataset['archive']!);
        this.renderPc();
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-buy]').forEach((btn) => {
      btn.addEventListener('click', () => {
        this.api.buy(btn.dataset['buy']!);
        this.renderPc();
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-buy-part]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const res = this.api.buyPart();
        this.hud.toast(res.message, res.ok ? 'good' : 'warn');
        this.renderPc();
      });
    });
    panel.querySelector('[data-transmit]')?.addEventListener('click', () => {
      const screen = this.hud.showScreen(`
        <div class="eyebrow">TRANSMISOR DE BANDA ANCHA</div>
        <h1>RESPONDER</h1>
        <h2>La antena puede emitir. Nada garantiza que solo te escuche el cielo.</h2>
        <p class="quote">Coste: 40 créditos de mantenimiento. El registro de transmisiones queda a tu nombre. Aumenta el estrés y puede atraer una respuesta.</p>
        <div class="actions">
          <button class="ghost" data-cancel>CANCELAR</button>
          <button class="danger" data-go>TRANSMITIR</button>
        </div>
      `);
      screen.querySelector('[data-cancel]')?.addEventListener('click', () => this.hud.closeScreen());
      screen.querySelector('[data-go]')?.addEventListener('click', () => {
        this.hud.closeScreen();
        this.api.transmit();
        this.renderPc();
      });
    });
    panel.querySelector('[data-sleep]')?.addEventListener('click', () => {
      this.api.sleep();
      this.close();
    });
    panel.querySelector('[data-save]')?.addEventListener('click', () => {
      this.api.saveNow();
    });
    panel.querySelectorAll<HTMLElement>('[data-quality]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const q = btn.dataset['quality'] as 'alta' | 'media' | 'baja';
        this.api.setQuality(q);
        this.renderPc();
      });
    });
    panel.querySelectorAll<HTMLElement>('[data-ending]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const ending = btn.dataset['ending'] as 'cortar' | 'responder' | 'disolver';
        this.close();
        this.api.finish(ending);
      });
    });
  }

  private pcArchive(): string {
    const s = this.api.state;
    const caps = s.captures.filter((c) => !c.sold);
    const tradeNote = s.flags['comerciante_activo']
      ? `<div class="notice bad">Hay un cajón en el porche con una lista dentro. Se abre con la mano, no con la consola.</div>`
      : '';
    if (caps.length === 0) {
      return `<div class="notice">El archivador está vacío. Usa el terminal del plato para grabar una señal.</div>${tradeNote}`;
    }
    return `
      <div class="stack">
        ${tradeNote}
        <div class="row between">
          <span class="legend">${caps.length}/${capacity(s)} HUECOS · ${s.points} CRÉDITOS</span>
          <span class="legend">Orden: más reciente primero</span>
        </div>
        ${caps
          .map((c) => {
            const done = c.stage >= STAGE.DECODIFICADA;
            return `<div class="card">
              <div class="row between">
                <h4>${done ? `${CLASS_INFO[c.klass].glyph} ${c.name}` : '▤ SEÑAL SIN IDENTIFICAR'}</h4>
                <span class="cost">${done ? `${saleValue(c)} cr` : 'sin valor'}</span>
              </div>
              <p>${c.band.toFixed(1)} MHz · ${STAGE_LABEL[c.stage]} · integridad ${Math.round(c.quality)}% · corrupción ${Math.round(c.corruption)}% ${done ? `· ${CLASS_INFO[c.klass].label}` : ''}</p>
              ${done && c.text ? `<div class="mono-box" style="min-height:0">${escapeHtml(c.text)}</div>` : ''}
              <div class="row">
                ${
                  done
                    ? `<button class="primary small" data-sell="${c.id}">VENDER</button><button class="ghost small" data-archive="${c.id}">ARCHIVAR</button>`
                    : `<button class="small" data-open-cap="${c.id}">CONTINUAR CADENA →</button><button class="ghost small" data-archive="${c.id}">DESCARTAR</button>`
                }
              </div>
            </div>`;
          })
          .join('')}
      </div>
    `;
  }

  private pcShop(): string {
    const s = this.api.state;
    return `
      <div class="row between" style="margin-bottom:14px">
        <span class="legend">PRESUPUESTO <b style="color:var(--amber)">${s.points} CR</b></span>
        <span class="legend">Las mejoras se aplican al instante.</span>
      </div>
      <div class="grid-3" style="margin-bottom:16px">
        <div class="card">
          <div class="row between"><h4>PIEZAS DE REPUESTO</h4><div class="levels"><i class="${s.parts > 0 ? 'on' : ''}"></i></div></div>
          <p>Juntas, agujas y un juego de contactos para la cadena. Sustituye una pieza y devuelve una máquina averiada al servicio al instante.</p>
          <div class="row between">
            <span class="cost">${PART_COST} CR · tienes ${s.parts}</span>
            <button class="small ${s.points >= PART_COST ? 'primary' : ''}" data-buy-part ${s.points >= PART_COST ? '' : 'disabled'}>COMPRAR</button>
          </div>
        </div>
      </div>
      <div class="grid-3">
        ${UPGRADES.map((u) => {
          const lvl = level(s, u.id);
          const cost = upgradeCost(s, u.id);
          const maxed = lvl >= u.max;
          return `<div class="card">
            <div class="row between"><h4>${u.name.toUpperCase()}</h4><div class="levels">${Array.from({ length: u.max }, (_, i) => `<i class="${i < lvl ? 'on' : ''}"></i>`).join('')}</div></div>
            <p>${u.desc}</p>
            <div class="row between">
              <span class="cost">${maxed ? 'MÁXIMO' : `${cost} CR`}</span>
              <button class="small ${maxed ? '' : 'primary'}" data-buy="${u.id}" ${maxed || s.points < cost ? 'disabled' : ''}>${maxed ? 'COMPLETO' : 'MEJORAR'}</button>
            </div>
          </div>`;
        }).join('')}
      </div>
    `;
  }

  private pcLog(): string {
    const s = this.api.state;
    return `
      <div class="grid-2" style="grid-template-columns:1.25fr 0.75fr">
        <div>
          <p class="label">Registro de la estación</p>
          <div class="log-list">
            ${s.log.length === 0 ? '<span class="ghost">Sin entradas todavía.</span>' : s.log
              .map((l) => `<div class="log-entry ${l.kind}"><span class="t">D${l.day} ${l.time}</span><span>${escapeHtml(l.text)}</span></div>`)
              .join('')}
          </div>
        </div>
        <div class="stack tight">
          <p class="label">Analítica de la estación</p>
          <div class="bar-row"><span>DECODIFICADAS</span><span class="spacer"></span><span>${s.stats.decoded}</span></div>
          <div class="bar-row"><span>VENDIDAS</span><span class="spacer"></span><span>${s.stats.sold}</span></div>
          <div class="bar-row"><span>CONTACTOS</span><span class="spacer"></span><span>${s.stats.contacts}</span></div>
          <div class="bar-row"><span>ESCANEOS</span><span class="spacer"></span><span>${s.stats.scans}</span></div>
          <div class="bar-row"><span>TRANSMISIONES</span><span class="spacer"></span><span>${s.stats.answered}</span></div>
          <div class="bar-row"><span>APAGONES</span><span class="spacer"></span><span>${s.stats.blackouts}</span></div>
          <div class="bar-row"><span>FRAGMENTOS</span><span class="spacer"></span><span>${s.fragments}</span></div>
          <div class="mono-box" style="min-height:0;margin-top:8px">Coherencia acumulada: ${s.fragments} / 12\n${s.glyphTable ? 'Tabla de glifos: recuperada.' : 'Tabla de glifos: ausente.'}</div>
          <span class="legend">Los fragmentos se obtienen decodificando señales anómalas y observando contactos.</span>
        </div>
      </div>
    `;
  }

  private pcControl(): string {
    const s = this.api.state;
    const canEnd = this.api.sim.canFinish();
    const broken = MACHINES.filter((m) => faultOf(s, m.id).broken);
    return `
      <div class="stack">
        <div class="grid-2" style="gap:20px">
          <div class="card">
            <h4>PARTE DE CONTROL</h4>
            <p>Cuota del turno: ${s.quota.earned} / ${s.quota.target} créditos.<br />Turnos fallidos: ${s.quota.failedDays}.<br />Quedan ${Math.max(0, Math.ceil(this.api.sim.shiftMinutesLeft))} minutos de turno.</p>
            <p>Clima: <b>${this.api.weatherLabel()}</b>. ${WEATHER_NOTE[s.weather.kind]}<br />
            Máquinas fuera de servicio: ${broken.length === 0 ? 'ninguna' : broken.map((m) => m.short).join(' · ')}.<br />
            Piezas de repuesto: ${s.parts}.</p>
            <div class="row">
              <button class="small" data-transmit>TRANSMITIR (40 CR)</button>
              <button class="small" data-sleep>CERRAR TURNO E IR A DORMIR</button>
            </div>
          </div>
          <div class="card">
            <h4>REGISTRO DE PANTALLA</h4>
            <p>Calidad gráfica actual: <b style="color:var(--green)">${s.quality.toUpperCase()}</b>. Si el equipo no sostiene 60 fps, baja la resolución automáticamente.</p>
            <div class="row">
              <button class="small ${s.quality === 'alta' ? 'primary' : ''}" data-quality="alta">ALTA</button>
              <button class="small ${s.quality === 'media' ? 'primary' : ''}" data-quality="media">MEDIA</button>
              <button class="small ${s.quality === 'baja' ? 'primary' : ''}" data-quality="baja">BAJA</button>
              <button class="ghost small" data-save>GUARDAR AHORA</button>
            </div>
          </div>
        </div>
        <div class="notice">
          La salida de la estación está cerrada por nieve. El único camino es terminar el turno.<br />
          Guardado: ${escapeHtml(this.api.storageLabel())} · partida versión 1.
        </div>
        ${
          s.decisions.length > 0
            ? `<div class="card">
                <h4>DECISIONES DEL ACTO II</h4>
                <p>${s.decisions.map((d) => DECISION_LABEL[d] ?? d).join('<br />')}</p>
                <span class="legend">Lo que decidiste sigue en pie y aparecerá en el epílogo.</span>
              </div>`
            : ''
        }
        ${
          canEnd
            ? `<div class="card" style="border-color:rgba(226,103,122,0.5)">
                <h4>SEÑAL FINAL · ELIGE CÓMO TERMINA</h4>
                <p>Tienes ${s.fragments} fragmentos de coherencia. El receptor puede cerrar la banda, responder o quedarse escuchando para siempre.</p>
                <div class="row">
                  <button class="small danger" data-ending="cortar">CORTAR LA SEÑAL</button>
                  <button class="small danger" data-ending="responder">RESPONDER</button>
                  <button class="small danger" data-ending="disolver">DEJAR DE ESCUCHAR</button>
                </div>
              </div>`
            : `<div class="notice">El desenlace requiere el día 12 y 12 fragmentos de coherencia (${s.fragments}/12).</div>`
        }
      </div>
    `;
  }

  /** Llamado desde el bucle principal para refrescar el panel abierto. */
  tick(): void {
    if (this.openId !== 'dish') {
      this.maybeRefresh();
      return;
    }
    const d = this.api.dish;
    const az = this.refs['az'] as HTMLElement | undefined;
    const el = this.refs['el'] as HTMLElement | undefined;
    const azRange = this.refs['azRange'] as HTMLInputElement | undefined;
    const elRange = this.refs['elRange'] as HTMLInputElement | undefined;
    const readout = this.refs['dishReadout'] as HTMLElement | undefined;
    const strength = this.refs['strength'] as HTMLElement | undefined;
    const strengthBar = this.refs['strengthBar'] as HTMLElement | undefined;
    const lock = this.refs['lock'] as HTMLElement | undefined;
    const recordBtn = this.refs['recordBtn'] as HTMLButtonElement | null | undefined;
    const recordHint = this.refs['recordHint'] as HTMLElement | null | undefined;
    const recBar = this.refs['recBar'] as HTMLElement | null | undefined;
    const recPct = this.refs['recPct'] as HTMLElement | null | undefined;

    if (az) az.innerHTML = `${d.az.toFixed(1)}<small>°</small>`;
    if (el) el.innerHTML = `${d.el.toFixed(1)}<small>°</small>`;
    if (azRange && document.activeElement !== azRange) azRange.value = String(d.az);
    if (elRange && document.activeElement !== elRange) elRange.value = String(d.el);
    if (readout) readout.innerHTML = this.dishReadout();
    if (strength) strength.innerHTML = `${Math.round(d.strength)}<small>%</small>`;
    if (strengthBar) strengthBar.style.width = `${Math.round(d.strength)}%`;
    if (lock) lock.textContent = d.locked ? 'LOCK' : '—';
    if (recordBtn) recordBtn.disabled = !(d.locked && this.api.state.power);
    if (recordHint) {
      recordHint.textContent = d.locked
        ? 'Enlace estable: la captura conservará la integridad del apuntado.'
        : 'Ajusta azimut y elevación hasta superar el 45 % de señal.';
    }
    if (recBar) recBar.style.width = `${Math.round(d.progress * 100)}%`;
    if (recPct) recPct.textContent = `${Math.round(d.progress * 100)}%`;

    // Cambiar entre grabar/cancelar exige reconstruir ese bloque.
    if (this.lastRecording !== d.recording) {
      this.lastRecording = d.recording;
      this.renderDish();
      return;
    }
    this.drawDish();
  }

  /**
   * El resto de paneles se refrescan solos cuando cambia algo que los afecta
   * (clima, averías, piezas, ruta de la motonieve). Sin reconstruir por frame.
   */
  private maybeRefresh(): void {
    const id = this.openId;
    if (id !== 'pc' && id !== 'tri' && id !== 'travel' && id !== 'trade') return;
    const now = Date.now();
    if (now - this.lastRefresh < 650) return;
    this.lastRefresh = now;
    const key = this.refreshKey();
    if (key === this.lastKey) return;
    this.lastKey = key;
    this.render();
  }

  private refreshKey(): string {
    const s = this.api.state;
    const travel = this.api.traveling();
    const tri = this.openId === 'tri' ? this.api.triTelemetry() : null;
    return [
      this.openId,
      s.day,
      s.points,
      s.parts,
      Math.round(s.stress / 2),
      s.weather.kind,
      Math.round(s.weather.intensity * 10),
      Object.keys(s.faults).length,
      s.quota.earned,
      s.decisions.length,
      s.captures.filter((c) => !c.sold).length,
      travel.active ? `ruta${Math.round(travel.progress * 20)}` : 'fijo',
      tri ? `${tri.locked}${tri.fixed ? 'F' : ''}${tri.visited ? 'V' : ''}` : '',
      s.flags['comerciante_activo'] ? 'trueque' : '',
    ].join('|');
  }
}

const MOD_DESC: Record<Modulation, string> = {
  AM: 'envolvente',
  FM: 'frecuencia',
  PULSO: 'tramos',
  COHERENTE: 'fase pura',
};

const WEATHER_NOTE: Record<string, string> = {
  clara: 'La banda está limpia.',
  niebla: 'La humedad se come las portadoras débiles.',
  tormenta: 'Estática de banda ancha: el demodulador no distingue tramas.',
  ventisca: 'El viento tapa el linde y borra el rastro.',
};

/** Texto del epílogo de cada decisión del acto II. */
const DECISION_LABEL: Record<string, string> = {
  'archivo_operador:leer': 'Leíste la carpeta del operador anterior y no la reportaste.',
  'archivo_operador:entregar': 'Entregaste la carpeta a Control. La prima llegó antes que la respuesta.',
  'baliza:contestar': 'Diste el código de la puerta del repetidor a una voz con tu timbre.',
  'baliza:desconectar': 'Cortaste la radio a media palabra.',
  'registro:firmar': 'Firmaste un registro escrito con tu letra antes de que ocurriera.',
  'registro:borrar': 'Arrancaste la hoja del registro. Control contó la que falta.',
};

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
}
