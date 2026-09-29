const { _electron: electron } = require('@playwright/test');
const fs = require('fs');
const os = require('os');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const SHOTS = path.join(__dirname, 'shots');
fs.mkdirSync(SHOTS, { recursive: true });

function tempProfile() {
  return fs.mkdtempSync(path.join(os.tmpdir(), 'koe-test-'));
}

async function launch({ profile = tempProfile(), engine = 'off', env = {} } = {}) {
  const t0 = Date.now();
  const app = await electron.launch({
    args: [ROOT],
    cwd: ROOT,
    env: { ...process.env, KOE_USER_DATA: profile, KOE_ENGINE: engine, KOE_TEST_INACTIVE: '1', ...env },
  });
  const ui = await findUi(app);
  await ui.waitForSelector('body[data-ready="1"]', { timeout: 30_000 });
  return { app, ui, profile, readyMs: Date.now() - t0 };
}

async function findUi(app) {
  for (let i = 0; i < 100; i++) {
    const page = app.windows().find((w) => w.url().endsWith('/index.html'));
    if (page) return page;
    await new Promise((r) => setTimeout(r, 100));
  }
  throw new Error('UI window never appeared');
}

async function browserPage(app) {
  for (let i = 0; i < 100; i++) {
    const page = app.windows().find((w) => /^https?:/.test(w.url()));
    if (page) return page;
    await new Promise((r) => setTimeout(r, 200));
  }
  throw new Error('browser view never loaded a page');
}

async function shot(ui, name) {
  await ui.waitForTimeout(450);        // let transitions and glass maps settle
  await ui.screenshot({ path: path.join(SHOTS, `${name}.png`) });
}

module.exports = { launch, tempProfile, browserPage, shot, SHOTS };
