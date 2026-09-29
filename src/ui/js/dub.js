import { DialogueDucker } from './ducker.js';

// Live dub session: player audio → engine (16 kHz over WebSocket) → English speech back → our own mix.
// While dubbing, the player's audio no longer goes straight to the speakers (main sets enableLocalEcho:false);
// we play it here through a gain we can lower whenever English is speaking.

const DUCK_ATTACK = 0.06;    // seconds to fade the Japanese down
const DUCK_RELEASE = 0.25;   // seconds to bring it back

export class Dubber extends EventTarget {
  constructor({ englishVolume = 1, duckLevel = 0.25, muted = false } = {}) {
    super();
    this.muted = muted;            // tests run the full pipeline without making noise
    this.englishVolume = englishVolume;
    this.duckLevel = duckLevel;
    this.active = false;
    this.pendingAudio = null;      // header of the next binary frame
    this.nextStart = 0;            // when the queued English runs out (AudioContext time)
    this.spans = [];               // [start, end] of scheduled English, for ducking
    this.ducked = false;
  }

  emit(type, detail) { this.dispatchEvent(new CustomEvent(type, { detail })); }

  async start(engineInfo) {
    if (this.active) return;
    this.active = true;
    try {
      this.stream = await navigator.mediaDevices.getDisplayMedia({ video: true, audio: true });
      this.stream.getVideoTracks().forEach((t) => t.stop());     // we only ever want the sound
      if (!this.stream.getAudioTracks().length) throw new Error('This page is not playing any audio yet.');

      this.ctx = new AudioContext({ latencyHint: 'interactive' });
      const src = this.ctx.createMediaStreamSource(this.stream);
      this.jp = this.ctx.createGain();
      this.en = this.ctx.createGain();
      this.en.gain.value = this.englishVolume;
      this.master = this.ctx.createGain();
      this.master.gain.value = this.muted ? 0 : 1;
      this.master.connect(this.ctx.destination);
      this.ducker = new DialogueDucker(this.ctx);       // lowers Japanese voices only, never the soundtrack
      src.connect(this.jp).connect(this.ducker.input);
      this.meter = this.ctx.createAnalyser();
      this.meter.fftSize = 2048;
      src.connect(this.meter);
      this.ducker.output.connect(this.master);
      this.en.connect(this.master);

      await this.ctx.audioWorklet.addModule('js/worklet.js');
      this.tap = new AudioWorkletNode(this.ctx, 'pcm-tap', { numberOfOutputs: 1 });
      const sink = this.ctx.createGain();
      sink.gain.value = 0;                                          // keeps the tap pulled, silently
      src.connect(this.tap).connect(sink).connect(this.ctx.destination);

      await this.connect(engineInfo);
      if (this.mode) this.send({ type: 'config', mode: this.mode });
      this.tap.port.onmessage = (e) => { if (this.ws?.readyState === 1) this.ws.send(e.data); };
      this.ticker = setInterval(() => this.tick(), 50);
      this.backlogTimer = setInterval(() => this.sendBacklog(), 1000);
      this.emit('state', { active: true });
    } catch (e) {
      await this.stop();
      throw e;
    }
  }

  connect({ port, token }) {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(`ws://127.0.0.1:${port}/?token=${token}`);
      ws.binaryType = 'arraybuffer';
      const timer = setTimeout(() => reject(new Error('The dubbing engine did not answer.')), 5000);
      ws.onopen = () => { clearTimeout(timer); this.ws = ws; resolve(); };
      ws.onerror = () => { clearTimeout(timer); reject(new Error('Could not reach the dubbing engine.')); };
      ws.onclose = () => { if (this.active) { this.emit('error', 'Lost connection to the dubbing engine.'); this.stop(); } };
      ws.onmessage = (e) => this.onMessage(e.data);
    });
  }

  onMessage(data) {
    if (data instanceof ArrayBuffer) {
      const head = this.pendingAudio;
      this.pendingAudio = null;
      if (head) this.play(head, new Float32Array(data));
      return;
    }
    const msg = JSON.parse(data);
    if (msg.type === 'audio') this.pendingAudio = msg;
    else if (msg.type === 'line') this.lines.set(msg.id, msg);
    else if (msg.type === 'status') this.emit('engine', msg);
  }

  lines = new Map();

  play(head, pcm) {
    const fade = Math.min(Math.floor(head.sr * 0.008), pcm.length >> 2);   // 8 ms fades: no clicks
    for (let i = 0; i < fade; i++) { const g = i / fade; pcm[i] *= g; pcm[pcm.length - 1 - i] *= g; }
    const buf = this.ctx.createBuffer(1, pcm.length, head.sr);
    buf.copyToChannel(pcm, 0);
    const node = this.ctx.createBufferSource();
    node.buffer = buf;
    const backlog = Math.max(0, this.nextStart - this.ctx.currentTime);
    node.playbackRate.value = backlog > 4 ? 1.12 : 1;               // quietly catch up if we fall behind
    node.connect(this.en);
    const start = Math.max(this.ctx.currentTime + 0.03, this.nextStart);
    const dur = buf.duration / node.playbackRate.value;
    node.start(start);
    this.nextStart = start + dur + 0.08;
    this.spans.push([start, start + dur]);
    const line = this.lines.get(head.id);
    this.lines.delete(head.id);
    const delay = Math.max(0, (start - this.ctx.currentTime) * 1000);
    setTimeout(() => this.emit('line', { ...line, duration: dur }), delay);
  }

  tick() {
    const now = this.ctx.currentTime;
    this.spans = this.spans.filter(([, end]) => end > now - 1);
    const speaking = this.spans.some(([s, e]) => now >= s - DUCK_ATTACK && now <= e);
    if (speaking !== this.ducked) {
      this.ducked = speaking;
      this.ducker.duck(speaking ? this.duckLevel : 1, now, (speaking ? DUCK_ATTACK : DUCK_RELEASE) / 3);
      this.emit('speaking', speaking);
    }
  }

  sendBacklog() {
    if (this.ws?.readyState !== 1) return;
    const seconds = Math.max(0, this.nextStart - this.ctx.currentTime);
    this.ws.send(JSON.stringify({ type: 'backlog', seconds: Math.round(seconds * 10) / 10 }));
  }

  reset() {
    this.send({ type: 'reset' });
  }

  // how loud the show is right now, 0..1 (Hoshi reads it as scene energy)
  energy() {
    if (!this.meter) return 0;
    const buf = new Float32Array(this.meter.fftSize);
    this.meter.getFloatTimeDomainData(buf);
    let s = 0;
    for (const v of buf) s += v * v;
    return Math.min(1, Math.sqrt(s / buf.length) * 5);
  }

  isSpeaking() { return this.active && this.spans.some(([, e]) => e > this.ctx.currentTime - 3); }

  send(msg) {
    if (this.ws?.readyState === 1) this.ws.send(JSON.stringify(msg));
  }

  // 'subs': speak the site's own subtitle lines (say()); 'listen': translate by ear
  setMode(mode) {
    this.mode = mode;
    this.send({ type: 'config', mode });
  }

  prepare(id, text, dur, speaker = '') {
    this.send({ type: 'prepare', id, text, dur, speaker });
  }

  say(id, text, dur, speaker = '') {
    this.send({ type: 'say', id, text, dur, speaker });
  }

  setEnglishVolume(v) {
    this.englishVolume = v;
    if (this.en) this.en.gain.setTargetAtTime(v, this.ctx.currentTime, 0.03);
  }

  setDuckLevel(v) {
    this.duckLevel = v;
    if (this.ducked && this.ducker) this.ducker.duck(v);
  }

  async stop() {
    const was = this.active;
    this.active = false;
    clearInterval(this.ticker);
    clearInterval(this.backlogTimer);
    try { this.ws?.close(); } catch { /* already closed */ }
    this.ws = null;
    this.stream?.getTracks().forEach((t) => t.stop());   // ends capture: the player's own audio returns
    this.stream = null;
    try { await this.ctx?.close(); } catch { /* closed */ }
    this.ctx = null;
    this.spans = [];
    this.nextStart = 0;
    this.ducked = false;
    this.lines.clear();
    if (was) this.emit('state', { active: false });
  }
}
