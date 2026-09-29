// Where things live, for both a source checkout and an installed copy of Otodub.
const fs = require('fs');
const path = require('path');
const { app } = require('electron');

const SOURCE_ROOT = path.resolve(__dirname, '..', '..');          // koe/ when running from source
const LOCAL = path.join(process.env.LOCALAPPDATA || app.getPath('appData'), 'DubIt');

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

// where the runtime pack is downloaded from (a GitHub release), set in package.json "dubit.runtimeBase"
function runtimeBase() {
  if (process.env.KOE_RUNTIME_BASE) return process.env.KOE_RUNTIME_BASE;
  try { return require(path.join(SOURCE_ROOT, 'package.json')).dubit.runtimeBase || ''; } catch { return ''; }
}

module.exports = { LOCAL, RUNTIME_DIR, RUNTIME_PYTHON, engineDir, python, runtimeBase };
