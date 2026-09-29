// First-run setup: which model packs are installed, and downloading missing ones with progress.
// The work happens in engine/packs.py (same Python runtime as the engine); this side just runs it.
const { spawn } = require('child_process');
const EventEmitter = require('events');
const path = require('path');
const readline = require('readline');
const log = require('./log');

const fs = require('fs');
const paths = require('./paths');
const { Runtime } = require('./runtime');

const PACKS_SCRIPT = path.join(paths.engineDir(), 'packs.py');
const REQUIRED = ['core', 'voices-en'];

class Setup extends EventEmitter {
  constructor(python) {
    super();
    this.python = python;
    this.status = null;
    this.running = null;
    this.runtime = new Runtime({ dir: paths.RUNTIME_DIR, downloads: `${paths.RUNTIME_DIR}.download`, base: paths.runtimeBase() });
  }

  hasRuntime() { return fs.existsSync(this.python); }

  run(args) {
    return spawn(this.python, [PACKS_SCRIPT, ...args], {
      cwd: path.dirname(PACKS_SCRIPT), windowsHide: true,
      env: { ...process.env, PYTHONUNBUFFERED: '1', HF_HUB_DISABLE_XET: '1' },
    });
  }

  check() {
    if (process.env.KOE_ENGINE === 'off') {
      this.status = { skipped: true, packs: {}, sizes_mb: {}, gpu: {}, ready: true };
      return Promise.resolve(this.status);
    }
    if (!this.hasRuntime()) {                 // installed copy on a fresh PC: nothing can run until the runtime arrives
      return this.runtime.manifest().then(
        (m) => (this.status = { runtime: false, packs: {}, gpu: {}, ready: false,
          sizes_mb: { runtime: Math.round(m.total / 1e6), core: 330, 'voices-en': 6, ear: 3090 } }),
        () => this.fail('Otodub couldn\'t reach its download server. Check your internet connection and reopen the app.'),
      );
    }
    return new Promise((resolve) => {
      let out = '';
      const p = this.run([]);
      p.stdout.on('data', (d) => { out += d; });
      p.on('error', () => resolve(this.fail('Otodub\'s dubbing runtime is missing. Reinstall the app.')));
      p.on('exit', () => {
        try {
          const s = JSON.parse(out.trim().split('\n').pop());
          s.runtime = true;
          s.ready = REQUIRED.every((k) => s.packs[k]);
          this.status = s;
          resolve(s);
        } catch {
          resolve(this.fail('Couldn\'t check the downloaded voices.'));
        }
      });
    });
  }

  fail(error) {
    this.status = { error, packs: {}, sizes_mb: {}, gpu: {}, ready: false };
    return this.status;
  }

  // download packs; emits progress {done,total}, done, and error events
  start(packs) {
    if (this.running) return false;
    if (!this.hasRuntime()) {                 // runtime first, then the model packs, as one continuous download
      this.running = true;
      const sizes = this.status?.sizes_mb || {};
      const later = (sizes.core || 0) + (sizes['voices-en'] || 0) + (packs.includes('ear') ? sizes.ear || 0 : 0);
      this.runtime.install((p) => this.emit('progress', { ...p, total: p.total + later * 1e6 }))
        .then(async () => {
          this.python = this.runtime.python();
          this.emit('runtime', this.python);
          this.running = null;
          await this.check();
          this.start(packs);
        })
        .catch((e) => { this.running = null; log.error('runtime install failed', { err: e.message }); this.emit('error', e.message); });
      return true;
    }
    const wanted = [...new Set([...REQUIRED.filter((k) => !this.status?.packs?.[k]), ...packs])];
    if (!wanted.length) {                     // everything is already on disk
      this.check().then((s) => this.emit('done', s));
      return true;
    }
    log.info('setup started', { packs: wanted });
    const p = this.run(['--setup', wanted.join(',')]);
    this.running = p;
    let failed = null;
    readline.createInterface({ input: p.stdout }).on('line', (line) => {
      let m;
      try { m = JSON.parse(line); } catch { return; }
      if (m.type === 'progress') this.emit('progress', { done: m.done, total: m.total, pack: m.pack });
      else if (m.type === 'setup-error') failed = m.error;
    });
    p.on('exit', async (code) => {
      this.running = null;
      if (code === 0) {
        await this.check();
        log.info('setup finished', { packs: wanted });
        this.emit('done', this.status);
      } else {
        log.error('setup failed', { error: failed, code });
        this.emit('error', failed && /urlopen|timed out|getaddrinfo|10060|10054/i.test(failed)
          ? 'The download was interrupted. Check your internet connection, then press Retry. It will continue where it stopped.'
          : 'The download didn\'t finish. Press Retry to continue where it stopped.');
      }
    });
    return true;
  }
}

module.exports = { Setup, REQUIRED };
