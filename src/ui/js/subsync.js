// Follows the video's clock and hands each subtitle line to the dubber the moment it comes up.
// Handles pause, seeking both ways, and playback speed; each line is spoken at most once per pass.

export class SubtitleSync {
  constructor({ lines, getState, onLine, onPrepare = () => {}, interval = 120, lookahead = 6 }) {
    this.lines = lines;
    this.getState = getState;
    this.onLine = onLine;
    this.onPrepare = onPrepare;     // lines coming up soon, so their audio can be rendered in advance
    this.lookahead = lookahead;
    this.prepared = new Set();
    this.interval = interval;
    this.said = new Set();
    this.lastT = null;
    this.timer = null;
    this.busy = false;
  }

  start() {
    this.timer = setInterval(() => this.tick(), this.interval);
  }

  stop() {
    clearInterval(this.timer);
    this.timer = null;
  }

  async tick() {
    if (this.busy) return;
    this.busy = true;
    try {
      const s = await this.getState();
      if (s) this.advance(s);
    } finally {
      this.busy = false;
    }
  }

  // pure step, unit-testable: given the player state, emit the lines that just started
  advance({ t, paused, rate = 1 }) {
    const jumped = this.lastT !== null && (t < this.lastT - 0.5 || t > this.lastT + 3);
    if (jumped) {
      // after a seek, forget lines ahead of us (so rewinding replays them) and never burst-play skipped ones
      for (const i of [...this.said]) if (this.lines[i].start >= t - 0.2) this.said.delete(i);
      for (const i of [...this.prepared]) if (this.lines[i].start >= t - 0.2) this.prepared.delete(i);
    }
    const from = this.lastT === null || jumped ? t - 0.35 : this.lastT - 0.05;
    this.lastT = t;
    for (let i = this.firstAfter(t); i < this.lines.length && this.lines[i].start <= t + this.lookahead; i++) {
      if (this.prepared.has(i)) continue;
      this.prepared.add(i);
      this.onPrepare(i, this.lines[i].text, (this.lines[i].end - this.lines[i].start) / (rate || 1), this.lines[i].speaker || '');
    }
    if (paused) return [];
    const due = [];
    for (let i = this.firstAfter(from); i < this.lines.length && this.lines[i].start <= t; i++) {
      const l = this.lines[i];
      if (this.said.has(i) || t - l.start > 0.8) continue;   // too late to start this one naturally
      this.said.add(i);
      due.push(i);
      this.onLine(i, l.text, (l.end - l.start) / (rate || 1), l.speaker || '');
    }
    return due;
  }

  firstAfter(time) {
    let lo = 0, hi = this.lines.length;
    while (lo < hi) {
      const mid = (lo + hi) >> 1;
      if (this.lines[mid].start < time) lo = mid + 1; else hi = mid;
    }
    return lo;
  }
}
