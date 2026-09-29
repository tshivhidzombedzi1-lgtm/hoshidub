// Finds a runtime and models left elsewhere on this PC and moves them into Hoshidub's folder, so the app
// doesn't download gigabytes it already has. Places searched (under %LOCALAPPDATA%):
//   DubIt\                                  builds from before the rename
//   Packages\<app>\LocalCache\Local\Hoshidub\ or \DubIt\
//                                           files written by a packaged (MSIX) app, e.g. a developer tool,
//                                           which Windows redirects there and hides from normal programs
// Only what's missing is moved, one item at a time; nothing already in place is overwritten.
const fs = require('fs');
const path = require('path');

const NAMES = ['Hoshidub', 'DubIt'];

function candidates(localRoot, dest) {
  const found = [path.join(localRoot, 'DubIt')];
  let pkgs = [];
  try { pkgs = fs.readdirSync(path.join(localRoot, 'Packages'), { withFileTypes: true }).filter((d) => d.isDirectory()); } catch { /* no Packages folder */ }
  for (const p of pkgs) for (const n of NAMES) found.push(path.join(localRoot, 'Packages', p.name, 'LocalCache', 'Local', n));
  return found.filter((d) => path.resolve(d) !== path.resolve(dest) && fs.existsSync(d));
}

function move(from, to) {
  try { fs.renameSync(from, to); return true; } catch { return false; }   // same drive: instant; in use or other drive: leave it
}

// returns a list of what was moved, e.g. ['runtime from ...', 'models/hexgrad__Kokoro-82M from ...']
function adoptExisting(localRoot, dest) {
  const moved = [];
  for (const src of candidates(localRoot, dest)) {
    const runtime = path.join(src, 'runtime');
    if (!fs.existsSync(path.join(dest, 'runtime', 'python.exe')) && fs.existsSync(path.join(runtime, 'python.exe'))) {
      fs.mkdirSync(dest, { recursive: true });
      fs.rmSync(path.join(dest, 'runtime'), { recursive: true, force: true });   // an unusable partial runtime
      if (move(runtime, path.join(dest, 'runtime'))) moved.push(`runtime from ${src}`);
    }
    let models = [];
    try { models = fs.readdirSync(path.join(src, 'models'), { withFileTypes: true }).filter((d) => d.isDirectory()); } catch { /* none */ }
    for (const m of models) {
      const to = path.join(dest, 'models', m.name);
      if (fs.existsSync(to)) continue;
      fs.mkdirSync(path.dirname(to), { recursive: true });
      if (move(path.join(src, 'models', m.name), to)) moved.push(`models/${m.name} from ${src}`);
    }
  }
  return moved;
}

module.exports = { adoptExisting };
