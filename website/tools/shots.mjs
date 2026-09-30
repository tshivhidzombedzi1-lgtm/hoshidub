// Full-page screenshots of every page, desktop and phone, in dark and light (headless Edge; nothing opens on screen).
//   node tools/shots.mjs [baseUrl] [outDir]
const { chromium } = await import(process.env.PLAYWRIGHT || '../../node_modules/playwright/index.mjs');
import fs from 'node:fs';

const base = process.argv[2] || 'http://localhost:4321';
const out = process.argv[3] || 'shots';
// page names without slashes (Git Bash rewrites leading slashes into Windows paths)
const pages = (process.env.PAGES || 'home,pricing,download,about,tip,support,press,privacy,terms,nope').split(',').map((n) => (n === 'home' ? '/' : '/' + n));
const sizes = (process.env.SIZES || 'desktop,phone').split(',');
const schemes = (process.env.SCHEMES || 'dark').split(',');
const viewport = {
  wide: { width: 1920, height: 1080 }, desktop: { width: 1366, height: 800 }, small: { width: 1024, height: 768 },
  tablet: { width: 768, height: 1024 }, phone: { width: 390, height: 844 }, mini: { width: 360, height: 740 },
};
fs.mkdirSync(out, { recursive: true });

const browser = await chromium.launch({ ...(process.env.CHANNEL === 'none' ? {} : { channel: process.env.CHANNEL || 'msedge' }), headless: true });
const problems = [];
for (const size of sizes) for (const scheme of schemes) {
  const ctx = await browser.newContext({ viewport: viewport[size], colorScheme: scheme, deviceScaleFactor: 1, reducedMotion: 'reduce' });
  const page = await ctx.newPage();
  page.on('console', (m) => { if (m.type() === 'error') problems.push(`${size}/${scheme} ${page.url()}: ${m.text()}`); });
  page.on('pageerror', (e) => problems.push(`${size}/${scheme} ${page.url()}: ${e.message}`));
  for (const p of pages) {
    await page.goto(base + p, { waitUntil: 'networkidle' });
    // scroll through once so lazy images load, then back to the top
    await page.evaluate(async () => { for (let y = 0; y < document.body.scrollHeight; y += 600) { scrollTo(0, y); await new Promise((r) => setTimeout(r, 60)); } scrollTo(0, 0); });
    await page.waitForTimeout(1500);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
    if (overflow > 0) problems.push(`${size}/${scheme} ${p}: page is ${overflow}px wider than the screen`);
    const name = (p === '/' ? 'home' : p.slice(1)) + `-${size}-${scheme}.png`;
    await page.screenshot({ path: `${out}/${name}`, fullPage: true });
  }
  await ctx.close();
}
await browser.close();
console.log(problems.length ? problems.join('\n') : 'no console errors, no sideways scroll');
