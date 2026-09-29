// First run on a PC with no models: the setup screen downloads the voices with progress, then hands over.
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const http = require('http');
const os = require('os');
const path = require('path');
const { launch, shot } = require('./helpers');

function fakeModelHost(bytes = 2_000_000) {
  const blob = Buffer.alloc(bytes, 7);
  const srv = http.createServer((req, res) => {
    const range = /bytes=(\d+)-/.exec(req.headers.range || '');
    const from = range ? Number(range[1]) : 0;
    const headers = { 'Content-Length': bytes - from, 'Content-Type': 'application/octet-stream' };
    if (req.method === 'HEAD') { res.writeHead(200, { ...headers, 'Content-Length': bytes }); return res.end(); }
    res.writeHead(range ? 206 : 200, headers);
    const body = blob.subarray(from);
    let i = 0;
    const tick = setInterval(() => {                    // trickle so progress is visible
      if (i >= body.length) { clearInterval(tick); return res.end(); }
      res.write(body.subarray(i, i + 200_000));
      i += 200_000;
    }, 5);
  });
  return new Promise((r) => srv.listen(0, '127.0.0.1', () => r(srv)));
}

test('first run: downloads the voices with progress, then the setup screen goes away', async () => {
  const host = await fakeModelHost();
  const models = fs.mkdtempSync(path.join(os.tmpdir(), 'koe-models-'));
  const { app, ui } = await launch({ engine: 'on', env: { KOE_MODELS: models, KOE_PACK_BASE: `http://127.0.0.1:${host.address().port}` } });
  await ui.keyboard.press('Escape');                       // finish onboarding → setup appears
  await expect(ui.locator('#setup')).toBeVisible({ timeout: 20_000 });
  await expect(ui.locator('#engine-state')).toHaveText('Needs voices');
  await expect(ui.locator('#gpu-line')).toContainText(/GB|No NVIDIA/);
  await expect(ui.locator('#setup-go')).toHaveText('Download (336 MB)');
  await expect(ui.locator('#ear-opt')).toBeHidden();          // translate-by-ear is already on this PC
  await shot(ui, '10-setup');
  await ui.click('#setup-go');
  await expect(ui.locator('#setup-text')).toContainText(/of \d+ MB/);
  await expect(ui.locator('#setup')).toBeHidden({ timeout: 60_000 });
  await expect(ui.locator('.toast')).toContainText('Voices downloaded');
  expect(fs.existsSync(path.join(models, 'hexgrad__Kokoro-82M', 'voices', 'af_heart.pt'))).toBe(true);
  await app.close();
  host.close();
});
