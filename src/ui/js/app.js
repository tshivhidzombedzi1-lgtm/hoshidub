import { enableRefraction, refreshRefraction } from './glass.js';
import { Dubber } from './dub.js';
import { SubtitleSync } from './subsync.js';
import { HoshiAvatar, HoshiClient } from './hoshi.js';

const $ = (id) => document.getElementById(id);
const koe = window.koe;
const root = document.documentElement;

const state = {
  settings: null,
  engine: { state: 'loading', detail: 'Starting' },
  nav: { url: '', showingBrowser: false, canGoBack: false, canGoForward: false, loading: false },
  page: 'home',               // home | settings | browser | error
  fullscreen: false,
  lastError: null,
  subs: null,                 // { count, format } when the page has English subtitles
};
let sync = null;
let usageTimer = null;
const dubber = new Dubber();
const voiceHues = new Map();

// ---------------------------------------------------------------- small UI helpers
function toast(text, kind = 'info', ms = 3200) {
  const el = document.createElement('div');
  el.className = `toast ${kind}`;
  el.innerHTML = kind === 'error' ? '<svg><use href="#i-alert"/></svg>' : '<svg><use href="#i-sparkle"/></svg>';
  el.append(text);
  const host = $('toasts');
  host.replaceChildren(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 240); }, ms);
}

function setFill(range) {
  const pct = ((range.value - range.min) / (range.max - range.min)) * 100;
  range.style.setProperty('--fill', `${pct}%`);
}

function hueFor(voice) {
  if (!voiceHues.has(voice)) voiceHues.set(voice, [265, 200, 330, 150, 30, 50][voiceHues.size % 6]);
  return voiceHues.get(voice);
}

function characterName(voice) {
  const n = [...voiceHues.keys()].indexOf(voice);
  return `Character ${n + 1}`;
}

// ---------------------------------------------------------------- pages & layout
function showPage(page) {
  state.page = page;
  $('page-home').hidden = page !== 'home';
  $('page-settings').hidden = page !== 'settings';
  $('page-error').hidden = page !== 'error';
  document.getElementById('app').classList.toggle('browsing', page === 'browser');
  document.body.classList.toggle('browsing', page === 'browser');
  if (page !== 'browser') clearTint();
  if (page === 'home' && typeof avatars !== 'undefined' && avatars.home) { avatars.home.jump(); greetOnce(); }
  for (const [id, p] of [['nav-home', 'home'], ['nav-settings', 'settings']]) {
    $(id).toggleAttribute('aria-current', page === p);
    if (page === p) $(id).setAttribute('aria-current', 'page');
  }
  const host = hostOf(state.nav.url);
  $('nav-crunchyroll').toggleAttribute('aria-current', page === 'browser' && host.endsWith('crunchyroll.com'));
  $('nav-youtube').toggleAttribute('aria-current', page === 'browser' && host.endsWith('youtube.com'));
  if (page !== 'browser') koe.nav.home();     // always hide the browser view (keeps the page alive), even if our state lags
  if (page === 'browser' && !state.nav.showingBrowser) koe.nav.resume();
}

function hostOf(url) {
  try { return new URL(url).hostname.replace(/^www\./, ''); } catch { return ''; }
}

function reportViewport() {
  const r = $('viewport').getBoundingClientRect();
  koe.layout.viewport({ x: r.left, y: r.top, width: r.width, height: r.height });
}

function setPanel(open) {
  $('app').dataset.panel = open ? 'open' : 'closed';
  $('btn-panel').setAttribute('aria-expanded', String(open));
  $('btn-panel').setAttribute('aria-label', open ? 'Hide dub panel' : 'Show dub panel');
  koe.settings.set('dubPanelOpen', open);
  // follow the column animation so the video resizes smoothly with the grid
  const until = performance.now() + 400;
  const step = () => { reportViewport(); if (performance.now() < until) requestAnimationFrame(step); };
  requestAnimationFrame(step);
}

// ---------------------------------------------------------------- navigation
function renderNav(nav) {
  state.nav = nav;
  $('btn-back').disabled = !nav.canGoBack || !nav.showingBrowser;
  $('btn-fwd').disabled = !nav.canGoForward || !nav.showingBrowser;
  const reload = $('btn-reload');
  reload.querySelector('use').setAttribute('href', nav.loading ? '#i-stop' : '#i-reload');
  reload.setAttribute('aria-label', nav.loading ? 'Stop' : 'Reload');
  const form = $('address-form');
  form.classList.toggle('loading', nav.loading);
  form.classList.toggle('loaded', !nav.loading);
  const input = $('address');
  if (document.activeElement !== input) input.value = nav.showingBrowser ? displayUrl(nav.url) : '';
  const secure = nav.showingBrowser && nav.url.startsWith('https://');
  $('address-icon').querySelector('use').setAttribute('href', secure ? '#i-lock' : '#i-search');
  if (nav.showingBrowser && state.page !== 'browser' && state.page !== 'error') showPage('browser');
  if (!nav.showingBrowser && state.page === 'browser') showPage('home');
  document.title = nav.showingBrowser && nav.title ? `${nav.title} — Hoshidub` : 'Hoshidub';
  if (state.adblock) renderAdblock(state.adblock);
  renderDubButton();
}

function displayUrl(url) {
  try {
    const u = new URL(url);
    return u.hostname.replace(/^www\./, '') + (u.pathname !== '/' ? u.pathname : '');
  } catch { return url; }
}

function go(input) {
  if (!input.trim()) return;
  state.lastError = null;
  koe.nav.go(input);
  showPage('browser');
  $('address').blur();
}

function open(site) {
  state.lastError = null;
  koe.nav.open(site);
  showPage('browser');
}

// ---------------------------------------------------------------- engine + dub
function renderEngine(info) {
  state.engine = info;
  if (info.port && info.state !== 'setup') hoshi.connect(info);            // Hoshi talks to the same engine
  const labels = { loading: 'Warming up', ready: 'Ready', error: 'Unavailable', off: 'Off', setup: 'Needs voices' };
  $('engine-state').textContent = labels[info.state] || info.state;
  $('engine-detail').textContent = friendlyDetail(info);
  $('engine-dot').dataset.state = info.state;
  $('about-engine').textContent = `${labels[info.state] || info.state} · ${friendlyDetail(info)}`;
  renderDubButton();
}

function friendlyDetail(info) {
  if (info.state !== 'ready') return info.detail || '';
  return info.detail.replace('whisper-large-v2', 'Best quality').replace(' on CUDA', ' · GPU').replace(' on CPU', ' · CPU');
}

function renderDubButton() {
  const btn = $('dub-btn');
  const ready = state.engine.state === 'ready';
  btn.setAttribute('aria-pressed', String(dubber.active));
  $('dub-switch').checked = dubber.active;
  $('dub-switch').disabled = !ready;
  $('dub-dot').dataset.state = dubber.active ? 'ready' : state.engine.state === 'ready' ? '' : state.engine.state;
  $('dub-label').textContent = dubber.active ? 'Dubbing' : state.engine.state === 'loading' ? 'Warming up' : 'Dub';
  btn.dataset.tip = ready ? 'Live dub  Ctrl+D' : state.engine.detail || 'Dubbing engine is starting';
}

async function toggleDub(force) {
  const want = force ?? !dubber.active;
  if (!want) { await dubber.stop(); renderDubButton(); return; }
  if (state.license?.plan === 'free' && state.license.remaining <= 0) { showUpgrade('limit'); return; }
  if (state.engine.state !== 'ready') {
    toast(state.engine.state === 'error' ? state.engine.detail : 'The voices are still warming up — one moment.', state.engine.state === 'error' ? 'error' : 'info');
    return;
  }
  if (!state.nav.showingBrowser) { toast('Open a video first, then press Dub.'); return; }
  try {
    dubber.englishVolume = state.settings.englishVolume;
    dubber.duckLevel = state.settings.duckLevel;
    dubber.mode = usingSubs() ? 'subs' : 'listen';
    await dubber.start(await koe.engine.info());
    await applyMode();
    koe.dubLog({ event: 'dub-on', mode: usingSubs() ? 'subs' : 'listen', page: state.nav.url });
    toast(usingSubs() ? 'Live dub is on — using official subtitles' : 'Live dub is on');
  } catch (e) {
    toast(e.message || 'Could not start the dub.', 'error');
  }
  renderDubButton();
}

function addTranscript(line) {
  $('transcript-empty').hidden = true;
  const list = $('transcript');
  list.querySelectorAll('.now').forEach((el) => el.classList.remove('now'));
  const li = document.createElement('li');
  li.className = 'now';
  li.style.setProperty('--hue', hueFor(line.voice));
  const who = document.createElement('b');
  who.textContent = characterName(line.voice);
  li.append(who, line.text);
  list.append(li);
  while (list.children.length > 80) list.children[1].remove();
  li.scrollIntoView({ block: 'end', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
  $('latency').textContent = `${line.latency.toFixed(1)} s behind`;
}

dubber.addEventListener('line', ({ detail: line }) => {
  if (!line || !line.text) return;
  addTranscript(line);
  koe.dubLog({ event: 'line', id: line.id, text: line.text, voice: line.voice, latency: line.latency, source: line.source || 'ear' });
  if (state.settings.captions && line.source !== 'subtitles') {    // the site already shows its own subtitles
    koe.captions.show({ text: line.text, ms: line.duration * 1000 + 900, size: state.settings.captionSize });
  }
});
dubber.addEventListener('speaking', ({ detail }) => $('dub-btn').classList.toggle('speaking', detail));
dubber.addEventListener('engine', ({ detail }) => { if (detail.detail?.startsWith('voice service')) toast(detail.detail, 'error'); });
dubber.addEventListener('error', ({ detail }) => { toast(detail, 'error'); renderDubButton(); });
dubber.addEventListener('state', () => {
  renderDubButton();
  clearInterval(usageTimer);
  if (!dubber.active) { koe.captions.hide(); stopSync(); return; }
  usageTimer = setInterval(async () => {          // Free plan: count dubbing time against today's allowance
    const remaining = await koe.license.usage(10);
    if (remaining === null) return;
    state.license = { ...state.license, remaining };
    renderPlan();
    if (remaining <= 0) { await toggleDub(false); showUpgrade('limit'); }
  }, 10000);
});

// ---------------------------------------------------------------- adaptive glass: follow the open page
let glowFront = 'a';
function applyTint(t) {
  const browsing = state.page === 'browser';
  if (!browsing) return;
  // glass goes dark on dark pages and light on bright ones (hysteresis stops it flickering around the middle)
  const cur = root.dataset.theme;
  const theme = t.lum < 0.42 ? 'dark' : t.lum > 0.55 ? 'light' : cur || (t.lum < 0.5 ? 'dark' : 'light');
  root.dataset.theme = theme;
  const back = glowFront === 'a' ? 'b' : 'a';
  const img = $(`glow-${back}`);
  img.style.backgroundImage = `url("${t.image}")`;
  img.classList.add('on');
  $(`glow-${glowFront}`).classList.remove('on');
  glowFront = back;
  const [r, g, b] = t.top;
  document.body.style.setProperty('--edge-glow', `rgba(${r}, ${g}, ${b}, 0.55)`);
}

function clearTint() {
  delete root.dataset.theme;                       // back to the system theme over the photo
  document.body.classList.remove('browsing');
}

// ---------------------------------------------------------------- ad blocker
function renderAdblock(s) {
  state.adblock = s;
  const btn = $('shield-btn');
  btn.hidden = !s.available || !state.nav.showingBrowser || !s.site;
  const on = s.enabled && !s.allowed;
  btn.classList.toggle('off', !on);
  $('shield-icon').querySelector('use').setAttribute('href', on ? '#i-shield' : '#i-shield-off');
  $('shield-count').textContent = s.blocked > 999 ? '999+' : String(s.blocked);
  const tip = !s.enabled ? 'Ad blocker is off (Settings)'
    : s.allowed ? `Ads allowed on ${s.site}. Click to block them.`
      : `${s.blocked} ads and trackers blocked on ${s.site}. Click to allow ads on this site.`;
  btn.dataset.tip = tip;
  btn.setAttribute('aria-label', tip);
  $('set-adblock').checked = s.enabled;
}

function bindAdblock() {
  $('shield-btn').addEventListener('click', async () => {
    const s = state.adblock;
    if (!s?.enabled) { showPage('settings'); return; }
    await koe.adblock.toggleSite();
    toast(s.allowed ? `Blocking ads on ${s.site}` : `Ads allowed on ${s.site}`);
  });
  $('set-adblock').addEventListener('change', (e) => koe.adblock.setEnabled(e.target.checked));
  koe.adblock.onState(renderAdblock);
}

function bindTint() {
  koe.page.onTint((t) => { state.lastTint = t; if (state.page === 'browser') applyTint(t); });
}

// ---------------------------------------------------------------- first-run setup: download the voices
const mb = (bytes) => Math.round(bytes / 1e6);

function setupSize() {
  const s = state.setup;
  const need = ['core', 'voices-en'].filter((k) => !s.packs[k]).reduce((t, k) => t + (s.sizes_mb[k] || 0), 0)
    + (s.runtime === false ? s.sizes_mb.runtime || 0 : 0);
  return need + ($('setup-ear').checked && !s.packs.ear ? s.sizes_mb.ear || 0 : 0);
}

function renderSetupButton() {
  const size = setupSize();
  $('setup-go').textContent = size >= 1000 ? `Download (${(size / 1000).toFixed(1)} GB)` : `Download (${size} MB)`;
}

function showSetup() {
  const s = state.setup;
  const gpu = $('gpu-line');
  if (s.error) { $('setup-error').textContent = s.error; $('setup-error').hidden = false; }
  gpu.hidden = s.runtime === false;               // the graphics card is checked once the engine is installed
  gpu.textContent = s.gpu?.cuda ? `${s.gpu.name.replace(/^NVIDIA (GeForce )?/, '')} · ${s.gpu.vram_gb} GB · fast dubbing ready`
    : 'No NVIDIA graphics card · voices start a little later';
  gpu.classList.toggle('slow', !s.gpu?.cuda);
  $('ear-opt').hidden = !!s.packs.ear;
  $('setup-ear').checked = false;
  renderSetupButton();
  $('setup').hidden = false;
  $('setup-go').focus();
}

let dlStart = 0;
function startSetup(packs) {
  $('setup-error').hidden = true;
  $('setup-progress').hidden = false;
  $('setup-go').disabled = true;
  $('setup-go').textContent = 'Downloading…';
  $('setup-ear').disabled = true;
  dlStart = performance.now();
  koe.setup.start(packs);
}

function bindSetup() {
  $('setup-ear').addEventListener('change', renderSetupButton);
  $('setup-go').addEventListener('click', () => startSetup($('setup-ear').checked ? ['ear'] : []));
  $('dl-ear').addEventListener('click', () => {
    $('dl-ear').disabled = true;
    $('dl-ear').textContent = 'Downloading…';
    koe.setup.start(['ear']);
  });
  koe.setup.onProgress(({ done, total, phase }) => {
    if (phase === 'unpack') { $('setup-text').textContent = 'Unpacking the dubbing engine…'; return; }
    const secs = (performance.now() - dlStart) / 1000;
    const rate = secs > 1 ? done / secs : 0;
    const left = rate ? (total - done) / rate : 0;
    const eta = left > 90 ? `about ${Math.round(left / 60)} min left` : left > 0 ? `about ${Math.ceil(left)} s left` : '';
    $('setup-fill').style.width = `${total ? (done / total) * 100 : 0}%`;
    $('setup-text').textContent = [`${mb(done)} of ${mb(total)} MB`, rate ? `${(rate / 1e6).toFixed(1)} MB/s` : '', eta].filter(Boolean).join(' · ');
    if (!$('dl-ear').disabled) return;
    $('dl-ear-detail').textContent = `Downloading · ${mb(done)} of ${mb(total)} MB`;
  });
  koe.setup.onDone((s) => {
    state.setup = s;
    $('setup').hidden = true;
    $('setup-go').disabled = false;
    $('setup-ear').disabled = false;
    renderDownloads();
    toast('Voices downloaded. Hoshidub is warming up.');
  });
  koe.setup.onError((msg) => {
    $('setup-error').textContent = msg;
    $('setup-error').hidden = false;
    $('setup-go').disabled = false;
    $('setup-go').textContent = 'Retry';
    $('setup-ear').disabled = false;
    $('dl-ear').disabled = false;
    $('dl-ear').textContent = 'Retry';
    if ($('setup').hidden) toast(msg, 'error', 6000);
  });
}

function renderDownloads() {
  const s = state.setup;
  if (!s || s.skipped) return;
  $('dl-voices').textContent = s.packs['voices-en'] ? 'Installed' : 'Not downloaded yet';
  const ear = !!s.packs.ear;
  $('dl-ear').hidden = ear;
  $('dl-ear').disabled = false;
  $('dl-ear').textContent = 'Download';
  $('dl-ear-detail').textContent = ear ? 'Installed · for shows without subtitles' : 'For shows without subtitles · 3.1 GB';
}

// ---------------------------------------------------------------- plan: Free allowance or Pro licence
function minutes(s) { return Math.max(0, Math.ceil(s / 60)); }

function renderPlan() {
  const l = state.license;
  if (!l) return;
  const pro = l.plan === 'pro';
  const meter = $('plan-meter');
  meter.hidden = pro;
  if (!pro) {
    const left = minutes(l.remaining);
    $('meter-text').textContent = left > 0 ? `${left} min of free dubbing left today` : 'Free dubbing used up for today';
    $('meter-fill').style.width = `${(l.remaining / l.freeSeconds) * 100}%`;
    meter.classList.toggle('low', l.remaining < 5 * 60);
  }
  $('plan-name').textContent = pro ? 'Hoshidub Pro' : 'Free';
  $('plan-detail').textContent = pro ? `Licence ${l.key} · unlimited dubbing` : `${minutes(l.freeSeconds)} minutes of dubbing a day · ${minutes(l.remaining)} left today`;
  $('plan-upgrade').hidden = pro;
  $('plan-deactivate').hidden = !pro;
}

function showUpgrade(reason) {
  const dlg = $('upgrade');
  $('up-title').textContent = reason === 'limit' ? "You've used today's free dubbing" : 'Keep dubbing with Pro';
  $('up-sub').textContent = reason === 'limit'
    ? 'Free dubbing comes back tomorrow. Go Pro to keep watching now, with no daily limit.'
    : 'Unlimited live dubbing, official subtitles on cue, and a voice for every character.';
  $('up-buy').hidden = !state.canCheckout;
  $('up-error').hidden = true;
  dlg.hidden = false;
  (state.canCheckout ? $('up-buy') : $('up-key')).focus();
}

function hideUpgrade() { $('upgrade').hidden = true; }

function bindPlan() {
  $('meter-upgrade').addEventListener('click', () => showUpgrade());
  $('plan-upgrade').addEventListener('click', () => showUpgrade());
  $('up-close').addEventListener('click', hideUpgrade);
  $('upgrade').addEventListener('keydown', (e) => { if (e.key === 'Escape') hideUpgrade(); });
  $('upgrade').addEventListener('click', (e) => { if (e.target.id === 'upgrade') hideUpgrade(); });
  $('up-buy').addEventListener('click', () => koe.license.checkout());
  $('up-key-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = $('up-activate');
    btn.disabled = true;
    btn.textContent = 'Checking…';
    const r = await koe.license.activate($('up-key').value);
    btn.disabled = false;
    btn.textContent = 'Activate';
    if (!r.ok) { $('up-error').textContent = r.error; $('up-error').hidden = false; return; }
    hideUpgrade();
    $('up-key').value = '';
    toast('Welcome to Hoshidub Pro');
  });
  let armed = false;
  $('plan-deactivate').addEventListener('click', async (e) => {
    if (!armed) { armed = true; e.currentTarget.textContent = 'Click again to remove'; setTimeout(() => { armed = false; $('plan-deactivate').textContent = 'Remove from this PC'; }, 4000); return; }
    armed = false;
    $('plan-deactivate').textContent = 'Remove from this PC';
    await koe.license.deactivate();
    toast('Licence removed from this PC');
  });
  koe.license.onState((s) => { state.license = s; renderPlan(); });
}

// ---------------------------------------------------------------- source: official subtitles or by ear
function usingSubs() {
  return !!(state.subs && state.settings.preferSubtitles);
}

function renderSource() {
  const subs = usingSubs();
  $('source').dataset.mode = subs ? 'subs' : 'listen';
  $('source-title').textContent = subs ? 'Official subtitles' : 'Translating by ear';
  $('source-detail').textContent = subs
    ? `${state.subs.count} lines · voiced in sync with the show`
    : state.subs ? 'Subtitles found, turned off in Settings' : 'No English subtitles found on this page';
}

function stopSync() {
  sync?.stop();
  sync = null;
}

let modeGen = 0;
async function applyMode() {
  renderSource();
  const gen = ++modeGen;                 // overlapping calls: only the latest one gets to start a sync
  stopSync();
  if (!dubber.active) return;
  if (usingSubs()) {
    const track = await koe.subs.get();
    if (gen !== modeGen) return;
    if (!track) { dubber.setMode('listen'); return; }
    dubber.setMode('subs');
    sync = new SubtitleSync({
      lines: track.lines,
      getState: () => koe.player.state(),
      onLine: (id, text, dur, speaker) => dubber.say(id, text, dur, speaker),
      onPrepare: (id, text, dur, speaker) => dubber.prepare(id, text, dur, speaker),
    });
    sync.start();
  } else {
    dubber.setMode('listen');
  }
}


// ---------------------------------------------------------------- Hoshi, the watch buddy
const hoshi = new HoshiClient();
const avatars = {};
let hoshiState = 'offline';
let hoshiGreeted = false;
let hoshiDownloading = false;

function setTab(tab) {
  const hoshiTab = tab === 'hoshi';
  $('tab-dub').setAttribute('aria-selected', String(!hoshiTab));
  $('tab-hoshi').setAttribute('aria-selected', String(hoshiTab));
  $('pane-dub').hidden = hoshiTab;
  $('pane-hoshi').hidden = !hoshiTab;
  if (state.settings.panelTab !== tab) koe.settings.set('panelTab', tab);
  state.settings.panelTab = tab;
  if (hoshiTab) { $('hoshi-peek').hidden = true; greetOnce(); }
}

function renderHoshi() {
  const on = state.settings.hoshi;
  $('tab-hoshi').hidden = !on;
  $('home-hoshi').hidden = !on;
  if (!on && state.settings.panelTab === 'hoshi') setTab('dub');
  const missing = hoshiState === 'missing' || hoshiDownloading;
  $('hoshi-get').hidden = !missing;
  $('hoshi-form').hidden = missing;
  $('hoshi-chat').hidden = missing;
  $('home-bubble').textContent = hoshiState === 'ready' ? $('home-bubble').textContent
    : missing ? "Hi! I'm Hoshi. Download me in the panel and we'll watch together!"
      : hoshiState === 'loading' ? "Waking up… one sec!" : "Hi! I'm Hoshi. Let's watch something together!";
}

function bubble(text, mood) {
  for (const [key, el] of [['panel', $('hoshi-bubble')], ['home', $('home-bubble')]]) {
    el.textContent = text;
    el.hidden = false;
    avatars[key]?.mood(mood || 'calm');
  }
  if (state.settings.panelTab !== 'hoshi' && state.settings.hoshi) {      // on the Dub tab she pops up
    $('hoshi-peek-text').textContent = text;
    $('hoshi-peek').hidden = false;
    avatars.peek?.mood(mood || 'calm');
    clearTimeout(bubble.peekTimer);
    bubble.peekTimer = setTimeout(() => { $('hoshi-peek').hidden = true; }, 9000);
  }
}

function chat(text, who) {
  const li = document.createElement('li');
  li.className = who;
  li.textContent = text;
  $('hoshi-chat').append(li);
  while ($('hoshi-chat').children.length > 60) $('hoshi-chat').firstElementChild.remove();
  li.scrollIntoView({ block: 'end' });
  return li;
}

function greetOnce() {
  if (hoshiGreeted || hoshiState !== 'ready') return;
  hoshiGreeted = true;
  hoshi.hello();
  Object.values(avatars).forEach((a) => a.wave());
}

// what Hoshi may know: the episode up to now (never later), the show, and how loud the scene is
async function hoshiContext() {
  const ps = state.nav.showingBrowser ? await koe.player.state() : null;
  const t = ps ? ps.t : Infinity;
  let past = [], future = [];
  if (state.track && ps) {
    past = state.track.lines.filter((l) => l.start <= t).slice(-30).map((l) => ({ speaker: l.speaker, text: l.text }));
    future = state.track.lines.filter((l) => l.start > t).slice(0, 150).map((l) => l.text);
  } else {
    past = [...$('transcript').querySelectorAll('li:not(.transcript-empty)')].slice(-30)
      .map((li) => ({ speaker: li.querySelector('b')?.textContent || '', text: li.lastChild.textContent }));
  }
  const gap = { quiet: 1e9, normal: 150, chatty: 60 }[state.settings.hoshiChat] || 150;
  return {
    title: state.pageInfo?.title || (state.nav.showingBrowser ? state.nav.title : ''),
    about: state.pageInfo?.about || '',
    past, future, energy: dubber.active ? dubber.energy() : 0, min_gap: gap,
    paused: ps ? ps.paused : true, t: ps ? ps.t : null,
  };
}

async function askHoshi(text) {
  if (!text.trim() || hoshiState !== 'ready') return;
  chat(text, 'me');
  const typing = chat('Hoshi is thinking…', 'them typing');
  avatars.panel?.set('thinking');
  hoshi.pendingTyping = typing;
  hoshi.ask(text, await hoshiContext());
}

// hold-to-talk: record the mic at 16 kHz with the same audio tap the dub uses
let rec = null;
async function startListening() {
  if (rec || hoshiState !== 'ready') return;
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true } });
    const ctx = new AudioContext();
    await ctx.audioWorklet.addModule('js/worklet.js');
    const tap = new AudioWorkletNode(ctx, 'pcm-tap');
    const chunks = [];
    tap.port.onmessage = (e) => { if (chunks.length < 150) chunks.push(new Float32Array(e.data)); };   // ≤15 s
    const src = ctx.createMediaStreamSource(stream);
    const sink = ctx.createGain(); sink.gain.value = 0;
    src.connect(tap).connect(sink).connect(ctx.destination);
    rec = { stream, ctx, chunks };
    $('hoshi-mic').classList.add('listening');
    avatars.panel?.set('surprised');
  } catch {
    toast('Hoshidub needs your microphone to hear you. Allow it in Windows privacy settings.', 'error', 6000);
  }
}

async function stopListening() {
  if (!rec) return;
  const { stream, ctx, chunks } = rec;
  rec = null;
  $('hoshi-mic').classList.remove('listening');
  stream.getTracks().forEach((t) => t.stop());
  await ctx.close();
  const len = chunks.reduce((n, c) => n + c.length, 0);
  if (len < 16000 * 0.4) { avatars.panel?.set('neutral'); return; }       // a tap, not speech
  const pcm = new Float32Array(len);
  let o = 0;
  for (const c of chunks) { pcm.set(c, o); o += c.length; }
  hoshi.pendingTyping = chat('Hoshi is listening…', 'them typing');
  avatars.panel?.set('thinking');
  hoshi.voice(pcm, await hoshiContext());
}

// in quiet moments of the episode, give her a chance to react
async function maybeReact() {
  if (!state.settings.hoshi || hoshiState !== 'ready' || state.settings.hoshiChat === 'quiet') return;
  if (!state.nav.showingBrowser || (dubber.active && dubber.isSpeaking())) return;
  const ctx = await hoshiContext();
  if (ctx.paused || ctx.past.length < 3) return;
  if (state.track && ctx.t !== null) {
    const next = state.track.lines.find((l) => l.start > ctx.t);
    if (next && next.start - ctx.t < 4) return;                             // someone is about to speak
  }
  hoshi.react(ctx);
}

function lipSync(analyser) {
  const buf = new Float32Array(analyser.fftSize);
  const tick = () => {
    if (!hoshi.speakingNow) { Object.values(avatars).forEach((a) => a.speak(null)); return; }
    analyser.getFloatTimeDomainData(buf);
    let s = 0;
    for (const v of buf) s += v * v;
    const level = Math.sqrt(s / buf.length) * 3;
    Object.values(avatars).forEach((a) => a.speak(level));
    requestAnimationFrame(tick);
  };
  tick();
}

function bindHoshi() {
  avatars.panel = new HoshiAvatar($('hoshi-panel-avatar'));
  avatars.home = new HoshiAvatar($('hoshi-home-avatar'));
  avatars.peek = new HoshiAvatar($('hoshi-peek-avatar'), { wander: false });
  $('tab-dub').addEventListener('click', () => setTab('dub'));
  $('tab-hoshi').addEventListener('click', () => setTab('hoshi'));
  $('hoshi-peek').addEventListener('click', () => setTab('hoshi'));
  $('home-hoshi').addEventListener('click', () => { setPanel(true); setTab('hoshi'); avatars.home.jump(); $('hoshi-text').focus(); });
  $('hoshi-form').addEventListener('submit', (e) => { e.preventDefault(); const v = $('hoshi-text').value; $('hoshi-text').value = ''; askHoshi(v); });
  $('hoshi-text').addEventListener('input', (e) => avatars.panel.lookAt(0.6, 0.8 * Math.min(1, e.target.value.length / 20)));
  $('hoshi-text').addEventListener('blur', () => avatars.panel.lookAt(0, 0));
  const mic = $('hoshi-mic');
  mic.addEventListener('pointerdown', (e) => { e.preventDefault(); startListening(); });
  mic.addEventListener('pointerup', stopListening);
  mic.addEventListener('pointerleave', stopListening);
  $('hoshi-download').addEventListener('click', () => {
    hoshiDownloading = true;
    $('hoshi-download').disabled = true;
    $('hoshi-progress').hidden = false;
    renderHoshi();
    koe.setup.start(['hoshi']);
  });
  koe.setup.onProgress(({ done, total }) => {
    if (!hoshiDownloading) return;
    $('hoshi-fill').style.width = `${total ? (done / total) * 100 : 0}%`;
    $('hoshi-progress-text').textContent = `${Math.round(done / 1e6)} of ${Math.round(total / 1e6)} MB`;
  });
  koe.setup.onDone(() => { if (hoshiDownloading) { hoshiDownloading = false; toast('Hoshi is downloaded and waking up'); renderHoshi(); } });
  koe.setup.onError(() => { if (hoshiDownloading) { $('hoshi-download').disabled = false; $('hoshi-download').textContent = 'Retry download'; } });

  hoshi.addEventListener('status', ({ detail }) => {
    hoshiState = detail;
    renderHoshi();
    if (detail === 'ready' && (state.settings.panelTab === 'hoshi' || state.page === 'home')) greetOnce();
  });
  hoshi.addEventListener('say', ({ detail: m }) => {
    hoshi.pendingTyping?.remove();
    hoshi.pendingTyping = null;
    if (m.heard) chat(m.heard, 'me');
    if (m.error === 'unheard') { chat("I didn't catch that. Hold the mic a bit longer?", 'them'); return; }
    if (!m.text) { avatars.panel?.set('neutral'); return; }
    chat(m.text, 'them');
    bubble(m.text, m.mood);
  });
  hoshi.addEventListener('speaking', ({ detail }) => { hoshi.speakingNow = true; lipSync(detail.analyser); });
  hoshi.addEventListener('quiet', () => { hoshi.speakingNow = false; });

  // settings
  bindSwitch('set-hoshi', 'hoshi', () => renderHoshi());
  bindRange('set-hoshi-vol', 'set-hoshi-vol-out', 'hoshiVolume', 100, (v) => { hoshi.volume = v; });
  hoshi.volume = state.settings.hoshiVolume;
  const seg = $('set-hoshi-chat');
  const renderSeg = () => seg.querySelectorAll('button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.v === state.settings.hoshiChat)));
  renderSeg();
  seg.addEventListener('click', (e) => {
    const v = e.target.closest('button')?.dataset.v;
    if (!v) return;
    state.settings.hoshiChat = v;
    koe.settings.set('hoshiChat', v);
    renderSeg();
  });
  let armed = false;
  $('set-hoshi-forget').addEventListener('click', (e) => {
    if (!armed) { armed = true; e.currentTarget.textContent = 'Click again to forget'; setTimeout(() => { armed = false; $('set-hoshi-forget').textContent = 'Forget me…'; }, 4000); return; }
    armed = false;
    $('set-hoshi-forget').textContent = 'Forget me…';
    hoshi.forget();
    $('hoshi-chat').replaceChildren();
    toast('Hoshi forgot everything about you');
  });

  koe.page.onInfo((i) => { state.pageInfo = i; });
  setInterval(maybeReact, 15000);
  setTab(state.settings.panelTab === 'hoshi' && state.settings.hoshi ? 'hoshi' : 'dub');
  renderHoshi();
}

// ---------------------------------------------------------------- settings
function bindRange(id, outId, key, scale, apply) {
  const el = $(id);
  el.value = Math.round(state.settings[key] * scale);
  const out = () => { $(outId).textContent = `${el.value}%`; setFill(el); };
  out();
  el.addEventListener('input', () => {
    out();
    const v = Number(el.value) / scale;
    state.settings[key] = v;
    apply?.(v);
    syncTwins(id, el.value);
  });
  el.addEventListener('change', () => koe.settings.set(key, Number(el.value) / scale));
}

// panel and settings page have the same two sliders; keep them in step
const TWINS = { vol: 'set-volume', 'set-volume': 'vol', duck: 'set-duck', 'set-duck': 'duck' };
function syncTwins(id, value) {
  const twin = $(TWINS[id]);
  if (!twin || twin.value === value) return;
  twin.value = value;
  setFill(twin);
  $(`${TWINS[id]}-out`).textContent = `${value}%`;
}

function bindSwitch(id, key, apply) {
  const el = $(id);
  el.checked = state.settings[key];
  el.addEventListener('change', () => {
    state.settings[key] = el.checked;
    koe.settings.set(key, el.checked);
    apply?.(el.checked);
    const twin = { 'cap-switch': 'set-captions', 'set-captions': 'cap-switch' }[id];
    if (twin) $(twin).checked = el.checked;
  });
}

function applyReduceTransparency(on) {
  root.classList.toggle('reduce-transparency', on);
  refreshRefraction();
}

function bindSettings() {
  bindRange('vol', 'vol-out', 'englishVolume', 100, (v) => dubber.setEnglishVolume(v));
  bindRange('set-volume', 'set-volume-out', 'englishVolume', 100, (v) => dubber.setEnglishVolume(v));
  bindRange('duck', 'duck-out', 'duckLevel', 100, (v) => dubber.setDuckLevel(v));
  bindRange('set-duck', 'set-duck-out', 'duckLevel', 100, (v) => dubber.setDuckLevel(v));
  bindSwitch('cap-switch', 'captions', (on) => !on && koe.captions.hide());
  bindSwitch('set-captions', 'captions', (on) => !on && koe.captions.hide());
  bindSwitch('set-reduce', 'reduceTransparency', applyReduceTransparency);
  bindSwitch('set-subs', 'preferSubtitles', () => applyMode());

  const seg = $('set-caption-size');
  const renderSeg = () => seg.querySelectorAll('button').forEach((b) => b.setAttribute('aria-checked', String(b.dataset.v === state.settings.captionSize)));
  renderSeg();
  seg.addEventListener('click', (e) => {
    const v = e.target.closest('button')?.dataset.v;
    if (!v) return;
    state.settings.captionSize = v;
    koe.settings.set('captionSize', v);
    renderSeg();
  });

  let confirmTimer;
  $('set-clear').addEventListener('click', async (e) => {
    const btn = e.currentTarget;
    if (btn.dataset.armed !== '1') {                       // two-step confirm, no modal
      btn.dataset.armed = '1';
      btn.textContent = 'Click again to sign out';
      confirmTimer = setTimeout(() => { btn.dataset.armed = ''; btn.textContent = 'Sign out…'; }, 4000);
      return;
    }
    clearTimeout(confirmTimer);
    btn.dataset.armed = '';
    btn.textContent = 'Sign out…';
    await dubber.stop();
    await koe.browsing.clear();
    toast('Signed out of all sites');
  });
  $('set-logs').addEventListener('click', () => koe.app.openLogs());
}

// ---------------------------------------------------------------- onboarding
function runOnboarding() {
  const dlg = $('onboarding');
  dlg.hidden = false;
  let step = 0;
  const steps = [...dlg.querySelectorAll('.ob-step')];
  const dots = [...$('ob-dots').children];
  const next = $('ob-next');
  next.focus();
  const render = () => {
    steps.forEach((s, i) => { s.hidden = i !== step; });
    dots.forEach((d, i) => d.classList.toggle('on', i === step));
    next.textContent = step === steps.length - 1 ? 'Get started' : 'Continue';
  };
  const finish = () => {
    dlg.hidden = true;
    koe.settings.set('onboarded', true);
    state.settings.onboarded = true;
    if (state.setup && !state.setup.ready && !state.setup.skipped) showSetup();
  };
  next.addEventListener('click', () => { if (step < steps.length - 1) { step++; render(); } else finish(); });
  dlg.addEventListener('keydown', (e) => { if (e.key === 'Escape') finish(); });
  render();
}

// ---------------------------------------------------------------- tooltips (native title tooltips look foreign)
function bindTooltips() {
  const tip = $('tooltip');
  let timer;
  document.addEventListener('pointerover', (e) => {
    const el = e.target.closest('[data-tip]');
    clearTimeout(timer);
    if (!el) { tip.hidden = true; return; }
    timer = setTimeout(() => {
      tip.textContent = el.dataset.tip;
      tip.hidden = false;
      const r = el.getBoundingClientRect();
      const t = tip.getBoundingClientRect();
      const x = Math.min(Math.max(8, r.left + r.width / 2 - t.width / 2), innerWidth - t.width - 8);
      const below = r.bottom + 8 + t.height < innerHeight;
      tip.style.left = `${x}px`;
      tip.style.top = `${below ? r.bottom + 8 : r.top - t.height - 8}px`;
      if (el.closest('.rail')) { tip.style.left = `${r.right + 10}px`; tip.style.top = `${r.top + r.height / 2 - t.height / 2}px`; }
    }, 450);
  });
  document.addEventListener('pointerdown', () => { clearTimeout(timer); tip.hidden = true; });
}

// ---------------------------------------------------------------- wire up
async function init() {
  state.settings = await koe.settings.get();
  root.classList.toggle('reduce-transparency', state.settings.reduceTransparency);

  bindSettings();
  bindTooltips();
  bindPlan();
  bindSetup();
  bindAdblock();
  bindTint();
  bindHoshi();
  state.pageInfo = await koe.page.info();
  renderAdblock(await koe.adblock.state());
  state.license = await koe.license.get();
  renderPlan();
  state.setup = await koe.setup.status();
  renderDownloads();
  setPanel(state.settings.dubPanelOpen);

  $('nav-home').addEventListener('click', () => showPage('home'));
  $('nav-settings').addEventListener('click', () => {
    if (state.page !== 'settings') { state.returnTo = state.page; showPage('settings'); }
    else showPage(state.returnTo === 'browser' ? 'browser' : 'home');
  });
  $('nav-crunchyroll').addEventListener('click', () => open('crunchyroll'));
  $('nav-youtube').addEventListener('click', () => open('youtube'));
  $('tile-crunchyroll').addEventListener('click', () => open('crunchyroll'));
  $('tile-youtube').addEventListener('click', () => open('youtube'));
  if (state.settings.lastUrl) {
    $('tile-continue').hidden = false;
    $('continue-sub').textContent = displayUrl(state.settings.lastUrl);
    $('tile-continue').addEventListener('click', () => go(state.settings.lastUrl));
  }

  $('btn-back').addEventListener('click', () => koe.nav.back());
  $('btn-fwd').addEventListener('click', () => koe.nav.forward());
  $('btn-reload').addEventListener('click', () => (state.nav.loading ? koe.nav.stop() : koe.nav.reload()));
  $('address-form').addEventListener('submit', (e) => { e.preventDefault(); go($('address').value); });
  $('address').addEventListener('focus', (e) => { if (state.nav.showingBrowser) e.target.value = state.nav.url; e.target.select(); });
  $('address').addEventListener('blur', (e) => { e.target.value = state.nav.showingBrowser ? displayUrl(state.nav.url) : ''; });
  $('address').addEventListener('keydown', (e) => { if (e.key === 'Escape') e.target.blur(); });
  $('dub-btn').addEventListener('click', () => toggleDub());
  $('dub-switch').addEventListener('change', (e) => toggleDub(e.target.checked));
  $('btn-panel').addEventListener('click', () => setPanel($('app').dataset.panel !== 'open'));
  $('error-retry').addEventListener('click', () => { showPage('browser'); state.lastError?.url ? koe.nav.go(state.lastError.url) : koe.nav.reload(); });

  koe.nav.onState(renderNav);
  koe.nav.onError((err) => {
    state.lastError = err;
    $('error-title').textContent = err.code === 'drm' ? 'Video protection unavailable' : err.code === 'crashed' ? 'This page stopped working' : "This page didn't load";
    $('error-desc').textContent = err.code === -106 ? "You're offline. Check your internet connection." : err.desc || 'Something went wrong.';
    showPage('error');
  });
  koe.engine.onStatus(renderEngine);
  koe.app.onDubReset(() => { dubber.reset(); stopSync(); });
  koe.subs.onState(async (info) => {
    const had = usingSubs();
    state.subs = info;
    state.track = info ? await koe.subs.get() : null;
    if (usingSubs() && !had && dubber.active) toast('Found English subtitles — switching to the official translation');
    applyMode();
  });
  koe.app.onFullscreen((on) => {
    state.fullscreen = on;
    $('app').classList.toggle('fullscreen', on);
    requestAnimationFrame(reportViewport);
  });
  const shortcut = (name) => {
    if (name === 'toggle-dub') toggleDub();
    else if (name === 'focus-address') $('address').focus();
    else if (name === 'settings') showPage('settings');
    else if (name === 'toggle-panel') setPanel($('app').dataset.panel !== 'open');
  };
  koe.app.onShortcut(shortcut);                  // from the main process (works while the video has focus)
  const KEYS = { d: 'toggle-dub', l: 'focus-address', ',': 'settings', j: 'toggle-panel' };
  document.addEventListener('keydown', (e) => {  // same shortcuts when the UI itself has focus
    const name = (e.ctrlKey || e.metaKey) && KEYS[e.key.toLowerCase()];
    if (name) { e.preventDefault(); shortcut(name); }
  });

  new ResizeObserver(reportViewport).observe($('viewport'));
  window.addEventListener('resize', reportViewport);
  reportViewport();

  renderEngine(await koe.engine.info());
  renderSource();
  renderNav(await koe.nav.state());
  const info = await koe.app.info();
  dubber.muted = info.testMute;
  state.canCheckout = info.canCheckout;
  $('about-version').textContent = `Version ${info.version} · Chromium ${info.chrome.split('.')[0]}`;

  enableRefraction();
  if (!state.settings.onboarded) runOnboarding();
  else if (!state.setup.ready && !state.setup.skipped) showSetup();
  document.body.dataset.ready = '1';
}

init();
