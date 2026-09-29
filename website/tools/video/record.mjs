// Records tools/video/reel.html headless (nothing opens on screen) and writes the home page video:
//   public/video/how-it-works.mp4 (H.264), .webm (VP9) and a poster image.
//   node tools/video/record.mjs        (needs Edge and ffmpeg on PATH)
import { chromium } from '../../../node_modules/playwright/index.mjs';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const site = path.join(here, '..', '..');
const tmp = path.join(here, 'raw');
const out = path.join(site, 'public', 'video');
fs.rmSync(tmp, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });

const size = { width: 1280, height: 720 };
const browser = await chromium.launch({ channel: 'msedge', headless: true });
const ctx = await browser.newContext({ viewport: size, recordVideo: { dir: tmp, size } });
const t0 = Date.now();
const page = await ctx.newPage();
await page.goto(pathToFileURL(path.join(here, 'reel.html')).href);
await page.evaluate(() => document.fonts.ready.then(() => Promise.all([...document.images].map((i) => i.decode().catch(() => {})))));
const lead = (Date.now() - t0) / 1000;                     // blank lead-in to trim off
await page.evaluate(() => window.startReel());
await page.waitForFunction(() => window.__reelDone, null, { timeout: 90_000, polling: 250 });
const raw = await page.video().path();
await ctx.close();
await browser.close();

const trim = ['-ss', lead.toFixed(2), '-i', raw, '-t', '44.5', '-an'];
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...trim, '-vf', 'fps=30', '-c:v', 'libx264', '-preset', 'slow', '-crf', '24', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
  path.join(out, 'how-it-works.mp4')]);
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...trim, '-vf', 'fps=30', '-c:v', 'libvpx-vp9', '-b:v', '0', '-crf', '38', '-row-mt', '1',
  path.join(out, 'how-it-works.webm')]);
execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-ss', '19.2', '-i', path.join(out, 'how-it-works.mp4'), '-frames:v', '1', '-q:v', '4',
  path.join(out, 'how-it-works-poster.jpg')]);
fs.rmSync(tmp, { recursive: true, force: true });
for (const f of fs.readdirSync(out)) console.log(f, (fs.statSync(path.join(out, f)).size / 1e6).toFixed(2), 'MB');
