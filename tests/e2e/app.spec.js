// End-to-end checks of the things people judge an app on: speed, first run, navigation, controls,
// persistence, keyboard access, accessibility preferences, and graceful errors.
const { test, expect } = require('@playwright/test');
const { launch, tempProfile, browserPage, shot } = require('./helpers');

test.describe.configure({ mode: 'serial' });

test('launches fast and shows onboarding on first run', async () => {
  const { app, ui, readyMs } = await launch();
  console.log(`time to interactive: ${readyMs} ms`);
  expect(readyMs).toBeLessThan(6000);
  await expect(ui.locator('#onboarding')).toBeVisible();
  await expect(ui.locator('#ob-title')).toHaveText('Welcome to Hoshidub');
  await shot(ui, '01-onboarding');
  await ui.click('#ob-next');
  await ui.click('#ob-next');
  await expect(ui.locator('#ob-next')).toHaveText('Get started');
  await ui.click('#ob-next');
  await expect(ui.locator('#onboarding')).toBeHidden();
  await shot(ui, '02-home');
  await app.close();
});

test('onboarding does not come back, settings survive a restart', async () => {
  const profile = tempProfile();
  let { app, ui } = await launch({ profile });
  await ui.keyboard.press('Escape');                       // Escape dismisses onboarding
  await expect(ui.locator('#onboarding')).toBeHidden();
  await ui.click('#nav-settings');
  await expect(ui.locator('#page-settings')).toBeVisible();
  await ui.locator('#set-volume').fill('70');
  await ui.locator('#set-volume').dispatchEvent('change');
  await ui.click('#set-caption-size button[data-v="large"]');
  await shot(ui, '03-settings');
  await app.close();

  ({ app, ui } = await launch({ profile }));
  await expect(ui.locator('#onboarding')).toBeHidden();
  await ui.click('#nav-settings');
  await expect(ui.locator('#set-volume')).toHaveValue('70');
  await expect(ui.locator('#vol')).toHaveValue('70');       // panel slider mirrors the setting
  await expect(ui.locator('#set-caption-size button[data-v="large"]')).toHaveAttribute('aria-checked', 'true');
  await app.close();
});

test('panel toggles and the video area resizes with it', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  const before = await ui.locator('#viewport').boundingBox();
  await ui.click('#btn-panel');
  await expect.poll(async () => (await ui.locator('#viewport').boundingBox()).width, { timeout: 3000 })
    .toBeGreaterThan(before.width + 250);
  await expect(ui.locator('#btn-panel')).toHaveAttribute('aria-expanded', 'false');
  await ui.click('#btn-panel');
  await expect(ui.locator('#btn-panel')).toHaveAttribute('aria-expanded', 'true');
  await app.close();
});

test('browses to a site, shows it in the address bar, and goes back home', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.click('#address');
  await ui.keyboard.type('example.com');
  await ui.keyboard.press('Enter');
  const page = await browserPage(app);
  await page.waitForLoadState('domcontentloaded');
  await expect(ui.locator('#address')).toHaveValue('example.com');
  await expect(ui.locator('#app')).toHaveClass(/browsing/);
  await expect(ui.locator('#address-icon use')).toHaveAttribute('href', '#i-lock');
  await shot(ui, '04-browsing');
  await ui.click('#nav-home');
  await expect(ui.locator('#page-home')).toBeVisible();
  await expect(ui.locator('#tile-continue')).toBeHidden();   // only on next launch
  await app.close();
});

test('typing words searches instead of failing', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.fill('#address', 'one piece episode 1');
  await ui.press('#address', 'Enter');
  const page = await browserPage(app);
  expect(page.url()).toContain('duckduckgo.com');
  await app.close();
});

test('dub explains itself when it cannot start', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.click('#dub-btn');
  await expect(ui.locator('.toast')).toBeVisible();
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'false');
  await app.close();
});

test('keyboard only: every control is reachable and labelled', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  const seen = new Set();
  for (let i = 0; i < 40; i++) {
    await ui.keyboard.press('Tab');
    const label = await ui.evaluate(() => {
      const el = document.activeElement;
      return el && el !== document.body ? (el.getAttribute('aria-label') || el.textContent.trim() || el.id) : '';
    });
    if (label) seen.add(label);
  }
  for (const need of ['Home', 'Crunchyroll', 'Settings', 'Address', 'Live dub', 'Hide dub panel']) {
    expect([...seen]).toContain(need);
  }
  const unlabelled = await ui.evaluate(() => [...document.querySelectorAll('button, input')]
    .filter((el) => el.offsetParent && !el.getAttribute('aria-label') && !el.textContent.trim() && !el.closest('label'))
    .map((el) => el.id || el.outerHTML.slice(0, 60)));
  expect(unlabelled).toEqual([]);
  await app.close();
});

test('Ctrl+L focuses the address bar, Ctrl+J toggles the panel', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.keyboard.press('Control+L');
  await expect(ui.locator('#address')).toBeFocused();
  await ui.keyboard.press('Escape');
  await ui.keyboard.press('Control+J');
  await expect(ui.locator('#btn-panel')).toHaveAttribute('aria-expanded', 'false');
  await app.close();
});

test('reduce transparency and light mode render cleanly', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.emulateMedia({ colorScheme: 'light' });
  await shot(ui, '05-home-light');
  await ui.click('#nav-settings');
  await ui.click('#set-reduce');
  await expect(ui.locator('html')).toHaveClass(/reduce-transparency/);
  const bg = await ui.locator('.rail').evaluate((el) => getComputedStyle(el).backdropFilter);
  expect(bg).toBe('none');
  await shot(ui, '06-settings-reduced-light');
  await ui.emulateMedia({ colorScheme: 'dark', reducedMotion: 'reduce' });
  await shot(ui, '07-settings-reduced-dark');
  await app.close();
});

test('no console errors on a normal session', async () => {
  const { app, ui } = await launch();
  const errors = [];
  ui.on('console', (m) => m.type() === 'error' && errors.push(m.text()));
  ui.on('pageerror', (e) => errors.push(e.message));
  await ui.keyboard.press('Escape');
  await ui.click('#nav-settings');
  await ui.click('#nav-home');
  await ui.click('#btn-panel');
  await ui.click('#btn-panel');
  await ui.waitForTimeout(500);
  expect(errors).toEqual([]);
  await app.close();
});
