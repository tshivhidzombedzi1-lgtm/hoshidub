// Free allowance and Pro licence, against a stand-in for Lemon Squeezy's public licence API.
const { test, expect } = require('@playwright/test');
const http = require('http');
const { launch, tempProfile, shot } = require('./helpers');

const GOOD = 'A1B2C3D4-E5F6-4711-9A8B-0C1D2E3F4A5B';
const calls = [];

function fakeLemonSqueezy() {
  const srv = http.createServer((req, res) => {
    let body = '';
    req.on('data', (d) => { body += d; });
    req.on('end', () => {
      const f = Object.fromEntries(new URLSearchParams(body));
      calls.push({ path: req.url, ...f });
      const good = f.license_key === GOOD;
      const out = req.url.endsWith('/activate')
        ? (good ? { activated: true, instance: { id: 'inst-1' }, license_key: { status: 'active' }, meta: { product_id: 1 } }
          : { activated: false, error: 'license_key not found.' })
        : req.url.endsWith('/validate')
          ? { valid: good, license_key: { status: good ? 'active' : 'disabled' }, meta: { product_id: 1 } }
          : { deactivated: true };
      res.writeHead(good || !req.url.endsWith('/activate') ? 200 : 404, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(out));
    });
  });
  return new Promise((r) => srv.listen(0, '127.0.0.1', () => r(srv)));
}

test('Free plan shows the allowance; a licence key unlocks Pro and survives a restart', async () => {
  const srv = await fakeLemonSqueezy();
  const env = { KOE_LICENSE_API: `http://127.0.0.1:${srv.address().port}` };
  const profile = tempProfile();
  let { app, ui } = await launch({ profile, env });
  await ui.keyboard.press('Escape');

  await expect(ui.locator('#plan-meter')).toBeVisible();
  await expect(ui.locator('#meter-text')).toHaveText('30 min of free dubbing left today');

  await ui.click('#meter-upgrade');
  await expect(ui.locator('#upgrade')).toBeVisible();
  await shot(ui, '09-upgrade');
  await ui.fill('#up-key', 'nope');
  await ui.click('#up-activate');
  await expect(ui.locator('#up-error')).toContainText("doesn't look like a licence key");
  await ui.fill('#up-key', 'ZZZZ-ZZZZ-ZZZZ-ZZZZ-ZZZZ');
  await ui.click('#up-activate');
  await expect(ui.locator('#up-error')).toContainText("wasn't recognised");

  await ui.fill('#up-key', GOOD);
  await ui.click('#up-activate');
  await expect(ui.locator('#upgrade')).toBeHidden();
  await expect(ui.locator('.toast')).toContainText('Welcome to Hoshidub Pro');
  await expect(ui.locator('#plan-meter')).toBeHidden();
  await ui.click('#nav-settings');
  await expect(ui.locator('#plan-name')).toHaveText('Hoshidub Pro');
  await expect(ui.locator('#plan-detail')).toContainText('A1B2…4A5B');
  await app.close();

  ({ app, ui } = await launch({ profile, env }));            // still Pro after a restart, no re-entry
  await ui.click('#nav-settings');
  await expect(ui.locator('#plan-name')).toHaveText('Hoshidub Pro');
  await ui.click('#plan-deactivate');
  await ui.click('#plan-deactivate');                      // two-step confirm
  await expect(ui.locator('#plan-name')).toHaveText('Free');
  expect(calls.some((c) => c.path.endsWith('/deactivate') && c.instance_id === 'inst-1')).toBe(true);
  await app.close();
  srv.close();
});

test('when the free allowance is used up, Dub offers Pro instead of starting', async () => {
  const page = http.createServer((_q, res) => { res.writeHead(200, { 'Content-Type': 'text/html' }); res.end('<p>video page</p>'); });
  await new Promise((r) => page.listen(0, '127.0.0.1', r));
  const { app, ui } = await launch({ env: { KOE_FREE_SECONDS: '0' } });
  await ui.keyboard.press('Escape');
  await expect(ui.locator('#meter-text')).toHaveText('Free dubbing used up for today');
  await ui.fill('#address', `http://127.0.0.1:${page.address().port}/`);
  await ui.press('#address', 'Enter');
  await ui.waitForTimeout(800);
  await ui.click('#dub-btn');
  await expect(ui.locator('#upgrade')).toBeVisible();
  await expect(ui.locator('#up-title')).toHaveText("You've used today's free dubbing");
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'false');
  await app.close();
  page.close();
});
