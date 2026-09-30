// Viewport screenshots of specific spots (the trouble areas from the responsive check), dark and light.
//   node tools/focus-shots.mjs [baseUrl] [outDir]
const { chromium } = await import(process.env.PLAYWRIGHT || '../../node_modules/playwright/index.mjs');
import fs from 'node:fs';

const base = process.argv[2] || 'http://localhost:3000';
const out = process.argv[3] || 'focus';
fs.mkdirSync(out, { recursive: true });

// [name, path, width, height, selector to scroll into view (or null for the top)]
const spots = [
  ['home-top-320', '/', 320, 640, null],
  ['home-top-390', '/', 390, 844, null],
  ['home-top-1366', '/', 1366, 800, null],
  ['home-callouts-1366', '/', 1366, 800, '#tour'],
  ['home-callouts-1100', '/', 1100, 800, '#tour'],
  ['home-callouts-1024', '/', 1024, 768, '#tour'],
  ['home-callouts-940', '/', 940, 768, '#tour'],
  ['paid-390', '/download?paid=1', 390, 844, null],
  ['paid-1366', '/download?paid=1', 1366, 800, null],
  ['lostkey-390', '/support', 390, 844, '#lost-key'],
  ['lostkey-1366', '/support', 1366, 800, '#lost-key'],
  ['compare-390', '/pricing', 390, 844, 'table'],
  ['compare-1366', '/pricing', 1366, 800, 'table'],
];
const schemes = (process.env.SCHEMES || 'dark,light').split(',');
const browser = await chromium.launch({ ...(process.env.CHANNEL === 'none' ? {} : { channel: process.env.CHANNEL || 'msedge' }), headless: true });
const problems = [];
for (const scheme of schemes) {
  for (const [name, path, width, height, sel] of spots) {
    const ctx = await browser.newContext({ viewport: { width, height }, colorScheme: scheme, reducedMotion: 'reduce' });
    const page = await ctx.newPage();
    page.on('pageerror', (e) => problems.push(`${name}/${scheme}: ${e.message}`));
    await page.goto(base + path, { waitUntil: 'networkidle' });
    if (sel) await page.locator(sel).first().scrollIntoViewIfNeeded().catch(() => problems.push(`${name}: no ${sel}`));
    if (sel === '#tour') await page.evaluate(() => scrollBy(0, -40));
    await page.waitForTimeout(1200);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
    if (overflow > 0) problems.push(`${name}/${scheme}: ${overflow}px wider than the screen`);
    await page.screenshot({ path: `${out}/${name}-${scheme}.png` });
    await ctx.close();
  }
}
await browser.close();
console.log(problems.length ? problems.join('\n') : 'no page errors, no sideways scroll');
