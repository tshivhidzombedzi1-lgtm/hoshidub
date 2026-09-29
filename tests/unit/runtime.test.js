// The runtime installer against a local server: multi-part download, resume, checksum, unzip.
const test = require('node:test');
const assert = require('node:assert');
const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { Runtime, WINDOWS_TAR } = require('../../src/main/runtime');

function makePack() {
  const src = fs.mkdtempSync(path.join(os.tmpdir(), 'rt-src-'));
  fs.writeFileSync(path.join(src, 'python.exe'), 'not really python');
  fs.writeFileSync(path.join(src, 'dubit-runtime.json'), JSON.stringify({ version: '7' }));
  fs.mkdirSync(path.join(src, 'Lib'));
  fs.writeFileSync(path.join(src, 'Lib', 'big.bin'), crypto.randomBytes(300_000));
  const zip = path.join(os.tmpdir(), `rt-${Date.now()}.zip`);
  execFileSync(WINDOWS_TAR, ['-a', '-cf', zip, '-C', src, '.']);
  const bytes = fs.readFileSync(zip);
  const cut = Math.floor(bytes.length / 2);
  const parts = [bytes.subarray(0, cut), bytes.subarray(cut)].map((b, i) => ({
    name: `runtime.zip.00${i + 1}`, size: b.length, sha256: crypto.createHash('sha256').update(b).digest('hex'), data: b,
  }));
  return { parts, total: bytes.length };
}

function serve(pack, { corruptSecond = false } = {}) {
  const srv = http.createServer((req, res) => {
    if (req.url === '/manifest.json') {
      res.end(JSON.stringify({ version: '7', total: pack.total, parts: pack.parts.map(({ data, ...p }) => p) }));
      return;
    }
    const part = pack.parts.find((p) => req.url === `/${p.name}`);
    if (!part) { res.statusCode = 404; return res.end(); }
    let data = part.data;
    if (corruptSecond && part.name.endsWith('002')) { data = Buffer.from(data); data[10] ^= 0xff; }
    const m = /bytes=(\d+)-/.exec(req.headers.range || '');
    if (m) { res.writeHead(206); return res.end(data.subarray(Number(m[1]))); }
    res.end(data);
  });
  return new Promise((r) => srv.listen(0, '127.0.0.1', () => r(srv)));
}

test('downloads every part, resumes a partial one, verifies and unpacks', async () => {
  const pack = makePack();
  const srv = await serve(pack);
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'rt-home-'));
  const rt = new Runtime({ dir: path.join(home, 'runtime'), downloads: path.join(home, 'dl'), base: `http://127.0.0.1:${srv.address().port}` });
  fs.mkdirSync(rt.downloads, { recursive: true });
  fs.writeFileSync(path.join(rt.downloads, pack.parts[0].name), pack.parts[0].data.subarray(0, 1000));   // interrupted earlier
  const phases = new Set();
  let last = 0;
  const version = await rt.install((p) => { phases.add(p.phase); last = p.done; });
  assert.equal(version, '7');
  assert.ok(fs.existsSync(rt.python()));
  assert.equal(fs.statSync(path.join(rt.dir, 'Lib', 'big.bin')).size, 300_000);
  assert.deepEqual([...phases], ['download', 'unpack']);
  assert.equal(last, pack.total);
  assert.ok(!fs.existsSync(rt.downloads), 'downloads cleaned up');
  srv.close();
});

test('a damaged part is rejected and never unpacked', async () => {
  const pack = makePack();
  const srv = await serve(pack, { corruptSecond: true });
  const home = fs.mkdtempSync(path.join(os.tmpdir(), 'rt-home-'));
  const rt = new Runtime({ dir: path.join(home, 'runtime'), downloads: path.join(home, 'dl'), base: `http://127.0.0.1:${srv.address().port}` });
  await assert.rejects(rt.install(), /damaged/);
  assert.ok(!fs.existsSync(rt.python()));
  assert.ok(!fs.existsSync(path.join(rt.downloads, 'runtime.zip.002')), 'bad part deleted so Retry refetches it');
  srv.close();
});
