// A brand-new PC: no Python, no models folder of its own. One Download button installs the real runtime pack,
// then the dubbing engine comes up Ready. Slow (unpacks ~5 GB); run on its own: npx playwright test fresh-pc
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { launch } = require('./helpers');

const PACK = path.resolve(__dirname, '..', '..', 'dist', 'runtime');

test('fresh PC: downloads and installs the runtime, then the engine is ready', async () => {
  test.skip(!fs.existsSync(path.join(PACK, 'manifest.json')), 'build the runtime pack first');
  test.setTimeout(1_200_000);
  const srv = http.createServer((req, res) => {          // stands in for the GitHub release
    const file = path.join(PACK, path.basename(req.url));
    if (!fs.existsSync(file)) { res.statusCode = 404; return res.end(); }
    const size = fs.statSync(file).size;
    const m = /bytes=(\d+)-/.exec(req.headers.range || '');
    const start = m ? Number(m[1]) : 0;
    res.writeHead(m ? 206 : 200, { 'Content-Length': size - start });
    fs.createReadStream(file, { start }).pipe(res);
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const { app, ui } = await launch({ engine: 'on', env: {
    KOE_PYTHON: 'C:\no-python-here\python.exe',          // behave like a PC without our runtime
    KOE_RUNTIME_BASE: `http://127.0.0.1:${srv.address().port}`,
  } });
  await ui.keyboard.press('Escape');
  await expect(ui.locator('#setup')).toBeVisible({ timeout: 30_000 });
  await expect(ui.locator('#setup-go')).toHaveText(/Download \(3\.\d GB\)/);
  await ui.click('#setup-go');
  await expect(ui.locator('#setup-text')).toContainText('Unpacking', { timeout: 600_000 });
  await expect(ui.locator('#setup')).toBeHidden({ timeout: 600_000 });
  await expect(ui.locator('#engine-state')).toHaveText('Ready', { timeout: 300_000 });
  console.log('ENGINE:', await ui.locator('#engine-detail').textContent());
  await app.close();
  srv.close();
});
