// First-run setup: which model packs are installed, and downloading missing ones with progress.
// The work happens in engine/packs.py (same Python runtime as the engine); this side just runs it.
const { spawn } = require('child_process');
const EventEmitter = require('events');
const path = require('path');
const readline = require('readline');
const log = require('./log');

const PACKS_SCRIPT = path.resolve(__dirname, '..', '..', 'engine', 'packs.py');
const REQUIRED = ['core', 'voices-en'];

class Setup extends EventEmitter {
  constructor(python) {
    super();
    this.python = python;
    this.status = null;
    this.running = null;
  }

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
    return new Promise((resolve) => {
      let out = '';
      const p = this.run([]);
      p.stdout.on('data', (d) => { out += d; });
      p.on('error', () => resolve(this.fail('Dub It\'s dubbing runtime is missing. Reinstall the app.')));
      p.on('exit', () => {
        try {
          const s = JSON.parse(out.trim().split('\n').pop());
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
    const wanted = [...new Set([...REQUIRED.filter((k) => !this.status?.packs?.[k]), ...packs])];
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
