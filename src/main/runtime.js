// Downloads and installs the Python runtime pack on first run: resumable parts, SHA-256 checked, then unzipped.
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');
const { Readable } = require('stream');
const { pipeline } = require('stream/promises');

const WINDOWS_TAR = path.join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'tar.exe');

class Runtime {
  constructor({ dir, downloads, base }) {
    this.dir = dir;                    // final install folder (contains python.exe)
    this.downloads = downloads;        // where parts are kept until verified
    this.base = (base || '').replace(/\/$/, '');
  }

  python() { return path.join(this.dir, 'python.exe'); }

  installedVersion() {
    try { return JSON.parse(fs.readFileSync(path.join(this.dir, 'dubit-runtime.json'), 'utf8')).version; } catch { return null; }
  }

  async manifest() {
    if (!this.base) throw new Error('No runtime download location is configured.');
    const res = await fetch(`${this.base}/manifest.json`, { signal: AbortSignal.timeout(20000) });
    if (!res.ok) throw new Error(`Runtime manifest unavailable (${res.status}).`);
    return res.json();
  }

  async downloadPart(part, onBytes) {
    const file = path.join(this.downloads, part.name);
    let have = fs.existsSync(file) ? fs.statSync(file).size : 0;
    if (have > part.size) { fs.rmSync(file); have = 0; }
    if (have < part.size) {
      const res = await fetch(`${this.base}/${part.name}`, { headers: have ? { Range: `bytes=${have}-` } : {} });
      if (!res.ok) throw new Error(`Download failed (${res.status}).`);
      if (have && res.status !== 206) { fs.rmSync(file); have = 0; }       // server ignored the range
      onBytes(have);
      const counter = new (require('stream').Transform)({
        transform(chunk, _enc, cb) { onBytes(chunk.length); cb(null, chunk); },
      });
      await pipeline(Readable.fromWeb(res.body), counter, fs.createWriteStream(file, { flags: have ? 'a' : 'w' }));
    } else {
      onBytes(part.size);
    }
    const hash = crypto.createHash('sha256');
    await pipeline(fs.createReadStream(file), hash);
    if (hash.digest('hex') !== part.sha256) {
      fs.rmSync(file);                  // corrupted or tampered: never unpack it
      throw new Error('A download was damaged. Press Retry to fetch it again.');
    }
    return file;
  }

  // onProgress({ phase: 'download' | 'unpack', done, total })
  async install(onProgress = () => {}) {
    const m = await this.manifest();
    fs.mkdirSync(this.downloads, { recursive: true });
    let done = 0;
    const files = [];
    for (const part of m.parts) {
      files.push(await this.downloadPart(part, (n) => { done += n; onProgress({ phase: 'download', done, total: m.total }); }));
    }
    onProgress({ phase: 'unpack', done: m.total, total: m.total });
    const zip = path.join(this.downloads, 'runtime.zip');
    const out = fs.createWriteStream(zip);
    for (const f of files) await pipeline(fs.createReadStream(f), out, { end: false });
    out.end();
    await new Promise((r) => out.on('close', r));

    const staging = `${this.dir}.new`;
    fs.rmSync(staging, { recursive: true, force: true });
    fs.mkdirSync(staging, { recursive: true });
    await new Promise((resolve, reject) => {
      // Windows 10+ ships bsdtar, which unpacks zip. Use it by full path: a Git install puts GNU tar
      // (which can't read zip) earlier on PATH.
      execFile(WINDOWS_TAR, ['-xf', zip, '-C', staging], { windowsHide: true, maxBuffer: 1 << 20 }, (err) => (err ? reject(err) : resolve()));
    });
    fs.rmSync(this.dir, { recursive: true, force: true });
    fs.renameSync(staging, this.dir);
    fs.rmSync(this.downloads, { recursive: true, force: true });
    return this.installedVersion();
  }
}

module.exports = { Runtime, WINDOWS_TAR };
