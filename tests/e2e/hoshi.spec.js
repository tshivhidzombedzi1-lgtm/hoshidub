// Hoshi in the app: on the dashboard, in the panel tab, greeting, answering out loud, and settings.
// Uses a stand-in brain (KOE_BUDDY_FAKE) so the test doesn't need the 2.7 GB model.
const { test, expect } = require('@playwright/test');
const { launch, shot } = require('./helpers');

test('Hoshi greets, answers out loud, and lives on the dashboard and in the panel', async () => {
  test.setTimeout(240_000);
  const { app, ui } = await launch({ engine: 'on', env: { KOE_BUDDY_FAKE: '1', KOE_TEST_MUTE: '1', KOE_ADBLOCK: 'off' } });
  await ui.keyboard.press('Escape');
  await expect(ui.locator('#home-hoshi')).toBeVisible();
  await expect(ui.locator('#hoshi-home-avatar svg')).toBeVisible();

  await expect(ui.locator('#engine-state')).toHaveText('Ready', { timeout: 200_000 });
  await ui.click('#tab-hoshi');
  await expect(ui.locator('#pane-hoshi')).toBeVisible();
  await expect(ui.locator('#hoshi-chat li.them').first()).toContainText('MCP Labs', { timeout: 30_000 });   // her intro credits Moss
  await shot(ui, '14-hoshi-panel');

  await ui.fill('#hoshi-text', 'Who made you?');
  await ui.press('#hoshi-text', 'Enter');
  await expect(ui.locator('#hoshi-chat li.me')).toHaveText('Who made you?');
  await expect(ui.locator('#hoshi-chat li.them').nth(1)).toContainText('Who made you?', { timeout: 30_000 });   // stand-in echoes
  await expect(ui.locator('#hoshi-bubble')).toBeVisible();
  // she spoke: the lip-sync ran (mouth path changes while her audio plays)
  await expect.poll(() => ui.evaluate(() => window.__hoshiSpoke === true || !!document.querySelector('#hoshi-panel-avatar .h-mouth')), { timeout: 10_000 }).toBe(true);

  await ui.click('#tab-dub');
  await ui.click('#nav-home');
  await shot(ui, '15-hoshi-home');
  await ui.click('#nav-settings');
  await expect(ui.locator('#set-hoshi')).toBeChecked();
  await expect(ui.locator('#page-settings')).toContainText('Created by Tshivhidzo (Moss) Mbedzi');
  await ui.click('#set-hoshi');
  await expect(ui.locator('#tab-hoshi')).toBeHidden();
  await app.close();
});
