// Verificación end-to-end en un navegador real (Edge headless).
// Comprueba arranque, render, grabación, cadena de decodificación, venta,
// paneles y persistencia. Sale con código 1 si algo falla.

import { chromium } from 'playwright-core';

const EDGE = 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe';
const URL = process.env.SMOKE_URL ?? 'http://localhost:5180/';

const failures = [];
const check = (name, condition, detail = '') => {
  if (condition) console.log(`  ok   ${name}`);
  else {
    failures.push(`${name} ${detail}`);
    console.log(`  FAIL ${name} ${detail}`);
  }
};

const browser = await chromium.launch({
  executablePath: EDGE,
  headless: true,
  args: [
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--enable-unsafe-swiftshader',
    '--disable-gpu-sandbox',
    '--no-sandbox',
  ],
});

const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
const frameCount = () => page.evaluate(() => window.__estatica?.world.renderer.info.render.frame ?? 0);
/** Espera a que el bucle de render avance n frames reales (independiente del fps). */
const waitFrames = async (n, timeout = 45000) => {
  const start = await frameCount();
  const deadline = Date.now() + timeout;
  while (Date.now() < deadline) {
    const now = await frameCount();
    if (now >= start + n) return now - start;
    await page.waitForTimeout(120);
  }
  return -1;
};
/** Espera a que el estado cumpla una condición, avanzando frames reales. */
const waitState = async (fn, framesPerWait = 24, rounds = 60) => {
  for (let i = 0; i < rounds; i++) {
    if (await fn()) return true;
    await waitFrames(framesPerWait, 60000);
  }
  return await fn();
};

const errors = [];
page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`));
page.on('console', (msg) => {
  if (msg.type() === 'error') errors.push(`console: ${msg.text()}`);
});

console.log('abriendo', URL);
await page.goto(URL, { waitUntil: 'networkidle' });

// El menú de arranque se construye tras los pasos de "boot".
await page.waitForSelector('#boot .menu button', { timeout: 15000 });
check('menú de arranque visible', true);

const newGameBtn = page.locator('#boot .menu button').last();
await newGameBtn.click();
await page.waitForTimeout(1200);

const initial = await page.evaluate(() => window.__estatica?.debugSnapshot());
check('partida iniciada', initial?.started === true, JSON.stringify(initial));
check('mundo con fuentes', (initial?.sources ?? 0) > 0, `sources=${initial?.sources}`);
check('sin entidades al inicio', initial?.entities === 0, `entities=${initial?.entities}`);

const canvas = await page.evaluate(() => {
  const c = document.getElementById('view');
  const gl = c.getContext('webgl2') || c.getContext('webgl');
  return { width: c.width, height: c.height, gl: !!gl };
});
check('canvas con contexto WebGL', canvas.gl && canvas.width > 0, JSON.stringify(canvas));

// FPS en headless (swiftshader): solo se comprueba que el bucle corre.
const fps = await page.evaluate(
  () =>
    new Promise((resolve) => {
      let frames = 0;
      const start = performance.now();
      const tick = () => {
        frames++;
        if (performance.now() - start < 1500) requestAnimationFrame(tick);
        else resolve((frames / (performance.now() - start)) * 1000);
      };
      requestAnimationFrame(tick);
    }),
);
check('bucle de render activo', fps > 0.5, `${fps.toFixed(1)} fps headless (software, no representativo de GPU)`);

const budget = await page.evaluate(() => {
  const r = window.__estatica.world.renderer.info.render;
  return { calls: r.calls, triangles: r.triangles };
});
check('presupuesto: menos de 150k triángulos', budget.triangles < 150000, JSON.stringify(budget));
check('presupuesto: menos de 250 draw calls', budget.calls < 250, JSON.stringify(budget));

// Apuntar a una fuente real y grabar.
const aim = await page.evaluate(() => {
  const g = window.__estatica;
  const src = g.sources[0];
  g.setDish(src.az, src.el);
  return { az: src.az, el: src.el, band: src.band, mod: src.modulation, cipher: src.cipher, id: src.id };
});
await waitState(() => page.evaluate(() => window.__estatica.dish.locked));
const locked = await page.evaluate(() => window.__estatica.dish.locked);
check('enlace estable apuntando a la fuente', locked === true);

await page.evaluate(() => window.__estatica.setQuality('baja'));
await page.evaluate(() => window.__estatica.startRecording());
const recDeadline = Date.now() + 40000;
let afterRec = { count: 0, stage: undefined, id: undefined };
while (Date.now() < recDeadline) {
  afterRec = await page.evaluate(() => ({
    count: window.__estatica.state.captures.length,
    stage: window.__estatica.state.captures[0]?.stage,
    id: window.__estatica.state.captures[0]?.id,
  }));
  if (afterRec.count > 0) break;
  await page.waitForTimeout(400);
}
check('captura grabada', afterRec.count === 1, JSON.stringify(afterRec));
check('captura en bruto', afterRec.stage === 0, `stage=${afterRec.stage}`);

// Cadena de decodificación: fallo controlado y acierto.
const pipeline = await page.evaluate(
  ({ band, mod, cipher }) => {
    const g = window.__estatica;
    g.selectCapture(g.state.captures[0].id);
    const wrongBand = g.isolate(band + 45);
    const okBand = g.isolate(band);
    const wrongMod = g.demod(mod === 'AM' ? 'FM' : 'AM');
    const okMod = g.demod(mod);
    const wrongCipher = g.decode(cipher === 'BASE' ? 'ARMONICO' : 'BASE');
    const okCipher = g.decode(cipher);
    const cap = g.state.captures[0];
    return {
      wrongBand: wrongBand.ok,
      okBand: okBand.ok,
      wrongMod: wrongMod.ok,
      okMod: okMod.ok,
      wrongCipher: wrongCipher.ok,
      okCipher: okCipher.ok,
      stage: cap.stage,
      klass: cap.klass,
      quality: Math.round(cap.quality),
      value: cap.text,
    };
  },
  aim,
);
check('banda incorrecta rechazada', pipeline.wrongBand === false);
check('banda correcta aceptada', pipeline.okBand === true);
check('demodulación incorrecta rechazada', pipeline.wrongMod === false);
check('demodulación correcta aceptada', pipeline.okMod === true);
check('cifrado incorrecto rechazado', pipeline.wrongCipher === false);
check('cifrado correcto aceptado', pipeline.okCipher === true);
check('captura decodificada', pipeline.stage === 3, `stage=${pipeline.stage}`);
check('texto reconstruido', typeof pipeline.value === 'string' && pipeline.value.length > 3);

// Venta y cuota
const sale = await page.evaluate(() => {
  const g = window.__estatica;
  const before = g.state.points;
  g.sell(g.state.captures[0].id);
  return { before, after: g.state.points, quota: g.state.quota.earned, sold: g.state.captures[0].sold };
});
check('venta acredita puntos', sale.after > sale.before, JSON.stringify(sale));
check('venta suma a la cuota', sale.quota > 0);
check('captura marcada como vendida', sale.sold === true);

// Panel de consola y de plato
await page.evaluate(() => window.__estatica.debugOpenPanel('pc'));
await page.waitForTimeout(300);
const pcVisible = await page.evaluate(() => {
  const panel = document.querySelector('#overlay .panel');
  return panel ? panel.textContent.length > 50 : false;
});
check('panel de consola renderiza', pcVisible);
await page.keyboard.press('Escape');
await page.waitForTimeout(200);
const closed = await page.evaluate(() => document.querySelectorAll('#overlay .panel').length === 0);
check('panel se cierra con Escape', closed);

await page.evaluate(() => window.__estatica.debugOpenPanel('dish'));
await page.waitForTimeout(400);
const dishCanvas = await page.evaluate(() => {
  const c = document.querySelector('#overlay canvas');
  return c ? { w: c.width, h: c.height } : null;
});
check('terminal del plato dibuja la carta del cielo', !!dishCanvas && dishCanvas.w > 0, JSON.stringify(dishCanvas));
await page.keyboard.press('Escape');

// Paneles de las tres máquinas con una captura nueva.
const mach = await page.evaluate(() => {
  const g = window.__estatica;
  g.debugGrantCapture('BALIZA');
  const c = g.state.captures.filter((x) => !x.sold).at(-1);
  g.selectCapture(c.id);
  return { id: c.id, band: c.band, mod: c.modulation, cipher: c.cipher };
});
await page.evaluate(() => window.__estatica.debugOpenPanel('spectrum'));
await page.waitForTimeout(350);
check(
  'analizador dibuja espectro',
  await page.evaluate(() => !!document.querySelector('#overlay .panel canvas')),
);
await page.keyboard.press('Escape');
const iso = await page.evaluate((band) => window.__estatica.isolate(band), mach.band);
check('aislar portadora desde la API', iso.ok, iso.message);

await page.evaluate(() => window.__estatica.debugOpenPanel('demod'));
await page.waitForTimeout(350);
check(
  'demodulador dibuja la onda',
  await page.evaluate(() => !!document.querySelector('#overlay .panel canvas')),
);
await page.keyboard.press('Escape');
const dem = await page.evaluate((mod) => window.__estatica.demod(mod), mach.mod);
check('demodular desde la API', dem.ok, dem.message);

await page.evaluate(() => window.__estatica.debugOpenPanel('decoder'));
await page.waitForTimeout(350);
const pattern = await page.evaluate(
  () => document.querySelector('#overlay [data-pattern]')?.textContent?.length ?? 0,
);
check('decodificador muestra la trama parcial', pattern > 6, `chars=${pattern}`);
await page.keyboard.press('Escape');
const dec = await page.evaluate((cipher) => window.__estatica.decode(cipher), mach.cipher);
check('decodificar desde la API', dec.ok, dec.message);

// Interacción real: mirar el terminal del plato y pulsar E.
await page.evaluate(() => {
  const g = window.__estatica;
  g.player.teleport(18, 0, -5.9);
  g.player.setLook(0, -0.3);
});
const advanced = await waitFrames(3);
check('el render avanza frames', advanced > 0, `frames=${advanced}`);
const focusBeforeE = await page.evaluate(() => {
  const g = window.__estatica;
  return {
    focus: g.player.currentFocus?.id ?? null,
    enabled: g.player.enabled,
    screenOpen: g.hud.screenOpen,
    panel: g.panels.current,
    pos: g.player.position.toArray(),
    cam: g.world.camera.position.toArray(),
    rot: g.world.camera.rotation.toArray().slice(0, 3),
    terminal: g.level.interactables.find((i) => i.id === 'terminal')?.position.toArray(),
    frame: g.world.renderer.info.render.frame,
    paused: g.sim.paused,
  };
});
check('el raycast detecta el terminal', focusBeforeE.focus === 'terminal', JSON.stringify(focusBeforeE));
await page.keyboard.press('e');
await page.waitForTimeout(600);
const dishTitle = await page.evaluate(
  () => document.querySelector('#overlay .panel-head h2')?.textContent ?? '',
);
check('E abre el terminal al mirarlo', /terminal del plato/i.test(dishTitle), dishTitle);
await page.keyboard.press('Escape');

// El escáner no debe atravesar las paredes del laboratorio.
await page.evaluate(() => {
  const g = window.__estatica;
  g.entities.clear();
  g.entities.spawn('perro', 'fence');
  const e = g.entities.entities.at(-1);
  const p = g.player.position;
  g.player.setLook(Math.atan2(-(e.position.x - p.x), -(e.position.z - p.z)), -0.05);
});
await waitFrames(2);
check(
  'el escáner no atraviesa paredes',
  await page.evaluate(() => window.__estatica.entities.scanTarget() === null),
);

// Entidad observable + escáner de campo, ahora con línea de visión despejada.
const scanTarget = await page.evaluate(() => {
  const g = window.__estatica;
  g.entities.clear();
  g.player.teleport(8, 0, 12);
  g.entities.spawn('perro', 'fence');
  const e = g.entities.entities.at(-1);
  const p = g.player.position;
  const dx = e.position.x - p.x;
  const dz = e.position.z - p.z;
  g.player.setLook(Math.atan2(-dx, -dz), -0.02);
  return { before: g.state.stats.scans, fragments: g.state.fragments };
});
await waitFrames(2);
check(
  'el escáner detecta con línea de visión',
  await page.evaluate(() => window.__estatica.entities.scanTarget() !== null),
);
await page.keyboard.press('q');
const scanDeadline = Date.now() + 15000;
let scanned = false;
while (Date.now() < scanDeadline) {
  scanned = await page.evaluate(() => window.__estatica.state.stats.scans > 0);
  if (scanned) break;
  await page.waitForTimeout(300);
}
const scanAfter = await page.evaluate(() => ({
  scans: window.__estatica.state.stats.scans,
  fragments: window.__estatica.state.fragments,
}));
check('escáner registra la lectura', scanned, JSON.stringify(scanAfter));
check('el contacto deja fragmentos', scanAfter.fragments > scanTarget.fragments, JSON.stringify(scanAfter));

// ---------- fase 2: clima, averías, repetidor, triangulación y trueque ----------

// Clima: entra en el estado, en el HUD y en la escena.
await page.evaluate(() => window.__estatica.debugWeather('ventisca', 1));
await waitFrames(3);
const weatherState = await page.evaluate(() => ({
  kind: window.__estatica.state.weather.kind,
  label: document.querySelector('[data-weather]')?.textContent ?? '',
  noise: window.__estatica.dish.noise,
  fog: window.__estatica.world.scene.fog.density,
}));
check('el clima llega al estado y al HUD', weatherState.kind === 'ventisca' && /ventisca/i.test(weatherState.label), JSON.stringify(weatherState));
check('la ventisca sube el ruido de banda', weatherState.noise > 20, `noise=${weatherState.noise}`);
check('la niebla de la escena se cierra con el clima', weatherState.fog > 0.0105, `fog=${weatherState.fog}`);

// Avería: la máquina no responde y el panel ofrece calibración y repuesto.
const faulted = await page.evaluate(() => {
  const g = window.__estatica;
  g.state.power = true;
  g.state.powerOutTimer = 0;
  g.debugFault('decoder');
  g.debugGrantCapture('BALIZA');
  const cap = g.state.captures.filter((c) => !c.sold).at(-1);
  g.selectCapture(cap.id);
  g.isolate(cap.band);
  g.demod(cap.modulation);
  const blocked = g.decode(cap.cipher);
  return { blocked: blocked.ok, message: blocked.message, faults: Object.keys(g.state.faults).length };
});
check('una máquina averiada no decodifica', faulted.blocked === false && faulted.faults === 1, JSON.stringify(faulted));

await page.evaluate(() => window.__estatica.debugOpenPanel('decoder'));
await page.waitForTimeout(300);
const faultPanel = await page.evaluate(() => document.querySelector('#overlay .panel')?.textContent ?? '');
check('el panel muestra la avería con sus acciones', /FUERA DE SERVICIO/i.test(faultPanel) && /CALIBRAR/.test(faultPanel) && /PIEZA/.test(faultPanel));
await page.keyboard.press('Escape');

const repaired = await page.evaluate(() => {
  const g = window.__estatica;
  g.state.points = 500;
  const bought = g.buyPart();
  const res = g.repair('decoder');
  return { bought: bought.ok, repair: res.ok, message: res.message, parts: g.state.parts, faults: Object.keys(g.state.faults).length };
});
check('comprar pieza y reparar devuelve la máquina al servicio', repaired.bought && repaired.repair && repaired.faults === 0, JSON.stringify(repaired));
check('la reparación consume la pieza', repaired.parts === 0, `parts=${repaired.parts}`);

// Motonieve: viaje real de 900 m al repetidor.
const tripOffer = await page.evaluate(() => {
  const g = window.__estatica;
  g.debugUnlockRepeater();
  return { zone: g.debugSnapshot().zone, options: g.travelOptions().filter((o) => o.enabled).map((o) => o.dest) };
});
check('la motonieve ofrece el repetidor con la baliza despierta', tripOffer.options.includes('repetidor'), JSON.stringify(tripOffer));
await page.evaluate(() => window.__estatica.debugOpenPanel('travel'));
await page.waitForTimeout(300);
const travelPanel = await page.evaluate(() => document.querySelector('#overlay .panel')?.textContent ?? '');
check('el panel de la motonieve lista los destinos', /REPETIDOR/i.test(travelPanel) && /KESTREL/i.test(travelPanel));
const travelStart = await page.evaluate(() => window.__estatica.travel('repetidor'));
check('el viaje arranca', travelStart.ok === true, travelStart.message);
const arrivedRepeater = await waitState(async () => (await page.evaluate(() => window.__estatica.debugSnapshot().zone)) === 'repetidor');
check('la motonieve llega al repetidor', arrivedRepeater === true);
const atRepeater = await page.evaluate(() => {
  const g = window.__estatica;
  return {
    zone: g.level.zoneAt(g.player.position),
    walkable: g.level.isWalkable(g.player.position.x, g.player.position.z),
    insideHut: g.level.isInside(g.player.position),
    x: Math.round(g.player.position.x),
  };
});
check('el repetidor es un emplazamiento caminable', atRepeater.zone === 'repetidor' && atRepeater.walkable === true, JSON.stringify(atRepeater));
check('el repetidor está a 900 m de Kestrel', Math.abs(atRepeater.x + 900) < 60, JSON.stringify(atRepeater));

// Triangulación: tres mástiles, umbral de aguja y origen localizado.
await page.evaluate(() => window.__estatica.debugOpenPanel('tri'));
await page.waitForTimeout(400);
const triPanel = await page.evaluate(() => ({
  masts: document.querySelectorAll('#overlay [data-mast-range]').length,
  canvas: !!document.querySelector('#overlay canvas'),
  text: document.querySelector('#overlay .panel')?.textContent ?? '',
}));
check('la consola del repetidor pinta los tres mástiles', triPanel.masts === 3 && triPanel.canvas, JSON.stringify({ masts: triPanel.masts, canvas: triPanel.canvas }));
check('la consola pide los tres rumbos', /TRIANGULAR \(0\/3\)/.test(triPanel.text));
const badLock = await page.evaluate(() => {
  const g = window.__estatica;
  g.aimMast(0, 15);
  return g.lockMast(0);
});
check('un apuntado flojo no fija el rumbo', badLock.ok === false, badLock.message);
const triFix = await page.evaluate(() => window.__estatica.debugAutoTriangulate());
check('la triangulación localiza el origen', triFix.ok === true, triFix.message);
const triState = await page.evaluate(() => {
  const g = window.__estatica;
  const snap = g.debugSnapshot();
  return { fixed: snap.triFixed, locked: snap.tri, originZone: g.level.hasOriginZone(), fragments: g.state.fragments };
});
check('el origen queda fijado con coordenadas', !!triState.fixed && triState.locked === 3, JSON.stringify(triState));
check('la triangulación abre una zona transitable en el origen', triState.originZone === true);
await page.keyboard.press('Escape');

// Viaje al origen y registro de los restos.
const originTrip = await page.evaluate(() => window.__estatica.travel('origen'));
check('se puede salir al origen triangulado', originTrip.ok === true, originTrip.message);
const arrivedOrigin = await waitState(async () => (await page.evaluate(() => window.__estatica.debugSnapshot().zone)) === 'origen');
check('la motonieve llega al origen', arrivedOrigin === true);
await page.evaluate(() => {
  const g = window.__estatica;
  const fixed = g.triFixed;
  g.player.teleport(fixed.x + 3.4, 0, fixed.z + 0.6);
  g.player.setLook(Math.atan2(1.2, 2.2), -0.3);
});
await waitFrames(3);
const originFocus = await page.evaluate(() => window.__estatica.player.currentFocus?.id ?? null);
check('el raycast detecta los restos del emisor', originFocus === 'origen', `focus=${originFocus}`);
const beforeInspect = await page.evaluate(() => window.__estatica.state.fragments);
await page.keyboard.press('e');
await page.waitForTimeout(600);
const inspected = await page.evaluate(() => ({
  visited: window.__estatica.state.flags['origen_visitado'],
  fragments: window.__estatica.state.fragments,
  captures: window.__estatica.state.captures.length,
}));
check('registrar los restos deja fragmentos', inspected.fragments > beforeInspect, JSON.stringify(inspected));
check('el origen queda marcado como registrado', !!inspected.visited);

// Trueque: el cajón pide una captura concreta y paga sin tocar la cuota.
const trade = await page.evaluate(() => {
  const g = window.__estatica;
  g.state.power = true;
  g.state.powerOutTimer = 0;
  g.debugSpawnOffer();
  const view = g.tradeView();
  g.debugGrantCapture(view.wantsKlass ?? 'BALIZA');
  const cap = g.state.captures.filter((c) => !c.sold).at(-1);
  g.selectCapture(cap.id);
  g.isolate(cap.band);
  g.demod(cap.modulation);
  g.decode(cap.cipher);
  const quota = g.state.quota.earned;
  const before = g.state.points;
  const res = g.trade(cap.id);
  return {
    ok: res.ok,
    message: res.message,
    gained: g.state.points - before,
    quotaUnchanged: g.state.quota.earned === quota,
    barters: g.state.stats.barters,
    active: !!g.state.flags['comerciante_activo'],
    wants: view.wantsKlass,
  };
});
check('el trueque entrega la captura pedida y paga en créditos', trade.ok && trade.gained > 0, JSON.stringify(trade));
check('el trueque no suma a la cuota de Control', trade.quotaUnchanged === true);
check('el cajón se cierra al cerrar el trato', trade.active === false && trade.barters === 1, JSON.stringify(trade));

// Vuelta a Kestrel para cerrar el turno.
const backHome = await page.evaluate(() => {
  window.__estatica.debugTeleport('kestrel');
  return window.__estatica.debugSnapshot().zone;
});
check('se puede volver a Kestrel', backHome === 'kestrel', `zone=${backHome}`);

// Cierre de turno y parte de control.
await page.evaluate(() => {
  window.__estatica.state.clock = 598.5;
});
const shiftDeadline = Date.now() + 30000;
let summary = { open: false, text: '' };
while (Date.now() < shiftDeadline) {
  summary = await page.evaluate(() => ({
    open: !!document.querySelector('.screen-layer.open'),
    text: document.querySelector('.screen-layer')?.textContent?.slice(0, 120) ?? '',
  }));
  if (summary.open) break;
  await page.waitForTimeout(300);
}
check('el fin de turno muestra el parte', summary.open && /PARTE DE TURNO/i.test(summary.text), summary.text.replace(/\s+/g, ' ').slice(0, 80));
await page.locator('[data-continue]').click();
await page.waitForTimeout(600);
const dayAfter = await page.evaluate(() => window.__estatica.debugSnapshot().day);
check('avanza al día siguiente', dayAfter === 2, `day=${dayAfter}`);

// Guardado + recarga (continuar)
await page.evaluate(() => window.__estatica.saveNow(false));
await page.waitForTimeout(300);
const reload = await page.evaluate(async () => {
  const raw = localStorage.getItem('estatica.save.v1');
  return raw ? JSON.parse(raw).day : null;
});
check('partida escrita en almacenamiento', reload !== null, `day=${reload}`);

await page.reload({ waitUntil: 'networkidle' });
await page.waitForSelector('#boot .menu button', { timeout: 15000 });
const menuText = await page.locator('#boot .menu').innerText();
check('al recargar ofrece continuar', /continuar/i.test(menuText), menuText.replace(/\n/g, ' | '));
await page.locator('#boot .menu button').first().click();
await page.waitForTimeout(1000);
const restored = await page.evaluate(() => window.__estatica.debugSnapshot());
check(
  'continúa con la partida guardada',
  restored?.started === true && restored?.day === 2 && (restored?.captures ?? 0) >= 1,
  JSON.stringify(restored),
);

// Acto II: decisión persistente del archivo del operador (día 7).
await page.evaluate(() => {
  const g = window.__estatica;
  g.state.day = 7;
  g.state.clock = 146;
  g.state.power = true;
});
const decisionOpen = await waitState(() =>
  page.evaluate(() => !!document.querySelector('.screen-layer.open [data-option]')),
);
const decisionTitle = await page.evaluate(
  () => document.querySelector('.screen-layer.open h1')?.textContent ?? '',
);
check('el día 7 abre la decisión del archivo', decisionOpen && /ARCHIVO/i.test(decisionTitle), decisionTitle);
const beforeDecision = await page.evaluate(() => ({
  fragments: window.__estatica.state.fragments,
  decisions: window.__estatica.state.decisions.length,
}));
await page.locator('[data-option="leer"]').click();
await page.waitForTimeout(400);
const afterDecision = await page.evaluate(() => ({
  fragments: window.__estatica.state.fragments,
  decisions: window.__estatica.state.decisions.length,
  pending: !!window.__estatica.sim.pendingDecision,
}));
check(
  'elegir en la decisión la registra',
  afterDecision.decisions === beforeDecision.decisions + 1 && !afterDecision.pending,
  JSON.stringify(afterDecision),
);
check(
  'leer la carpeta suma un fragmento',
  afterDecision.fragments === beforeDecision.fragments + 1,
  JSON.stringify(afterDecision),
);

// Final: día 12 + 12 fragmentos habilita los tres desenlaces en la consola.
await page.evaluate(() => {
  const g = window.__estatica;
  g.state.day = 12;
  g.state.clock = 200;
  g.state.fragments = Math.max(12, g.state.fragments);
  g.debugOpenPanel('pc');
});
await page.locator('[data-tab="control"]').click();
const endings = await page.locator('[data-ending]').count();
check('el final ofrece los tres desenlaces', endings === 3, `endings=${endings}`);
await page.locator('[data-ending="cortar"]').click();
await page.waitForTimeout(500);
const ending = await page.evaluate(() => ({
  ending: window.__estatica.state.ending,
  decisions: window.__estatica.state.decisions.length,
  screen: document.querySelector('.screen-layer.open')?.textContent ?? '',
}));
check('elegir un desenlace cierra la partida', ending.ending === 'cortar', JSON.stringify(ending));
check(
  'el epílogo recuerda las decisiones',
  ending.decisions >= 1 && /LO QUE DECIDISTE/i.test(ending.screen),
  ending.screen.slice(0, 80),
);

// Errores de runtime
const relevant = errors.filter(
  (e) =>
    !/AudioContext|pointer lock|favicon|fonts\.googleapis|net::ERR|Failed to load resource|WebGL|SwiftShader/i.test(e),
);
check('sin errores de runtime', relevant.length === 0, relevant.slice(0, 5).join(' || '));

await browser.close();

if (failures.length > 0) {
  console.error(`\n${failures.length} comprobaciones fallidas:`);
  for (const f of failures) console.error(' -', f);
  process.exit(1);
}
console.log('\nSMOKE OK');
