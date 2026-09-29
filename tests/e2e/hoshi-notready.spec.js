// Before Hoshi is ready, the mic and send buttons still answer and say why.
const { test, expect } = require('@playwright/test');
const { launch } = require('./helpers');

test('talking to Hoshi before she is ready explains what is happening', async () => {
  const { app, ui } = await launch();                        // engine off: Hoshi never connects
  await ui.keyboard.press('Escape');
  await ui.click('#tab-hoshi');
  await expect(ui.locator('#hoshi-status-text')).toHaveText('Connecting…');
  await ui.locator('#hoshi-mic').dispatchEvent('pointerdown');
  await expect(ui.locator('#hoshi-chat li.them').last()).toContainText('not connected yet');
  await ui.fill('#hoshi-text', 'hello?');
  await ui.press('#hoshi-text', 'Enter');
  await expect(ui.locator('#hoshi-chat li.me').last()).toHaveText('hello?');
  await expect(ui.locator('#hoshi-chat li.them').last()).toContainText('not connected yet');
  await app.close();
});
