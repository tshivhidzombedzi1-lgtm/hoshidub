// The glass follows the open page: dark page -> dark glass with the page's colours glowing behind it,
// bright page -> light glass, back home -> the system theme over the photo.
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { launch, SHOTS } = require('./helpers');

async function windowShot(app, name) {
  const png = await app.evaluate(async ({ BrowserWindow }) => {
    const w = BrowserWindow.getAllWindows()[0];
    const base = await w.capturePage();
    return base.toPNG().toString('base64');
  });
  fs.writeFileSync(path.join(SHOTS, `${name}.png`), Buffer.from(png, 'base64'));
}

test('glass turns dark on a dark page, light on a bright page, and resets at home', async () => {
  const srv = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(req.url === '/dark'
      ? '<body style="margin:0;height:100vh;background:linear-gradient(135deg,#0b0620,#3a0d5c 60%,#07131f)"><h1 style="color:#eee;font:48px sans-serif;padding:40px">Night page</h1></body>'
      : '<body style="margin:0;height:100vh;background:linear-gradient(135deg,#fff8ec,#ffe3c2 60%,#f4fbff)"><h1 style="color:#222;font:48px sans-serif;padding:40px">Day page</h1></body>');
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const base = `http://127.0.0.1:${srv.address().port}`;
  const { app, ui } = await launch({ env: { KOE_ADBLOCK: 'off' } });
  await ui.keyboard.press('Escape');
  await ui.emulateMedia({ colorScheme: 'light' });

  await ui.fill('#address', `${base}/dark`);
  await ui.press('#address', 'Enter');
  await expect(ui.locator('html')).toHaveAttribute('data-theme', 'dark', { timeout: 10_000 });
  await expect.poll(() => ui.locator('#glow-a, #glow-b').evaluateAll((els) => els.some((e) => e.classList.contains('on')))).toBe(true);
  await ui.waitForTimeout(1200);
  await windowShot(app, '12-glass-dark-page');

  await ui.fill('#address', `${base}/light`);
  await ui.press('#address', 'Enter');
  await expect(ui.locator('html')).toHaveAttribute('data-theme', 'light', { timeout: 10_000 });
  await ui.waitForTimeout(1200);
  await windowShot(app, '13-glass-light-page');

  await ui.click('#nav-home');
  await expect(ui.locator('html')).not.toHaveAttribute('data-theme', /./);
  await expect.poll(() => ui.locator('.content').evaluate((el) => getComputedStyle(el).backdropFilter)).toContain('blur');
  await app.close();
  srv.close();
});
