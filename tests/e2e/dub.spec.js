// The whole product in one test: a real page plays Japanese video in Otodub's browser, the user presses Dub,
// and English lines come back with separate voices, captions, and a live transcript. Runs silently.
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { launch, browserPage, SHOTS } = require('./helpers');

const CLIP = path.resolve(__dirname, '..', '..', '..', 'test', 'test_clip.mp4');
const VTT = path.resolve(__dirname, '..', '..', '..', 'test', 'test_clip.en.vtt');

function serveClip() {
  const plain = `<!doctype html><body style="margin:0;background:#000">
    <video id="v" src="/clip.mp4" style="width:100%;height:100vh" playsinline></video></body>`;
  // like a streaming site: the player fetches an English subtitle track alongside the video
  const withSubs = `<!doctype html><body style="margin:0;background:#000">
    <video id="v" src="/clip.mp4" style="width:100%;height:100vh" playsinline>
      <track kind="subtitles" srclang="en" src="/subs/en-US.vtt" default></video></body>`;
  const srv = http.createServer((req, res) => {
    if (req.url === '/subs/en-US.vtt') {
      res.writeHead(200, { 'Content-Type': 'text/vtt' });
      res.end(fs.readFileSync(VTT));
    } else if (req.url === '/subs') {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(withSubs);
    } else if (req.url === '/clip.mp4') {
      const stat = fs.statSync(CLIP);
      res.writeHead(200, { 'Content-Type': 'video/mp4', 'Content-Length': stat.size, 'Accept-Ranges': 'bytes' });
      fs.createReadStream(CLIP).pipe(res);
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(plain);
    }
  });
  return new Promise((r) => srv.listen(0, '127.0.0.1', () => r(srv)));
}

test('live dub: press Dub on a playing video and hear it in English', async () => {
  test.skip(!fs.existsSync(CLIP), 'test clip missing');
  test.setTimeout(300_000);
  const srv = await serveClip();
  const { app, ui } = await launch({ engine: 'on', env: { KOE_TEST_MUTE: '1' } });
  await ui.keyboard.press('Escape');

  // engine warms up in the background while the UI is already usable
  await expect(ui.locator('#engine-state')).toHaveText('Ready', { timeout: 240_000 });
  await expect(ui.locator('#dub-label')).toHaveText('Dub');

  await ui.fill('#address', `http://127.0.0.1:${srv.address().port}/`);
  await ui.press('#address', 'Enter');
  const page = await browserPage(app);
  await page.waitForSelector('#v');

  await ui.click('#dub-btn');
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'true');
  await page.evaluate(() => document.getElementById('v').play());

  // English lines arrive while the video plays
  await expect(ui.locator('#transcript li:not(.transcript-empty)')).toHaveCount(4, { timeout: 60_000 }).catch(() => {});
  await page.waitForFunction(() => document.getElementById('v').ended, null, { timeout: 90_000 });
  await ui.waitForTimeout(4000);

  const lines = await ui.locator('#transcript li:not(.transcript-empty)').allTextContents();
  console.log(lines.join('\n'));
  const text = lines.join(' ').toLowerCase();
  expect(lines.length).toBeGreaterThanOrEqual(8);
  for (const w of ['who are you', 'village', 'hurry']) expect(text).toContain(w);
  const characters = new Set(lines.map((l) => l.match(/^Character \d+/)?.[0]));
  expect(characters.size).toBe(2);                       // two speakers in the clip, two voices

  const latency = await ui.locator('#latency').textContent();
  console.log('last latency:', latency);
  expect(parseFloat(latency)).toBeLessThan(2.5);

  // full-window picture including the browser view and caption overlay, for the design review
  const png = await app.evaluate(async ({ BrowserWindow }) => (await BrowserWindow.getAllWindows()[0].capturePage()).toPNG().toString('base64'));
  fs.writeFileSync(path.join(SHOTS, '08-dubbing-window.png'), Buffer.from(png, 'base64'));

  await ui.click('#dub-btn');
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'false');
  await app.close();
  srv.close();
});

test('official subtitles: speaks the site translation, in sync, with character voices', async () => {
  test.skip(!fs.existsSync(CLIP), 'test clip missing');
  test.setTimeout(300_000);
  const srv = await serveClip();
  const { app, ui } = await launch({ engine: 'on', env: { KOE_TEST_MUTE: '1' } });
  await ui.keyboard.press('Escape');
  await expect(ui.locator('#engine-state')).toHaveText('Ready', { timeout: 240_000 });

  await ui.fill('#address', `http://127.0.0.1:${srv.address().port}/subs`);
  await ui.press('#address', 'Enter');
  const page = await browserPage(app);
  await page.waitForSelector('#v', { state: 'attached' });
  await expect(ui.locator('#source-title')).toHaveText('Official subtitles', { timeout: 15_000 });
  await expect(ui.locator('#source-detail')).toContainText('12 lines');

  await ui.click('#dub-btn');
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'true');
  await page.evaluate(() => document.getElementById('v').play());
  await page.waitForFunction(() => document.getElementById('v').ended, null, { timeout: 90_000 });
  await ui.waitForTimeout(3000);

  const lines = await ui.locator('#transcript li:not(.transcript-empty)').allTextContents();
  console.log(lines.join('\n'));
  const text = lines.join(' ');
  expect(lines.length).toBeGreaterThanOrEqual(11);            // nearly every line voiced, none invented
  expect(lines.length).toBeLessThanOrEqual(12);
  expect(text).toContain('beyond the mountains');             // the official wording, not a by-ear guess
  expect(text).not.toContain('devil');
  const byLine = Object.fromEntries(lines.map((l) => [l.replace(/^Character \d+/, ''), l.match(/^Character \d+/)[0]]));
  expect(byLine['Who goes there?']).toBe(byLine['The survivors fled beyond the mountains.']);
  expect(byLine['We came to protect the village.']).toBe(byLine['Where did everyone go?']);
  expect(byLine['Who goes there?']).not.toBe(byLine['We came to protect the village.']);
  expect(new Set(Object.values(byLine)).size).toBe(2);        // two people talk, so exactly two voices
  const latency = parseFloat(await ui.locator('#latency').textContent());
  console.log('latency after line start:', latency);
  expect(latency).toBeLessThan(1.5);

  // seeking back replays lines rather than going silent
  await page.evaluate(() => { const v = document.getElementById('v'); v.currentTime = 22; v.play(); });
  await expect.poll(async () => (await ui.locator('#transcript li:not(.transcript-empty)').allTextContents()).length,
    { timeout: 15_000 }).toBeGreaterThan(lines.length);

  await app.close();
  srv.close();
});

test('named characters (Crunchyroll-style subtitles): one fixed voice each, spoken on cue', async () => {
  test.skip(!fs.existsSync(CLIP), 'test clip missing');
  test.setTimeout(300_000);
  const ASS = fs.readFileSync(path.resolve(__dirname, '..', '..', '..', 'test', 'test_clip.en.ass'));
  const srv = http.createServer((req, res) => {
    const base = `http://127.0.0.1:${srv.address().port}`;
    if (req.url.startsWith('/play')) {             // the player learns its subtitle list from JSON, like Crunchyroll
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ hardSubs: {}, subtitles: { 'en-US': { format: 'ass', url: `${base}/cdn/77ab.txt?t=1` } } }));
    } else if (req.url.startsWith('/cdn/77ab')) {
      res.writeHead(200, { 'Content-Type': 'application/octet-stream' });
      res.end(ASS);
    } else if (req.url === '/clip.mp4') {
      const stat = fs.statSync(CLIP);
      res.writeHead(200, { 'Content-Type': 'video/mp4', 'Content-Length': stat.size });
      fs.createReadStream(CLIP).pipe(res);
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(`<!doctype html><body style="margin:0;background:#000"><video id="v" src="/clip.mp4" style="width:100%;height:100vh"></video>
        <script>fetch('/play').then(r => r.json())</script></body>`);
    }
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const { app, ui } = await launch({ engine: 'on', env: { KOE_TEST_MUTE: '1' } });
  await ui.keyboard.press('Escape');
  await expect(ui.locator('#engine-state')).toHaveText('Ready', { timeout: 240_000 });
  await ui.fill('#address', `http://127.0.0.1:${srv.address().port}/watch`);
  await ui.press('#address', 'Enter');
  const page = await browserPage(app);
  await page.waitForSelector('#v', { state: 'attached' });
  await expect(ui.locator('#source-title')).toHaveText('Official subtitles', { timeout: 15_000 });
  await ui.click('#dub-btn');
  await ui.waitForTimeout(1500);
  console.log('TOAST', await ui.locator('.toast').allTextContents(), await ui.locator('#dub-btn').getAttribute('aria-pressed'));
  await expect(ui.locator('#dub-btn')).toHaveAttribute('aria-pressed', 'true');
  await page.evaluate(() => document.getElementById('v').play());
  await page.waitForFunction(() => document.getElementById('v').ended, null, { timeout: 90_000 });
  await ui.waitForTimeout(2500);

  const lines = await ui.locator('#transcript li:not(.transcript-empty)').allTextContents();
  console.log(lines.join('\n'));
  expect(lines.length).toBe(12);
  const byLine = Object.fromEntries(lines.map((l) => [l.replace(/^Character \d+/, ''), l.match(/^Character \d+/)[0]]));
  const keita = new Set(['Who goes there?', 'What business do you have here?', 'The village?', 'That village already burned down.',
    'The survivors fled beyond the mountains.', 'Hurry, before nightfall.'].map((t) => byLine[t]));
  const nanami = new Set(['We came to protect the village.', 'Please, trust us.', "No... You're lying, right?",
    'Where did everyone go?', 'Understood.', "Let's go together!"].map((t) => byLine[t]));
  expect(keita.size).toBe(1);
  expect(nanami.size).toBe(1);
  expect([...keita][0]).not.toBe([...nanami][0]);
  const latency = parseFloat(await ui.locator('#latency').textContent());
  console.log('latency after line start:', latency);
  expect(latency).toBeLessThan(0.25);                        // known characters play the moment the line appears
  await app.close();
  srv.close();
});
