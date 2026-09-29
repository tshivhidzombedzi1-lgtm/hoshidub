// Live check against the real Crunchyroll with the user's own saved Koe profile. Not part of `npm test`.
// Run: npx playwright test --config tests/live/playwright.live.config.js
const { test, expect } = require('@playwright/test');
const { launch } = require('../e2e/helpers');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const PROFILE = process.env.KOE_LIVE_PROFILE || path.join(process.env.APPDATA, 'Koe');
const EPISODE = process.env.KOE_LIVE_URL || 'https://www.crunchyroll.com/watch/GE00361959JAJP/we-came-to-svel';
const LISTEN_SECONDS = Number(process.env.KOE_LIVE_SECONDS || 90);
const OUT = path.join(__dirname, 'out');
fs.mkdirSync(OUT, { recursive: true });

async function videoFrameState(app) {
  return app.evaluate(async ({ BrowserWindow }) => {
    const win = BrowserWindow.getAllWindows()[0];
    const view = win.contentView.children.find((v) => v.webContents && /^https?:/.test(v.webContents.getURL()));
    if (!view) return null;
    for (const f of view.webContents.mainFrame.framesInSubtree) {
      try {
        const s = await f.executeJavaScript(`(() => { const v = [...document.querySelectorAll('video')].find(v => v.duration > 0);
          return v ? { t: v.currentTime, paused: v.paused, url: location.host } : null; })()`);
        if (s) return s;
      } catch { /* cross-navigation */ }
    }
    return null;
  });
}

async function playVideo(app) {
  return app.evaluate(async ({ BrowserWindow }) => {
    const win = BrowserWindow.getAllWindows()[0];
    const view = win.contentView.children.find((v) => v.webContents && /^https?:/.test(v.webContents.getURL()));
    for (const f of view.webContents.mainFrame.framesInSubtree) {
      try {
        const ok = await f.executeJavaScript(`(() => { const v = [...document.querySelectorAll('video')].find(v => v.duration > 0);
          if (!v) return false; v.play(); return true; })()`, true);
        if (ok) return true;
      } catch { /* next frame */ }
    }
    return false;
  });
}

test('Crunchyroll: plays, finds official subtitles, dubs live', async () => {
  test.setTimeout(420_000);
  const { app, ui } = await launch({ profile: PROFILE, engine: 'on',
    env: { KOE_TEST_MUTE: process.env.KOE_LIVE_SOUND ? '' : '1' } });
  if (await ui.locator('#onboarding').isVisible()) await ui.keyboard.press('Escape');
  const report = { episode: EPISODE };

  await expect(ui.locator('#engine-state')).toHaveText('Ready', { timeout: 240_000 });
  report.engine = await ui.locator('#engine-detail').textContent();

  await ui.fill('#address', EPISODE);
  await ui.press('#address', 'Enter');

  // wait for the player's video to exist (login wall or DRM failure would stop here)
  let state = null;
  for (let i = 0; i < 90 && !state; i++) { state = await videoFrameState(app); if (!state) await ui.waitForTimeout(1000); }
  report.pageUrl = await ui.locator('#address').inputValue();
  if (!state) {
    fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify({ ...report, result: 'no video (not signed in, or playback blocked)' }, null, 2));
    await app.close();
    throw new Error('No playing video found — is this Koe profile signed in to Crunchyroll?');
  }
  report.playerHost = state.url;

  const source = await ui.locator('#source-title').textContent();
  report.subtitlesBeforePlay = source;

  await ui.click('#dub-btn');
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'true', { timeout: 10_000 });
  if ((await videoFrameState(app))?.paused) await playVideo(app);
  const t0 = (await videoFrameState(app))?.t;

  const latencies = [];
  const started = Date.now();
  let seen = 0;
  while (Date.now() - started < LISTEN_SECONDS * 1000) {
    await ui.waitForTimeout(3000);
    const n = await ui.locator('#transcript li:not(.transcript-empty)').count();
    if (n > seen) {
      seen = n;
      const l = parseFloat(await ui.locator('#latency').textContent());
      if (!Number.isNaN(l)) latencies.push(l);
    }
  }
  const t1 = (await videoFrameState(app))?.t;
  report.videoAdvancedSeconds = t1 && t0 !== undefined ? Math.round(t1 - t0) : null;
  report.source = `${await ui.locator('#source-title').textContent()} — ${await ui.locator('#source-detail').textContent()}`;
  report.lines = await ui.locator('#transcript li:not(.transcript-empty)').allTextContents();
  const track = await ui.evaluate(() => window.koe.subs.get());
  if (track) {                                   // official lines that were due while we listened, to compare
    report.officialDuring = track.lines.filter((l) => l.start >= (t0 ?? 0) - 1 && l.start <= (t1 ?? 0))
      .map((l) => `${l.start.toFixed(1)}s ${l.text}`);
  }
  report.characters = [...new Set(report.lines.map((l) => l.match(/^Character \d+/)?.[0]))].length;
  report.latencySamples = latencies;

  const png = await app.evaluate(async ({ BrowserWindow }) => (await BrowserWindow.getAllWindows()[0].capturePage()).toPNG().toString('base64'));
  fs.writeFileSync(path.join(OUT, 'window.png'), Buffer.from(png, 'base64'));

  await ui.click('#dub-btn');
  await app.evaluate(async ({ BrowserWindow }) => {
    const view = BrowserWindow.getAllWindows()[0].contentView.children.find((v) => /^https?:/.test(v.webContents?.getURL?.() || ''));
    for (const f of view.webContents.mainFrame.framesInSubtree) f.executeJavaScript('document.querySelectorAll("video").forEach(v => v.pause())').catch(() => {});
  });
  fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  await app.close();
  expect(report.lines.length).toBeGreaterThan(5);
});
