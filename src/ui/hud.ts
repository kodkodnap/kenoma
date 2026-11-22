// HUD y pantallas. DOM puro, sin frameworks: se actualiza cada frame con
// escrituras mínimas y diffs para no castigar el rendimiento.

import type { DecisionPrompt, ShiftSummary, EndingId } from '../core/sim';
import type { GameState } from '../core/state';
import { clockLabel, shiftPhase, shiftProgress } from '../core/time';
import { weatherLabel } from '../core/weather';
import type { ToastKind } from './types';

/** Texto del epílogo de cada decisión del acto II. */
const DECISION_EPILOGUE: Record<string, string> = {
  'archivo_operador:leer': 'Leíste su carpeta y no la reportaste. Las cuarenta horas de escucha caben en una noche.',
  'archivo_operador:entregar': 'Entregaste su carpeta. Control nunca encontró un expediente que cerrar a su nombre.',
  'baliza:contestar': 'Diste el código de la puerta del repetidor. Alguien entró y no cerró.',
  'baliza:desconectar': 'Cortaste la radio. La cerradura volvió a su sitio sin que nadie la tocara.',
  'registro:firmar': 'Firmaste el registro antes de vivirlo. La última entrada sigue escribiéndose.',
  'registro:borrar': 'Arrancaste la hoja. El hueco quedó en el expediente, con fecha y hora.',
};

const CONTROLS = 'WASD mover · Ratón mirar · Shift correr · E interactuar · F linterna · Q escáner · Tab registro · Esc pausa';

export class Hud {
  private root: HTMLElement;
  readonly layer: HTMLElement;
  private screenLayer: HTMLElement;
  readonly panelLayer: HTMLElement;

  private clockEl!: HTMLElement;
  private phaseEl!: HTMLElement;
  private dayEl!: HTMLElement;
  private quotaEl!: HTMLElement;
  private pointsEl!: HTMLElement;
  private stressBar!: HTMLElement;
  private stressLabel!: HTMLElement;
  private fpsEl!: HTMLElement;
  private tasksEl!: HTMLElement;
  private promptEl!: HTMLElement;
  private crosshairEl!: HTMLElement;
  private toastsEl!: HTMLElement;
  private scanEl!: HTMLElement;
  private scanBar!: HTMLElement;
  private powerEl!: HTMLElement;
  private weatherEl!: HTMLElement;

  private tasksCache = '';
  private lastClock = '';
  private lastPoints = -1;
  private lastStress = -1;
  private lastQuota = -1;
  private lastWeather = '';
  private scanHide = 0;

  constructor() {
    this.root = document.getElementById('hud')!;
    this.layer = document.getElementById('overlay')!;
    this.root.innerHTML = `
      <div class="hud-top">
        <div>
          <div class="tag">Kestrel · 46°33′N 8°04′E</div>
          <div class="clock"><span data-clock>19:00</span><span class="phase" data-phase>noche</span></div>
          <div class="day">TURNO <b data-day>1</b> · CUOTA <span data-quota>0/125</span> · <span data-power>SISTEMA OK</span> · <span data-weather>CIELO ABIERTO</span></div>
        </div>
        <div class="hud-right">
          <div class="meter">CRÉDITOS <b data-points>0</b></div>
          <div class="meter">ESTRÉS <b data-stress-label>14</b>
            <div class="bar" id="stressBar"><i data-stress></i></div>
          </div>
          <div class="fps" data-fps>— fps</div>
        </div>
      </div>
      <div class="hud-tasks" data-tasks></div>
      <div class="crosshair" data-crosshair></div>
      <div class="prompt" data-prompt></div>
      <div class="toasts" data-toasts></div>
      <div class="scan" data-scan>
        <div class="frame"></div>
        <div class="scan-bar"><i></i></div>
        <p>lectura de campo</p>
      </div>
      <div class="hud-bottom">${CONTROLS}</div>
    `;

    this.clockEl = this.q('[data-clock]');
    this.phaseEl = this.q('[data-phase]');
    this.dayEl = this.q('[data-day]');
    this.quotaEl = this.q('[data-quota]');
    this.pointsEl = this.q('[data-points]');
    this.stressBar = this.q('[data-stress]');
    this.stressLabel = this.q('[data-stress-label]');
    this.fpsEl = this.q('[data-fps]');
    this.tasksEl = this.q('[data-tasks]');
    this.promptEl = this.q('[data-prompt]');
    this.crosshairEl = this.q('[data-crosshair]');
    this.toastsEl = this.q('[data-toasts]');
    this.scanEl = this.q('[data-scan]');
    this.scanBar = this.q('[data-scan] .scan-bar > i');
    this.powerEl = this.q('[data-power]');
    this.weatherEl = this.q('[data-weather]');

    this.panelLayer = document.createElement('div');
    this.panelLayer.className = 'panel-layer';
    this.layer.appendChild(this.panelLayer);

    this.screenLayer = document.createElement('div');
    this.screenLayer.className = 'screen-layer';
    this.layer.appendChild(this.screenLayer);
  }

  private q<T extends HTMLElement = HTMLElement>(sel: string): T {
    return this.root.querySelector(sel) as T;
  }

  update(state: GameState, fps: number): void {
    const clock = clockLabel(state.clock);
    if (clock !== this.lastClock) {
      this.lastClock = clock;
      this.clockEl.textContent = clock;
      this.phaseEl.textContent = shiftPhase(state.clock);
    }
    this.dayEl.textContent = String(state.day);
    if (state.points !== this.lastPoints) {
      this.lastPoints = state.points;
      this.pointsEl.textContent = state.points.toLocaleString('es-ES');
    }
    if (state.stress !== this.lastStress) {
      this.lastStress = state.stress;
      const v = Math.round(state.stress);
      this.stressBar.style.width = `${v}%`;
      this.stressLabel.textContent = String(v);
      this.root.style.setProperty('--stress', String(v));
      document.documentElement.style.setProperty('--stress', String(v));
    }
    if (state.quota.earned !== this.lastQuota) {
      this.lastQuota = state.quota.earned;
      this.quotaEl.textContent = `${state.quota.earned}/${state.quota.target}`;
      this.quotaEl.classList.toggle('low', state.quota.earned < state.quota.target * 0.5);
    }

    this.fpsEl.textContent = `${Math.round(fps)} fps · ${shiftProgress(state.clock) > 0.99 ? 'fin de turno' : 'turno activo'}`;

    const powered = state.power;
    this.powerEl.textContent = powered ? 'SISTEMA OK' : 'SIN CORRIENTE';
    this.powerEl.style.color = powered ? '' : 'var(--red)';

    const weather = weatherLabel(state);
    if (weather !== this.lastWeather) {
      this.lastWeather = weather;
      this.weatherEl.textContent = weather.toUpperCase();
      this.weatherEl.style.color = state.weather.kind === 'clara' ? '' : 'var(--amber)';
    }

    const tasks = state.tasks
      .map((t) => {
        const count = t.kind === 'no_blackout' ? '' : ` <span class="count">${Math.min(t.progress, t.target)}/${t.target}</span>`;
        return `<div class="task ${t.done ? 'done' : ''}">${t.text}${count}</div>`;
      })
      .join('');
    const key = tasks + state.tasks.map((t) => t.done).join();
    if (key !== this.tasksCache) {
      this.tasksCache = key;
      this.tasksEl.innerHTML = `<div class="quota-line">CUOTA <span>${state.quota.earned}/${state.quota.target}</span> · ${state.quota.failedDays} fallos</div>${tasks}`;
    }

    if (this.scanHide > 0) {
      this.scanHide -= 1;
      if (this.scanHide <= 0) this.scanEl.classList.remove('show');
    }
  }

  setPrompt(text: string | null): void {
    if (!text) {
      this.promptEl.classList.remove('show');
      this.crosshairEl.classList.remove('focus');
      return;
    }
    this.promptEl.innerHTML = text;
    this.promptEl.classList.add('show');
    this.crosshairEl.classList.add('focus');
  }

  setScan(progress: number | null): void {
    if (progress === null) {
      this.scanEl.classList.remove('show');
      return;
    }
    this.scanEl.classList.add('show');
    this.scanHide = 0;
    this.scanBar.style.width = `${Math.round(progress * 100)}%`;
  }

  toast(text: string, kind: ToastKind = 'info'): void {
    const el = document.createElement('div');
    el.className = `toast ${kind}`;
    el.textContent = text;
    this.toastsEl.appendChild(el);
    while (this.toastsEl.children.length > 5) this.toastsEl.removeChild(this.toastsEl.firstChild!);
    window.setTimeout(() => {
      el.classList.add('out');
      window.setTimeout(() => el.remove(), 420);
    }, 4600);
  }

  flash(intensity = 1): void {
    const el = document.createElement('div');
    el.style.cssText = `position:fixed;inset:0;background:#dff7ff;opacity:${0.55 * intensity};z-index:25;pointer-events:none;transition:opacity .5s`;
    document.body.appendChild(el);
    requestAnimationFrame(() => {
      el.style.opacity = '0';
    });
    window.setTimeout(() => el.remove(), 700);
  }

  // ---------- pantallas ----------

  get screenOpen(): boolean {
    return this.screenLayer.classList.contains('open');
  }

  showScreen(html: string): HTMLElement {
    this.screenLayer.innerHTML = `<div class="screen fade-in">${html}</div>`;
    this.screenLayer.classList.add('open');
    return this.screenLayer.querySelector('.screen') as HTMLElement;
  }

  closeScreen(): void {
    this.screenLayer.classList.remove('open');
    this.screenLayer.innerHTML = '';
  }

  showSummary(summary: ShiftSummary, briefing: string, onContinue: () => void): void {
    const quotaClass = summary.quotaMet ? 'good' : 'bad';
    const act = summary.actBreak
      ? `<div class="notice" style="margin-top:18px">FIN DEL ACTO I — La estación sigue en pie. Los días 6 a 12 abren el resto del archivo y el desenlace.</div>`
      : '';
    const screen = this.showScreen(`
      <div class="eyebrow">PARTE DE TURNO · DÍA ${summary.day}</div>
      <h1>${summary.quotaMet ? 'CUOTA CUBIERTA' : 'CUOTA INCOMPLETA'}</h1>
      <h2>${summary.quotaMet ? 'Control archiva el parte sin comentarios.' : 'Control ha aplicado una deducción.'}</h2>
      <div class="quote">${briefing}</div>
      <div class="stat-grid">
        <div class="stat"><b>${summary.earned}</b><span>CRÉDITOS / ${summary.target}</span></div>
        <div class="stat"><b>${summary.decoded}</b><span>SEÑALES DECODIFICADAS</span></div>
        <div class="stat"><b>${summary.contacts}</b><span>CONTACTOS REGISTRADOS</span></div>
      </div>
      <p class="quote">Cierre del turno con ${summary.weather.toLowerCase()}${summary.faults > 0 ? ` · ${summary.faults} máquina(s) fuera de servicio` : ' · cadena operativa'}.</p>
      <p class="${quotaClass}">${summary.quotaMet ? 'Sin incidencias en el registro. El turno siguiente empieza a las 19:00.' : `Tres turnos fallidos consecutivos no están contemplados en el contrato. Aviso interno.`}</p>
      ${act}
      <div class="actions">
        <button class="primary" data-continue>Empezar turno ${summary.day + 1}</button>
      </div>
    `);
    screen.querySelector('[data-continue]')?.addEventListener('click', () => {
      this.closeScreen();
      onContinue();
    });
  }

  showPause(
    state: GameState,
    handlers: { resume: () => void; quality: () => void; mute: () => void; abandon: () => void },
  ): void {
    const screen = this.showScreen(`
      <div class="eyebrow">TURNO ${state.day} · ${clockLabel(state.clock)}</div>
      <h1>PAUSA</h1>
      <h2>El reloj se detiene, pero la estación sigue ahí.</h2>
      <div class="stat-grid">
        <div class="stat"><b>${state.fragments}</b><span>FRAGMENTOS DE COHERENCIA</span></div>
        <div class="stat"><b>${state.stats.contacts}</b><span>CONTACTOS</span></div>
        <div class="stat"><b>${state.stats.decoded}</b><span>DECODIFICACIONES</span></div>
      </div>
      <p class="quote">${CONTROLS}<br /><br />La partida se guarda sola cada 40 segundos y al cambiar de turno.</p>
      <div class="actions">
        <button class="ghost" data-quality>CALIDAD: ${state.quality.toUpperCase()}</button>
        <button class="ghost" data-mute>SONIDO</button>
        <button class="ghost danger" data-abandon>ABANDONAR ESTACIÓN</button>
        <button class="primary" data-resume>VOLVER AL TURNO</button>
      </div>
    `);
    screen.querySelector('[data-resume]')?.addEventListener('click', () => {
      this.closeScreen();
      handlers.resume();
    });
    screen.querySelector('[data-quality]')?.addEventListener('click', () => {
      handlers.quality();
      this.closeScreen();
    });
    screen.querySelector('[data-mute]')?.addEventListener('click', handlers.mute);
    screen.querySelector('[data-abandon]')?.addEventListener('click', handlers.abandon);
  }

  showEnding(ending: EndingId, state: GameState, onRestart: () => void): void {
    const texts: Record<EndingId, { title: string; lines: string[] }> = {
      cortar: {
        title: 'CORTE EN SECO',
        lines: [
          'Bajas el interruptor del receptor a las 04:12. La aguja cae a cero y la estación se queda sin voz.',
          'Durante once minutos no pasa nada. Después, el plato empieza a girar hacia el sur. No hay corriente en los motores.',
          'A las 05:00 llega Control. Preguntan por qué el registro tiene cuarenta horas de más. No tienes respuesta. Te dejan marchar.',
          'La nieve tapa tus huellas antes de que llegues al coche. Algo, debajo de la estación, sigue escuchando.',
        ],
      },
      responder: {
        title: 'LA TERCERA LLAMADA',
        lines: [
          'Transmites tu nombre, la fecha y la frase que llevabas toda la noche escribiendo: "Estoy aquí".',
          'La respuesta llega en el mismo instante, sin retardo: tu propia voz, grabada de antemano, repitiendo la frase con tu cadencia.',
          'La puerta se abre sola. En el umbral hay una figura con tu chaqueta y tu altura, y no tiene cara.',
          'Cuando Control llama a las 05:00, alguien contesta. Sabe operar la estación. Conoce tu nombre. No eres tú.',
        ],
      },
      disolver: {
        title: 'LO QUE QUEDA CUANDO DEJAS DE ESCUCHAR',
        lines: [
          'Apagas el plato, la consola y la luz. Por primera vez en cuatro meses, la estación está en silencio.',
          'El silencio no es vacío: tiene textura. Se mueve por las paredes como una marea lenta.',
          'A las 05:00 no llega Control. Nadie llama nunca más. En el registro solo hay una línea, escrita con tu letra: "no había nada al otro lado".',
          'No es cierto. Pero es lo que decidiste creer, y la estación lo archivó por ti.',
        ],
      },
    };
    const t = texts[ending];
    const decisions = state.decisions.map((d) => DECISION_EPILOGUE[d]).filter((l): l is string => !!l);
    const screen = this.showScreen(`
      <div class="eyebrow">FIN · TURNO ${state.day}</div>
      <h1>${t.title}</h1>
      <h2>${state.fragments} fragmentos de coherencia · ${state.stats.contacts} contactos</h2>
      <div class="stack tight">
        ${t.lines.map((l) => `<p>${l}</p>`).join('')}
      </div>
      ${
        decisions.length > 0
          ? `<div class="notice">LO QUE DECIDISTE<br />${decisions.map((l) => `· ${l}`).join('<br />')}</div>`
          : ''
      }
      <div class="stat-grid">
        <div class="stat"><b>${state.stats.decoded}</b><span>SEÑALES DECODIFICADAS</span></div>
        <div class="stat"><b>${state.stats.sold}</b><span>CAPTURAS VENDIDAS</span></div>
        <div class="stat"><b>${Math.round(state.totalSeconds / 60)}</b><span>MINUTOS EN KESTREL</span></div>
      </div>
      <div class="actions">
        <button class="primary" data-restart>VOLVER A EMPEZAR</button>
      </div>
    `);
    screen.querySelector('[data-restart]')?.addEventListener('click', onRestart);
  }

  /** Decisión del acto II: dos opciones que quedan guardadas en la partida. */
  showDecision(prompt: DecisionPrompt, onChoose: (optionId: string) => void): void {
    const screen = this.showScreen(`
      <div class="eyebrow">DECISIÓN DEL TURNO</div>
      <h1>${prompt.title}</h1>
      <div class="quote">${prompt.text}</div>
      <div class="stack tight">
        ${prompt.options
          .map(
            (o) => `<div class="card">
              <div class="row between"><h4>${o.label.toUpperCase()}</h4></div>
              <p>${o.detail}</p>
              <div class="row end"><button class="small primary" data-option="${o.id}">ELEGIR</button></div>
            </div>`,
          )
          .join('')}
      </div>
      <p class="quote">La decisión queda en el registro y condiciona el epílogo.</p>
    `);
    screen.querySelectorAll<HTMLElement>('[data-option]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset['option']!;
        this.closeScreen();
        onChoose(id);
      });
    });
  }

  showConfirm(title: string, text: string, onYes: () => void): void {
    const screen = this.showScreen(`
      <div class="eyebrow">CONFIRMACIÓN</div>
      <h1>${title}</h1>
      <h2>${text}</h2>
      <div class="actions">
        <button class="ghost" data-no>CANCELAR</button>
        <button class="danger" data-yes>CONFIRMAR</button>
      </div>
    `);
    screen.querySelector('[data-no]')?.addEventListener('click', () => this.closeScreen());
    screen.querySelector('[data-yes]')?.addEventListener('click', () => {
      this.closeScreen();
      onYes();
    });
  }
}
