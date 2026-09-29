// A site whose player gets its subtitle list inside JSON (no <track>, no .vtt URL): Hoshidub must still find it.
const { test, expect } = require('@playwright/test');
const fs = require('fs');
const http = require('http');
const path = require('path');
const { launch } = require('./helpers');

const VTT = fs.readFileSync(path.resolve(__dirname, '..', '..', '..', 'test', 'test_clip.en.vtt'));

test('finds subtitles listed in the player JSON', async () => {
  const srv = http.createServer((req, res) => {
    const base = `http://127.0.0.1:${srv.address().port}`;
    if (req.url.startsWith('/api/play')) {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ url: `${base}/manifest.mpd`, subtitles: { 'ja-JP': { url: `${base}/s/ja?sig=1` }, 'en-US': { format: 'vtt', url: `${base}/s/9f8e7d?sig=2` } } }));
    } else if (req.url.startsWith('/s/9f8e7d')) {
      res.writeHead(200, { 'Content-Type': 'application/octet-stream' });
      res.end(VTT);
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(`<!doctype html><body><p>player</p><script>fetch('/api/play?id=1').then(r => r.json()).then(j => document.body.dataset.got = j.url);</script></body>`);
    }
  });
  await new Promise((r) => srv.listen(0, '127.0.0.1', r));
  const { app, ui } = await launch();
  await ui.keyboard.press('Escape');
  await ui.fill('#address', `http://127.0.0.1:${srv.address().port}/watch/1`);
  await ui.press('#address', 'Enter');
  await expect(ui.locator('#source-title')).toHaveText('Official subtitles', { timeout: 15_000 });
  await expect(ui.locator('#source-detail')).toContainText('12 lines');
  await app.close();
  srv.close();
});
