// Tiny JSON settings store with atomic writes (write temp, then rename) so a crash never corrupts it.
const fs = require('fs');
const path = require('path');

const DEFAULTS = {
  onboarded: false,
  window: { width: 1360, height: 860, x: undefined, y: undefined, maximized: false },
  englishVolume: 1.0,      // 0..1.5
  duckLevel: 0.25,         // Japanese volume while English speaks, 0..1
  captions: true,
  captionSize: 'medium',   // small | medium | large
  dubPanelOpen: true,
  reduceTransparency: false,
  preferSubtitles: true,
  adblock: true,           // block ads and trackers in the built-in browser
  adblockAllow: null,      // sites where blocking is off (null = the default list)   // speak the site's own English subtitles when it has them
  lastUrl: '',
};

class Store {
  constructor(dir) {
    this.file = path.join(dir, 'settings.json');
    this.data = structuredClone(DEFAULTS);
    try {
      const saved = JSON.parse(fs.readFileSync(this.file, 'utf8'));
      this.data = { ...this.data, ...saved, window: { ...DEFAULTS.window, ...(saved.window || {}) } };
    } catch { /* first run or unreadable: defaults */ }
    this.timer = null;
  }

  get(key) { return this.data[key]; }

  all() { return structuredClone(this.data); }

  set(key, value) {
    if (!(key in DEFAULTS)) throw new Error(`unknown setting: ${key}`);
    this.data[key] = value;
    this.saveSoon();
  }

  saveSoon() {
    clearTimeout(this.timer);
    this.timer = setTimeout(() => this.saveNow(), 300);
  }

  saveNow() {
    clearTimeout(this.timer);
    const tmp = this.file + '.tmp';
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    fs.writeFileSync(tmp, JSON.stringify(this.data, null, 2));
    fs.renameSync(tmp, this.file);
  }
}

module.exports = { Store, DEFAULTS };
