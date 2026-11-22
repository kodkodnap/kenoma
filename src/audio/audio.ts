// Audio 100 % procedural: no se descarga ni un solo archivo. Viento, zumbido
// eléctrico, pasos y efectos sintetizados en WebAudio.

type Ctx = AudioContext;

export class AudioEngine {
  private ctx: Ctx | null = null;
  private master: GainNode | null = null;
  private ambience: GainNode | null = null;
  private windGain: GainNode | null = null;
  private humGain: GainNode | null = null;
  private staticGain: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  private started = false;
  private muted = false;
  private stress = 0;

  get isStarted(): boolean {
    return this.started;
  }

  get isMuted(): boolean {
    return this.muted;
  }

  /** Debe llamarse desde un gesto del usuario. */
  start(): void {
    if (this.started) {
      void this.ctx?.resume();
      return;
    }
    const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctor) return;
    const ctx = new Ctor();
    this.ctx = ctx;
    this.started = true;

    const master = ctx.createGain();
    master.gain.value = this.muted ? 0 : 0.75;
    const comp = ctx.createDynamicsCompressor();
    comp.threshold.value = -18;
    comp.knee.value = 12;
    comp.ratio.value = 4;
    master.connect(comp).connect(ctx.destination);
    this.master = master;

    // Buffer de ruido reutilizable
    const len = ctx.sampleRate * 4;
    const buffer = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    this.noise = buffer;

    this.ambience = ctx.createGain();
    this.ambience.gain.value = 0.9;
    this.ambience.connect(master);

    this.windGain = this.loopNoise(320, 'lowpass', 0.14);
    this.staticGain = this.loopNoise(2400, 'bandpass', 0.035);
    this.humGain = this.hum();
  }

  private loopNoise(freq: number, type: BiquadFilterType, gainValue: number): GainNode {
    const ctx = this.ctx!;
    const src = ctx.createBufferSource();
    src.buffer = this.noise!;
    src.loop = true;
    const filter = ctx.createBiquadFilter();
    filter.type = type;
    filter.frequency.value = freq;
    filter.Q.value = type === 'bandpass' ? 0.7 : 0.9;
    const gain = ctx.createGain();
    gain.gain.value = gainValue;
    src.connect(filter).connect(gain).connect(this.ambience!);
    src.start();

    // Modulación lenta para que respire
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 0.06 + Math.random() * 0.05;
    const lfoGain = ctx.createGain();
    lfoGain.gain.value = gainValue * 0.55;
    lfo.connect(lfoGain).connect(gain.gain);
    lfo.start();
    return gain;
  }

  private hum(): GainNode {
    const ctx = this.ctx!;
    const gain = ctx.createGain();
    gain.gain.value = 0.018;
    gain.connect(this.ambience!);
    for (const [freq, amp] of [
      [50, 0.7],
      [100, 0.35],
      [150, 0.12],
    ] as const) {
      const osc = ctx.createOscillator();
      osc.type = 'sine';
      osc.frequency.value = freq;
      const g = ctx.createGain();
      g.gain.value = amp;
      osc.connect(g).connect(gain);
      osc.start();
    }
    return gain;
  }

  setMuted(muted: boolean): void {
    this.muted = muted;
    if (this.master && this.ctx) {
      this.master.gain.setTargetAtTime(muted ? 0 : 0.75, this.ctx.currentTime, 0.1);
    }
  }

  toggleMute(): boolean {
    this.setMuted(!this.muted);
    return this.muted;
  }

  setPower(on: boolean): void {
    if (!this.ctx || !this.humGain) return;
    this.humGain.gain.setTargetAtTime(on ? 0.018 : 0, this.ctx.currentTime, 0.4);
  }

  /** El estrés sube el ruido eléctrico y baja el viento: sensación de opresión. */
  setStress(stress: number): void {
    this.stress = stress;
    if (!this.ctx || !this.windGain || !this.staticGain) return;
    const t = this.ctx.currentTime;
    this.windGain.gain.setTargetAtTime(0.14 - stress * 0.0009, t, 0.8);
    this.staticGain.gain.setTargetAtTime(0.02 + stress * 0.0011, t, 0.8);
  }

  setOutside(outside: boolean): void {
    if (!this.ctx || !this.windGain) return;
    this.windGain.gain.setTargetAtTime((outside ? 0.2 : 0.055) - this.stress * 0.0006, this.ctx.currentTime, 1.2);
  }

  silence(seconds = 8): void {
    if (!this.ctx || !this.ambience) return;
    const t = this.ctx.currentTime;
    this.ambience.gain.cancelScheduledValues(t);
    this.ambience.gain.setValueAtTime(this.ambience.gain.value, t);
    this.ambience.gain.linearRampToValueAtTime(0.02, t + 0.6);
    this.ambience.gain.linearRampToValueAtTime(0.9, t + seconds);
  }

  private burst(volume: number, freq: number, type: BiquadFilterType, dur: number, at = 0): void {
    if (!this.ctx || !this.noise || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime + at;
    const src = ctx.createBufferSource();
    src.buffer = this.noise;
    const filter = ctx.createBiquadFilter();
    filter.type = type;
    filter.frequency.value = freq;
    filter.Q.value = 0.8;
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(volume, t + 0.012);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(filter).connect(gain).connect(this.master);
    src.start(t, Math.random() * 2);
    src.stop(t + dur + 0.05);
  }

  private tone(freq: number, dur: number, type: OscillatorType, volume: number, at = 0, slideTo?: number): void {
    if (!this.ctx || !this.master) return;
    const ctx = this.ctx;
    const t = ctx.currentTime + at;
    const osc = ctx.createOscillator();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (slideTo !== undefined) osc.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(volume, t + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(gain).connect(this.master);
    osc.start(t);
    osc.stop(t + dur + 0.05);
  }

  step(surface: 'snow' | 'floor'): void {
    if (surface === 'snow') {
      this.burst(0.16, 900, 'lowpass', 0.16);
      this.burst(0.06, 2400, 'highpass', 0.09, 0.01);
    } else {
      this.burst(0.09, 500, 'lowpass', 0.08);
      this.tone(90, 0.07, 'sine', 0.03);
    }
  }

  click(): void {
    this.tone(1400, 0.04, 'square', 0.025);
  }

  beep(freq = 880): void {
    this.tone(freq, 0.09, 'sine', 0.05);
  }

  error(): void {
    this.tone(180, 0.18, 'square', 0.05);
    this.tone(120, 0.22, 'square', 0.04, 0.06);
  }

  echoTick(): void {
    this.tone(2200, 0.025, 'sine', 0.02);
  }

  breaker(): void {
    this.tone(60, 0.35, 'sawtooth', 0.08, 0, 28);
    this.burst(0.2, 400, 'lowpass', 0.3);
  }

  knock(): void {
    for (let i = 0; i < 3; i++) {
      this.burst(0.28, 220, 'lowpass', 0.2, i * 0.34);
      this.tone(70, 0.16, 'sine', 0.06, i * 0.34);
    }
  }

  breath(): void {
    if (!this.ctx) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = this.noise!;
    const filter = ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(180, t);
    filter.frequency.linearRampToValueAtTime(520, t + 1.1);
    const gain = ctx.createGain();
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.linearRampToValueAtTime(0.18, t + 0.9);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 2.6);
    src.connect(filter).connect(gain).connect(this.master!);
    src.start(t);
    src.stop(t + 2.8);
  }

  voice(): void {
    // Voz amortiguada: ruido con formantes en movimiento.
    if (!this.ctx) return;
    const ctx = this.ctx;
    const t = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = this.noise!;
    for (const [freq, q, amp] of [
      [520, 6, 0.16],
      [1180, 8, 0.1],
      [2400, 9, 0.05],
    ] as const) {
      const filter = ctx.createBiquadFilter();
      filter.type = 'bandpass';
      filter.frequency.value = freq;
      filter.Q.value = q;
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, t);
      for (let i = 0; i < 5; i++) {
        const at = t + i * 0.28;
        gain.gain.linearRampToValueAtTime(amp, at + 0.05);
        gain.gain.linearRampToValueAtTime(0.0001, at + 0.22);
      }
      src.connect(filter).connect(gain).connect(this.master!);
    }
    src.start(t);
    src.stop(t + 1.8);
  }

  motor(on: boolean): void {
    if (on) {
      this.tone(90, 3.4, 'sawtooth', 0.03, 0, 130);
      this.burst(0.05, 300, 'lowpass', 3.2);
    }
  }

  transmit(): void {
    this.tone(200, 1.4, 'sine', 0.07, 0, 1400);
    this.burst(0.12, 1800, 'bandpass', 1.6, 0.2);
    this.tone(110, 0.9, 'triangle', 0.04, 1.2);
  }

  melody(): void {
    const notes = [392, 440, 523.25, 492, 392, 349.23, 392];
    notes.forEach((n, i) => this.tone(n, 0.5, 'sine', 0.035, i * 0.62));
    this.burst(0.03, 1200, 'bandpass', 4.5);
  }

  scanStart(): void {
    this.tone(600, 0.5, 'sine', 0.03, 0, 1200);
  }

  scanDone(): void {
    this.tone(880, 0.12, 'sine', 0.04);
    this.tone(1320, 0.16, 'sine', 0.035, 0.1);
    this.tone(1760, 0.2, 'sine', 0.03, 0.22);
  }

  dishLock(): void {
    this.tone(660, 0.08, 'square', 0.025);
    this.tone(990, 0.1, 'square', 0.02, 0.08);
  }

  sell(): void {
    this.tone(1200, 0.09, 'sine', 0.04);
    this.tone(1600, 0.12, 'sine', 0.035, 0.09);
  }

  /** Latido lejano que crece con el estrés. */
  heartbeat(): void {
    this.tone(52, 0.22, 'sine', 0.05);
    this.tone(46, 0.26, 'sine', 0.045, 0.24);
  }

  /** Trueno: desplome grave y cola de ruido filtrado. */
  thunder(): void {
    this.tone(120, 1.5, 'sawtooth', 0.06, 0, 34);
    this.burst(0.22, 420, 'lowpass', 2.2);
    this.burst(0.08, 160, 'lowpass', 3.2, 0.25);
  }

  /** Ráfaga de viento sostenida. */
  wind(): void {
    this.burst(0.2, 520, 'lowpass', 3.4);
    this.burst(0.06, 2200, 'bandpass', 2.6, 0.2);
  }

  /** Baliza en morse: tres cortos, tres largos, tres cortos. */
  morse(): void {
    const pattern = [0.1, 0.1, 0.1, 0.3, 0.3, 0.3, 0.1, 0.1, 0.1];
    let at = 0;
    for (const d of pattern) {
      this.tone(880, d, 'sine', 0.035, at);
      at += d + 0.1;
    }
  }

  /** Trueque: dos notas apagadas, casi un trueque de monedas viejas. */
  trade(): void {
    this.tone(520, 0.1, 'triangle', 0.045);
    this.tone(392, 0.16, 'triangle', 0.04, 0.1);
  }

  /** Avería: relé que se suelta. */
  fault(): void {
    this.burst(0.24, 320, 'lowpass', 0.18);
    this.tone(150, 0.2, 'square', 0.04, 0.05, 60);
  }

  play(id: string): void {
    switch (id) {
      case 'breaker':
        this.breaker();
        break;
      case 'knock':
        this.knock();
        break;
      case 'breath':
        this.breath();
        break;
      case 'voice':
        this.voice();
        break;
      case 'motor':
        this.motor(true);
        break;
      case 'transmit':
        this.transmit();
        break;
      case 'melody':
        this.melody();
        break;
      case 'silence':
        this.silence();
        break;
      case 'snowstep':
        this.step('snow');
        break;
      case 'beep':
        this.beep();
        break;
      case 'thunder':
        this.thunder();
        break;
      case 'wind':
        this.wind();
        break;
      case 'morse':
        this.morse();
        break;
      case 'trade':
        this.trade();
        break;
      case 'fault':
        this.fault();
        break;
      case 'heartbeat':
        this.heartbeat();
        break;
      default:
        this.beep();
    }
  }
}
