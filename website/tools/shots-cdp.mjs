// Screenshots via a running chrome-headless-shell on :9222 (for hosts that cap threads; see run-shots.sh).
//   node tools/shots-cdp.mjs [baseUrl] [outDir]     env: SIZES, PAGES
import { connect } from './cdp.mjs';
import fs from 'node:fs';
const base = process.argv[2] || 'http://localhost:3000';
const out = process.argv[3] || 'shots';
const pages = (process.env.PAGES || 'home,pricing,download,about,tip,support,press,privacy,terms,nope').split(',').map((n) => (n === 'home' ? '/' : '/' + n));
const sizes = (process.env.SIZES || 'desktop,phone').split(',');
const viewport = { wide: [1920, 1080], desktop: [1366, 800], small: [1024, 768], tablet: [768, 1024], phone: [390, 844], mini: [360, 740] };
fs.mkdirSync(out, { recursive: true });
const c = await connect();
const problems = [];
let cur = '';
c.on((m) => {
  if (m.method === 'Runtime.exceptionThrown') problems.push(`${cur}: ${m.params.exceptionDetails.exception?.description || m.params.exceptionDetails.text}`);
  if (m.method === 'Log.entryAdded' && m.params.entry.level === 'error') problems.push(`${cur}: ${m.params.entry.text} ${m.params.entry.url || ''}`);
});
await c.send('Runtime.enable'); await c.send('Log.enable'); await c.send('Page.enable');
await c.send('Emulation.setEmulatedMedia', { features: [{ name: 'prefers-reduced-motion', value: 'reduce' }, { name: 'prefers-color-scheme', value: 'dark' }] });
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const PROBE = `(() => {
  const vw = document.documentElement.clientWidth, o = [];
  for (const el of document.body.querySelectorAll('h1,h2,h3,p,a,button,li,span,img,canvas,.btn')) {
    const r = el.getBoundingClientRect(); if (!r.width || !r.height) continue;
    if (r.right > vw + 1 || r.left < -1) { const cs = getComputedStyle(el); if (cs.position !== 'fixed') o.push(el.tagName.toLowerCase() + '.' + (el.className.baseVal ?? el.className) + ' ' + Math.round(r.left) + '..' + Math.round(r.right) + ' "' + (el.textContent || '').trim().slice(0, 30) + '"'); }
  }
  const clip = []; for (const el of document.querySelectorAll('h1,h2,h3,p,a,button,.btn,li')) { if (el.scrollWidth > el.clientWidth + 2 && getComputedStyle(el).overflowX !== 'visible') clip.push(el.tagName + '.' + el.className); }
  return { over: document.documentElement.scrollWidth - vw, offenders: o.slice(0, 8), clipped: clip.slice(0, 5), h: document.documentElement.scrollHeight };
})()`;
for (const size of sizes) {
  const [w, h] = viewport[size];
  await c.send('Emulation.setDeviceMetricsOverride', { width: w, height: h, deviceScaleFactor: 1, mobile: w < 700 });
  for (const p of pages) {
    cur = `${size} ${p}`;
    await c.send('Page.navigate', { url: base + p });
    await sleep(1800);
    await c.evaluate(`(async()=>{for(let y=0;y<document.body.scrollHeight;y+=500){scrollTo(0,y);await new Promise(r=>setTimeout(r,50))}scrollTo(0,0)})()`);
    await sleep(600);
    const r = await c.evaluate(PROBE);
    if (r.over > 0 || r.offenders.length || r.clipped.length) problems.push(`${cur}: over=${r.over} ${JSON.stringify(r.offenders)} clipped=${JSON.stringify(r.clipped)}`);
    const shot = await c.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true, clip: { x: 0, y: 0, width: w, height: Math.min(r.h, 9000), scale: 1 } });
    fs.writeFileSync(`${out}/${p === '/' ? 'home' : p.slice(1)}-${size}.png`, Buffer.from(shot.data, 'base64'));
  }
}
console.log(problems.length ? problems.join('\n') : 'no console errors, no sideways scroll');
c.close(); process.exit(0);
