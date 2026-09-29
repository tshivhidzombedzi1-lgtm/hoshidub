// Hoshi's avatar: an original animated character drawn in SVG (owned by Dub It / MCP Labs).
// Idle life (float, blink, sway, wander), expressions, lip-sync from her voice, jumps and waves.

const MOUTHS = {
  neutral: 'M92 142 Q100 146 108 142',
  smile: 'M88 139 Q100 152 112 139',
  open: 'M90 139 Q100 158 110 139 Q100 146 90 139 Z',
  talk: 'M91 140 Q100 150 109 140 Q100 144 91 140 Z',
  o: 'M100 137 m-6 6 a6 7 0 1 0 12 0 a6 7 0 1 0 -12 0',
  frown: 'M90 147 Q100 139 110 147',
};

export function avatarSVG(id) {
  return `
<svg class="hoshi-svg" viewBox="0 0 200 240" role="img" aria-label="Hoshi">
  <defs>
    <linearGradient id="${id}-hair" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#ff8fc0"/><stop offset="0.6" stop-color="#c38bff"/><stop offset="1" stop-color="#8f7bff"/>
    </linearGradient>
    <radialGradient id="${id}-iris" cx="0.5" cy="0.35" r="0.7">
      <stop offset="0" stop-color="#ff9ad5"/><stop offset="0.55" stop-color="#8a5cff"/><stop offset="1" stop-color="#3d2a8c"/>
    </radialGradient>
    <linearGradient id="${id}-hood" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#3b3355"/><stop offset="1" stop-color="#231e36"/>
    </linearGradient>
  </defs>
  <g class="h-body">
    <g class="h-tail h-tail-l"><path d="M44 96 C10 120 18 190 40 214 C44 180 52 140 62 112 Z" fill="url(#${id}-hair)"/></g>
    <g class="h-tail h-tail-r"><path d="M156 96 C190 120 182 190 160 214 C156 180 148 140 138 112 Z" fill="url(#${id}-hair)"/></g>
    <path d="M52 238 C52 196 74 176 100 176 C126 176 148 196 148 238 Z" fill="url(#${id}-hood)"/>
    <path d="M86 180 L92 206 M114 180 L108 206" stroke="#f5f0ff" stroke-width="2.4" stroke-linecap="round"/>
    <g class="h-logo" fill="#fff" opacity="0.92">
      <rect x="86" y="212" width="4" height="8" rx="2"/><rect x="93" y="207" width="4" height="18" rx="2"/>
      <rect x="100" y="203" width="4" height="26" rx="2"/><rect x="107" y="208" width="4" height="16" rx="2"/>
      <rect x="114" y="212" width="4" height="8" rx="2" opacity="0.8"/>
    </g>
    <g class="h-hand h-hand-l"><circle cx="58" cy="214" r="9" fill="#ffe4d6"/></g>
    <g class="h-hand h-hand-r"><circle cx="142" cy="214" r="9" fill="#ffe4d6"/></g>
    <g class="h-head">
      <path d="M40 104 C38 50 70 34 100 34 C130 34 162 50 160 104 C160 124 150 150 100 170 C50 150 40 124 40 104 Z" fill="url(#${id}-hair)"/>
      <ellipse cx="100" cy="116" rx="52" ry="50" fill="#ffe9dc"/>
      <ellipse class="h-blush" cx="70" cy="132" rx="9" ry="5" fill="#ff8fb0" opacity="0.45"/>
      <ellipse class="h-blush" cx="130" cy="132" rx="9" ry="5" fill="#ff8fb0" opacity="0.45"/>
      <g class="h-eye h-eye-l">
        <ellipse cx="78" cy="116" rx="11" ry="14" fill="#2a1f45"/>
        <ellipse class="h-iris" cx="78" cy="118" rx="9" ry="11.5" fill="url(#${id}-iris)"/>
        <circle cx="74" cy="111" r="3.6" fill="#fff"/><circle cx="82" cy="123" r="1.6" fill="#fff" opacity="0.85"/>
      </g>
      <g class="h-eye h-eye-r">
        <ellipse cx="122" cy="116" rx="11" ry="14" fill="#2a1f45"/>
        <ellipse class="h-iris" cx="122" cy="118" rx="9" ry="11.5" fill="url(#${id}-iris)"/>
        <circle cx="118" cy="111" r="3.6" fill="#fff"/><circle cx="126" cy="123" r="1.6" fill="#fff" opacity="0.85"/>
      </g>
      <path class="h-happy" d="M68 118 Q78 106 88 118 M112 118 Q122 106 132 118" stroke="#2a1f45" stroke-width="3.5" fill="none" stroke-linecap="round"/>
      <path class="h-brow h-brow-l" d="M68 96 Q78 91 88 95" stroke="#6b4a8f" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path class="h-brow h-brow-r" d="M112 95 Q122 91 132 96" stroke="#6b4a8f" stroke-width="3" fill="none" stroke-linecap="round"/>
      <path class="h-mouth" d="${MOUTHS.smile}" fill="#c2415f" stroke="#8c2a44" stroke-width="2" stroke-linecap="round"/>
      <path class="h-tear" d="M131 124 C127 132 129 138 133 138 C137 138 138 132 131 124 Z" fill="#8fd3ff"/>
      <path d="M44 100 C50 60 76 48 100 50 C124 48 150 60 156 100 C146 86 138 80 128 78 L124 92 L116 78 L106 90 L100 76 L92 90 L84 78 L76 92 L72 78 C62 80 54 86 44 100 Z" fill="url(#${id}-hair)"/>
      <path class="h-star" d="M62 70 l3.5 7.2 7.9 1.1 -5.7 5.6 1.4 7.8 -7.1-3.7 -7.1 3.7 1.4-7.8 -5.7-5.6 7.9-1.1 z" fill="#ffd35c" stroke="#e6a92a" stroke-width="1.2"/>
      <path class="h-star" d="M140 66 l2.8 5.8 6.3 .9 -4.6 4.5 1.1 6.3 -5.6-3 -5.6 3 1.1-6.3 -4.6-4.5 6.3-.9 z" fill="#ffd35c" stroke="#e6a92a" stroke-width="1.2"/>
    </g>
  </g>
  <g class="h-spark" fill="#ffd35c">
    <path d="M22 60 l2 5 5 2 -5 2 -2 5 -2-5 -5-2 5-2z"/><path d="M178 50 l2 5 5 2 -5 2 -2 5 -2-5 -5-2 5-2z"/>
    <path d="M170 140 l1.5 4 4 1.5 -4 1.5 -1.5 4 -1.5-4 -4-1.5 4-1.5z"/>
  </g>
</svg>`;
}

export class HoshiAvatar {
  constructor(el, { wander = true } = {}) {
    this.el = el;
    this.el.innerHTML = avatarSVG(`h${Math.random().toString(36).slice(2, 7)}`);
    this.svg = el.querySelector('svg');
    this.mouth = el.querySelector('.h-mouth');
    this.irises = [...el.querySelectorAll('.h-iris')];
    this.expr = 'happy-idle';
    this.talking = false;
    this.wander = wander;
    this.timers = [];
    this.reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
    this.set('neutral');
    this.blinkLoop();
    if (wander) this.wanderLoop();
  }

  set(expression) {
    this.expr = expression;
    this.el.dataset.expr = expression;
    if (!this.talking) this.mouth.setAttribute('d', MOUTHS[{ happy: 'smile', surprised: 'o', sad: 'frown', thinking: 'neutral', hype: 'open' }[expression] || 'smile']);
  }

  mood(mood) {
    this.set({ hype: 'hype', sad: 'sad', funny: 'happy', tense: 'surprised', calm: 'neutral' }[mood] || 'neutral');
    if (mood === 'hype' || mood === 'funny') this.jump();
  }

  blinkLoop() {
    const t = setTimeout(() => {
      this.el.classList.add('blink');
      setTimeout(() => this.el.classList.remove('blink'), 140);
      this.blinkLoop();
    }, 2500 + Math.random() * 3500);
    this.timers.push(t);
  }

  wanderLoop() {
    const t = setTimeout(() => {
      if (!this.reduced && !this.talking) {
        const x = Math.round((Math.random() * 2 - 1) * 28);           // percent of the stage
        const prev = Number(this.el.style.getPropertyValue('--x').replace('%', '') || 0);
        this.el.style.setProperty('--x', `${x}%`);
        this.el.style.setProperty('--face', x < prev ? '-1' : '1');
      }
      this.wanderLoop();
    }, 5000 + Math.random() * 5000);
    this.timers.push(t);
  }

  jump() {
    if (this.reduced) return;
    this.el.classList.remove('jump');
    void this.el.offsetWidth;                                       // restart the animation
    this.el.classList.add('jump');
  }

  wave() {
    this.el.classList.add('wave');
    setTimeout(() => this.el.classList.remove('wave'), 1800);
  }

  lookAt(dx, dy) {                                                   // -1..1, towards what she's watching
    for (const i of this.irises) i.style.transform = `translate(${dx * 2.5}px, ${dy * 2}px)`;
  }

  // lip-sync: amplitude 0..1 from her voice, called every animation frame while she speaks
  speak(level) {
    this.talking = level !== null;
    if (level === null) { this.set(this.expr); return; }
    this.mouth.setAttribute('d', level > 0.08 ? (level > 0.22 ? MOUTHS.open : MOUTHS.talk) : MOUTHS.smile);
  }

  destroy() { this.timers.forEach(clearTimeout); }
}

// ---------------------------------------------------------------- talking to her through the engine
export class HoshiClient extends EventTarget {
  constructor() {
    super();
    this.ws = null;
    this.pending = null;
    this.nextId = 1;
    this.volume = 1;
    this.ctx = null;
  }

  emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }

  connect({ port, token }) {
    if (this.ws && this.ws.readyState <= 1) return;
    const ws = new WebSocket(`ws://127.0.0.1:${port}/?token=${token}`);
    ws.binaryType = 'arraybuffer';
    ws.onmessage = (e) => this.onMessage(e.data);
    ws.onclose = () => { this.ws = null; this.emit('status', 'offline'); };
    this.ws = ws;
  }

  send(msg) {
    if (this.ws?.readyState !== 1) return false;
    this.ws.send(JSON.stringify(msg));
    return true;
  }

  ask(text, ctx) { const id = this.nextId++; this.send({ type: 'buddy-ask', id, text, ctx }); return id; }
  react(ctx) { const id = this.nextId++; this.send({ type: 'buddy-react', id, ctx }); return id; }
  hello() { this.send({ type: 'buddy-hello', id: this.nextId++ }); }
  forget() { this.send({ type: 'buddy-forget' }); }

  voice(pcm, ctx) {
    const bytes = new Uint8Array(pcm.buffer);
    let bin = '';
    for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    const id = this.nextId++;
    this.send({ type: 'buddy-voice', id, pcm: btoa(bin), ctx });
    return id;
  }

  onMessage(data) {
    if (data instanceof ArrayBuffer) {
      const head = this.pending;
      this.pending = null;
      if (head) this.play(head, new Float32Array(data));
      return;
    }
    const m = JSON.parse(data);
    if (m.type === 'buddy-status') this.emit('status', m.state);
    else if (m.type === 'buddy-say') this.emit('say', m);
    else if (m.type === 'buddy-audio') this.pending = m;
  }

  play(head, pcm) {
    this.ctx ||= new AudioContext();
    const buf = this.ctx.createBuffer(1, pcm.length, head.sr);
    buf.copyToChannel(pcm, 0);
    const src = this.ctx.createBufferSource();
    const gain = this.ctx.createGain();
    const an = this.ctx.createAnalyser();
    an.fftSize = 512;
    gain.gain.value = this.volume;
    src.buffer = buf;
    src.connect(an).connect(gain).connect(this.ctx.destination);
    src.start();
    this.emit('speaking', { id: head.id, analyser: an, duration: buf.duration });
    src.onended = () => this.emit('quiet', head.id);
  }
}
