// The built-in ad blocker: blocks real ad/tracker requests, counts them, and can be turned off per site.
const { test, expect } = require('@playwright/test');
const http = require('http');
const { launch } = require('./helpers');

test('blocks ads and trackers, and the shield turns it off for one site', async () => {
  const srv = http.createServer((_q, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    res.end(`<!doctype html><h1>A page with ads</h1>
      <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js"></script>
      <img src="https://www.google-analytics.com/collect?v=1&t=pageview" width="1" height="1">
      <script src="https://securepubads.g.doubleclick.net/tag/js/gpt.js"></script>`);
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const { app, ui } = await launch({ env: { KOE_ADBLOCK: 'on' } });
  await ui.keyboard.press('Escape');
  // a brand-new profile downloads the filter lists once (later runs load them from disk instantly)
  await expect.poll(() => ui.evaluate(() => window.koe.adblock.state().then((s) => s.available)), { timeout: 60_000 }).toBe(true);
  await ui.fill('#address', `http://127.0.0.1:${srv.address().port}/`);
  await ui.press('#address', 'Enter');

  const shield = ui.locator('#shield-btn');
  await expect(shield).toBeVisible({ timeout: 30_000 });
  await expect.poll(async () => Number(await ui.locator('#shield-count').textContent()), { timeout: 30_000 }).toBeGreaterThanOrEqual(2);
  console.log('blocked on page:', await ui.locator('#shield-count').textContent());
  await expect(shield).not.toHaveClass(/off/);

  await shield.click();                                   // allow ads on this site
  await expect(ui.locator('.toast')).toContainText('Ads allowed on 127.0.0.1');
  await expect(shield).toHaveClass(/off/);
  await shield.click();                                   // and block them again
  await expect(shield).not.toHaveClass(/off/);
  await expect.poll(async () => Number(await ui.locator('#shield-count').textContent()), { timeout: 20_000 }).toBeGreaterThanOrEqual(2);

  await ui.click('#nav-settings');
  await expect(ui.locator('#set-adblock')).toBeChecked();
  await app.close();
  srv.close();
});
