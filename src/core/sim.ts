// Simulación del turno: reloj, clima, averías, eventos, cuotas y fin de día.
// No conoce Three.js; el mundo se actualiza en main.ts a partir de este estado.

import { EventHost, nextEventGap, pickEvent, runEvent } from './events';
import { activeCaptures, level } from './economy';
import { breakMachine, healthyMachines, machineDef, maybeFault, type MachineId } from './faults';
import { Rng } from './rng';
import {
  addPoints,
  addStress,
  counterFor,
  createTasks,
  GameState,
  log,
  quotaForDay,
} from './state';
import { clockLabel, GAME_MIN_PER_SECOND, isShiftOver, SHIFT_LENGTH_MIN } from './time';
import { advanceWeather, rollWeather, WEATHER_INFO, weatherLabel, weatherStressRate } from './weather';

export interface SimHooks {
  onNewShift(day: number): void;
  onShiftSummary(summary: ShiftSummary): void;
  onEnding(ending: EndingId): void;
  /** El turno pide una decisión del acto II: la UI la muestra y responde. */
  onDecision(prompt: DecisionPrompt): void;
}

export interface ShiftSummary {
  day: number;
  earned: number;
  target: number;
  quotaMet: boolean;
  decoded: number;
  contacts: number;
  failures: number;
  actBreak: boolean;
  /** Etiqueta del clima con el que se ha cerrado la noche. */
  weather: string;
  /** Número de averías que quedaron sin resolver. */
  faults: number;
}

export type EndingId = 'cortar' | 'responder' | 'disolver';

export interface DecisionOption {
  id: string;
  label: string;
  detail: string;
}

export interface DecisionPrompt {
  id: string;
  title: string;
  text: string;
  options: DecisionOption[];
}

export const ACT_DAYS = 5;
/** Día en el que se abre el repetidor de los 900 m. */
export const REPEATER_DAY = 8;

export class Sim {
  state: GameState;
  private host: EventHost;
  private hooks: SimHooks;
  private rng: Rng;
  private eventTimer = 0;
  private eventsThisShift = 0;
  private saveTimer = 0;
  private shiftStartDecoded = 0;
  private shiftStartContacts = 0;
  private outside = false;
  private inLight = false;
  /** Pausa de simulación (menús, overlays). El reloj no avanza. */
  paused = false;
  /** Decisión pendiente del acto II, si la hay. */
  pendingDecision: DecisionPrompt | null = null;
  private firedScripted = new Set<string>();

  constructor(state: GameState, host: EventHost, hooks: SimHooks) {
    this.state = state;
    this.host = host;
    this.hooks = hooks;
    this.rng = new Rng(state.rngState);
    this.scheduleFirstEvent();
    this.shiftStartDecoded = state.stats.decoded;
    this.shiftStartContacts = state.stats.contacts;
  }

  get day(): number {
    return this.state.day;
  }

  private scheduleFirstEvent(): void {
    this.eventTimer = this.rng.range(55, 95);
  }

  setContext(outside: boolean, inLight: boolean): void {
    this.outside = outside;
    this.inLight = inLight;
  }

  tick(dt: number): void {
    const s = this.state;
    if (s.ending || this.paused) return;

    s.totalSeconds += dt;
    s.clock += dt * GAME_MIN_PER_SECOND;

    // Tensión de fondo: la noche pesa, el frío pesa más, la luz sostiene.
    const suit = level(s, 'traje');
    const exposure = this.outside ? 0.055 : 0.013;
    const weatherStress = this.outside ? weatherStressRate(s) : 0;
    const lightRelief = this.inLight ? 0.014 + level(s, 'luz') * 0.004 : 0;
    addStress(s, (exposure + weatherStress - lightRelief) * (1 - suit * 0.12) * dt);

    // Clima del valle: cambia solo, y la tormenta tira la corriente.
    const weatherTick = advanceWeather(s, dt, this.rng);
    if (weatherTick.change === 'cambio') {
      const info = WEATHER_INFO[s.weather.kind];
      this.host.log(`El tiempo ha cambiado: ${info.label.toLowerCase()}. ${info.desc}`, s.weather.kind === 'clara' ? 'info' : 'warn');
      this.host.toast(`CLIMA · ${weatherLabel(s)}`, s.weather.kind === 'clara' ? 'info' : 'warn');
    }
    if (weatherTick.outageSeconds > 0) {
      this.host.log('Una descarga ha caído en la línea. El grupo electrógeno se ha parado.', 'bad');
      this.host.toast('TORMENTA · corte de corriente', 'bad');
      this.host.sound('thunder');
      this.host.powerOut(weatherTick.outageSeconds);
    }

    // Averías: la cadena se desajusta sola con el uso y el estrés.
    const faulted = maybeFault(s, this.rng, dt);
    if (faulted) {
      this.host.sound('fault');
      this.host.toast(`AVERÍA · ${machineDef(faulted).short} fuera de servicio`, 'bad');
      this.host.save();
    }

    // Corriente
    if (!s.power) {
      s.powerOutTimer = Math.max(0, s.powerOutTimer - dt);
      if (s.powerOutTimer <= 0) {
        s.power = true;
        log(s, 'El grupo electrógeno ha vuelto a arrancar. Corriente restablecida.', 'good', clockLabel(s.clock));
        this.host.toast('Corriente restablecida', 'good');
        s.flags['apagon_pendiente'] = false;
      }
    }

    // Eventos
    this.eventTimer -= dt * GAME_MIN_PER_SECOND;
    const maxEvents = Math.min(5, 3 + Math.floor(s.day / 3));
    if (this.eventTimer <= 0 && this.eventsThisShift < maxEvents) {
      this.fireRandomEvent();
      this.eventTimer = nextEventGap(s.clock, this.rng);
    }

    // Hitos guionizados (acto I y acto II). No son una línea recta: marcan actos.
    this.checkMilestones();

    // Autoguardado
    this.saveTimer += dt;
    if (this.saveTimer > 40) {
      this.saveTimer = 0;
      this.host.save();
    }

    if (isShiftOver(s.clock)) this.endShift(false);
    s.rngState = this.rng.state;
  }

  fireRandomEvent(): void {
    const event = pickEvent(this.state, this.rng);
    if (!event) return;
    this.eventsThisShift += 1;
    this.host.log(`[evento] ${event.title}`, 'info');
    runEvent(event, this.host, this.state, this.rng);
  }

  /** Hito del acto I: la tercera noche, el plato se apaga solo a las 03:00. */
  private checkMilestones(): void {
    const s = this.state;
    const key = `act1_${s.day}`;
    if (s.day === 3 && s.clock > 480 && !this.firedScripted.has(key)) {
      this.firedScripted.add(key);
      s.flags['acto1_hito'] = true;
      this.host.sound('silence');
      this.host.stress(10);
      this.host.log('03:00. La antena se detiene y el receptor marca señal plena sin fuente.', 'bad');
      this.host.toast('Señal plena sin fuente', 'bad');
      this.host.grantCapture('VACIO', 'evento');
    }
    if (s.day === 5 && s.clock > 520 && !this.firedScripted.has('act1_final')) {
      this.firedScripted.add('act1_final');
      this.host.log('La puerta de la antena está abierta. La nieve de dentro está pisada.', 'bad');
      this.host.spawnEntity('figura', 'window');
      this.host.stress(18);
      this.host.flash(0.6);
      this.host.sound('breath');
      s.flags['acto1_final'] = true;
    }

    this.checkActTwo();
  }

  /**
   * Acto II (días 6–12): arco del operador anterior. Ocho hitos, tres de ellos
   * con una decisión persistente que después aparece en el epílogo.
   */
  private checkActTwo(): void {
    const s = this.state;
    if (s.day < 6) return;

    if (s.day === 6 && s.clock > 460 && !this.firedScripted.has('act2_parte')) {
      this.firedScripted.add('act2_parte');
      this.host.weather('ventisca', 0.9, 240);
      this.host.log('El parte meteorológico repite la misma frase desde ayer: "viento del sur, visibilidad nula, no salir".', 'warn');
      this.host.toast('El parte repite la frase de ayer', 'warn');
      this.host.stress(6);
    }

    if (s.day === 7 && s.clock > 145 && !this.firedScripted.has('act2_archivo')) {
      this.firedScripted.add('act2_archivo');
      s.flags['acto2_archivo'] = true;
      this.host.log('En el cajón de la consola hay una carpeta con el nombre de quien operaba esta estación antes que tú.', 'info');
      this.requestDecision({
        id: 'archivo_operador',
        title: 'EL ARCHIVO DEL OPERADOR ANTERIOR',
        text: 'La carpeta no lleva número de registro. Dentro hay cuarenta horas de escucha firmadas por alguien que ya no aparece en ninguna plantilla.',
        options: [
          { id: 'leer', label: 'Leer la carpeta', detail: 'Coherencia para ti: +1 fragmento, más estrés. Control no sabrá que existe.' },
          { id: 'entregar', label: 'Reportarla a Control', detail: 'Control te compensa con 150 créditos y no pregunta por el resto del turno.' },
        ],
      });
    }

    if (s.day === REPEATER_DAY && s.clock > 60 && !this.firedScripted.has('act2_repetidor')) {
      this.firedScripted.add('act2_repetidor');
      s.flags['repetidor_abierto'] = true;
      this.host.log('La baliza del repetidor, a 900 metros, lleva veinte minutos emitiendo portadora. La motonieve tiene gasolina.', 'warn');
      this.host.toast('El repetidor ha despertado · motonieve disponible', 'bad');
      this.host.sound('beep');
      this.host.fragment(1);
      this.host.stress(8);
    }

    if (s.day === 9 && s.clock > 420 && !this.firedScripted.has('act2_baliza')) {
      this.firedScripted.add('act2_baliza');
      s.flags['acto2_baliza'] = true;
      this.host.sound('voice');
      this.host.stress(12);
      this.host.log('Una voz igual a la tuya pide por radio el código de la puerta del repetidor. Lo da como si lo hubieras dado tú.', 'bad');
      this.requestDecision({
        id: 'baliza',
        title: 'EL CÓDIGO DE LA PUERTA',
        text: 'La voz conoce el código, la fecha y el nombre del operador anterior. Solo falta que alguien confirme. Si cuelgas, la cerradura vuelve a su sitio sola.',
        options: [
          { id: 'contestar', label: 'Dar el código', detail: 'Algo queda invitado: +2 fragmentos, mucho estrés y un contacto dentro.' },
          { id: 'desconectar', label: 'Cortar la radio', detail: 'Te quedas sin la pista, pero el turno pesa menos y Control no oye nada raro.' },
        ],
      });
    }

    if (s.day === 10 && s.clock > 30 && !this.firedScripted.has('act2_cinta')) {
      this.firedScripted.add('act2_cinta');
      s.flags['acto2_cinta'] = true;
      this.host.sound('voice');
      this.host.grantCapture('VOZ', 'evento');
      this.host.log('El archivador ha recibido una cinta que no has grabado. La voz es del operador anterior y lleva tu nombre puesto.', 'bad');
      this.host.toast('Cinta nueva en el archivador', 'warn');
      this.host.stress(10);
    }

    if (s.day === 11 && s.clock > 480 && !this.firedScripted.has('act2_registro')) {
      this.firedScripted.add('act2_registro');
      s.flags['acto2_registro'] = true;
      this.host.log('El registro del turno está escrito con tu letra desde la primera línea. Incluye cosas que aún no has hecho.', 'bad');
      this.host.stress(9);
      this.requestDecision({
        id: 'registro',
        title: 'EL REGISTRO ESTÁ FIRMADO',
        text: 'La última entrada lleva tu firma y la hora de mañana. Puedes firmar lo que queda por pasar o arrancar la hoja.',
        options: [
          { id: 'firmar', label: 'Firmar el registro', detail: 'Aceptas el turno que viene escrito: +1 fragmento y menos estrés.' },
          { id: 'borrar', label: 'Arrancar la hoja', detail: 'Control notará el hueco: te quedas sin fragmento y con un aviso en el expediente.' },
        ],
      });
    }

    if (s.day === 12 && s.clock > 480 && !this.firedScripted.has('act2_final')) {
      this.firedScripted.add('act2_final');
      s.flags['final_preparado'] = true;
      this.host.weather('tormenta', 1, 300);
      this.host.sound('thunder');
      this.host.log('La banda entera está ocupada por una portadora que no admite demodulación. Tienes doce fragmentos y una decisión.', 'bad');
      this.host.toast('LA SEÑAL FINAL ESTÁ EN LA CONSOLA', 'bad');
      this.host.fragment(1);
      this.host.stress(14);
      if (s.fragments < 12) {
        this.host.grantCapture('VACIO', 'evento');
      }
    }
  }

  private requestDecision(prompt: DecisionPrompt): void {
    if (this.pendingDecision) return;
    this.pendingDecision = prompt;
    this.hooks.onDecision(prompt);
  }

  /** Aplica la decisión del acto II. Se guarda para el epílogo. */
  resolveDecision(optionId: string): { ok: boolean; message: string } {
    const prompt = this.pendingDecision;
    if (!prompt) return { ok: false, message: 'No hay ninguna decisión pendiente.' };
    const option = prompt.options.find((o) => o.id === optionId);
    if (!option) return { ok: false, message: 'Opción desconocida.' };
    const s = this.state;
    this.pendingDecision = null;

    switch (prompt.id) {
      case 'archivo_operador':
        if (option.id === 'leer') {
          s.fragments += 1;
          addStress(s, 12);
          this.host.log('Lees la carpeta entera. El operador anterior describía esta misma noche, con cuarenta horas de detalle.', 'bad');
          this.host.toast('Carpeta leída · +1 fragmento', 'bad');
        } else {
          addPoints(s, 150);
          this.host.log('Control recoge la carpeta sin preguntar. Te ingresan la prima antes de colgar.', 'good');
          this.host.toast('Carpeta entregada · +150 créditos', 'good');
        }
        break;
      case 'baliza':
        if (option.id === 'contestar') {
          s.fragments += 2;
          addStress(s, 20);
          this.host.spawnEntity('doble', 'inside');
          this.host.sound('breath');
          this.host.log('Recitas el código. La puerta del repetidor se abre a 900 metros. Algo entra y no cierra.', 'bad');
          this.host.toast('La puerta del repetidor está abierta', 'bad');
        } else {
          addStress(s, -6);
          this.host.log('Cortas la radio a media palabra. La cerradura vuelve a su sitio sola, sin que nadie la toque.', 'warn');
          this.host.toast('Radio cortada', 'info');
        }
        break;
      case 'registro':
        if (option.id === 'firmar') {
          s.fragments += 1;
          addStress(s, -8);
          this.host.log('Firmas el registro completo. La última entrada se escribe sola al terminar la tuya.', 'bad');
          this.host.toast('Registro firmado · +1 fragmento', 'bad');
        } else {
          s.flags['registro_arrancado'] = true;
          addStress(s, 6);
          this.host.log('Arrancas la hoja. El hueco se queda ahí, y Control lleva la cuenta de las hojas.', 'warn');
          this.host.toast('Hoja arrancada', 'warn');
        }
        break;
      default:
        break;
    }

    s.decisions.push(`${prompt.id}:${option.id}`);
    this.host.save();
    return { ok: true, message: option.label };
  }

  /** Fin de turno: cuota, tareas, resumen y día siguiente. */
  endShift(slept: boolean): ShiftSummary {
    const s = this.state;
    const quotaMet = s.quota.earned >= s.quota.target;
    if (!quotaMet) {
      s.quota.failedDays += 1;
      addStress(s, 10);
      addPoints(s, -Math.min(s.points, 25));
      this.host.log('Control: cuota incompleta. Se aplica una deducción al presupuesto.', 'bad');
    } else {
      const bonus = Math.round(s.quota.target * 0.15);
      addPoints(s, bonus);
      this.host.log(`Control: cuota cubierta. Prima de turno +${bonus}.`, 'good');
    }

    // Tareas: las de "no ha pasado nada" se cierran ahora; el resto penaliza poco.
    for (const t of s.tasks) {
      if (t.done) continue;
      if (t.kind === 'no_blackout' || t.kind === 'no_averia') {
        if (counterFor(t.kind, s.stats) === t.base) {
          t.done = true;
          t.progress = t.target;
          addPoints(s, t.reward);
          continue;
        }
      }
      addStress(s, 3);
    }

    const summary: ShiftSummary = {
      day: s.day,
      earned: s.quota.earned,
      target: s.quota.target,
      quotaMet,
      decoded: s.stats.decoded - this.shiftStartDecoded,
      contacts: s.stats.contacts - this.shiftStartContacts,
      failures: s.quota.failedDays,
      actBreak: s.day % ACT_DAYS === 0,
      weather: weatherLabel(s),
      faults: Object.keys(s.faults).length,
    };

    if (s.day >= 12 && s.fragments >= 12 && !s.ending) {
      // El desenlace se decide en la consola; aquí solo se avisa.
      s.flags['final_disponible'] = true;
    }

    s.day += 1;
    s.clock = 0;
    s.shiftId += 1;
    s.quota = { target: quotaForDay(s.day), earned: 0, failedDays: s.quota.failedDays };
    s.tasks = createTasks(s.day, this.rng, s.stats);
    s.stress = Math.max(8, s.stress - (slept ? 26 : 14));
    if (!s.power) {
      s.power = true;
      s.powerOutTimer = 0;
    }
    s.flags['apagon_pendiente'] = false;
    // Las averías no se arreglan solas, pero amanece con la máquina en mejor
    // disposición: la severidad baja y las calibradas vuelven a servicio.
    for (const [id, fault] of Object.entries(s.faults)) {
      fault.severity = Math.max(0.15, fault.severity - 0.25);
      fault.attempt = 0;
      if (!fault.broken) delete s.faults[id];
    }
    // Clima de la noche siguiente.
    s.weather = rollWeather(s.day, this.rng, s.weather.kind);
    // Solo se descartan las vendidas: el archivador está limitado al grabar.
    s.captures = s.captures.filter((c) => !c.sold);

    this.eventsThisShift = 0;
    this.scheduleFirstEvent();
    this.host.save();
    this.hooks.onNewShift(s.day);
    this.hooks.onShiftSummary(summary);
    this.shiftStartDecoded = s.stats.decoded;
    this.shiftStartContacts = s.stats.contacts;
    this.state.rngState = this.rng.state;
    return summary;
  }

  sleep(): void {
    if (this.state.clock < 120) {
      this.host.toast('Todavía no puedes dormir: el turno acaba de empezar.', 'warn');
      return;
    }
    this.host.log('Te tumbas con la radio encendida. Duermes mal, pero duermes.', 'info');
    this.endShift(true);
  }

  /** Transmisión desde la consola. Es la acción más peligrosa del juego. */
  transmit(): { ok: boolean; message: string } {
    const s = this.state;
    if (!s.power) return { ok: false, message: 'Sin corriente no hay transmisor.' };
    const cost = 40;
    if (s.points < cost) return { ok: false, message: `El amplificador cuesta ${cost} créditos de mantenimiento.` };
    addPoints(s, -cost);
    s.stats.answered += 1;
    s.flags['ha_transmitido'] = true;
    addStress(s, 12);
    log(s, 'Has transmitido en la banda de la última señal. El cielo no ha cambiado.', 'warn', clockLabel(s.clock));
    this.host.sound('transmit');
    this.host.shake(0.25);
    if (this.rng.chance(0.65)) {
      this.host.spawnEntity('figura', 'fence');
      this.host.log('A 40 metros, algo ha levantado la cabeza.', 'bad');
      this.host.stress(6);
    }
    if (this.rng.chance(0.3)) this.host.fragment(1);
    s.rngState = this.rng.state;
    return { ok: true, message: 'Transmisión enviada. Algo la ha recibido.' };
  }

  /** Avalancha de consecuencias de haber respondido con la puerta abierta. */
  escalate(): void {
    const s = this.state;
    const victim = healthyMachines(s);
    if (victim.length > 0) {
      const id: MachineId = this.rng.pick(victim);
      breakMachine(s, id, this.rng.range(0.5, 0.9), true);
      this.host.sound('fault');
      this.host.toast(`SABOTAJE · ${machineDef(id).short} fuera de servicio`, 'bad');
    }
    s.rngState = this.rng.state;
  }

  /** Registro de una captura decodificada como "contacto" medido. */
  registerContact(): void {
    this.state.stats.contacts += 1;
    this.state.flags['ultimo_contacto'] = this.state.clock;
  }

  /** Escaneo de campo: convierte observación en datos. */
  registerScan(): void {
    this.state.stats.scans += 1;
  }

  resetPower(): void {
    const s = this.state;
    if (s.power) return;
    s.powerOutTimer = Math.min(s.powerOutTimer, 6);
    log(s, 'Cuadro del generador reiniciado. Arranque en unos segundos.', 'info', clockLabel(s.clock));
  }

  /** El jugador decide el desenlace desde la consola. */
  finish(ending: EndingId): void {
    const s = this.state;
    if (s.ending) return;
    s.ending = ending;
    s.stats.contacts += 1;
    this.host.save();
    this.hooks.onEnding(ending);
  }

  canFinish(): boolean {
    const s = this.state;
    return !s.ending && s.day >= 12 && s.fragments >= 12;
  }

  freeSlots(): number {
    return Math.max(0, 8 - activeCaptures(this.state));
  }

  get shiftMinutesLeft(): number {
    return Math.max(0, SHIFT_LENGTH_MIN - this.state.clock);
  }
}

export { GAME_MIN_PER_SECOND };
