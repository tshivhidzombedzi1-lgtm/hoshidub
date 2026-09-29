// Windows decides what a real mouse click hits (client area vs title bar), and Playwright's clicks bypass that.
// So ask Windows directly: every control must be clickable, and only the empty drag areas may move the window.
const { test, expect } = require('@playwright/test');
const { execFileSync } = require('child_process');
const path = require('path');
const { launch } = require('./helpers');

test('every control is clickable with a real mouse; only empty areas drag the window', async () => {
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.waitForTimeout(800);
  const { hwnd, cx, cy } = await app.evaluate(({ BrowserWindow }) => {
    const w = BrowserWindow.getAllWindows()[0];
    const b = w.getContentBounds();
    return { hwnd: String(w.getNativeWindowHandle().readBigUInt64LE(0)), cx: b.x, cy: b.y };
  });
  const controls = ['#address', '#dub-btn', '#btn-back', '#btn-reload', '#btn-panel', '#nav-home', '#nav-crunchyroll', '#nav-youtube', '#nav-settings', '#dub-switch', '#vol', '#tile-crunchyroll'];
  const drags = ['.drag-space', '.brand'];
  const pts = [];
  for (const sel of [...controls, ...drags]) {
    const r = await ui.locator(sel).boundingBox();
    pts.push(`${sel},${Math.round(cx + r.x + r.width / 2)},${Math.round(cy + r.y + r.height / 2)}`);
  }
  const out = execFileSync('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    path.join(__dirname, '..', 'support', 'hittest.ps1'), hwnd, pts.join(';')]).toString();
  const hit = Object.fromEntries(out.trim().split(/\r?\n/).map((l) => { const m = l.match(/^(\S+)\s+->\s+(\d+)/); return [m[1], Number(m[2])]; }));
  for (const sel of controls) expect(hit[sel], `${sel} must be clickable`).toBe(1);        // HTCLIENT
  for (const sel of drags) expect(hit[sel], `${sel} should drag the window`).toBe(2);      // HTCAPTION
  await app.close();
});
