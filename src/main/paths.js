// Where things live, for both a source checkout and an installed copy of Hoshidub.
const fs = require('fs');
const path = require('path');
const { app } = require('electron');

const SOURCE_ROOT = path.resolve(__dirname, '..', '..');          // koe/ when running from source
const LOCAL_ROOT = process.env.LOCALAPPDATA || app.getPath('appData');
const LOCAL = localDir();

// downloads (runtime, models) live in %LOCALAPPDATA%\Hoshidub. Builds from before the rename used "DubIt":
// move that folder over once rather than download gigabytes again; if it's in use, keep using it this run.
function localDir() {
  const now = path.join(LOCAL_ROOT, 'Hoshidub');
  const old = path.join(LOCAL_ROOT, 'DubIt');
  if (!fs.existsSync(now) && fs.existsSync(old)) {
    try { fs.renameSync(old, now); } catch { return old; }
  }
  return now;
}

// the Python runtime: downloaded on first run for installed copies, the dev venv when working from source
const RUNTIME_DIR = path.join(LOCAL, 'runtime');
const RUNTIME_PYTHON = path.join(RUNTIME_DIR, 'python.exe');
const DEV_PYTHON = path.resolve(SOURCE_ROOT, '..', '.venv', 'Scripts', 'python.exe');

function engineDir() {
  return app.isPackaged ? path.join(process.resourcesPath, 'engine') : path.join(SOURCE_ROOT, 'engine');
}

function python() {
  if (process.env.KOE_PYTHON) return process.env.KOE_PYTHON;
  if (fs.existsSync(RUNTIME_PYTHON)) return RUNTIME_PYTHON;
  return fs.existsSync(DEV_PYTHON) ? DEV_PYTHON : RUNTIME_PYTHON;
}

// release settings baked into the build, from package.json "dubit" (an env var overrides each one for tests)
function setting(key, envName) {
  if (process.env[envName]) return process.env[envName];
  try { return require(path.join(SOURCE_ROOT, 'package.json')).dubit[key] || ''; } catch { return ''; }
}
const runtimeBase = () => setting('runtimeBase', 'KOE_RUNTIME_BASE');     // where the runtime pack downloads from (a GitHub release)
const productId = () => setting('productId', 'KOE_PRODUCT_ID');           // Lemon Squeezy product that Pro keys must belong to
const checkoutUrl = () => setting('checkoutUrl', 'KOE_CHECKOUT_URL');     // Lemon Squeezy checkout link behind "Get Pro"

module.exports = { LOCAL, RUNTIME_DIR, RUNTIME_PYTHON, engineDir, python, runtimeBase, productId, checkoutUrl };
