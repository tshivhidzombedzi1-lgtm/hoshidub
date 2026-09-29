// Starts and supervises the Python dubbing engine. Restarts it (with backoff) if it crashes.
const { spawn } = require('child_process');
const crypto = require('crypto');
const EventEmitter = require('events');
const fs = require('fs');
const net = require('net');
const path = require('path');
const readline = require('readline');
const log = require('./log');

const ROOT = path.resolve(__dirname, '..', '..');            // koe/
const DEFAULT_PYTHON = path.resolve(ROOT, '..', '.venv', 'Scripts', 'python.exe');
const SCRIPT = path.join(ROOT, 'engine', 'koe_engine.py');

function freePort() {
  return new Promise((resolve, reject) => {
    const srv = net.createServer();
    srv.unref();
    srv.on('error', reject);
    srv.listen(0, '127.0.0.1', () => {
      const { port } = srv.address();
      srv.close(() => resolve(port));
    });
  });
}

class Engine extends EventEmitter {
  constructor() {
    super();
    this.python = process.env.KOE_PYTHON || DEFAULT_PYTHON;
    this.token = crypto.randomBytes(24).toString('hex');
    this.port = null;
    this.proc = null;
    this.status = { state: 'loading', detail: 'starting engine' };
    this.restarts = 0;
    this.stopping = false;
  }

  info() {
    return { port: this.port, token: this.token, ...this.status };
  }

  setStatus(state, detail) {
    this.status = { state, detail };
    this.emit('status', this.info());
  }

  async start() {
    if (process.env.KOE_ENGINE === 'off') {
      this.setStatus('off', 'engine disabled');
      return;
    }
    if (!fs.existsSync(this.python) || !fs.existsSync(SCRIPT)) {
      this.setStatus('error', 'Dubbing engine not installed');
      log.error('engine missing', { python: this.python, script: SCRIPT });
      return;
    }
    this.port = await freePort();
    this.setStatus('loading', 'starting engine');
    const started = Date.now();
    const proc = spawn(this.python, [SCRIPT, '--port', String(this.port), '--token', this.token], {
      cwd: path.dirname(SCRIPT),
      windowsHide: true,
      env: { ...process.env, PYTHONUNBUFFERED: '1', PYTHONIOENCODING: 'utf-8', HF_HUB_DISABLE_XET: '1' },
    });
    this.proc = proc;
    // every handler checks it still belongs to the current process, so a stopped engine can't talk over a new one
    readline.createInterface({ input: proc.stdout }).on('line', (line) => {
      if (this.proc !== proc) return;
      let msg;
      try { msg = JSON.parse(line); } catch { return; }
      if (msg.type === 'status') {
        if (msg.state === 'ready') {
          this.restarts = 0;
          log.info('engine ready', { detail: msg.detail, ms: Date.now() - started });
        }
        this.setStatus(msg.state, msg.detail);
      } else if (msg.type === 'log') {
        log.warn('engine', { msg: msg.msg });
      }
    });
    let stderrTail = '';
    proc.stderr.on('data', (d) => { stderrTail = (stderrTail + d).slice(-2000); });
    proc.on('exit', (code) => {
      if (this.proc !== proc) return;          // replaced by a restart
      this.proc = null;
      if (this.stopping) return;
      log.error('engine exited', { code, stderr: stderrTail.slice(-600) });
      if (this.restarts < 3) {
        this.restarts += 1;
        const wait = 1000 * 2 ** this.restarts;
        this.setStatus('loading', 'Restarting the dubbing engine…');
        setTimeout(() => this.start(), wait);
      } else {
        this.setStatus('error', 'The dubbing engine keeps stopping. See the log for details.');
      }
    });
  }

  async restart() {
    this.stop();
    this.stopping = false;
    this.restarts = 0;
    await this.start();
  }

  stop() {
    this.stopping = true;
    if (this.proc) {
      this.proc.kill();
      this.proc = null;
    }
  }
}

module.exports = { Engine };
