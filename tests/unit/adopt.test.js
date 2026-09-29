// adopt.js: runtime and models already on the PC are moved into place instead of downloaded again.
const test = require('node:test');
const assert = require('node:assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { adoptExisting } = require('../../src/main/adopt');

function tree(root, files) {
  for (const f of files) {
    fs.mkdirSync(path.dirname(path.join(root, f)), { recursive: true });
    fs.writeFileSync(path.join(root, f), f);
  }
}
const tmp = () => fs.mkdtempSync(path.join(os.tmpdir(), 'hoshidub-adopt-'));

test('moves runtime and models out of a packaged app\'s redirected AppData', () => {
  const local = tmp();
  const hidden = path.join(local, 'Packages', 'Claude_x', 'LocalCache', 'Local', 'Hoshidub');
  tree(hidden, ['runtime/python.exe', 'runtime/Lib/os.py', 'models/hexgrad__Kokoro-82M/config.json']);
  const dest = path.join(local, 'Hoshidub');
  const moved = adoptExisting(local, dest);
  assert.equal(moved.length, 2);
  assert.ok(fs.existsSync(path.join(dest, 'runtime', 'python.exe')));
  assert.ok(fs.existsSync(path.join(dest, 'models', 'hexgrad__Kokoro-82M', 'config.json')));
  assert.ok(!fs.existsSync(path.join(hidden, 'runtime')));
});

test('moves the old DubIt folder\'s contents; never overwrites what is already in place', () => {
  const local = tmp();
  tree(path.join(local, 'DubIt'), ['runtime/python.exe', 'models/a/x.bin', 'models/b/y.bin']);
  tree(path.join(local, 'Hoshidub'), ['runtime/python.exe', 'models/a/mine.bin']);
  const moved = adoptExisting(local, path.join(local, 'Hoshidub'));
  assert.deepEqual(moved.map((m) => m.split(' ')[0]), ['models/b']);
  assert.ok(fs.existsSync(path.join(local, 'Hoshidub', 'models', 'a', 'mine.bin')));      // kept
  assert.ok(fs.existsSync(path.join(local, 'DubIt', 'runtime', 'python.exe')));          // not moved: one is in place
});

test('replaces a partial runtime (no python.exe) and does nothing on a clean PC', () => {
  const local = tmp();
  tree(path.join(local, 'DubIt'), ['runtime/python.exe']);
  tree(path.join(local, 'Hoshidub'), ['runtime/half-unpacked.txt']);
  assert.equal(adoptExisting(local, path.join(local, 'Hoshidub')).length, 1);
  assert.ok(fs.existsSync(path.join(local, 'Hoshidub', 'runtime', 'python.exe')));
  const clean = tmp();
  assert.deepEqual(adoptExisting(clean, path.join(clean, 'Hoshidub')), []);
});
